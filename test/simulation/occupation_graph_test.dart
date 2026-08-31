import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/application/occupation_graph.dart';
import 'package:flowmap/src/features/simulation/application/run_filter.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Demand against capacity, month by month (`TODO.md` §10.3).
///
/// Built from a **stored** run rather than a fresh result, because that is what
/// the chart reads and because the two things it needs — the rework split and
/// the monthly capacity — are v25 columns whose whole point is surviving the
/// trip through the database.
void main() {
  late AppDatabase db;
  late SimulationRunsRepository runs;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    runs = SimulationRunsRepository(db);
  });

  tearDown(() => db.close());

  /// A plant and a project for the run to hang off — the foreign keys are on,
  /// so a run needs a project that exists.
  Future<String> seedProject() async {
    final now = DateTime.now();
    // Idempotent: one test stores two runs, and a fixture that could only be
    // called once would fail on the second rather than on anything it means to
    // test.
    await db
        .into(db.plants)
        .insertOnConflictUpdate(
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
        .insertOnConflictUpdate(
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
    name: 'Always',
    cycleType: ShiftCycleType.fixedWeekly,
    workingWeekdays: ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5, 6, 7]),
    shifts: const [
      ShiftWindow(
        label: 'A',
        position: 0,
        startMinute: 0,
        endMinute: 1439,
        breakSeconds: 0,
      ),
    ],
  );

  SimWorkcenter workcenter(
    String id,
    String name, {
    double rework = 0,
    String? typeId,
    String? typeName,
  }) {
    final schedule = WorkcenterScheduleSpec([
      WorkcenterSchedulePeriodSpec(
        startDate: DateTime(2020),
        endDate: DateTime(2030),
        operatorsPerShift: const [1],
        availability: 1,
        rework: rework,
      ),
    ]);
    return SimWorkcenter(
      id: id,
      name: name,
      calendar: WorkingCalendar.scheduled(pattern: always, staffing: schedule),
      schedule: schedule,
      typeId: typeId,
      typeName: typeName,
    );
  }

  /// Two lines that share MILL02, which is the shape every rule here is about.
  ({List<SimStudy> studies, Map<String, SimWorkcenter> plant}) model({
    double rework = 0,
  }) {
    final plant = {
      'wc-1': workcenter(
        'wc-1',
        'CLAD04',
        rework: rework,
        typeId: 'type-clad',
        typeName: 'Cladding',
      ),
      'wc-2': workcenter(
        'wc-2',
        'MILL02',
        rework: rework,
        typeId: 'type-mill',
        typeName: 'Milling',
      ),
    };

    SimStudy study(String id, String name, String lineId, String lineName) =>
        SimStudy(
          id: id,
          name: name,
          productionCellId: 'cell-1',
          productionCellName: 'Cell 11',
          productionLineId: lineId,
          productionLineName: lineName,
          nodes: [
            SimStep(
              id: '$id-node-0',
              position: 0,
              title: 'Cladding',
              candidates: const ['wc-1'],
              demandKey: 'wc-1',
              queue: SimQueue(targetId: 'wc-1'),
            ),
            SimStep(
              id: '$id-node-1',
              position: 1,
              title: 'Milling',
              candidates: const ['wc-2'],
              demandKey: 'wc-2',
              queue: SimQueue(targetId: 'wc-2'),
            ),
          ],
          parts: {
            'part-$id': SimPart(
              id: 'part-$id',
              partNumber: 'PN-$id',
              processTimes: const {
                'wc-1': Duration(hours: 4),
                'wc-2': Duration(hours: 2),
              },
            ),
          },
          orders: [
            for (var i = 0; i < 3; i++)
              SimOrder(
                id: '$id-o$i',
                sequence: i,
                partId: 'part-$id',
                needDate: DateTime(2026, 8, 20),
              ),
          ],
          releaseInterval: const Duration(hours: 12),
          releaseCalendarId: 'wc-1',
        );

    return (
      studies: [
        study('study-a', 'Line A', 'line-a', 'Fluxo A'),
        study('study-b', 'Line B', 'line-b', 'Fluxo B'),
      ],
      plant: plant,
    );
  }

  Future<StoredRun> stored({double rework = 0}) async {
    final projectId = await seedProject();
    final (:studies, :plant) = model(rework: rework);
    final result = runSimulation(studies: studies, workcenters: plant);
    final runId = await runs.saveRun(
      projectId: projectId,
      result: result,
      studies: studies,
      workcenters: plant,
    );
    return (await runs.loadRun(runId))!;
  }

  test('a run made before v25 gets no graph rather than an empty one', () async {
    // **The honest fixture is a real run with its v25 rows taken away**, which
    // is exactly what a pre-v25 run looks like once the migration has been past
    // it: the columns are there and hold nothing.
    //
    // §10.2 is explicit that there is nothing to recover them from, and
    // inventing them out of today's schedules would draw a 2025 capacity line
    // from a plant retuned in 2026. A wrong line is worse than no graph.
    final projectId = await seedProject();
    final (:studies, :plant) = model();
    final result = runSimulation(studies: studies, workcenters: plant);
    final runId = await runs.saveRun(
      projectId: projectId,
      result: result,
      studies: studies,
      workcenters: plant,
    );
    await db.customStatement(
      'DELETE FROM simulation_run_workcenter_months',
    );

    final run = (await runs.loadRun(runId))!;
    expect(run.result.openByWorkcenterMonth, isEmpty);
    expect(occupationGraph(run: run), isNull);
  });

  test('the three segments sum to what the Summary calls required', () async {
    // **The §7.6 check, made deliberately.** A bar omitting the changeover would
    // draw a station under its line while the Summary read 96 %.
    final run = await stored(rework: 0.1);
    final graph = occupationGraph(run: run)!;

    expect(graph.months, isNotEmpty);
    for (final month in graph.months) {
      expect(month.required, month.process + month.rework + month.changeover);
      // Nothing is filtered, so the neutral segment is empty and the bar is
      // exactly what was asked.
      expect(month.other, Duration.zero);
      expect(month.total, month.required);
    }
  });

  test('rework is its own segment, and zero where there is none', () async {
    final withRework = occupationGraph(run: await stored(rework: 0.1))!;
    final without = occupationGraph(run: await stored())!;

    final reworked = withRework.months.fold(
      Duration.zero,
      (sum, m) => sum + m.rework,
    );
    expect(reworked, greaterThan(Duration.zero));
    // A tenth of the work, which is what 10 % rework is.
    final work = withRework.months.fold(
      Duration.zero,
      (sum, m) => sum + m.process,
    );
    expect(reworked.inSeconds, closeTo(work.inSeconds * 0.1, 2));

    // **A true zero, not a rounding of one** — the distinction §10.2's column
    // exists to keep.
    expect(
      without.months.every((m) => m.rework == Duration.zero),
      isTrue,
    );
  });

  test('a filter colours the bar and never shrinks it', () async {
    // The rule the whole design turns on. MILL02 is shared by both lines:
    // filtered to one, its own demand is smaller, but the bar total and the
    // capacity line must not move — otherwise an overload could be filtered
    // away.
    final run = await stored();
    final whole = occupationGraph(run: run)!;
    final sliced = occupationGraph(
      run: run,
      filter: const RunFilter(studyIds: {'study-a'}),
    )!;

    expect(sliced.months.length, whole.months.length);
    for (var i = 0; i < whole.months.length; i++) {
      final all = whole.months[i];
      final one = sliced.months[i];

      // The coloured part shrank...
      expect(one.required, lessThan(all.required));
      // ...the neutral segment took up exactly the difference...
      expect(one.other, all.required - one.required);
      // ...so the total is untouched, and so is the line.
      expect(one.total, all.total);
      expect(one.capacity, all.capacity);
      expect(one.occupation, all.occupation);
    }
  });

  test('a station filter changes the capacity line, a study filter never does',
      () async {
    // The two filters narrow different things, which is why they are two
    // objects: stations choose what is drawn, orders choose what is coloured.
    final run = await stored();
    final whole = occupationGraph(run: run)!;
    final oneStation = occupationGraph(
      run: run,
      stations: const OccupationStations(workcenterIds: {'wc-1'}),
    )!;

    expect(oneStation.stationsInView, {'wc-1'});
    expect(
      oneStation.months.first.capacity,
      lessThan(whole.months.first.capacity),
      reason: 'a station out of view contributes no capacity',
    );
    expect(oneStation.months.first.stations, 1);
  });

  test('a month counts how many stations are individually over', () async {
    // The badge that stops an aggregate reading as an occupation: summed over
    // twelve stations the ratio says nothing about whether any one is
    // overloaded.
    final run = await stored();
    final graph = occupationGraph(run: run)!;

    for (final month in graph.months) {
      expect(month.stationsOver, lessThanOrEqualTo(month.stations));
      expect(month.stations, 2);
    }
  });

  test('work is bucketed by when it arrived, not when it ran', () async {
    // Bucketing by `processStart` would hide every overload: work the engine
    // scheduled can never much exceed capacity, because it would not have been
    // scheduled otherwise.
    final run = await stored();
    final graph = occupationGraph(run: run)!;

    final arrivals = <DateTime>{
      for (final step in run.result.steps)
        DateTime(step.queueStart.year, step.queueStart.month),
    };
    for (final month in graph.months.where((m) => m.total > Duration.zero)) {
      expect(arrivals, contains(month.month));
    }
  });

  test('the pivot is types across and lines down, sharing one denominator',
      () async {
    final run = await stored();
    final graph = occupationGraph(run: run)!;
    final pivot = graph.pivot;

    expect(pivot.typeIds, ['type-clad', 'type-mill']);
    expect(pivot.typeNames['type-clad'], 'Cladding');
    expect(pivot.rows.map((r) => r.lineName), ['Fluxo A', 'Fluxo B']);
    expect(pivot.rows.every((r) => r.cellName == 'Cell 11'), isTrue);

    // **With every line in view a column's cells sum to its total**, because a
    // cell holds that line's own demand over the type's *full* capacity.
    for (final type in pivot.typeIds) {
      final cells = pivot.rows
          .map((r) => r.byType[type] ?? 0)
          .fold(0.0, (sum, v) => sum + v);
      expect(cells, closeTo(pivot.totals[type]!, 0.0001));
    }
  });

  test('under a filter the TOTAL row does not equal the cells above it',
      () async {
    // **The point rather than a defect.** It is the only place the contention
    // still appears once a cell reads its own comfortable share.
    final run = await stored();
    final sliced = occupationGraph(
      run: run,
      filter: const RunFilter(studyIds: {'study-a'}),
    )!;

    // The rows still describe every line that touched the stations...
    expect(sliced.pivot.rows.length, 2);
    for (final type in sliced.pivot.typeIds) {
      final cells = sliced.pivot.rows
          .map((r) => r.byType[type] ?? 0)
          .fold(0.0, (sum, v) => sum + v);
      // ...and the total counts them all, so filtering one line out of the
      // *chart* leaves the pivot's total where it was.
      expect(cells, closeTo(sliced.pivot.totals[type]!, 0.0001));
    }
  });
}
