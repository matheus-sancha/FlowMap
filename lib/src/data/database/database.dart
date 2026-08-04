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
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedReferenceData();
    },
    onUpgrade: (m, from, to) async {
      // Read **before any step below runs**. The v3 step rebuilds
      // `workcenters` from the *current* Dart definition, which no longer has
      // `home_line_id` — so on a v1 or v2 database the column is gone by the
      // time the v7 step is reached. Same lesson as the two `from >= 2` guards
      // further down, in the other direction (DATA.md).
      final homeLines = from < 7
          ? await customSelect(
              'SELECT id, home_line_id FROM workcenters '
              'WHERE home_line_id IS NOT NULL',
            ).get()
          : const <QueryRow>[];

      if (from < 2) {
        // M2: the project layer. Purely additive — every table below is
        // new, so `createTable` from the current definition is safe and no
        // existing row is touched.
        await m.createTable(projects);
        await m.createTable(calendarExceptions);
        await m.createTable(taktPeriods);
        await m.createTable(workcenterSchedulePeriods);
        await m.createTable(studies);
        await m.createTable(flowNodes);
        await m.createTable(flowAnnotations);
      }

      if (from < 3) {
        // `workcenters.code` is gone: in practice every user filled it with
        // the same value as `name`. A table rebuild, because SQLite cannot
        // drop a column in place on the versions this app runs against.
        // TableMigration copies by name from the current Dart definition, so
        // the dropped column is simply not carried across — and every other
        // value survives whatever column order this machine's table has,
        // which is the reason not to hand-roll the copy.
        await m.alterTable(TableMigration(workcenters));
      }

      if (from < 4 && from >= 2) {
        // A fixed inventory wait remembers the unit it was typed in. Additive
        // and nullable — rows written before this read as hours, the unit the
        // editor offered at the time.
        //
        // **Guarded on `from >= 2` deliberately.** The v2 step above calls
        // `createTable(flowNodes)`, which builds from the *current* Dart
        // definition — so a v1 database already has this column by the time it
        // gets here, and adding it again fails the whole upgrade. The next
        // column added to `flow_nodes` needs the same guard for the same
        // reason (DATA.md).
        await m.addColumn(flowNodes, flowNodes.inventoryUnit);
      }

      if (from < 5 && from >= 2) {
        // A step may state the flow equivalent's process time itself. Guarded
        // on `from >= 2` for the same reason as the step above: a v1 database
        // gets `flow_nodes` from the current definition and already has these.
        await m.addColumn(flowNodes, flowNodes.equivalentValue);
        await m.addColumn(flowNodes, flowNodes.equivalentUnit);
      }

      if (from < 6) {
        // M3: the demand table. Three new tables and no change to an existing
        // one, so `createTable` from the current definition is safe at any
        // starting version — and needs none of the `from >= 2` guarding the
        // two `addColumn` steps above do, because nothing earlier creates
        // these.
        await m.createTable(demandParts);
        await m.createTable(partProcessTimes);
        await m.createTable(demandOrders);
      }

      if (from < 7) {
        // A workcenter is drawn under a *set* of lines, not one. The single
        // `workcenters.home_line_id` this replaces meant filing `CLAD04` under
        // a second line silently took it out of the first — the tree fought
        // the very arrangement the app exists to analyse (DESIGN.md §7.7).
        //
        // Guarded on `from >= 3`: a v1 or v2 database has already been rebuilt
        // by the v3 step above, from a definition that no longer carries the
        // column, so a second rebuild would find nothing to drop.
        if (from >= 3) await m.alterTable(TableMigration(workcenters));
        await m.createTable(workcenterLines);

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
        await m.addColumn(workcenterTypes, workcenterTypes.icon);
      }

      if (from < 9) {
        // A part carries the **customer's** project — their programme, not the
        // FlowMap project the study sits in. Additive and nullable, and
        // guarded on `from >= 6` for the reason the v4 and v5 steps are
        // guarded on `from >= 2`: the v6 step creates `demand_parts` from the
        // *current* definition, so a database older than that already has the
        // column by the time it reaches here (DATA.md).
        if (from >= 6) {
          await m.addColumn(demandParts, demandParts.customerProject);
        }

        // `demand_orders.order_number` is gone. A simulation identifies an
        // order by the row it is; asking a planner to type a works order
        // number they already hold in their own system was work for nothing.
        // A table rebuild, because SQLite cannot drop a column in place on the
        // versions this app runs against — and guarded on `from >= 6` because
        // a database older than that gets `demand_orders` from the *current*
        // definition at the v6 step and never had the column (DATA.md).
        if (from >= 6) await m.alterTable(TableMigration(demandOrders));
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
