/// Rows × months, with banded cells and a frozen first column (#10).
///
/// **Two callers, from the start**: the Delivery Float matrix (§10.4) and the
/// Occupation grid (§10.3). #10 counted the grid widgets in this repo and found
/// two — the editable `DataGrid` and the read-only `resultTable` — plus these
/// two surfaces, each a raw `DataTable`. They are neither of the first two: a
/// period matrix has one column per month, so its width is data rather than
/// declared, and its cells are painted bands rather than text.
///
/// **The frozen column became real in #16.** This comment claimed one from the
/// day it was written while every column sat inside a single `DataTable` inside
/// a single scroll — so the labels slid away with the data, and nobody noticed
/// because nothing asserted it. It is now a pinned gutter beside a scrolling
/// body, two `Column`s kept in step by one row height, and
/// `period_matrix_test.dart` holds it down.
///
/// **[banner] is why it had to be.** The Occupation chart is drawn above this
/// matrix as its header; its hours axis has to stay out of the scroll (#13) and
/// its bars have to move with the month columns (#16), which is only possible
/// once the gutter and the body are separately scrollable things.
///
/// **Known asymmetry, accepted.** The two share the chrome and not the row
/// semantics: float's row *r* means *"the order ranked r that month"*, each
/// column independently sorted and ragged, while occupation's rows are stations
/// or lines that persist across the row. So this takes `cellAt(row, column)` and
/// the row's meaning stays the caller's — which is the honest seam, and the
/// reason this is not `FloatMatrixTable` with a flag.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'horizontal_scroll.dart';

/// The frozen first column of one row: what identifies it.
class PeriodMatrixRow {
  const PeriodMatrixRow({required this.label, this.qualifier, this.emphasis});

  /// `CEU27`, or the rank `1` on the float matrix.
  final String label;

  /// A second line under it — the pool a station ran in, or the cell a line
  /// sits in. Null where there is nothing to qualify.
  final String? qualifier;

  /// A row that reads differently from the rest: the Occupation grid's TOTAL
  /// row, drawn along the bottom in the emphasis colour (#14).
  final bool? emphasis;
}

/// A banded cell: a background, an ink colour, the text, and an optional fill
/// along the base.
class PeriodMatrixCell {
  const PeriodMatrixCell({
    required this.text,
    this.subtext,
    required this.background,
    required this.foreground,
    this.tooltip,
    this.richTooltip,
    this.share,
  });

  final String text;

  /// A second line under [text], dimmer and smaller (#14).
  ///
  /// **What the Hours unit uses to stop reading as a fraction.** It was
  /// `733/499` on one line, which is two facts wearing the punctuation of one
  /// number — and the field asked for demand above capacity instead. Null on
  /// every other unit and on the float matrix, which have one figure to give.
  final String? subtext;

  final Color background;
  final Color foreground;
  final String? tooltip;

  /// A formatted hover, where a plain [tooltip] is not enough (#14).
  ///
  /// The Occupation grid uses it so its cells carry **the same hover the chart
  /// bars carry** — a bold heading, then demand and capacity, then what the
  /// demand is made of. Both are built by one function, so the two surfaces
  /// cannot come to explain the same month differently.
  final InlineSpan? richTooltip;

  /// How much of the cell belongs to the reader's own filter, 0–1, or null for
  /// a cell with nothing to divide.
  ///
  /// **Drawn as a fill along the base rather than as a second colour**, so the
  /// band still says *how loaded* while the fill says *how much of it is
  /// yours*. Those are two questions and a single hue can only answer one.
  final double? share;
}

/// The matrix.
class PeriodMatrix extends StatelessWidget {
  const PeriodMatrix({
    super.key,
    required this.months,
    required this.rows,
    required this.cellAt,
    required this.headerLabel,
    this.headerWidth = 150,
    this.monthWidth = defaultMonthWidth,
    this.banner,
    this.aggregate,
    this.aggregateCellAt,
    this.trailingLabel,
    this.trailingCellAt,
    this.aggregateTrailingCell,
    this.trailingWidth = 84,
    this.sortedMonth,
    this.sortAscending = false,
    this.onSortMonth,
  });

  final List<DateTime> months;
  final List<PeriodMatrixRow> rows;

  /// Null for a cell this row has nothing to say in — **blank rather than
  /// zero**, which would read as a real figure of zero.
  final PeriodMatrixCell? Function(int row, int month) cellAt;

  /// What sits over the frozen column: `#` on the float matrix, the grouping's
  /// name on the Occupation grid.
  final String headerLabel;
  final double headerWidth;

  /// The width every month column takes unless a caller says otherwise.
  ///
  /// Public because the Occupation chart has to lay its bars out to exactly
  /// this before it is handed to [banner], and a second copy of the number is
  /// how the two would come apart.
  static const defaultMonthWidth = 72.0;

  /// **One width for every month column, rather than sizing to content** (#16).
  /// The Occupation chart is drawn above this matrix and its bars must be as
  /// wide as the columns they sit over; a column that sized itself to its
  /// widest cell would move the moment the unit switch changed `81%` into
  /// `733/499`, and take the chart out of alignment with it.
  final double monthWidth;

  /// Which month column the rows are ordered by, and whether ascending.
  ///
  /// **Offered, and one of the two callers declines it** (#10). *A surface
  /// sorts unless its row order is itself data*: the Occupation grid's rows are
  /// stations, so ordering them by April is a question a planner asks — while
  /// the float matrix's row *r* **means** rank *r* in that column, and sorting
  /// it would produce a table that looks fine and says something false.
  ///
  /// So this is null there, and the headings show no arrow.
  final int? sortedMonth;
  final bool sortAscending;
  final ValueChanged<int>? onSortMonth;

  /// A widget spanning the top of the matrix, in two pieces that line up with
  /// the two halves below it (#16).
  ///
  /// **This is how the Occupation chart became the grid's header.** The chart
  /// and the grid are the same months, so drawing them as two stacked surfaces
  /// with two scrollbars and two column widths made a reader align them by eye.
  /// Passing the chart in here instead means one column width, one horizontal
  /// scrollbar, and a bar sitting directly above its own row of cells.
  ///
  /// `gutter` is pinned beside the frozen labels — it holds the chart's hours
  /// axis, which #13 established has to stay out of the scroll or the bars are
  /// measured against nothing. `body` scrolls with the month columns and is
  /// laid out `months.length * monthWidth` wide, so it cannot drift out of step.
  final ({double height, Widget gutter, Widget body})? banner;

  /// The row along the bottom: the Occupation grid's TOTAL (#14).
  ///
  /// **At the bottom, and always shown** — both of which changed in #14. It was
  /// `pinned`, drawn at the top, and hidden the moment a filter narrowed the
  /// station set, because #9 judged *"a partial wearing the plant's name"*
  /// worse than no row at all. Renaming it from PLANT to **TOTAL** dissolved
  /// that: a total only ever claims to be the total of the rows above it, which
  /// is true under every filter — and a filtered view is exactly when someone
  /// wants one.
  final PeriodMatrixRow? aggregate;
  final PeriodMatrixCell? Function(int month)? aggregateCellAt;

  /// The column along the right: each row summarised across every month shown.
  ///
  /// **Frozen, like the labels opposite it** (#14). The months scroll between
  /// two fixed edges — the row's name on the left, its total on the right — so
  /// the summary is never the column a reader has to hunt for on a long run.
  ///
  /// Null on a caller that has no per-row summary worth drawing: the float
  /// matrix's rows are *ranks*, and averaging rank 3 across months averages
  /// unrelated orders. It passes [aggregateTrailingCell] alone, so its right
  /// edge holds one figure — the run's own mean float — and nothing above it.
  final String? trailingLabel;
  final PeriodMatrixCell? Function(int row)? trailingCellAt;
  final PeriodMatrixCell? aggregateTrailingCell;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // **The matrix measures itself** (#16). The field reported the Occupation
    // grid's rows cramped at 48; the float matrix's rows are a bare rank and
    // were fine at 34. Rather than one constant that is wrong for one of them,
    // or a parameter each caller has to remember, the height follows the thing
    // that actually decides it: whether any row carries a second line.
    // A cell can carry a second line too (the Hours unit stacks demand over
    // capacity), and a 40 pt row cannot hold one. Probing the first row's
    // months is enough: a unit is a property of the whole grid, never of one
    // cell.
    var stacked = false;
    if (rows.isNotEmpty) {
      for (var m = 0; m < months.length && !stacked; m++) {
        stacked = cellAt(0, m)?.subtext != null;
      }
    }

    final tall =
        stacked ||
        rows.any((row) => row.qualifier != null) ||
        aggregate?.qualifier != null;
    final rowHeight = tall ? 60.0 : 40.0;
    const headingHeight = 40.0;

    final divider = BorderSide(color: theme.colorScheme.outlineVariant);
    final hasTrailing = trailingLabel != null || aggregateTrailingCell != null;

    Color? tint(bool emphasis) =>
        emphasis ? theme.colorScheme.surfaceContainerHighest : null;

    Widget gutterCell(PeriodMatrixRow row) => Container(
      height: rowHeight,
      padding: const EdgeInsets.only(left: 8, right: 4),
      alignment: Alignment.centerLeft,
      color: tint(row.emphasis ?? false),
      child: _Header(row: row, width: headerWidth - 12),
    );

    Widget valueCell(PeriodMatrixCell? cell, double width) => SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: _Cell(cell: cell),
      ),
    );

    Widget bodyRow(
      PeriodMatrixCell? Function(int month) cellOf, {
      bool emphasis = false,
    }) => Container(
      height: rowHeight,
      color: tint(emphasis),
      child: Row(
        children: [
          for (var m = 0; m < months.length; m++)
            valueCell(cellOf(m), monthWidth),
        ],
      ),
    );

    Widget trailingCell(PeriodMatrixCell? cell, {bool emphasis = false}) =>
        Container(
          height: rowHeight,
          color: tint(emphasis),
          child: valueCell(cell, trailingWidth),
        );

    Widget headingBox({required Widget child, EdgeInsets? padding}) =>
        Container(
          height: headingHeight,
          padding: padding,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(border: Border(bottom: divider)),
          child: child,
        );

    final bodyWidth = months.length * monthWidth;

    // **A real frozen column, at last.** This file has claimed one since #10 —
    // *"rows × months, with banded cells and a frozen first column"* — while
    // putting every column inside one `DataTable` inside one scroll, so the
    // labels slid away with the data. #16 needed the gutter pinned for the
    // chart's axis anyway, and pinning one meant pinning both. #14 then pinned
    // the other edge too, so the months scroll between two fixed columns.
    //
    // **But only once there is something to scroll** (#14, after the field
    // reported *"the distance between the column and the grid"*). Making the
    // body `Expanded` unconditionally gave it every spare pixel, which pushed
    // the frozen TOTAL column hard against the window edge and left a band of
    // dead space between the last month and the summary of it. Where the whole
    // matrix fits, the body takes exactly its own width and the trailing column
    // sits where a reader expects it: immediately after the last month.
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed =
            headerWidth + bodyWidth + (hasTrailing ? trailingWidth : 0);
        final fits =
            constraints.hasBoundedWidth && needed <= constraints.maxWidth;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: headerWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (banner case final top?)
                    SizedBox(
                      height: top.height,
                      width: headerWidth,
                      child: top.gutter,
                    ),
                  headingBox(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(headerLabel, style: theme.textTheme.labelLarge),
                  ),
                  for (final row in rows) gutterCell(row),
                  if (aggregate case final row?) gutterCell(row),
                ],
              ),
            ),
            // Sized to its months when they fit, and only then wrapped in a
            // scroller — a scrollbar under content that cannot move is a control
            // that says the table is cut off when it is not.
            _Body(
              fits: fits,
              width: bodyWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (banner case final top?)
                    SizedBox(
                      height: top.height,
                      width: months.length * monthWidth,
                      child: top.body,
                    ),
                  Container(
                    height: headingHeight,
                    decoration: BoxDecoration(border: Border(bottom: divider)),
                    child: Row(
                      children: [
                        for (final (index, month) in months.indexed)
                          SizedBox(
                            width: monthWidth,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: _MonthHeading(
                                label: DateFormat('MMM/yy').format(month),
                                sorted: sortedMonth == index,
                                ascending: sortAscending,
                                onTap: onSortMonth == null
                                    ? null
                                    : () => onSortMonth!(index),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final (index, _) in rows.indexed)
                    bodyRow((month) => cellAt(index, month)),
                  if (aggregate case final row? when aggregateCellAt != null)
                    bodyRow(aggregateCellAt!, emphasis: row.emphasis ?? false),
                ],
              ),
            ),
            if (hasTrailing)
              SizedBox(
                width: trailingWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (banner case final top?) SizedBox(height: top.height),
                    headingBox(
                      child: SizedBox(
                        width: trailingWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            trailingLabel ?? '',
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                      ),
                    ),
                    for (final (index, _) in rows.indexed)
                      trailingCell(trailingCellAt?.call(index)),
                    if (aggregate case final row?)
                      trailingCell(
                        aggregateTrailingCell,
                        emphasis: row.emphasis ?? false,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The month columns: their own width where the matrix fits, a scroller where
/// it does not (#14).
///
/// **A widget rather than a ternary at the call site**, because the two branches
/// have to sit in the same slot of the same `Row` — `Expanded` is only legal as
/// a direct child of one, so the choice cannot be pushed any further down.
class _Body extends StatelessWidget {
  const _Body({required this.fits, required this.width, required this.child});

  final bool fits;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => fits
      ? SizedBox(width: width, child: child)
      : Expanded(child: HorizontalScroll(child: child));
}

/// A month heading that can be pressed to sort by it.
///
/// The arrow slot is **reserved whether or not this column is the sorted one**,
/// so pressing a heading does not shuffle the labels either side of it — the
/// same rule `result_table.dart` follows, for the same reason.
class _MonthHeading extends StatelessWidget {
  const _MonthHeading({
    required this.label,
    required this.sorted,
    required this.ascending,
    required this.onTap,
  });

  final String label;
  final bool sorted;
  final bool ascending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // **Ellipsised, because the column is now a declared width** (#16).
        // Inside a `DataTable` this heading sized its own column and could
        // never overflow; over a fixed 72 px it can, and an unbounded `Text`
        // here throws rather than clipping.
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        if (onTap != null)
          SizedBox(
            width: 16,
            child: sorted
                ? Icon(
                    ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 13,
                    color: theme.colorScheme.primary,
                  )
                : null,
          ),
      ],
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.row, required this.width});

  final PeriodMatrixRow row;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            row.label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: (row.emphasis ?? false)
                ? theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )
                : null,
          ),
          // **Ellipsised, never wrapped.** A pool name is long enough to take
          // two lines and a row that grows breaks the alignment every other row
          // depends on.
          if (row.qualifier case final qualifier?)
            Text(
              qualifier,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }
}

/// One banded cell.
///
/// **The colour is a background rather than the text**, so a red cell is legible
/// at a glance across a matrix of sixty and does not depend on the reader
/// telling three similar text colours apart.
class _Cell extends StatelessWidget {
  const _Cell({required this.cell});

  final PeriodMatrixCell? cell;

  @override
  Widget build(BuildContext context) {
    final value = cell;
    // Blank rather than zero: a month this row has nothing to say in is not a
    // month it said zero.
    if (value == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    // **Centred** (#14), where these were right-aligned. Right alignment is the
    // usual rule for a column of figures, because it lines the digits up — but
    // every cell here is its own filled band with its own rounded edges, so the
    // digits are read against the band rather than against the column, and a
    // number pushed to one edge of its own tile reads as an accident.
    final body = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: value.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (value.share case final share? when share < 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: share.clamp(0, 1),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: value.foreground,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          // Ellipsised for the same reason as the month heading (#16): the
          // column is a declared width now. The tooltip carries every figure in
          // full, so a clipped cell loses nothing that cannot be recovered by
          // hovering it.
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.text,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: value.foreground,
                ),
              ),
              // **Under it rather than after a slash.** Demand above, capacity
              // below, dimmer — so the pair reads as two measurements of the
              // same month instead of as one division.
              if (value.subtext case final second?)
                Text(
                  second,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: value.foreground.withValues(alpha: 0.72),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (value.richTooltip case final rich?) {
      return Tooltip(richMessage: rich, child: body);
    }
    return value.tooltip == null
        ? body
        : Tooltip(message: value.tooltip!, child: body);
  }
}
