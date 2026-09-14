import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/documents/data/document_migration.dart';
import 'package:flowmap/src/features/documents/data/flowmap_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// This conversion runs on one machine, once, against data nobody else has a
/// copy of — so the claims are about not losing it and not doing it twice.
void main() {
  late AppDatabase db;
  late Directory dir;
  late DocumentMigration migration;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('flowmap_convert');
    migration = DocumentMigration(db, DatabaseSettingsAccess(db));
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> seedProject(String id, String name, {int created = 0}) async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      "INSERT OR IGNORE INTO plants (id,name,created_at,updated_at) "
      "VALUES ('plant-1','Planta',0,0)",
    );
    await db.customStatement(
      "INSERT OR IGNORE INTO shift_patterns (id,name,cycle_type,"
      "working_weekdays,created_at,updated_at) "
      "VALUES ('sp-1','Fixture','fixedWeekly',62,0,0)",
    );
    await db.customStatement(
      "INSERT INTO projects (id,name,plant_id,shift_pattern_id,float_red_days,"
      "float_green_days,occupation_amber_pct,occupation_red_pct,created_at,"
      "updated_at) VALUES ('$id','$name','plant-1','sp-1',0,30,85,100,"
      "$created,$created)",
    );
    await db.customStatement('PRAGMA foreign_keys = ON');
  }

  test('a project becomes a document named after itself', () async {
    await seedProject('proj-1', 'VSM 2026 Q1');

    final written = await migration.run(dir);

    expect(written, hasLength(1));
    expect(p.basename(written.single.path), 'VSM 2026 Q1.flowmap');
    final doc = FlowmapDocument.read(written.single.readAsBytesSync());
    expect(doc.manifest.projectName, 'VSM 2026 Q1');
    expect(doc.project['projects']!.single['id'], 'proj-1');
  });

  test('nothing is deleted — the database is left exactly as it was', () async {
    // The conversion is one-way and the data is irreplaceable, so it only
    // writes. Clearing the working database is what *opening* a document does,
    // and that happens later and on purpose.
    await seedProject('proj-1', 'VSM 2026 Q1');
    await migration.run(dir);

    final projects = await db.select(db.projects).get();
    expect(projects, hasLength(1));
    expect(projects.single.name, 'VSM 2026 Q1');
  });

  test('every project is converted, not just the first', () async {
    await seedProject('proj-1', 'First', created: 1);
    await seedProject('proj-2', 'Second', created: 2);

    final written = await migration.run(dir);

    expect(written.map((f) => p.basename(f.path)), [
      'First.flowmap',
      'Second.flowmap',
    ]);
  });

  test('it never runs twice', () async {
    // A second pass would overwrite documents that have since been edited,
    // which is the one way this could destroy work rather than preserve it.
    await seedProject('proj-1', 'VSM 2026 Q1');
    expect(await migration.run(dir), hasLength(1));

    await File(p.join(dir.path, 'VSM 2026 Q1.flowmap'))
        .writeAsString('edited since');

    expect(await migration.run(dir), isEmpty);
    expect(
      File(p.join(dir.path, 'VSM 2026 Q1.flowmap')).readAsStringSync(),
      'edited since',
    );
  });

  test('a database with no projects is still marked done', () async {
    // Otherwise the conversion would lie in wait and fire the first time a
    // fresh install created a project — which is the shape of mistake the
    // reference-data seed stamp exists to avoid.
    expect(await migration.run(dir), isEmpty);

    await seedProject('proj-1', 'Made later');
    expect(await migration.run(dir), isEmpty);
    expect(dir.listSync(), isEmpty);
  });

  group('file names', () {
    test('a name Windows would refuse is reduced to one it accepts', () {
      expect(
        DocumentMigration.fileNameFor('Q1/Q2: "final"', dir),
        'Q1-Q2- -final-.flowmap',
      );
      // Project names have been free text since M2, and nothing has ever
      // stopped someone typing a slash.
      expect(DocumentMigration.fileNameFor(r'a\b|c?d*e', dir), 'a-b-c-d-e.flowmap');
    });

    test('a trailing dot or space is trimmed, which Windows also refuses', () {
      expect(DocumentMigration.fileNameFor('Draft. ', dir), 'Draft.flowmap');
    });

    test('a reserved device name is made safe', () {
      // `CON.flowmap` is still CON to Windows, extension or not.
      expect(DocumentMigration.fileNameFor('CON', dir), 'CON-project.flowmap');
      expect(DocumentMigration.fileNameFor('lpt1', dir), 'lpt1-project.flowmap');
    });

    test('an empty name still produces a file', () {
      expect(DocumentMigration.fileNameFor('   ', dir), 'Project.flowmap');
      expect(DocumentMigration.fileNameFor('///', dir), 'Project.flowmap');
    });

    test('a collision takes a suffix rather than overwriting', () {
      File(p.join(dir.path, 'Plan.flowmap')).writeAsStringSync('existing');
      expect(DocumentMigration.fileNameFor('Plan', dir), 'Plan (2).flowmap');

      File(p.join(dir.path, 'Plan (2).flowmap')).writeAsStringSync('also');
      expect(DocumentMigration.fileNameFor('Plan', dir), 'Plan (3).flowmap');
    });

    test('a document already in the folder is never overwritten', () async {
      // `projects.name` is UNIQUE, so two projects cannot share a name and the
      // conversion can never collide with itself. What it can collide with is a
      // file already sitting there — an earlier export, or a document someone
      // put in the folder by hand.
      File(p.join(dir.path, 'VSM 2026 Q1.flowmap')).writeAsStringSync('mine');
      await seedProject('proj-1', 'VSM 2026 Q1');

      final written = await migration.run(dir);

      expect(p.basename(written.single.path), 'VSM 2026 Q1 (2).flowmap');
      expect(
        File(p.join(dir.path, 'VSM 2026 Q1.flowmap')).readAsStringSync(),
        'mine',
      );
    });

    test('a very long name is shortened, not rejected', () {
      final name = DocumentMigration.fileNameFor('x' * 300, dir);
      expect(name.length, lessThan(100));
      expect(name, endsWith('.flowmap'));
    });
  });
}
