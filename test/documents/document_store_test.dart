import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/documents/data/document_store.dart';
import 'package:flowmap/src/features/documents/data/flowmap_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Opening a document replaces everything, so the claims here are about what
/// survives and what must not.
void main() {
  late AppDatabase db;
  late DocumentStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DocumentStore(db);
  });
  tearDown(() => db.close());

  Future<void> seedPlant({
    String plant = 'plant-1',
    String workcenter = 'CLAD07',
    String project = 'proj-1',
    String projectName = 'Plan Q1',
  }) async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    Future<void> run(String sql) => db.customStatement(sql);
    await run("INSERT INTO plants (id,name,created_at,updated_at) "
        "VALUES ('$plant','Planta',0,0)");
    await run("INSERT INTO workcenter_types (id,name,is_built_in,created_at) "
        "VALUES ('type-$plant','Type $plant',0,0)");
    await run("INSERT INTO workcenters (id,plant_id,type_id,name,parallel_capacity,"
        "created_at,updated_at) "
        "VALUES ('wc-$plant','$plant','type-$plant','$workcenter',1,0,0)");
    await run("INSERT INTO shift_patterns (id,name,cycle_type,working_weekdays,"
        "created_at,updated_at) VALUES ('sp-$plant','Pattern $plant','fixedWeekly',62,0,0)");
    await run("INSERT INTO projects (id,name,plant_id,shift_pattern_id,float_red_days,"
        "float_green_days,occupation_amber_pct,occupation_red_pct,created_at,updated_at) "
        "VALUES ('$project','$projectName','$plant','sp-$plant',0,30,85,100,0,0)");
    await db.customStatement('PRAGMA foreign_keys = ON');
  }

  test('loading a document replaces the plant rather than merging it', () async {
    // The reason the working database holds one document at a time:
    // `workcenter_types.name` and `shift_patterns.name` are unique, and
    // `seedReferenceData` installs built-ins on every machine. A merge would
    // collide by name on every open.
    await seedPlant();
    final incoming = await store.capture(
      projectId: 'proj-1',
      projectName: 'Plan Q1',
    );

    // A different plant is now in the database — the state a second document
    // would find.
    await db.customStatement('DELETE FROM projects');
    await db.customStatement('DELETE FROM workcenters');
    await db.customStatement('DELETE FROM plants');
    await seedPlant(
      plant: 'plant-2',
      workcenter: 'BAN10',
      project: 'proj-2',
      projectName: 'Other',
    );

    await store.load(incoming);

    final workcenters = await db.select(db.workcenters).get();
    expect(workcenters, hasLength(1));
    expect(workcenters.single.name, 'CLAD07');
    final projects = await db.select(db.projects).get();
    expect(projects, hasLength(1));
    expect(projects.single.id, 'proj-1');
    // What is in the database is what is in the file, and nothing else — down
    // to the workcenter types. The document carries the built-ins too, because
    // it carries the whole plant; what it must not do is leave plant-2's type
    // behind beside them.
    final types = await db.select(db.workcenterTypes).get();
    expect(
      types.map((t) => t.name).toSet(),
      {for (final row in incoming.plant['workcenter_types']!) row['name']},
    );
    expect(types.map((t) => t.name), isNot(contains('Type plant-2')));
  });

  test('a loaded document leaves nothing dangling', () async {
    await seedPlant();
    final doc = await store.capture(projectId: 'proj-1', projectName: 'X');
    await store.load(doc);
    expect(await store.checkIntegrity(), isEmpty);
  });

  test('stored runs survive the swap', () async {
    // The whole reason v32 exists. Before it, `simulation_runs` cascaded from
    // `projects`, and this delete would have taken every run.
    await seedPlant();
    await db.customStatement(
      "INSERT INTO simulation_runs (id,document_id,dispatch,run_start,run_end,"
      "guard,created_at) VALUES ('run-1','proj-1','',0,0,0,0)",
    );
    await db.customStatement(
      "INSERT INTO simulation_run_steps (run_id,study_id,order_id,node_id,"
      "workcenter_id,queue_start,process_start,process_end) "
      "VALUES ('run-1','s','o','n','wc',0,0,0)",
    );
    final doc = await store.capture(projectId: 'proj-1', projectName: 'X');

    await store.load(doc);

    expect(await db.select(db.simulationRuns).get(), hasLength(1));
    expect(await db.select(db.simulationRunSteps).get(), hasLength(1));
  });

  test('a round trip through the database changes nothing', () async {
    await seedPlant();
    final before = await store.capture(projectId: 'proj-1', projectName: 'X');
    await store.load(before);
    final after = await store.capture(projectId: 'proj-1', projectName: 'X');

    expect(after.rowCount, before.rowCount);
    expect(after.plant['workcenters'], before.plant['workcenters']);
    expect(after.project['projects'], before.project['projects']);
  });

  test('a document carrying an unknown column is refused, not truncated',
      () async {
    await seedPlant();
    final doc = await store.capture(projectId: 'proj-1', projectName: 'X');
    doc.plant['workcenters']!.first['invented_by_a_later_build'] = 'x';

    await expectLater(
      store.load(doc),
      throwsA(
        isA<DocumentFormatException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('invented_by_a_later_build'),
            contains('newer FlowMap'),
          ),
        ),
      ),
    );
  });

  test('foreign keys are enforced again after a load', () async {
    await seedPlant();
    final doc = await store.capture(projectId: 'proj-1', projectName: 'X');
    await store.load(doc);

    // Off during the swap, on afterwards — otherwise every later write would
    // run unguarded and the guarantee would quietly be gone.
    final pragma = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(pragma.data.values.first, 1);
  });

  group('writeAtomically', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('flowmap_doc'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('writes the bytes and leaves no temporary behind', () async {
      final file = File(p.join(dir.path, 'doc.flowmap'));
      await DocumentStore.writeAtomically(
        file,
        Uint8List.fromList([1, 2, 3, 4]),
      );

      expect(file.readAsBytesSync(), [1, 2, 3, 4]);
      expect(
        dir.listSync().map((e) => p.basename(e.path)),
        ['doc.flowmap'],
        reason: 'a leftover .saving file is a half-written document to anyone '
            'reading the folder',
      );
    });

    test('a rewrite replaces the whole file, never appends', () async {
      final file = File(p.join(dir.path, 'doc.flowmap'));
      await DocumentStore.writeAtomically(
        file,
        Uint8List.fromList(List.filled(64, 9)),
      );
      await DocumentStore.writeAtomically(file, Uint8List.fromList([7]));

      // The short write must not leave the tail of the long one behind, which
      // is exactly what an in-place write would do.
      expect(file.readAsBytesSync(), [7]);
    });
  });
}
