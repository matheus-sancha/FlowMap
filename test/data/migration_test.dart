import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Migrations are tested against fixtures built in the **old** shape, not
/// against the current schema (DATA.md).
///
/// A migration exercised only against today's tables tests nothing: the shape
/// it has to survive is the one that will never exist in development again.
/// One fixture per version that has been on someone's machine — v1 and v2 both
/// ran on the developer's PC, so both count.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('flowmap_migration'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// The tables v1 and v2 share. `workcenters.code` is present here and is
  /// dropped by the v3 step — the whole point of these fixtures.
  const resourceTables = '''
    CREATE TABLE shift_patterns (
      id TEXT NOT NULL, name TEXT NOT NULL UNIQUE, cycle_type TEXT NOT NULL,
      working_weekdays INTEGER NOT NULL, notes TEXT NULL,
      archived_at INTEGER NULL, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL, PRIMARY KEY (id));
    CREATE TABLE pattern_shifts (
      id TEXT NOT NULL,
      pattern_id TEXT NOT NULL REFERENCES shift_patterns (id) ON DELETE CASCADE,
      label TEXT NOT NULL, position INTEGER NOT NULL,
      start_minute INTEGER NOT NULL, end_minute INTEGER NOT NULL,
      break_seconds INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (id),
      UNIQUE (pattern_id, label), UNIQUE (pattern_id, position));
    CREATE TABLE plants (
      id TEXT NOT NULL, name TEXT NOT NULL UNIQUE, code TEXT NULL,
      notes TEXT NULL, archived_at INTEGER NULL, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL, PRIMARY KEY (id));
    CREATE TABLE production_cells (
      id TEXT NOT NULL,
      plant_id TEXT NOT NULL REFERENCES plants (id) ON DELETE CASCADE,
      name TEXT NOT NULL, notes TEXT NULL, archived_at INTEGER NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      PRIMARY KEY (id), UNIQUE (plant_id, name));
    CREATE TABLE production_lines (
      id TEXT NOT NULL,
      cell_id TEXT NOT NULL REFERENCES production_cells (id) ON DELETE CASCADE,
      name TEXT NOT NULL, notes TEXT NULL, archived_at INTEGER NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      PRIMARY KEY (id), UNIQUE (cell_id, name));
    CREATE TABLE workcenter_types (
      id TEXT NOT NULL, name TEXT NOT NULL UNIQUE,
      is_built_in INTEGER NOT NULL DEFAULT 0 CHECK (is_built_in IN (0, 1)),
      archived_at INTEGER NULL, created_at INTEGER NOT NULL,
      PRIMARY KEY (id));
    CREATE TABLE workcenters (
      id TEXT NOT NULL,
      plant_id TEXT NOT NULL REFERENCES plants (id) ON DELETE CASCADE,
      home_line_id TEXT NULL REFERENCES production_lines (id) ON DELETE SET NULL,
      type_id TEXT NULL REFERENCES workcenter_types (id) ON DELETE SET NULL,
      name TEXT NOT NULL, code TEXT NULL, notes TEXT NULL,
      archived_at INTEGER NULL, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL, PRIMARY KEY (id), UNIQUE (plant_id, name));
    CREATE TABLE workcenter_pools (
      id TEXT NOT NULL,
      plant_id TEXT NOT NULL REFERENCES plants (id) ON DELETE CASCADE,
      name TEXT NOT NULL, notes TEXT NULL, archived_at INTEGER NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      PRIMARY KEY (id), UNIQUE (plant_id, name));
    CREATE TABLE workcenter_pool_members (
      pool_id TEXT NOT NULL REFERENCES workcenter_pools (id) ON DELETE CASCADE,
      workcenter_id TEXT NOT NULL REFERENCES workcenters (id) ON DELETE CASCADE,
      created_at INTEGER NOT NULL, PRIMARY KEY (pool_id, workcenter_id));
    CREATE TABLE app_settings (
      key TEXT NOT NULL, value TEXT NULL, updated_at INTEGER NOT NULL,
      PRIMARY KEY (key));
  ''';

  /// The tables v2 added on top.
  const projectTables = '''
    CREATE TABLE projects (
      id TEXT NOT NULL, name TEXT NOT NULL UNIQUE,
      plant_id TEXT NOT NULL REFERENCES plants (id),
      shift_pattern_id TEXT NOT NULL REFERENCES shift_patterns (id),
      notes TEXT NULL, archived_at INTEGER NULL, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL, PRIMARY KEY (id));
    CREATE TABLE calendar_exceptions (
      id TEXT NOT NULL,
      project_id TEXT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
      date INTEGER NOT NULL, kind TEXT NOT NULL, scope TEXT NOT NULL,
      scope_id TEXT NOT NULL DEFAULT '', operators_per_shift TEXT NULL,
      note TEXT NULL, created_at INTEGER NOT NULL, PRIMARY KEY (id),
      UNIQUE (project_id, date, scope, scope_id));
    CREATE TABLE takt_periods (
      id TEXT NOT NULL,
      project_id TEXT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
      production_line_id TEXT NOT NULL REFERENCES production_lines (id) ON DELETE CASCADE,
      start_date INTEGER NOT NULL, end_date INTEGER NOT NULL,
      takt_value REAL NOT NULL, takt_unit TEXT NOT NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      PRIMARY KEY (id), UNIQUE (project_id, production_line_id, start_date));
    CREATE TABLE workcenter_schedule_periods (
      id TEXT NOT NULL,
      project_id TEXT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
      workcenter_id TEXT NOT NULL REFERENCES workcenters (id) ON DELETE CASCADE,
      start_date INTEGER NOT NULL, end_date INTEGER NOT NULL,
      operators_per_shift TEXT NOT NULL,
      availability REAL NOT NULL DEFAULT 1.0, rework REAL NOT NULL DEFAULT 0.0,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      PRIMARY KEY (id), UNIQUE (project_id, workcenter_id, start_date));
    CREATE TABLE studies (
      id TEXT NOT NULL,
      project_id TEXT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
      production_cell_id TEXT NOT NULL REFERENCES production_cells (id) ON DELETE CASCADE,
      production_line_id TEXT NOT NULL REFERENCES production_lines (id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      include_in_simulation INTEGER NOT NULL DEFAULT 0 CHECK (include_in_simulation IN (0, 1)),
      priority INTEGER NOT NULL DEFAULT 100, wip_cap INTEGER NULL,
      supplier_name TEXT NULL, customer_name TEXT NULL, notes TEXT NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      PRIMARY KEY (id), UNIQUE (project_id, name));
    CREATE TABLE flow_nodes (
      id TEXT NOT NULL,
      study_id TEXT NOT NULL REFERENCES studies (id) ON DELETE CASCADE,
      position INTEGER NOT NULL, kind TEXT NOT NULL,
      workcenter_id TEXT NULL REFERENCES workcenters (id) ON DELETE SET NULL,
      pool_id TEXT NULL REFERENCES workcenter_pools (id) ON DELETE SET NULL,
      changeover_seconds INTEGER NOT NULL DEFAULT 0,
      inventory_mode TEXT NULL, inventory_quantity INTEGER NULL,
      inventory_seconds INTEGER NULL,
      inventory_uses_working_time INTEGER NOT NULL DEFAULT 0 CHECK (inventory_uses_working_time IN (0, 1)),
      label TEXT NULL, notes TEXT NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      PRIMARY KEY (id), UNIQUE (study_id, position));
    CREATE TABLE flow_annotations (
      id TEXT NOT NULL,
      study_id TEXT NOT NULL REFERENCES studies (id) ON DELETE CASCADE,
      symbol TEXT NOT NULL, x REAL NOT NULL, y REAL NOT NULL,
      caption TEXT NULL, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL, PRIMARY KEY (id));
  ''';

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// Seeds the rows every fixture carries, in the old shape.
  void insertResourceRows(Database db) {
    db
      ..execute(
        'INSERT INTO plants (id, name, code, created_at, updated_at) '
        "VALUES ('plant-1', 'Werk Nord', 'WN', $now, $now)",
      )
      ..execute(
        'INSERT INTO shift_patterns '
        '(id, name, cycle_type, working_weekdays, created_at, updated_at) '
        "VALUES ('pattern-1', 'ABC', 'fixedWeekly', 31, $now, $now)",
      )
      ..execute(
        'INSERT INTO production_cells (id, plant_id, name, created_at, updated_at) '
        "VALUES ('cell-1', 'plant-1', 'Cell A', $now, $now)",
      )
      ..execute(
        'INSERT INTO production_lines (id, cell_id, name, created_at, updated_at) '
        "VALUES ('line-1', 'cell-1', 'Line 1', $now, $now)",
      )
      ..execute(
        'INSERT INTO workcenters '
        '(id, plant_id, home_line_id, name, code, created_at, updated_at) '
        "VALUES ('wc-1', 'plant-1', 'line-1', 'CLAD04', 'CLAD04', $now, $now)",
      );
  }

  test('v1 → current: adds the project layer and keeps every v1 row', () async {
    final file = File(p.join(dir.path, 'flowmap.sqlite'));
    final v1 = sqlite3.open(file.path)
      ..execute(resourceTables)
      ..execute('PRAGMA user_version = 1');
    insertResourceRows(v1);
    v1.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    // A query forces the lazy open, and therefore the migration.
    final plants = await db.select(db.plants).get();
    expect(plants.single.name, 'Werk Nord');

    final workcenters = await db.select(db.workcenters).get();
    expect(workcenters.single.name, 'CLAD04');
    expect(workcenters.single.plantId, 'plant-1');
    // v7 moved the single home line into `workcenter_lines`; a v1 row that
    // named one keeps it, now as a set of one.
    final membership = await db.select(db.workcenterLines).get();
    expect(membership.single.workcenterId, 'wc-1');
    expect(membership.single.lineId, 'line-1');

    // The v1 pattern survived and was not re-seeded into a duplicate.
    final patterns = await db.select(db.shiftPatterns).get();
    expect(patterns.where((p) => p.name == 'ABC'), hasLength(1));

    // The v2 tables exist and are usable.
    expect(await db.select(db.projects).get(), isEmpty);
    expect(await db.select(db.studies).get(), isEmpty);
    expect(await db.select(db.flowNodes).get(), isEmpty);
    expect(await db.select(db.taktPeriods).get(), isEmpty);
    expect(await db.select(db.workcenterSchedulePeriods).get(), isEmpty);
    expect(await db.select(db.calendarExceptions).get(), isEmpty);
    expect(await db.select(db.flowAnnotations).get(), isEmpty);

    // And the v6 demand tables, which are created at every starting version
    // rather than guarded like the two `addColumn` steps.
    expect(await db.select(db.demandParts).get(), isEmpty);
    expect(await db.select(db.partProcessTimes).get(), isEmpty);
    expect(await db.select(db.demandOrders).get(), isEmpty);

    // Seeding reached a database that already existed.
    expect(patterns.map((p) => p.name), contains('ABCD'));
    expect(await db.select(db.workcenterTypes).get(), isNotEmpty);
  });

  test('v2 → v3: drops workcenters.code and keeps the project data', () async {
    final file = File(p.join(dir.path, 'flowmap.sqlite'));
    final v2 = sqlite3.open(file.path)
      ..execute(resourceTables)
      ..execute(projectTables)
      ..execute('PRAGMA user_version = 2');
    insertResourceRows(v2);
    v2
      ..execute(
        'INSERT INTO projects '
        '(id, name, plant_id, shift_pattern_id, created_at, updated_at) '
        "VALUES ('proj-1', 'H2 2026', 'plant-1', 'pattern-1', $now, $now)",
      )
      ..execute(
        'INSERT INTO studies (id, project_id, production_cell_id, '
        'production_line_id, name, created_at, updated_at) '
        "VALUES ('study-1', 'proj-1', 'cell-1', 'line-1', 'Current', $now, $now)",
      )
      ..execute(
        'INSERT INTO flow_nodes (id, study_id, position, kind, workcenter_id, '
        'created_at, updated_at) '
        "VALUES ('node-1', 'study-1', 0, 'step', 'wc-1', $now, $now)",
      )
      ..execute(
        'INSERT INTO workcenter_schedule_periods (id, project_id, '
        'workcenter_id, start_date, end_date, operators_per_shift, '
        'availability, rework, created_at, updated_at) '
        "VALUES ('sched-1', 'proj-1', 'wc-1', 0, 99999999, '1/1/1', "
        '0.74, 0.037, $now, $now)',
      );
    v2.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final workcenters = await db.select(db.workcenters).get();
    expect(workcenters.single.name, 'CLAD04');
    final membership = await db.select(db.workcenterLines).get();
    expect(membership.single.lineId, 'line-1');

    // The rebuild recreates the table; rows pointing at it must survive, which
    // is what `legacy_alter_table` during the rename is for.
    final nodes = await db.select(db.flowNodes).get();
    expect(nodes.single.workcenterId, 'wc-1');
    // v4 added the wait unit and v5 the step equivalent; rows written before
    // them read as null, which means "the unit the editor offered at the time"
    // and "follow the line's takt".
    expect(nodes.single.inventoryUnit, isNull);
    expect(nodes.single.equivalentValue, isNull);
    expect(nodes.single.equivalentUnit, isNull);

    final schedules = await db.select(db.workcenterSchedulePeriods).get();
    expect(schedules.single.operatorsPerShift, '1/1/1');
    expect(schedules.single.availability, 0.74);

    expect((await db.select(db.studies).get()).single.name, 'Current');

    // The v6 demand tables reached a database that already carried studies, so
    // a part can be keyed to one that existed before them.
    expect(await db.select(db.demandParts).get(), isEmpty);
    expect(await db.select(db.demandOrders).get(), isEmpty);
  });

  /// A **v6** database: what shipped with M3, and what is on a user's machine
  /// right now. It has been through the v3 rebuild, so `workcenters` has no
  /// `code` — but it still carries `home_line_id`, which is the column the v7
  /// step has to harvest before dropping.
  ///
  /// This is the branch a real user upgrades through, and it is not the one
  /// the v1 and v2 fixtures exercise: those reach v7 with the column already
  /// gone, dropped by the v3 step running against today's definition.
  const v6Workcenters = """
    CREATE TABLE workcenters (
      id TEXT NOT NULL,
      plant_id TEXT NOT NULL REFERENCES plants (id) ON DELETE CASCADE,
      home_line_id TEXT NULL REFERENCES production_lines (id) ON DELETE SET NULL,
      type_id TEXT NULL REFERENCES workcenter_types (id) ON DELETE SET NULL,
      name TEXT NOT NULL, notes TEXT NULL,
      archived_at INTEGER NULL, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL, PRIMARY KEY (id), UNIQUE (plant_id, name));
  """;

  const v6DemandTables = """
    CREATE TABLE demand_parts (
      id TEXT NOT NULL,
      study_id TEXT NOT NULL REFERENCES studies (id) ON DELETE CASCADE,
      part_number TEXT NOT NULL, description TEXT NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      PRIMARY KEY (id), UNIQUE (study_id, part_number));
    CREATE TABLE part_process_times (
      part_id TEXT NOT NULL REFERENCES demand_parts (id) ON DELETE CASCADE,
      target_id TEXT NOT NULL, seconds INTEGER NOT NULL,
      PRIMARY KEY (part_id, target_id));
    CREATE TABLE demand_orders (
      id TEXT NOT NULL,
      study_id TEXT NOT NULL REFERENCES studies (id) ON DELETE CASCADE,
      part_id TEXT NOT NULL REFERENCES demand_parts (id) ON DELETE CASCADE,
      sequence INTEGER NOT NULL, order_number TEXT NULL,
      batch_size INTEGER NOT NULL DEFAULT 1, need_date INTEGER NOT NULL,
      material_date INTEGER NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      PRIMARY KEY (id), UNIQUE (study_id, sequence));
  """;

  test('v6 to v7: the home line becomes a set of one', () async {
    final file = File(p.join(dir.path, 'flowmap.sqlite'));

    // `resourceTables` carries the v1 `workcenters`; v6 has its own shape.
    final withoutWorkcenters = resourceTables.replaceAll(
      RegExp(r'CREATE TABLE workcenters \([^;]*\);'),
      '',
    );

    final v6 = sqlite3.open(file.path)
      ..execute(withoutWorkcenters)
      ..execute(v6Workcenters)
      ..execute(projectTables)
      ..execute(v6DemandTables)
      ..execute('ALTER TABLE flow_nodes ADD COLUMN inventory_unit TEXT NULL')
      ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_value REAL NULL')
      ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_unit TEXT NULL')
      ..execute('PRAGMA user_version = 6');

    v6
      ..execute(
        'INSERT INTO plants (id, name, code, created_at, updated_at) '
        "VALUES ('plant-1', 'Werk Nord', 'WN', $now, $now)",
      )
      ..execute(
        'INSERT INTO production_cells '
        '(id, plant_id, name, created_at, updated_at) '
        "VALUES ('cell-1', 'plant-1', 'Cell A', $now, $now)",
      )
      ..execute(
        'INSERT INTO production_lines '
        '(id, cell_id, name, created_at, updated_at) '
        "VALUES ('line-1', 'cell-1', 'Line 1', $now, $now)",
      )
      ..execute(
        'INSERT INTO workcenters '
        '(id, plant_id, home_line_id, name, created_at, updated_at) '
        "VALUES ('wc-1', 'plant-1', 'line-1', 'CLAD04', $now, $now)",
      )
      ..execute(
        'INSERT INTO workcenters '
        '(id, plant_id, home_line_id, name, created_at, updated_at) '
        "VALUES ('wc-2', 'plant-1', NULL, 'Shared oven', $now, $now)",
      )
      ..close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final workcenters = await db.select(db.workcenters).get();
    expect(
      workcenters.map((w) => w.name),
      containsAll(['CLAD04', 'Shared oven']),
    );

    // The one that had a home line keeps it, now as a set of one — nobody's
    // tree rearranges itself under them on upgrade.
    final membership = await db.select(db.workcenterLines).get();
    expect(membership, hasLength(1));
    expect(membership.single.workcenterId, 'wc-1');
    expect(membership.single.lineId, 'line-1');

    // A workcenter that had no home line is filed under nothing, which is now
    // a first-class state rather than a null.
    expect(membership.where((m) => m.workcenterId == 'wc-2'), isEmpty);
  });

  test('v8 to v9: parts gain a project, orders lose their number', () async {
    final file = File(p.join(dir.path, 'flowmap.sqlite'));

    final withoutWorkcenters = resourceTables.replaceAll(
      RegExp(r'CREATE TABLE workcenters \([^;]*\);'),
      '',
    );

    final v8 = sqlite3.open(file.path)
      ..execute(withoutWorkcenters)
      ..execute(v6Workcenters)
      ..execute(projectTables)
      ..execute(v6DemandTables)
      ..execute('ALTER TABLE flow_nodes ADD COLUMN inventory_unit TEXT NULL')
      ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_value REAL NULL')
      ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_unit TEXT NULL')
      ..execute(
        'CREATE TABLE workcenter_lines ('
        'workcenter_id TEXT NOT NULL REFERENCES workcenters (id) ON DELETE CASCADE, '
        'line_id TEXT NOT NULL REFERENCES production_lines (id) ON DELETE CASCADE, '
        'created_at INTEGER NOT NULL, PRIMARY KEY (workcenter_id, line_id))',
      )
      ..execute('ALTER TABLE workcenter_types ADD COLUMN icon TEXT NULL')
      ..execute('PRAGMA user_version = 8');

    v8
      ..execute(
        'INSERT INTO plants (id, name, created_at, updated_at) '
        "VALUES ('plant-1', 'Werk Nord', $now, $now)",
      )
      ..execute(
        'INSERT INTO production_cells '
        '(id, plant_id, name, created_at, updated_at) '
        "VALUES ('cell-1', 'plant-1', 'Cell A', $now, $now)",
      )
      ..execute(
        'INSERT INTO production_lines '
        '(id, cell_id, name, created_at, updated_at) '
        "VALUES ('line-1', 'cell-1', 'Line 1', $now, $now)",
      )
      ..execute(
        'INSERT INTO shift_patterns '
        '(id, name, cycle_type, working_weekdays, created_at, updated_at) '
        "VALUES ('pattern-1', 'ABC', 'fixedWeekly', 31, $now, $now)",
      )
      ..execute(
        'INSERT INTO projects '
        '(id, name, plant_id, shift_pattern_id, created_at, updated_at) '
        "VALUES ('proj-1', 'H2 2026', 'plant-1', 'pattern-1', $now, $now)",
      )
      ..execute(
        'INSERT INTO studies (id, project_id, production_cell_id, '
        'production_line_id, name, created_at, updated_at) '
        "VALUES ('study-1', 'proj-1', 'cell-1', 'line-1', 'Current', $now, $now)",
      )
      ..execute(
        'INSERT INTO demand_parts '
        '(id, study_id, part_number, created_at, updated_at) '
        "VALUES ('part-1', 'study-1', 'PN1', $now, $now)",
      )
      ..execute(
        'INSERT INTO demand_orders (id, study_id, part_id, sequence, '
        'order_number, batch_size, need_date, created_at, updated_at) '
        "VALUES ('order-1', 'study-1', 'part-1', 0, 'SO-9', 4, $now, "
        '$now, $now)',
      )
      ..close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    // The part survives and can now carry a customer project; the order keeps
    // everything that still means something, minus the works order number the
    // simulation never needed.
    final parts = await db.select(db.demandParts).get();
    expect(parts.single.partNumber, 'PN1');
    // Empty, not null: the project is half of a part's identity now, and
    // SQLite would treat two nulls as distinct in the unique key (§9.3).
    expect(parts.single.customerProject, '');

    final orders = await db.select(db.demandOrders).get();
    expect(orders.single.id, 'order-1');
    expect(orders.single.batchSize, 4);
    expect(orders.single.sequence, 0);
  });

  test('v10 to v11: run storage arrives and the demand survives', () async {
    final file = File(p.join(dir.path, 'flowmap.sqlite'));

    final withoutWorkcenters = resourceTables.replaceAll(
      RegExp(r'CREATE TABLE workcenters \([^;]*\);'),
      '',
    );

    // v10's demand tables: `demand_orders` has lost its `order_number` and
    // `demand_parts` carries a non-null `customer_project` in its unique key.
    const v10DemandTables = """
      CREATE TABLE demand_parts (
        id TEXT NOT NULL,
        study_id TEXT NOT NULL REFERENCES studies (id) ON DELETE CASCADE,
        part_number TEXT NOT NULL,
        customer_project TEXT NOT NULL DEFAULT '',
        description TEXT NULL,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
        PRIMARY KEY (id), UNIQUE (study_id, customer_project, part_number));
      CREATE TABLE part_process_times (
        part_id TEXT NOT NULL REFERENCES demand_parts (id) ON DELETE CASCADE,
        target_id TEXT NOT NULL, seconds INTEGER NOT NULL,
        PRIMARY KEY (part_id, target_id));
      CREATE TABLE demand_orders (
        id TEXT NOT NULL,
        study_id TEXT NOT NULL REFERENCES studies (id) ON DELETE CASCADE,
        part_id TEXT NOT NULL REFERENCES demand_parts (id) ON DELETE CASCADE,
        sequence INTEGER NOT NULL, batch_size INTEGER NOT NULL DEFAULT 1,
        need_date INTEGER NOT NULL, material_date INTEGER NULL,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
        PRIMARY KEY (id), UNIQUE (study_id, sequence));
    """;

    final v10 = sqlite3.open(file.path)
      ..execute(withoutWorkcenters)
      ..execute(v6Workcenters)
      ..execute(projectTables)
      ..execute(v10DemandTables)
      ..execute('ALTER TABLE flow_nodes ADD COLUMN inventory_unit TEXT NULL')
      ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_value REAL NULL')
      ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_unit TEXT NULL')
      ..execute(
        'CREATE TABLE workcenter_lines ('
        'workcenter_id TEXT NOT NULL REFERENCES workcenters (id) ON DELETE CASCADE, '
        'line_id TEXT NOT NULL REFERENCES production_lines (id) ON DELETE CASCADE, '
        'created_at INTEGER NOT NULL, PRIMARY KEY (workcenter_id, line_id))',
      )
      ..execute('ALTER TABLE workcenter_types ADD COLUMN icon TEXT NULL')
      ..execute('PRAGMA user_version = 10');

    v10
      ..execute(
        'INSERT INTO plants (id, name, created_at, updated_at) '
        "VALUES ('plant-1', 'Werk Nord', $now, $now)",
      )
      ..execute(
        'INSERT INTO production_cells '
        '(id, plant_id, name, created_at, updated_at) '
        "VALUES ('cell-1', 'plant-1', 'Cell A', $now, $now)",
      )
      ..execute(
        'INSERT INTO production_lines '
        '(id, cell_id, name, created_at, updated_at) '
        "VALUES ('line-1', 'cell-1', 'Line 1', $now, $now)",
      )
      ..execute(
        'INSERT INTO shift_patterns '
        '(id, name, cycle_type, working_weekdays, created_at, updated_at) '
        "VALUES ('pattern-1', 'ABC', 'fixedWeekly', 31, $now, $now)",
      )
      ..execute(
        'INSERT INTO projects '
        '(id, name, plant_id, shift_pattern_id, created_at, updated_at) '
        "VALUES ('proj-1', 'H2 2026', 'plant-1', 'pattern-1', $now, $now)",
      )
      ..execute(
        'INSERT INTO studies (id, project_id, production_cell_id, '
        'production_line_id, name, created_at, updated_at) '
        "VALUES ('study-1', 'proj-1', 'cell-1', 'line-1', 'Current', $now, $now)",
      )
      ..execute(
        'INSERT INTO demand_parts (id, study_id, part_number, '
        'customer_project, created_at, updated_at) '
        "VALUES ('part-1', 'study-1', 'PN2', 'Wing 7', $now, $now)",
      )
      ..execute(
        'INSERT INTO demand_orders (id, study_id, part_id, sequence, '
        'batch_size, need_date, created_at, updated_at) '
        "VALUES ('order-1', 'study-1', 'part-1', 0, 6, $now, $now, $now)",
      )
      ..close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    // The six run-storage tables exist and are usable — six `createTable`s and
    // no change to an existing table, so nothing above them can have moved.
    expect(await db.select(db.simulationRuns).get(), isEmpty);
    expect(await db.select(db.simulationRunStudies).get(), isEmpty);
    expect(await db.select(db.simulationRunOrders).get(), isEmpty);
    expect(await db.select(db.simulationRunSteps).get(), isEmpty);
    expect(await db.select(db.simulationRunEmptySlots).get(), isEmpty);
    expect(await db.select(db.simulationRunWorkcenters).get(), isEmpty);

    // And the demand the user typed came through untouched — parts keep their
    // numbers and their project, orders keep their sequence and batch size.
    final parts = await db.select(db.demandParts).get();
    expect(parts.single.partNumber, 'PN2');
    expect(parts.single.customerProject, 'Wing 7');

    final orders = await db.select(db.demandOrders).get();
    expect(orders.single.sequence, 0);
    expect(orders.single.batchSize, 6);
  });

  test(
    'v11 to v12: a stored run keeps its rows and gains blank columns',
    () async {
      final file = File(p.join(dir.path, 'flowmap.sqlite'));

      final withoutWorkcenters = resourceTables.replaceAll(
        RegExp(r'CREATE TABLE workcenters \([^;]*\);'),
        '',
      );

      // v11's demand tables — no `batch_number` yet.
      const v11DemandTables = """
        CREATE TABLE demand_parts (
          id TEXT NOT NULL,
          study_id TEXT NOT NULL REFERENCES studies (id) ON DELETE CASCADE,
          part_number TEXT NOT NULL,
          customer_project TEXT NOT NULL DEFAULT '',
          description TEXT NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          PRIMARY KEY (id), UNIQUE (study_id, customer_project, part_number));
        CREATE TABLE part_process_times (
          part_id TEXT NOT NULL REFERENCES demand_parts (id) ON DELETE CASCADE,
          target_id TEXT NOT NULL, seconds INTEGER NOT NULL,
          PRIMARY KEY (part_id, target_id));
        CREATE TABLE demand_orders (
          id TEXT NOT NULL,
          study_id TEXT NOT NULL REFERENCES studies (id) ON DELETE CASCADE,
          part_id TEXT NOT NULL REFERENCES demand_parts (id) ON DELETE CASCADE,
          sequence INTEGER NOT NULL, batch_size INTEGER NOT NULL DEFAULT 1,
          need_date INTEGER NOT NULL, material_date INTEGER NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          PRIMARY KEY (id), UNIQUE (study_id, sequence));
      """;

      // M4's run storage as v11 left it: `simulation_run_orders` carries none
      // of the four columns the Production Plan reads, and there is no
      // `simulation_run_dispatch` at all.
      const v11RunTables = """
        CREATE TABLE simulation_runs (
          id TEXT NOT NULL,
          project_id TEXT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
          dispatch TEXT NOT NULL, run_start INTEGER NOT NULL,
          run_end INTEGER NOT NULL, guard INTEGER NOT NULL,
          abort_reason TEXT NULL, created_at INTEGER NOT NULL,
          PRIMARY KEY (id));
        CREATE TABLE simulation_run_studies (
          run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
          study_id TEXT NOT NULL, name TEXT NOT NULL,
          release_seconds INTEGER NOT NULL, release_calendar_id TEXT NULL,
          priority INTEGER NOT NULL, wip_cap INTEGER NULL,
          PRIMARY KEY (run_id, study_id));
        CREATE TABLE simulation_run_orders (
          run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
          study_id TEXT NOT NULL, order_id TEXT NOT NULL,
          sequence INTEGER NOT NULL, part_id TEXT NOT NULL,
          part_number TEXT NOT NULL, need_date INTEGER NOT NULL,
          released INTEGER NULL, delivered INTEGER NULL,
          theoretical_seconds INTEGER NULL, PRIMARY KEY (run_id, order_id));
        CREATE TABLE simulation_run_steps (
          run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
          study_id TEXT NOT NULL, order_id TEXT NOT NULL, node_id TEXT NOT NULL,
          workcenter_id TEXT NOT NULL, queue_start INTEGER NOT NULL,
          process_start INTEGER NOT NULL, process_end INTEGER NOT NULL,
          changeover_incurred INTEGER NOT NULL DEFAULT 0
            CHECK (changeover_incurred IN (0, 1)),
          PRIMARY KEY (run_id, order_id, node_id));
        CREATE TABLE simulation_run_empty_slots (
          run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
          study_id TEXT NOT NULL, slot_at INTEGER NOT NULL, reason TEXT NOT NULL,
          PRIMARY KEY (run_id, study_id, slot_at));
        CREATE TABLE simulation_run_workcenters (
          run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
          workcenter_id TEXT NOT NULL, name TEXT NOT NULL,
          busy_seconds INTEGER NOT NULL, open_seconds INTEGER NOT NULL,
          PRIMARY KEY (run_id, workcenter_id));
      """;

      final v11 = sqlite3.open(file.path)
        ..execute(withoutWorkcenters)
        ..execute(v6Workcenters)
        ..execute(projectTables)
        ..execute(v11DemandTables)
        ..execute(v11RunTables)
        ..execute('ALTER TABLE flow_nodes ADD COLUMN inventory_unit TEXT NULL')
        ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_value REAL NULL')
        ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_unit TEXT NULL')
        ..execute(
          'CREATE TABLE workcenter_lines ('
          'workcenter_id TEXT NOT NULL REFERENCES workcenters (id) ON DELETE CASCADE, '
          'line_id TEXT NOT NULL REFERENCES production_lines (id) ON DELETE CASCADE, '
          'created_at INTEGER NOT NULL, PRIMARY KEY (workcenter_id, line_id))',
        )
        ..execute('ALTER TABLE workcenter_types ADD COLUMN icon TEXT NULL')
        ..execute('PRAGMA user_version = 11');

      v11
        ..execute(
          'INSERT INTO plants (id, name, created_at, updated_at) '
          "VALUES ('plant-1', 'Werk Nord', $now, $now)",
        )
        ..execute(
          'INSERT INTO production_cells '
          '(id, plant_id, name, created_at, updated_at) '
          "VALUES ('cell-1', 'plant-1', 'Cell A', $now, $now)",
        )
        ..execute(
          'INSERT INTO production_lines '
          '(id, cell_id, name, created_at, updated_at) '
          "VALUES ('line-1', 'cell-1', 'Line 1', $now, $now)",
        )
        ..execute(
          'INSERT INTO shift_patterns '
          '(id, name, cycle_type, working_weekdays, created_at, updated_at) '
          "VALUES ('pattern-1', 'ABC', 'fixedWeekly', 31, $now, $now)",
        )
        ..execute(
          'INSERT INTO projects '
          '(id, name, plant_id, shift_pattern_id, created_at, updated_at) '
          "VALUES ('proj-1', 'H2 2026', 'plant-1', 'pattern-1', $now, $now)",
        )
        ..execute(
          'INSERT INTO studies (id, project_id, production_cell_id, '
          'production_line_id, name, created_at, updated_at) '
          "VALUES ('study-1', 'proj-1', 'cell-1', 'line-1', 'Current', $now, $now)",
        )
        ..execute(
          'INSERT INTO demand_parts (id, study_id, part_number, '
          'customer_project, created_at, updated_at) '
          "VALUES ('part-1', 'study-1', 'PN2', 'Wing 7', $now, $now)",
        )
        ..execute(
          'INSERT INTO demand_orders (id, study_id, part_id, sequence, '
          'batch_size, need_date, created_at, updated_at) '
          "VALUES ('order-1', 'study-1', 'part-1', 0, 6, $now, $now, $now)",
        )
        // A run made before any of this existed — the case the whole "nullable,
        // never backfilled" decision is about.
        ..execute(
          'INSERT INTO simulation_runs (id, project_id, dispatch, run_start, '
          'run_end, guard, created_at) '
          "VALUES ('run-1', 'proj-1', 'fifo', $now, $now, $now, $now)",
        )
        ..execute(
          'INSERT INTO simulation_run_orders (run_id, study_id, order_id, '
          'sequence, part_id, part_number, need_date, released, delivered) '
          "VALUES ('run-1', 'study-1', 'order-1', 0, 'part-1', 'PN2', "
          '$now, $now, $now)',
        )
        ..close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      // The order the planner typed is untouched, and can now carry a batch
      // number — null, because nobody has typed one, which is not the same as
      // an empty string and is why the column is nullable (§9.1).
      final orders = await db.select(db.demandOrders).get();
      expect(orders.single.batchSize, 6);
      expect(orders.single.batchNumber, isNull);

      // The stored run survived, and its order row gained four columns with
      // nothing in them. Blank because that run genuinely did not record them —
      // backfilling from the demand above would make it a hybrid of two moments.
      final runOrders = await db.select(db.simulationRunOrders).get();
      expect(runOrders.single.partNumber, 'PN2');
      expect(runOrders.single.delivered, isNotNull);
      expect(runOrders.single.customerProject, isNull);
      expect(runOrders.single.batchNumber, isNull);
      expect(runOrders.single.batchSize, isNull);
      expect(runOrders.single.materialDate, isNull);

      // The run header itself is undisturbed — this step rebuilds no table.
      expect((await db.select(db.simulationRuns).get()).single.id, 'run-1');

      // And the two new tables exist and are usable.
      expect(await db.select(db.workcenterDispatch).get(), isEmpty);
      expect(await db.select(db.simulationRunDispatch).get(), isEmpty);
    },
  );

  test('an upgrade that died part-way can still be opened', () async {
    // The shape found on the developer's own machine: `user_version` 6, but
    // the v7 and v8 steps had already run — `workcenters` rebuilt without
    // `home_line_id`, `workcenter_lines` created, `workcenter_types.icon`
    // added — while `demand_parts` and `demand_orders` were still v6.
    //
    // A migration cannot run in a transaction (`alterTable` needs foreign keys
    // off, which SQLite refuses to change mid-transaction), so a step that
    // throws leaves exactly this: tables ahead of the counter. Replaying from
    // the counter then read a column the v7 step had already dropped, and the
    // app could not open the database again at all.
    final file = File(p.join(dir.path, 'flowmap.sqlite'));

    final withoutWorkcenters = resourceTables.replaceAll(
      RegExp(r'CREATE TABLE workcenters \([^;]*\);'),
      '',
    );

    // `workcenters` as the v7 rebuild leaves it: no `code`, no `home_line_id`.
    const rebuiltWorkcenters = """
      CREATE TABLE workcenters (
        id TEXT NOT NULL,
        plant_id TEXT NOT NULL REFERENCES plants (id) ON DELETE CASCADE,
        type_id TEXT NULL REFERENCES workcenter_types (id) ON DELETE SET NULL,
        name TEXT NOT NULL, notes TEXT NULL,
        archived_at INTEGER NULL, created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL, PRIMARY KEY (id), UNIQUE (plant_id, name));
    """;

    final stuck = sqlite3.open(file.path)
      ..execute(withoutWorkcenters)
      ..execute(rebuiltWorkcenters)
      ..execute(projectTables)
      ..execute(v6DemandTables)
      ..execute('ALTER TABLE flow_nodes ADD COLUMN inventory_unit TEXT NULL')
      ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_value REAL NULL')
      ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_unit TEXT NULL')
      ..execute(
        'CREATE TABLE workcenter_lines ('
        'workcenter_id TEXT NOT NULL REFERENCES workcenters (id) ON DELETE CASCADE, '
        'line_id TEXT NOT NULL REFERENCES production_lines (id) ON DELETE CASCADE, '
        'created_at INTEGER NOT NULL, PRIMARY KEY (workcenter_id, line_id))',
      )
      ..execute('ALTER TABLE workcenter_types ADD COLUMN icon TEXT NULL')
      // The counter never moved, because the step after these threw.
      ..execute('PRAGMA user_version = 6');

    stuck
      ..execute(
        'INSERT INTO plants (id, name, created_at, updated_at) '
        "VALUES ('plant-1', 'Werk Nord', $now, $now)",
      )
      ..execute(
        'INSERT INTO production_cells '
        '(id, plant_id, name, created_at, updated_at) '
        "VALUES ('cell-1', 'plant-1', 'Cell A', $now, $now)",
      )
      ..execute(
        'INSERT INTO production_lines '
        '(id, cell_id, name, created_at, updated_at) '
        "VALUES ('line-1', 'cell-1', 'Line 1', $now, $now)",
      )
      ..execute(
        'INSERT INTO workcenters (id, plant_id, name, created_at, updated_at) '
        "VALUES ('wc-1', 'plant-1', 'CLAD04', $now, $now)",
      )
      ..execute(
        "INSERT INTO workcenter_lines VALUES ('wc-1', 'line-1', $now)",
      )
      ..execute(
        'INSERT INTO shift_patterns '
        '(id, name, cycle_type, working_weekdays, created_at, updated_at) '
        "VALUES ('pattern-1', 'ABC', 'fixedWeekly', 31, $now, $now)",
      )
      ..execute(
        'INSERT INTO projects '
        '(id, name, plant_id, shift_pattern_id, created_at, updated_at) '
        "VALUES ('proj-1', 'H2 2026', 'plant-1', 'pattern-1', $now, $now)",
      )
      ..execute(
        'INSERT INTO studies (id, project_id, production_cell_id, '
        'production_line_id, name, created_at, updated_at) '
        "VALUES ('study-1', 'proj-1', 'cell-1', 'line-1', 'Current', $now, $now)",
      )
      ..execute(
        'INSERT INTO demand_parts '
        '(id, study_id, part_number, created_at, updated_at) '
        "VALUES ('part-1', 'study-1', 'PN2', $now, $now)",
      )
      ..execute(
        'INSERT INTO demand_orders (id, study_id, part_id, sequence, '
        'order_number, batch_size, need_date, created_at, updated_at) '
        "VALUES ('order-1', 'study-1', 'part-1', 0, 'SO-9', 6, $now, $now, $now)",
      )
      ..close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    // It opens at all, which is the whole point.
    final workcenters = await db.select(db.workcenters).get();
    expect(workcenters.single.name, 'CLAD04');

    // The half that had already run is not run again and not undone.
    final membership = await db.select(db.workcenterLines).get();
    expect(membership.single.lineId, 'line-1');

    // The half that had not run, runs — and the user's demand survives it.
    final parts = await db.select(db.demandParts).get();
    expect(parts.single.partNumber, 'PN2');
    expect(parts.single.customerProject, '');

    final orders = await db.select(db.demandOrders).get();
    expect(orders.single.sequence, 0);
    expect(orders.single.batchSize, 6);

    // And M4's tables arrive, so the counter really did reach the end.
    expect(await db.select(db.simulationRuns).get(), isEmpty);
  });

  test(
    'a v1 database with no seed stamp still gets its reference data',
    () async {
      final file = File(p.join(dir.path, 'flowmap.sqlite'));
      sqlite3.open(file.path)
        ..execute(resourceTables)
        ..execute('PRAGMA user_version = 1')
        ..close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      final types = await db.select(db.workcenterTypes).get();
      expect(types.map((t) => t.name), contains('Machining'));
    },
  );
}
