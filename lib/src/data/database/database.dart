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
    ProjectQueues,
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
    SimulationRunLanes,
    SimulationRunLaneVisits,
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
  int get schemaVersion => 20;

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
        //
        // **The transformer is not optional**, and it is the third time this
        // file has learned that (§16.13, §16.15). `TableMigration` copies from
        // the *current* Dart definition, so this reaches for every column
        // `workcenters` has today — including `parallel_capacity`, which v15
        // added and which a table this old has never had. Without a constant
        // naming it the copy fails on a column twelve versions in the future.
        // Every future column on this table needs the same line, here and in
        // the v7 step below.
        if (await _hasColumn('workcenters', 'code')) {
          await m.alterTable(
            TableMigration(
              workcenters,
              columnTransformer: {
                workcenters.parallelCapacity: const Constant<int>(1),
              },
            ),
          );
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
        // The v3 step's note about `parallel_capacity` applies here too: this
        // rebuild copies from the same current definition.
        if (await _hasColumn('workcenters', 'home_line_id')) {
          await m.alterTable(
            TableMigration(
              workcenters,
              columnTransformer: {
                workcenters.parallelCapacity: const Constant<int>(1),
              },
            ),
          );
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
        //
        // Raw SQL, because v14 moved this column off `demand_parts` and Drift
        // can no longer name a column the current definition does not have.
        // The step still has to run: v14 reads these values to put them on the
        // orders, so a database arriving from v8 must grow the column here and
        // lose it there, in that order.
        if (!await _hasColumn('demand_parts', 'customer_project')) {
          await customStatement(
            'ALTER TABLE demand_parts ADD COLUMN customer_project TEXT',
          );
        }

        // `demand_orders.order_number` is gone. A simulation identifies an
        // order by the row it is; asking a planner to type a works order
        // number they already hold in their own system was work for nothing.
        // A table rebuild, because SQLite cannot drop a column in place on the
        // versions this app runs against — and only if the column is still
        // there, because a database older than v6 got `demand_orders` from the
        // *current* definition at the v6 step and never had it.
        //
        // **The transformer is not optional.** `TableMigration` copies column
        // by column from the *current* Dart definition, so this step reaches
        // for every column `demand_orders` has today — including
        // `batch_number`, which v12 added and which a table this old has never
        // had. Without a constant naming it the copy fails on a column that
        // will not exist until three versions later, and the upgrade dies
        // here. Every future column on this table needs the same line —
        // `customer_project`, added by v14, is the second one to need it.
        if (await _hasColumn('demand_orders', 'order_number')) {
          await m.alterTable(
            TableMigration(
              demandOrders,
              columnTransformer: {
                demandOrders.batchNumber: const Constant<String>(null),
                demandOrders.customerProject: const Constant<String>(null),
              },
            ),
          );
        }
      }

      // v10 rebuilt `demand_parts` to make `customer_project` non-null and put
      // it in the unique key, on the argument that project and number together
      // identify a part. v14 reversed that, and the step had to go rather than
      // be left alone: `TableMigration` copies from the **current** definition,
      // which no longer has the column, so replaying it would have destroyed
      // the very values v14 exists to move onto the orders. Nothing is lost by
      // dropping it — every upgrade that would have run it now runs v14, which
      // rebuilds the same table with the right shape and key, and a null
      // project is legal on an order (§16.15).

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

      if (from < 12) {
        // Field feedback: a batch carries the planner's own number, a station
        // may override the run's dispatch rule, and a run records enough of an
        // order to print a production plan from it.
        //
        // Every one of these is additive — two new tables and five nullable
        // columns — so no existing row is rewritten and no table is rebuilt.
        // That matters more here than usual: the database this runs against
        // first is the one that already survived a half-finished upgrade
        // (§16.11), and a step that cannot rebuild a table cannot leave one
        // half-rebuilt.
        await _ensureColumn(m, demandOrders, demandOrders.batchNumber);

        // Deliberately not backfilled from the demand: a run stored before now
        // has no answer, and a blank saying so is true (§7.10).
        await _ensureColumn(
          m,
          simulationRunOrders,
          simulationRunOrders.customerProject,
        );
        await _ensureColumn(
          m,
          simulationRunOrders,
          simulationRunOrders.batchNumber,
        );
        await _ensureColumn(
          m,
          simulationRunOrders,
          simulationRunOrders.batchSize,
        );
        await _ensureColumn(
          m,
          simulationRunOrders,
          simulationRunOrders.materialDate,
        );
      }

      if (from < 13) {
        // Field feedback: the Production Plan names the part's description
        // (§8.5), and §7.10 forbids reaching for it through a join to
        // `demand_parts` — a part re-described since would rewrite what a
        // finished run says.
        //
        // One nullable column and nothing else. `simulation_run_orders` is
        // never rebuilt by a `TableMigration`, so §16.13's warning about
        // `demand_orders` — every future column needs a constant in the v9
        // step's `columnTransformer` — does not reach this table.
        await _ensureColumn(
          m,
          simulationRunOrders,
          simulationRunOrders.partDescription,
        );
      }

      if (from < 14) {
        // Field feedback: the customer's project belongs to the **order**, not
        // to the part. A part number means one part; the process times are the
        // part's, and the project is what a given batch of it is for (§9.3).
        //
        // Three steps, and the order of them is the whole migration: the values
        // have to be read off the parts before the column carrying them is
        // dropped, and the numbers have to be made unique before a key that
        // demands it is applied.
        await _ensureColumn(m, demandOrders, demandOrders.customerProject);

        // Guarded because a database that never reached v9 never had the
        // column — there is then nothing to carry across, which is not an
        // error.
        if (await _hasColumn('demand_parts', 'customer_project')) {
          // 1. Carry each order's project down from the part it is for. Blank
          //    becomes null: on the part it had to be an empty string so
          //    SQLite's UNIQUE would not treat two unprojected parts as
          //    distinct (§16.2), and on the order — a label in no key — null
          //    is what "none" honestly is.
          await customStatement('''
            UPDATE demand_orders SET customer_project = (
              SELECT NULLIF(p.customer_project, '')
              FROM demand_parts p WHERE p.id = demand_orders.part_id
            )
          ''');

          // 2. Two parts differing only by project are about to collide on
          //    `(study, number)`. Keep both — each has its own process times,
          //    and merging them would silently give every order of one the
          //    other's times, which is §11's one intolerable bug. The earliest
          //    keeps the number the planner typed; the rest say which project
          //    they came from, so the rename is legible on the Parts grid
          //    rather than mysterious. A part with no project falls back to a
          //    fragment of its id, which is ugly and unique — and only reachable
          //    for an unprojected part that is *not* the earliest of its twins.
          await customStatement('''
            UPDATE demand_parts
            SET part_number = part_number || ' (' ||
                  COALESCE(NULLIF(customer_project, ''), substr(id, 1, 4)) || ')'
            WHERE EXISTS (
              SELECT 1 FROM demand_parts q
              WHERE q.study_id = demand_parts.study_id
                AND q.part_number = demand_parts.part_number
                AND (q.created_at < demand_parts.created_at
                     OR (q.created_at = demand_parts.created_at
                         AND q.id < demand_parts.id))
            )
          ''');
        }

        // 3. Drop the column and take the new key. No `columnTransformer`:
        //    every column the current definition still has already exists in
        //    the old table, and `customer_project` is dropped precisely by not
        //    being named in it.
        await m.alterTable(TableMigration(demandParts));
      }

      if (from < 15) {
        // Field feedback: the inventories should govern the flow. The queue
        // discipline moves off the station and onto the lane in front of it
        // (§5.5, §7.4), lanes gain a capacity that blocks upstream, a station
        // may run more than one order at once (§3.1), and a study may add a
        // margin ahead of its derived cold start (§7.8).
        //
        // **No table is rebuilt**, which is deliberate on a database that has
        // already survived a half-finished upgrade (§16.11): nullable or
        // defaulted columns and two new tables, so no step here can leave one
        // half-copied. The two tables that go are dropped outright at the end,
        // after their values have been carried across and after the code that
        // read them has gone.
        await _ensureColumn(m, flowNodes, flowNodes.laneRule);
        await _ensureColumn(m, flowNodes, flowNodes.laneCapacity);
        await _ensureColumn(m, studies, studies.startBufferDays);
        await _ensureColumn(m, studies, studies.paceSetterTargetId);
        await _ensureColumn(m, workcenters, workcenters.parallelCapacity);

        await _ensureColumn(
          m,
          simulationRunStudies,
          simulationRunStudies.startBufferDays,
        );
        await _ensureColumn(
          m,
          simulationRunSteps,
          simulationRunSteps.laneNodeId,
        );
        await _ensureColumn(
          m,
          simulationRunSteps,
          simulationRunSteps.blockedSeconds,
        );
        await _ensureColumn(
          m,
          simulationRunWorkcenters,
          simulationRunWorkcenters.blockedSeconds,
        );
        await _ensureColumn(
          m,
          simulationRunWorkcenters,
          simulationRunWorkcenters.units,
        );
        await _ensureTable(m, simulationRunLanes);
        await _ensureTable(m, simulationRunLaneVisits);

        // Carry every stored dispatch rule onto the lane that feeds its target.
        //
        // The rule was keyed by workcenter or pool; a lane is the inventory
        // node immediately before the step pointing at that target, which is
        // the same queue seen from the other side. §5.1's spine is what makes
        // "immediately before" exact — positions are dense and ordered, so the
        // lane feeding a step is the node at `position - 1` if that node is an
        // inventory.
        //
        // A target with no lane in front of it — a step that opens a flow, or a
        // workcenter in no flow at all — has nowhere to carry its rule to and
        // loses it. That is the honest outcome rather than a loss: the rule
        // described a queue that the model no longer holds anywhere, and §7.4's
        // fallback to the run's rule is what it becomes. `workcenter_dispatch`
        // is still here if a value ever needs recovering by hand.
        if (await _hasTable('workcenter_dispatch')) {
          await customStatement('''
            UPDATE flow_nodes SET lane_rule = (
              SELECT d.rule
              FROM flow_nodes step
              JOIN studies s ON s.id = step.study_id
              JOIN workcenter_dispatch d
                ON d.project_id = s.project_id
               AND d.target_id = COALESCE(step.pool_id, step.workcenter_id)
              WHERE step.study_id = flow_nodes.study_id
                AND step.position = flow_nodes.position + 1
                AND step.kind = 'step'
            )
            WHERE flow_nodes.kind = 'inventory'
          ''');
        }

        // Dropped last, and only once nothing reads them. `workcenter_dispatch`
        // has been carried onto the lanes above; `simulation_run_dispatch` is
        // superseded by `simulation_run_lanes`, which records the same fact
        // about the queue that actually held the orders.
        await customStatement('DROP TABLE IF EXISTS workcenter_dispatch');
        await customStatement('DROP TABLE IF EXISTS simulation_run_dispatch');
      }

      if (from < 16) {
        // §11.1's tail warning had nowhere to live. A run whose orders finish
        // past the last defined schedule period carries that period forward,
        // which is right — refusing would make an overloaded plant
        // unsimulatable exactly when the simulation is most informative — but
        // nothing said so. One nullable column, and no table is rebuilt.
        await _ensureColumn(m, simulationRuns, simulationRuns.scheduleHorizon);
      }

      if (from < 17) {
        // Field feedback: a changeover is two halves, not one. Setup rigs the
        // station and teardown strips it, both are optional, and a repeat of the
        // same part pays a percentage of the pair rather than nothing (§7.6).
        // The run records what it charged, because a percentage cannot be read
        // back off a bool. And a stored run learns which cell and line each of
        // its studies belonged to, so §7.10's copy-in rule can answer a filter
        // that would otherwise need a join (§12.1).
        //
        // **No table is rebuilt**, for the third migration running: every column
        // here is nullable and lands on a table that already exists, so no step
        // can leave one half-copied on a database that has already survived an
        // interrupted upgrade (§16.11).
        await _ensureColumn(m, flowNodes, flowNodes.setupValue);
        await _ensureColumn(m, flowNodes, flowNodes.setupUnit);
        await _ensureColumn(m, flowNodes, flowNodes.teardownValue);
        await _ensureColumn(m, flowNodes, flowNodes.teardownUnit);
        await _ensureColumn(m, flowNodes, flowNodes.samePartPercent);

        await _ensureColumn(
          m,
          simulationRunSteps,
          simulationRunSteps.changeoverSeconds,
        );
        await _ensureColumn(
          m,
          simulationRunStudies,
          simulationRunStudies.productionCellId,
        );
        await _ensureColumn(
          m,
          simulationRunStudies,
          simulationRunStudies.productionCellName,
        );
        await _ensureColumn(
          m,
          simulationRunStudies,
          simulationRunStudies.productionLineId,
        );
        await _ensureColumn(
          m,
          simulationRunStudies,
          simulationRunStudies.productionLineName,
        );

        // Carry every stored changeover onto the setup it became.
        //
        // `changeover_seconds` was canonical seconds and `seconds` is a literal
        // TaktUnit that resolves identically at every station (§6.1), so this
        // preserves the typed figure exactly. What it does not preserve is the
        // charge: §7.6 stops derating setup by availability in the same round,
        // so a 90-minute setup on a 74 % station occupies 90 minutes rather than
        // 121.6. That is the point of the change and it is why every stored run
        // is invalidated by it.
        //
        // **A zero carries as null, not as zero.** They mean the same thing —
        // nothing charged — and null is what an untouched node reads as, so the
        // editor shows an empty field rather than a `0 s` nobody typed.
        await customStatement('''
          UPDATE flow_nodes
             SET setup_value = changeover_seconds,
                 setup_unit  = 'seconds'
           WHERE changeover_seconds IS NOT NULL
             AND changeover_seconds > 0
        ''');
      }

      if (from < 18) {
        // Field feedback, 2026-08-15: a pool's members read as three loose
        // machines. §3.1 is right that a run's stations are real workcenters —
        // that is what lets a run say which one ran an order — but nothing
        // recorded which pool they came from, so nothing could group them.
        //
        // Two nullable columns on a table that already exists, so no table is
        // rebuilt for the fourth migration running (§16.11).
        //
        // **Backfilled from nothing.** Pool membership lives in the plant and
        // may have changed since; reading it here would make every stored run
        // claim a grouping it never observed, which is the drift §7.10's
        // copy-in rule exists to prevent. Pre-v18 runs group nothing, which is
        // §12.1's rule that a blank is not a wildcard.
        await _ensureColumn(
          m,
          simulationRunWorkcenters,
          simulationRunWorkcenters.poolId,
        );
        await _ensureColumn(
          m,
          simulationRunWorkcenters,
          simulationRunWorkcenters.poolName,
        );
      }

      if (from < 19) {
        // Field feedback, 2026-08-15: "the inventories of a workcenter used in
        // multiple flows must be the same, they are not."
        //
        // They were not, because an inventory was a node on one study's spine
        // (§5.5). Two studies whose flows both reached CLAD07 each had their
        // own, with their own name, discipline and capacity — and the engine
        // simulated two floor spaces where the plant has one. The Gantt drawing
        // them twice was repeating what the model said.
        //
        // So a queue belongs to what a step *targets*, one row per
        // `{project, target}`, and every step feeding that target reads it.
        await _ensureTable(m, projectQueues);
        await _ensureColumn(m, studies, studies.inboundStock);
        await _ensureColumn(m, studies, studies.outboundStock);
        await _ensureColumn(
          m,
          simulationRunWorkcenters,
          simulationRunWorkcenters.queueType,
        );
        await _ensureColumn(
          m,
          simulationRunWorkcenters,
          simulationRunWorkcenters.queueCapacity,
        );

        // **The fold, and it is the first step here that moves data between
        // concepts rather than adding a column.**
        //
        // Each inventory node becomes part of the queue in front of the step
        // *after* it on its own spine — that step's target is what the node was
        // really describing. Several nodes therefore land on one row: on the
        // database this was written against, 15 nodes fold onto 10 targets,
        // because the two studies share five stations and disagree about two of
        // their names.
        //
        // **First study wins, by study then position.** The first node to reach
        // a target sets the name; a later node's non-null rule or capacity
        // fills a blank rather than being lost, so nothing that was actually
        // configured is dropped in favour of something unset. Deterministic, and
        // it never silently prefers one name without saying so.
        //
        // Guarded on emptiness rather than on `from`, so an upgrade interrupted
        // after this point does not fold twice and overwrite a queue the user
        // has since edited (§16.11).
        final alreadyFolded = (await customSelect(
          'SELECT 1 FROM project_queues LIMIT 1',
        ).get()).isNotEmpty;

        if (!alreadyFolded) {
          // Ordered so the fold is reproducible: study, then position down the
          // spine. `study_id` is a uuid, so this is arbitrary but stable —
          // which is all determinism needs.
          final nodes = await customSelect('''
            SELECT inv.study_id      AS study_id,
                   inv.position      AS position,
                   inv.label         AS label,
                   inv.lane_rule     AS lane_rule,
                   inv.lane_capacity AS lane_capacity,
                   inv.inventory_mode     AS mode,
                   inv.inventory_quantity AS quantity,
                   inv.inventory_seconds  AS seconds,
                   inv.inventory_unit     AS unit,
                   s.project_id      AS project_id,
                   COALESCE(nxt.pool_id, nxt.workcenter_id) AS target_id
              FROM flow_nodes inv
              JOIN studies s ON s.id = inv.study_id
              LEFT JOIN flow_nodes nxt
                     ON nxt.study_id = inv.study_id
                    AND nxt.position = inv.position + 1
                    AND nxt.kind = 'step'
             WHERE inv.kind = 'inventory'
             ORDER BY inv.study_id, inv.position
          ''').get();

          final now = DateTime.now();
          // What each target has been given so far, so a second node can fill a
          // blank without overwriting an answer.
          final folded = <String, Map<String, Object?>>{};

          for (final node in nodes) {
            final target = node.read<String?>('target_id');
            if (target == null) {
              // An inventory node with no step after it describes a queue in
              // front of nothing. It is dropped rather than guessed at, and
              // said out loud — the same rule §8.6 applies to a lane no step
              // ever named.
              Diag.event(
                'v19.orphan',
                'node at ${node.read<int>('position')} feeds no step',
              );
              continue;
            }
            final project = node.read<String>('project_id');
            final key = '$project|$target';
            final seen = folded[key];

            if (seen == null) {
              folded[key] = {
                'name': node.read<String?>('label'),
                'rule': node.read<String?>('lane_rule'),
                'capacity': node.read<int?>('lane_capacity'),
                'mode': node.read<String?>('mode'),
                'quantity': node.read<int?>('quantity'),
                'seconds': node.read<int?>('seconds'),
                'unit': node.read<String?>('unit'),
              };
              continue;
            }

            // A later node on the same target. Fill what is blank, and say what
            // is not taken — `FIFO BAN11` is recoverable from this line, and
            // from the `flow_nodes` row itself, which is kept.
            for (final pair in [
              ('name', node.read<String?>('label')),
              ('rule', node.read<String?>('lane_rule')),
              ('mode', node.read<String?>('mode')),
              ('unit', node.read<String?>('unit')),
            ]) {
              final (field, value) = pair;
              if (value == null) continue;
              if (seen[field] == null) {
                seen[field] = value;
              } else if (seen[field] != value) {
                Diag.event('v19.discarded', '$field on $target');
              }
            }
            for (final pair in [
              ('capacity', node.read<int?>('lane_capacity')),
              ('quantity', node.read<int?>('quantity')),
              ('seconds', node.read<int?>('seconds')),
            ]) {
              final (field, value) = pair;
              if (value == null) continue;
              if (seen[field] == null) {
                seen[field] = value;
              } else if (seen[field] != value) {
                Diag.event('v19.discarded', '$field on $target');
              }
            }
          }

          for (final entry in folded.entries) {
            final parts = entry.key.split('|');
            await customInsert(
              'INSERT INTO project_queues (project_id, target_id, name, rule, '
              'capacity, stock_mode, stock_quantity, stock_seconds, '
              'stock_unit, created_at, updated_at) '
              'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              variables: [
                Variable<String>(parts[0]),
                Variable<String>(parts[1]),
                Variable<String>(entry.value['name'] as String?),
                Variable<String>(entry.value['rule'] as String?),
                Variable<int>(entry.value['capacity'] as int?),
                Variable<String>(entry.value['mode'] as String?),
                Variable<int>(entry.value['quantity'] as int?),
                Variable<int>(entry.value['seconds'] as int?),
                Variable<String>(entry.value['unit'] as String?),
                Variable<DateTime>(now),
                Variable<DateTime>(now),
              ],
            );
          }

          Diag.event('v19.fold', '${nodes.length} nodes → ${folded.length} queues');
        }

        // **The inventory rows are kept and stop being read.** The same call
        // §16.18 made for `changeover_seconds`, and stronger here: a row is a
        // better recovery path for a name the fold discarded than a log line
        // is. Deleting them would make the upgrade irreversible against a v18
        // backup for no gain but tidiness.
      }

      if (from < 20) {
        // Four nullable columns and **nothing rebuilt** — back to the shape
        // §16.19 called safe, after v19's fold was the one migration in this
        // repo that moved data between concepts (§16.21).
        //
        // Field, against célula 11D: a station a part does not run on was being
        // given a share of its neighbours' work, and there was no way to pin a
        // station out of §6.2.1's rebalancing at all. The first was a defect and
        // is fixed in code; this is the flag for the second.
        //
        // **Null is off, so rebalancing stays on.** Every step already in the
        // tree behaves exactly as it did, which is the call §16.18 made for the
        // same-part percentage.
        await _ensureColumn(m, flowNodes, flowNodes.balanceDisabled);

        // What the run ran at. §18.3 is settled rather than deferred — a run
        // keeps one cadence throughout — so the takt is the run's identity, and
        // until now a stored run could not say what it was. `release_seconds`
        // already held the *resolved* interval; these hold the figure a human
        // typed, and when it next changes inside the run's span (§7.7.2, §7.7.3).
        await _ensureColumn(
          m,
          simulationRunStudies,
          simulationRunStudies.taktValue,
        );
        await _ensureColumn(
          m,
          simulationRunStudies,
          simulationRunStudies.taktUnit,
        );
        await _ensureColumn(
          m,
          simulationRunStudies,
          simulationRunStudies.nextTaktChange,
        );

        // **Nothing is backfilled**, and the reason is the one §16.19 gave for
        // the pool columns: the takt schedule lives in the project and may say
        // something different today from what a run used. Reading it here would
        // make every stored run claim a cadence it never ran at, which is the
        // drift §7.10's copy-in rule exists to prevent. Pre-v20 runs say
        // nothing, which is §12.1's rule that a blank is not a wildcard.
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

  /// Adds [column] unless it is already there — or the table is not.
  ///
  /// **The missing-table case is not defensive padding.** A step adds columns to
  /// tables an earlier step creates, and `from` says only where the counter
  /// stopped: a database whose upgrade died between the two has the version of
  /// the second and the tables of neither (§16.11). Asking is what the note at
  /// the top of `onUpgrade` requires, and [_ensureTable] has always asked.
  ///
  /// Skipping is safe rather than merely quiet: whatever creates the table
  /// later builds it from the current Dart definition, which already carries
  /// the column. There is no path where this loses one.
  Future<void> _ensureColumn(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    if (!await _hasTable(table.actualTableName)) return;
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
