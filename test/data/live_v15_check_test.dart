@Tags(['live'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives the v14 → v15 migration against a **copy of the real database**.
///
/// Not part of the suite — it needs a file that only exists on the developer's
/// machine, and is run by hand with `--tags live` when a migration is about to
/// meet real data. The fixtures in `migration_test.dart` prove the step against
/// shapes we constructed; this proves it against the one shape we did not.
void main() {
  test('the live database upgrades to v15 and keeps its rules', () async {
    final path = Platform.environment['FLOWMAP_LIVE_DB'];
    if (path == null || !File(path).existsSync()) {
      markTestSkipped('set FLOWMAP_LIVE_DB to a copy of flowmap.sqlite');
      return;
    }

    final db = AppDatabase(NativeDatabase(File(path)));
    addTearDown(db.close);

    // Opening it at all is the first assertion.
    final version = await db
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 15);

    final integrity = await db
        .customSelect('PRAGMA integrity_check')
        .getSingle();
    expect(integrity.read<String>('integrity_check'), 'ok');

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

    // The demand and the stored runs are untouched: this step rebuilds nothing.
    // Asserted rather than only printed, because "the migration destroyed the
    // demand" is the one failure that would be silent — an empty table reads
    // like a fresh install.
    final orders = await db.select(db.demandOrders).get();
    final runs = await db.select(db.simulationRuns).get();
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
