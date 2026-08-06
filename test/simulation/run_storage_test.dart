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
          changeover: const Duration(hours: 1),
        ),
        SimStep(
          id: 'node-1',
          position: 1,
          title: 'Milling',
          candidates: const ['wc-2'],
          demandKey: 'wc-2',
        ),
      ],
      parts: {
        'part-a': const SimPart(
          id: 'part-a',
          partNumber: 'PN1',
          customerProject: 'Wing 7',
          processTimes: {
            'wc-1': Duration(hours: 4),
            'wc-2': Duration(hours: 2),
          },
        ),
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

  test('a stored run reports exactly what it reported when it was made',
      () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();

    final result = runSimulation(
      studies: studies,
      workcenters: plant,
      dispatch: DispatchRule.earliestDueDate,
    );
    final fresh = computeRunMetrics(
      result: result,
      studies: studies,
      workcenters: plant,
    );

    final runId = await runs.saveRun(
      projectId: projectId,
      dispatch: DispatchRule.earliestDueDate,
      result: result,
      studies: studies,
      workcenters: plant,
    );

    final stored = await runs.loadRun(runId);
    expect(stored, isNotNull);
    expect(stored!.dispatch, DispatchRule.earliestDueDate);
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
      dispatch: DispatchRule.fifo,
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
      dispatch: DispatchRule.shortestProcessing,
      result: aborted,
      studies: studies,
      workcenters: plant,
    );

    final stored = await runs.loadRun(runId);
    expect(stored!.result.abort, SimAbortReason.horizonExceeded);
    expect(stored.result.completed, isFalse);
    expect(stored.dispatch, DispatchRule.shortestProcessing);
  });

  test('a rule this build has never heard of reads as the default', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();
    final runId = await runs.saveRun(
      projectId: projectId,
      dispatch: DispatchRule.fifo,
      result: runSimulation(studies: studies, workcenters: plant),
      studies: studies,
      workcenters: plant,
    );

    // What a database written by a later build looks like to this one. A list
    // of runs that cannot be opened at all is a worse answer than one run that
    // reads as FIFO.
    await (db.update(db.simulationRuns)..where((r) => r.id.equals(runId)))
        .write(const SimulationRunsCompanion(dispatch: Value('leastSlack')));

    final stored = await runs.loadRun(runId);
    expect(stored!.dispatch, DispatchRule.fifo);
  });

  test('deleting the project takes its runs with it', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();
    final runId = await runs.saveRun(
      projectId: projectId,
      dispatch: DispatchRule.fifo,
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
      dispatch: DispatchRule.fifo,
      result: result,
      studies: studies,
      workcenters: plant,
    );
    final newer = await runs.saveRun(
      projectId: projectId,
      dispatch: DispatchRule.earliestDueDate,
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
    expect(listed.map((r) => r.id), [newer, older]);
  });

  test('two runs in the same second still come back in a fixed order',
      () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();
    final result = runSimulation(studies: studies, workcenters: plant);

    final ids = [
      for (var i = 0; i < 3; i++)
        await runs.saveRun(
          projectId: projectId,
          dispatch: DispatchRule.fifo,
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
    expect((await runs.watchRuns(projectId).first).map((r) => r.id), ids);
  });

  test('the production plan survives the demand it was built from', () async {
    final projectId = await seedProject();
    final (:studies, :plant) = model();

    final result = runSimulation(studies: studies, workcenters: plant);
    final runId = await runs.saveRun(
      projectId: projectId,
      dispatch: DispatchRule.fifo,
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
    expect(first.batchNumber, 'B-0012');
    expect(first.batchSize, 4);
    expect(first.materialDate, DateTime(2026, 8, 1));

    // The outcome half, and Float from the one place it is defined (§8).
    expect(first.orderStart, first.outcome.released);
    expect(first.delivery, first.outcome.delivered);
    expect(first.float, first.outcome.float);

    // An order with no batch number simply has none — a label, not identity.
    expect(plan[1].batchNumber, isNull);
    expect(plan[1].batchSize, 1);
  });
}
