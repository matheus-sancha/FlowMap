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
/// The durable form of **"the migration did not reach backwards"**.
///
/// A "nothing is backfilled" claim is a fact about the *moment the migration
/// ran*, and asserting one directly has now broken this file twice: v17's
/// *every zero-changeover node still has a null setup* stopped being true the
/// first time somebody typed a setup, and v20's *no stored run claims a takt*
/// the first time somebody pressed Simulate after it (§16.21). Both were true
/// when written; neither said anything a fortnight later, and the second failed
/// before v21's own claim below was ever reached.
///
/// What stays true is the **ordering**. A column the migration left alone is
/// answered only by runs made after it existed, so every run that answers is
/// newer than every run that does not. Ordinary use adds to the newer group and
/// can never falsify that — where a backfill would have put an answer on the
/// oldest run in the file.
///
/// Vacuous until the file holds some of each, which is honest: a database where
/// nothing has run since the migration has nothing to say here. The counts are
/// printed either way, so a reader can see which case they are looking at.
void expectOnlyNewerRunsAnswer(
  String what, {
  required List<SimulationRun> runs,
  required Set<String> answering,
}) {
  final answered = runs.where((r) => answering.contains(r.id)).toList();
  final silent = runs.where((r) => !answering.contains(r.id)).toList();
  // ignore: avoid_print
  print('$what: ${answered.length} of ${runs.length} runs answer');
  if (answered.isEmpty || silent.isEmpty) return;

  final newestSilent = silent
      .map((r) => r.createdAt)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  final oldestAnswered = answered
      .map((r) => r.createdAt)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  expect(
    newestSilent.isBefore(oldestAnswered),
    isTrue,
    reason:
        '$what reached a run older than the newest run that says nothing, '
        'which is what a backfill looks like from here',
  );
}

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
      SELECT n.lane_rule, n.lane_capacity, n.position, s.name AS study
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
        // The label went in v27 (#5), so these print by position now — which
        // is all this listing was ever using it for.
        '${row.read<String>('study')} #${row.read<int>('position')} '
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
    //
    // Asserted as *not uniform* rather than as *empty*: a pin is a user's act
    // and this plant may well have one by now, where a backfill is the same
    // value on every row. The count is printed so it is on the record either
    // way.
    final pinned = nodes.where((n) => n.balanceDisabled != null);
    // ignore: avoid_print
    print('pinned nodes: ${pinned.length} of ${nodes.length}');
    expect(
      pinned.length,
      lessThan(nodes.length),
      reason: 'v20 must not pin anything the user did not pin',
    );

    // And no run made *before* v20 claims a takt it was never asked about. The
    // schedule lives in the project and may say something different today, so
    // reading it here would make a past run assert a cadence it never ran at
    // (§7.10).
    //
    // **This read `isEmpty` and failed**, on three runs made in the half hour
    // after v20 landed — correct behaviour caught by a stale claim, which is
    // the trap `expectOnlyNewerRunsAnswer` exists to close.
    final runStudies = await db.select(db.simulationRunStudies).get();
    expect(runStudies, isNotEmpty, reason: 'the run studies survived it');
    expectOnlyNewerRunsAnswer(
      'the takt a run ran at (v20)',
      runs: runs,
      answering: {
        for (final s in runStudies)
          if (s.taktValue != null || s.taktUnit != null) s.runId,
      },
    );

    // --- v21: what the work at a step cost -----------------------------------

    // **Null on every step made before the column existed**, and it has to stay
    // that way: the work cannot be derived after the fact — it needs the batch,
    // the availability and the rework as they stood, and a run joins to nothing
    // (§7.10). A backfill here would be an invention wearing a run's authority.
    //
    // Null is not zero on this column either. A step whose part does not route
    // through its station records zero work on purpose (§6.2.1), so what is
    // asked is whether a value is *there*, never whether it is small.
    //
    // Written in the durable form from the start rather than as `isEmpty`,
    // because v21 had already met this database and been run against before the
    // check was written — so the stale form would have been born failing.
    final steps = await db.select(db.simulationRunSteps).get();
    expectOnlyNewerRunsAnswer(
      'what the work at a step cost (v21)',
      runs: runs,
      answering: {
        for (final s in steps)
          if (s.processSeconds != null) s.runId,
      },
    );

    // And no run is a hybrid of two moments, which is the other half of the
    // same rule: a run recorded its work throughout or it never did.
    final hybrid = {
      for (final run in runs)
        if (steps.where((s) => s.runId == run.id).toList() case final own
            when own.isNotEmpty &&
                own.any((s) => s.processSeconds == null) &&
                own.any((s) => s.processSeconds != null))
          run.id,
    };
    expect(
      hybrid,
      isEmpty,
      reason: 'a run half-carrying its work is a run of two moments (§7.10)',
    );

    // --- v22: the takt each order opened under -------------------------------

    // Same shape as v21's claim and for the same reason: the takt cannot be
    // derived for a stored order after the fact — it depends on a schedule the
    // plant may have retuned — so a run made before the column says nothing,
    // and only runs made after it answer.
    final storedOrders = await db.select(db.simulationRunOrders).get();
    expectOnlyNewerRunsAnswer(
      'the takt an order opened under (v22)',
      runs: runs,
      answering: {
        for (final o in storedOrders)
          if (o.taktValue != null) o.runId,
      },
    );

    // And no study claims a cadence that ran out on a database where every
    // takt schedule covers its demand. Printed rather than asserted empty: the
    // day one does not, this is a finding and not a regression.
    final stalled = runStudies.where((s) => s.cadenceEndedAt != null);
    // ignore: avoid_print
    print('studies whose cadence ran out: ${stalled.length}');

    // --- what no migration may cost -----------------------------------------

    // The demand and the stored runs are untouched: these steps rebuild
    // nothing. Asserted rather than only printed, because "the migration
    // destroyed the demand" is the one failure that would be silent — an empty
    // table reads like a fresh install.
    final orders = await db.select(db.demandOrders).get();
    expect(orders, isNotEmpty, reason: 'the demand survived the migration');
    expect(runs, isNotEmpty, reason: 'the stored runs survived it too');

    // ignore: avoid_print
    print('orders: ${orders.length}');
    // ignore: avoid_print
    print('runs: ${runs.length}');
    // ignore: avoid_print
    print('run steps: ${steps.length}');

    // --- v27: a queue is an aspect, and a box is its station (#5) -----------

    // Both columns are gone. Asked of the database rather than inferred from
    // the row class, because it is the *table* the step had to change and this
    // is the only place it meets the real one.
    Future<bool> hasColumn(String table, String column) async =>
        (await db.customSelect('PRAGMA table_info($table)').get()).any(
          (row) => row.read<String>('name') == column,
        );
    expect(await hasColumn('project_queues', 'name'), isFalse);
    expect(await hasColumn('flow_nodes', 'label'), isFalse);

    // **And the rows survived.** 15 queues and 25 steps on this database when
    // the phase was written — asserted as non-empty rather than as those
    // numbers, which is the lesson at the top of this file: a literal count
    // goes stale the first time somebody adds a step.
    final queues = await db.select(db.projectQueues).get();
    expect(queues, isNotEmpty, reason: 'dropping a column kept every row');
    expect(nodes, isNotEmpty, reason: 'and so did every flow node');

    // Every queue can be captioned, which is what replaced the name: the
    // caption is `<type> · <target>`, and the type is derivable for every row
    // because an unset rule is `Queue` rather than nothing. All 15 names on
    // this database were `FIFO ` plus a mangled target name and 7 of them sat
    // on a row with no rule at all — those now read `Queue · …` over the push
    // arrow they already drew.
    // ignore: avoid_print
    print(
      'queues: ${queues.length} '
      '(${queues.where((q) => q.rule == null).length} untyped)',
    );

    // --- v28: study priority goes (#6) --------------------------------------

    // Both columns are gone, the study's and the run's copy of it.
    expect(await hasColumn('studies', 'priority'), isFalse);
    expect(await hasColumn('simulation_run_studies', 'priority'), isFalse);

    // **And every study and every stored study row survived the drop.** This
    // is the whole claim: 3 studies and 324 rows across 147 runs all sat at the
    // default 100, so a lever nobody ever moved could be removed without
    // changing a single stored run. Non-empty rather than those counts, per the
    // note at the top of this file.
    expect(studies, isNotEmpty, reason: 'the studies survived the drop');
    expect(
      runStudies,
      isNotEmpty,
      reason: 'and so did every stored study row',
    );
    // ignore: avoid_print
    print('studies: ${studies.length}');
    // ignore: avoid_print
    print('stored study rows: ${runStudies.length}');

    // **The untyped-lane fix is not assertable here, and this says why.**
    //
    // `SimQueue.rule` became nullable so a run keeps the difference between a
    // lane someone typed FIFO on and one nobody typed anything on. The obvious
    // check — `expectOnlyNewerRunsAnswer` on lanes with a null rule — was
    // written, run against this file, and **failed correctly**: 37 of the 148
    // runs here already carry null lane rules, from before the column was
    // written at all. Null in this column has two meanings across generations,
    // *unset* and *never recorded*, so it cannot be a sentinel for the newer
    // one.
    //
    // That is the trap at the top of this file arriving a third time: the claim
    // is about the moment a run is *stored*, and this file only ever sees runs
    // that already exist. It belongs in `run_storage_test.dart`, which stores a
    // run with one typed lane and one untyped and asserts both come back as
    // they went in — and it is there.
    //
    // What is checked here is what this file can actually see: the lane rows
    // survived the migration, and how many runs sit on each side of the
    // ambiguity, printed so a reader knows which case they are looking at.
    final laneRows = await db.select(db.simulationRunLanes).get();
    expect(laneRows, isNotEmpty, reason: 'the stored lanes survived too');
    final untypedRuns = {
      for (final lane in laneRows)
        if (lane.rule == null) lane.runId,
    };
    // ignore: avoid_print
    print(
      'lanes: ${laneRows.length}, '
      'runs with a null lane rule: ${untypedRuns.length} of ${runs.length}',
    );
  });
}
