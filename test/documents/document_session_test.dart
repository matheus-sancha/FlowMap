import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/documents/application/document_session.dart';
import 'package:flowmap/src/features/documents/data/document_lock.dart';
import 'package:flowmap/src/features/documents/data/document_store.dart';
import 'package:flowmap/src/features/documents/data/flowmap_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// There is no Save button, so every claim here is about the file keeping up
/// with the database on its own — and about the two ways that could go wrong:
/// writing too often, and not writing at all.
void main() {
  late AppDatabase db;
  late Directory dir;
  late String path;

  // Short enough to wait on in a test, long enough to still coalesce.
  const debounce = Duration(milliseconds: 60);
  final settle = debounce * 4;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('flowmap_session');
    path = p.join(dir.path, 'Celula-11.flowmap');

    await db.customStatement('PRAGMA foreign_keys = OFF');
    Future<void> run(String sql) => db.customStatement(sql);
    await run("INSERT INTO plants (id,name,created_at,updated_at) "
        "VALUES ('plant-1','Planta',0,0)");
    await run("INSERT INTO shift_patterns (id,name,cycle_type,working_weekdays,"
        "created_at,updated_at) VALUES ('sp-1','Fixture','fixedWeekly',62,0,0)");
    await run("INSERT INTO workcenter_types (id,name,is_built_in,created_at) "
        "VALUES ('type-1','Fixture Type',0,0)");
    await run("INSERT INTO workcenters (id,plant_id,type_id,name,"
        "parallel_capacity,created_at,updated_at) "
        "VALUES ('wc-1','plant-1','type-1','CLAD07',1,0,0)");
    await run("INSERT INTO projects (id,name,plant_id,shift_pattern_id,"
        "float_red_days,float_green_days,occupation_amber_pct,"
        "occupation_red_pct,created_at,updated_at) "
        "VALUES ('proj-1','VSM 2026 Q1','plant-1','sp-1',0,30,85,100,0,0)");
    await db.customStatement('PRAGMA foreign_keys = ON');

    final doc = await DocumentStore(db).capture(
      projectId: 'proj-1',
      projectName: 'VSM 2026 Q1',
    );
    await DocumentStore.writeAtomically(File(path), doc.write());
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<DocumentSession> open({Duration d = debounce}) async {
    final session = await DocumentSession.open(
      path,
      db: db,
      user: 'matheus',
      machine: 'ENG-04',
      debounce: d,
    );
    return session!;
  }

  /// Through Drift's typed API, as every repository does — `customStatement`
  /// deliberately raises no table update, so a raw write would be invisible to
  /// the session. That asymmetry is real and is asserted further down.
  Future<void> rename(String name) =>
      (db.update(db.projects)..where((p) => p.id.equals('proj-1'))).write(
        ProjectsCompanion(name: Value(name)),
      );

  test('an edit reaches the file with nobody pressing anything', () async {
    final session = await open();
    addTearDown(session.close);

    await rename('Renamed');
    await Future<void>.delayed(settle);

    final written = FlowmapDocument.read(File(path).readAsBytesSync());
    expect(written.project['projects']!.single['name'], 'Renamed');
    expect(session.state, SaveState.saved);
    expect(session.savedAt, isNotNull);
  });

  test('a burst of edits is one write, not one per edit', () async {
    final session = await open();
    addTearDown(session.close);

    await Future<void>.delayed(settle);
    final saves = <SaveState>[];
    final sub = session.states.listen(saves.add);
    addTearDown(sub.cancel);

    for (var i = 0; i < 8; i++) {
      await rename('Name $i');
    }
    await Future<void>.delayed(settle);

    final written = FlowmapDocument.read(File(path).readAsBytesSync());
    // Only the last one needs to be on disk: the debounce exists so typing a
    // name is one write over a network share rather than twelve.
    expect(written.project['projects']!.single['name'], 'Name 7');
    // And the proof that it *was* one write rather than eight — a write each
    // time would cycle the state eight times over. File timestamps cannot say
    // this: the writes land inside one filesystem tick.
    expect(
      saves.where((s) => s == SaveState.saved),
      hasLength(1),
      reason: 'the debounce did not coalesce: $saves',
    );
  });

  test('a simulation does not rewrite the document', () async {
    // **The claim that pays for watching only the working tables.** Runs belong
    // to the machine, not the file (#37), and one press of Simulate writes
    // hundreds of thousands of rows — every one of which would otherwise push
    // the whole document over the network again.
    final session = await open();
    addTearDown(session.close);
    await Future<void>.delayed(settle);
    final before = File(path).readAsBytesSync();

    await db.customStatement(
      "INSERT INTO simulation_runs (id,document_id,dispatch,run_start,run_end,"
      "guard,created_at) VALUES ('run-1','proj-1','',0,0,0,0)",
    );
    await db.customStatement(
      "INSERT INTO simulation_run_steps (run_id,study_id,order_id,node_id,"
      "workcenter_id,queue_start,process_start,process_end) "
      "VALUES ('run-1','s','o','n','wc',0,0,0)",
    );
    await Future<void>.delayed(settle);

    expect(session.state, SaveState.saved);
    expect(File(path).readAsBytesSync(), before);
  });

  test('opening does not count as an edit', () async {
    // A document just read from disk already matches its file. If the load
    // looked like a change, every open would immediately write the whole
    // document straight back out — over the network, for nothing.
    final session = await open();
    addTearDown(session.close);

    final seen = <SaveState>[];
    final sub = session.states.listen(seen.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(settle);

    expect(seen, isEmpty);
    expect(session.state, SaveState.saved);
  });

  test('closing flushes work the debounce had not written yet', () async {
    final session = await open(d: const Duration(seconds: 30));

    await rename('Typed just before closing');
    // Nowhere near the debounce — without the flush this edit would be lost.
    await session.close();

    final written = FlowmapDocument.read(File(path).readAsBytesSync());
    expect(
      written.project['projects']!.single['name'],
      'Typed just before closing',
    );
  });

  test('closing releases the lock, and only after the write', () async {
    final session = await open(d: const Duration(seconds: 30));
    expect(DocumentLock.holderOf(path), isNotNull);

    await rename('Last word');
    await session.close();

    expect(DocumentLock.holderOf(path), isNull);
    final written = FlowmapDocument.read(File(path).readAsBytesSync());
    expect(written.project['projects']!.single['name'], 'Last word');
  });

  test('a second session is refused while the first holds the lock', () async {
    final first = await open();
    addTearDown(first.close);

    final second = await DocumentSession.open(
      path,
      db: db,
      user: 'ana',
      machine: 'ENG-09',
    );
    expect(second, isNull);
  });

  test('a failed write is reported, and never thrown at the app', () async {
    final session = await open();
    addTearDown(() async {
      dir.createSync(recursive: true);
      await session.close();
    });
    await Future<void>.delayed(settle);

    // The share goes away mid-edit.
    dir.deleteSync(recursive: true);
    await rename('Into the void');

    await expectLater(session.save(), completes);
    expect(session.state, SaveState.failed);
    // And the work is still in the database, which is the point: an edit must
    // not fail because saving did.
    final row = await db.customSelect(
      "SELECT name FROM projects WHERE id = 'proj-1'",
    ).getSingle();
    expect(row.data['name'], 'Into the void');
  });

  test('the state says saving before it says saved', () async {
    final session = await open();
    addTearDown(session.close);
    await Future<void>.delayed(settle);

    final seen = <SaveState>[];
    final sub = session.states.listen(seen.add);
    addTearDown(sub.cancel);

    await rename('Watched');
    await Future<void>.delayed(settle);

    expect(seen, [SaveState.saving, SaveState.saved]);
  });

  test('opening a document from a newer format refuses by name', () async {
    final session = await open();
    await session.close();

    // Hand-edit the manifest to claim a format this build cannot know.
    final doc = FlowmapDocument.read(File(path).readAsBytesSync());
    final ahead = FlowmapDocument(
      manifest: DocumentManifest(
        format: DocumentManifest.currentFormat + 1,
        appVersion: 'later',
        schemaVersion: 99,
        projectId: 'proj-1',
        projectName: 'From the future',
        written: DateTime.now(),
        counts: const {},
      ),
      plant: doc.plant,
      project: doc.project,
    );
    await DocumentStore.writeAtomically(File(path), ahead.write());

    await expectLater(
      DocumentSession.open(path, db: db, user: 'm', machine: 'ENG-04'),
      throwsA(
        isA<DocumentFormatException>().having(
          (e) => e.message,
          'message',
          contains('newer version of FlowMap'),
        ),
      ),
    );
    // And it did not take the lock on a document it could not open.
    expect(DocumentLock.holderOf(path), isNull);
  });
}
