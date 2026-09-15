import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/seed_data.dart';
import 'package:flowmap/src/features/documents/data/document_store.dart';
import 'package:flowmap/src/features/documents/data/flowmap_document.dart';
import 'package:flowmap/src/features/documents/data/new_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A new document starts with the reference data and nothing else. A reference
/// *plant* is something the user opens and saves a copy of — content they chose
/// rather than content the app pressed on them.
void main() {
  late AppDatabase db;
  late Directory dir;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('flowmap_new');
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<FlowmapDocument> create({String name = 'Célula 12'}) async {
    final file = await NewDocument(db).create(
      p.join(dir.path, '$name.flowmap'),
      projectName: name,
      plantName: 'Planta',
    );
    return FlowmapDocument.read(file.readAsBytesSync());
  }

  test('it carries the seeded reference data and no plant of its own', () async {
    final doc = await create();

    expect(
      doc.plant['workcenter_types']!.map((r) => r['name']),
      containsAll(workcenterTypeSeeds),
      reason: 'a new document starts where a fresh install starts',
    );
    expect(doc.plant['shift_patterns'], isNotEmpty);
    // And nothing that would be somebody else's plant.
    expect(doc.plant['workcenters'], isEmpty);
    expect(doc.plant['production_cells'], isEmpty);
    expect(doc.plant['production_lines'], isEmpty);
    expect(doc.plant['workcenter_pools'], isEmpty);
  });

  test('one plant exists, because a project cannot be stored without one',
      () async {
    // `projects.plant_id` and `shift_pattern_id` are both NOT NULL, so an
    // entirely empty document could not hold the project it is.
    final doc = await create();

    expect(doc.plant['plants'], hasLength(1));
    expect(doc.plant['plants']!.single['name'], 'Planta');
    expect(doc.project['projects'], hasLength(1));
    expect(doc.project['projects']!.single['name'], 'Célula 12');
  });

  test('it holds one project and no studies', () async {
    final doc = await create();

    expect(doc.project['studies'], isEmpty);
    expect(doc.project['demand_orders'], isEmpty);
    expect(doc.project['flow_nodes'], isEmpty);
    expect(doc.project['project_queues'], isEmpty);
  });

  test('it is a document the ordinary loader can open', () async {
    // There is one load path, so a document created is indistinguishable from
    // a document opened — and only one thing can be wrong with either.
    final doc = await create();
    final store = DocumentStore(db);

    await store.load(doc);

    expect(await store.checkIntegrity(), isEmpty);
    final projects = await db.select(db.projects).get();
    expect(projects.single.name, 'Célula 12');
  });

  test('creating replaces whatever was open', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      "INSERT INTO plants (id,name,created_at,updated_at) "
      "VALUES ('old','Someone else',0,0)",
    );
    await db.customStatement('PRAGMA foreign_keys = ON');

    await create();

    final plants = await db.select(db.plants).get();
    expect(plants.map((row) => row.name), ['Planta']);
  });

  test('the file name suggests the project name, so New asks once', () {
    expect(
      NewDocument.projectNameFor(r'C:\work\Plan Q2.flowmap'),
      'Plan Q2',
    );
    expect(NewDocument.projectNameFor(r'C:\work\.flowmap'), 'Project');
  });

  test('two new documents do not share ids', () async {
    final first = await create(name: 'One');
    final second = await create(name: 'Two');

    expect(
      first.project['projects']!.single['id'],
      isNot(second.project['projects']!.single['id']),
    );
    expect(
      first.plant['plants']!.single['id'],
      isNot(second.plant['plants']!.single['id']),
    );
  });
}
