import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/demand/application/demand_table.dart';
import 'package:flowmap/src/features/demand/application/mm3.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sequence smoothness (DESIGN.md §6.3).
void main() {
  final now = DateTime(2026, 8, 1);

  DemandPart part(String id, String number) => DemandPart(
    id: id,
    studyId: 'study-1',
    partNumber: number,
    createdAt: now,
    updatedAt: now,
  );

  DemandOrder order(String id, int sequence, String partId, {int batch = 1}) =>
      DemandOrder(
        id: id,
        studyId: 'study-1',
        partId: partId,
        sequence: sequence,
        batchSize: batch,
        needDate: DateTime(2026, 8, 13),
        createdAt: now,
        updatedAt: now,
      );

  /// One step whose yardstick is a round 100 hours, so an equivalence reads
  /// straight off the part's time.
  const oneStep = [
    Mm3Step(
      nodeId: 'node-1',
      targetId: 'wc-1',
      equivalentProcessTime: Duration(hours: 100),
      rework: 0,
    ),
  ];

  const oneColumn = [
    DemandColumn(nodeId: 'node-0', targetId: 'wc-1', title: 'CLAD04'),
  ];

  test('the worked example in §6.3: 1.11, 1.01, 0.97', () {
    // Equivalences of 1.20, 1.13, 1.00, 0.90, 1.01 — the centred means of
    // three are exactly the figures the spec states.
    final parts = [
      for (var i = 0; i < 5; i++) part('p$i', 'PN$i'),
    ];
    final hours = [120, 113, 100, 90, 101];

    final series = computeMm3(
      scope: const Mm3Scope(targetId: 'wc-1', title: 'CLAD04'),
      orders: [
        for (var i = 0; i < 5; i++) order('o$i', i, 'p$i'),
      ],
      table: DemandTable(
        parts: parts,
        columns: oneColumn,
        times: {
          for (var i = 0; i < 5; i++)
            'p$i': {'node-1': Duration(hours: hours[i])},
        },
      ),
      steps: oneStep,
    );

    expect(
      series.points.map((p) => p.slotLoad),
      [1.20, 1.13, 1.00, 0.90, 1.01],
    );
    expect(series.points.first.movingAverage, isNull);
    expect(series.points.last.movingAverage, isNull);
    expect(
      series.points.skip(1).take(3).map((p) => p.movingAverage!.toStringAsFixed(2)),
      ['1.11', '1.01', '0.97'],
    );
  });

  test('the ends are blank, not averaged over two', () {
    final series = computeMm3(
      scope: const Mm3Scope(targetId: 'wc-1', title: 'CLAD04'),
      orders: [order('o0', 0, 'p1'), order('o1', 1, 'p1')],
      table: DemandTable(
        parts: [part('p1', 'PN1')],
        columns: oneColumn,
        times: {
          'p1': {'node-1': const Duration(hours: 100)},
        },
      ),
      steps: oneStep,
    );

    // A two-point mean is a different statistic wearing the same heading.
    expect(series.points.map((p) => p.movingAverage), [null, null]);
    expect(series.averageDeviation, isNull);
    expect(series.isEmpty, isTrue);
  });

  test('a batch of ten loads the slot ten times as hard', () {
    final series = computeMm3(
      scope: const Mm3Scope(targetId: 'wc-1', title: 'CLAD04'),
      orders: [order('o0', 0, 'p1', batch: 10)],
      table: DemandTable(
        parts: [part('p1', 'PN1')],
        columns: oneColumn,
        times: {
          'p1': {'node-1': const Duration(hours: 100)},
        },
      ),
      steps: oneStep,
    );

    // One takt slot releases one order (§7.2), so lot sizing is a lever this
    // measure has to respond to (§7.6). The part's own equivalence does not
    // move, though: §6.2's quantity belongs to the part, and showing only the
    // product made it look as if it drifted.
    expect(series.points.single.slotLoad, 10.0);
    expect(series.points.single.partEquivalence, 1.0);
  });

  test('rework is charged against the part, not against the yardstick', () {
    final series = computeMm3(
      scope: const Mm3Scope(targetId: 'wc-1', title: 'CLAD04'),
      orders: [order('o0', 0, 'p1')],
      table: DemandTable(
        parts: [part('p1', 'PN1')],
        columns: oneColumn,
        times: {
          'p1': {'node-1': const Duration(hours: 100)},
        },
      ),
      steps: const [
        Mm3Step(
          nodeId: 'node-1',
          targetId: 'wc-1',
          equivalentProcessTime: Duration(hours: 100),
          rework: 0.037,
        ),
      ],
    );

    expect(series.points.single.slotLoad, closeTo(1.037, 0.0001));
  });

  group('scope', () {
    final table = DemandTable(
      parts: [part('p1', 'PN1'), part('p2', 'PN2')],
      columns: const [
        DemandColumn(nodeId: 'node-0', targetId: 'wc-1', title: 'CLAD04'),
        DemandColumn(nodeId: 'node-1', targetId: 'wc-2', title: 'TTAT'),
      ],
      times: {
        'p1': {
          'node-1': const Duration(hours: 120),
          'node-2': const Duration(hours: 40),
        },
        // PN2 never visits TTAT.
        'p2': {'node-1': const Duration(hours: 80)},
      },
    );

    const steps = [
      Mm3Step(
        nodeId: 'node-1',
        targetId: 'wc-1',
        equivalentProcessTime: Duration(hours: 100),
        rework: 0,
      ),
      Mm3Step(
        nodeId: 'node-2',
        targetId: 'wc-2',
        equivalentProcessTime: Duration(hours: 50),
        rework: 0,
      ),
    ];

    final orders = [order('o0', 0, 'p1'), order('o1', 1, 'p2')];

    test('the whole flow divides the sum by the sum', () {
      final series = computeMm3(
        scope: const Mm3Scope(targetId: null, title: ''),
        orders: orders,
        table: table,
        steps: steps,
      );

      // PN1: (120 + 40) ÷ (100 + 50) = 1.0667.
      expect(series.points.first.slotLoad, closeTo(160 / 150, 0.0001));
      // PN2 skips TTAT, so it contributes nothing there — but the yardstick is
      // the flow's, because that is the capacity a slot of the flow is worth
      // (§5.1).
      expect(series.points.last.slotLoad, closeTo(80 / 150, 0.0001));
    });

    test('one step measures only that step', () {
      final series = computeMm3(
        scope: const Mm3Scope(targetId: 'wc-2', title: 'TTAT'),
        orders: orders,
        table: table,
        steps: steps,
      );

      expect(series.points.first.slotLoad, closeTo(40 / 50, 0.0001));
      // A part that does not visit the step has no equivalence there at all —
      // blank, not zero.
      expect(series.points.last.slotLoad, isNull);
    });

    test('a part with no time anywhere in scope is blank', () {
      final series = computeMm3(
        scope: const Mm3Scope(targetId: null, title: ''),
        orders: [order('o0', 0, 'p3')],
        table: DemandTable(
          parts: [part('p3', 'PN3')],
          columns: table.columns,
          times: const {},
        ),
        steps: steps,
      );

      expect(series.points.single.slotLoad, isNull);
    });

    test('a missing neighbour blanks the moving average', () {
      final series = computeMm3(
        scope: const Mm3Scope(targetId: 'wc-2', title: 'TTAT'),
        orders: [
          order('o0', 0, 'p1'),
          order('o1', 1, 'p1'),
          // PN2 does not visit TTAT, so the window around it is incomplete.
          order('o2', 2, 'p2'),
          order('o3', 3, 'p1'),
          order('o4', 4, 'p1'),
        ],
        table: table,
        steps: steps,
      );

      expect(
        series.points.map((p) => p.movingAverage),
        [null, null, null, null, null],
      );
    });
  });

  test('the headline is the mean distance from 1.0', () {
    final series = computeMm3(
      scope: const Mm3Scope(targetId: 'wc-1', title: 'CLAD04'),
      orders: [
        for (var i = 0; i < 5; i++) order('o$i', i, 'p$i'),
      ],
      table: DemandTable(
        parts: [for (var i = 0; i < 5; i++) part('p$i', 'PN$i')],
        columns: oneColumn,
        times: {
          for (var i = 0; i < 5; i++)
            'p$i': {'node-1': Duration(hours: [120, 113, 100, 90, 101][i])},
        },
      ),
      steps: oneStep,
    );

    // |1.11 − 1| + |1.01 − 1| + |0.97 − 1|, over three.
    expect(series.averageDeviation, closeTo((0.11 + 0.01 + 0.03) / 3, 0.0005));
  });

  group('busiestTargetId', () {
    test('is the step carrying the most work across the sequence', () {
      final table = DemandTable(
        parts: [part('p1', 'PN1')],
        columns: const [
          DemandColumn(nodeId: 'node-0', targetId: 'wc-1', title: 'CLAD04'),
          DemandColumn(nodeId: 'node-1', targetId: 'wc-2', title: 'TTAT'),
        ],
        times: {
          'p1': {
            'node-1': const Duration(hours: 10),
            'node-2': const Duration(hours: 40),
          },
        },
      );

      expect(
        busiestTargetId(
          orders: [order('o0', 0, 'p1')],
          table: table,
          steps: const [
            Mm3Step(nodeId: 'node-1', targetId: 'wc-1', equivalentProcessTime: null, rework: 0),
            Mm3Step(nodeId: 'node-2', targetId: 'wc-2', equivalentProcessTime: null, rework: 0),
          ],
        ),
        'wc-2',
      );
    });

    test('is nothing when there is no work to weigh', () {
      expect(
        busiestTargetId(
          orders: const [],
          table: const DemandTable(parts: [], columns: [], times: {}),
          steps: const [],
        ),
        isNull,
      );
    });
  });
}
