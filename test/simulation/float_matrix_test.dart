import 'package:flowmap/src/features/simulation/application/float_matrix.dart';
import 'package:flowmap/src/features/simulation/application/run_filter.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Float, month by month (`TODO.md` §10.4).
///
/// The outcomes are built directly rather than run through the engine: what a
/// cell *means* is a question about need dates and delivery dates, and a
/// simulation that produced them would only make the fixture harder to read.
void main() {
  SimOrderOutcome order(
    String id, {
    required DateTime need,
    DateTime? delivered,
    int sequence = 0,
    String partId = 'part-a',
  }) => SimOrderOutcome(
    studyId: 'study-1',
    orderId: id,
    sequence: sequence,
    partId: partId,
    needDate: need,
    released: DateTime(2026),
    delivered: delivered,
  );

  FilteredRun sliceOf(List<SimOrderOutcome> orders) {
    final result = SimRunResult(
      start: DateTime(2026),
      end: DateTime(2027),
      guard: DateTime(2027),
      steps: const [],
      orders: orders,
      emptySlots: const [],
      busyByWorkcenter: const {},
      openByWorkcenter: const {},
    );
    final metrics = summariseRun(
      result: result,
      partNumbers: const {'part-a': 'PN1'},
      workcenterNames: const {},
      theoreticalByOrder: const {},
    );
    return FilteredRun(
      run: StoredRun(
        id: 'run-1',
        projectId: 'p',
        createdAt: DateTime(2026),
        queues: const RunQueues([]),
        studies: const [],
        result: result,
        metrics: metrics,
        plan: const [],
      ),
      filter: const RunFilter(),
      studyIds: const {'study-1'},
      result: result,
      metrics: metrics,
      plan: const [],
      stationsAreWholeRun: true,
    );
  }

  FloatMatrix matrixOf(
    List<SimOrderOutcome> orders, {
    int red = 0,
    int green = 30,
  }) => buildFloatMatrix(
    slice: sliceOf(orders),
    redDays: red,
    greenDays: green,
  );

  test('columns are the need-date month, not the delivery month', () {
    // **The rule §12's run comparison depends on.** An order due in March and
    // shipped in April would change column between two runs of the same demand,
    // and then the two matrices could not be laid side by side at all.
    final matrix = matrixOf([
      order('o1', need: DateTime(2026, 3, 10), delivered: DateTime(2026, 4, 2)),
    ]);

    expect(matrix.months, [DateTime(2026, 3)]);
  });

  test('rows rank within the month by need date, earliest first', () {
    // Not the demand `sequence`, which the Gantt and §8.5's plan already use for
    // a global order number — the same `#3` would otherwise name two different
    // orders on two screens.
    final matrix = matrixOf([
      order('late', need: DateTime(2026, 3, 20), sequence: 0),
      order('early', need: DateTime(2026, 3, 2), sequence: 1),
    ]);

    expect(matrix.rows.first.single!.orderId, 'early');
    expect(matrix.rows[1].single!.orderId, 'late');
  });

  test('two orders due the same day keep a fixed order between runs', () {
    // Ties break by sequence, so one study run twice does not swap two rows
    // (§4.4).
    final matrix = matrixOf([
      order('b', need: DateTime(2026, 3, 2), sequence: 5),
      order('a', need: DateTime(2026, 3, 2), sequence: 1),
    ]);

    expect(matrix.rows.first.single!.orderId, 'a');
    expect(matrix.rows[1].single!.orderId, 'b');
  });

  test('the bands are read off the project thresholds', () {
    final matrix = matrixOf(
      [
        // Delivered on the need date: no slack left, which is what red is for.
        order('none', need: DateTime(2026, 3, 10), delivered: DateTime(2026, 3, 10)),
        order('late', need: DateTime(2026, 3, 11), delivered: DateTime(2026, 4, 11)),
        order('some', need: DateTime(2026, 3, 12), delivered: DateTime(2026, 3, 1)),
        order('lots', need: DateTime(2026, 4, 20), delivered: DateTime(2026, 3, 1)),
      ],
      red: 0,
      green: 30,
    );

    final byId = {
      for (final row in matrix.rows)
        for (final cell in row)
          if (cell != null) cell.orderId: cell.band,
    };

    expect(byId['none'], FloatBand.red, reason: 'at the threshold is red');
    expect(byId['late'], FloatBand.red);
    expect(byId['some'], FloatBand.amber);
    expect(byId['lots'], FloatBand.green);
  });

  test('a threshold the project moved moves the colours with it', () {
    final orders = [
      order('o', need: DateTime(2026, 3, 20), delivered: DateTime(2026, 3, 10)),
    ];

    expect(matrixOf(orders).rows.first.single!.band, FloatBand.amber);
    // Ten days of slack is comfortable on a plant that says so.
    expect(
      matrixOf(orders, green: 5).rows.first.single!.band,
      FloatBand.green,
    );
  });

  test('an order that never delivered is its own band, not red', () {
    // Late by a month and never finished are different findings; colouring them
    // alike would hide a run that aborted on the guard inside one that is
    // merely behind.
    final matrix = matrixOf([order('o', need: DateTime(2026, 3, 10))]);

    final cell = matrix.rows.first.single!;
    expect(cell.band, FloatBand.undelivered);
    expect(cell.float, isNull);
    expect(cell.days, isNull);
  });

  test('a month with fewer orders leaves the tail blank, not zero', () {
    // A zero would read as an order delivered exactly on its need date, which is
    // the one figure the red band exists to catch.
    final matrix = matrixOf([
      order('a1', need: DateTime(2026, 3, 1), delivered: DateTime(2026, 2, 1)),
      order('a2', need: DateTime(2026, 3, 2), delivered: DateTime(2026, 2, 1)),
      order('b1', need: DateTime(2026, 4, 1), delivered: DateTime(2026, 2, 1)),
    ]);

    expect(matrix.months, [DateTime(2026, 3), DateTime(2026, 4)]);
    expect(matrix.rows, hasLength(2));
    // Second row: March has one, April has none.
    expect(matrix.rows[1][0], isNotNull);
    expect(matrix.rows[1][1], isNull);
  });

  test('the tally counts what the matrix found', () {
    final matrix = matrixOf([
      order('r', need: DateTime(2026, 3, 1), delivered: DateTime(2026, 3, 1)),
      order('g', need: DateTime(2026, 3, 2), delivered: DateTime(2026, 1, 1)),
      order('u', need: DateTime(2026, 3, 3)),
    ]);

    final tally = matrix.tally;
    expect(tally[FloatBand.red], 1);
    expect(tally[FloatBand.green], 1);
    expect(tally[FloatBand.undelivered], 1);
    expect(tally[FloatBand.amber], 0);
  });

  test('a slice with no orders is empty rather than a matrix of nothing', () {
    expect(matrixOf(const []).isEmpty, isTrue);
  });
}
