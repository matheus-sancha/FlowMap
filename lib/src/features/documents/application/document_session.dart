import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

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

  /// The file on disk is no longer the one this session read or wrote —
  /// renamed over, restored, or synced in from elsewhere — so it is not saved
  /// over. The work is still in the database, and leaving the document keeps
  /// it as a separate copy beside the file.
  conflict,
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

  /// True once this session has stopped following the database, and so must
  /// not write again until it [resume]s — see [detach].
  bool _detached = false;

  /// Whether the last [detach] left the work in a file.
  bool _detachedOk = false;

  /// The exact bytes this session last read from or wrote to [file].
  ///
  /// **A file is only ever saved over when it is still this.** The second loss
  /// on 2026-09-13 was a session holding a path whose file had been replaced
  /// under it — the restored Q1, renamed into the damaged one's place — and one
  /// more write would have put the damaged tables over it again.
  Uint8List? _onDisk;

  /// What [resume] reloads: the file as opened, or what [detach] last wrote,
  /// wherever it wrote it.
  Uint8List? _detachedAs;

  /// Where this session's work went when its file had been replaced, if it did.
  File? get conflictCopy => _conflictCopy;
  File? _conflictCopy;

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
    final bytes = await file.readAsBytes();
    final document = FlowmapDocument.read(bytes);
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
    try {
      await store.load(document);
    } catch (_) {
      // A document that could not be opened is not left locked against
      // everyone else until the heartbeat goes stale.
      await lock.release();
      rethrow;
    }
    announceLoad(db);

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
    session._onDisk = session._detachedAs = bytes;
    session._follow();
    return session;
  }

  /// Tells every stream reading a working table that its rows were replaced.
  ///
  /// **A load raises no table update of its own** (see `DocumentStore.load`),
  /// so without this every list already on screen went on showing the previous
  /// document — which is what Resources did on 2026-09-13.
  ///
  /// **Called before a session follows, never after.** Drift delivers these
  /// synchronously to the listeners present at that moment, so the session about
  /// to follow does not hear its own load as an edit; and a session that was
  /// following has already [detach]ed, so it cannot hear it either.
  static void announceLoad(GeneratedDatabase db) {
    db.notifyUpdates({
      for (final info in db.allTables)
        if (DocumentStore.workingTables.contains(info.actualTableName))
          TableUpdate.onTable(info),
    });
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
    // In conflict nothing is written until the document is left, so there is
    // nothing to schedule.
    if (_closed || _detached || _state == SaveState.conflict) return;
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
    // A detached session's tables may already hold another document, and a
    // capture now would write that document into this one's file.
    if (_detached) return;
    final inFlight = _writing;
    if (inFlight != null) {
      await inFlight;
      if (_pending != null || _closed || _detached) return;
    }
    final work = _write();
    _writing = work;
    try {
      await work;
    } finally {
      if (identical(_writing, work)) _writing = null;
    }
  }

  /// Whether the file at [file]'s path is still the one this session knows.
  ///
  /// A file that is simply gone is: writing it again replaces nothing.
  Future<bool> fileIsStillOurs() async {
    if (!await file.exists()) return true;
    final known = _onDisk;
    if (known == null) return false;
    final now = await file.readAsBytes();
    if (now.length != known.length) return false;
    for (var i = 0; i < now.length; i++) {
      if (now[i] != known[i]) return false;
    }
    return true;
  }

  /// Captures the database and writes it to [file].
  ///
  /// When [leaving], a file replaced on disk gets the work beside it as a
  /// conflict copy instead, because this is the last chance to keep it.
  /// Returns whether the work is now in a file somewhere.
  Future<bool> _write({bool leaving = false}) async {
    try {
      _emit(SaveState.saving);
      final document = await _store.capture(
        projectId: projectId,
        projectName: projectName,
      );
      // **A document without its project is never the work** — it is what a
      // capture of somebody else's tables looks like, which is exactly what
      // the first loss wrote. Whatever led here, it is written nowhere.
      //
      // And when leaving, tables that do not hold this project hold none of
      // its work either, so there is nothing to keep and nothing to stop the
      // next document opening — which is the state the damaged Q1 left behind.
      if (document.project['projects']?.isEmpty ?? true) {
        _emit(SaveState.failed);
        return leaving;
      }
      final bytes = document.write();

      if (!await fileIsStillOurs()) {
        if (!leaving) {
          _emit(SaveState.conflict);
          return false;
        }
        final copy = File(conflictPathFor(file.path, DateTime.now()));
        await DocumentStore.writeAtomically(copy, bytes);
        _conflictCopy = copy;
        _detachedAs = bytes;
        _emit(SaveState.conflict);
        return true;
      }

      await DocumentStore.writeAtomically(file, bytes);
      _onDisk = bytes;
      _detachedAs = bytes;
      _savedAt = DateTime.now();
      _emit(SaveState.saved);
      return true;
    } catch (_) {
      // **Never thrown at the app.** A share that has gone away, a file gone
      // read-only, a disk that is full: the work is still in the database and
      // the next change tries again. What must not happen is an edit failing
      // because saving did.
      _emit(SaveState.failed);
      return false;
    }
  }

  /// A sibling of [path] that says it holds work its file could not take —
  /// `Plan Q1 (conflict 2026-09-13 2031).flowmap` — and is never a name
  /// already taken.
  static String conflictPathFor(String path, DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    final dir = p.dirname(path);
    final stem = p.basename(path).replaceFirst(
      RegExp(r'\.flowmap$', caseSensitive: false),
      '',
    );
    final stamp =
        '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}${two(at.minute)}';
    var candidate = p.join(dir, '$stem (conflict $stamp).flowmap');
    for (var n = 2; File(candidate).existsSync(); n++) {
      candidate = p.join(dir, '$stem (conflict $stamp, $n).flowmap');
    }
    return candidate;
  }

  void _emit(SaveState next) {
    if (_state == next) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  /// Writes one last time and stops following the database, **keeping the
  /// lock**.
  ///
  /// **Called before anything replaces the working tables** — opening another
  /// document, or creating one. Closing afterwards is too late, because a close
  /// writes and by then the tables hold the other document: A's session
  /// captured B, found no row for A's project, and wrote B's plant and an empty
  /// project over A's file. That is what emptied `Plan Q1.flowmap` on
  /// 2026-09-13.
  ///
  /// Returns whether the work is now in a file — this session's own, or a
  /// conflict copy beside it when its own was replaced on disk. When it is in
  /// neither, the caller must not replace the tables — the only copy of the
  /// last edit is in them — and [resume]s instead.
  Future<bool> detach() async {
    if (_closed) return false;
    if (_detached) return _detachedOk;
    _detached = true;
    _pending?.cancel();
    _pending = null;
    await _watch?.cancel();
    _watch = null;
    await _writing;
    _detachedOk = await _write(leaving: true);
    return _detachedOk;
  }

  /// Follows the database again after a [detach] that led nowhere.
  ///
  /// With [reload] the tables are refilled from this session's own file first,
  /// for when a replacement had already begun emptying them. That is exact,
  /// because a replacement only starts once [detach] said the file held
  /// everything.
  Future<void> resume({required bool reload}) async {
    if (_closed || !_detached) return;
    if (reload) {
      // What [detach] wrote, wherever it went: the file, or the conflict copy
      // when the file was no longer this session's.
      await _store.load(FlowmapDocument.read(_detachedAs!));
      announceLoad(_db);
    }
    _detached = false;
    _follow();
    // A write that failed before is still owed to the file.
    if (_state == SaveState.failed) _markDirty();
  }

  /// Flushes anything outstanding, releases the lock, and stops following.
  ///
  /// **The flush comes first.** Releasing a lock on a document whose last edit
  /// has not landed invites the next person to open a file that is behind. A
  /// session that has already [detach]ed wrote its last then, and does not
  /// write again: the tables may hold another document by now.
  Future<void> close() async {
    if (_closed) return;
    await detach();
    _closed = true;
    await lock.release();
    await _states.close();
  }
}
