import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';

import '../data/document_lock.dart';
import '../data/document_store.dart';
import '../data/flowmap_document.dart';

/// What the open document is doing, for the one indicator the app shows.
enum SaveState {
  /// Everything in the database has reached the file.
  saved,

  /// A change is waiting for the debounce, or is being written now.
  saving,

  /// The last write failed. The work is still in the database; the file is
  /// behind.
  failed,
}

/// The open document: its file, its lock, and the write-through that keeps the
/// two in step.
///
/// **There is no Save button** (#37). Every edit commits to the working database
/// exactly as it always has — §12 has never had a Save, and unsaved work would
/// be new vocabulary on every screen for people who cannot be walked through
/// recovery. The file simply follows.
///
/// **Changes are noticed through Drift rather than through the app.** Every
/// write raises a table update, so this watches the database instead of asking
/// nine repositories to report in. That is what keeps #37's promise that all
/// nine are untouched.
///
/// **A run does not dirty the document.** Runs belong to the machine, not the
/// file (#37), and pressing Simulate writes hundreds of thousands of rows — so
/// the eight `simulation_run*` tables are deliberately not watched. Without
/// that, every simulation would rewrite the document over the network for no
/// reason.
class DocumentSession {
  DocumentSession._({
    required this.file,
    required this.lock,
    required this._store,
    required this._db,
    required this.projectId,
    required this.projectName,
    required this._debounce,
  });

  /// How long a change waits before it is written.
  ///
  /// Long enough that typing a name is one write rather than twelve, short
  /// enough that closing the lid a second later has already saved. It matters
  /// most on a network share, which is where #37 expects these files to live.
  static const defaultDebounce = Duration(seconds: 2);

  final File file;
  final DocumentLock lock;
  final DocumentStore _store;
  final GeneratedDatabase _db;
  final String projectId;
  final String projectName;
  final Duration _debounce;

  StreamSubscription<void>? _watch;
  Timer? _pending;
  Future<void>? _writing;
  bool _closed = false;

  final _states = StreamController<SaveState>.broadcast();

  /// The save indicator's source: `saved 14:22` / `saving…`.
  Stream<SaveState> get states => _states.stream;

  SaveState _state = SaveState.saved;
  SaveState get state => _state;

  DateTime? _savedAt;

  /// When the file last matched the database.
  DateTime? get savedAt => _savedAt;

  /// Opens [path] into the working database and begins following it.
  ///
  /// Returns null when someone else holds the lock — the caller offers a
  /// read-only copy rather than a way to force it.
  static Future<DocumentSession?> open(
    String path, {
    required GeneratedDatabase db,
    required String user,
    required String machine,
    Duration debounce = defaultDebounce,
  }) async {
    final file = File(path);
    final document = FlowmapDocument.read(await file.readAsBytes());
    if (document.manifest.isFromNewerFormat) {
      throw DocumentFormatException(
        'This document was written by a newer version of FlowMap. '
        'Update FlowMap to open it.',
      );
    }

    final lock = await DocumentLock.acquire(
      path,
      user: user,
      machine: machine,
    );
    if (lock == null) return null;

    final store = DocumentStore(db);
    await store.load(document);

    final session = DocumentSession._(
      file: file,
      lock: lock,
      store: store,
      db: db,
      projectId: document.manifest.projectId,
      projectName: document.manifest.projectName,
      debounce: debounce,
    );
    session._savedAt = DateTime.now();
    session._follow();
    return session;
  }

  /// Watches every table the document owns, and nothing else.
  void _follow() {
    final watched = [
      for (final info in _db.allTables)
        if (DocumentStore.workingTables.contains(info.actualTableName)) info,
    ];
    _watch = _db
        .tableUpdates(TableUpdateQuery.onAllTables(watched))
        .listen((_) => _markDirty());
  }

  void _markDirty() {
    if (_closed) return;
    _emit(SaveState.saving);
    _pending?.cancel();
    // Restarted on every change, so a burst of edits is one write at the end
    // rather than one per keystroke.
    _pending = Timer(_debounce, () => unawaited(_flush()));
  }

  /// Writes now, whatever the debounce was going to do.
  ///
  /// Used on close, and by anything that wants the file current before it is
  /// read by something else.
  Future<void> save() async {
    _pending?.cancel();
    _pending = null;
    await _flush();
  }

  Future<void> _flush() async {
    // One writer at a time inside the process, too: two overlapping captures
    // would race to rename over the same file.
    final inFlight = _writing;
    if (inFlight != null) {
      await inFlight;
      if (_pending != null || _closed) return;
    }
    final work = _write();
    _writing = work;
    try {
      await work;
    } finally {
      if (identical(_writing, work)) _writing = null;
    }
  }

  Future<void> _write() async {
    try {
      _emit(SaveState.saving);
      final document = await _store.capture(
        projectId: projectId,
        projectName: projectName,
      );
      await DocumentStore.writeAtomically(file, document.write());
      _savedAt = DateTime.now();
      _emit(SaveState.saved);
    } catch (_) {
      // **Never thrown at the app.** A share that has gone away, a file gone
      // read-only, a disk that is full: the work is still in the database and
      // the next change tries again. What must not happen is an edit failing
      // because saving did.
      _emit(SaveState.failed);
    }
  }

  void _emit(SaveState next) {
    if (_state == next) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  /// Flushes anything outstanding, releases the lock, and stops following.
  ///
  /// **The flush comes first.** Releasing a lock on a document whose last edit
  /// has not landed invites the next person to open a file that is behind.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _pending?.cancel();
    _pending = null;
    await _writing;
    await _write();
    await _watch?.cancel();
    await lock.release();
    await _states.close();
  }
}
