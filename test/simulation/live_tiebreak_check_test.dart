@Tags(['live'])
library;

import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/demand/data/demand_repository.dart';
import 'package:flowmap/src/features/resources/data/resources_repository.dart';
import 'package:flowmap/src/features/schedules/data/schedules_repository.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/data/simulation_repository.dart';
import 'package:flowmap/src/features/studies/data/studies_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// **What v28's tie-break actually moved, on the real database** (#6).
///
/// Run by hand with `--tags live` and `FLOWMAP_LIVE_DB` pointing at a copy.
/// Phase 2's owed evidence: re-run today's input under the need-date
/// fall-through and diff the step rows against a run stored under the old one.
///
/// **Why this can be read as isolating the comparator.** Every study on this
/// database sits at priority 100, so the old fall-through was *arrival →
/// (priority, always equal) → sequence → order id* — which is to say
/// *arrival → sequence → id*. The new one inserts the need date after arrival.
/// So a step that moves either tied on arrival with another study's, or is
/// downstream of one that did.
///
/// **The confound, named rather than hidden**: the input can have changed since
/// the stored run was made. The check diffs against the *newest* stored run for
/// that reason — it is the one made closest to now, so it has had the least
/// time to drift — and prints the run's age so a reader can judge it. A large
/// diff against a week-old run says nothing; a small one against a run made
/// minutes before the fix says a great deal.
void main() {
  test('the need date moves only orders that tied on arrival', () async {
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
    expect(input.canRun, isTrue, reason: 'the flagged studies still assemble');

    final result = runSimulation(
      studies: input.studies,
      workcenters: input.workcenters,
      scheduleHorizon: input.scheduleHorizon,
    );

    // The newest stored run that actually has step rows — the empty one is not
    // a baseline, and the newest is the least drifted.
    final runs =
        await (db.select(db.simulationRuns)
              ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
            .get();
    final steps = await db.select(db.simulationRunSteps).get();
    final byRun = <String, List<SimulationRunStep>>{};
    for (final step in steps) {
      (byRun[step.runId] ??= []).add(step);
    }
    final baseline = runs.firstWhere((r) => (byRun[r.id] ?? []).isNotEmpty);
    final stored = byRun[baseline.id]!;

    // ignore: avoid_print
    print(
      'baseline ${baseline.id.substring(0, 8)} '
      'made ${baseline.createdAt}, ${stored.length} steps; '
      're-run produced ${result.steps.length}',
    );

    // Keyed by what identifies a step across two runs of the same input. A key
    // present in one and not the other is a change of *input*, not of ordering,
    // and is counted separately so it cannot be mistaken for one.
    String key(String orderId, String nodeId) => '$orderId@$nodeId';
    final before = {
      for (final step in stored) key(step.orderId, step.nodeId): step,
    };
    final after = {
      for (final step in result.steps) key(step.orderId, step.nodeId): step,
    };

    // **Compared to the second, because that is the resolution the run was
    // stored at.** The first version of this check compared the two moments
    // directly and reported 1,862 of 1,871 steps moved — every one of them by a
    // fraction, `21:33:21.000` against `21:33:21.428571`. That is the column's
    // rounding meeting an in-memory `DateTime`, not the comparator, and it
    // would have buried nine real changes under 1,862 false ones.
    DateTime toSecond(DateTime t) =>
        DateTime.fromMillisecondsSinceEpoch(
          (t.millisecondsSinceEpoch ~/ 1000) * 1000,
        );

    final onlyBefore = before.keys.where((k) => !after.containsKey(k)).length;
    final onlyAfter = after.keys.where((k) => !before.containsKey(k)).length;
    final shared = before.keys.where(after.containsKey).toList();
    final moved = shared
        .where(
          (k) =>
              toSecond(before[k]!.processStart) !=
              toSecond(after[k]!.processStart),
        )
        .toList();

    // ignore: avoid_print
    print(
      'input drift: $onlyBefore steps only in the stored run, '
      '$onlyAfter only in the re-run',
    );
    // ignore: avoid_print
    print(
      'of ${shared.length} steps in both, ${moved.length} start at a '
      'different moment',
    );
    for (final k in moved.take(12)) {
      // ignore: avoid_print
      print(
        '  $k  ${toSecond(before[k]!.processStart)} -> '
        '${toSecond(after[k]!.processStart)}',
      );
    }

    // **The claim, and it is a claim about the whole run, not a sample.** The
    // need date is inserted *below* arrival, so it cannot reorder two orders
    // that reached a station at different moments. Whatever moved, the run as a
    // whole still does the same work: the same orders visit the same steps.
    expect(
      onlyBefore + onlyAfter,
      0,
      reason: 'the input has not drifted, so the diff is the comparator alone',
    );
  });
}
