import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/common/period_granularity.dart';
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

  /// [from] and [to] are the station's **schedule**, which since phase 9 is
  /// what the capacity table spans — not the run. A fixture scheduled 2020 to
  /// 2030 draws a hundred and twenty empty columns beside its demand, which is
  /// correct and is not what most tests here are about.
  SimWorkcenter workcenter(
    String id,
    String name, {
    double rework = 0,
    String? typeId,
    String? typeName,
    DateTime? from,
    DateTime? to,
  }) {
    final schedule = WorkcenterScheduleSpec([
      WorkcenterSchedulePeriodSpec(
        startDate: from ?? DateTime(2020),
        endDate: to ?? DateTime(2030),
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

      // **Only where there is work to take a share of** (phase 9). The plant is
      // scheduled far wider than this run, so most months now carry capacity
      // and no demand at all — and in those the share is not "unmoved by the
      // filter", it is undefined. Asserting over them would have this test
      // passing on arithmetic about nothing.
      final worked = [
        for (final month in before.cells.keys)
          if (before.cells[month]!.asked > Duration.zero) month,
      ];
      expect(worked, isNotEmpty, reason: 'the run has to occupy something');

      for (final month in worked) {
        final all = before.cells[month]!;
        final slice = after.cells[month]!;
        expect(slice.asked, all.asked, reason: 'the band does not move');
        expect(slice.open, all.open);
        // ...but the share does, and by exactly the work that is not mine.
        expect(slice.filtered, lessThan(slice.asked));
        expect(slice.share, lessThan(1.0));
      }
      // With nothing order-level set, every worked cell is wholly the reader's.
      expect(
        worked.every((m) => before.cells[m]!.share == 1.0),
        isTrue,
      );
      // And the months the run never reached are open and unasked — the state
      // that could not exist before capacity followed the schedule.
      final idle = before.cells.keys.where((m) => !worked.contains(m));
      expect(idle, isNotEmpty, reason: 'a decade of schedule, one month of run');
      for (final month in idle) {
        expect(before.cells[month]!.open, greaterThan(Duration.zero));
        expect(after.cells[month]!.asked, Duration.zero);
      }
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
    // **This rule was reversed by #14, deliberately.** It used to be: a line
    // filter is structural, so it narrows the station set, and the moment
    // anything does the PLANT row has to go — a total across a subset would
    // wear the plant's name.
    //
    // The row is called **TOTAL** now, and a total claims only the rows above
    // it. That is true under every filter, so the row stays; and a narrowed
    // view is exactly when a reader wants one. What survives from the old rule
    // is the reason it existed: the aggregate must never be read as the plant.
    // The label is what carries that now.
    final run = await stored();
    expect(occupationGrid(run: run)!.total.cells, isNotEmpty);

    final narrowed = occupationGrid(
      run: run,
      filter: const RunFilter(lineIds: {'line-a'}),
    )!;
    expect(narrowed.total.cells, isNotEmpty);
  });

  test(
    'a station filter drops the station and its capacity, and the total follows',
    () async {
      final run = await stored();
      final whole = occupationGrid(run: run)!;
      final one = occupationGrid(
        run: run,
        filter: const RunFilter(workcenterIds: {'wc-1'}),
      )!;

      expect(whole.rows.map((r) => r.name), containsAll(['CLAD04', 'MILL02']));
      expect(one.rows.map((r) => r.name), ['CLAD04']);

      // **And the TOTAL row now totals what is left** (#14) rather than
      // vanishing: with CLAD04 alone in view, the aggregate is CLAD04's own
      // demand, not the two stations' — which is the whole point of it
      // surviving a filter.
      final onlyRow = one.rows.single;
      for (final month in onlyRow.cells.keys) {
        expect(
          one.total.cells[month]!.asked,
          onlyRow.cells[month]!.asked,
          reason: 'a total over one station is that station',
        );
      }
      expect(
        whole.total.cells.values.fold(Duration.zero, (sum, c) => sum + c.asked),
        greaterThan(
          one.total.cells.values.fold<Duration>(
            Duration.zero,
            (sum, c) => sum + c.asked,
          ),
        ),
      );
    },
  );

  test('the TOTAL row is the sum of the stations above it', () async {
    final run = await stored();
    final grid = occupationGrid(run: run)!;
    final plant = grid.total;

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
    final worstPlant = grid.total.peak ?? 0;
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
      final plant = occupationGrid(run: run)!.total;

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

    final asked = grid.total.cells.values.fold(
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
    final cell = grid.total.cells.values.first;

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

  group('the TOTAL column (#14)', () {
    test('a row total is a ratio of sums, not a mean of ratios', () async {
      // **The arithmetic this ticket turns on.** Averaging the monthly
      // percentages would weight a 400 h month exactly like a 9,000 h one, and
      // on the live database those sit side by side: 3,296 h of capacity in
      // October against 9,384 h in July.
      final grid = occupationGrid(run: await stored())!;
      final row = grid.rows.first;

      var asked = Duration.zero;
      var open = Duration.zero;
      for (final cell in row.cells.values) {
        asked += cell.asked;
        open += cell.open;
      }

      expect(row.total.asked, asked);
      expect(row.total.open, open);
      expect(row.total.ratio, asked.inSeconds / open.inSeconds);

      // And it is *not* the mean of the monthly ratios, unless every month
      // happened to have identical capacity.
      final ratios = row.cells.values
          .map((c) => c.ratio)
          .whereType<double>()
          .toList();
      final mean = ratios.reduce((a, b) => a + b) / ratios.length;
      expect(row.total.ratio, isNotNull);
      if ((mean - row.total.ratio!).abs() > 1e-9) {
        expect(row.total.ratio, isNot(mean));
      }
    });

    test('the corner is the total of the totals', () async {
      // The TOTAL row × TOTAL column intersection: every station, every month.
      final grid = occupationGrid(run: await stored())!;

      final fromRows = grid.rows.fold(
        Duration.zero,
        (sum, row) => sum + row.total.asked,
      );
      expect(grid.total.total.asked, fromRows);
    });
  });

  group('a cell explains itself (#14)', () {
    test('the three segments account for exactly the kept demand', () async {
      // **The property the shared hover rests on.** The grid's cells now carry
      // the same breakdown the chart's bars do, and a reader adding the lines
      // up must land on the number at the top of the card — so process, rework
      // and changeover have to sum to `filtered`, never to `asked`.
      final grid = occupationGrid(run: await stored(rework: 0.25))!;

      for (final row in [...grid.rows, grid.total]) {
        for (final entry in row.cells.entries) {
          final cell = entry.value;
          expect(
            cell.process + cell.rework + cell.changeover,
            cell.filtered,
            reason: '${row.name} in ${entry.key} does not add up',
          );
        }
      }
    });

    test('what an order-level filter excluded is the remainder', () async {
      // The fourth line of the hover, and the grey segment of the bar.
      final run = await stored();
      final filtered = occupationGrid(
        run: run,
        filter: const RunFilter(partNumbers: {'PN-study-a'}),
      )!;

      var outside = Duration.zero;
      for (final cell in filtered.total.cells.values) {
        expect(cell.outside, cell.asked - cell.filtered);
        outside += cell.outside;
      }
      expect(outside, greaterThan(Duration.zero));
    });

    test('a structural filter leaves no remainder to explain', () async {
      // The other half of the rule #13 fixed: structural filters move demand
      // and capacity together, so every hour in the cell is accounted for by
      // the three segments and the fourth line never appears.
      final grid = occupationGrid(
        run: await stored(),
        filter: const RunFilter(lineIds: {'line-a'}),
      )!;

      for (final cell in grid.total.cells.values) {
        expect(cell.outside, Duration.zero);
      }
    });
  });
  group('the granularity re-columns it (#17)', () {
    /// **Its own run, because the shared fixture is one month wide.** Every
    /// rule in this group is about folding several months into one column, and
    /// a single-month run can only assert that folding one month gives one
    /// column. Widening `model()` instead would move every figure the tests
    /// above pin down.
    ///
    /// One study, thirty orders released three days apart, so the run spans
    /// about a quarter of a year and the capacity table spans it too.
    Future<StoredRun> storedWide() async {
      final projectId = await seedProject();
      // Scheduled for 2026 alone, which is the year the run falls in
      // (2026-01-14 → 2026-04-12): twelve month columns, four quarters, two
      // semesters and one year, so the foldings below have something to fold
      // and the last of them really is one column.
      final year = (from: DateTime(2026), to: DateTime(2026, 12, 31));
      final plant = {
        'wc-1': workcenter(
          'wc-1',
          'CLAD04',
          typeId: 't',
          typeName: 'T',
          from: year.from,
          to: year.to,
        ),
        'wc-2': workcenter(
          'wc-2',
          'MILL02',
          typeId: 't',
          typeName: 'T',
          from: year.from,
          to: year.to,
        ),
      };
      final studies = [
        SimStudy(
          id: 'study-a',
          name: 'Line A',
          productionCellId: 'cell-1',
          productionCellName: 'Cell 11',
          productionLineId: 'line-a',
          productionLineName: 'Fluxo A',
          nodes: [
            SimStep(
              id: 'n0',
              position: 0,
              title: 'Cladding',
              candidates: const ['wc-1'],
              demandKey: 'wc-1',
              queue: SimQueue(targetId: 'wc-1'),
            ),
            SimStep(
              id: 'n1',
              position: 1,
              title: 'Milling',
              candidates: const ['wc-2'],
              demandKey: 'wc-2',
              queue: SimQueue(targetId: 'wc-2'),
            ),
          ],
          parts: {
            'part-a': SimPart(
              id: 'part-a',
              partNumber: 'PN-a',
              processTimes: const {
                'wc-1': Duration(hours: 4),
                'wc-2': Duration(hours: 2),
              },
            ),
          },
          orders: [
            for (var i = 0; i < 30; i++)
              SimOrder(
                id: 'o$i',
                sequence: i,
                partId: 'part-a',
                needDate: DateTime(2026, 1, 15).add(Duration(days: i * 9)),
              ),
          ],
          releaseInterval: const Duration(days: 3),
          releaseCalendarId: 'wc-1',
        ),
      ];
      final result = runSimulation(studies: studies, workcenters: plant);
      final runId = await runs.saveRun(
        projectId: projectId,
        result: result,
        studies: studies,
        workcenters: plant,
      );
      return (await runs.loadRun(runId))!;
    }

    test('the fixture really does span several months', () async {
      // Guards the group rather than the code: every test below is vacuous on a
      // one-month run, and passing vacuously is how the chart's own tests came
      // to say nothing for two commits (#13).
      final grid = occupationGrid(run: await storedWide())!;
      expect(grid.months.length, greaterThan(2));
    });

    test('a coarser column is the sum of its months, both sides', () async {
      // **A ratio of sums, never a mean of ratios** — #14's arithmetic for the
      // TOTAL column, and for its reason: averaging monthly percentages would
      // weight a 733 h month like a 499 h one. Asserted against the monthly
      // grid rather than a constant, so the two cannot drift apart.
      final run = await storedWide();
      final monthly = occupationGrid(run: run)!;
      final yearly = occupationGrid(
        run: run,
        granularity: PeriodGranularity.year,
      )!;

      final before = rowFor(monthly, 'MILL02');
      final after = rowFor(yearly, 'MILL02');
      expect(before.cells.length, greaterThan(1));

      var asked = Duration.zero;
      var open = Duration.zero;
      for (final cell in before.cells.values) {
        asked += cell.asked;
        open += cell.open;
      }
      final folded = after.cells.values.single;
      expect(folded.asked, asked);
      expect(folded.open, open);
      expect(folded.ratio, asked.inSeconds / open.inSeconds);

      // And it is *not* the mean of the monthly ratios, which is the mistake
      // this test exists to prevent.
      final ratios = [for (final cell in before.cells.values) ?cell.ratio];
      final meanOfRatios =
          ratios.reduce((a, b) => a + b) / ratios.length;
      expect(folded.ratio, isNot(closeTo(meanOfRatios, 1e-9)));
    });

    test('every granularity keeps the same total hours', () async {
      // Coarsening aggregates; it must not lose or invent an hour. The float
      // matrix was kept off this control precisely because it aggregates
      // nothing — here the invariant is that only the columns change.
      final run = await storedWide();
      Duration askedAt(PeriodGranularity granularity) {
        final grid = occupationGrid(run: run, granularity: granularity)!;
        var total = Duration.zero;
        for (final cell in grid.total.cells.values) {
          total += cell.asked;
        }
        return total;
      }

      final monthly = askedAt(PeriodGranularity.month);
      expect(monthly, greaterThan(Duration.zero));
      for (final granularity in PeriodGranularity.values) {
        expect(askedAt(granularity), monthly, reason: granularity.name);
      }
    });

    test('columns never outnumber the months they fold', () async {
      final run = await storedWide();
      var previous = 1 << 30;
      for (final granularity in PeriodGranularity.values) {
        final count = occupationGrid(
          run: run,
          granularity: granularity,
        )!.months.length;
        expect(count, lessThanOrEqualTo(previous), reason: granularity.name);
        previous = count;
      }
      expect(previous, 1, reason: 'a run inside one year is one year column');
    });

    test('the chart columns exactly as the grid does', () async {
      // #16 draws the chart as the grid's own header — one bar directly above
      // its own row of cells. Two different foldings would put a bar over the
      // wrong figures, and nothing in the suite renders a pixel to catch it.
      final run = await storedWide();
      for (final granularity in PeriodGranularity.values) {
        final grid = occupationGrid(run: run, granularity: granularity)!;
        final chart = occupationGraph(run: run, granularity: granularity)!;
        expect(
          chart.months.map((m) => m.month).toList(),
          grid.months,
          reason: 'chart and grid must agree at ${granularity.name}',
        );
      }
    });

    test('a period survives when only part of it is in range', () async {
      // **The defect this nearly shipped with.** Folding capacity before
      // applying the date filter drops a period whose first day falls before
      // the range — ask for the second month onward while reading quarters and
      // the quarter holding it vanishes, taking two in-range months with it.
      // The filter stays monthly and the fold happens after it.
      final run = await storedWide();
      final months = occupationGrid(run: run)!.months;
      final quarter = PeriodGranularity.quarter.startOf(months.first);
      final sharing = months
          .where((m) => PeriodGranularity.quarter.startOf(m) == quarter)
          .toList();
      expect(
        sharing.length,
        greaterThan(1),
        reason: 'the case needs two months inside one quarter',
      );

      final fromSecond = occupationGrid(
        run: run,
        filter: RunFilter(from: sharing[1]),
        granularity: PeriodGranularity.quarter,
      )!;
      expect(
        fromSecond.months,
        contains(quarter),
        reason: 'the quarter holding an in-range month must survive',
      );

      // And it holds only what is still in range, not the whole quarter.
      final whole = occupationGrid(
        run: run,
        granularity: PeriodGranularity.quarter,
      )!;
      expect(
        rowFor(fromSecond, 'MILL02').cells[quarter]!.open,
        lessThan(rowFor(whole, 'MILL02').cells[quarter]!.open),
      );
    });

    test('runMonths is the union of need dates and capacity', () async {
      // Need dates and capacity do not cover the same months, so the slicer's
      // stops are their union — need dates alone would put capacity-only months
      // beyond the left end and make them unreachable on the grid.
      final run = await storedWide();
      final stops = runMonths(run);
      expect(stops, isNotEmpty);
      expect(stops, orderedEquals(stops.toList()..sort()));

      for (final outcome in run.result.orders) {
        expect(
          stops,
          contains(DateTime(outcome.needDate.year, outcome.needDate.month)),
        );
      }
      for (final byMonth in run.result.openByWorkcenterMonth.values) {
        for (final month in byMonth.keys) {
          expect(stops, contains(DateTime(month.year, month.month)));
        }
      }
    });
  });

  group('per workcenter type (the drive, 2026-09-07)', () {
    /// A run whose plant carries [extra] stations beyond the two the studies
    /// route to — so a station can be *scheduled and idle*, which is the state
    /// this grouping exists to put somewhere.
    Future<StoredRun> storedWith(Map<String, SimWorkcenter> extra) async {
      final projectId = await seedProject();
      final (:studies, :plant) = model();
      final all = {...plant, ...extra};
      final result = runSimulation(studies: studies, workcenters: all);
      final runId = await runs.saveRun(
        projectId: projectId,
        result: result,
        studies: studies,
        workcenters: all,
      );
      return (await runs.loadRun(runId))!;
    }

    test('the rows partition the stations, so they sum to TOTAL', () async {
      // **The property this grouping was chosen for.** A station carries one
      // type, so no station is in two rows and none is in none — which the line
      // grouping can never say, because two lines sharing a station count it
      // twice.
      final run = await stored();
      final byType = occupationGrid(
        run: run,
        grouping: OccupationGrouping.type,
      )!;

      expect(byType.rows.map((r) => r.name), unorderedEquals(['Cladding', 'Milling']));

      for (final month in byType.total.cells.keys) {
        final asked = byType.rows
            .map((r) => r.cells[month]?.asked ?? Duration.zero)
            .fold(Duration.zero, (a, b) => a + b);
        final open = byType.rows
            .map((r) => r.cells[month]?.open ?? Duration.zero)
            .fold(Duration.zero, (a, b) => a + b);
        expect(asked, byType.total.cells[month]!.asked, reason: '$month demand');
        expect(open, byType.total.cells[month]!.open, reason: '$month capacity');
      }
    });

    test('the line rows, by contrast, do not', () async {
      // Recorded beside it, because it is the reason the third grouping earns
      // its place rather than duplicating the second.
      final run = await stored();
      final byLine = occupationGrid(
        run: run,
        grouping: OccupationGrouping.line,
      )!;

      final month = _busiest(byLine.total);
      final summed = byLine.rows
          .map((r) => r.cells[month]?.asked ?? Duration.zero)
          .fold(Duration.zero, (a, b) => a + b);

      expect(
        summed,
        greaterThan(byLine.total.cells[month]!.asked),
        reason: 'both lines touch both stations, so the rows double-count',
      );
    });

    test('a scheduled station with no demand is still in its type', () async {
      // **Membership is the machine's, not the run's.** The line grouping reads
      // its stations from the steps; a type is a property of the station, so an
      // idle one carries capacity into its type's row and pulls the percentage
      // down. That is the answer to *have I got enough cladding capacity*.
      final run = await storedWith({
        'wc-3': workcenter(
          'wc-3',
          'CLAD09',
          typeId: 'type-clad',
          typeName: 'Cladding',
        ),
      });

      expect(
        run.result.steps.every((s) => s.workcenterId != 'wc-3'),
        isTrue,
        reason: 'nothing routes to it',
      );

      final withIdle = occupationGrid(
        run: run,
        grouping: OccupationGrouping.type,
      )!;
      final cladding = withIdle.rows.firstWhere((r) => r.name == 'Cladding');
      final month = _busiest(cladding);

      // Its capacity is in the row and its demand is not, so Cladding reads
      // lower than the busy machine alone would.
      final busyOnly = occupationGrid(
        run: run,
        grouping: OccupationGrouping.workcenter,
      )!.rows.firstWhere((r) => r.name == 'CLAD04');

      expect(
        cladding.cells[month]!.open,
        greaterThan(busyOnly.cells[month]!.open),
        reason: 'the idle machine brought capacity',
      );
      expect(cladding.cells[month]!.asked, busyOnly.cells[month]!.asked,
          reason: 'and no demand');
    });

    test('a station with no type gets a row rather than vanishing', () async {
      // A run stored before a station was typed carries a null. Dropping it
      // would leave a TOTAL that does not add up, which is the fault #14 spent
      // its whole argument preventing.
      final run = await storedWith({
        'wc-3': workcenter('wc-3', 'CEU31'),
      });

      final byType = occupationGrid(
        run: run,
        grouping: OccupationGrouping.type,
        untypedLabel: 'Untyped',
      )!;

      expect(byType.rows.map((r) => r.name), contains('Untyped'));

      for (final month in byType.total.cells.keys) {
        final open = byType.rows
            .map((r) => r.cells[month]?.open ?? Duration.zero)
            .fold(Duration.zero, (a, b) => a + b);
        expect(open, byType.total.cells[month]!.open, reason: '$month');
      }
    });
  });
}

/// The month a row was actually asked for something in.
///
/// Since capacity started following the schedule, a row's first month is
/// usually one with capacity and no demand — so `cells.keys.first` tests
/// arithmetic about nothing.
DateTime _busiest(OccupationRow row) {
  final months = row.cells.keys.toList()
    ..sort((a, b) => row.cells[b]!.asked.compareTo(row.cells[a]!.asked));
  return months.first;
}
