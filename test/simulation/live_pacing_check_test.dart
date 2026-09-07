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
/// What #20 says it has to show: marking a type labour-paced moves **that
/// type's stations and nothing else**, and moves them by the crew. Exactly one
/// station on the live plant is crewed above 1 — Coating, at `3/2/2` — so the
/// blast radius is checkable rather than argued about.
void main() {
  test('a crew divides the work, and only where the type says so', () async {
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

    // --- nothing is labour-paced until someone says so ----------------------

    expect(
      input.workcenters.values.every((w) => !w.labourPaced),
      isTrue,
      reason: 'v30 defaults every type to machine-paced',
    );

    Map<String, Duration> busyOf(SimRunResult result) => {
      for (final entry in result.busyByWorkcenter.entries)
        input.workcenters[entry.key]?.name ?? entry.key: entry.value,
    };

    final before = busyOf(
      runSimulation(
        studies: input.studies,
        workcenters: input.workcenters,
        scheduledStations: input.scheduledStations,
        scheduleHorizon: input.scheduleHorizon,
      ),
    );

    // --- repace one type, in memory, and run the same plant again -----------

    // Coating: one station, crewed 3/2/2, and the only crew above 1 on the
    // plant. Repaced here rather than written, so the check is repeatable and
    // leaves the copy as it found it.
    const target = 'Coating';
    SimWorkcenter repaced(SimWorkcenter w) => SimWorkcenter(
      id: w.id,
      name: w.name,
      calendar: w.calendar,
      schedule: w.schedule,
      units: w.units,
      typeId: w.typeId,
      typeName: w.typeName,
      labourPaced: w.typeName == target,
    );

    final paced = {
      for (final entry in input.workcenters.entries)
        entry.key: repaced(entry.value),
    };
    expect(
      paced.values.where((w) => w.labourPaced).map((w) => w.name).toList(),
      isNotEmpty,
      reason: 'the plant has a $target station to repace',
    );

    final after = busyOf(
      runSimulation(
        studies: input.studies,
        workcenters: paced,
        scheduledStations: {
          for (final entry in input.scheduledStations.entries)
            entry.key: repaced(entry.value),
        },
        scheduleHorizon: input.scheduleHorizon,
      ),
    );

    // --- the blast radius ---------------------------------------------------

    final moved = <String>[];
    for (final name in before.keys) {
      if (before[name] != after[name]) moved.add(name);
    }
    // ignore: avoid_print
    print('stations whose demand moved: $moved');

    for (final name in moved) {
      final was = before[name]!.inHours;
      final now = after[name]!.inHours;
      // ignore: avoid_print
      print('  $name  ${was}h -> ${now}h');
    }

    final pacedNames = paced.values
        .where((w) => w.labourPaced)
        .map((w) => w.name)
        .toSet();
    expect(
      moved.toSet(),
      pacedNames,
      reason: 'only the repaced type may move',
    );

    // And it moved the right way: a crew of 2 or 3 does the work sooner.
    for (final name in pacedNames) {
      expect(
        after[name]!,
        lessThan(before[name]!),
        reason: '$name is crewed above 1, so its work takes less of it',
      );
    }
  });
}
