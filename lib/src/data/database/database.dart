import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../features/diagnostics/application/diagnostics.dart';
import '../app_directory.dart';
import 'enums.dart';
import 'project_tables.dart';
import 'seed_data.dart';
import 'simulation_tables.dart';
import 'tables.dart';

part 'database.g.dart';

const _uuid = Uuid();

/// Settings key recording when reference data was last offered.
///
/// Paired with an "is the table empty" check rather than used alone: emptiness
/// on its own refills a table the user deliberately cleared, and this stamp on
/// its own never reaches someone who installed before a seed existed. The stamp
/// is written even in the branch that seeds nothing, so a later deletion does
/// not read as "never offered" (DATA.md).
const _seededAtKey = 'reference_data.seeded_at';

@DriftDatabase(
  tables: [
    ShiftPatterns,
    PatternShifts,
    Plants,
    ProductionCells,
    ProductionLines,
    WorkcenterTypes,
    Workcenters,
    WorkcenterLines,
    WorkcenterPools,
    WorkcenterPoolMembers,
    AppSettings,
    Projects,
    CalendarExceptions,
    TaktPeriods,
    WorkcenterSchedulePeriods,
    Studies,
    FlowNodes,
    FlowAnnotations,
    DemandParts,
    PartProcessTimes,
    DemandOrders,
    SimulationRuns,
    SimulationRunStudies,
    SimulationRunOrders,
    SimulationRunSteps,
    SimulationRunEmptySlots,
    SimulationRunWorkcenters,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database. Pass an explicit [executor] (e.g.
  /// `NativeDatabase.memory()`) in tests to run against an in-memory database.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openOnDevice());

  static QueryExecutor _openOnDevice() => LazyDatabase(() async {
    final dir = await appDataDirectory();
    await dir.create(recursive: true);
    return NativeDatabase.createInBackground(
      File(p.join(dir.path, 'flowmap.sqlite')),
    );
  });

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedReferenceData();
    },
    onUpgrade: (m, from, to) async {
      // **Every step below asks the database what it has rather than inferring
      // it from `from`.**
      //
      // A migration cannot run inside a transaction: `alterTable` needs
      // foreign keys off, and SQLite refuses to change that mid-transaction.
      // So a step that throws leaves the database *part* upgraded with its
      // version counter unchanged, and every later open replays from a number
      // that no longer describes the tables. A machine here reached exactly
      // that — `user_version` 6, `workcenters` already rebuilt by the v7 step,
      // `demand_parts` still in its v6 shape — and could not be opened again
      // at all, because the first thing this function did was read a column
      // the v7 step had already dropped.
      //
      // Version-based guards cannot express that state, and the `from >= 2` /
      // `from >= 6` guards this replaces were the same lesson learned one
      // column at a time (DATA.md). Asking is cheap, and it is the only thing
      // that is true on a database nobody can inspect.
      final homeLines = await _hasColumn('workcenters', 'home_line_id')
          ? await customSelect(
              'SELECT id, home_line_id FROM workcenters '
              'WHERE home_line_id IS NOT NULL',
            ).get()
          : const <QueryRow>[];

      if (from < 2) {
        // M2: the project layer. Purely additive — every table below is
        // new, so `createTable` from the current definition is safe and no
        // existing row is touched.
        await _ensureTable(m, projects);
        await _ensureTable(m, calendarExceptions);
        await _ensureTable(m, taktPeriods);
        await _ensureTable(m, workcenterSchedulePeriods);
        await _ensureTable(m, studies);
        await _ensureTable(m, flowNodes);
        await _ensureTable(m, flowAnnotations);
      }

      if (from < 3) {
        // `workcenters.code` is gone: in practice every user filled it with
        // the same value as `name`. A table rebuild, because SQLite cannot
        // drop a column in place on the versions this app runs against.
        // TableMigration copies by name from the current Dart definition, so
        // the dropped column is simply not carried across — and every other
        // value survives whatever column order this machine's table has,
        // which is the reason not to hand-roll the copy.
        if (await _hasColumn('workcenters', 'code')) {
          await m.alterTable(TableMigration(workcenters));
        }
      }

      if (from < 4) {
        // A fixed inventory wait remembers the unit it was typed in. Additive
        // and nullable — rows written before this read as hours, the unit the
        // editor offered at the time.
        //
        // A v1 database already has this column: the v2 step above builds
        // `flow_nodes` from the *current* Dart definition, which carries it.
        // `_ensureColumn` is what makes that a fact to check rather than a
        // version to remember (DATA.md).
        await _ensureColumn(m, flowNodes, flowNodes.inventoryUnit);
      }

      if (from < 5) {
        // A step may state the flow equivalent's process time itself.
        await _ensureColumn(m, flowNodes, flowNodes.equivalentValue);
        await _ensureColumn(m, flowNodes, flowNodes.equivalentUnit);
      }

      if (from < 6) {
        // M3: the demand table. Three new tables and no change to an existing
        // one, so building them from the current definition is safe at any
        // starting version.
        await _ensureTable(m, demandParts);
        await _ensureTable(m, partProcessTimes);
        await _ensureTable(m, demandOrders);
      }

      if (from < 7) {
        // A workcenter is drawn under a *set* of lines, not one. The single
        // `workcenters.home_line_id` this replaces meant filing `CLAD04` under
        // a second line silently took it out of the first — the tree fought
        // the very arrangement the app exists to analyse (DESIGN.md §7.7).
        //
        // Rebuilt only if the column is still there: a v1 or v2 database has
        // already been rebuilt by the v3 step above, from a definition that no
        // longer carries it, and so has a database whose upgrade died after
        // this point last time.
        if (await _hasColumn('workcenters', 'home_line_id')) {
          await m.alterTable(TableMigration(workcenters));
        }
        await _ensureTable(m, workcenterLines);

        // The old home line becomes a set of one, so nobody's tree rearranges
        // itself under them on upgrade.
        final now = DateTime.now();
        await batch((b) {
          for (final row in homeLines) {
            b.insert(
              workcenterLines,
              WorkcenterLinesCompanion.insert(
                workcenterId: row.read<String>('id'),
                lineId: row.read<String>('home_line_id'),
                createdAt: now,
              ),
            );
          }
        });
      }

      if (from < 8) {
        // A workcenter type carries an icon. Additive and nullable, so a type
        // created before this simply draws the default.
        await _ensureColumn(m, workcenterTypes, workcenterTypes.icon);
      }

      if (from < 9) {
        // A part carries the **customer's** project — their programme, not the
        // FlowMap project the study sits in.
        await _ensureColumn(m, demandParts, demandParts.customerProject);

        // `demand_orders.order_number` is gone. A simulation identifies an
        // order by the row it is; asking a planner to type a works order
        // number they already hold in their own system was work for nothing.
        // A table rebuild, because SQLite cannot drop a column in place on the
        // versions this app runs against — and only if the column is still
        // there, because a database older than v6 got `demand_orders` from the
        // *current* definition at the v6 step and never had it.
        if (await _hasColumn('demand_orders', 'order_number')) {
          await m.alterTable(TableMigration(demandOrders));
        }
      }

      if (from < 10) {
        // A part is identified by its project **and** its number: the same part
        // number is legitimately ordered by two clients' projects, and they are
        // two rows of demand with their own times and their own place in the
        // sequence. The unique key gains the project, and the column stops
        // being nullable so SQLite cannot treat two unprojected parts as
        // distinct (the `scope_id` lesson, §16.2).
        await m.alterTable(
          TableMigration(
            demandParts,
            columnTransformer: {
              demandParts.customerProject: coalesce([
                demandParts.customerProject,
                const Constant(''),
              ]),
            },
          ),
        );
      }

      if (from < 11) {
        // M4: where a run is kept (DESIGN.md §7.10). Six new tables and no
        // change to an existing one, so building them from the current
        // definition is safe at any starting version.
        await _ensureTable(m, simulationRuns);
        await _ensureTable(m, simulationRunStudies);
        await _ensureTable(m, simulationRunOrders);
        await _ensureTable(m, simulationRunSteps);
        await _ensureTable(m, simulationRunEmptySlots);
        await _ensureTable(m, simulationRunWorkcenters);
      }

      // Reference-data seeding runs outside every version guard, on every
      // upgrade, so content added to a later build reaches the people
      // already running the app — who are exactly who it is for.
      await seedReferenceData();
    },
    beforeOpen: (details) async {
      // SQLite has foreign keys OFF by default, and they stay off during
      // migration — which is what makes a rename/copy/drop rebuild safe.
      await customStatement('PRAGMA foreign_keys = ON');
      // Logged here rather than in the session header: the database opens
      // lazily on first query, long after that header is written, and
      // "fresh install or upgrade?" resolves a surprising share of reports.
      Diag.event(
        'db.open',
        'schema ${details.versionNow} '
            '${details.wasCreated ? 'created' : 'from ${details.versionBefore}'}',
      );
    },
  );

  // --- Asking the database what it has ------------------------------------
  //
  // A migration is not atomic — see the note at the top of `onUpgrade` — so
  // `from` says where the counter stopped, not what the tables look like. A
  // step that has already run must be a no-op rather than an error, or one
  // interrupted upgrade locks the user out of their own data for good.

  Future<bool> _hasTable(String name) async =>
      (await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(name)],
      ).get()).isNotEmpty;

  /// Interpolated rather than bound: `PRAGMA` takes no parameters, and every
  /// caller passes a table name written in this file.
  Future<bool> _hasColumn(String table, String column) async {
    if (!await _hasTable(table)) return false;
    final columns = await customSelect('PRAGMA table_info($table)').get();
    return columns.any((row) => row.read<String>('name') == column);
  }

  Future<void> _ensureTable(Migrator m, TableInfo<Table, dynamic> table) async {
    if (!await _hasTable(table.actualTableName)) await m.createTable(table);
  }

  Future<void> _ensureColumn(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    if (!await _hasColumn(table.actualTableName, column.name)) {
      await m.addColumn(table, column);
    }
  }

  /// Gives an icon to any type that has none — the nine seeds on an install
  /// that predates icons, and anything the user named before them.
  ///
  /// Runs with the seeding below rather than in the v8 migration step, so it
  /// also reaches a type created between builds. Only ever fills a blank; a
  /// glyph the user picked is never overwritten.
  Future<void> _guessMissingTypeIcons() async {
    final blank = await (select(
      workcenterTypes,
    )..where((t) => t.icon.isNull())).get();

    for (final type in blank) {
      final guess = guessWorkcenterIcon(type.name);
      if (guess == null) continue;
      await (update(
        workcenterTypes,
      )..where((t) => t.id.equals(type.id))).write(
        WorkcenterTypesCompanion(icon: Value(guess)),
      );
    }
  }

  /// Inserts starter workcenter types and shift patterns if they have never
  /// been offered, or if the tables are empty.
  ///
  /// Matches by **name, not id**: rows created on an earlier install carry
  /// generated uuids no constant here could know.
  Future<void> seedReferenceData() async {
    final stamp = await (select(
      appSettings,
    )..where((s) => s.key.equals(_seededAtKey))).getSingleOrNull();
    final typesEmpty = await select(
      workcenterTypes,
    ).get().then((r) => r.isEmpty);
    final patternsEmpty = await select(
      shiftPatterns,
    ).get().then((r) => r.isEmpty);

    final neverSeeded = stamp == null;
    if (neverSeeded || typesEmpty) await _seedWorkcenterTypes();
    if (neverSeeded || patternsEmpty) await _seedShiftPatterns();
    await _guessMissingTypeIcons();

    // Written even when nothing was seeded above: otherwise emptying a table
    // later would read as "never offered" and silently refill it.
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: _seededAtKey,
        value: Value(DateTime.now().toIso8601String()),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _seedWorkcenterTypes() async {
    final existing = await select(workcenterTypes).get();
    final present = existing.map((t) => t.name.toLowerCase()).toSet();
    final now = DateTime.now();
    await batch((b) {
      for (final name in workcenterTypeSeeds) {
        if (present.contains(name.toLowerCase())) continue;
        b.insert(
          workcenterTypes,
          WorkcenterTypesCompanion.insert(
            id: _uuid.v4(),
            name: name,
            isBuiltIn: const Value(true),
            // The seeds are named in English, which is what the guesser reads,
            // so all nine arrive with the right glyph rather than a default.
            icon: Value(guessWorkcenterIcon(name)),
            createdAt: now,
          ),
        );
      }
    });
  }

  Future<void> _seedShiftPatterns() async {
    final existing = await select(shiftPatterns).get();
    final present = existing.map((p) => p.name.toLowerCase()).toSet();
    final now = DateTime.now();
    for (final seed in shiftPatternSeeds) {
      if (present.contains(seed.name.toLowerCase())) continue;
      final patternId = _uuid.v4();
      await into(shiftPatterns).insert(
        ShiftPatternsCompanion.insert(
          id: patternId,
          name: seed.name,
          cycleType: seed.cycleType,
          workingWeekdays: seed.workingWeekdays,
          notes: Value(seed.notes),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await batch((b) {
        for (var i = 0; i < seed.shifts.length; i++) {
          final shift = seed.shifts[i];
          b.insert(
            patternShifts,
            PatternShiftsCompanion.insert(
              id: _uuid.v4(),
              patternId: patternId,
              label: shift.label,
              position: i,
              startMinute: shift.startMinute,
              endMinute: shift.endMinute,
              breakSeconds: Value(shift.breakSeconds),
            ),
          );
        }
      });
    }
  }
}

/// Generates the ids every repository assigns. Kept here so there is one
/// answer to "where do ids come from" and one place to change it.
String newId() => _uuid.v4();
