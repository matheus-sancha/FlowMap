@Tags(['live'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/demand/data/demand_repository.dart';
import 'package:flowmap/src/features/resources/data/resources_repository.dart';
import 'package:flowmap/src/features/schedules/data/schedules_repository.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/application/gantt_layout.dart';
import 'package:flowmap/src/features/studies/data/studies_repository.dart';
import 'package:flowmap/src/features/simulation/data/simulation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// §9.5's two run-dependent checks, against a **copy of the real database**.
///
/// Run by hand with `--tags live` and `FLOWMAP_LIVE_DB` pointing at a copy. It
/// answers the half of check 2 the field could not drive: whether a flow that
/// visits one station twice charges each pass its own time, and whether the
/// Gantt's rows still settle when that revisit makes the precedence graph
/// cyclic (§9.6).
void main() {
  test('a revisited station charges each pass its own time', () async {
    final path = Platform.environment['FLOWMAP_LIVE_DB'];
    if (path == null || !File(path).existsSync()) {
      markTestSkipped('set FLOWMAP_LIVE_DB to a copy of flowmap.sqlite');
      return;
    }

    final db = AppDatabase(NativeDatabase(File(path)));
    addTearDown(db.close);

    final resources = ResourcesRepository(db);
    final simulation = SimulationRepository(
      db,
      resources,
      SchedulesRepository(db, resources),
      StudiesRepository(db),
      DemandRepository(db),
    );

    final project = await db.select(db.projects).getSingle();
    final input = await simulation.assembleRun(project.id);
    // ignore: avoid_print
    print('canRun=${input.canRun}  studies=${input.studies.length}');
    for (final problem in input.readiness) {
      if (problem.problems.isEmpty) continue;
      // ignore: avoid_print
      print('  readiness ${problem.name}: ${problem.problems}');
    }
    expect(input.canRun, isTrue);

    final result = runSimulation(
      studies: input.studies,
      workcenters: input.workcenters,
      scheduleHorizon: input.scheduleHorizon,
    );
    // ignore: avoid_print
    print('abort=${result.abort}  steps=${result.steps.length}');

    // --- the two visits ------------------------------------------------------

    // **Found by shape, not by name.** The first version of this looked for a
    // study called `copy`, which is a fact about one afternoon: the fixture is
    // a scratch duplicate and the field will delete it. Any study whose flow
    // reaches one station twice answers the same question, and a database with
    // none has nothing to say here — which is the durable form
    // `live_db_check_test.dart` spent two broken assertions learning.
    final study = input.studies
        .where(
          (s) =>
              s.nodes.map((n) => n.candidates.firstOrNull).nonNulls.length !=
              s.nodes
                  .map((n) => n.candidates.firstOrNull)
                  .nonNulls
                  .toSet()
                  .length,
        )
        .firstOrNull;
    if (study == null) {
      markTestSkipped('no study in this database visits a station twice');
      return;
    }
    // ignore: avoid_print
    print('--- steps of ${study.name} ---');
    for (final node in study.nodes) {
      // ignore: avoid_print
      print('  ${node.title}  demandKey=${node.demandKey.substring(0, 8)}');
    }

    final byOrder = <String, List<SimOrderStep>>{};
    for (final step in result.steps) {
      if (step.studyId != study.id) continue;
      byOrder.putIfAbsent(step.orderId, () => []).add(step);
    }

    // ignore: avoid_print
    print('--- charges per order, first three that visit both ---');
    var shown = 0;
    for (final entry in byOrder.entries) {
      final grouped = <String, List<SimOrderStep>>{};
      for (final s in entry.value) {
        grouped.putIfAbsent(s.workcenterId, () => []).add(s);
      }
      final twice = grouped.entries.where((e) => e.value.length > 1);
      if (twice.isEmpty || shown >= 3) continue;
      shown++;
      for (final e in twice) {
        // ignore: avoid_print
        print(
          '  order ${entry.key.substring(0, 8)} station ${e.key.substring(0, 8)}: '
          '${e.value.map((s) => '${((s.process?.inMinutes ?? 0) / 60).toStringAsFixed(2)} h').join('  then  ')}',
        );
      }
    }
    expect(shown, greaterThan(0), reason: 'no order visited one station twice');

    // --- §9.6: the row order still settles -----------------------------------

    final ranks = routingRanks(result);
    final named = {
      for (final entry in ranks.entries)
        (input.workcenters[entry.key]?.name ?? entry.key): entry.value,
    };
    final ordered = named.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    // ignore: avoid_print
    print('--- routing ranks ---');
    for (final entry in ordered) {
      // ignore: avoid_print
      print('  ${entry.value.toString().padLeft(3)}  ${entry.key}');
    }

    // The claim §9.6 pins: everything downstream of the loop keeps its order.
    // Against the cyclic version these climbed to the pass cap together.
    for (final downstream in ['BAN11', 'END', 'Coating']) {
      final rank = named[downstream];
      final tcn = named['TCN20'];
      if (rank == null || tcn == null) continue;
      expect(
        rank,
        greaterThan(tcn),
        reason: '$downstream must sit below TCN20',
      );
    }
  });
}
