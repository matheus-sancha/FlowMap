import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/database_providers.dart';
import 'package:flowmap/src/features/documents/application/documents_providers.dart';
import 'package:flowmap/src/features/documents/data/document_lock.dart';
import 'package:flowmap/src/features/documents/data/new_document.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Opening the document that is already open (drive, 2026-09-13).
///
/// The field report: a recent entry clicked once loaded the project without
/// going to it, and clicked again said *"mathe has this project open"*. The
/// second click had asked the lock again and found this session's own
/// heartbeat.
void main() {
  late AppDatabase db;
  late Directory dir;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('flowmap_reopen');
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('opening the open document again is not a lock conflict', () async {
    final path = p.join(dir.path, 'VSM 2026 Q1.flowmap');
    await NewDocument(
      db,
    ).create(path, projectName: 'VSM 2026 Q1', plantName: 'Planta');

    final notifier = container.read(openDocumentProvider.notifier);
    final first = await notifier.open(path, user: 'mathe', machine: 'Desktop');
    expect(first.taken, isFalse);
    final session = container.read(openDocumentProvider);
    expect(DocumentLock.holderOf(path), isNotNull, reason: 'the lock is held');

    // The same file, spelled the way Windows might hand it back.
    final again = await notifier.open(
      path.toUpperCase(),
      user: 'mathe',
      machine: 'Desktop',
    );
    expect(again.taken, isFalse);
    // And it is the same session, not a reload over the work in progress.
    expect(container.read(openDocumentProvider), same(session));
  });

  test('a different document still meets its own lock', () async {
    final path = p.join(dir.path, 'Other.flowmap');
    await NewDocument(db).create(path, projectName: 'Other', plantName: 'P');
    await DocumentLock.acquire(path, user: 'colleague', machine: 'Laptop');

    final outcome = await container
        .read(openDocumentProvider.notifier)
        .open(path, user: 'mathe', machine: 'Desktop');
    expect(outcome.taken, isTrue);
  });
}
