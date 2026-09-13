import 'package:path/path.dart' as p;
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/database_providers.dart';
import '../data/document_migration.dart';
import '../data/documents_directory.dart';
import '../data/document_store.dart';
import '../data/new_document.dart';
import '../data/save_as.dart';
import '../data/recent_documents.dart';
import 'document_session.dart';

part 'documents_providers.g.dart';

@Riverpod(keepAlive: true)
RecentDocuments recentDocumentsStore(Ref ref) =>
    RecentDocuments(DatabaseSettingsAccess(ref.watch(appDatabaseProvider)));

/// The recent list, newest first.
@riverpod
Future<List<RecentDocument>> recentDocuments(Ref ref) =>
    ref.watch(recentDocumentsStoreProvider).load();

/// Converts any pre-document projects the first time the app runs, and reports
/// what it wrote so the start screen can show them.
///
/// Runs once per machine and is a no-op everywhere else — see
/// [DocumentMigration].
@Riverpod(keepAlive: true)
Future<List<File>> convertedDocuments(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final written = await DocumentMigration(
    db,
    DatabaseSettingsAccess(db),
  ).run(await documentsDirectory());

  // Anything converted is offered in the recent list, so the one machine this
  // happens on finds its work where it expects to.
  final recents = ref.read(recentDocumentsStoreProvider);
  for (final file in written.reversed) {
    await recents.remember(
      file.path,
      name: file.uri.pathSegments.last.replaceAll('.flowmap', ''),
    );
  }
  ref.invalidate(recentDocumentsProvider);
  return written;
}

/// The document that is open, or null when the app is showing the start screen.
///
/// **One document owns the working tables at a time.** Opening or creating
/// another detaches this one first — it writes its last and stops following —
/// and only then are the tables replaced; see [DocumentSession.detach].
@Riverpod(keepAlive: true)
class OpenDocument extends _$OpenDocument {
  /// The session this notifier holds, kept beside [state] because Riverpod
  /// forbids reading `state` inside `onDispose` — which is where the lock has
  /// to be released when the app goes away.
  DocumentSession? _held;

  @override
  DocumentSession? build() {
    ref.onDispose(() => _held?.close());
    return null;
  }

  /// Opens [path], replacing whatever was open.
  ///
  /// Returns the holder when someone else has it, in which case nothing
  /// changed and the caller offers a read-only copy rather than a way to force
  /// it.
  Future<OpenOutcome> open(
    String path, {
    required String user,
    required String machine,
  }) async {
    final previous = state;
    // **The document already open here is not someone else's.** Asking the
    // lock again would find this session's own heartbeat and report the user
    // as holding their own project against themselves, which is what a second
    // click on a recent entry did (drive, 2026-09-13).
    if (previous != null && isSameDocument(previous.file.path, path)) {
      if (await previous.fileIsStillOurs()) return const OpenOutcome.opened();
      // **Unless the file was replaced under it** — renamed over, restored,
      // synced in. Then "already open" shows tables that are not the file, and
      // the next save would put them over it: the second loss of 2026-09-13.
      // The work is kept beside the file, the lock on this path is let go, and
      // what is on disk now is opened like any other document.
      if (!await previous.detach()) {
        await previous.resume(reload: false);
        return const OpenOutcome.unsaved();
      }
      final kept = previous.conflictCopy;
      state = _held = null;
      await previous.close();
      final outcome = await open(path, user: user, machine: machine);
      return outcome.taken || outcome.unsaved
          ? outcome
          : OpenOutcome.opened(conflictCopy: kept);
    }
    // **The open document gets out of the way before anything touches the
    // tables under it** — see [DocumentSession.detach] for what closing it
    // afterwards did to `VSM 2026 Q1.flowmap`.
    if (previous != null && !await previous.detach()) {
      await previous.resume(reload: false);
      return const OpenOutcome.unsaved();
    }

    final DocumentSession? session;
    try {
      session = await DocumentSession.open(
        path,
        db: ref.read(appDatabaseProvider),
        user: user,
        machine: machine,
      );
    } catch (_) {
      // The load may have emptied the tables before it failed. The previous
      // document's file holds everything (detach said so), so it comes back
      // whole from there.
      await previous?.resume(reload: true);
      rethrow;
    }
    if (session == null) {
      // Refused before this load touched anything — but [create] empties the
      // tables before it gets here, so they are refilled either way.
      await previous?.resume(reload: true);
      return const OpenOutcome.taken();
    }

    // Released only now: closing — rather than detaching — first would leave
    // the app with nothing if the open had failed.
    await previous?.close();
    state = _held = session;

    await ref
        .read(recentDocumentsStoreProvider)
        .remember(path, name: session.projectName);
    ref.invalidate(recentDocumentsProvider);
    return OpenOutcome.opened(conflictCopy: previous?.conflictCopy);
  }

  /// Writes a new document at [path] and opens it.
  ///
  /// **Creating and opening are the same act after the first line.** A new
  /// document is written to disk and then loaded through the ordinary path, so
  /// there is one loader, one lock, one autosave — and one thing that can be
  /// wrong with any of it.
  Future<OpenOutcome> create(
    String path, {
    required String projectName,
    required String plantName,
    required String user,
    required String machine,
  }) async {
    // `NewDocument` empties the working tables itself, so the open document
    // has to be out of the way before that rather than before the load.
    final previous = state;
    if (previous != null && !await previous.detach()) {
      await previous.resume(reload: false);
      return const OpenOutcome.unsaved();
    }
    try {
      await NewDocument(
        ref.read(appDatabaseProvider),
      ).create(path, projectName: projectName, plantName: plantName);
    } catch (_) {
      await previous?.resume(reload: true);
      rethrow;
    }
    return open(path, user: user, machine: machine);
  }

  /// Writes the open document to [path] as a **separate project**, and opens it.
  ///
  /// This is how a new project gets a plant, since a new document starts empty:
  /// open a reference, save a copy, and the copy is yours. The copy takes a
  /// fresh project id, so its runs are its own rather than the original's —
  /// stored runs are keyed by document id (v32), and a byte-for-byte copy would
  /// leave two files pooling one history.
  Future<OpenOutcome> saveAs(
    String path, {
    required String user,
    required String machine,
  }) async {
    final session = state;
    if (session == null) return const OpenOutcome.opened();

    // Flush first, so the copy is of what is on screen rather than of whatever
    // the debounce had last written.
    await session.save();

    final db = ref.read(appDatabaseProvider);
    final current = await DocumentStore(
      db,
    ).capture(projectId: session.projectId, projectName: session.projectName);
    final copy = SaveAs.rename(
      current,
      newProjectId: const Uuid().v4(),
      newProjectName: SaveAs.projectNameFor(path),
      appVersion: current.manifest.appVersion,
    );
    await DocumentStore.writeAtomically(File(path), copy.write());

    return open(path, user: user, machine: machine);
  }

  /// Flushes and releases, leaving the app on the start screen.
  ///
  /// Returns where the work went when the file had been replaced on disk.
  Future<File?> close() async {
    final session = state;
    state = _held = null;
    await session?.close();
    return session?.conflictCopy;
  }
}

/// What opening a document did.
class OpenOutcome {
  const OpenOutcome.opened({this.conflictCopy})
    : taken = false,
      unsaved = false;
  const OpenOutcome.taken() : taken = true, unsaved = false, conflictCopy = null;
  const OpenOutcome.unsaved()
    : taken = false,
      unsaved = true,
      conflictCopy = null;

  /// Where the previous document's work was kept, when its own file had been
  /// replaced on disk and could not take it.
  final File? conflictCopy;

  /// True when another person holds the lock and nothing was opened.
  final bool taken;

  /// True when the document already open could not be written, so it was kept
  /// open rather than replaced: its latest work exists only in the database.
  final bool unsaved;
}

/// Whether two paths name one document. Canonicalised, because Windows paths
/// differ in case and separators and still name the same file.
bool isSameDocument(String a, String b) =>
    p.canonicalize(a) == p.canonicalize(b);
