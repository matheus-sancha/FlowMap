@Tags(['live'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/demand/data/demand_repository.dart';
import 'package:flowmap/src/features/resources/data/resources_repository.dart';
import 'package:flowmap/src/features/schedules/data/schedules_repository.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/data/simulation_repository.dart';
import 'package:flowmap/src/features/studies/data/studies_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Phase 9's owed evidence**, against a copy of the real database.
///
/// The phase is provable rather than visible, so it owes a *query* rather than
/// a drive. Run by hand with `--tags live` and `FLOWMAP_LIVE_DB` pointing at a
/// copy of `flowmap.sqlite`:
///
/// ```
/// flutter test --tags live test/simulation/live_capacity_check_test.dart \
///   --dart-define=... # no: set the env var instead
/// ```
///
/// What it has to show, from #19:
///
/// - the newest run goes from **17 stations × 15 months = 255 rows** to the
///   whole of what the plant has scheduled;
/// - `CLAD09` appears **with capacity and no demand**;
/// - its columns **stop at 2026-12** while the busy stations run to 2027-12;
/// - and `scheduleHorizon` **still reads 2027-12-31** — the trap.
///
/// **The row count is 636, not the 648 #19 predicted.** 648 was 18 × 36, the
/// unragged arithmetic; `CLAD09` is scheduled for 24 months rather than 36, so
/// the ragged answer the phase actually asked for is 17 × 36 + 24. The two
/// halves of the ticket's own evidence — "648 rows" and "its columns stop at
/// 2026-12" — could not both be true, and this is which one held.
void main() {
  test('capacity follows the schedule, and the horizon does not', () async {
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

    // ignore: avoid_print
    print(
      'resource model=${input.workcenters.length}  '
      'scheduled=${input.scheduledStations.length}  '
      'horizon=${input.scheduleHorizon}',
    );

    // --- the two sets are different, and that is the phase -------------------

    expect(
      input.scheduledStations.length,
      greaterThan(input.workcenters.length),
      reason: 'the plant schedules more stations than the routings reach',
    );
    final idle = {
      for (final entry in input.scheduledStations.entries)
        if (!input.workcenters.containsKey(entry.key)) entry.key: entry.value,
    };
    // ignore: avoid_print
    print('scheduled but unrouted: ${idle.values.map((w) => w.name).toList()}');
    expect(idle, isNotEmpty, reason: 'CLAD09 is why this phase exists');

    // --- the horizon is over the stations the run USES ------------------------

    // The trap. Every busy station is scheduled to 2027-12-31 and the idle one
    // stops a year earlier, so a horizon taken over the wider set would read
    // 2026-12-31 and start firing §11.1's tail warning on a run with nothing
    // wrong with it.
    final idleEnd = idle.values
        .expand((w) => w.schedule.periods)
        .map((p) => p.endDate)
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    // ignore: avoid_print
    print('the idle stations are defined to $idleEnd');
    expect(
      input.scheduleHorizon!.isAfter(idleEnd!),
      isTrue,
      reason: 'the idle station must not have moved the horizon',
    );

    // --- the run, and what it now writes down --------------------------------

    final result = runSimulation(
      studies: input.studies,
      workcenters: input.workcenters,
      scheduledStations: input.scheduledStations,
      scheduleHorizon: input.scheduleHorizon,
    );
    expect(result.abort, isNull);

    final rows = result.openByWorkcenterMonth.values.fold<int>(
      0,
      (sum, months) => sum + months.length,
    );
    // ignore: avoid_print
    print(
      'capacity rows=$rows across '
      '${result.openByWorkcenterMonth.length} stations',
    );
    expect(
      result.openByWorkcenterMonth.length,
      input.scheduledStations.length,
      reason: 'every scheduled station is on the chart',
    );

    // --- the idle station has capacity, no demand, and stops early -----------

    final worked = {for (final step in result.steps) step.workcenterId};
    for (final entry in idle.entries) {
      final name = entry.value.name;
      final months = result.openByWorkcenterMonth[entry.key]!;
      final sorted = months.keys.toList()..sort();
      // ignore: avoid_print
      print(
        '$name: ${months.length} months, '
        '${sorted.first} → ${sorted.last}, steps=${worked.contains(entry.key)}',
      );
      expect(worked, isNot(contains(entry.key)), reason: '$name ran nothing');
      expect(
        months.values.any((open) => open > Duration.zero),
        isTrue,
        reason: '$name is open, which is what makes it idle rather than absent',
      );
      // Ragged: it stops where its own schedule stops, not where the busy
      // stations do.
      final busiest = result.openByWorkcenterMonth[input.workcenters.keys.first]!
          .keys
          .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
      expect(
        sorted.last.isBefore(busiest!),
        isTrue,
        reason: '$name is blank past its schedule, not zero',
      );
    }

    // --- and capacity is no longer clipped to the run ------------------------

    final runMonths = <DateTime>{};
    for (var m = DateTime(result.start.year, result.start.month);
        m.isBefore(result.end);
        m = DateTime(m.year, m.month + 1)) {
      runMonths.add(m);
    }
    final busy = result.openByWorkcenterMonth[input.workcenters.keys.first]!;
    // ignore: avoid_print
    print('the run spans ${runMonths.length} months, its stations ${busy.length}');
    expect(
      busy.length,
      greaterThan(runMonths.length),
      reason: 'a scheduled station is open before and after the run',
    );
  });
}
