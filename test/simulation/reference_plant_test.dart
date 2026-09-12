/// **The reference plant** — a plant small enough to work by hand, asserted
/// end to end through the real repositories and the real engine.
///
/// The 1,137 tests around this one check the app against itself: a change that
/// breaks one is caught, a model that was always wrong is not. Two model
/// defects have been found by *using* the app that the whole suite had nothing
/// to say about — §7.5's claim that operators never scale output, and the
/// demand-clipped capacity of #19. Both were arithmetic nobody had worked by
/// hand.
///
/// So every number below is computed **independently, on paper**, from figures
/// chosen to make that possible:
///
/// - One shift, **08:00–16:00, no break** — 8 h a day, so a day is a round
///   number and a month is a weekday count.
/// - **Mon–Fri only** (`workingWeekdays` is a bitmask, `1 << (weekday - 1)`,
///   so Mon–Fri is 31).
/// - **June 2026 begins on a Monday** and holds **22 working days**, hence
///   `22 × 8 = 176 h` of open time per single-unit workcenter. May has 21 days
///   (168 h) and July 23 (184 h), which is what makes the ragged edges of a
///   monthly grid worth asserting.
/// - Process times in whole hours, two parts, thirty orders each.
///
/// **What is asserted here is scheduling-independent.** How the engine
/// sequences the work is its business; the *total* it must do is not. Busy time
/// per workcenter, open time per workcenter-month, and the count of orders in and out
/// are all fixed by the inputs, so they can be stated before the run and
/// checked after it.
///
/// Seeds [FlowMap v2.1's reference-plant ticket][1].
///
/// [1]: https://github.com/matheus-sancha/FlowMap/issues/22
library;

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/demand/data/demand_repository.dart';
import 'package:flowmap/src/features/projects/data/projects_repository.dart';
import 'package:flowmap/src/features/resources/data/resources_repository.dart';
import 'package:flowmap/src/features/schedules/data/schedules_repository.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/data/simulation_repository.dart';
import 'package:flowmap/src/features/studies/data/studies_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mon–Fri, as the bitmask `ShiftPatternSpec.isWorkingWeekday` reads.
const monToFri = 31;

/// The plant's one shift: 08:00 to 16:00, nothing unpaid inside it.
const dayShift = ShiftWindow(
  label: 'Day',
  position: 0,
  startMinute: 8 * 60,
  endMinute: 16 * 60,
);

/// Hand-worked, and the reason every figure below is a round number.
const hoursPerDay = 8;
const workingDaysJune2026 = 22;
const openHoursJune2026 = hoursPerDay * workingDaysJune2026; // 176

void main() {
  late AppDatabase db;
  late ResourcesRepository resources;
  late ProjectsRepository projects;
  late SchedulesRepository schedules;
  late StudiesRepository studies;
  late DemandRepository demand;
  late SimulationRepository simulation;

  late String projectId;
  late String studyId;
  late String sawId;
  late String paintId;

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

    // --- the plant ---------------------------------------------------------

    final plantId = await resources.createPlant(name: 'Reference Works');
    final cellId = await resources.createCell(
      plantId: plantId,
      name: 'Reference Cell',
    );
    final lineId = await resources.createLine(
      cellId: cellId,
      name: 'Reference Line',
    );

    sawId = await resources.createWorkcenter(
      plantId: plantId,
      name: 'SAW01',
      lineIds: {lineId},
    );
    paintId = await resources.createWorkcenter(
      plantId: plantId,
      name: 'PAINT01',
      lineIds: {lineId},
    );

    // A pattern of our own rather than a seeded one, because the whole point is
    // that the open hours are a number we chose and can multiply out.
    final patternId = await resources.createShiftPattern(
      name: 'One day shift',
      cycleType: ShiftCycleType.fixedWeekly,
      workingWeekdays: monToFri,
    );
    await resources.setPatternShifts(patternId, const [dayShift]);

    projectId = await projects.createProject(
      name: 'Reference 2026',
      plantId: plantId,
      shiftPatternId: patternId,
    );

    // Three months, so the grid is ragged by construction: 168 h, 176 h, 184 h.
    for (final workcenterId in [sawId, paintId]) {
      await schedules.createWorkcenterSchedulePeriod(
        projectId: projectId,
        workcenterId: workcenterId,
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 7, 31),
        operatorsPerShift: const [1],
        availability: 1,
        rework: 0,
      );
    }

    await schedules.createTaktPeriod(
      projectId: projectId,
      productionLineId: lineId,
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 7, 31),
      takt: 4,
      unit: TaktUnit.hours,
    );

    // --- the study ---------------------------------------------------------

    studyId = await studies.createStudy(
      projectId: projectId,
      productionCellId: cellId,
      productionLineId: lineId,
      name: 'Reference study',
    );

    // Saw, then paint. Two steps, so an order queues at the second.
    final sawStep = await studies.insertStep(
      studyId: studyId,
      atPosition: 0,
      workcenterId: sawId,
    );
    final paintStep = await studies.insertStep(
      studyId: studyId,
      atPosition: 1,
      workcenterId: paintId,
    );

    // Two parts with deliberately different shapes: P1 is saw-heavy relative to
    // P2, and both are paint-heavy overall, so PAINT01 is the bottleneck and
    // the ranking has an unambiguous answer.
    final p1 = await demand.createPart(studyId: studyId, partNumber: 'P1');
    final p2 = await demand.createPart(studyId: studyId, partNumber: 'P2');

    await demand.setProcessTime(
      partId: p1,
      nodeId: sawStep,
      time: const Duration(hours: 2),
    );
    await demand.setProcessTime(
      partId: p1,
      nodeId: paintStep,
      time: const Duration(hours: 3),
    );
    await demand.setProcessTime(
      partId: p2,
      nodeId: sawStep,
      time: const Duration(hours: 1),
    );
    await demand.setProcessTime(
      partId: p2,
      nodeId: paintStep,
      time: const Duration(hours: 4),
    );

    // Thirty of each, one pair due on each day of June.
    //
    // **Spread rather than stacked, and the first draft got this wrong.** With
    // all sixty due on one date the run aborted `horizonExceeded` after
    // thirteen days: §7.8's guard sits at about five times the horizon the
    // demand implies, and demand due on a single day implies almost no horizon
    // at all. That was the engine being right about a plant that could not
    // exist — 210 h of paint wanted inside a fortnight — and the fix belongs in
    // the plant, not in the guard.
    for (var i = 0; i < 30; i++) {
      final due = DateTime(2026, 6, 1 + i);
      await demand.createOrder(studyId: studyId, partId: p1, needDate: due);
      await demand.createOrder(studyId: studyId, partId: p2, needDate: due);
    }

    await studies.setIncludedInSimulation(studyId, true);
  });

  tearDown(() => db.close());

  test('the plant assembles into something the engine will run', () async {
    final input = await simulation.assembleRun(projectId);

    expect(input.canRun, isTrue, reason: 'readiness: ${input.readiness}');
    expect(
      input.readiness.single.problems,
      isEmpty,
      reason: 'a reference plant with a gap in it proves nothing',
    );
    expect(input.studies.single.id, studyId);
    expect(input.workcenters.keys, unorderedEquals([sawId, paintId]));

    // Both workcenters are single-unit and machine-paced, which is what makes the
    // open time below a plain multiplication.
    for (final workcenter in input.workcenters.values) {
      expect(workcenter.units, 1);
      expect(workcenter.labourPaced, isFalse);
    }
  });

  test('open time is the weekday count times the shift, per month', () async {
    final input = await simulation.assembleRun(projectId);
    final result = runSimulation(
      studies: input.studies,
      workcenters: input.workcenters,
    );

    // **Hand-worked**: June 2026 opens on a Monday and holds 22 working days;
    // at 8 h a shift that is 176 h. May holds 21 (168 h) and July 23 (184 h).
    // A month is not a twelfth of a year and a grid that treats it as one is
    // wrong three times in every four columns.
    for (final workcenterId in [sawId, paintId]) {
      final months = result.openByWorkcenterMonth[workcenterId]!;
      expect(
        months[DateTime(2026, 6)]!.inHours,
        openHoursJune2026,
        reason: 'June 2026: 22 working days x 8 h',
      );
      expect(months[DateTime(2026, 5)]!.inHours, 21 * hoursPerDay);
      expect(months[DateTime(2026, 7)]!.inHours, 23 * hoursPerDay);
    }
  });

  test('busy time is the sum of the work, whatever order it is done in',
      () async {
    final input = await simulation.assembleRun(projectId);
    final result = runSimulation(
      studies: input.studies,
      workcenters: input.workcenters,
    );

    // Every order is delivered, so every step's process time is charged
    // somewhere. **These totals are fixed by the inputs, not by the schedule.**
    expect(result.orders, hasLength(60));
    expect(result.undelivered, isEmpty);
    expect(result.steps, hasLength(120));

    // **Hand-worked**:
    //   SAW01   = 30 x 2 h + 30 x 1 h =  90 h
    //   PAINT01 = 30 x 3 h + 30 x 4 h = 210 h
    // No changeover is configured, so busy time is process time exactly.
    expect(result.busyByWorkcenter[sawId]!.inHours, 90);
    expect(result.busyByWorkcenter[paintId]!.inHours, 210);

    // And the whole plant did 300 h of work: 60 orders x 5 h of routing each,
    // which both parts happen to share (2+3 and 1+4).
    final total = result.busyByWorkcenter.values
        .fold(Duration.zero, (sum, d) => sum + d);
    expect(total.inHours, 300);
  });

  test('PAINT01 is over its June capacity and SAW01 is not', () async {
    final input = await simulation.assembleRun(projectId);
    final result = runSimulation(
      studies: input.studies,
      workcenters: input.workcenters,
    );

    // **Hand-worked**, the whole run's work against the 176 h one month holds:
    //   SAW01    90 / 176 =  51.1 %
    //   PAINT01 210 / 176 = 119.3 %  <- more than a June
    //
    // This is a claim about *fit*, not the Occupation view's own figure: that
    // one buckets by `queueStart` (§10.3) and is a per-month ratio, while this
    // asks whether a month could hold the run at all. Both are useful and they
    // are not the same number.
    final sawPct = 100 * result.busyByWorkcenter[sawId]!.inMinutes /
        (openHoursJune2026 * 60);
    final paintPct = 100 * result.busyByWorkcenter[paintId]!.inMinutes /
        (openHoursJune2026 * 60);

    expect(sawPct, closeTo(51.1, 0.1));
    expect(paintPct, closeTo(119.3, 0.1));

    // So the run has to spill out of June, and does: it runs 2026-05-29 to
    // 2026-07-10. A plant asked for 210 h of paint inside 176 cannot finish in
    // the month however it is sequenced — arithmetic, not a scheduling opinion.
    expect(
      result.busyByWorkcenter[paintId]!.inHours,
      greaterThan(openHoursJune2026),
    );
    final starts = result.steps.map((s) => s.processStart).toList()..sort();
    expect(starts.first.month, 5, reason: 'work starts before June');
    expect(starts.last.month, 7, reason: 'and finishes after it');
  });

  test('utilization measures the machine clock, not the calendar', () async {
    final input = await simulation.assembleRun(projectId);
    final result = runSimulation(
      studies: input.studies,
      workcenters: input.workcenters,
    );

    // §8.3: utilization is busy over the open time of the span the run actually
    // occupied — 241 h here, for a run of 2026-05-29 to 2026-07-10 — so it is
    // not the monthly occupation above and must not be read as one. Both
    // workcenters share that span, so their ratio is the ratio of their work and
    // survives any change to the run's length.
    final saw = result.utilization[sawId]!;
    final paint = result.utilization[paintId]!;

    expect(paint, greaterThan(saw));
    // 210 / 90 = 2.333..., and both are measured over the same open span.
    expect(paint / saw, closeTo(210 / 90, 0.001));
  });

}
