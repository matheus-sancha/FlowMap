import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/demand/data/demand_repository.dart';
import 'package:flowmap/src/features/projects/data/projects_repository.dart';
import 'package:flowmap/src/features/resources/data/resources_repository.dart';
import 'package:flowmap/src/features/schedules/data/schedules_repository.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/application/sim_assembly.dart';
import 'package:flowmap/src/features/simulation/application/simulation_providers.dart';
import 'package:flowmap/src/features/simulation/data/simulation_repository.dart';
import 'package:flowmap/src/features/studies/data/studies_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The seam where a stored project becomes something the engine can run
/// (DESIGN.md §7.7).
///
/// The pure assembler is tested next door against hand-built rows; what these
/// catch is the wiring the pure suite cannot see — a study that is not flagged
/// taking part anyway, a pool loaded as one workcenter, a plant model built per
/// study instead of once.
void main() {
  late AppDatabase db;
  late ResourcesRepository resources;
  late ProjectsRepository projects;
  late SchedulesRepository schedules;
  late StudiesRepository studies;
  late DemandRepository demand;
  late SimulationRepository simulation;

  late String plantId;
  late String cellId;
  late String lineId;
  late String otherLineId;
  late String cladId;
  late String millId;
  late String projectId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    resources = ResourcesRepository(db);
    projects = ProjectsRepository(db);
    schedules = SchedulesRepository(db, resources);
    studies = StudiesRepository(db);
    demand = DemandRepository(db);
    simulation = SimulationRepository(
      db,
      resources,
      schedules,
      studies,
      demand,
    );

    plantId = await resources.createPlant(name: 'Werk Nord');
    cellId = await resources.createCell(plantId: plantId, name: 'Cell A');
    lineId = await resources.createLine(cellId: cellId, name: 'Line 1');
    otherLineId = await resources.createLine(cellId: cellId, name: 'Line 2');
    cladId = await resources.createWorkcenter(
      plantId: plantId,
      name: 'CLAD04',
      lineIds: {lineId},
    );
    millId = await resources.createWorkcenter(
      plantId: plantId,
      name: 'MILL02',
      lineIds: {lineId},
    );

    final patterns = await resources.watchShiftPatterns().first;
    projectId = await projects.createProject(
      name: 'H2 2026',
      plantId: plantId,
      shiftPatternId: patterns.firstWhere((p) => p.name == 'ABC').id,
    );

    for (final workcenterId in [cladId, millId]) {
      await schedules.createWorkcenterSchedulePeriod(
        projectId: projectId,
        workcenterId: workcenterId,
        startDate: DateTime(2026),
        endDate: DateTime(2026, 12, 31),
        operatorsPerShift: const [1, 1, 1],
        availability: 1,
        rework: 0,
      );
    }
  });

  tearDown(() => db.close());

  Future<void> taktFor(String line, {double hours = 6}) =>
      schedules.createTaktPeriod(
        projectId: projectId,
        productionLineId: line,
        startDate: DateTime(2026),
        endDate: DateTime(2026, 12, 31),
        takt: hours,
        unit: TaktUnit.hours,
      );

  /// A two-step study with two orders of one part, flagged for the run.
  Future<String> seedStudy({
    required String name,
    required String line,
    List<String>? targets,
    bool flagged = true,
  }) async {
    final studyId = await studies.createStudy(
      projectId: projectId,
      productionCellId: cellId,
      productionLineId: line,
      name: name,
    );
    final steps = targets ?? [cladId, millId];
    // **The ids the steps came back with**, because §9 keys a process time by
    // the node rather than by the station it points at - and the foreign key
    // refuses a workcenter id standing in for one.
    final stepIds = <String>[];
    for (var i = 0; i < steps.length; i++) {
      stepIds.add(
        await studies.insertStep(
          studyId: studyId,
          atPosition: i,
          workcenterId: steps[i],
        ),
      );
    }
    final partId = await demand.createPart(
      studyId: studyId,
      partNumber: 'PN1',
    );
    for (final stepId in stepIds) {
      await demand.setProcessTime(
        partId: partId,
        nodeId: stepId,
        time: const Duration(hours: 2),
      );
    }
    for (var i = 0; i < 2; i++) {
      await demand.createOrder(
        studyId: studyId,
        partId: partId,
        needDate: DateTime(2026, 8, 20 + i),
      );
    }
    if (flagged) await studies.setIncludedInSimulation(studyId, true);
    return studyId;
  }

  test('assembles a flagged study into something the engine runs', () async {
    await taktFor(lineId);
    final studyId = await seedStudy(name: 'Current state', line: lineId);

    final input = await simulation.assembleRun(projectId);

    expect(input.canRun, isTrue);
    expect(input.studies.single.id, studyId);
    expect(input.studies.single.name, 'Current state');
    expect(input.readiness.single.problems, isEmpty);

    // Both stations of the flow are in the model, each once, with the
    // project's calendar under them.
    expect(input.workcenters.keys, unorderedEquals([cladId, millId]));
    expect(
      input.workcenters.values.map((w) => w.name),
      unorderedEquals(['CLAD04', 'MILL02']),
    );

    // And it actually runs: two orders in, two orders out.
    final result = runSimulation(
      studies: input.studies,
      workcenters: input.workcenters,
    );
    expect(result.orders, hasLength(2));
    expect(result.undelivered, isEmpty);
    expect(result.steps, hasLength(4));
  });

  test('an assembled run survives the trip to a background isolate', () async {
    await taktFor(lineId);
    await seedStudy(name: 'Current state', line: lineId);
    final input = await simulation.assembleRun(projectId);

    // The real isolate, not a stand-in. `SimStudy` and `SimWorkcenter` hold no
    // database handle so that this works (§7.1), and nothing running in
    // process would ever catch a value that cannot be sent — it would surface
    // as Simulate throwing on a machine nobody is watching.
    final result = await compute(runSimulationOffThread, (
      studies: input.studies,
      workcenters: input.workcenters,
      // A `DateTime` has to cross the isolate too, and null is not a test of
      // that — the horizon is what §11.1's warning is built on, so a value
      // that could not be sent would surface as Simulate throwing.
      scheduleHorizon: input.scheduleHorizon,
    ));

    expect(result.orders, hasLength(2));
    expect(result.undelivered, isEmpty);
    expect(
      result.busyByWorkcenter.keys,
      unorderedEquals([cladId, millId]),
    );
  });

  test('a study that is not flagged stays out of the run', () async {
    await taktFor(lineId);
    await taktFor(otherLineId);
    final included = await seedStudy(name: 'Current state', line: lineId);
    await seedStudy(name: 'Idea', line: otherLineId, flagged: false);

    final input = await simulation.assembleRun(projectId);

    expect(input.studies.map((s) => s.id), [included]);
    expect(input.readiness.map((r) => r.name), ['Current state']);
  });

  test('two lines contend for one plant model', () async {
    await taktFor(lineId);
    await taktFor(otherLineId);
    await seedStudy(name: 'A', line: lineId);
    await seedStudy(name: 'B', line: otherLineId);

    final input = await simulation.assembleRun(projectId);

    expect(input.studies, hasLength(2));
    // The point of §7.7: CLAD04 exists once however many studies point at it,
    // which is what makes line A's orders genuinely delay line B's.
    expect(input.workcenters.keys, unorderedEquals([cladId, millId]));
    expect(input.canRun, isTrue);
  });

  test('a pool step brings its members into the model', () async {
    await taktFor(lineId);
    final lathe1 = await resources.createWorkcenter(
      plantId: plantId,
      name: 'LAT01',
      lineIds: {lineId},
    );
    final lathe2 = await resources.createWorkcenter(
      plantId: plantId,
      name: 'LAT02',
      lineIds: {lineId},
    );
    for (final id in [lathe1, lathe2]) {
      await schedules.createWorkcenterSchedulePeriod(
        projectId: projectId,
        workcenterId: id,
        startDate: DateTime(2026),
        endDate: DateTime(2026, 12, 31),
        operatorsPerShift: const [1, 1, 1],
        availability: 1,
        rework: 0,
      );
    }
    final poolId = await resources.createPool(
      plantId: plantId,
      name: 'CNC Lathes',
    );
    await resources.setPoolMembers(poolId, {lathe1, lathe2});

    final studyId = await studies.createStudy(
      projectId: projectId,
      productionCellId: cellId,
      productionLineId: lineId,
      name: 'With the pool',
    );
    final poolStep = await studies.insertStep(
      studyId: studyId,
      atPosition: 0,
      poolId: poolId,
    );
    final partId = await demand.createPart(studyId: studyId, partNumber: 'PN1');
    // **Keyed by the step, and the step targets the pool** — so the members
    // still share one time, which is the rule §3.1 cared about and which §9
    // left standing: a part has one process time at a pool, not one per lathe.
    await demand.setProcessTime(
      partId: partId,
      nodeId: poolStep,
      time: const Duration(hours: 2),
    );
    await demand.createOrder(
      studyId: studyId,
      partId: partId,
      needDate: DateTime(2026, 8, 20),
    );
    await studies.setIncludedInSimulation(studyId, true);

    final input = await simulation.assembleRun(projectId);

    expect(input.canRun, isTrue);
    expect(input.workcenters.keys, unorderedEquals([lathe1, lathe2]));
    final step = input.studies.single.steps.single;
    expect(step.isPool, isTrue);
    expect(step.candidates, unorderedEquals([lathe1, lathe2]));
    // **The step, not the pool** (§9). What the members share is the step
    // that targets them; the key is the node, and `poolId` is what that node
    // points at — which is why a part still has one time here rather than one
    // per lathe.
    expect(step.demandKey, poolStep);
    expect(step.poolId, poolId);
  });

  test('an unbound step blocks the run and names the study', () async {
    await taktFor(lineId);
    final studyId = await seedStudy(name: 'Current state', line: lineId);
    // The workcenter goes; §5.1's `ON DELETE SET NULL` leaves the step
    // pointing at nothing, which is §11's first blocking error.
    await resources.deleteWorkcenter(millId);

    final input = await simulation.assembleRun(projectId);

    expect(input.canRun, isFalse);
    expect(input.studies, isEmpty);
    expect(input.readiness.single.studyId, studyId);
    expect(input.readiness.single.name, 'Current state');
    expect(
      input.readiness.single.problems,
      contains(SimAssemblyProblem.unboundStep),
    );
  });

  test('no takt covering the run is a blocking problem, not a guess', () async {
    await seedStudy(name: 'Current state', line: lineId);

    final input = await simulation.assembleRun(projectId);

    expect(input.canRun, isFalse);
    expect(
      input.readiness.single.problems,
      contains(SimAssemblyProblem.noTakt),
    );
  });

  test('a study with no sequence has nothing to release', () async {
    await taktFor(lineId);
    final studyId = await studies.createStudy(
      projectId: projectId,
      productionCellId: cellId,
      productionLineId: lineId,
      name: 'Empty',
    );
    await studies.insertStep(
      studyId: studyId,
      atPosition: 0,
      workcenterId: cladId,
    );
    await studies.setIncludedInSimulation(studyId, true);

    final input = await simulation.assembleRun(projectId);

    expect(input.canRun, isFalse);
    expect(
      input.readiness.single.problems,
      contains(SimAssemblyProblem.noOrders),
    );
  });

  test('nothing flagged is empty rather than unready', () async {
    await taktFor(lineId);
    await seedStudy(name: 'Current state', line: lineId, flagged: false);

    final input = await simulation.assembleRun(projectId);

    expect(input.isEmpty, isTrue);
    expect(input.canRun, isFalse);
    expect(input.readiness, isEmpty);
  });

  test('one ready study does not carry an unready one into the run', () async {
    await taktFor(lineId);
    await taktFor(otherLineId);
    final spare = await resources.createWorkcenter(
      plantId: plantId,
      name: 'DRIL01',
      lineIds: {otherLineId},
    );
    await schedules.createWorkcenterSchedulePeriod(
      projectId: projectId,
      workcenterId: spare,
      startDate: DateTime(2026),
      endDate: DateTime(2026, 12, 31),
      operatorsPerShift: const [1, 1, 1],
      availability: 1,
      rework: 0,
    );
    await seedStudy(name: 'A', line: lineId);
    await seedStudy(name: 'B', line: otherLineId, targets: [spare]);
    // B's only step loses its workcenter; A never used it and still assembles.
    await resources.deleteWorkcenter(spare);

    final input = await simulation.assembleRun(projectId);

    // A run the user asked for over two studies that quietly ran one would
    // report a plant that was never contended for (§7.7).
    expect(input.canRun, isFalse);
    expect(input.readiness.where((r) => r.isReady).map((r) => r.name), ['A']);
    expect(input.readiness.where((r) => !r.isReady).map((r) => r.name), ['B']);
  });

  test('the takt is resolved at the run start, not at the need date', () async {
    // Two periods, and an order whose theoretical lead time straddles the
    // boundary: the need date is in the second, the cold start the run
    // actually begins at is in the first (§7.8). Which of the two the run
    // takes its cadence from is what the second assembly pass decides.
    await schedules.createTaktPeriod(
      projectId: projectId,
      productionLineId: lineId,
      startDate: DateTime(2026),
      endDate: DateTime(2026, 8, 15),
      takt: 3,
      unit: TaktUnit.hours,
    );
    await schedules.createTaktPeriod(
      projectId: projectId,
      productionLineId: lineId,
      startDate: DateTime(2026, 8, 16),
      endDate: DateTime(2026, 12, 31),
      takt: 9,
      unit: TaktUnit.hours,
    );

    final studyId = await studies.createStudy(
      projectId: projectId,
      productionCellId: cellId,
      productionLineId: lineId,
      name: 'Current state',
    );
    final cladStep = await studies.insertStep(
      studyId: studyId,
      atPosition: 0,
      workcenterId: cladId,
    );
    final partId = await demand.createPart(studyId: studyId, partNumber: 'PN1');
    // Weeks of work per order, so the walk back from the need date lands
    // comfortably inside the earlier period rather than a few hours before it.
    await demand.setProcessTime(
      partId: partId,
      nodeId: cladStep,
      time: const Duration(hours: 400),
    );
    await demand.createOrder(
      studyId: studyId,
      partId: partId,
      needDate: DateTime(2026, 8, 20),
    );
    await studies.setIncludedInSimulation(studyId, true);

    final input = await simulation.assembleRun(projectId);

    expect(input.studies.single.releaseInterval, const Duration(hours: 3));
  });

  test('a line that changes takt reaches the run as both (§7.9)', () async {
    // **The end-to-end claim of the round**, through the real assembly rather
    // than a hand-built study: a takt period says how often orders open in it,
    // so a line stating two of them hands the engine two cadences and the
    // engine picks per release. Before this, `taktOn(runStart)` was read once
    // and the second period could not reach a run at all.
    await schedules.createTaktPeriod(
      projectId: projectId,
      productionLineId: lineId,
      startDate: DateTime(2026),
      endDate: DateTime(2026, 6, 30),
      takt: 6,
      unit: TaktUnit.hours,
    );
    await schedules.createTaktPeriod(
      projectId: projectId,
      productionLineId: lineId,
      startDate: DateTime(2026, 7),
      endDate: DateTime(2026, 12, 31),
      takt: 12,
      unit: TaktUnit.hours,
    );
    await seedStudy(name: 'Current state', line: lineId);

    final input = await simulation.assembleRun(projectId);
    final study = input.studies.single;

    expect(study.taktPeriods, hasLength(2));
    expect(study.taktAt(DateTime(2026, 3, 1))?.interval, const Duration(hours: 6));
    expect(study.taktAt(DateTime(2026, 9, 1))?.interval, const Duration(hours: 12));

    // And the study still reports one takt as its own — the one it first
    // releases at (§7.7.2). That is what a run stores and what its header says;
    // what it *ran* at is now read off its orders.
    //
    // **It is the second period's here**, and that is the fixture being useful
    // rather than a stray: this demand is needed in late August, so the cold
    // start lands past 1 July. Which is exactly the shape the round exists for
    // — before it, the 6-hour period was unreachable by any run of this study,
    // and now it is one instant's lookup away.
    expect(study.taktValue, 12);
    expect(study.releaseInterval, const Duration(hours: 12));
  });

  test('an instant no takt covers has no cadence at all (§7.9.2)', () async {
    // The takt table stops at the end of June. A study whose releases would run
    // past it does not carry a 6-hour cadence into July — it carries none, and
    // the engine stops opening orders rather than inventing a rate the plant
    // never stated.
    await schedules.createTaktPeriod(
      projectId: projectId,
      productionLineId: lineId,
      startDate: DateTime(2026),
      endDate: DateTime(2026, 6, 30),
      takt: 6,
      unit: TaktUnit.hours,
    );
    await seedStudy(name: 'Current state', line: lineId);

    final study = (await simulation.assembleRun(projectId)).studies.single;

    expect(study.taktAt(DateTime(2026, 9, 1)), isNull);
    expect(study.intervalAt(DateTime(2026, 9, 1)), isNull);
    expect(study.cadenceResumesAfter(DateTime(2026, 9, 1)), isNull);
  });

  group('the schedule horizon (§11.1)', () {
    test('is the last date every schedule is defined for', () async {
      await taktFor(lineId);
      await seedStudy(name: 'Current state', line: lineId);

      // Everything seeded runs to the end of 2026.
      final input = await simulation.assembleRun(projectId);
      expect(input.scheduleHorizon, DateTime(2026, 12, 31));
    });

    test('takes the earliest of them, not the latest', () async {
      await taktFor(lineId);
      await seedStudy(name: 'Current state', line: lineId);

      // One station defined only to mid-August. Past that date the run is
      // carrying its schedule forward, whatever the others say — so a figure
      // is only as defined as the least-defined thing that produced it.
      // Taking the maximum here would report the run covered to December.
      await schedules.createWorkcenterSchedulePeriod(
        projectId: projectId,
        workcenterId: cladId,
        startDate: DateTime(2027),
        endDate: DateTime(2027, 8, 15),
        operatorsPerShift: const [1, 1, 1],
        availability: 1,
        rework: 0,
      );

      final input = await simulation.assembleRun(projectId);
      expect(input.scheduleHorizon, DateTime(2026, 12, 31));
    });

    test('reaches the stored run, so the warning survives a reload', () async {
      await taktFor(lineId);
      await seedStudy(name: 'Current state', line: lineId);
      final input = await simulation.assembleRun(projectId);

      final result = runSimulation(
        studies: input.studies,
        workcenters: input.workcenters,
        scheduleHorizon: input.scheduleHorizon,
      );

      // The engine carries it without reading it: past the horizon a schedule
      // is simply carried forward, and the run's job is to say so.
      expect(result.scheduleHorizon, DateTime(2026, 12, 31));
    });
  });
}
