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
  }) => SimOrderOutcome(
    studyId: studyId,
    orderId: id,
    sequence: 1,
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

  WorkcenterRunMetrics station(String id, String name) => WorkcenterRunMetrics(
    workcenterId: id,
    name: name,
    visits: 10,
    busy: const Duration(hours: 100),
    open: const Duration(hours: 200),
    blocked: Duration.zero,
    queueTime: const Duration(hours: 5),
    changeovers: 2,
    contributedTime: const Duration(hours: 100),
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
      busyByWorkcenter: const {},
      openByWorkcenter: const {},
    );
    final metrics = summariseRun(
      result: result,
      partNumbers: const {'p1': 'PN1'},
      workcenterNames: const {'wc-1': 'CLAD04', 'wc-2': 'TTAT'},
      theoreticalByOrder: const {},
    ).withWorkcenters([station('wc-1', 'CLAD04'), station('wc-2', 'TTAT')]);

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

  test('the stations stay whole, and the view says so', () {
    // Utilisation's denominator is a run total and the run does not carry what a
    // windowed one would need — so a slice reports the plant, labelled, rather
    // than a busy total over an open total that do not describe the same thing.
    final view = filterRun(run(), RunFilter.study('a'));

    expect(view.metrics.workcenters.map((w) => w.name), ['CLAD04', 'TTAT']);
    expect(
      view.metrics.workcenters.first.open,
      const Duration(hours: 200),
      reason: 'the whole run, not study a alone',
    );
    expect(view.stationsAreWholeRun, isTrue);
  });

  test('a cell filter narrows the studies, not the stations', () {
    // Workcenters belong to a plant rather than to a cell (§7.10), so a cell
    // filter is a study filter one level up.
    final view = filterRun(run(), const RunFilter(cellIds: {'cell-2'}));

    expect(view.studyIds, {'b'});
    expect(view.metrics.orders, 1);
    expect(view.metrics.workcenters, hasLength(2));
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
      // The stations still describe the run, which is the one thing that does
      // not go empty with the slice.
      expect(view.metrics.workcenters, hasLength(2));
    });
  });
}
