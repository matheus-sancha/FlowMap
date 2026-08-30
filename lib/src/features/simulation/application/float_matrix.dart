/// Float, month by month (DESIGN.md §8, `TODO.md` §10.4).
///
/// **§0's finding made readable.** On-time delivery came back **60/60 in all
/// four** of that drive's confounder runs, because a thirty-day start buffer
/// swamped every difference between them — *"on-time cannot currently
/// discriminate between these configurations and lead time is doing all the
/// work."* A single ratio cannot say that January is comfortable and April is
/// not; a month-by-month matrix of slack can, and it is the same figure the
/// production plan already puts in front of a planner.
///
/// Pure and free of Drift, so what a cell means is a unit test.
library;

import 'run_filter.dart';
import 'sim_result.dart';

/// How a cell reads at a glance.
enum FloatBand {
  /// At or below the project's lower threshold — no slack left, or late.
  red,

  /// Between the two.
  amber,

  /// At or above the upper threshold.
  green,

  /// The order never delivered, so it has no float at all.
  ///
  /// **Not red.** Late by a month and never finished are different findings, and
  /// colouring them alike would hide the second inside the first — a run that
  /// aborts on the guard (§7.8) would read as a plant that is merely behind.
  undelivered,
}

/// One order's slack, in the column its need date puts it in.
class FloatCell {
  const FloatCell({
    required this.orderId,
    required this.partNumber,
    required this.needDate,
    required this.float,
    required this.band,
  });

  final String orderId;
  final String partNumber;
  final DateTime needDate;

  /// Positive is early, with that much time in hand (§8). Null where the order
  /// never delivered.
  final Duration? float;

  final FloatBand band;

  /// Whole days, rounded toward zero, which is how the plan's column reads it.
  int? get days => float?.inDays;
}

/// Orders down, months across.
class FloatMatrix {
  const FloatMatrix({
    required this.months,
    required this.rows,
    required this.redDays,
    required this.greenDays,
  });

  /// The columns, in date order — the **need-date** month of each order.
  final List<DateTime> months;

  /// Row *r* holds, for each month, the order ranked *r* in that month by need
  /// date. Short months have fewer entries and the tail is blank.
  final List<List<FloatCell?>> rows;

  final int redDays;
  final int greenDays;

  bool get isEmpty => months.isEmpty;

  /// How many cells in each band, for the caption that says what the matrix
  /// found without the reader counting squares.
  Map<FloatBand, int> get tally {
    final counts = {for (final band in FloatBand.values) band: 0};
    for (final row in rows) {
      for (final cell in row) {
        if (cell != null) counts[cell.band] = counts[cell.band]! + 1;
      }
    }
    return counts;
  }
}

/// Builds the matrix from a slice of a run.
///
/// [redDays] and [greenDays] are the project's own thresholds (§10.1).
FloatMatrix buildFloatMatrix({
  required FilteredRun slice,
  required int redDays,
  required int greenDays,
  Map<String, String> partNumbers = const {},
}) {
  // **The month of the need date, not of the delivery.** An order due in March
  // and shipped in April would change column between runs, and §12's run
  // comparison is the one thing that cannot survive that — the whole point of
  // the matrix is holding two runs of the same demand side by side.
  final byMonth = <DateTime, List<SimOrderOutcome>>{};
  for (final outcome in slice.result.orders) {
    final month = DateTime(outcome.needDate.year, outcome.needDate.month);
    (byMonth[month] ??= []).add(outcome);
  }

  final months = byMonth.keys.toList()..sort();
  // **Ranked within the month by need date, earliest first** — not by the demand
  // `sequence`, which `gantt_layout.dart` and §8.5's plan already use for a
  // global 1-based order number. The same `#3` would otherwise name two
  // different orders on two screens.
  for (final orders in byMonth.values) {
    orders.sort((a, b) {
      final byDate = a.needDate.compareTo(b.needDate);
      // Sequence breaks the tie, so two orders due the same day do not swap
      // rows between two runs of one study (§4.4).
      return byDate != 0 ? byDate : a.sequence.compareTo(b.sequence);
    });
  }

  FloatBand band(Duration? float) {
    if (float == null) return FloatBand.undelivered;
    final days = float.inDays;
    if (days <= redDays) return FloatBand.red;
    if (days >= greenDays) return FloatBand.green;
    return FloatBand.amber;
  }

  final depth = byMonth.values.fold(0, (deepest, orders) =>
      orders.length > deepest ? orders.length : deepest);

  return FloatMatrix(
    months: months,
    redDays: redDays,
    greenDays: greenDays,
    rows: [
      for (var rank = 0; rank < depth; rank++)
        [
          for (final month in months)
            if (byMonth[month]!.length > rank)
              () {
                final outcome = byMonth[month]![rank];
                return FloatCell(
                  orderId: outcome.orderId,
                  partNumber: partNumbers[outcome.partId] ?? outcome.partId,
                  needDate: outcome.needDate,
                  float: outcome.float,
                  band: band(outcome.float),
                );
              }()
            else
              // **Blank, not zero.** A month with fewer orders has nothing to
              // say in that row, and a zero would read as an order delivered
              // exactly on its need date — which is the one figure the red band
              // exists to catch.
              null,
        ],
    ],
  );
}
