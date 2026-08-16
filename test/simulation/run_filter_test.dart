import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/simulation/application/run_filter.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reading a slice of a stored run (DESIGN.md §12.1).
void main() {
  final start = DateTime(2026, 1, 1);

  SimulationRunStudy study(
    String id, {
    String? cell,
    String? line,
  }) => SimulationRunStudy(
    runId: 'run-1',
    studyId: id,
    name: id,
    releaseSeconds: 3600,
    priority: 100,
    wipCap: null,
    startBufferDays: 0,
    productionCellId: cell,
    productionCellName: cell,
    productionLineId: line,
    productionLineName: line,
  );

  SimOrderOutcome outcome(
    String id, {
    required String studyId,
    required DateTime need,
    DateTime? delivered,
    String partId = 'p1',
    int sequence = 1,
  }) => SimOrderOutcome(
    studyId: studyId,
    orderId: id,
    sequence: sequence,
    partId: partId,
    needDate: need,
    released: start,
    delivered: delivered,
  );

  SimOrderStep step(String orderId, String workcenterId) => SimOrderStep(
    studyId: 'a',
    orderId: orderId,
    nodeId: 'node-1',
    workcenterId: workcenterId,
    queueStart: start,
    processStart: start,
    processEnd: start.add(const Duration(hours: 1)),
    changeoverIncurred: false,
  );

  StoredRun run() {
    final orders = [
      outcome(
        'o1',
        studyId: 'a',
        need: DateTime(2026, 3, 1),
        delivered: DateTime(2026, 2, 1),
      ),
      outcome(
        'o2',
        studyId: 'a',
        need: DateTime(2026, 9, 1),
        delivered: DateTime(2026, 10, 1),
      ),
      // Never completed, which is what a period filter has to keep visible.
      outcome('o3', studyId: 'b', need: DateTime(2026, 9, 15)),
    ];
    final result = SimRunResult(
      start: start,
      end: DateTime(2026, 12, 31),
      guard: DateTime(2027, 1, 1),
      steps: [step('o1', 'wc-1'), step('o2', 'wc-1'), step('o3', 'wc-2')],
      orders: orders,
      emptySlots: const [],
      // Busy and open live on the run, which is what makes them whole-run
      // figures a slice cannot narrow — they used to be supplied by splicing
      // the metrics after the fact, which hid that.
      busyByWorkcenter: const {
        'wc-1': Duration(hours: 100),
        'wc-2': Duration(hours: 100),
      },
      openByWorkcenter: const {
        'wc-1': Duration(hours: 200),
        'wc-2': Duration(hours: 200),
      },
    );
    final metrics = summariseRun(
      result: result,
      partNumbers: const {'p1': 'PN1'},
      workcenterNames: const {'wc-1': 'CLAD04', 'wc-2': 'TTAT'},
      theoreticalByOrder: const {},
    );

    return StoredRun(
      id: 'run-1',
      projectId: 'proj-1',
      createdAt: start,
      dispatch: DispatchRule.fifo,
      dispatchOverrides: const [],
      studies: [
        study('a', cell: 'cell-1', line: 'line-1'),
        study('b', cell: 'cell-2', line: 'line-2'),
      ],
      result: result,
      metrics: metrics,
      plan: [
        for (final o in orders)
          ProductionPlanRow(
            outcome: o,
            partNumber: 'PN1',
            partDescription: null,
            customerProject: null,
            batchNumber: null,
            batchSize: 1,
            materialDate: null,
            theoreticalLeadTime: const Duration(hours: 1),
          ),
      ],
    );
  }

  test('no filter is the whole run', () {
    final view = filterRun(run(), const RunFilter());
    expect(view.isWholeRun, isTrue);
    expect(view.metrics.orders, 3);
    expect(view.plan, hasLength(3));
    expect(view.stationsAreWholeRun, isFalse);
  });

  test('a study filter keeps its own orders, steps and plan rows', () {
    final view = filterRun(run(), RunFilter.study('a'));

    expect(view.studyIds, {'a'});
    expect(view.metrics.orders, 2);
    expect(view.result.orders.map((o) => o.orderId), ['o1', 'o2']);
    expect(view.result.steps.map((s) => s.orderId), ['o1', 'o2']);
    expect(view.plan.map((r) => r.outcome.orderId), ['o1', 'o2']);
  });

  test('the stations narrow, but their open time does not', () {
    // **Per column, not per table.** This asserted that a slice reported every
    // station in the plant, on the argument that utilisation cannot be
    // narrowed. Utilisation cannot; the rows, the queue and the visits can, and
    // ranking the whole plant under a filter is what the field reported as
    // "the ranked by queue table does not filter".
    //
    // Study a's orders only ever reach CLAD04, so TTAT leaves the table — and
    // CLAD04's open time still describes the whole run, because that is the one
    // figure the run stores as a total.
    final view = filterRun(run(), RunFilter.study('a'));

    expect(view.metrics.workcenters.map((w) => w.name), ['CLAD04']);
    expect(
      view.metrics.workcenters.first.open,
      const Duration(hours: 200),
      reason: 'the whole run, not study a alone',
    );
    expect(view.stationsAreWholeRun, isTrue);
  });

  test('a cell filter narrows the studies, and the stations follow', () {
    // Workcenters belong to a plant rather than to a cell (§7.10), so a cell
    // filter is a study filter one level up — and the stations that survive are
    // the ones those studies' orders actually reached. Study b runs on TTAT
    // alone.
    final view = filterRun(run(), const RunFilter(cellIds: {'cell-2'}));

    expect(view.studyIds, {'b'});
    expect(view.metrics.orders, 1);
    expect(view.metrics.workcenters.map((w) => w.name), ['TTAT']);
  });

  test('a run made before v17 matches no cell rather than every cell', () {
    // Both columns are null on every run stored before they existed (§16.18).
    // Matching everything would make a filtered view silently describe studies
    // that were never asked for.
    final before = run();
    final withoutCells = StoredRun(
      id: before.id,
      projectId: before.projectId,
      createdAt: before.createdAt,
      dispatch: before.dispatch,
      dispatchOverrides: before.dispatchOverrides,
      studies: [study('a'), study('b')],
      result: before.result,
      metrics: before.metrics,
      plan: before.plan,
    );

    expect(filterRun(withoutCells, const RunFilter(cellIds: {'cell-1'})).studyIds, isEmpty);
    // And with no cell filter they are all still there.
    expect(filterRun(withoutCells, const RunFilter()).studyIds, {'a', 'b'});
  });

  group('the period filter', () {
    test('selects by need date, not by delivery', () {
      // `o1` is needed in March and was delivered in February; `o2` is needed in
      // September and delivered in October. A Q3 window takes the second and not
      // the first, which is the opposite of what filtering by delivery would do.
      final view = filterRun(
        run(),
        RunFilter(from: DateTime(2026, 7, 1), to: DateTime(2026, 9, 30)),
      );

      expect(view.result.orders.map((o) => o.orderId), ['o2', 'o3']);
    });

    test('keeps an order the run never completed', () {
      // The whole reason it is need date: `o3` has no delivery at all, and
      // §7.8's abort case is exactly what a planner filters to find. Filtering
      // by delivery would drop it and make every filtered view optimistic.
      final view = filterRun(
        run(),
        RunFilter(from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30)),
      );

      expect(view.result.orders.map((o) => o.orderId), contains('o3'));
      expect(view.result.orders.where((o) => o.delivered == null), hasLength(1));
    });

    test('order-level figures recompute over the slice', () {
      final whole = filterRun(run(), const RunFilter());
      final q3 = filterRun(
        run(),
        RunFilter(from: DateTime(2026, 7, 1), to: DateTime(2026, 9, 30)),
      );

      expect(whole.metrics.orders, 3);
      expect(q3.metrics.orders, 2);
      // `o1` was the only one delivered on time, and it is outside the window.
      expect(q3.metrics.onTime, 0);
    });

    test('a window with nothing in it is empty rather than whole', () {
      final view = filterRun(
        run(),
        RunFilter(from: DateTime(2027, 1, 1), to: DateTime(2027, 12, 31)),
      );

      expect(view.metrics.orders, 0);
      expect(view.plan, isEmpty);
      // And the stations go with them: a slice no order reached is a slice no
      // station worked in. The whole-run figures that survive are *columns* of
      // a row, so with no rows there is nothing left to describe.
      expect(view.metrics.workcenters, isEmpty);
    });
  });

  /// A queue belongs to the station it stands in front of, not to a study
  /// (§7.3, v19) — so filtering by study must not take it away.
  ///
  /// **The field reported this as "when filtering one study, I can't see the
  /// CLAD pool queue".** It was never the pool's problem: `simulation_run_lanes`
  /// writes one row per *target* and stamps it with whichever study was written
  /// last, so on the real run eight of ten lanes carry one study's id and two
  /// carry the other's. Filtering to either study dropped most of the queues.
  group('a shared queue survives a study filter (§7.3)', () {
    /// Two studies feeding one station, both queuing in the one lane in front
    /// of it — and the lane stamped with study `b`, as the repository stamps it.
    StoredRun shared() {
      final orders = [
        outcome('o1', studyId: 'a', need: DateTime(2026, 3, 1)),
        outcome('o2', studyId: 'b', need: DateTime(2026, 3, 2)),
      ];
      SimOrderStep queued(String orderId, String studyId) => SimOrderStep(
        studyId: studyId,
        orderId: orderId,
        nodeId: 'node-1',
        workcenterId: 'wc-1',
        queueStart: start,
        processStart: start.add(const Duration(hours: 1)),
        processEnd: start.add(const Duration(hours: 2)),
        changeoverIncurred: false,
        laneNodeId: 'clad-pool',
      );

      final result = SimRunResult(
        start: start,
        end: DateTime(2026, 12, 31),
        guard: DateTime(2027, 1, 1),
        steps: [queued('o1', 'a'), queued('o2', 'b')],
        orders: orders,
        emptySlots: const [],
        busyByWorkcenter: const {'wc-1': Duration(hours: 100)},
        openByWorkcenter: const {'wc-1': Duration(hours: 200)},
        lanes: const [
          // **Stamped `b`, and fed by both.** This is the whole fixture: the
          // study on the row is an artefact of write order since v19.
          SimLane(
            studyId: 'b',
            nodeId: 'clad-pool',
            position: 0,
            name: 'FIFO CLAD',
          ),
        ],
      );

      return StoredRun(
        id: 'run-shared',
        projectId: 'proj-1',
        createdAt: start,
        dispatch: DispatchRule.fifo,
        dispatchOverrides: const [],
        studies: [
          study('a', cell: 'cell-1', line: 'line-1'),
          study('b', cell: 'cell-2', line: 'line-2'),
        ],
        result: result,
        metrics: summariseRun(
          result: result,
          partNumbers: const {'p1': 'PN1'},
          workcenterNames: const {'wc-1': 'CLAD07'},
          theoreticalByOrder: const {},
        ),
        plan: const [],
      );
    }

    test('the study the lane is not stamped with still sees it', () {
      // The reported bug, at its sharpest: study `a` queues in this lane and the
      // row says `b`. Filtering to `a` used to drop it.
      final view = filterRun(shared(), const RunFilter(studyIds: {'a'}));

      expect(view.result.lanes.map((l) => l.name), ['FIFO CLAD']);
      expect(view.result.steps.map((s) => s.orderId), ['o1']);
    });

    test('and so does the study it is stamped with', () {
      final view = filterRun(shared(), const RunFilter(studyIds: {'b'}));

      expect(view.result.lanes.map((l) => l.name), ['FIFO CLAD']);
    });

    test('a lane no kept order queued in is dropped', () {
      // The rule is the steps, not the study — so narrowing to orders that never
      // reached this queue takes the band away, which is right: the chart draws
      // the queues the slice actually stood in.
      final view = filterRun(
        shared(),
        RunFilter(from: DateTime(2027), to: DateTime(2027, 12, 31)),
      );

      expect(view.result.orders, isEmpty);
      expect(view.result.lanes, isEmpty);
    });

    test('an open stay goes with the order it belongs to', () {
      final base = shared();
      final withOpen = StoredRun(
        id: base.id,
        projectId: base.projectId,
        createdAt: base.createdAt,
        dispatch: base.dispatch,
        dispatchOverrides: base.dispatchOverrides,
        studies: base.studies,
        metrics: base.metrics,
        plan: base.plan,
        result: SimRunResult(
          start: base.result.start,
          end: base.result.end,
          guard: base.result.guard,
          steps: base.result.steps,
          orders: base.result.orders,
          emptySlots: const [],
          busyByWorkcenter: base.result.busyByWorkcenter,
          openByWorkcenter: base.result.openByWorkcenter,
          lanes: base.result.lanes,
          openLaneVisits: [
            SimOpenLaneVisit(
              studyId: 'b',
              laneNodeId: 'clad-pool',
              orderId: 'o2',
              enteredAt: start,
            ),
          ],
        ),
      );

      // `o2` is study `b`'s, so filtering to `a` leaves the lane standing and
      // takes the stay with the order — or the band would be drawn fuller than
      // the slice it describes.
      final view = filterRun(withOpen, const RunFilter(studyIds: {'a'}));
      expect(view.result.lanes, hasLength(1));
      expect(view.result.openLaneVisits, isEmpty);
    });
  });

  /// What each picker offers, given what the others narrowed to (§7.6).
  ///
  /// Two field complaints, one rule: *"Cells and Lines are showing cells and
  /// lines that don't have studies, only the resources"*, and *"if a user
  /// selects a study only show the part numbers of that study"*.
  group('the pickers offer what could still narrow (§7.6)', () {
    /// Two studies in different cells and lines, each making its own part and
    /// booked to its own project.
    ///
    /// | order | study | cell | line | part | project |
    /// |---|---|---|---|---|---|
    /// | `o1` | a | Cell 1 | Line 1 | PN1 | MANIFOLD |
    /// | `o2` | b | Cell 2 | Line 2 | PN2 | Global 23 |
    StoredRun twoLines() {
      final orders = [
        outcome('o1', studyId: 'a', need: DateTime(2026, 3, 1), sequence: 0),
        outcome(
          'o2',
          studyId: 'b',
          need: DateTime(2026, 4, 1),
          sequence: 0,
          partId: 'p2',
        ),
      ];
      final result = SimRunResult(
        start: start,
        end: DateTime(2026, 12, 31),
        guard: DateTime(2027, 1, 1),
        steps: [step('o1', 'wc-1'), step('o2', 'wc-2')],
        orders: orders,
        emptySlots: const [],
        busyByWorkcenter: const {'wc-1': Duration(hours: 100)},
        openByWorkcenter: const {'wc-1': Duration(hours: 200)},
      );

      return StoredRun(
        id: 'run-two-lines',
        projectId: 'proj-1',
        createdAt: start,
        dispatch: DispatchRule.fifo,
        dispatchOverrides: const [],
        studies: [
          study('a', cell: 'cell-1', line: 'line-1'),
          study('b', cell: 'cell-2', line: 'line-2'),
        ],
        result: result,
        metrics: summariseRun(
          result: result,
          partNumbers: const {'p1': 'PN1', 'p2': 'PN2'},
          workcenterNames: const {'wc-1': 'CLAD04', 'wc-2': 'TTAT'},
          theoreticalByOrder: const {},
        ),
        plan: [
          for (final o in orders)
            ProductionPlanRow(
              outcome: o,
              partNumber: o.partId == 'p1' ? 'PN1' : 'PN2',
              partDescription: null,
              customerProject: o.orderId == 'o1' ? 'MANIFOLD' : 'Global 23',
              batchNumber: null,
              batchSize: 1,
              materialDate: null,
              theoreticalLeadTime: const Duration(hours: 1),
            ),
        ],
      );
    }

    test('with nothing selected, everything the run has is offered', () {
      final options = runFilterOptions(twoLines(), const RunFilter());

      expect(options.studies.keys, {'a', 'b'});
      expect(options.cells.keys, {'cell-1', 'cell-2'});
      expect(options.lines.keys, {'line-1', 'line-2'});
      expect(options.parts.keys, {'PN1', 'PN2'});
      expect(options.projects.keys, {'MANIFOLD', 'Global 23'});
      expect(options.studiesInView, 2);
    });

    test('choosing a study narrows the parts, projects, cells and lines', () {
      // The second complaint, exactly: study `a` never makes PN2.
      final options = runFilterOptions(
        twoLines(),
        const RunFilter(studyIds: {'a'}),
      );

      expect(options.parts.keys, {'PN1'});
      expect(options.projects.keys, {'MANIFOLD'});
      expect(options.cells.keys, {'cell-1'});
      expect(options.lines.keys, {'line-1'});
      expect(options.studiesInView, 1);
    });

    test('a picker does not narrow itself, or a multi-select could not be '
        'extended', () {
      // Ticking one study must leave the other in the menu it was ticked in —
      // otherwise the second can never be reached. This is the whole reason
      // each facet ignores its own selection.
      final options = runFilterOptions(
        twoLines(),
        const RunFilter(studyIds: {'a'}),
      );

      expect(options.studies.keys, {'a', 'b'});
    });

    test('choosing a part narrows the studies', () {
      final options = runFilterOptions(
        twoLines(),
        const RunFilter(partNumbers: {'PN2'}),
      );

      expect(options.studies.keys, {'b'});
      expect(options.cells.keys, {'cell-2'});
      // And not itself.
      expect(options.parts.keys, {'PN1', 'PN2'});
    });

    test('a cell narrows exactly as its study would', () {
      final options = runFilterOptions(
        twoLines(),
        const RunFilter(cellIds: {'cell-2'}),
      );

      expect(options.studies.keys, {'b'});
      expect(options.parts.keys, {'PN2'});
    });

    test('the period narrows every picker', () {
      // `o2` needs 2026-04-01, outside this window.
      final options = runFilterOptions(
        twoLines(),
        RunFilter(from: DateTime(2026, 2, 1), to: DateTime(2026, 3, 15)),
      );

      expect(options.studies.keys, {'a'});
      expect(options.parts.keys, {'PN1'});
      expect(options.studiesInView, 1);
    });

    test('a cell no study uses is never offered', () {
      // The first complaint. The plant may have twenty cells; the run knows
      // about the two its studies sat in, and nothing else can be reached from
      // here — so a menu built from this cannot list a cell that selects
      // nothing.
      final options = runFilterOptions(twoLines(), const RunFilter());

      expect(options.cells.keys, hasLength(2));
      expect(options.cells.keys, isNot(contains('cell-3')));
    });

    test('a run made before v17 offers no cells rather than a blank one', () {
      // Its `production_cell_id` is null (§16.18) — the same reason the filter
      // treats a blank as matching nothing rather than as a wildcard.
      final before = run();
      final withoutCells = StoredRun(
        id: before.id,
        projectId: before.projectId,
        createdAt: before.createdAt,
        dispatch: before.dispatch,
        dispatchOverrides: before.dispatchOverrides,
        studies: [study('a'), study('b')],
        result: before.result,
        metrics: before.metrics,
        plan: before.plan,
      );

      final options = runFilterOptions(withoutCells, const RunFilter());

      expect(options.cells, isEmpty);
      expect(options.lines, isEmpty);
      // The studies themselves are still offered — it is only the cell and the
      // line the run cannot answer for.
      expect(options.studies.keys, {'a', 'b'});
    });

    test('before a run exists there is nothing to offer', () {
      // The pane below says nothing has been run. A menu of things that cannot
      // narrow it would be describing the plant rather than the screen.
      const options = RunFilterOptions();
      expect(runFilterOptions(null, const RunFilter()).studies, options.studies);
      expect(runFilterOptions(null, const RunFilter()).cells, isEmpty);
    });

    test('the unbooked orders are offered only when there are some', () {
      expect(
        runFilterOptions(twoLines(), const RunFilter()).projects.keys,
        isNot(contains(RunFilter.noProject)),
      );
      // `run()`'s plan answers null for every order, which is also every
      // pre-v12 run.
      expect(
        runFilterOptions(run(), const RunFilter()).projects.keys,
        contains(RunFilter.noProject),
      );
    });
  });

  /// §7.5's three, which narrow **within** a study where the period is the only
  /// thing that did before.
  group('the project, part and order filters (§7.5)', () {
    /// Three orders across two studies, built to make every claim below
    /// falsifiable: two parts, two projects and one unbooked order, and the same
    /// order number in both studies.
    ///
    /// | order | study | seq | part | project |
    /// |---|---|---|---|---|
    /// | `o1` | a | 0 | PN1 | MANIFOLD |
    /// | `o2` | a | 1 | PN2 | Global 23 |
    /// | `o3` | b | 0 | PN1 | *none* |
    StoredRun booked() {
      final orders = [
        outcome('o1', studyId: 'a', need: DateTime(2026, 3, 1), sequence: 0),
        outcome(
          'o2',
          studyId: 'a',
          need: DateTime(2026, 4, 1),
          sequence: 1,
          partId: 'p2',
        ),
        outcome('o3', studyId: 'b', need: DateTime(2026, 5, 1), sequence: 0),
      ];
      final projects = {'o1': 'MANIFOLD', 'o2': 'Global 23', 'o3': null};
      final result = SimRunResult(
        start: start,
        end: DateTime(2026, 12, 31),
        guard: DateTime(2027, 1, 1),
        steps: [step('o1', 'wc-1'), step('o2', 'wc-1'), step('o3', 'wc-2')],
        orders: orders,
        emptySlots: const [],
        busyByWorkcenter: const {'wc-1': Duration(hours: 100)},
        openByWorkcenter: const {'wc-1': Duration(hours: 200)},
      );

      return StoredRun(
        id: 'run-booked',
        projectId: 'proj-1',
        createdAt: start,
        dispatch: DispatchRule.fifo,
        dispatchOverrides: const [],
        studies: [
          study('a', cell: 'cell-1', line: 'line-1'),
          study('b', cell: 'cell-2', line: 'line-2'),
        ],
        result: result,
        metrics: summariseRun(
          result: result,
          partNumbers: const {'p1': 'PN1', 'p2': 'PN2'},
          workcenterNames: const {'wc-1': 'CLAD04', 'wc-2': 'TTAT'},
          theoreticalByOrder: const {},
        ),
        plan: [
          for (final o in orders)
            ProductionPlanRow(
              outcome: o,
              partNumber: o.partId == 'p1' ? 'PN1' : 'PN2',
              partDescription: null,
              customerProject: projects[o.orderId],
              batchNumber: null,
              batchSize: 1,
              materialDate: null,
              theoreticalLeadTime: const Duration(hours: 1),
            ),
        ],
      );
    }

    Set<String> orderIds(FilteredRun view) => {
      for (final o in view.result.orders) o.orderId,
    };

    test('a project filter keeps only that project s orders', () {
      final view = filterRun(
        booked(),
        const RunFilter(customerProjects: {'MANIFOLD'}),
      );

      expect(orderIds(view), {'o1'});
      expect(view.isWholeRun, isFalse);
      // The steps follow the orders, which is what makes every table narrow
      // rather than only the count at the top.
      expect(view.result.steps.map((s) => s.orderId), ['o1']);
      expect(view.plan.map((r) => r.outcome.orderId), ['o1']);
    });

    test('two projects are a union, not an intersection', () {
      final view = filterRun(
        booked(),
        const RunFilter(customerProjects: {'MANIFOLD', 'Global 23'}),
      );

      expect(orderIds(view), {'o1', 'o2'});
    });

    test('the unbooked orders are selectable, and are not in any project', () {
      // 11 % of the live database is this order. Offering the real names while
      // silently dropping it from all of them would hide a ninth of the run.
      expect(
        orderIds(
          filterRun(
            booked(),
            const RunFilter(customerProjects: {RunFilter.noProject}),
          ),
        ),
        {'o3'},
      );
      // And it is not swept up by a named project.
      expect(
        orderIds(
          filterRun(
            booked(),
            const RunFilter(customerProjects: {'MANIFOLD'}),
          ),
        ),
        isNot(contains('o3')),
      );
    });

    test('a part filter reads the number off the metrics', () {
      expect(
        orderIds(filterRun(booked(), const RunFilter(partNumbers: {'PN1'}))),
        {'o1', 'o3'},
      );
      expect(
        orderIds(filterRun(booked(), const RunFilter(partNumbers: {'PN2'}))),
        {'o2'},
      );
    });

    test('an order number names one order in every study, and says so by '
        'doing it', () {
      // The whole reason §7.5 refused to pretend this picks one thing: `o1` and
      // `o3` are both order 1, in different studies.
      expect(
        orderIds(filterRun(booked(), const RunFilter(orderNumbers: {1}))),
        {'o1', 'o3'},
      );
      // And combining with the study filter is what narrows it to one.
      expect(
        orderIds(
          filterRun(
            booked(),
            const RunFilter(orderNumbers: {1}, studyIds: {'a'}),
          ),
        ),
        {'o1'},
      );
    });

    test('the order number is 1-based, as the column is', () {
      // `o2` is sequence 1 and is therefore order **2**. Off by one here would
      // silently select the neighbour of whatever was asked for.
      expect(
        orderIds(filterRun(booked(), const RunFilter(orderNumbers: {2}))),
        {'o2'},
      );
    });

    test('the three combine, and combine as an and', () {
      expect(
        orderIds(
          filterRun(
            booked(),
            const RunFilter(
              customerProjects: {'MANIFOLD', 'Global 23'},
              partNumbers: {'PN1'},
            ),
          ),
        ),
        {'o1'},
      );
      // Nothing satisfies both.
      expect(
        orderIds(
          filterRun(
            booked(),
            const RunFilter(
              customerProjects: {'MANIFOLD'},
              partNumbers: {'PN2'},
            ),
          ),
        ),
        isEmpty,
      );
    });

    test('order-level figures recompute over the slice', () {
      final view = filterRun(
        booked(),
        const RunFilter(partNumbers: {'PN1'}),
      );

      expect(view.metrics.orders, 2);
      // And the stations narrow with them: PN1 never went through wc-2's
      // sibling, so only the stations these two orders touched have rows.
      expect(
        view.metrics.workcenters.map((w) => w.name).toSet(),
        {'CLAD04', 'TTAT'},
      );
      expect(view.stationsAreWholeRun, isTrue);
    });

    test('a slice s signature is fixed when the slice is taken', () {
      // **The filter bar mutates one long-lived set per control**, in place, and
      // hands the same instance to every `RunFilter` it builds. So a
      // `FilteredRun` taken before the edit could still see the edit through it
      // — and `signature` being a getter meant the *old* slice recomputed to the
      // new value. `GanttView.didUpdateWidget` compares old against new to
      // decide whether to rebuild its chart, found them equal, and returned
      // early: the three §7.5 filters moved every table and left the Gantt
      // showing the slice before last.
      //
      // Only the study segment escaped, because `FilteredRun.studyIds` is built
      // fresh in `filterRun` rather than read through — which is exactly why the
      // field saw the three "only work when a single study is filtered".
      final projects = <String>{'MANIFOLD'};
      final view = filterRun(booked(), RunFilter(customerProjects: projects));
      final taken = view.signature;

      projects.add('Global 23');

      expect(view.signature, taken);
    });

    test('each of the three makes the signature different', () {
      // Without this the chart keeps drawing the slice before last, because the
      // run id and the studies are unchanged by all three.
      final base = filterRun(booked(), const RunFilter()).signature;
      final byProject = filterRun(
        booked(),
        const RunFilter(customerProjects: {'MANIFOLD'}),
      ).signature;
      final byPart = filterRun(
        booked(),
        const RunFilter(partNumbers: {'PN1'}),
      ).signature;
      final byOrder = filterRun(
        booked(),
        const RunFilter(orderNumbers: {1}),
      ).signature;

      expect({base, byProject, byPart, byOrder}, hasLength(4));
    });

    test('none of them is the whole run, and no filter still is', () {
      expect(filterRun(booked(), const RunFilter()).isWholeRun, isTrue);
      for (final filter in const [
        RunFilter(customerProjects: {'MANIFOLD'}),
        RunFilter(partNumbers: {'PN1'}),
        RunFilter(orderNumbers: {1}),
      ]) {
        expect(filterRun(booked(), filter).isWholeRun, isFalse);
        expect(filter.narrowsOrders, isTrue);
      }
    });

    test('a run stored before v12 has no project to match', () {
      // Every plan row answers null, so a named project selects nothing and
      // `(none)` selects everything — both true, neither inventing a project.
      final legacy = run(); // its plan carries `customerProject: null`
      expect(
        filterRun(
          legacy,
          const RunFilter(customerProjects: {'MANIFOLD'}),
        ).result.orders,
        isEmpty,
      );
      expect(
        filterRun(
          legacy,
          const RunFilter(customerProjects: {RunFilter.noProject}),
        ).result.orders,
        hasLength(3),
      );
    });
  });
}
