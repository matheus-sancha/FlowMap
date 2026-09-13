import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/documents/data/flow_template.dart';
import 'package:flowmap/src/features/documents/data/template_binding.dart';
import 'package:flutter_test/flutter_test.dart';

/// A template is a flow landing on a plant that is not its own — the case #23
/// was written for, and the one thing Save As cannot do.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> run(String sql) => db.customStatement(sql);

  /// The plant a template is *saved from*.
  Future<FlowTemplate> sourceTemplate({bool withPool = false}) async {
    await run('PRAGMA foreign_keys = OFF');
    await run("INSERT INTO plants (id,name,created_at,updated_at) "
        "VALUES ('p1','Planta A',0,0)");
    await run("INSERT INTO production_cells (id,plant_id,name,created_at,updated_at) "
        "VALUES ('c1','p1','Célula 11',0,0)");
    await run("INSERT INTO production_lines (id,cell_id,name,created_at,updated_at) "
        "VALUES ('l1','c1','Fluxo 11B',0,0)");
    await run("INSERT INTO workcenter_types (id,name,is_built_in,created_at) "
        "VALUES ('t1','Cladding X',0,0)");
    await run("INSERT INTO workcenters (id,plant_id,type_id,name,parallel_capacity,"
        "created_at,updated_at) VALUES ('w1','p1','t1','CLAD07',1,0,0)");
    await run("INSERT INTO workcenters (id,plant_id,type_id,name,parallel_capacity,"
        "created_at,updated_at) VALUES ('w2','p1','t1','CLAD08',1,0,0)");
    if (withPool) {
      await run("INSERT INTO workcenter_pools (id,plant_id,name,created_at,updated_at) "
          "VALUES ('pool1','p1','CLAD Pool',0,0)");
      await run("INSERT INTO workcenter_pool_members (pool_id,workcenter_id,created_at) "
          "VALUES ('pool1','w1',0)");
      await run("INSERT INTO workcenter_pool_members (pool_id,workcenter_id,created_at) "
          "VALUES ('pool1','w2',0)");
    }
    await run("INSERT INTO shift_patterns (id,name,cycle_type,working_weekdays,"
        "created_at,updated_at) VALUES ('sp1','P','fixedWeekly',62,0,0)");
    await run("INSERT INTO projects (id,name,plant_id,shift_pattern_id,float_red_days,"
        "float_green_days,occupation_amber_pct,occupation_red_pct,created_at,updated_at) "
        "VALUES ('prj1','Source','p1','sp1',0,30,85,100,0,0)");
    await run("INSERT INTO studies (id,project_id,production_cell_id,production_line_id,"
        "name,include_in_simulation,start_buffer_days,pace_setter_target_id,"
        "created_at,updated_at) "
        "VALUES ('s1','prj1','c1','l1','Célula 11B',1,0,'w1',0,0)");
    await run("INSERT INTO flow_nodes (id,study_id,position,kind,workcenter_id,"
        "changeover_seconds,inventory_uses_working_time,created_at,updated_at) "
        "VALUES ('n1','s1',0,'step','w1',1800,0,0,0)");
    if (withPool) {
      await run("INSERT INTO flow_nodes (id,study_id,position,kind,pool_id,"
          "changeover_seconds,inventory_uses_working_time,created_at,updated_at) "
          "VALUES ('n2','s1',1,'step','pool1',0,0,0,0)");
    }
    await run('PRAGMA foreign_keys = ON');

    return FlowTemplate.fromDatabase(db, studyId: 's1', includeDemand: false);
  }

  /// A different plant, in a different database, for the template to land on.
  Future<AppDatabase> destination({
    List<String> workcenters = const [],
    List<String> types = const [],
  }) async {
    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await other.customStatement('PRAGMA foreign_keys = OFF');
    await other.customStatement("INSERT INTO plants (id,name,created_at,updated_at) "
        "VALUES ('p2','Planta B',0,0)");
    await other.customStatement("INSERT INTO shift_patterns (id,name,cycle_type,"
        "working_weekdays,created_at,updated_at) VALUES ('sp2','P','fixedWeekly',62,0,0)");
    await other.customStatement("INSERT INTO projects (id,name,plant_id,shift_pattern_id,"
        "float_red_days,float_green_days,occupation_amber_pct,occupation_red_pct,"
        "created_at,updated_at) VALUES ('prj2','Dest','p2','sp2',0,30,85,100,0,0)");
    for (final (i, name) in types.indexed) {
      await other.customStatement("INSERT INTO workcenter_types (id,name,is_built_in,"
          "created_at) VALUES ('dt$i','$name',0,0)");
    }
    for (final (i, name) in workcenters.indexed) {
      await other.customStatement("INSERT INTO workcenters (id,plant_id,name,"
          "parallel_capacity,created_at,updated_at) "
          "VALUES ('dw$i','p2','$name',1,0,0)");
    }
    await other.customStatement('PRAGMA foreign_keys = ON');
    return other;
  }

  test('a target already on the plant is matched by name', () async {
    final template = await sourceTemplate();
    final other = await destination(workcenters: ['CLAD07']);

    final result = await TemplateBinding(other)
        .apply(template, projectId: 'prj2', plantId: 'p2');

    expect(result.matched, contains('CLAD07'));
    expect(result.created, isNot(contains('CLAD07')));
    // The step points at the workcenter that was already here, not a copy.
    final nodes = await other.select(other.flowNodes).get();
    expect(nodes.single.workcenterId, 'dw0');
  });

  test('a target that is not here is created, with its type', () async {
    final template = await sourceTemplate();
    final other = await destination();

    final result = await TemplateBinding(other)
        .apply(template, projectId: 'prj2', plantId: 'p2');

    expect(result.created, contains('CLAD07'));
    final workcenters = await other.select(other.workcenters).get();
    final made = workcenters.firstWhere((w) => w.name == 'CLAD07');
    final types = await other.select(other.workcenterTypes).get();
    expect(
      types.firstWhere((t) => t.id == made.typeId).name,
      'Cladding X',
      reason: 'a created workcenter arrives with the type it had',
    );
  });

  test('a pool is created over its members, never a subset', () async {
    // #23: a pool of three landing as a pool of one changes dispatch without
    // saying so. One member already exists here; the other must be made.
    final template = await sourceTemplate(withPool: true);
    final other = await destination(workcenters: ['CLAD07']);

    await TemplateBinding(other)
        .apply(template, projectId: 'prj2', plantId: 'p2');

    final pools = await other.select(other.workcenterPools).get();
    expect(pools.single.name, 'CLAD Pool');
    final members = await other.select(other.workcenterPoolMembers).get();
    expect(members, hasLength(2));
  });

  test('the study lands where it says it is', () async {
    // A study is written `name (cell · line)` and is neither (#29), so both
    // have to bind or the applied study cannot say where it sits.
    final template = await sourceTemplate();
    final other = await destination();

    final result = await TemplateBinding(other)
        .apply(template, projectId: 'prj2', plantId: 'p2');

    final study = (await other.select(other.studies).get()).single;
    expect(study.id, result.studyId);
    expect(study.projectId, 'prj2');
    final cells = await other.select(other.productionCells).get();
    final lines = await other.select(other.productionLines).get();
    expect(cells.single.name, 'Célula 11');
    expect(lines.single.name, 'Fluxo 11B');
    expect(study.productionCellId, cells.single.id);
    expect(study.productionLineId, lines.single.id);
  });

  test('the pace setter binds too', () async {
    // The third reference on the study's own row, which #23 did not name.
    final template = await sourceTemplate();
    final other = await destination(workcenters: ['CLAD07']);

    await TemplateBinding(other)
        .apply(template, projectId: 'prj2', plantId: 'p2');

    final study = (await other.select(other.studies).get()).single;
    expect(study.paceSetterTargetId, 'dw0');
  });

  test('the applied study is never included in a run', () async {
    // Two flagged studies on one production line is the state
    // `setIncludedInSimulation` forbids, and an applied template is the second.
    final template = await sourceTemplate();
    final other = await destination();

    await TemplateBinding(other)
        .apply(template, projectId: 'prj2', plantId: 'p2');

    expect(
      (await other.select(other.studies).get()).single.includeInSimulation,
      isFalse,
    );
  });

  test('nothing dangles after applying', () async {
    final template = await sourceTemplate(withPool: true);
    final other = await destination();

    await TemplateBinding(other)
        .apply(template, projectId: 'prj2', plantId: 'p2');

    final check = await other.customSelect('PRAGMA foreign_key_check').get();
    expect(check, isEmpty);
  });

  test('applying twice makes two studies and one plant', () async {
    // The second apply matches everything the first created, so the plant does
    // not double.
    final template = await sourceTemplate();
    final other = await destination();
    final binding = TemplateBinding(other);

    await binding.apply(template, projectId: 'prj2', plantId: 'p2');
    final second = await binding.apply(
      template,
      projectId: 'prj2',
      plantId: 'p2',
    );

    expect(await other.select(other.studies).get(), hasLength(2));
    expect(await other.select(other.workcenters).get(), hasLength(1));
    expect(second.matched, contains('CLAD07'));
    expect(second.created, isEmpty);
    // `studies` is unique on (project, name), so the second one is renamed
    // rather than refused.
    final names = (await other.select(other.studies).get()).map((s) => s.name);
    expect(names, containsAll(['Célula 11B', 'Célula 11B (2)']));
    expect(second.studyName, 'Célula 11B (2)');
  });

  test('a queue setting never travels', () async {
    // Queues are project-scoped and 6 of 15 are shared between studies on the
    // live plant, so a template carrying them would rewrite discipline for
    // studies nobody applied anything to (#23).
    final template = await sourceTemplate();
    await run("INSERT INTO project_queues (project_id,target_id,rule,created_at,"
        "updated_at) VALUES ('prj1','w1','lifo',0,0)");
    final other = await destination();

    await TemplateBinding(other)
        .apply(template, projectId: 'prj2', plantId: 'p2');

    expect(await other.select(other.projectQueues).get(), isEmpty);
    expect(template.study.keys, isNot(contains('project_queues')));
  });
}
