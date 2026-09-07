@Tags(['live'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/demand/data/demand_repository.dart';
import 'package:flowmap/src/features/resources/data/resources_repository.dart';
import 'package:flowmap/src/features/schedules/data/schedules_repository.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/data/simulation_repository.dart';
import 'package:flowmap/src/features/studies/data/studies_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Phase 10's owed evidence**, against a copy of the real database.
///
/// Run by hand with `--tags live` and `FLOWMAP_LIVE_DB` pointing at a copy.
///
/// What it has to show: marking a type **Operator Pace** moves *that type's
/// stations and nothing else*, and moves them the right way — **capacity up,
/// demand unchanged**. A crew does not make the job smaller; it makes more of
/// the day available to do it in.
///
/// The baseline is the same plant with every station machine-paced, built in
/// memory from the same rows, so the diff is the pacing and nothing else.
void main() {
  test('a crew is more room, and only where the type says so', () async {
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
    expect(input.canRun, isTrue);

    // --- whatever the plant says its pacing is ------------------------------

    final pacedNames = input.workcenters.values
        .where((w) => w.labourPaced)
        .map((w) => w.name)
        .toSet();
    // ignore: avoid_print
    print('operator-paced on this plant: ${pacedNames.toList()}');

    SimWorkcenter machinePaced(SimWorkcenter w) => SimWorkcenter(
      id: w.id,
      name: w.name,
      calendar: w.calendar,
      schedule: w.schedule,
      units: w.units,
      typeId: w.typeId,
      typeName: w.typeName,
    );

    String nameOf(String id) => input.workcenters[id]?.name ?? id;

    /// Demand in labour hours and capacity in whatever unit the pacing
    /// measures it in — the two halves §10.3 divides.
    Map<String, ({Duration demand, Duration capacity})> gridOf(
      SimRunResult result,
    ) {
      final demand = <String, Duration>{};
      for (final step in result.steps) {
        demand[step.workcenterId] =
            (demand[step.workcenterId] ?? Duration.zero) +
            Duration(seconds: step.processSeconds ?? 0);
      }
      return {
        for (final entry in result.openByWorkcenterMonth.entries)
          nameOf(entry.key): (
            demand: demand[entry.key] ?? Duration.zero,
            capacity: entry.value.values.fold(
              Duration.zero,
              (a, b) => a + b,
            ),
          ),
      };
    }

    final before = gridOf(
      runSimulation(
        studies: input.studies,
        workcenters: {
          for (final e in input.workcenters.entries)
            e.key: machinePaced(e.value),
        },
        scheduledStations: {
          for (final e in input.scheduledStations.entries)
            e.key: machinePaced(e.value),
        },
        scheduleHorizon: input.scheduleHorizon,
      ),
    );

    // --- the same plant with every station machine-paced --------------------

    // The baseline is the model as it was before v30, built in memory from the
    // same rows — so the diff below is the pacing and nothing else. Repaced
    // here rather than written, so the check is repeatable and leaves the copy
    // as it found it.
    final paced = input.workcenters;
    expect(
      pacedNames,
      isNotEmpty,
      reason: 'mark a type Operator Pace before this can say anything',
    );

    final after = gridOf(
      runSimulation(
        studies: input.studies,
        workcenters: paced,
        scheduledStations: input.scheduledStations,
        scheduleHorizon: input.scheduleHorizon,
      ),
    );

    // --- the blast radius ---------------------------------------------------

    final moved = [
      for (final name in before.keys)
        if (before[name] != after[name]) name,
    ];
    // ignore: avoid_print
    print('stations whose grid moved: $moved');
    for (final name in moved) {
      final was = before[name]!;
      final now = after[name]!;
      // ignore: avoid_print
      print(
        '  $name  demand ${was.demand.inHours}h -> ${now.demand.inHours}h, '
        'capacity ${was.capacity.inHours}h -> ${now.capacity.inHours}h',
      );
    }

    expect(moved.toSet(), pacedNames, reason: 'only a paced type may move');

    for (final name in pacedNames) {
      // **The room grows and the work does not shrink**, which is the whole
      // correction: a crew does not make the job smaller, it makes more of the
      // day available to do it in.
      expect(
        after[name]!.capacity,
        greaterThan(before[name]!.capacity),
        reason: '$name is crewed above 1, so it offers more operator-hours',
      );
      expect(
        after[name]!.demand,
        before[name]!.demand,
        reason: '$name does the same work either way',
      );
    }
  });
}
