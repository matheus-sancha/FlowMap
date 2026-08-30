import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
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

    // The part survives; the order keeps everything that still means
    // something, minus the works order number the simulation never needed.
    final parts = await db.select(db.demandParts).get();
    expect(parts.single.partNumber, 'PN1');

    // The project this part never had is now a column on the order, and null
    // is what "none" is there — v9 gave the part an empty string only so
    // SQLite's UNIQUE would not treat two unprojected parts as distinct, and
    // v14 took it out of every key (§9.3).
    final orders = await db.select(db.demandOrders).get();
    expect(orders.single.customerProject, isNull);
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

    // And the demand the user typed came through untouched — the part keeps
    // its number, the order keeps its sequence and batch size, and the project
    // that was typed against the part has moved onto the order that is for it
    // (§16.15). Nothing was lost in the move.
    final parts = await db.select(db.demandParts).get();
    expect(parts.single.partNumber, 'PN2');

    final orders = await db.select(db.demandOrders).get();
    expect(orders.single.sequence, 0);
    expect(orders.single.batchSize, 6);
    expect(orders.single.customerProject, 'Wing 7');
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

      // v12's two tables were dropped again by v15, once the lanes had taken
      // over what they held — so what this step now has to prove is that a
      // database arriving from v11 still reaches the end.
      expect(await db.select(db.simulationRunLanes).get(), isEmpty);
    },
  );

  test(
    'v12 to v13: a stored run keeps its v12 columns and gains a blank one',
    () async {
      final file = File(p.join(dir.path, 'flowmap.sqlite'));

      final withoutWorkcenters = resourceTables.replaceAll(
        RegExp(r'CREATE TABLE workcenters \([^;]*\);'),
        '',
      );

      // v12's demand tables — `batch_number` has arrived.
      const v12DemandTables = """
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
          batch_number TEXT NULL,
          need_date INTEGER NOT NULL, material_date INTEGER NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          PRIMARY KEY (id), UNIQUE (study_id, sequence));
        CREATE TABLE workcenter_dispatch (
          project_id TEXT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
          target_id TEXT NOT NULL, rule TEXT NOT NULL,
          updated_at INTEGER NOT NULL, PRIMARY KEY (project_id, target_id));
      """;

      // Run storage as v12 left it: the four Production Plan columns are
      // there, `part_description` is not.
      const v12RunTables = """
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
          part_number TEXT NOT NULL,
          customer_project TEXT NULL, batch_number TEXT NULL,
          batch_size INTEGER NULL, material_date INTEGER NULL,
          need_date INTEGER NOT NULL,
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
        CREATE TABLE simulation_run_dispatch (
          run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
          target_id TEXT NOT NULL, name TEXT NOT NULL, rule TEXT NOT NULL,
          PRIMARY KEY (run_id, target_id));
      """;

      final v12 = sqlite3.open(file.path)
        ..execute(withoutWorkcenters)
        ..execute(v6Workcenters)
        ..execute(projectTables)
        ..execute(v12DemandTables)
        ..execute(v12RunTables)
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
        ..execute('PRAGMA user_version = 12');

      v12
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
        // The part carries a description all along — v13's point is that the
        // *run* could not see it, not that nobody had typed one.
        ..execute(
          'INSERT INTO demand_parts (id, study_id, part_number, '
          'customer_project, description, created_at, updated_at) '
          "VALUES ('part-1', 'study-1', 'PN2', 'Wing 7', 'AWB 10K 1.0', "
          '$now, $now)',
        )
        ..execute(
          'INSERT INTO demand_orders (id, study_id, part_id, sequence, '
          'batch_size, need_date, created_at, updated_at) '
          "VALUES ('order-1', 'study-1', 'part-1', 0, 6, $now, $now, $now)",
        )
        ..execute(
          'INSERT INTO simulation_runs (id, project_id, dispatch, run_start, '
          'run_end, guard, created_at) '
          "VALUES ('run-1', 'proj-1', 'fifo', $now, $now, $now, $now)",
        )
        // A v12 run: the four plan columns are populated, so this fixture can
        // tell "the column arrived blank" from "the step wiped the row".
        ..execute(
          'INSERT INTO simulation_run_orders (run_id, study_id, order_id, '
          'sequence, part_id, part_number, customer_project, batch_number, '
          'batch_size, material_date, need_date, released, delivered) '
          "VALUES ('run-1', 'study-1', 'order-1', 0, 'part-1', 'PN2', "
          "'Wing 7', 'B-001', 6, $now, $now, $now, $now)",
        )
        ..close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      final runOrders = await db.select(db.simulationRunOrders).get();

      // v12's four columns still hold what they held. This step adds a column
      // and rebuilds nothing, and that is the assertion which would fail if it
      // ever started rebuilding.
      expect(runOrders.single.customerProject, 'Wing 7');
      expect(runOrders.single.batchNumber, 'B-001');
      expect(runOrders.single.batchSize, 6);
      expect(runOrders.single.materialDate, isNotNull);

      // The new one is blank, even though the part it points at has a
      // description sitting right there in `demand_parts`. Reaching across for
      // it is the join §7.10 forbids: this run did not record one, and a blank
      // saying so is true.
      expect(runOrders.single.partDescription, isNull);

      // The run header is undisturbed, and the demand is where it was.
      expect((await db.select(db.simulationRuns).get()).single.id, 'run-1');
      expect(
        (await db.select(db.demandParts).get()).single.description,
        'AWB 10K 1.0',
      );
    },
  );

  test(
    'v13 to v14: the project moves to the order, and twins keep their times',
    () async {
      final file = File(p.join(dir.path, 'flowmap.sqlite'));

      final withoutWorkcenters = resourceTables.replaceAll(
        RegExp(r'CREATE TABLE workcenters \([^;]*\);'),
        '',
      );

      // v13's demand tables: the project is still on the part, and still half
      // of what identifies one.
      const v13DemandTables = """
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
          batch_number TEXT NULL,
          need_date INTEGER NOT NULL, material_date INTEGER NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          PRIMARY KEY (id), UNIQUE (study_id, sequence));
        CREATE TABLE workcenter_dispatch (
          project_id TEXT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
          target_id TEXT NOT NULL, rule TEXT NOT NULL,
          updated_at INTEGER NOT NULL, PRIMARY KEY (project_id, target_id));
      """;

      final v13 = sqlite3.open(file.path)
        ..execute(withoutWorkcenters)
        ..execute(v6Workcenters)
        ..execute(projectTables)
        ..execute(v13DemandTables)
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
        ..execute('PRAGMA user_version = 13');

      v13
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
        // The case v14 has to survive: one part number under two projects,
        // which v13 called two parts — with their own process times, which is
        // exactly why they cannot be merged.
        ..execute(
          'INSERT INTO demand_parts (id, study_id, part_number, '
          'customer_project, created_at, updated_at) '
          "VALUES ('part-a', 'study-1', 'PN2', 'Wing 7', $now, $now)",
        )
        ..execute(
          'INSERT INTO demand_parts (id, study_id, part_number, '
          'customer_project, created_at, updated_at) '
          "VALUES ('part-b', 'study-1', 'PN2', 'Wing 9', ${now + 1}, ${now + 1})",
        )
        // And an ordinary part, to show the common case is left alone.
        ..execute(
          'INSERT INTO demand_parts (id, study_id, part_number, '
          'customer_project, created_at, updated_at) '
          "VALUES ('part-c', 'study-1', 'PN5', '', $now, $now)",
        )
        ..execute(
          // **A step for the times to belong to.** §9 keys a process time by
          // its flow node, and the v24 migration joins through the part's own
          // study to find one — a time whose target has no step is dropped,
          // which would have taken both of these with it.
          'INSERT INTO flow_nodes (id, study_id, position, kind, '
          'workcenter_id, created_at, updated_at) '
          "VALUES ('node-1', 'study-1', 0, 'step', 'wc-1', $now, $now)",
        )
        ..execute(
          'INSERT INTO part_process_times (part_id, target_id, seconds) '
          "VALUES ('part-a', 'wc-1', 14400)",
        )
        ..execute(
          'INSERT INTO part_process_times (part_id, target_id, seconds) '
          "VALUES ('part-b', 'wc-1', 10800)",
        )
        ..execute(
          'INSERT INTO demand_orders (id, study_id, part_id, sequence, '
          'batch_size, need_date, created_at, updated_at) '
          "VALUES ('order-1', 'study-1', 'part-a', 0, 4, $now, $now, $now)",
        )
        ..execute(
          'INSERT INTO demand_orders (id, study_id, part_id, sequence, '
          'batch_size, need_date, created_at, updated_at) '
          "VALUES ('order-2', 'study-1', 'part-b', 1, 6, $now, $now, $now)",
        )
        ..execute(
          'INSERT INTO demand_orders (id, study_id, part_id, sequence, '
          'batch_size, need_date, created_at, updated_at) '
          "VALUES ('order-3', 'study-1', 'part-c', 2, 1, $now, $now, $now)",
        )
        ..close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      // Each order now says which project it is for, read down from the part
      // it was for. The unprojected one says null rather than an empty string:
      // on the part the blank existed only to keep SQLite's UNIQUE honest.
      final orders = await db.select(db.demandOrders).get()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
      expect(orders.map((o) => o.customerProject), ['Wing 7', 'Wing 9', null]);
      expect(orders.map((o) => o.batchSize), [4, 6, 1]);

      // **Both twins survive, and neither lost its times.** Merging them would
      // have given every order of one the other's process times, silently —
      // §11's one intolerable bug. The earlier keeps the number the planner
      // typed; the later says which project it came from, so the rename is
      // legible on the grid rather than mysterious.
      final parts = await db.select(db.demandParts).get()
        ..sort((a, b) => a.id.compareTo(b.id));
      expect(parts.map((p) => p.id), ['part-a', 'part-b', 'part-c']);
      expect(parts.map((p) => p.partNumber), ['PN2', 'PN2 (Wing 9)', 'PN5']);

      final times = await db.select(db.partProcessTimes).get()
        ..sort((a, b) => a.partId.compareTo(b.partId));
      expect(times.map((t) => (t.partId, t.seconds)), [
        ('part-a', 14400),
        ('part-b', 10800),
      ]);

      // And each order still points at the part it always did, so the rename
      // moved a label and not a relationship.
      expect(orders.map((o) => o.partId), ['part-a', 'part-b', 'part-c']);
    },
  );

  test('v14 to v15: the dispatch rule moves onto the lane that feeds it', () async {
    final file = File(p.join(dir.path, 'flowmap.sqlite'));

    final withoutWorkcenters = resourceTables.replaceAll(
      RegExp(r'CREATE TABLE workcenters \([^;]*\);'),
      '',
    );

    // v14's shape: `code` and `home_line_id` both long gone, so neither the v3
    // nor the v7 rebuild runs and `parallel_capacity` has to arrive by
    // `addColumn` on a live table rather than by a copy.
    const v14Workcenters = """
      CREATE TABLE workcenters (
        id TEXT NOT NULL,
        plant_id TEXT NOT NULL REFERENCES plants (id) ON DELETE CASCADE,
        type_id TEXT NULL REFERENCES workcenter_types (id) ON DELETE SET NULL,
        name TEXT NOT NULL, notes TEXT NULL,
        archived_at INTEGER NULL, created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL, PRIMARY KEY (id), UNIQUE (plant_id, name));
    """;

    const v14DemandTables = """
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
        sequence INTEGER NOT NULL, batch_size INTEGER NOT NULL DEFAULT 1,
        batch_number TEXT NULL, customer_project TEXT NULL,
        need_date INTEGER NOT NULL, material_date INTEGER NULL,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
        PRIMARY KEY (id), UNIQUE (study_id, sequence));
      CREATE TABLE workcenter_dispatch (
        project_id TEXT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
        target_id TEXT NOT NULL, rule TEXT NOT NULL,
        updated_at INTEGER NOT NULL, PRIMARY KEY (project_id, target_id));
    """;

    // M4's storage, as v11 built it. It has to be here: the v15 step adds
    // columns to three of these tables and only a database below v11 gets them
    // created on the way past.
    const v14RunTables = """
      CREATE TABLE simulation_runs (
        id TEXT NOT NULL,
        project_id TEXT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
        dispatch TEXT NOT NULL, run_start INTEGER NOT NULL,
        run_end INTEGER NOT NULL, guard INTEGER NOT NULL,
        abort_reason TEXT NULL, created_at INTEGER NOT NULL, PRIMARY KEY (id));
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
        part_number TEXT NOT NULL, customer_project TEXT NULL,
        batch_number TEXT NULL, batch_size INTEGER NULL,
        material_date INTEGER NULL, part_description TEXT NULL,
        need_date INTEGER NOT NULL, released INTEGER NULL,
        delivered INTEGER NULL, theoretical_seconds INTEGER NULL,
        PRIMARY KEY (run_id, order_id));
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
      CREATE TABLE simulation_run_dispatch (
        run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
        target_id TEXT NOT NULL, name TEXT NOT NULL, rule TEXT NOT NULL,
        PRIMARY KEY (run_id, target_id));
      CREATE TABLE simulation_run_workcenters (
        run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
        workcenter_id TEXT NOT NULL, name TEXT NOT NULL,
        busy_seconds INTEGER NOT NULL, open_seconds INTEGER NOT NULL,
        PRIMARY KEY (run_id, workcenter_id));
    """;

    final v14 = sqlite3.open(file.path)
      ..execute(withoutWorkcenters)
      ..execute(v14Workcenters)
      ..execute(projectTables)
      ..execute(v14DemandTables)
      ..execute(v14RunTables)
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
      ..execute('PRAGMA user_version = 14');

    v14
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
        'INSERT INTO production_lines (id, cell_id, name, created_at, updated_at) '
        "VALUES ('line-1', 'cell-1', 'Line 1', $now, $now)",
      )
      ..execute(
        'INSERT INTO shift_patterns '
        '(id, name, cycle_type, working_weekdays, created_at, updated_at) '
        "VALUES ('pattern-1', 'ABC', 'fixedWeekly', 31, $now, $now)",
      )
      ..execute(
        'INSERT INTO workcenters (id, plant_id, name, created_at, updated_at) '
        "VALUES ('wc-1', 'plant-1', 'CLAD04', $now, $now)",
      )
      ..execute(
        'INSERT INTO workcenters (id, plant_id, name, created_at, updated_at) '
        "VALUES ('wc-2', 'plant-1', 'TTAT', $now, $now)",
      )
      ..execute(
        'INSERT INTO workcenter_pools (id, plant_id, name, created_at, updated_at) '
        "VALUES ('pool-1', 'plant-1', 'CLAD Pool', $now, $now)",
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
      );

    // The flow the rules have to land on. Positions 0-3 are the ordinary case
    // — a lane, then the step it feeds, twice — and position 4 is the case with
    // nowhere to carry a rule to: a step whose upstream neighbour is another
    // step rather than a lane.
    for (final (id, position, kind, target) in [
      ('node-0', 0, 'inventory', null),
      ('node-1', 1, 'step', 'pool-1'),
      ('node-2', 2, 'inventory', null),
      ('node-3', 3, 'step', 'wc-1'),
      ('node-4', 4, 'step', 'wc-2'),
    ]) {
      final pool = kind == 'step' && target!.startsWith('pool')
          ? "'$target'"
          : 'NULL';
      final workcenter = kind == 'step' && target!.startsWith('wc')
          ? "'$target'"
          : 'NULL';
      v14.execute(
        'INSERT INTO flow_nodes (id, study_id, position, kind, workcenter_id, '
        'pool_id, label, created_at, updated_at) '
        "VALUES ('$id', 'study-1', $position, '$kind', $workcenter, $pool, "
        "'FIFO $position', $now, $now)",
      );
    }

    v14
      // One rule per kind of target, plus one for the step that has no lane.
      ..execute(
        'INSERT INTO workcenter_dispatch '
        '(project_id, target_id, rule, updated_at) '
        "VALUES ('proj-1', 'pool-1', 'shortestProcessing', $now)",
      )
      ..execute(
        'INSERT INTO workcenter_dispatch '
        '(project_id, target_id, rule, updated_at) '
        "VALUES ('proj-1', 'wc-1', 'earliestDueDate', $now)",
      )
      ..execute(
        'INSERT INTO workcenter_dispatch '
        '(project_id, target_id, rule, updated_at) '
        "VALUES ('proj-1', 'wc-2', 'earliestDueDate', $now)",
      )
      // A stored run, to show the added columns land on real rows rather than
      // only on an empty table.
      ..execute(
        'INSERT INTO simulation_runs (id, project_id, dispatch, run_start, '
        'run_end, guard, created_at) '
        "VALUES ('run-1', 'proj-1', 'fifo', $now, $now, $now, $now)",
      )
      ..execute(
        'INSERT INTO simulation_run_studies (run_id, study_id, name, '
        'release_seconds, priority) '
        "VALUES ('run-1', 'study-1', 'Current', 3600, 100)",
      )
      ..execute(
        'INSERT INTO simulation_run_steps (run_id, study_id, order_id, node_id, '
        'workcenter_id, queue_start, process_start, process_end) '
        "VALUES ('run-1', 'study-1', 'order-1', 'node-3', 'wc-1', "
        '$now, $now, $now)',
      )
      ..execute(
        'INSERT INTO simulation_run_workcenters '
        '(run_id, workcenter_id, name, busy_seconds, open_seconds) '
        "VALUES ('run-1', 'wc-1', 'CLAD04', 3600, 7200)",
      )
      ..close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final nodes = await db.select(db.flowNodes).get()
      ..sort((a, b) => a.position.compareTo(b.position));

    // **The rule now sits on the lane that feeds the step, not on the step's
    // target.** Both kinds of target carry across: a pool's rule and a single
    // workcenter's, because the queue forms in the same place either way.
    expect(nodes[0].laneRule, DispatchRule.shortestProcessing);
    expect(nodes[2].laneRule, DispatchRule.earliestDueDate);

    // A step is not a lane, so nothing was written to one.
    expect(nodes[1].laneRule, isNull);
    expect(nodes[3].laneRule, isNull);

    // And `wc-2`'s rule had nowhere to go: node-4 is a step whose upstream
    // neighbour is node-3, another step. The rule is dropped rather than
    // guessed at, which is the honest outcome — it described a queue this model
    // no longer holds anywhere — and the upgrade does not fail over it.
    expect(nodes[4].laneRule, isNull);

    // Capacity is untouched by the carry-over: a rule says how to choose, not
    // how many fit, and nothing in v14 knew the second thing.
    expect(nodes.map((n) => n.laneCapacity), everyElement(isNull));

    // The defaults land on rows that already existed, which is what makes them
    // safe: every station is one unit and every study has no buffer, exactly as
    // they behaved before the columns were there.
    final workcenters = await db.select(db.workcenters).get()
      ..sort((a, b) => a.id.compareTo(b.id));
    expect(workcenters.map((w) => w.parallelCapacity), [1, 1]);

    final study = await db.select(db.studies).getSingle();
    expect(study.startBufferDays, 0);
    expect(study.paceSetterTargetId, isNull);

    // A run stored before lanes had capacity says nothing was ever blocked and
    // every station was one unit, which is true of it.
    final step = await db.select(db.simulationRunSteps).getSingle();
    expect(step.blockedSeconds, 0);

    final station = await db.select(db.simulationRunWorkcenters).getSingle();
    expect(station.blockedSeconds, 0);
    expect(station.units, 1);
    expect(station.busySeconds, 3600);

    final runStudy = await db.select(db.simulationRunStudies).getSingle();
    expect(runStudy.startBufferDays, 0);

    // The two new tables arrive empty, so the counter really did reach the end.
    expect(await db.select(db.simulationRunLanes).get(), isEmpty);
    expect(await db.select(db.simulationRunLaneVisits).get(), isEmpty);

    // v16 rides on the same fixture: one nullable column, and a run stored
    // before §11.1 had anywhere to put its horizon says it has none — which is
    // true of it, and is what makes the warning absent rather than wrong on
    // every run made before this version.
    final header = await db.select(db.simulationRuns).getSingle();
    expect(header.scheduleHorizon, isNull);

    // v17 rides on the same fixture for the columns that only have to *arrive*.
    // The carry-over that has something to lose gets its own test below, with a
    // changeover populated — this fixture's nodes have none, so it could not
    // tell a working carry from a missing one.
    expect(nodes.map((n) => n.setupValue), everyElement(isNull));
    expect(nodes.map((n) => n.teardownValue), everyElement(isNull));
    expect(nodes.map((n) => n.samePartPercent), everyElement(isNull));
    expect(step.changeoverSeconds, isNull);
    expect(runStudy.productionCellId, isNull);
    expect(runStudy.productionLineName, isNull);
  });

  // v16's shape, built the way the real chain reached it: v14's tables, then
  // the columns v15 and v16 added. Written out rather than migrated up from
  // v14, because a fixture that ran the earlier steps would be testing them
  // again and would stop being the one shape v17 has to survive.
  //
  // Hoisted out of the v16 test when v18 arrived: the v17 fixture is this plus
  // v17's own columns, and copying eighty lines of DDL to add two is how two
  // fixtures come to disagree about the version they both claim to be.
  const v16Workcenters = """
    CREATE TABLE workcenters (
      id TEXT NOT NULL,
      plant_id TEXT NOT NULL REFERENCES plants (id) ON DELETE CASCADE,
      type_id TEXT NULL REFERENCES workcenter_types (id) ON DELETE SET NULL,
      name TEXT NOT NULL, notes TEXT NULL,
      parallel_capacity INTEGER NOT NULL DEFAULT 1,
      archived_at INTEGER NULL, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL, PRIMARY KEY (id), UNIQUE (plant_id, name));
  """;

  const v16RunTables = """
    CREATE TABLE simulation_runs (
      id TEXT NOT NULL,
      project_id TEXT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
      dispatch TEXT NOT NULL, run_start INTEGER NOT NULL,
      run_end INTEGER NOT NULL, guard INTEGER NOT NULL,
      abort_reason TEXT NULL, schedule_horizon INTEGER NULL,
      created_at INTEGER NOT NULL, PRIMARY KEY (id));
    CREATE TABLE simulation_run_studies (
      run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
      study_id TEXT NOT NULL, name TEXT NOT NULL,
      release_seconds INTEGER NOT NULL, release_calendar_id TEXT NULL,
      priority INTEGER NOT NULL, wip_cap INTEGER NULL,
      start_buffer_days INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (run_id, study_id));
    CREATE TABLE simulation_run_orders (
      run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
      study_id TEXT NOT NULL, order_id TEXT NOT NULL,
      sequence INTEGER NOT NULL, part_id TEXT NOT NULL,
      part_number TEXT NOT NULL, customer_project TEXT NULL,
      batch_number TEXT NULL, batch_size INTEGER NULL,
      material_date INTEGER NULL, part_description TEXT NULL,
      need_date INTEGER NOT NULL, released INTEGER NULL,
      delivered INTEGER NULL, theoretical_seconds INTEGER NULL,
      PRIMARY KEY (run_id, order_id));
    CREATE TABLE simulation_run_steps (
      run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
      study_id TEXT NOT NULL, order_id TEXT NOT NULL, node_id TEXT NOT NULL,
      workcenter_id TEXT NOT NULL, queue_start INTEGER NOT NULL,
      process_start INTEGER NOT NULL, process_end INTEGER NOT NULL,
      changeover_incurred INTEGER NOT NULL DEFAULT 0
        CHECK (changeover_incurred IN (0, 1)),
      lane_node_id TEXT NULL,
      blocked_seconds INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (run_id, order_id, node_id));
    CREATE TABLE simulation_run_empty_slots (
      run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
      study_id TEXT NOT NULL, slot_at INTEGER NOT NULL, reason TEXT NOT NULL,
      PRIMARY KEY (run_id, study_id, slot_at));
    CREATE TABLE simulation_run_workcenters (
      run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
      workcenter_id TEXT NOT NULL, name TEXT NOT NULL,
      busy_seconds INTEGER NOT NULL, open_seconds INTEGER NOT NULL,
      blocked_seconds INTEGER NOT NULL DEFAULT 0,
      units INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (run_id, workcenter_id));
    CREATE TABLE simulation_run_lanes (
      run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
      study_id TEXT NOT NULL, node_id TEXT NOT NULL, name TEXT NULL,
      position INTEGER NOT NULL, rule TEXT NULL, capacity INTEGER NULL,
      PRIMARY KEY (run_id, node_id));
    CREATE TABLE simulation_run_lane_visits (
      run_id TEXT NOT NULL REFERENCES simulation_runs (id) ON DELETE CASCADE,
      node_id TEXT NOT NULL, order_id TEXT NOT NULL,
      entered INTEGER NOT NULL, left INTEGER NULL,
      PRIMARY KEY (run_id, node_id, order_id));
  """;

  test('v16 to v17: a changeover becomes a setup and keeps its length', () async {
    final file = File(p.join(dir.path, 'flowmap.sqlite'));

    final v16 =
        sqlite3.open(file.path)
          ..execute(
            resourceTables.replaceAll(
              RegExp(r'CREATE TABLE workcenters \([^;]*\);'),
              '',
            ),
          )
          ..execute(v16Workcenters)
          ..execute(projectTables)
          ..execute(v16RunTables)
          ..execute('ALTER TABLE flow_nodes ADD COLUMN inventory_unit TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_value REAL NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_unit TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN lane_rule TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN lane_capacity INTEGER NULL')
          ..execute('ALTER TABLE studies ADD COLUMN start_buffer_days INTEGER NOT NULL DEFAULT 0')
          ..execute('ALTER TABLE studies ADD COLUMN pace_setter_target_id TEXT NULL')
          ..execute('ALTER TABLE workcenter_types ADD COLUMN icon TEXT NULL')
          ..execute(
            'CREATE TABLE workcenter_lines ('
            'workcenter_id TEXT NOT NULL REFERENCES workcenters (id) ON DELETE CASCADE, '
            'line_id TEXT NOT NULL REFERENCES production_lines (id) ON DELETE CASCADE, '
            'created_at INTEGER NOT NULL, PRIMARY KEY (workcenter_id, line_id))',
          )
          ..execute('PRAGMA user_version = 16');

    v16
      ..execute(
        'INSERT INTO plants (id, name, created_at, updated_at) '
        "VALUES ('plant-1', 'Werk Nord', $now, $now)",
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
        'INSERT INTO shift_patterns '
        '(id, name, cycle_type, working_weekdays, created_at, updated_at) '
        "VALUES ('pattern-1', 'ABC', 'fixedWeekly', 31, $now, $now)",
      )
      ..execute(
        'INSERT INTO workcenters (id, plant_id, name, created_at, updated_at) '
        "VALUES ('wc-1', 'plant-1', 'CLAD04', $now, $now)",
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
      );

    // Three nodes, so the carry is shown to be selective rather than blanket: a
    // step with a real changeover, a step explicitly at zero, and an inventory
    // node which never had one.
    for (final (id, position, kind, changeover) in [
      ('node-0', 0, 'step', 5400),
      ('node-1', 1, 'inventory', 0),
      ('node-2', 2, 'step', 0),
    ]) {
      final workcenter = kind == 'step' ? "'wc-1'" : 'NULL';
      v16.execute(
        'INSERT INTO flow_nodes (id, study_id, position, kind, workcenter_id, '
        'changeover_seconds, label, created_at, updated_at) '
        "VALUES ('$id', 'study-1', $position, '$kind', $workcenter, "
        "$changeover, 'node $position', $now, $now)",
      );
    }

    v16
      ..execute(
        'INSERT INTO simulation_runs (id, project_id, dispatch, run_start, '
        'run_end, guard, created_at) '
        "VALUES ('run-1', 'proj-1', 'fifo', $now, $now, $now, $now)",
      )
      ..execute(
        'INSERT INTO simulation_run_studies (run_id, study_id, name, '
        'release_seconds, priority) '
        "VALUES ('run-1', 'study-1', 'Current', 3600, 100)",
      )
      // A step that paid a changeover under the old rule. It is the row that
      // shows `changeover_incurred` survives while `changeover_seconds` arrives
      // null — the two say different things about the same run and only one of
      // them could have been recorded at the time.
      ..execute(
        'INSERT INTO simulation_run_steps (run_id, study_id, order_id, node_id, '
        'workcenter_id, queue_start, process_start, process_end, '
        'changeover_incurred) '
        "VALUES ('run-1', 'study-1', 'order-1', 'node-0', 'wc-1', "
        '$now, $now, $now, 1)',
      )
      ..close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final nodes = await db.select(db.flowNodes).get()
      ..sort((a, b) => a.position.compareTo(b.position));

    // **The changeover carried onto the setup, and its length is unchanged.**
    // 5400 seconds stored as `5400 seconds` rather than `90 minutes`: the unit
    // is literal and resolves identically at every station (§6.1), so this is
    // the same duration written in the one unit that cannot mean two things.
    // Reducing it to `1.5 hours` would have been prettier and would have been
    // the first place a productive day could sneak in.
    expect(nodes[0].setupValue, 5400);
    expect(nodes[0].setupUnit, TaktUnit.seconds);

    // A zero carries as null, on both kinds of node. They meant the same thing
    // — nothing charged — and null is what an untouched node reads as, so the
    // editor shows an empty field rather than a `0 s` nobody typed.
    expect(nodes[1].setupValue, isNull);
    expect(nodes[2].setupValue, isNull);
    expect(nodes[2].setupUnit, isNull);

    // Teardown and the percentage arrive empty on every node, which is what
    // makes the upgrade behaviour-preserving: no node had a teardown to carry
    // and a null percentage is 0 %, exactly the free-repeat rule v16 followed.
    expect(nodes.map((n) => n.teardownValue), everyElement(isNull));
    expect(nodes.map((n) => n.teardownUnit), everyElement(isNull));
    expect(nodes.map((n) => n.samePartPercent), everyElement(isNull));

    // **`changeover_seconds` is not the old column read back.** The source
    // column is still there and still holds what it held, which is what makes a
    // pre-v17 setup recoverable by hand if this carry ever turns out to be
    // wrong for someone.
    expect(nodes[0].changeoverSeconds, 5400);

    // A run stored before v17 says a changeover happened and cannot say what it
    // cost. Null is *made before this column existed*, and it is deliberately
    // not zero — zero would claim the changeover was free, which this run did
    // not observe and cannot now be asked.
    final step = await db.select(db.simulationRunSteps).getSingle();
    expect(step.changeoverIncurred, isTrue);
    expect(step.changeoverSeconds, isNull);

    // The same distinction on the study: it belonged to a cell and a line, and
    // this run predates the columns that would have said which.
    final runStudy = await db.select(db.simulationRunStudies).getSingle();
    expect(runStudy.productionCellId, isNull);
    expect(runStudy.productionCellName, isNull);
    expect(runStudy.productionLineId, isNull);
    expect(runStudy.productionLineName, isNull);

    // The counter reached the end rather than stopping inside the step.
    //
    // Against `schemaVersion` rather than a literal: what this asserts is that
    // the upgrade ran to completion, and pinning the number made a later
    // version's arrival read as this step failing.
    expect(
      await db.customSelect('PRAGMA user_version').getSingle().then(
        (row) => row.data.values.first,
      ),
      db.schemaVersion,
    );
  });

  test('v17 to v18: a run\'s stations arrive without a pool', () async {
    final file = File(p.join(dir.path, 'flowmap.sqlite'));

    // v17's shape: v16's tables plus the five columns v17 added. Built from the
    // hoisted fixture rather than copied, so the two versions cannot drift
    // apart in the one thing they are both supposed to be — the same schema,
    // one step apart.
    final v17 =
        sqlite3.open(file.path)
          ..execute(
            resourceTables.replaceAll(
              RegExp(r'CREATE TABLE workcenters \([^;]*\);'),
              '',
            ),
          )
          ..execute(v16Workcenters)
          ..execute(projectTables)
          ..execute(v16RunTables)
          ..execute('ALTER TABLE flow_nodes ADD COLUMN inventory_unit TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_value REAL NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_unit TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN lane_rule TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN lane_capacity INTEGER NULL')
          ..execute('ALTER TABLE studies ADD COLUMN start_buffer_days INTEGER NOT NULL DEFAULT 0')
          ..execute('ALTER TABLE studies ADD COLUMN pace_setter_target_id TEXT NULL')
          ..execute('ALTER TABLE workcenter_types ADD COLUMN icon TEXT NULL')
          ..execute(
            'CREATE TABLE workcenter_lines ('
            'workcenter_id TEXT NOT NULL REFERENCES workcenters (id) ON DELETE CASCADE, '
            'line_id TEXT NOT NULL REFERENCES production_lines (id) ON DELETE CASCADE, '
            'created_at INTEGER NOT NULL, PRIMARY KEY (workcenter_id, line_id))',
          )
          // v17's own five.
          ..execute('ALTER TABLE flow_nodes ADD COLUMN setup_value REAL NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN setup_unit TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN teardown_value REAL NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN teardown_unit TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN same_part_percent REAL NULL')
          ..execute('ALTER TABLE simulation_run_steps ADD COLUMN changeover_seconds INTEGER NULL')
          ..execute('ALTER TABLE simulation_run_studies ADD COLUMN production_cell_id TEXT NULL')
          ..execute('ALTER TABLE simulation_run_studies ADD COLUMN production_cell_name TEXT NULL')
          ..execute('ALTER TABLE simulation_run_studies ADD COLUMN production_line_id TEXT NULL')
          ..execute('ALTER TABLE simulation_run_studies ADD COLUMN production_line_name TEXT NULL')
          ..execute('PRAGMA user_version = 17');

    v17
      ..execute(
        'INSERT INTO plants (id, name, created_at, updated_at) '
        "VALUES ('plant-1', 'Werk Nord', $now, $now)",
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
        'INSERT INTO shift_patterns '
        '(id, name, cycle_type, working_weekdays, created_at, updated_at) '
        "VALUES ('pattern-1', 'ABC', 'fixedWeekly', 31, $now, $now)",
      )
      ..execute(
        'INSERT INTO workcenters (id, plant_id, name, created_at, updated_at) '
        "VALUES ('wc-1', 'plant-1', 'CLAD07', $now, $now)",
      )
      ..execute(
        'INSERT INTO workcenter_pools (id, plant_id, name, created_at, updated_at) '
        "VALUES ('pool-1', 'plant-1', 'CAL Pool', $now, $now)",
      )
      // **The membership exists in the plant and must not reach the run.** This
      // is the whole point of the step: a v17 run observed no pool, and reading
      // today's grouping into it would make it claim something it never saw
      // (§7.10).
      ..execute(
        'INSERT INTO workcenter_pool_members (pool_id, workcenter_id, created_at) '
        "VALUES ('pool-1', 'wc-1', $now)",
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
        'INSERT INTO simulation_runs (id, project_id, dispatch, run_start, '
        'run_end, guard, created_at) '
        "VALUES ('run-1', 'proj-1', 'fifo', $now, $now, $now, $now)",
      )
      ..execute(
        'INSERT INTO simulation_run_workcenters (run_id, workcenter_id, name, '
        'busy_seconds, open_seconds) '
        "VALUES ('run-1', 'wc-1', 'CLAD07', 3600, 7200)",
      )
      ..close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final station = await db.select(db.simulationRunWorkcenters).getSingle();

    // **Both null, and the pool in the plant is why that matters.** `wc-1` is a
    // member of `CAL Pool` today; this run predates the columns that would have
    // said so, and a backfill from current membership would have it group under
    // a heading it never dispatched through. Null means ungrouped, never
    // "every pool" (§12.1).
    expect(station.poolId, isNull);
    expect(station.poolName, isNull);

    // What the run did record is untouched — the step is additive and rebuilds
    // no table, which is the fourth migration running that can say so (§16.11).
    expect(station.name, 'CLAD07');
    expect(station.busySeconds, 3600);
    expect(station.openSeconds, 7200);

    expect(
      await db.customSelect('PRAGMA user_version').getSingle().then(
        (row) => row.data.values.first,
      ),
      db.schemaVersion,
    );
  });


  test('v18 to v19: two studies\' inventories fold onto one queue', () async {
    final file = File(p.join(dir.path, 'flowmap.sqlite'));

    // v18's shape: the v17 fixture plus v18's two columns. Built from the
    // hoisted strings for the reason the v17 one is — two fixtures claiming to
    // be one schema apart must not drift.
    final v18 =
        sqlite3.open(file.path)
          ..execute(
            resourceTables.replaceAll(
              RegExp(r'CREATE TABLE workcenters \([^;]*\);'),
              '',
            ),
          )
          ..execute(v16Workcenters)
          ..execute(projectTables)
          ..execute(v16RunTables)
          ..execute('ALTER TABLE flow_nodes ADD COLUMN inventory_unit TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_value REAL NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_unit TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN lane_rule TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN lane_capacity INTEGER NULL')
          ..execute('ALTER TABLE studies ADD COLUMN start_buffer_days INTEGER NOT NULL DEFAULT 0')
          ..execute('ALTER TABLE studies ADD COLUMN pace_setter_target_id TEXT NULL')
          ..execute('ALTER TABLE workcenter_types ADD COLUMN icon TEXT NULL')
          ..execute(
            'CREATE TABLE workcenter_lines ('
            'workcenter_id TEXT NOT NULL REFERENCES workcenters (id) ON DELETE CASCADE, '
            'line_id TEXT NOT NULL REFERENCES production_lines (id) ON DELETE CASCADE, '
            'created_at INTEGER NOT NULL, PRIMARY KEY (workcenter_id, line_id))',
          )
          ..execute('ALTER TABLE flow_nodes ADD COLUMN setup_value REAL NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN setup_unit TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN teardown_value REAL NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN teardown_unit TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN same_part_percent REAL NULL')
          ..execute('ALTER TABLE simulation_run_steps ADD COLUMN changeover_seconds INTEGER NULL')
          ..execute('ALTER TABLE simulation_run_studies ADD COLUMN production_cell_id TEXT NULL')
          ..execute('ALTER TABLE simulation_run_studies ADD COLUMN production_cell_name TEXT NULL')
          ..execute('ALTER TABLE simulation_run_studies ADD COLUMN production_line_id TEXT NULL')
          ..execute('ALTER TABLE simulation_run_studies ADD COLUMN production_line_name TEXT NULL')
          ..execute('ALTER TABLE simulation_run_workcenters ADD COLUMN pool_id TEXT NULL')
          ..execute('ALTER TABLE simulation_run_workcenters ADD COLUMN pool_name TEXT NULL')
          ..execute('PRAGMA user_version = 18');

    v18
      ..execute(
        'INSERT INTO plants (id, name, created_at, updated_at) '
        "VALUES ('plant-1', 'Werk Nord', $now, $now)",
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
        'INSERT INTO shift_patterns '
        '(id, name, cycle_type, working_weekdays, created_at, updated_at) '
        "VALUES ('pattern-1', 'ABC', 'fixedWeekly', 31, $now, $now)",
      )
      ..execute(
        'INSERT INTO workcenters (id, plant_id, name, created_at, updated_at) '
        "VALUES ('wc-ban', 'plant-1', 'BAN11', $now, $now)",
      )
      ..execute(
        'INSERT INTO workcenters (id, plant_id, name, created_at, updated_at) '
        "VALUES ('wc-solo', 'plant-1', 'TCN20', $now, $now)",
      )
      ..execute(
        'INSERT INTO projects '
        '(id, name, plant_id, shift_pattern_id, created_at, updated_at) '
        "VALUES ('proj-1', 'H2 2026', 'plant-1', 'pattern-1', $now, $now)",
      );

    // Two studies, both reaching BAN11 — the shape the real database has, and
    // the reason this is a fold rather than a rename. Study `a` sorts first.
    for (final id in ['a-study', 'b-study']) {
      v18.execute(
        'INSERT INTO studies (id, project_id, production_cell_id, '
        'production_line_id, name, created_at, updated_at) '
        "VALUES ('$id', 'proj-1', 'cell-1', 'line-1', '$id', $now, $now)",
      );
    }

    // `a-study`: an inventory naming the lane, then the step it feeds.
    // `b-study`: the same target, a different name, and a rule and capacity
    // `a` left blank.
    for (final (study, pos, kind, label, rule, cap, target) in [
      ('a-study', 0, 'inventory', 'FIFO BAN', null, null, null),
      ('a-study', 1, 'step', null, null, null, 'wc-ban'),
      ('b-study', 0, 'inventory', 'FIFO BAN11', 'shortestProcessing', 3, null),
      ('b-study', 1, 'step', null, null, null, 'wc-ban'),
      // A queue nothing shares, so the ordinary case is covered too.
      ('b-study', 2, 'inventory', 'FIFO TCN', null, null, null),
      ('b-study', 3, 'step', null, null, null, 'wc-solo'),
      // And an inventory with no step after it: a queue in front of nothing.
      ('b-study', 4, 'inventory', 'FIFO NOWHERE', null, null, null),
    ]) {
      final wc = target == null ? 'NULL' : "'$target'";
      final lbl = label == null ? 'NULL' : "'$label'";
      final rl = rule == null ? 'NULL' : "'$rule'";
      final cp = cap?.toString() ?? 'NULL';
      v18.execute(
        'INSERT INTO flow_nodes (id, study_id, position, kind, workcenter_id, '
        'label, lane_rule, lane_capacity, changeover_seconds, created_at, '
        'updated_at) '
        "VALUES ('$study-$pos', '$study', $pos, '$kind', $wc, $lbl, $rl, $cp, "
        '0, $now, $now)',
      );
    }
    v18.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final queues = await db.select(db.projectQueues).get()
      ..sort((a, b) => a.targetId.compareTo(b.targetId));

    // Three inventory nodes across two studies land on **two** queues, and the
    // fourth — the one feeding no step — lands on none.
    expect(queues.map((q) => q.targetId), ['wc-ban', 'wc-solo']);

    // **A later node fills what the first left blank.** `a` set no rule and no
    // capacity, so `b`'s survive.
    //
    // *The name half of this rule is no longer observable*: v27 dropped
    // `project_queues.name`, and this database is opened at the current
    // version, so the fold's "first study wins the name" — `FIFO BAN` over
    // `FIFO BAN11` — is gone by the time the row can be read. The fold still
    // does it, and still logs what it discarded; what is asserted here is the
    // half that survives into the schema.
    final ban = queues.first;
    expect(ban.rule, DispatchRule.shortestProcessing);
    expect(ban.capacity, 3);

    // **The inventory rows are still there.** They stop being read; they are
    // not deleted, because they are the recovery path for `FIFO BAN11`.
    final nodes = await db.select(db.flowNodes).get();
    expect(
      nodes.where((n) => n.kind == FlowNodeKind.inventory),
      hasLength(4),
    );

    // **v20 rides along, and its whole claim is that it changes nothing.**
    // Asserted here rather than from a fixture of its own because it carries
    // four nullable columns and no carry — there is nothing to isolate, and
    // §16.18's warning about a fixture full of nulls is about a migration that
    // *moves* data, which this one deliberately does not.
    //
    // Rebalancing is on for every step that already existed, which is what a
    // null in a disable flag means (§7.7.4).
    expect(
      nodes.every((n) => n.balanceDisabled == null),
      isTrue,
      reason: 'a pre-v20 step must keep rebalancing on',
    );

    // And the run's three takt columns land. Asserted against the table's own
    // shape rather than against rows, because this fixture stores no run —
    // a `every()` over an empty list passes whether or not the columns exist,
    // which is §16.18's warning arriving from the other direction.
    final columns = await db
        .customSelect('PRAGMA table_info(simulation_run_studies)')
        .get();
    expect(
      columns.map((row) => row.data['name']),
      containsAll(['takt_value', 'takt_unit', 'next_takt_change']),
    );

    // **v21 rides along on the same terms**, and is asserted the same way and
    // for the same reason: one nullable column, no carry, and no row in this
    // fixture to carry it — so the claim worth making is that the column
    // exists on a table that predates it, not that some row is null.
    final stepColumns = await db
        .customSelect('PRAGMA table_info(simulation_run_steps)')
        .get();
    expect(
      stepColumns.map((row) => row.data['name']),
      contains('process_seconds'),
    );

    // **And v22 on the same terms again** (§7.9): the takt each order opened
    // under, and where a study's cadence ran out. Three nullable columns on two
    // tables that predate them, so what is worth asserting is that they arrived
    // on the old tables rather than that some row is null.
    final orderColumns = await db
        .customSelect('PRAGMA table_info(simulation_run_orders)')
        .get();
    expect(
      orderColumns.map((row) => row.data['name']),
      containsAll(['takt_value', 'takt_unit']),
    );
    expect(
      columns.map((row) => row.data['name']),
      contains('cadence_ended_at'),
    );

    expect(
      await db.customSelect('PRAGMA user_version').getSingle().then(
        (row) => row.data.values.first,
      ),
      db.schemaVersion,
    );
  });

  test('v19 folds once, however often the upgrade is replayed', () async {
    // §16.11's shape: an upgrade that died after the fold and replays from a
    // counter that no longer describes the tables. Folding twice would
    // overwrite a queue the user has since edited, so the step is guarded on
    // the table being empty rather than on `from`.
    final file = File(p.join(dir.path, 'flowmap.sqlite'));

    final v18 =
        sqlite3.open(file.path)
          ..execute(
            resourceTables.replaceAll(
              RegExp(r'CREATE TABLE workcenters \([^;]*\);'),
              '',
            ),
          )
          ..execute(v16Workcenters)
          ..execute(projectTables)
          ..execute(v16RunTables)
          // Faithful to v18 rather than minimal: `inventory_unit` arrives at v4
          // and the fold reads it, so a fixture without it is not a database
          // that could ever reach v19.
          ..execute('ALTER TABLE flow_nodes ADD COLUMN inventory_unit TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_value REAL NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN equivalent_unit TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN lane_rule TEXT NULL')
          ..execute('ALTER TABLE flow_nodes ADD COLUMN lane_capacity INTEGER NULL')
          ..execute('ALTER TABLE studies ADD COLUMN start_buffer_days INTEGER NOT NULL DEFAULT 0')
          ..execute('ALTER TABLE studies ADD COLUMN pace_setter_target_id TEXT NULL')
          // Reference-data seeding runs on every upgrade, and it writes an
          // icon — so a v18 fixture without the column fails on the seed rather
          // than on anything this test is about.
          ..execute('ALTER TABLE workcenter_types ADD COLUMN icon TEXT NULL')
          ..execute('PRAGMA user_version = 18')
          ..execute(
            'INSERT INTO plants (id, name, created_at, updated_at) '
            "VALUES ('plant-1', 'Werk Nord', $now, $now)",
          )
          ..execute(
            'INSERT INTO shift_patterns '
            '(id, name, cycle_type, working_weekdays, created_at, updated_at) '
            "VALUES ('pattern-1', 'ABC', 'fixedWeekly', 31, $now, $now)",
          )
          ..execute(
            'INSERT INTO workcenters (id, plant_id, name, created_at, updated_at) '
            "VALUES ('wc-1', 'plant-1', 'CLAD07', $now, $now)",
          )
          ..execute(
            'INSERT INTO projects '
            '(id, name, plant_id, shift_pattern_id, created_at, updated_at) '
            "VALUES ('proj-1', 'H2 2026', 'plant-1', 'pattern-1', $now, $now)",
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
            'INSERT INTO studies (id, project_id, production_cell_id, '
            'production_line_id, name, created_at, updated_at) '
            "VALUES ('study-1', 'proj-1', 'cell-1', 'line-1', 'Current', $now, $now)",
          )
          ..execute(
            'INSERT INTO flow_nodes (id, study_id, position, kind, label, '
            'changeover_seconds, created_at, updated_at) '
            "VALUES ('n0', 'study-1', 0, 'inventory', 'FIFO CLAD', 0, $now, $now)",
          )
          ..execute(
            'INSERT INTO flow_nodes (id, study_id, position, kind, '
            'workcenter_id, changeover_seconds, created_at, updated_at) '
            "VALUES ('n1', 'study-1', 1, 'step', 'wc-1', 0, $now, $now)",
          );
    v18.close();

    final first = AppDatabase(NativeDatabase(file));
    await first.select(first.projectQueues).get();
    // The user edits the queue after the upgrade. **Capacity rather than the
    // name**, which v27 dropped — the point of the test is that a replayed fold
    // must not overwrite an edit, and any surviving column proves it.
    await first.customStatement('UPDATE project_queues SET capacity = 42');
    await first.close();

    // Wind the counter back, as an interrupted upgrade leaves it.
    final rewound = sqlite3.open(file.path)
      ..execute('PRAGMA user_version = 18');
    rewound.close();

    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final queues = await second.select(second.projectQueues).get();

    expect(queues, hasLength(1));
    expect(
      queues.single.capacity,
      42,
      reason: 'the fold ran once; a replay must not undo an edit',
    );
  });

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

    final orders = await db.select(db.demandOrders).get();
    expect(orders.single.sequence, 0);
    expect(orders.single.batchSize, 6);
    expect(orders.single.customerProject, isNull);

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

  group('v22 to v23: a stay in a queue belongs to a step (§8.6)', () {
    /// Puts an existing database back into v22's shape for this one table and
    /// stamps the version, so the v23 step runs against what it will actually
    /// meet.
    ///
    /// **Built by regressing the current schema rather than by hand.** Every
    /// fixture above builds its era from scratch, which is right when the
    /// migration reaches across many tables; this one touches exactly one, and
    /// a hand-built v22 of the whole database would be four hundred lines that
    /// could drift from the twenty-two steps above it.
    Future<File> v22WithVisits({
      required List<({String order, String lane, String? step})> visits,
    }) async {
      final file = File(p.join(dir.path, 'flowmap.sqlite'));

      // Create at the current version, then seed the rows the migration reads.
      final fresh = AppDatabase(NativeDatabase(file));
      await fresh.customStatement('PRAGMA foreign_keys = OFF');
      await fresh.customStatement(
        "INSERT INTO simulation_runs (id, project_id, dispatch, run_start, "
        "run_end, guard, created_at) VALUES "
        "('run-1', 'proj-1', 'fifo', 0, 1, 2, 3)",
      );
      for (final v in visits.where((v) => v.step != null)) {
        await fresh.customStatement(
          "INSERT INTO simulation_run_steps (run_id, study_id, order_id, "
          "node_id, workcenter_id, queue_start, process_start, process_end, "
          "changeover_incurred, lane_node_id) VALUES "
          "('run-1', 'study-1', '${v.order}', '${v.step}', 'wc-1', "
          "10, 20, 30, 0, '${v.lane}')",
        );
      }
      await fresh.close();

      // Now put the one table back the way v22 had it, rows and all.
      final raw = sqlite3.open(file.path)
        ..execute('DROP TABLE simulation_run_lane_visits')
        ..execute('''
          CREATE TABLE simulation_run_lane_visits (
            run_id TEXT NOT NULL REFERENCES simulation_runs (id)
              ON DELETE CASCADE,
            study_id TEXT NOT NULL,
            order_id TEXT NOT NULL,
            node_id TEXT NOT NULL,
            entered_at INTEGER NOT NULL,
            left_at INTEGER NULL,
            PRIMARY KEY (run_id, order_id, node_id))
        ''');
      for (final v in visits) {
        raw.execute(
          "INSERT INTO simulation_run_lane_visits VALUES "
          "('run-1', 'study-1', '${v.order}', '${v.lane}', 10, 20)",
        );
      }
      raw
        ..execute('PRAGMA user_version = 22')
        ..close();
      return file;
    }

    test('a stay that produced a step is matched to it', () async {
      final file = await v22WithVisits(
        visits: [(order: 'o0', lane: 'wc-2', step: 'node-1')],
      );

      final db = AppDatabase(NativeDatabase(file));
      final rows = await db.select(db.simulationRunLaneVisits).get();
      expect(rows.length, 1);
      expect(rows.single.targetId, 'wc-2', reason: 'node_id held the station');
      expect(
        rows.single.stepNodeId,
        'node-1',
        reason: 'backfilled from the step the writer derived it from',
      );
      expect(rows.single.enteredAt.millisecondsSinceEpoch, isNotNull);
      await db.close();
    });

    test('a stay with no step keeps the station as its surrogate', () async {
      // An order the guard caught still queueing produced no step, so there is
      // nothing to name. v22's own key guaranteed at most one such row per
      // order per station, so the target collides with nothing.
      final file = await v22WithVisits(
        visits: [(order: 'o9', lane: 'wc-2', step: null)],
      );

      final db = AppDatabase(NativeDatabase(file));
      final rows = await db.select(db.simulationRunLaneVisits).get();
      expect(rows.length, 1, reason: 'the row is carried, not dropped');
      expect(rows.single.stepNodeId, 'wc-2');
      await db.close();
    });

    test('nothing is lost across a mixed table', () async {
      final file = await v22WithVisits(
        visits: [
          (order: 'o0', lane: 'wc-1', step: 'node-0'),
          (order: 'o0', lane: 'wc-2', step: 'node-1'),
          (order: 'o1', lane: 'wc-1', step: 'node-0'),
          (order: 'o9', lane: 'wc-2', step: null),
        ],
      );

      final db = AppDatabase(NativeDatabase(file));
      final rows = await db.select(db.simulationRunLaneVisits).get();
      expect(rows.length, 4, reason: 'every v22 row survives the rebuild');
      expect(
        rows.map((r) => '${r.orderId}/${r.targetId}').toSet(),
        {'o0/wc-1', 'o0/wc-2', 'o1/wc-1', 'o9/wc-2'},
      );
      await db.close();
    });

    test('the new key admits what the old one refused', () async {
      // The defect itself, at the far end of a migration: once upgraded, the
      // table takes two stays of one order in one station's queue — which is
      // what a part going back for a second operation produces, and what v22
      // rejected with a UNIQUE constraint after the run had been computed.
      final file = await v22WithVisits(
        visits: [(order: 'o0', lane: 'wc-2', step: 'node-1')],
      );

      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement(
        "INSERT INTO simulation_run_lane_visits (run_id, study_id, order_id, "
        "target_id, step_node_id, entered_at, left_at) VALUES "
        "('run-1', 'study-1', 'o0', 'wc-2', 'node-2', 40, 50)",
      );
      final rows = await db.select(db.simulationRunLaneVisits).get();
      expect(rows.where((r) => r.orderId == 'o0').length, 2);
      await db.close();
    });
  });

  group('v23 to v24: a process time belongs to a step (§9)', () {
    /// Regresses `part_process_times` to its v23 shape and stamps the version,
    /// so the v24 step runs against what it will actually meet.
    ///
    /// [steps] are `(nodeId, targetId)` pairs inserted into one study, and
    /// [times] are `(partId, targetId)` rows in the old shape.
    Future<File> v23With({
      required List<(String, String)> steps,
      required List<(String, String, int)> times,
    }) async {
      final file = File(p.join(dir.path, 'flowmap.sqlite'));
      final fresh = AppDatabase(NativeDatabase(file));
      await fresh.customStatement('PRAGMA foreign_keys = OFF');
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await fresh.customStatement(
        "INSERT INTO studies (id, project_id, production_cell_id, "
        "production_line_id, name, created_at, updated_at) VALUES "
        "('study-1', 'proj-1', 'cell-1', 'line-1', 'S', $now, $now)",
      );
      for (final (i, (nodeId, targetId)) in steps.indexed) {
        await fresh.customStatement(
          "INSERT INTO flow_nodes (id, study_id, position, kind, "
          "workcenter_id, created_at, updated_at) VALUES "
          "('$nodeId', 'study-1', $i, 'step', '$targetId', $now, $now)",
        );
      }
      for (final (partId, _, _) in times.toSet()) {
        await fresh.customStatement(
          "INSERT OR IGNORE INTO demand_parts (id, study_id, part_number, "
          "created_at, updated_at) VALUES "
          "('$partId', 'study-1', '$partId', $now, $now)",
        );
      }
      await fresh.close();

      final raw = sqlite3.open(file.path)
        ..execute('DROP TABLE part_process_times')
        ..execute('''
          CREATE TABLE part_process_times (
            part_id TEXT NOT NULL REFERENCES demand_parts (id)
              ON DELETE CASCADE,
            target_id TEXT NOT NULL,
            seconds INTEGER NOT NULL,
            PRIMARY KEY (part_id, target_id))
        ''');
      for (final (partId, targetId, seconds) in times) {
        raw.execute(
          "INSERT INTO part_process_times VALUES "
          "('$partId', '$targetId', $seconds)",
        );
      }
      raw
        ..execute('PRAGMA user_version = 23')
        ..close();
      return file;
    }

    test('a time follows its target onto the step that points there', () async {
      final file = await v23With(
        steps: [('node-1', 'wc-1')],
        times: [('part-a', 'wc-1', 7200)],
      );

      final db = AppDatabase(NativeDatabase(file));
      final rows = await db.select(db.partProcessTimes).get();
      expect(rows.single.nodeId, 'node-1');
      expect(rows.single.seconds, 7200);
      await db.close();
    });

    test('a station used twice becomes two cells at the same value', () async {
      // **What the round is for.** They start equal, so nothing about today's
      // numbers changes — and they can now diverge, which is what a routing
      // revisit means.
      final file = await v23With(
        steps: [('node-1', 'wc-1'), ('node-2', 'wc-2'), ('node-3', 'wc-1')],
        times: [('part-a', 'wc-1', 7200), ('part-a', 'wc-2', 3600)],
      );

      final db = AppDatabase(NativeDatabase(file));
      final rows = await db.select(db.partProcessTimes).get();
      expect(rows.length, 3, reason: 'two rows became three');
      expect(
        {for (final r in rows) r.nodeId: r.seconds},
        {'node-1': 7200, 'node-3': 7200, 'node-2': 3600},
      );
      await db.close();
    });

    test('a time whose target has no step is dropped', () async {
      // The only step in this file that removes anything. On the live database
      // it was 8 rows of 279 — left behind when a step was deleted or
      // repointed after somebody had typed a time, already drawn by no column
      // and read by no run.
      final file = await v23With(
        steps: [('node-1', 'wc-1')],
        times: [('part-a', 'wc-1', 7200), ('part-a', 'wc-9', 999)],
      );

      final db = AppDatabase(NativeDatabase(file));
      final rows = await db.select(db.partProcessTimes).get();
      expect(rows.map((r) => r.nodeId), ['node-1']);
      await db.close();
    });

    test('the new key admits what the old one could not hold', () async {
      // Two visits, two different times — impossible under v23, where the two
      // steps shared one row keyed by the station.
      final file = await v23With(
        steps: [('node-1', 'wc-1'), ('node-2', 'wc-1')],
        times: [('part-a', 'wc-1', 7200)],
      );

      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement(
        "UPDATE part_process_times SET seconds = 1800 "
        "WHERE node_id = 'node-2'",
      );
      final rows = await db.select(db.partProcessTimes).get();
      expect(
        {for (final r in rows) r.nodeId: r.seconds},
        {'node-1': 7200, 'node-2': 1800},
        reason: 'the second pass is charged its own work',
      );
      await db.close();
    });
  });
  group('v24 to v25: what a run must carry to be graphed (§10.2)', () {
    /// A v24 database holding one stored run, with the three things v25 adds
    /// absent — which is exactly what a real one arrives with.
    Future<File> v24WithARun() async {
      final file = File(p.join(dir.path, 'flowmap.sqlite'));
      final fresh = AppDatabase(NativeDatabase(file));
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await fresh.customStatement('PRAGMA foreign_keys = OFF');
      await fresh.customStatement(
        "INSERT INTO simulation_runs (id, project_id, dispatch, run_start, "
        "run_end, guard, created_at) VALUES "
        "('run-1', 'proj-1', '', $now, $now, $now, $now)",
      );
      await fresh.customStatement(
        "INSERT INTO simulation_run_steps (run_id, study_id, order_id, "
        "node_id, workcenter_id, queue_start, process_start, process_end, "
        "process_seconds) VALUES "
        "('run-1', 'study-1', 'order-1', 'node-1', 'wc-1', $now, $now, $now, "
        "3737)",
      );
      await fresh.customStatement(
        "INSERT INTO simulation_run_workcenters (run_id, workcenter_id, name, "
        "busy_seconds, open_seconds) VALUES "
        "('run-1', 'wc-1', 'CLAD06', 100, 200)",
      );
      await fresh.close();

      sqlite3.open(file.path)
        ..execute('ALTER TABLE simulation_run_steps '
            'DROP COLUMN process_seconds_before_rework')
        ..execute('ALTER TABLE simulation_run_workcenters DROP COLUMN type_id')
        ..execute(
          'ALTER TABLE simulation_run_workcenters DROP COLUMN type_name',
        )
        ..execute('DROP TABLE simulation_run_workcenter_months')
        ..execute('PRAGMA user_version = 24')
        ..close();
      return file;
    }

    test('the two columns and the table arrive, and no rebuild is needed',
        () async {
      final file = await v24WithARun();

      final db = AppDatabase(NativeDatabase(file));
      // Opening it runs the migration; the assertion is that all three landed.
      final step = await db.select(db.simulationRunSteps).getSingle();
      final station = await db.select(db.simulationRunWorkcenters).getSingle();
      final months = await db.select(db.simulationRunWorkcenterMonths).get();

      expect(step.processSecondsBeforeRework, isNull);
      expect(station.typeId, isNull);
      expect(station.typeName, isNull);
      expect(months, isEmpty);
      await db.close();
    });

    test('the run it found is left exactly as it was', () async {
      // **No backfill, deliberately** (§10.2). `process_seconds` is
      // `work × (1 + rework)` with the rework gone, so there is nothing to
      // recover it from — and inventing a figure out of today's schedules would
      // draw a 2025 capacity line from a plant retuned in 2026. A run that
      // cannot be graphed says so by holding nulls.
      final file = await v24WithARun();

      final db = AppDatabase(NativeDatabase(file));
      final step = await db.select(db.simulationRunSteps).getSingle();

      expect(step.processSeconds, 3737, reason: 'the old figure is untouched');
      expect(step.workcenterId, 'wc-1');
      await db.close();
    });

    test('a second open is a no-op', () async {
      // The rule at the top of `onUpgrade`: a migration is not atomic, so every
      // step has to tolerate having already run.
      final file = await v24WithARun();

      final first = AppDatabase(NativeDatabase(file));
      await first.select(first.simulationRunSteps).get();
      await first.close();

      final second = AppDatabase(NativeDatabase(file));
      final version = await second
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), second.schemaVersion);
      expect(await second.select(second.simulationRunSteps).get(), hasLength(1));
      await second.close();
    });
  });

  group('v25 to v26: where the float matrix turns red (§10.4)', () {
    test('every project gets the defaults, and nothing else moves', () async {
      // **Not a backfill in §10.2's sense.** These are thresholds for *reading*
      // a figure rather than a record of what the plant was, so a default is
      // the right answer where an invented capacity would not be. Nothing about
      // any stored run changes.
      final file = File(p.join(dir.path, 'flowmap.sqlite'));
      final fresh = AppDatabase(NativeDatabase(file));
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await fresh.customStatement('PRAGMA foreign_keys = OFF');
      await fresh.customStatement(
        "INSERT INTO projects (id, name, plant_id, shift_pattern_id, "
        "created_at, updated_at) VALUES "
        "('proj-1', 'Old', 'plant-1', 'pattern-1', $now, $now)",
      );
      await fresh.close();

      sqlite3.open(file.path)
        ..execute('ALTER TABLE projects DROP COLUMN float_red_days')
        ..execute('ALTER TABLE projects DROP COLUMN float_green_days')
        ..execute('PRAGMA user_version = 25')
        ..close();

      final db = AppDatabase(NativeDatabase(file));
      final project = await (db.select(
        db.projects,
      )..where((p) => p.id.equals('proj-1'))).getSingle();

      expect(project.floatRedDays, 0);
      expect(project.floatGreenDays, 30);
      expect(project.name, 'Old', reason: 'the row is otherwise untouched');
      await db.close();
    });
  });

  group('v26 to v27: a queue is an aspect, and a box is its station (#5)', () {
    /// A v26 database with both columns present and filled, so the step can
    /// actually be exercised rather than skipped.
    Future<File> v26() async {
      final file = File(p.join(dir.path, 'flowmap.sqlite'));
      final fresh = AppDatabase(NativeDatabase(file));
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await fresh.customStatement('PRAGMA foreign_keys = OFF');
      await fresh.customStatement(
        "INSERT INTO projects (id, name, plant_id, shift_pattern_id, "
        "created_at, updated_at) VALUES "
        "('proj-1', 'P', 'plant-1', 'pattern-1', $now, $now)",
      );
      await fresh.customStatement(
        'INSERT INTO studies (id, project_id, production_cell_id, '
        'production_line_id, name, created_at, updated_at) '
        "VALUES ('study-1', 'proj-1', 'cell-1', 'line-1', 'S', $now, $now)",
      );
      await fresh.close();

      // Put the two columns back, exactly as a v26 database has them, and fill
      // each with the shape the live database actually holds.
      sqlite3.open(file.path)
        ..execute('ALTER TABLE project_queues ADD COLUMN name TEXT')
        ..execute('ALTER TABLE flow_nodes ADD COLUMN label TEXT')
        ..execute(
          'INSERT INTO project_queues (project_id, target_id, name, rule, '
          'capacity, created_at, updated_at) VALUES '
          "('proj-1', 'wc-1', 'FIFO CEU 21', 'fifo', 3, $now, $now)",
        )
        ..execute(
          'INSERT INTO flow_nodes (id, study_id, position, kind, '
          'workcenter_id, label, changeover_seconds, created_at, updated_at) '
          "VALUES ('n1', 'study-1', 0, 'step', 'wc-1', 'CLAD Pool', 0, "
          '$now, $now)',
        )
        ..execute('PRAGMA user_version = 26')
        ..close();
      return file;
    }

    test('both columns go, and every other value survives', () async {
      final db = AppDatabase(NativeDatabase(await v26()));
      addTearDown(db.close);

      // The rows are kept; only the two names are dropped. A queue was never
      // identity — its key is its target — so nothing here is lost that the
      // caption cannot derive.
      final queue = await db.select(db.projectQueues).getSingle();
      expect(queue.targetId, 'wc-1');
      expect(queue.rule, DispatchRule.fifo);
      expect(queue.capacity, 3);

      final node = await db.select(db.flowNodes).getSingle();
      expect(node.id, 'n1');
      expect(node.workcenterId, 'wc-1');
      expect(node.position, 0);

      // Asked of the database rather than inferred from the row class, because
      // it is the *table* the migration had to rebuild.
      Future<bool> hasColumn(String table, String column) async =>
          (await db.customSelect('PRAGMA table_info($table)').get()).any(
            (row) => row.read<String>('name') == column,
          );
      expect(await hasColumn('project_queues', 'name'), isFalse);
      expect(await hasColumn('flow_nodes', 'label'), isFalse);
    });

    test('running it twice is a no-op, as an interrupted upgrade replays', () async {
      final file = await v26();
      final first = AppDatabase(NativeDatabase(file));
      await first.select(first.projectQueues).get();
      await first.close();

      // Wind the counter back, as an interrupted upgrade leaves it. The step
      // asks the database what it has rather than trusting `from`, so it finds
      // the columns already gone and does nothing.
      sqlite3.open(file.path)
        ..execute('PRAGMA user_version = 26')
        ..close();

      final second = AppDatabase(NativeDatabase(file));
      addTearDown(second.close);
      expect(await second.select(second.projectQueues).get(), hasLength(1));
      expect(await second.select(second.flowNodes).get(), hasLength(1));
    });
  });

}
