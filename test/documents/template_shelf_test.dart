import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/documents/application/templates_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Saving a template puts it on the shelf (field report, 2026-09-13).
///
/// Saving ran inside an auto-disposing provider, which was gone by the time
/// the file was written; refreshing the shelf through it threw, and the saved
/// template never appeared on the Templates screen. These are functions now.
void main() {
  late AppDatabase db;
  late Directory dir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('flowmap_shelf');
    Future<void> run(String sql) => db.customStatement(sql);
    await run('PRAGMA foreign_keys = OFF');
    await run("INSERT INTO plants (id,name,created_at,updated_at) "
        "VALUES ('p1','Plant 1',0,0)");
    await run("INSERT INTO production_cells (id,plant_id,name,created_at,"
        "updated_at) VALUES ('c1','p1','Célula 11',0,0)");
    await run("INSERT INTO production_lines (id,cell_id,name,created_at,"
        "updated_at) VALUES ('l1','c1','Fluxo 11B',0,0)");
    await run("INSERT INTO workcenters (id,plant_id,name,parallel_capacity,"
        "created_at,updated_at) VALUES ('w1','p1','CLAD07',1,0,0)");
    await run("INSERT INTO shift_patterns (id,name,cycle_type,working_weekdays,"
        "created_at,updated_at) VALUES ('sp1','P','fixedWeekly',62,0,0)");
    await run("INSERT INTO projects (id,name,plant_id,shift_pattern_id,"
        "float_red_days,float_green_days,occupation_amber_pct,"
        "occupation_red_pct,created_at,updated_at) "
        "VALUES ('prj1','Plan Q1','p1','sp1',0,30,85,100,0,0)");
    await run("INSERT INTO studies (id,project_id,production_cell_id,"
        "production_line_id,name,include_in_simulation,start_buffer_days,"
        "created_at,updated_at) "
        "VALUES ('s1','prj1','c1','l1','Célula 11B',1,0,0,0)");
    await run("INSERT INTO flow_nodes (id,study_id,position,kind,workcenter_id,"
        "changeover_seconds,inventory_uses_working_time,created_at,updated_at) "
        "VALUES ('n1','s1',0,'step','w1',0,0,0,0)");
    await run('PRAGMA foreign_keys = ON');
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('a saved template is on the shelf', () async {
    final file = await saveStudyAsTemplate(
      db,
      dir,
      studyId: 's1',
      includeDemand: false,
    );

    final shelf = await readTemplateShelf(dir);
    expect(shelf.map((t) => t.file.path), [file.path]);
    expect(shelf.single.manifest.studyName, 'Célula 11B');
  });

  test('saving the same study twice keeps both, and neither is lost', () async {
    await saveStudyAsTemplate(db, dir, studyId: 's1', includeDemand: false);
    await saveStudyAsTemplate(db, dir, studyId: 's1', includeDemand: true);

    expect(await readTemplateShelf(dir), hasLength(2));
  });

  test('applying the same template twice applies it twice', () async {
    final file = await saveStudyAsTemplate(
      db,
      dir,
      studyId: 's1',
      includeDemand: false,
    );

    final first = await applyTemplate(db, projectId: 'prj1', file: file);
    final second = await applyTemplate(db, projectId: 'prj1', file: file);

    expect(first.studyId, isNot(second.studyId));
    expect(await db.select(db.studies).get(), hasLength(3));
  });
}
