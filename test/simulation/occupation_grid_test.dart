import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/application/occupation_graph.dart';
import 'package:flowmap/src/features/simulation/application/occupation_grid.dart';
import 'package:flowmap/src/features/simulation/application/run_filter.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Demand against capacity, station by station and month by month (§10.3, #9).
///
/// Built from a **stored** run rather than a fresh result, because that is what
/// the grid reads and because the thing it needs — the monthly capacity — is a
/// v25 column whose whole point is surviving the trip through the database.
///
/// **This file was `occupation_graph_test.dart`** and its nine tests were about
/// a stacked bar: three segments summing to the required time, a neutral
/// segment for load outside the filter, a per-month count of stations over, and
/// a pivot of lines against types. The chart was deleted (#9) and so were they.
/// What survived is the fixture — two lines sharing MILL02, which is the shape
/// every rule here is still about — and the three claims that were never about
/// the bar: bucketing by arrival, a pre-v25 run drawing nothing, and a filter
/// never shrinking what a machine was asked for.
///
/// **The chart then came back (`795ac6e`, #13) and its tests did not**, which is
/// how the neutral segment came to be drawn under a study, cell or line filter
/// for two commits without anything failing. The field found it instead. The
/// `the chart` group at the foot of this file is the part that had to return:
/// not the pivot or the over-count, but the one rule the two surfaces are
/// supposed to share and briefly did not.
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

  OccupationRow rowFor(OccupationGrid grid, String name) =>
      grid.rows.firstWhere((r) => r.name == name);

  test('a run made before v25 gets no grid rather than an empty one', () async {
    // **The honest fixture is a real run with its v25 rows taken away**, which
    // is what a pre-v25 run looks like once the migration has been past it: the
    // columns are there and hold nothing. §10.2 is explicit that inventing them
    // out of today's schedules would draw a 2025 capacity from a plant retuned
    // in 2026 — and 144 of the live database's 147 runs are in this state, so
    // this is the common case rather than the edge.
    final projectId = await seedProject();
    final (:studies, :plant) = model();
    final result = runSimulation(studies: studies, workcenters: plant);
    final runId = await runs.saveRun(
      projectId: projectId,
      result: result,
      studies: studies,
      workcenters: plant,
    );
    await db.customStatement('DELETE FROM simulation_run_workcenter_months');

    final run = (await runs.loadRun(runId))!;
    expect(run.result.openByWorkcenterMonth, isEmpty);
    expect(occupationGrid(run: run), isNull);
  });

  test(
    'a structural filter never shrinks what a machine was asked for',
    () async {
      // **The rule the whole design turns on**, and the one the chart got wrong.
      // MILL02 is shared by both lines: filtered to one, the *cell* must still
      // read everyone's demand over MILL02's full capacity, or no station would
      // ever be over 100 % under a filter and the view would stop finding
      // overloads the moment anyone used it.
      final run = await stored();
      final whole = occupationGrid(run: run)!;
      final oneLine = occupationGrid(
        run: run,
        filter: const RunFilter(studyIds: {'study-a'}),
      )!;

      final before = rowFor(whole, 'MILL02');
      final after = rowFor(oneLine, 'MILL02');
      for (final month in before.cells.keys) {
        expect(
          after.cells[month]!.asked,
          before.cells[month]!.asked,
          reason:
              'a filter chooses what you look at, not what a machine was '
              'asked for',
        );
        expect(after.cells[month]!.open, before.cells[month]!.open);
        expect(after.cells[month]!.ratio, before.cells[month]!.ratio);
      }
    },
  );

  test(
    'an order-level filter moves the share and leaves the number alone',
    () async {
      // The other half: project, part and order number cannot choose stations, so
      // capacity is untouched and the cell dims instead. This is what tells
      // "CEU27 is at 100 % and 80 of it is yours" from "CEU32 is at 147 % and
      // none of it is" — same colour, opposite action.
      final run = await stored();
      final whole = occupationGrid(run: run)!;
      final mine = occupationGrid(
        run: run,
        filter: const RunFilter(partNumbers: {'PN-study-a'}),
      )!;

      final before = rowFor(whole, 'MILL02');
      final after = rowFor(mine, 'MILL02');
      for (final month in before.cells.keys) {
        final all = before.cells[month]!;
        final slice = after.cells[month]!;
        expect(slice.asked, all.asked, reason: 'the band does not move');
        expect(slice.open, all.open);
        // ...but the share does, and by exactly the work that is not mine.
        expect(slice.filtered, lessThan(slice.asked));
        expect(slice.share, lessThan(1.0));
      }
      // With nothing order-level set, every cell is wholly the reader's.
      expect(before.cells.values.every((c) => c.share == 1.0), isTrue);
    },
  );

  test('a study filter reaches the grid at all', () async {
    // **The bug the field found**: "the occupation tables are not being
    // filtered when I select different study, cell or lines". The grid applied
    // only `typeIds` and `workcenterIds`, and a comment claimed the other three
    // were handled elsewhere — they were handled nowhere, so choosing a study
    // narrowed every other surface on the page and left this one drawing the
    // whole plant.
    //
    // Both studies here visit both stations, so a study filter cannot remove a
    // row from this fixture — what it can show is that the filter is *read*.
    // A study nothing matches must leave no grid, which is only true if the
    // set is being consulted.
    final run = await stored();
    expect(occupationGrid(run: run), isNotNull);
    expect(
      occupationGrid(
        run: run,
        filter: const RunFilter(studyIds: {'nobody'}),
      ),
      isNull,
      reason: 'a study filter that matches nothing leaves no stations in view',
    );
  });

  test('a line filter narrows the stations, so the plant row goes', () async {
    // The half the fixture can show directly: a line filter is structural, so
    // it narrows the station set — and the moment anything does, the PLANT row
    // has to go, because a total across a subset would wear the plant's name.
    final run = await stored();
    expect(occupationGrid(run: run)!.plant, isNotNull);
    expect(
      occupationGrid(
        run: run,
        filter: const RunFilter(lineIds: {'line-a'}),
      )!.plant,
      isNull,
    );
  });

  test(
    'a station filter drops the station, its capacity and the plant row',
    () async {
      final run = await stored();
      final whole = occupationGrid(run: run)!;
      final one = occupationGrid(
        run: run,
        filter: const RunFilter(workcenterIds: {'wc-1'}),
      )!;

      expect(whole.rows.map((r) => r.name), containsAll(['CLAD04', 'MILL02']));
      expect(one.rows.map((r) => r.name), ['CLAD04']);

      // **And the plant row goes with it.** Once anything has narrowed the
      // station set, a total across what is left would be a partial wearing the
      // plant's name.
      expect(whole.plant, isNotNull);
      expect(one.plant, isNull);
    },
  );

  test('the plant row is the sum of the stations under it', () async {
    final run = await stored();
    final grid = occupationGrid(run: run)!;
    final plant = grid.plant!;

    for (final month in plant.cells.keys) {
      final asked = grid.rows.fold(
        Duration.zero,
        (sum, row) => sum + (row.cells[month]?.asked ?? Duration.zero),
      );
      final open = grid.rows.fold(
        Duration.zero,
        (sum, row) => sum + (row.cells[month]?.open ?? Duration.zero),
      );
      expect(plant.cells[month]!.asked, asked);
      expect(plant.cells[month]!.open, open);
    }
  });

  test('a plant total can hide a station that is over', () async {
    // **The finding that killed the chart**, as a property. On the live
    // database the aggregate never once broke its line while single stations
    // reached 149 % — so the grid must be able to show a plant under its
    // threshold with a station above it, which an aggregate figure cannot.
    final run = await stored();
    final grid = occupationGrid(run: run)!;

    final worstStation = grid.rows
        .map((r) => r.peak ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final worstPlant = grid.plant!.peak ?? 0;
    expect(
      worstStation,
      greaterThanOrEqualTo(worstPlant),
      reason:
          'an aggregate can never be worse than its worst member, which is '
          'exactly why it cannot report the finding',
    );
  });

  test(
    'per line, a row is everyone at the stations that line touches',
    () async {
      // Arithmetically identical to filtering to that line — which is what lets
      // the bands carry over unchanged and makes a line row one PLANT row per
      // line. Both lines here touch both stations, so both rows equal the plant.
      final run = await stored();
      final byLine = occupationGrid(
        run: run,
        grouping: OccupationGrouping.line,
      )!;
      final plant = occupationGrid(run: run)!.plant!;

      expect(
        byLine.rows.map((r) => r.name),
        containsAll(['Fluxo A', 'Fluxo B']),
      );
      for (final row in byLine.rows) {
        for (final month in row.cells.keys) {
          expect(
            row.cells[month]!.asked,
            plant.cells[month]!.asked,
            reason:
                'both lines touch both stations, so both see all of it — '
                'the known cost #9 accepted',
          );
        }
      }
    },
  );

  test('work is bucketed by when it arrived, not when it ran', () async {
    // Bucketing by `processStart` would hide every overload: work the engine
    // scheduled can never much exceed capacity, because it would not have been
    // scheduled otherwise.
    final run = await stored();
    final grid = occupationGrid(run: run)!;

    final arrivals = <DateTime>{
      for (final step in run.result.steps)
        DateTime(step.queueStart.year, step.queueStart.month),
    };
    for (final row in grid.rows) {
      for (final entry in row.cells.entries) {
        if (entry.value.asked == Duration.zero) continue;
        expect(arrivals, contains(entry.key));
      }
    }
  });

  test('changeover stays inside the number (§7.6)', () async {
    // A cell omitting it would disagree with the Summary, which is the §7.6
    // check made deliberately rather than left to be noticed.
    final run = await stored();
    final grid = occupationGrid(run: run)!;

    final asked = grid.plant!.cells.values.fold(
      Duration.zero,
      (sum, c) => sum + c.asked,
    );
    final work = run.result.steps.fold(
      Duration.zero,
      (sum, s) =>
          sum +
          Duration(seconds: s.processSeconds ?? 0) +
          Duration(seconds: s.changeoverSeconds ?? 0),
    );
    expect(asked, work);
  });

  test('the three units read one cell three ways', () async {
    final run = await stored();
    final grid = occupationGrid(run: run)!;
    final cell = grid.plant!.cells.values.first;

    // `%` is asked ÷ open; `gap` is open − asked; `hours` is the pair. They are
    // one number, so they cannot disagree — which is what makes the switch a
    // way of reading rather than three figures to reconcile.
    expect(cell.ratio, cell.asked.inSeconds / cell.open.inSeconds);
    expect(cell.gap, cell.open - cell.asked);
    expect(
      cell.gap.isNegative,
      (cell.ratio ?? 0) > 1,
      reason: 'over capacity and a negative gap are the same statement',
    );
  });

  group('the chart', () {
    Duration greyIn(OccupationGraph graph) =>
        graph.months.fold(Duration.zero, (sum, month) => sum + month.other);

    test('a structural filter leaves no neutral segment at all', () async {
      // **The bug the field found**: "the graph is still showing the outside
      // filter when i filter studies, cells, lines, workcenter type and
      // workcenter. I don't want that."
      //
      // `occupationGraph` passed the *whole* filter through to `kept`, so a
      // structural filter narrowed the station set and simultaneously dropped
      // every other study's orders out of the kept set — painting their work at
      // the shared stations grey. `occupation_grid.dart` has always stripped
      // the structural filters out of that computation; the chart never did.
      //
      // Both studies visit both stations here, so a line filter cannot change
      // which stations are in view: any grey it produces is the defect and
      // nothing else.
      final run = await stored();

      for (final filter in const [
        RunFilter(studyIds: {'study-a'}),
        RunFilter(cellIds: {'cell-1'}),
        RunFilter(lineIds: {'line-a'}),
        RunFilter(typeIds: {'type-mill'}),
        RunFilter(workcenterIds: {'wc-2'}),
      ]) {
        final graph = occupationGraph(run: run, filter: filter)!;
        expect(
          greyIn(graph),
          Duration.zero,
          reason: 'structural filter $filter produced a neutral segment',
        );
      }
    });

    test('an order-level filter still produces one', () async {
      // The other half of the rule, and the reason the segment exists at all:
      // capacity is fixed, so the bar keeps its full height and the part of it
      // that is not yours goes grey. Without this the fix above would read
      // equally well as "the segment never appears", which is not the decision.
      final run = await stored();

      final graph = occupationGraph(
        run: run,
        filter: const RunFilter(partNumbers: {'PN-study-a'}),
      )!;

      expect(greyIn(graph), greaterThan(Duration.zero));
    });

    test(
      'a structural filter never shrinks what a machine was asked for',
      () async {
        // The property that stops a filter making an overload disappear. Both
        // studies visit both stations, so narrowing to one line leaves the same
        // stations in view — and therefore the same total demand on them, now
        // entirely coloured rather than partly grey.
        final whole = occupationGraph(run: await stored())!;
        final line = occupationGraph(
          run: await stored(),
          filter: const RunFilter(lineIds: {'line-a'}),
        )!;

        expect(
          line.months.map((m) => m.total),
          whole.months.map((m) => m.total),
        );
        expect(greyIn(whole), Duration.zero);
        expect(greyIn(line), Duration.zero);
      },
    );

    test(
      'the coloured segments sum to the whole bar when nothing is grey',
      () async {
        // What the reader is actually looking at once the neutral segment is
        // gone: three colours that account for every hour the stations were
        // asked for.
        final graph = occupationGraph(
          run: await stored(rework: 0.25),
          filter: const RunFilter(lineIds: {'line-a'}),
        )!;

        for (final month in graph.months) {
          expect(
            month.process + month.rework + month.changeover,
            month.required,
          );
          expect(month.required, month.total);
        }
      },
    );
  });
}
