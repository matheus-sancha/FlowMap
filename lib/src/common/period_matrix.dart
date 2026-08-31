/// Rows × months, with banded cells and a frozen first column (#10).
///
/// **Two callers, from the start**: the Delivery Float matrix (§10.4) and the
/// Occupation grid (§10.3). #10 counted the grid widgets in this repo and found
/// two — the editable `DataGrid` and the read-only `resultTable` — plus these
/// two surfaces, each a raw `DataTable`. They are neither of the first two: a
/// period matrix has one column per month, so its width is data rather than
/// declared, and its cells are painted bands rather than text.
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

  /// A row that reads differently from the rest: the Occupation grid's PLANT
  /// row, pinned at the top and drawn in the emphasis colour.
  final bool? emphasis;
}

/// A banded cell: a background, an ink colour, the text, and an optional fill
/// along the base.
class PeriodMatrixCell {
  const PeriodMatrixCell({
    required this.text,
    required this.background,
    required this.foreground,
    this.tooltip,
    this.share,
  });

  final String text;
  final Color background;
  final Color foreground;
  final String? tooltip;

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
    this.pinned,
    this.pinnedCellAt,
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

  /// A row held above the scroll — the plant's own. Null when there is none.
  final PeriodMatrixRow? pinned;
  final PeriodMatrixCell? Function(int month)? pinnedCellAt;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HorizontalScroll(
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 34,
        columnSpacing: 12,
        horizontalMargin: 8,
        columns: [
          DataColumn(
            label: SizedBox(width: headerWidth, child: Text(headerLabel)),
          ),
          for (final (index, month) in months.indexed)
            DataColumn(
              label: _MonthHeading(
                label: DateFormat('MMM/yy').format(month),
                sorted: sortedMonth == index,
                ascending: sortAscending,
                onTap: onSortMonth == null
                    ? null
                    : () => onSortMonth!(index),
              ),
              numeric: true,
            ),
        ],
        rows: [
          if (pinned case final row? when pinnedCellAt != null)
            DataRow(
              // The plant reads as chrome rather than as one more station.
              color: WidgetStatePropertyAll(
                theme.colorScheme.surfaceContainerHighest,
              ),
              cells: [
                DataCell(_Header(row: row, width: headerWidth)),
                for (var m = 0; m < months.length; m++)
                  DataCell(_Cell(cell: pinnedCellAt!(m))),
              ],
            ),
          for (final (index, row) in rows.indexed)
            DataRow(
              cells: [
                DataCell(_Header(row: row, width: headerWidth)),
                for (var m = 0; m < months.length; m++)
                  DataCell(_Cell(cell: cellAt(index, m))),
              ],
            ),
        ],
      ),
    );
  }
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
        Text(label),
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
    return onTap == null
        ? row
        : InkWell(onTap: onTap, child: row);
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
    final body = Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: value.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        alignment: Alignment.centerRight,
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
          Text(
            value.text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: value.foreground,
            ),
          ),
        ],
      ),
    );

    return value.tooltip == null
        ? body
        : Tooltip(message: value.tooltip!, child: body);
  }
}
