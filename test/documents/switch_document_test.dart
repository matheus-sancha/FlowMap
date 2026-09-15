import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/database_providers.dart';
import 'package:flowmap/src/features/documents/application/document_session.dart';
import 'package:flowmap/src/features/documents/application/documents_providers.dart';
import 'package:flowmap/src/features/documents/data/document_lock.dart';
import 'package:flowmap/src/features/documents/data/document_store.dart';
import 'package:flowmap/src/features/documents/data/flowmap_document.dart';
import 'package:flowmap/src/features/documents/data/new_document.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Going from one document to another (field report, 2026-09-13).
///
/// **What happened:** opening B loaded B into the working tables and only then
/// closed A — and closing always writes. A's session captured a database that
/// now held B, found no row for A's project, and wrote B's plant and an empty
/// project over A's file. Every switch that day handed the loaded plant on to
/// the next file, and `Plan Q1.flowmap` ended as 1.8 KB of empty plants.
///
/// The rule these tests hold: **a session stops following, and writes for the
/// last time, before anything replaces the tables under it.**
void main() {
  late AppDatabase db;
  late Directory dir;
  late ProviderContainer container;
  late String pathA;
  late String pathB;

  const user = 'mathe';
  const machine = 'Desktop';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('flowmap_switch');
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    pathA = p.join(dir.path, 'a', 'Plan Q1.flowmap');
    pathB = p.join(dir.path, 'b', 'Plan Q2.flowmap');
    await NewDocument(
      db,
    ).create(pathA, projectName: 'Plan Q1', plantName: 'Plant 1');
    await NewDocument(
      db,
    ).create(pathB, projectName: 'Plan Q2', plantName: 'Plant 2');
  });

  tearDown(() async {
    await container.read(openDocumentProvider.notifier).close();
    container.dispose();
    await db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  OpenDocument notifier() => container.read(openDocumentProvider.notifier);

  FlowmapDocument onDisk(String path) =>
      FlowmapDocument.read(File(path).readAsBytesSync());

  /// Through Drift's typed API, as every repository writes.
  Future<void> renameProject(String name) async {
    final id = container.read(openDocumentProvider)!.projectId;
    await (db.update(db.projects)..where((r) => r.id.equals(id))).write(
      ProjectsCompanion(name: Value(name)),
    );
  }

  Future<List<String>> projectNames() async => [
    for (final row in await db.select(db.projects).get()) row.name,
  ];

  test('opening B leaves A\'s file holding A', () async {
    await notifier().open(pathA, user: user, machine: machine);
    await renameProject('Plan Q1 edited');

    await notifier().open(pathB, user: user, machine: machine);

    final a = onDisk(pathA);
    expect(a.project['projects']!.map((r) => r['name']), [
      'Plan Q1 edited',
    ], reason: 'the edit made before switching reached A');
    expect(a.plant['plants']!.map((r) => r['name']), ['Plant 1']);
    // And B is what is open, whole.
    expect(await projectNames(), ['Plan Q2']);
    expect(DocumentLock.holderOf(pathA), isNull);
    expect(DocumentLock.holderOf(pathB), isNotNull);
  });

  test('switching back and forth changes neither file', () async {
    await notifier().open(pathA, user: user, machine: machine);
    await notifier().open(pathB, user: user, machine: machine);
    await notifier().open(pathA, user: user, machine: machine);
    await notifier().open(pathB, user: user, machine: machine);

    expect(onDisk(pathA).plant['plants']!.map((r) => r['name']), ['Plant 1']);
    expect(onDisk(pathA).project['projects'], hasLength(1));
    expect(onDisk(pathB).plant['plants']!.map((r) => r['name']), ['Plant 2']);
    expect(onDisk(pathB).project['projects'], hasLength(1));
  });

  test('creating a new document leaves the open one\'s file whole', () async {
    // `NewDocument` empties the working tables before it opens anything, so
    // the open session has to be out of the way before *that*, not just
    // before the load.
    await notifier().open(pathA, user: user, machine: machine);
    await renameProject('Kept');

    await notifier().create(
      p.join(dir.path, 'c', 'New.flowmap'),
      projectName: 'New',
      plantName: '4003',
      user: user,
      machine: machine,
    );

    final a = onDisk(pathA);
    expect(a.project['projects']!.single['name'], 'Kept');
    expect(a.plant['plants']!.map((r) => r['name']), ['Plant 1']);
  });

  test('a document someone else holds leaves the open one open and following',
      () async {
    await notifier().open(pathA, user: user, machine: machine);
    final session = container.read(openDocumentProvider);
    await DocumentLock.acquire(pathB, user: 'ana', machine: 'Laptop');

    final outcome = await notifier().open(pathB, user: user, machine: machine);

    expect(outcome.taken, isTrue);
    expect(container.read(openDocumentProvider), same(session));
    expect(await projectNames(), ['Plan Q1']);

    // Still following: an edit after the refusal reaches A's file.
    await renameProject('After the refusal');
    await session!.save();
    expect(onDisk(pathA).project['projects']!.single['name'],
        'After the refusal');
  });

  test('a document that fails while loading puts the open one back', () async {
    // A column this build does not know is refused inside the load, after the
    // working tables have already been emptied.
    final b = onDisk(pathB);
    final bad = FlowmapDocument(
      manifest: b.manifest,
      plant: {
        ...b.plant,
        'plants': [
          for (final row in b.plant['plants']!) {...row, 'from_the_future': 1},
        ],
      },
      project: b.project,
    );
    await DocumentStore.writeAtomically(File(pathB), bad.write());

    await notifier().open(pathA, user: user, machine: machine);
    await renameProject('Before the failure');
    final session = container.read(openDocumentProvider);

    await expectLater(
      notifier().open(pathB, user: user, machine: machine),
      throwsA(isA<DocumentFormatException>()),
    );

    expect(container.read(openDocumentProvider), same(session));
    expect(await projectNames(), ['Before the failure']);
    expect(
      DocumentLock.holderOf(pathB),
      isNull,
      reason: 'a document that could not be opened is not left locked',
    );

    await renameProject('After the failure');
    await session!.save();
    expect(onDisk(pathA).project['projects']!.single['name'],
        'After the failure');
  });

  test('an open document that cannot be saved is not replaced', () async {
    await notifier().open(pathA, user: user, machine: machine);
    final session = container.read(openDocumentProvider);

    // A's share goes away, then an edit lands that only the database has.
    Directory(p.dirname(pathA)).deleteSync(recursive: true);
    await renameProject('Only in the database');

    final outcome = await notifier().open(pathB, user: user, machine: machine);

    expect(outcome.unsaved, isTrue);
    expect(container.read(openDocumentProvider), same(session));
    expect(await projectNames(), ['Only in the database']);
    expect(DocumentLock.holderOf(pathB), isNull);

    // The share comes back, and the next save reaches it.
    Directory(p.dirname(pathA)).createSync(recursive: true);
    await session!.save();
    expect(onDisk(pathA).project['projects']!.single['name'],
        'Only in the database');
  });

  test('a list already on screen shows the document just opened', () async {
    // The other half of the same report: Resources kept showing the previous
    // document's plant, because a load raised no table update and no stream
    // ever re-read.
    await notifier().open(pathA, user: user, machine: machine);

    final seen = <List<String>>[];
    final sub = db
        .select(db.plants)
        .watch()
        .map((rows) => [for (final r in rows) r.name])
        .listen(seen.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(seen.last, ['Plant 1']);

    await notifier().open(pathB, user: user, machine: machine);
    await pumpEventQueue();

    expect(seen.last, ['Plant 2']);
    // And the announcement did not read as an edit to the session now open.
    expect(container.read(openDocumentProvider)!.state, SaveState.saved);
  });

  test('reopening a file that was replaced on disk loads what is there now',
      () async {
    // The second loss, the same evening: the damaged Q1 was open, the files
    // were renamed so the restored copy took its name, and a click on the
    // recent entry counted as "already open" — showing the damaged tables and
    // poised to save them over the restored file.
    await notifier().open(pathA, user: user, machine: machine);
    await renameProject('Damaged, still open');

    await DocumentStore.writeAtomically(
      File(pathA),
      File(pathB).readAsBytesSync(),
    );
    final outcome = await notifier().open(pathA, user: user, machine: machine);

    expect(outcome.taken, isFalse);
    expect(outcome.unsaved, isFalse);
    expect(await projectNames(), ['Plan Q2'], reason: 'what is on disk');
    expect(onDisk(pathA).project['projects']!.single['name'], 'Plan Q2');
    expect(outcome.conflictCopy, isNotNull);
    expect(
      onDisk(outcome.conflictCopy!.path).project['projects']!.single['name'],
      'Damaged, still open',
    );
    expect(DocumentLock.holderOf(pathA), isNotNull);
  });

  test('the damaged document, replaced by the restored one, opens the restored one',
      () async {
    // Exactly the second loss: what was open held no project at all, the
    // restored file took its name, and the recent entry was clicked again.
    await notifier().open(pathA, user: user, machine: machine);
    final id = container.read(openDocumentProvider)!.projectId;
    await (db.delete(db.projects)..where((r) => r.id.equals(id))).go();
    final restored = File(pathB).readAsBytesSync();
    await DocumentStore.writeAtomically(File(pathA), restored);

    final outcome = await notifier().open(pathA, user: user, machine: machine);

    expect(outcome.unsaved, isFalse, reason: 'nothing there to keep');
    expect(outcome.conflictCopy, isNull, reason: 'and nothing written for it');
    expect(await projectNames(), ['Plan Q2']);
    expect(File(pathA).readAsBytesSync(), restored);

    // Leaving it again does not touch the restored file either, beyond saving
    // what is really open.
    await notifier().close();
    expect(onDisk(pathA).project['projects']!.single['name'], 'Plan Q2');
  });
}
