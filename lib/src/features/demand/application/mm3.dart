/// MM3 — how smooth the demand sequence is (DESIGN.md §6.3).
///
/// A centered moving average of 3 over the equivalence of the sequence:
/// `(prev + current + next) ÷ 3`, blank at both ends. Closer to 1.0 is better
/// levelled. The user reorders by hand and watches it improve; nothing here
/// suggests an order, because a suggestion that violates a need date is worse
/// than no suggestion.
library;

import '../../../data/database/database.dart';
import 'demand_table.dart';

/// What the measure is taken over: the whole flow, or one step of it.
class Mm3Scope {
  const Mm3Scope({required this.targetId, required this.title});

  /// Null for the whole flow.
  final String? targetId;

  /// What to call it on screen — a step's title, or the flow's own label.
  final String title;

  bool get isWholeFlow => targetId == null;
}

/// One order's row in the table and point on the chart.
class Mm3Point {
  const Mm3Point({
    required this.orderId,
    required this.sequence,
    required this.partNumber,
    required this.batchSize,
    required this.equivalence,
    required this.movingAverage,
  });

  final String orderId;

  /// Zero-based position in the sequence.
  final int sequence;

  final String partNumber;
  final int batchSize;

  /// How many takts of the scope's capacity this order consumes. Null when the
  /// part has no process time anywhere in scope — it cannot be placed against
  /// the yardstick at all, which is different from consuming nothing.
  final double? equivalence;

  /// The centered mean of this order's equivalence and its two neighbours'.
  ///
  /// Null at the first and last order, which have no neighbour on one side —
  /// blank rather than averaged over two, because a two-point mean is a
  /// different statistic wearing the same column heading.
  final double? movingAverage;
}

/// The sequence, measured.
class Mm3Series {
  const Mm3Series({required this.scope, required this.points});

  final Mm3Scope scope;
  final List<Mm3Point> points;

  Iterable<double> get _averages =>
      points.map((p) => p.movingAverage).whereType<double>();

  /// Mean distance from 1.0 across the points that have a moving average —
  /// the headline figure. `0.042` reads as "4.2 % off takt on average".
  ///
  /// A mean rather than a worst case: one awkward order in two hundred is not
  /// what the measure is for, and a maximum would make every sequence look
  /// equally bad.
  double? get averageDeviation {
    final values = _averages.toList();
    if (values.isEmpty) return null;
    return values.fold<double>(0, (sum, v) => sum + (v - 1).abs()) /
        values.length;
  }

  /// Whether anything could be measured at all.
  bool get isEmpty => _averages.isEmpty;
}

/// How far off 1.0 a point is allowed to be before it is worth looking at
/// (DESIGN.md §6.3). Defaults are ±10 % amber, ±20 % red.
class Mm3Bands {
  const Mm3Bands({this.warning = 0.10, this.severe = 0.20});

  final double warning;
  final double severe;
}

/// What one step contributes to the measure: the yardstick there, and the
/// rework charged against a part's time there.
class Mm3Step {
  const Mm3Step({
    required this.targetId,
    required this.equivalentProcessTime,
    required this.rework,
  });

  final String targetId;

  /// `FE_pt` at this step — one takt of its own productive capacity (§6.1).
  /// Null where the step cannot be costed; such a step is left out of the
  /// yardstick rather than counted as free.
  final Duration? equivalentProcessTime;

  final double rework;
}

/// Measures [orders] against [scope].
///
/// **A blank cell is a skip, not a hole.** §5.1 says a part that does not visit
/// a step simply has no time in that column, so a blank contributes nothing to
/// the numerator and the part is still measurable. Only a part with no time
/// anywhere in scope has no equivalence at all.
///
/// **Batch size multiplies the equivalence.** One takt slot releases one order
/// (§7.2), so an order of ten pieces genuinely loads the flow ten times as
/// hard as one of one — and lot sizing is exactly a lever this measure should
/// respond to (§7.6). With batch 1 throughout it reduces to the per-part
/// equivalence of §6.2.
Mm3Series computeMm3({
  required Mm3Scope scope,
  required List<DemandOrder> orders,
  required DemandTable table,
  required List<Mm3Step> steps,
}) {
  final inScope = scope.isWholeFlow
      ? steps
      : steps.where((s) => s.targetId == scope.targetId).toList();

  final partsById = {for (final part in table.parts) part.id: part};

  // The yardstick is the same for every order: Σ FE_pt over the steps in
  // scope. A step that cannot be costed contributes nothing to either side.
  var yardstick = 0;
  for (final step in inScope) {
    yardstick += step.equivalentProcessTime?.inSeconds ?? 0;
  }

  double? equivalenceOf(String partId) {
    if (yardstick == 0) return null;

    var work = 0.0;
    var visited = false;
    for (final step in inScope) {
      if (step.equivalentProcessTime == null) continue;
      final stored = table.times[partId]?[step.targetId];
      if (stored == null) continue;
      visited = true;
      work += stored.inSeconds * (1 + step.rework);
    }
    return visited ? work / yardstick : null;
  }

  final equivalences = <double?>[];
  for (final order in orders) {
    final part = partsById[order.partId];
    final each = part == null ? null : equivalenceOf(part.id);
    equivalences.add(each == null ? null : each * order.batchSize);
  }

  final points = <Mm3Point>[];
  for (var i = 0; i < orders.length; i++) {
    final order = orders[i];

    double? average;
    if (i > 0 && i < orders.length - 1) {
      final window = [equivalences[i - 1], equivalences[i], equivalences[i + 1]];
      // Blank if any of the three is missing: a mean over two of them is a
      // different number wearing the same column heading.
      if (!window.contains(null)) {
        average = window.cast<double>().reduce((a, b) => a + b) / 3;
      }
    }

    points.add(
      Mm3Point(
        orderId: order.id,
        sequence: i,
        partNumber: partsById[order.partId]?.partNumber ?? '—',
        batchSize: order.batchSize,
        equivalence: equivalences[i],
        movingAverage: average,
      ),
    );
  }

  return Mm3Series(scope: scope, points: points);
}

/// The step carrying the most work across the whole sequence — what the scope
/// selector opens on (DESIGN.md §6.3).
///
/// The busiest station is where a lumpy sequence hurts first, so it is the one
/// worth showing before the user has chosen anything.
String? busiestTargetId({
  required List<DemandOrder> orders,
  required DemandTable table,
  required List<Mm3Step> steps,
}) {
  final work = <String, double>{};
  for (final order in orders) {
    for (final step in steps) {
      final stored = table.times[order.partId]?[step.targetId];
      if (stored == null) continue;
      work[step.targetId] =
          (work[step.targetId] ?? 0) + stored.inSeconds * order.batchSize;
    }
  }
  if (work.isEmpty) return null;
  return work.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}
