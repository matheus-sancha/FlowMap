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
    expect(parts.single.customerProject, isNull);

    final orders = await db.select(db.demandOrders).get();
    expect(orders.single.id, 'order-1');
    expect(orders.single.batchSize, 4);
    expect(orders.single.sequence, 0);
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
