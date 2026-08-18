@Tags(['live'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives the pending migration against a **copy of the real database**.
///
/// Not part of the suite — it needs a file that only exists on the developer's
/// machine, and is run by hand with `--tags live` when a migration is about to
/// meet real data. The fixtures in `migration_test.dart` prove each step
/// against shapes we constructed; this proves them against the one shape we
/// did not.
///
/// **It asserts `db.schemaVersion`, not a literal.** This file was
/// `live_v15_check_test.dart` and demanded `user_version == 15`, which went
/// stale the moment v16 landed: opening the file *runs* the migration, so
/// against a v15 copy the test upgraded it to 16 and then failed its own first
/// assertion. A per-version literal has to be edited by whoever bumps the
/// schema, and nothing makes them — so the check that exists to catch a
/// migration problem was itself broken by a migration.
///
/// Each version's specific claims accumulate below rather than being replaced:
/// they stay true, they are cheap, and they are the only place they are
/// asserted against real data rather than a fixture.
void main() {
  test('the live database upgrades and keeps what it had', () async {
    final path = Platform.environment['FLOWMAP_LIVE_DB'];
    if (path == null || !File(path).existsSync()) {
      markTestSkipped('set FLOWMAP_LIVE_DB to a copy of flowmap.sqlite');
      return;
    }

    final db = AppDatabase(NativeDatabase(File(path)));
    addTearDown(db.close);

    // Opening it at all is the first assertion.
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);

    final integrity = await db
        .customSelect('PRAGMA integrity_check')
        .getSingle();
    expect(integrity.read<String>('integrity_check'), 'ok');

    // --- v15: the dispatch rule moved onto the lane -------------------------

    // The carry-over: every rule that had a lane in front of its target should
    // now be on that lane, and the two superseded tables should be gone.
    final lanes = await db.customSelect('''
      SELECT n.label, n.lane_rule, n.lane_capacity, n.position, s.name AS study
      FROM flow_nodes n
      JOIN studies s ON s.id = n.study_id
      WHERE n.kind = 'inventory'
      ORDER BY s.name, n.position
    ''').get();

    // ignore: avoid_print
    print('--- lanes ---');
    for (final row in lanes) {
      // ignore: avoid_print
      print(
        '${row.read<String>('study')} #${row.read<int>('position')} '
        '${row.readNullable<String>('label') ?? '(unnamed)'} '
        'rule=${row.readNullable<String>('lane_rule') ?? '-'} '
        'cap=${row.readNullable<int>('lane_capacity') ?? '-'}',
      );
    }

    final dropped = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('workcenter_dispatch', 'simulation_run_dispatch')",
    ).get();
    expect(dropped, isEmpty, reason: 'both superseded tables are dropped');

    // v15's three new settings are asserted **in their domain, not at their
    // defaults**. The first version of this test demanded one unit per station,
    // a zero buffer and no pacemaker — which is only true for the instant
    // between the migration and the first hand-driven check, and §4 asks for
    // exactly those three to be changed. It failed on 2026-08-11 against a
    // TTAT the field had set to two units, which is the check working
    // correctly and the assertion being wrong.
    final stations = await db.select(db.workcenters).get();
    expect(stations.every((w) => w.parallelCapacity >= 1), isTrue);
    for (final w in stations.where((w) => w.parallelCapacity != 1)) {
      // ignore: avoid_print
      print('units: ${w.name} = ${w.parallelCapacity}');
    }

    final studies = await db.select(db.studies).get();
    expect(studies.every((s) => s.startBufferDays >= 0), isTrue);
    for (final s in studies) {
      // ignore: avoid_print
      print(
        'study ${s.name}: buffer=${s.startBufferDays}d '
        'pacemaker=${s.paceSetterTargetId ?? '(derived)'}',
      );
    }

    // --- v16: the schedule horizon ------------------------------------------

    // §16.17 adds one nullable column and rebuilds no table, so the risk here
    // is not the data — it is that `_ensureColumn` silently did nothing and the
    // app then writes a horizon nowhere. Asked of the file rather than of the
    // Dart definition, which would answer yes either way.
    final columns = await db
        .customSelect("PRAGMA table_info('simulation_runs')")
        .get();
    final columnNames = columns.map((r) => r.read<String>('name')).toSet();
    expect(
      columnNames,
      contains('schedule_horizon'),
      reason: 'v16 added the column to the real table, not only to the schema',
    );

    // Every run in the file predates v16, so every horizon is null — the same
    // thing a blank has meant on a stored run since v12 (§16.13), and true
    // rather than backfilled. The first non-null one arrives with the first run
    // made in a v16 build, which is a §4 step and not this test's to make.
    final runs = await db.select(db.simulationRuns).get();
    final withHorizon = runs.where((r) => r.scheduleHorizon != null).toList();
    // ignore: avoid_print
    print('runs carrying a horizon: ${withHorizon.length} of ${runs.length}');
    for (final r in withHorizon) {
      // ignore: avoid_print
      print('  ${r.id}: ${r.scheduleHorizon}');
    }

    // --- v17: a changeover in two halves (§16.18) ---------------------------

    // The same question as above, on the table the carry writes to. A
    // `_ensureColumn` that silently did nothing would leave the editor unable to
    // store a setup, and nothing else would say so.
    final nodeColumns = (await db
            .customSelect("PRAGMA table_info('flow_nodes')")
            .get())
        .map((r) => r.read<String>('name'))
        .toSet();
    expect(
      nodeColumns,
      containsAll(['setup_value', 'setup_unit', 'teardown_value', 'same_part_percent']),
      reason: 'v17 reached the real table, not only the schema',
    );

    // **Every non-zero changeover became a setup of the same length.** Asserted
    // as an implication rather than as a count, because the answer depends on
    // what this particular file happens to hold — and on the developer's own
    // database the answer is *none*: no node has ever had a changeover typed
    // into it. So this passes vacuously here and would still catch a carry that
    // dropped or rescaled a value on a database that has one.
    final nodes = await db.select(db.flowNodes).get();
    final carried = nodes.where((n) => n.changeoverSeconds > 0);
    for (final node in carried) {
      expect(
        node.setupValue,
        node.changeoverSeconds.toDouble(),
        reason: 'the setup kept the changeover it was carried from',
      );
      expect(node.setupUnit, TaktUnit.seconds);
    }
    // ignore: avoid_print
    print(
      'nodes: ${nodes.length}, '
      'with a stored changeover: ${carried.length}, '
      'with a setup: ${nodes.where((n) => n.setupValue != null).length}',
    );

    // **The carry writes seconds, and only the carry does.** A zero becomes null
    // rather than `0 s`, so an untouched node reads as untouched in the editor —
    // but "untouched" is the whole difficulty, and this assertion used to ignore
    // it.
    //
    // _It was `everyElement(isNull)` over every zero-changeover node, and by
    // 2026-08-17 that was false:_ two nodes on the real database carry setups
    // somebody typed — `1 min`, and `12 h` with a 24 h teardown — against a
    // stored changeover of zero. The claim was a fact about the **moment v17
    // ran** and stopped being a fact about the database the first time anyone
    // used the feature v17 shipped.
    //
    // That is this file's own header arriving from a new direction: it records
    // being broken once by a later *migration*, and this is being broken by
    // ordinary *use*. So the carry is asserted by its fingerprint — the unit it
    // writes — rather than by the absence of anything else.
    expect(
      nodes.where(
        (n) => n.changeoverSeconds == 0 && n.setupUnit == TaktUnit.seconds,
      ),
      isEmpty,
      reason: 'a zero must carry as null, not as 0 s',
    );

    // ignore: avoid_print
    print(
      'hand-typed setups since v17: '
      '${nodes.where((n) => n.setupValue != null && n.changeoverSeconds == 0).length}, '
      'teardowns: ${nodes.where((n) => n.teardownValue != null).length}, '
      'percentages: ${nodes.where((n) => n.samePartPercent != null).length}',
    );

    // Teardown and the percentage had nothing that could have supplied them, so
    // v17 left them empty — which is what made it behaviour-preserving until
    // something was typed. Something has been typed since, so what is asserted
    // now is the half that stays true: no *carried* node gained either.
    expect(
      carried.where((n) => n.teardownValue != null || n.samePartPercent != null),
      isEmpty,
      reason: 'the carry supplied a setup and nothing else',
    );

    // --- v20: the pin, and the takt a run ran at ------------------------------

    // **Nothing is backfilled, and that is the whole of v20's claim.** Every
    // step keeps rebalancing on, because null in a disable flag is off (§7.7.4)
    // — so an upgraded database draws exactly the map it drew before.
    expect(
      nodes.where((n) => n.balanceDisabled != null),
      isEmpty,
      reason: 'v20 must not pin anything the user did not pin',
    );

    // And no stored run claims a takt it was never asked about. The schedule
    // lives in the project and may say something different today, so reading it
    // here would make every past run assert a cadence it never ran at (§7.10).
    final runStudies = await db.select(db.simulationRunStudies).get();
    expect(runStudies, isNotEmpty, reason: 'the run studies survived it');
    expect(
      runStudies.where(
        (s) =>
            s.taktValue != null ||
            s.taktUnit != null ||
            s.nextTaktChange != null,
      ),
      isEmpty,
      reason: 'a pre-v20 run says nothing about its takt rather than guessing',
    );

    // --- what no migration may cost -----------------------------------------

    // The demand and the stored runs are untouched: these steps rebuild
    // nothing. Asserted rather than only printed, because "the migration
    // destroyed the demand" is the one failure that would be silent — an empty
    // table reads like a fresh install.
    final orders = await db.select(db.demandOrders).get();
    final steps = await db.select(db.simulationRunSteps).get();
    expect(orders, isNotEmpty, reason: 'the demand survived the migration');
    expect(runs, isNotEmpty, reason: 'the stored runs survived it too');

    // ignore: avoid_print
    print('orders: ${orders.length}');
    // ignore: avoid_print
    print('runs: ${runs.length}');
    // ignore: avoid_print
    print('run steps: ${steps.length}');
  });
}
