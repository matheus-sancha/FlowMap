import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/projects/data/plant_move.dart';
import 'package:flutter_test/flutter_test.dart';

/// Moving a project to another plant of its document (phase 8).
///
/// **Nothing is orphaned.** Every project column that names a plant row is
/// re-pointed at the row of the same name on the other plant, and a row that
/// is not there is made from the one it replaces.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    Future<void> run(String sql) => db.customStatement(sql);
    await run('PRAGMA foreign_keys = OFF');

    // --- plant 4001, which the project uses ---------------------------------
    await run("INSERT INTO plants (id,name,created_at,updated_at) "
        "VALUES ('p1','4001',0,0)");
    await run("INSERT INTO production_cells (id,plant_id,name,created_at,"
        "updated_at) VALUES ('c1','p1','Célula 11',0,0)");
    await run("INSERT INTO production_lines (id,cell_id,name,created_at,"
        "updated_at) VALUES ('l1','c1','Fluxo 11B',0,0)");
    await run("INSERT INTO production_lines (id,cell_id,name,created_at,"
        "updated_at) VALUES ('l1t','c1','Fluxo 11C',0,0)");
    await run("INSERT INTO workcenter_types (id,name,is_built_in,created_at) "
        "VALUES ('t1','Cladding X',0,0)");
    await run("INSERT INTO workcenters (id,plant_id,type_id,name,"
        "parallel_capacity,created_at,updated_at) "
        "VALUES ('w1','p1','t1','CLAD07',1,0,0)");
    await run("INSERT INTO workcenters (id,plant_id,type_id,name,"
        "parallel_capacity,created_at,updated_at) "
        "VALUES ('w2','p1','t1','CLAD08',3,0,0)");
    await run("INSERT INTO workcenters (id,plant_id,type_id,name,"
        "parallel_capacity,created_at,updated_at) "
        "VALUES ('w3','p1','t1','FORN02',1,0,0)");
    await run("INSERT INTO workcenter_lines (workcenter_id,line_id,created_at) "
        "VALUES ('w2','l1',0)");
    await run("INSERT INTO workcenter_pools (id,plant_id,name,created_at,"
        "updated_at) VALUES ('pool1','p1','CLAD Pool',0,0)");
    await run("INSERT INTO workcenter_pool_members (pool_id,workcenter_id,"
        "created_at) VALUES ('pool1','w1',0)");
    await run("INSERT INTO workcenter_pool_members (pool_id,workcenter_id,"
        "created_at) VALUES ('pool1','w2',0)");

    // --- plant 4002, which has some of the same names ------------------------
    await run("INSERT INTO plants (id,name,created_at,updated_at) "
        "VALUES ('p2','4002',0,0)");
    await run("INSERT INTO production_cells (id,plant_id,name,created_at,"
        "updated_at) VALUES ('c2','p2','Célula 11',0,0)");
    await run("INSERT INTO workcenters (id,plant_id,type_id,name,"
        "parallel_capacity,created_at,updated_at) "
        "VALUES ('x1','p2','t1','CLAD07',1,0,0)");

    // --- the project, pointing at 4001 in every way it can ------------------
    await run("INSERT INTO shift_patterns (id,name,cycle_type,working_weekdays,"
        "created_at,updated_at) VALUES ('sp1','P','fixedWeekly',62,0,0)");
    await run("INSERT INTO projects (id,name,plant_id,shift_pattern_id,"
        "float_red_days,float_green_days,occupation_amber_pct,"
        "occupation_red_pct,created_at,updated_at) "
        "VALUES ('prj1','VSM 2026 Q1','p1','sp1',0,30,85,100,0,0)");
    await run("INSERT INTO studies (id,project_id,production_cell_id,"
        "production_line_id,name,include_in_simulation,start_buffer_days,"
        "pace_setter_target_id,created_at,updated_at) "
        "VALUES ('s1','prj1','c1','l1','Célula 11B',1,0,'pool1',0,0)");
    await run("INSERT INTO flow_nodes (id,study_id,position,kind,workcenter_id,"
        "changeover_seconds,inventory_uses_working_time,created_at,updated_at) "
        "VALUES ('n1','s1',0,'step','w1',0,0,0,0)");
    await run("INSERT INTO flow_nodes (id,study_id,position,kind,pool_id,"
        "changeover_seconds,inventory_uses_working_time,created_at,updated_at) "
        "VALUES ('n2','s1',1,'step','pool1',0,0,0,0)");
    await run("INSERT INTO project_queues (project_id,target_id,rule,created_at,"
        "updated_at) VALUES ('prj1','w1','lifo',0,0)");
    await run("INSERT INTO workcenter_schedule_periods (id,project_id,"
        "workcenter_id,start_date,end_date,operators_per_shift,created_at,"
        "updated_at) VALUES ('wsp1','prj1','w3',0,0,'1/1/1',0,0)");
    await run("INSERT INTO takt_periods (id,project_id,production_line_id,"
        "start_date,end_date,takt_value,takt_unit,created_at,updated_at) "
        "VALUES ('tk1','prj1','l1t',0,0,1,'days',0,0)");
    await run("INSERT INTO calendar_exceptions (id,project_id,date,kind,scope,"
        "scope_id,created_at) "
        "VALUES ('ce1','prj1',0,'nonWorking','workcenter','w3',0)");
    await run('PRAGMA foreign_keys = ON');
  });

  tearDown(() => db.close());

  Future<String?> one(String sql) async {
    final row = await db.customSelect(sql).getSingleOrNull();
    return row?.data.values.first as String?;
  }

  Future<String> plantOfWorkcenter(String? id) async =>
      (await one("SELECT plant_id FROM workcenters WHERE id = '$id'"))!;

  test('what is on the other plant is matched by name', () async {
    final report = await PlantMove(db).apply(
      projectId: 'prj1',
      toPlantId: 'p2',
    );

    expect(report.matched, containsAll(['CLAD07', 'Célula 11']));
    expect(await one("SELECT workcenter_id FROM flow_nodes WHERE id = 'n1'"),
        'x1', reason: 'the CLAD07 already on 4002, not a copy of it');
    expect(await one("SELECT production_cell_id FROM studies"), 'c2');
    expect(await one("SELECT plant_id FROM projects"), 'p2');
  });

  test('what is missing is made from the row it replaces', () async {
    final report = await PlantMove(db).apply(
      projectId: 'prj1',
      toPlantId: 'p2',
    );

    expect(report.created,
        containsAll(['CLAD08', 'FORN02', 'CLAD Pool', 'Fluxo 11B', 'Fluxo 11C']));
    final clad08 = await db
        .customSelect("SELECT * FROM workcenters WHERE name = 'CLAD08' "
            "AND plant_id = 'p2'")
        .getSingle();
    expect(clad08.data['parallel_capacity'], 3,
        reason: 'a copy, not a stub with a capacity of one');
    expect(clad08.data['type_id'], 't1');

    // The pool over its members on 4002, never a subset (#23).
    final poolId = await one("SELECT pool_id FROM flow_nodes WHERE id = 'n2'");
    final members = await db
        .customSelect("SELECT w.plant_id, w.name FROM workcenter_pool_members m "
            "JOIN workcenters w ON w.id = m.workcenter_id "
            "WHERE m.pool_id = '$poolId'")
        .get();
    expect(members.map((r) => r.data['name']), unorderedEquals(['CLAD07', 'CLAD08']));
    expect(members.map((r) => r.data['plant_id']), everyElement('p2'));

    // A line lands under the cell its old one sat in.
    final lineId = await one("SELECT production_line_id FROM studies");
    expect(await one("SELECT cell_id FROM production_lines WHERE id = '$lineId'"),
        'c2');
    // And a made workcenter is filed under the lines its original was.
    expect(
      await one("SELECT line_id FROM workcenter_lines "
          "WHERE workcenter_id = '${clad08.data['id']}'"),
      lineId,
    );
  });

  test('every reference to the old plant is re-pointed', () async {
    await PlantMove(db).apply(projectId: 'prj1', toPlantId: 'p2');

    expect(await plantOfWorkcenter(
        await one("SELECT target_id FROM project_queues")), 'p2');
    expect(await plantOfWorkcenter(await one(
        "SELECT workcenter_id FROM workcenter_schedule_periods")), 'p2');
    expect(await plantOfWorkcenter(
        await one("SELECT scope_id FROM calendar_exceptions")), 'p2');
    final takt = await one("SELECT production_line_id FROM takt_periods");
    expect(await one("SELECT c.plant_id FROM production_lines l JOIN "
        "production_cells c ON c.id = l.cell_id WHERE l.id = '$takt'"), 'p2');
    final pace = await one("SELECT pace_setter_target_id FROM studies");
    expect(await one("SELECT plant_id FROM workcenter_pools WHERE id = '$pace'"),
        'p2');
  });

  test('nothing in the project still names the old plant', () async {
    await PlantMove(db).apply(projectId: 'prj1', toPlantId: 'p2');

    final old = await db.customSelect('''
      SELECT id FROM workcenters WHERE plant_id = 'p1'
      UNION SELECT id FROM workcenter_pools WHERE plant_id = 'p1'
      UNION SELECT id FROM production_cells WHERE plant_id = 'p1'
      UNION SELECT l.id FROM production_lines l
        JOIN production_cells c ON c.id = l.cell_id WHERE c.plant_id = 'p1'
    ''').get();
    final oldIds = {for (final r in old) r.data['id']};

    final used = await db.customSelect('''
      SELECT production_cell_id AS v FROM studies
      UNION ALL SELECT production_line_id FROM studies
      UNION ALL SELECT pace_setter_target_id FROM studies
      UNION ALL SELECT workcenter_id FROM flow_nodes
      UNION ALL SELECT pool_id FROM flow_nodes
      UNION ALL SELECT target_id FROM project_queues
      UNION ALL SELECT workcenter_id FROM workcenter_schedule_periods
      UNION ALL SELECT production_line_id FROM takt_periods
      UNION ALL SELECT scope_id FROM calendar_exceptions
    ''').get();
    expect(used.map((r) => r.data['v']).where(oldIds.contains), isEmpty);

    final dangling =
        await db.customSelect('PRAGMA foreign_key_check').get();
    expect(dangling, isEmpty);
  });

  test('the old plant is left as it was', () async {
    await PlantMove(db).apply(projectId: 'prj1', toPlantId: 'p2');

    expect(await one("SELECT name FROM plants WHERE id = 'p1'"), '4001');
    final left = await db
        .customSelect("SELECT COUNT(*) AS n FROM workcenters WHERE plant_id = 'p1'")
        .getSingle();
    expect(left.data['n'], 3);
  });

  test('moving back finds everything and makes nothing', () async {
    await PlantMove(db).apply(projectId: 'prj1', toPlantId: 'p2');
    final back = await PlantMove(db).apply(projectId: 'prj1', toPlantId: 'p1');

    expect(back.created, isEmpty);
    expect(await one("SELECT workcenter_id FROM flow_nodes WHERE id = 'n1'"),
        'w1');
    expect(await one("SELECT pool_id FROM flow_nodes WHERE id = 'n2'"), 'pool1');
    expect(await one("SELECT production_line_id FROM studies"), 'l1');
    expect(await one("SELECT scope_id FROM calendar_exceptions"), 'w3');
  });

  test('a preview says the same and writes nothing', () async {
    final seen = <String>{};
    final sub = db.tableUpdates().listen((u) => seen.addAll(u.map((t) => t.table)));
    addTearDown(sub.cancel);

    final preview = await PlantMove(db).preview(
      projectId: 'prj1',
      toPlantId: 'p2',
    );
    await pumpEventQueue();

    expect(seen, isEmpty);
    expect(await one("SELECT plant_id FROM projects"), 'p1');
    expect(preview.studies, 1);

    final applied = await PlantMove(db).apply(
      projectId: 'prj1',
      toPlantId: 'p2',
    );
    expect(preview.matched, applied.matched);
    expect(preview.created, applied.created);
  });

  test('a move to a new plant makes the plant and everything on it', () async {
    final preview = await PlantMove(db).preview(
      projectId: 'prj1',
      newPlantName: '4003',
    );
    expect(preview.matched, isEmpty);

    final report = await PlantMove(db).apply(
      projectId: 'prj1',
      newPlantName: '4003',
    );

    final plantId = await one("SELECT plant_id FROM projects");
    expect(await one("SELECT name FROM plants WHERE id = '$plantId'"), '4003');
    expect(report.created, containsAll(['CLAD07', 'CLAD08', 'Célula 11']));
    expect(await plantOfWorkcenter(
        await one("SELECT workcenter_id FROM flow_nodes WHERE id = 'n1'")),
        plantId);
  });

  test('the move is seen by the autosave', () async {
    final seen = <String>{};
    final sub = db.tableUpdates().listen((u) => seen.addAll(u.map((t) => t.table)));
    addTearDown(sub.cancel);

    await PlantMove(db).apply(projectId: 'prj1', toPlantId: 'p2');
    await pumpEventQueue();

    expect(seen, containsAll(['projects', 'studies', 'flow_nodes', 'workcenters']));
  });
}
