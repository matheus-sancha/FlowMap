import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/database_providers.dart';
import '../data/document_migration.dart';
import '../data/documents_directory.dart';
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
/// **Resources and Settings stay reachable with nothing open.** With no
/// document, Resources shows the *library* — the plant `New project` seeds from
/// — which is what #37 left the local database holding. With a document open it
/// shows that document's plant, because a load replaces the working tables
/// whole.
@Riverpod(keepAlive: true)
class OpenDocument extends _$OpenDocument {
  @override
  DocumentSession? build() {
    ref.onDispose(() => state?.close());
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
    final session = await DocumentSession.open(
      path,
      db: ref.read(appDatabaseProvider),
      user: user,
      machine: machine,
    );
    if (session == null) return const OpenOutcome.taken();

    // Only after the new one is open: closing first would leave the app with
    // nothing if the open failed.
    await previous?.close();
    state = session;

    await ref
        .read(recentDocumentsStoreProvider)
        .remember(path, name: session.projectName);
    ref.invalidate(recentDocumentsProvider);
    return const OpenOutcome.opened();
  }

  /// Flushes and releases, leaving the app on the start screen.
  Future<void> close() async {
    final session = state;
    state = null;
    await session?.close();
  }
}

/// What opening a document did.
class OpenOutcome {
  const OpenOutcome.opened() : taken = false;
  const OpenOutcome.taken() : taken = true;

  /// True when another person holds the lock and nothing was opened.
  final bool taken;
}
