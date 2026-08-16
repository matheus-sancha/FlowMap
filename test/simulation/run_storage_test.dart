import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Storing a run and reading it back (DESIGN.md §7.10).
///
/// The assertion that matters is the **round trip**: a run read out of storage
/// has to report exactly what it reported when it was made, because M5's run
/// comparison puts a stored run beside a fresh one. Checking the row count
/// would pass on a repository that lost the abort reason.
void main() {
  late AppDatabase db;
  late SimulationRunsRepository runs;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    runs = SimulationRunsRepository(db);
  });
  tearDown(() => db.close());

  /// A project to hang runs off — the one foreign key a run carries.
  Future<String> seedProject() async {
    final now = DateTime.now();
    await db
        .into(db.plants)
        .insert(
          PlantsCompanion.insert(
            id: 'plant-1',
            name: 'Werk Nord',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final pattern = (await db.select(db.shiftPatterns).get()).first;
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'proj-1',
            name: 'H2 2026',
            plantId: 'plant-1',
            shiftPatternId: pattern.id,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return 'proj-1';
  }

  final always = ShiftPatternSpec(
    name: 'Continuous',
    cycleType: ShiftCycleType.rotating,
    workingWeekdays: ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5, 6, 7]),
    shifts: const [
      ShiftWindow(
        label: 'All day',
        position: 0,
        startMinute: 0,
        endMinute: 24 * 60,
        breakSeconds: 0,
      ),
    ],
  );

  SimWorkcenter workcenter(String id, String name) {
    final schedule = WorkcenterScheduleSpec([
      WorkcenterSchedulePeriodSpec(
        startDate: DateTime(2020),
        endDate: DateTime(2030),
        operatorsPerShift: const [1],
        availability: 1,
        rework: 0,
      ),
    ]);
    return SimWorkcenter(
      id: id,
      name: name,
      calendar: WorkingCalendar.scheduled(pattern: always, staffing: schedule),
      schedule: schedule,
    );
  }

  /// Two stations, three orders of two parts, and a changeover — enough that
  /// every table below gets rows and the two rankings have something to rank.
  ({List<SimStudy> studies, Map<String, SimWorkcenter> plant}) model() {
    final plant = {
      'wc-1': workcenter('wc-1', 'CLAD04'),
      'wc-2': workcenter('wc-2', 'MILL02'),
    };
    final study = SimStudy(
      id: 'study-1',
      name: 'Current state',
      nodes: [
        SimStep(
          id: 'node-0',
          position: 0,
          title: 'Cladding',
          candidates: const ['wc-1'],
          demandKey: 'wc-1',
          queue: SimQueue(targetId: 'wc-1'),
          setupValue: 3600,
          setupUnit: TaktUnit.seconds,
        ),
        SimStep(
          id: 'node-1',
          position: 1,
          title: 'Milling',
          candidates: const ['wc-2'],
          demandKey: 'wc-2',
          queue: SimQueue(targetId: 'wc-2'),
        ),
      ],
      parts: {
        'part-a': const SimPart(
          id: 'part-a',
          partNumber: 'PN1',
          description: 'PWB 10K',
          processTimes: {
            'wc-1': Duration(hours: 4),
            'wc-2': Duration(hours: 2),
          },
        ),
        // Deliberately undescribed, so the plan can be shown to carry a blank
        // rather than inventing one.
        'part-b': const SimPart(
          id: 'part-b',
          partNumber: 'PN2',
          processTimes: {
            'wc-1': Duration(hours: 3),
            'wc-2': Duration(hours: 5),
          },
        ),
      },
      orders: [
        SimOrder(
          id: 'o0',
          sequence: 0,
          partId: 'part-a',
          needDate: DateTime(2026, 8, 10),
          batchSize: 4,
          batchNumber: 'B-0012',
          customerProject: 'Wing 7',
          materialDate: DateTime(2026, 8, 1),
        ),
        SimOrder(
          id: 'o1',
          sequence: 1,
          partId: 'part-b',
          needDate: DateTime(2026, 8, 11),
        ),
        SimOrder(
          id: 'o2',
          sequence: 2,
          partId: 'part-a',
          // Early enough that it cannot be met — so the run has a late order
          // and OTD is not trivially 1.0.
          needDate: DateTime(2026, 8, 2),
        ),
      ],
      releaseInterval: const Duration(hours: 6),
      releaseCalendarId: 'wc-1',
      priority: 20,
      wipCap: 2,
    );
    return (studies: [study], plant: plant);
  }

  test('the lanes survive storage, so the chart can draw them', () async {
    final projectId = await seedProject();
    final plant = {
      'wc-1': workcenter('wc-1', 'CLAD04'),
      'wc-2': workcenter('wc-2', 'CEU27'),
    };
    final study = SimStudy(
      id: 'study-1',
      name: 'Current state',
      nodes: const [
        SimStep(
          id: 'node-0',
          position: 0,
          title: 'Cladding',
          candidates: ['wc-1'],
          demandKey: 'wc-1',
          queue: SimQueue(targetId: 'wc-1'),
        ),
        // The named, capped queue is a property of the step it feeds now, so
        // both halves of §8.6's row-height rule still have something to read.
        SimStep(
          id: 'node-2',
          position: 2,
          title: 'CEU27',
          candidates: ['wc-2'],
          demandKey: 'wc-2',
          queue: SimQueue(targetId: 'wc-2', name: 'FIFO CEU27', capacity: 1),
        ),
      ],
      parts: {
        'part-a': const SimPart(
          id: 'part-a',
          partNumber: 'PN1',
          processTimes: {
            'wc-1': Duration(hours: 1),
            'wc-2': Duration(hours: 6),
          },
        ),
      },
      orders: [
        for (var i = 0; i < 4; i++)
          SimOrder(
            id: 'o$i',
            sequence: i,
            partId: 'part-a',
            needDate: DateTime(2026, 8, 20),
          ),
      ],
      releaseInterval: const Duration(hours: 1),
      releaseCalendarId: 'wc-1',
    );

    final result = runSimulation(studies: [study], workcenters: plant);
    final runId = await runs.saveRun(
      projectId: projectId,
      result: result,
      studies: [study],
      workcenters: plant,
    );
    final stored = (await runs.loadRun(runId))!;

    // The snapshot the chart places a row from. §7.10 joins to nothing, so
    // without the position there is no way to draw the lane between the two
    // stations it connects.
    //
    // **One row per target now, and the target is the id.** A queue belongs to
    // the station it stands in front of, so both steps have one — and a lane is
    // identified by what it feeds rather than by a node of its own.
    expect(stored.result.lanes.map((l) => l.nodeId), ['wc-1', 'wc-2']);
    final lane = stored.result.lanes.firstWhere((l) => l.nodeId == 'wc-2');
    expect(lane.name, 'FIFO CEU27');
    expect(lane.position, 2);
    expect(lane.capacity, 1);

    // And the stays themselves: every order that was pulled leaves a step
    // naming the lane it stood in, which is what the occupancy is read from.
    final visits = stored.result.steps.where((s) => s.laneNodeId == 'wc-2');
    expect(visits, isNotEmpty);
    expect(visits.every((s) => !s.processStart.isBefore(s.queueStart)), isTrue);

    // A capped lane with a slow station behind it blocks, and that time is
    // stored beside the step rather than inside its occupancy.
    expect(
      stored.result.blockedByWorkcenter['wc-1'],
      greaterThan(Duration.zero),
    );

    // **Per step as well as per station**, and the two have to agree. Both of
    // these columns were being read back and written by nobody until this test
    // asked — §1.5's failure, from the other direction.
    final blockedSteps = stored.result.steps.where(
      (s) => s.workcenterId == 'wc-1' && s.blocked > Duration.zero,
    );
    expect(blockedSteps, isNotEmpty);
    expect(
      blockedSteps.fold(Duration.zero, (sum, s) => sum + s.blocked),
      stored.result.blockedByWorkcenter['wc-1'],
    );

    // And the fresh result says the same as the stored one, which is the whole
    // claim of this file.
    expect(
      stored.result.steps
          .map((s) => (s.orderId, s.laneNodeId, s.blocked))
          .toSet(),
      result.steps.map((s) => (s.orderId, s.laneNodeId, s.blocked)).toSet(),
    );
  });

  test('a stored run reports exactly what it reported when it was made', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();

    final result = runSimulation(studies: studies, workcenters: plant);
    final fresh = computeRunMetrics(
      result: result,
      studies: studies,
      workcenters: plant,
    );

    final runId = await runs.saveRun(
      projectId: projectId,
      result: result,
      studies: studies,
      workcenters: plant,
    );

    final stored = await runs.loadRun(runId);
    expect(stored, isNotNull);
    expect(stored!.queues.uniform, DispatchRule.fifo);
    expect(stored.projectId, projectId);

    // The result itself.
    expect(stored.result.start, result.start);
    expect(stored.result.end, result.end);
    expect(stored.result.guard, result.guard);
    expect(stored.result.abort, result.abort);
    expect(stored.result.steps, hasLength(result.steps.length));
    expect(stored.result.orders, hasLength(result.orders.length));
    expect(stored.result.busyByWorkcenter, result.busyByWorkcenter);
    expect(stored.result.openByWorkcenter, result.openByWorkcenter);

    // **What each changeover cost, per step, round-tripped.** A column written
    // by nobody is the failure this repo has had twice (§1.5, §2.3) and this
    // one is the only place the new setup rule can be checked against what it
    // actually did — so it is asserted against the fresh run rather than merely
    // for being non-null.
    expect(
      stored.result.steps
          .map((s) => (s.orderId, s.nodeId, s.changeoverSeconds))
          .toSet(),
      result.steps
          .map((s) => (s.orderId, s.nodeId, s.changeoverSeconds))
          .toSet(),
    );
    // And it is stated rather than left blank: a fresh run always says, even
    // when the answer is zero. Null would mean nobody recorded it, which is
    // only ever true of a run made before v17.
    expect(
      stored.result.steps.map((s) => s.changeoverSeconds),
      everyElement(isNotNull),
    );
    // The fixture has a setup and two parts, so at least one step paid.
    expect(
      stored.result.steps.where((s) => (s.changeoverSeconds ?? 0) > 0),
      isNotEmpty,
    );

    // And every figure §8 asks of it.
    expect(stored.metrics.orders, fresh.orders);
    expect(stored.metrics.delivered, fresh.delivered);
    expect(stored.metrics.onTime, fresh.onTime);
    expect(stored.metrics.emptySlots, fresh.emptySlots);
    expect(stored.metrics.averageFloat, fresh.averageFloat);
    expect(stored.metrics.averageLeadTime, fresh.averageLeadTime);
    expect(stored.metrics.theoreticalLeadTime, fresh.theoreticalLeadTime);
    expect(stored.metrics.leadTimeEfficiency, fresh.leadTimeEfficiency);
    expect(
      stored.metrics.parts.map((p) => p.partNumber),
      fresh.parts.map((p) => p.partNumber),
    );
    expect(
      stored.metrics.workcenters.map((w) => w.name),
      fresh.workcenters.map((w) => w.name),
    );
    expect(
      stored.metrics.workcenters.map((w) => w.queueTime),
      fresh.workcenters.map((w) => w.queueTime),
    );
    expect(
      stored.metrics.workcenters.map((w) => w.changeovers),
      fresh.workcenters.map((w) => w.changeovers),
    );
    expect(stored.metrics.bottleneck!.name, fresh.bottleneck!.name);

    // The snapshot of what went in.
    expect(stored.studies.single.name, 'Current state');
    expect(stored.studies.single.releaseSeconds, 6 * 3600);
    expect(stored.studies.single.releaseCalendarId, 'wc-1');
    expect(stored.studies.single.priority, 20);
    expect(stored.studies.single.wipCap, 2);
  });

  test('a run outlives the resources it names', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();

    final runId = await runs.saveRun(
      projectId: projectId,
      result: runSimulation(studies: studies, workcenters: plant),
      studies: studies,
      workcenters: plant,
    );

    // Nothing above points at a study, a part or a workcenter row, so there is
    // nothing to delete here to prove it — the proof is that the run still
    // names them after they could no longer be looked up (§7.10).
    final stored = await runs.loadRun(runId);
    expect(
      stored!.metrics.workcenters.map((w) => w.name),
      containsAll(['CLAD04', 'MILL02']),
    );
    expect(
      stored.metrics.parts.map((p) => p.partNumber),
      containsAll(['PN1', 'PN2']),
    );
    expect(stored.studies.single.name, 'Current state');
  });

  test('an aborted run keeps its reason', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();

    final aborted = SimRunResult(
      start: DateTime(2026, 8),
      end: DateTime(2026, 9),
      guard: DateTime(2026, 9),
      steps: const [],
      orders: const [],
      emptySlots: const [],
      busyByWorkcenter: const {},
      openByWorkcenter: const {},
      abort: SimAbortReason.horizonExceeded,
    );

    final runId = await runs.saveRun(
      projectId: projectId,
      result: aborted,
      studies: studies,
      workcenters: plant,
    );

    final stored = await runs.loadRun(runId);
    expect(stored!.result.abort, SimAbortReason.horizonExceeded);
    expect(stored.result.completed, isFalse);
  });

  test(
    'a queue type this build has never heard of is not read as FIFO',
    () async {
      final projectId = await seedProject();
      final (:studies, :plant) = model();
      final runId = await runs.saveRun(
        projectId: projectId,
        result: runSimulation(studies: studies, workcenters: plant),
        studies: studies,
        workcenters: plant,
      );

      // What a database written by a later build looks like to this one. Two
      // things have to hold, and the second is the one §7.3 changed: the run
      // still **opens**, because a list of runs that cannot be read at all is a
      // worse answer than one run that reads oddly — and the station is not
      // claimed to have dispatched FIFO, because it did not, and a run's whole
      // job is to say what it observed.
      await (db.update(db.simulationRunWorkcenters)
            ..where((w) => w.runId.equals(runId))
            ..where((w) => w.workcenterId.equals('wc-1')))
          .write(
            const SimulationRunWorkcentersCompanion(
              queueType: Value('leastSlack'),
            ),
          );

      final stored = await runs.loadRun(runId);
      expect(stored, isNotNull);
      expect(stored!.queues.stations.map((s) => s.name), ['MILL02']);
    },
  );

  test('a run made before v19 reports its one rule at every station', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();
    final runId = await runs.saveRun(
      projectId: projectId,
      result: runSimulation(studies: studies, workcenters: plant),
      studies: studies,
      workcenters: plant,
    );

    // The 35 runs on the real database: no queue type per station, and one rule
    // on the header. It really did dispatch the whole plant by that rule, and
    // reading it here is the only thing `simulation_runs.dispatch` is still for
    // (§7.3).
    await (db.update(db.simulationRunWorkcenters)
          ..where((w) => w.runId.equals(runId)))
        .write(const SimulationRunWorkcentersCompanion(queueType: Value(null)));
    await (db.update(
      db.simulationRuns,
    )..where((r) => r.id.equals(runId))).write(
      const SimulationRunsCompanion(dispatch: Value('earliestDueDate')),
    );

    final stored = await runs.loadRun(runId);
    expect(stored!.queues.uniform, DispatchRule.earliestDueDate);
    expect(stored.queues.isMixed, isFalse);
    expect(stored.queues.stations.map((s) => (s.name, s.rule)), [
      ('CLAD04', DispatchRule.earliestDueDate),
      ('MILL02', DispatchRule.earliestDueDate),
    ]);
  });

  test('a run whose stations differ is mixed, and says which', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();
    final runId = await runs.saveRun(
      projectId: projectId,
      result: runSimulation(studies: studies, workcenters: plant),
      studies: studies,
      workcenters: plant,
    );

    await (db.update(db.simulationRunWorkcenters)
          ..where((w) => w.runId.equals(runId))
          ..where((w) => w.workcenterId.equals('wc-2')))
        .write(
          const SimulationRunWorkcentersCompanion(queueType: Value('lifo')),
        );

    final stored = await runs.loadRun(runId);
    // No one rule to name, and the breakdown is what says so. Both are read off
    // the same list, so the header and the line under it cannot disagree.
    expect(stored!.queues.uniform, isNull);
    expect(stored.queues.isMixed, isTrue);
    expect(stored.queues.stations.map((s) => (s.name, s.rule)), [
      ('CLAD04', DispatchRule.fifo),
      ('MILL02', DispatchRule.lifo),
    ]);
  });

  test('a v19 run writes no rule of its own', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();
    final runId = await runs.saveRun(
      projectId: projectId,
      result: runSimulation(studies: studies, workcenters: plant),
      studies: studies,
      workcenters: plant,
    );

    // The column stays on the schema so the pre-v19 runs keep what they were
    // made with, and stops being written (§7.3). Empty rather than `fifo`,
    // which would be a claim: every station of this run speaks for itself, and
    // a station missing its type has nothing to fall back on.
    final header = await (db.select(
      db.simulationRuns,
    )..where((r) => r.id.equals(runId))).getSingle();
    expect(header.dispatch, isEmpty);
  });

  test('deleting the project takes its runs with it', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();
    final runId = await runs.saveRun(
      projectId: projectId,
      result: runSimulation(studies: studies, workcenters: plant),
      studies: studies,
      workcenters: plant,
    );

    await (db.delete(db.projects)..where((p) => p.id.equals(projectId))).go();

    expect(await runs.loadRun(runId), isNull);
    // And the children went with the header rather than being orphaned.
    expect(await db.select(db.simulationRunSteps).get(), isEmpty);
    expect(await db.select(db.simulationRunOrders).get(), isEmpty);
    expect(await db.select(db.simulationRunWorkcenters).get(), isEmpty);
  });

  test('watchRuns lists a project newest first', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();
    final result = runSimulation(studies: studies, workcenters: plant);

    final older = await runs.saveRun(
      projectId: projectId,
      result: result,
      studies: studies,
      workcenters: plant,
    );
    final newer = await runs.saveRun(
      projectId: projectId,
      result: result,
      studies: studies,
      workcenters: plant,
    );

    // Backdated rather than slept through: `createdAt` is `DateTime.now()` and
    // dates are stored to the second, so two saves in a row genuinely share a
    // timestamp and the ordering under test would never be exercised.
    await (db.update(db.simulationRuns)..where((r) => r.id.equals(older)))
        .write(SimulationRunsCompanion(createdAt: Value(DateTime(2026))));

    final listed = await runs.watchRuns(projectId).first;
    expect(listed.map((r) => r.run.id), [newer, older]);
  });

  test('the history carries what each run dispatched by', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();
    final result = runSimulation(studies: studies, workcenters: plant);

    final uniform = await runs.saveRun(
      projectId: projectId,
      result: result,
      studies: studies,
      workcenters: plant,
    );
    final mixed = await runs.saveRun(
      projectId: projectId,
      result: result,
      studies: studies,
      workcenters: plant,
    );
    await (db.update(db.simulationRunWorkcenters)
          ..where((w) => w.runId.equals(mixed))
          ..where((w) => w.workcenterId.equals('wc-2')))
        .write(
          const SimulationRunWorkcentersCompanion(queueType: Value('lifo')),
        );

    // Read with the list rather than per run, and folded by the same code the
    // run header uses — a menu row saying `FIFO` over a header saying `mixed`
    // is the disagreement the join exists to make impossible.
    final listed = await runs.watchRuns(projectId).first;
    final byId = {for (final listing in listed) listing.run.id: listing.queues};
    expect(byId[uniform]!.uniform, DispatchRule.fifo);
    expect(byId[uniform]!.isMixed, isFalse);
    expect(byId[mixed]!.uniform, isNull);
    expect(byId[mixed]!.isMixed, isTrue);
  });

  test(
    'two runs in the same second still come back in a fixed order',
    () async {
      final projectId = await seedProject();
      final (:studies, :plant) = model();
      final result = runSimulation(studies: studies, workcenters: plant);

      final ids = [
        for (var i = 0; i < 3; i++)
          await runs.saveRun(
            projectId: projectId,
            result: result,
            studies: studies,
            workcenters: plant,
          ),
      ]..sort();

      // Pinned to one instant rather than trusting three saves to land inside
      // the same second: the tie is the thing under test, and a test that only
      // creates one when the clock cooperates is a test that passes for the
      // wrong reason.
      await db
          .update(db.simulationRuns)
          .write(SimulationRunsCompanion(createdAt: Value(DateTime(2026))));

      // Ties break by id, so the list cannot reorder itself between rebuilds
      // (§4.4) — a run list that shuffles reads as a bug in the run.
      expect((await runs.watchRuns(projectId).first).map((r) => r.run.id), ids);
    },
  );

  test('the production plan survives the demand it was built from', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();

    final result = runSimulation(studies: studies, workcenters: plant);
    final runId = await runs.saveRun(
      projectId: projectId,
      result: result,
      studies: studies,
      workcenters: plant,
    );

    final stored = await runs.loadRun(runId);
    final plan = stored!.plan;

    // One row per order, in sequence order — which is release order, so the
    // Order column and "over time" are the same list (§7.2, §8.4).
    expect(plan.map((r) => r.orderNumber), [1, 2, 3]);

    final first = plan.first;
    expect(first.partNumber, 'PN1');
    // Copied in, not joined: nothing here reads demand_parts or demand_orders,
    // which is what keeps the plan readable after either is edited (§7.10).
    expect(first.customerProject, 'Wing 7');
    expect(first.partDescription, 'PWB 10K');
    expect(first.batchNumber, 'B-0012');
    expect(first.batchSize, 4);
    expect(first.materialDate, DateTime(2026, 8, 1));

    // The outcome half, and Float from the one place it is defined (§8).
    expect(first.orderStart, first.outcome.released);
    expect(first.delivery, first.outcome.delivered);
    expect(first.float, first.outcome.float);

    // Actual lead time is order end minus order start, read from the outcome
    // rather than stored, so the column and the tab's average cannot come from
    // two different subtractions.
    expect(first.actualLeadTime, first.outcome.leadTime);

    // Theoretical is the stored §7.9 walk, and it is walked from this order's
    // own release with no queueing and no changeover. So it can never exceed
    // what actually happened — the excess is precisely the waiting, which is
    // the whole reason both columns sit side by side.
    expect(first.theoreticalLeadTime, isNotNull);
    expect(
      first.theoreticalLeadTime!,
      lessThanOrEqualTo(first.actualLeadTime!),
    );

    // An order with no batch number simply has none — a label, not identity.
    expect(plan[1].batchNumber, isNull);
    expect(plan[1].batchSize, 1);

    // Same for a part nobody described. A blank here means "none was typed";
    // on a run stored before v13 it means "this run did not record one"
    // (§16.14). The plan draws a dash for both, which is honest either way.
    expect(plan[1].partDescription, isNull);
  });

  test('the schedule horizon survives, and with it the warning', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();

    // A run that finished past the last defined schedule. The horizon has to
    // be stored, not recomputed: how far the periods reach is a fact about the
    // plant, and §7.10 forbids a stored run joining back to it — so a run that
    // could not say this would drop its own caveat exactly when the reader
    // comes back to quote the figures.
    final horizon = DateTime(2026, 12, 31);
    final result = SimRunResult(
      start: DateTime(2026, 8),
      end: DateTime(2027, 2),
      guard: DateTime(2027, 6),
      steps: const [],
      orders: [
        SimOrderOutcome(
          studyId: 'study-1',
          orderId: 'o1',
          sequence: 0,
          partId: 'part-1',
          needDate: DateTime(2026, 12),
          released: DateTime(2026, 11),
          delivered: DateTime(2026, 12, 20),
        ),
        SimOrderOutcome(
          studyId: 'study-1',
          orderId: 'o2',
          sequence: 1,
          partId: 'part-1',
          needDate: DateTime(2027),
          released: DateTime(2026, 12),
          delivered: DateTime(2027, 1, 15),
        ),
      ],
      emptySlots: const [],
      busyByWorkcenter: const {},
      openByWorkcenter: const {},
      scheduleHorizon: horizon,
    );

    final runId = await runs.saveRun(
      projectId: projectId,
      result: result,
      studies: studies,
      workcenters: plant,
    );

    final stored = await runs.loadRun(runId);
    expect(stored!.result.scheduleHorizon, horizon);

    // The count is derived from the stored orders rather than stored beside
    // the date, so the two cannot come to describe different sets.
    expect(stored.result.ordersPastHorizon.map((o) => o.orderId), ['o2']);
  });

  test('a run with no horizon warns about nothing', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();

    // Every run made before v16, and every plant with no periods at all. The
    // absence has to read as "no warning" rather than as "everything is past
    // it", which is what an epoch default would have done.
    final runId = await runs.saveRun(
      projectId: projectId,
      result: SimRunResult(
        start: DateTime(2026, 8),
        end: DateTime(2026, 9),
        guard: DateTime(2026, 10),
        steps: const [],
        orders: [
          SimOrderOutcome(
            studyId: 'study-1',
            orderId: 'o1',
            sequence: 0,
            partId: 'part-1',
            needDate: DateTime(2026, 9),
            released: DateTime(2026, 8),
            delivered: DateTime(2026, 9),
          ),
        ],
        emptySlots: const [],
        busyByWorkcenter: const {},
        openByWorkcenter: const {},
      ),
      studies: studies,
      workcenters: plant,
    );

    final stored = await runs.loadRun(runId);
    expect(stored!.result.scheduleHorizon, isNull);
    expect(stored.result.ordersPastHorizon, isEmpty);
  });
}
