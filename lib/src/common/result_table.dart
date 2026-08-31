/// The read-only result tables: declared widths, a pinned heading, and a pane
/// you can always reach the scrollbar of (DESIGN.md §12.6).
///
/// A table wider than its window has to scroll, and a table longer than its
/// window has to be bounded — otherwise its horizontal scrollbar sits at the
/// foot of a thousand rows, which is a bar you cannot get to. So a result table
/// is a fixed-height pane: the heading holds still, the body scrolls under it,
/// and both bars pin to the pane's edges. [maxHeight] only bites once the
/// content reaches it, so a five-row table shrink-wraps and looks exactly as it
/// did before.
///
/// **The heading and the body are two `DataTable`s.** Material sizes a column
/// to its widest participant, so two tables agree on a column only if they are
/// given the same width — which is why [ResultColumn] carries one and why both
/// the heading cell and every body cell are built through [_sized]. A heading
/// that could disagree with its body is worse than a heading that scrolls away:
/// the production plan has four adjacent date columns, and a column label over
/// the wrong column is a misread rather than a missing read.
///
/// The gutters are set to nothing on purpose. `DataTable`'s 24 px margin and
/// 56 px spacing would put 728 px of air into a fourteen-column plan and make
/// `ResultColumn.width` a number that does not describe the column it names.
/// The breathing room belongs *inside* the declared width, where it can be seen.
///
/// **Not the Takt table.** It fits, and §12.5 deliberately stretches it to fill
/// its card — declared widths would end that stretch for no gain. It is a
/// [DataGrid] rather than a table at all now, which is what finally killed
/// `centred_table.dart`: that file wrapped `DataColumn` and `DataCell` in a
/// `Center` for the Takt table's sake, this pane centres its own cells through
/// [ResultColumn.centred], and by the time #10 counted the callers it had none
/// outside its own test. Centring lives here and in [DataGrid], nowhere else.
///
/// **Not lazy.** A `DataTable` builds every row, so a §14-scale 2000-order plan
/// constructs 2000 rows to show seven of them. That was true before this pane
/// existed and is recorded in TODO §4 beside the run-time target it sits behind;
/// the pane makes it look lazier than it is, which is the reason to write it
/// down rather than the reason to fix it first.
library;

import 'package:flutter/material.dart';

import 'horizontal_scroll.dart';

/// One column of a [resultTable]: what it is called and how wide it is.
class ResultColumn {
  const ResultColumn({
    required this.label,
    required this.width,
    this.centred = true,
  });

  final String label;

  /// The whole column, gutters included — see the library comment.
  final double width;

  /// §12.5's rule: data read down a column is centred, actions are not. An
  /// edit-and-delete cell belongs beside the row it acts on, not adrift in the
  /// middle of it.
  final bool centred;
}

/// How tall a result pane grows before its body starts scrolling.
///
/// §2.7 picked this figure for the Gantt on the same tab and for the same
/// reason, so the Simulation tab has one answer to "a section taller than it is
/// useful" rather than one per section.
const double resultTableMaxHeight = 360;

const double _horizontalMargin = 12;
const double _columnSpacing = 0;

/// Room under the body for the horizontal bar, which Flutter draws inside the
/// viewport and would otherwise lay over the last row.
const double _barGutter = 12;

/// Declared rather than left to `DataTable`'s default, because the vertical
/// bar's track has to start where the body does. The bar is placed around the
/// whole pane — that is what pins it to the pane's right edge instead of the
/// table's — so without this it draws its thumb up beside the heading, over
/// rows that do not scroll. Two lines of label at 56 px, which is the same
/// figure `DataTable` would have chosen.
const double _headingHeight = 56;

Widget resultTable({
  Key? key,
  required List<ResultColumn> columns,
  required int rowCount,
  required Widget Function(int row, int column) cellAt,
  double? maxHeight = resultTableMaxHeight,
  bool fill = false,
  int? sortColumn,
  bool sortAscending = true,
  void Function(int column)? onSort,
}) => _ResultTable(
  key: key,
  columns: columns,
  rowCount: rowCount,
  cellAt: cellAt,
  maxHeight: maxHeight,
  fill: fill,
  sortColumn: sortColumn,
  sortAscending: sortAscending,
  onSort: onSort,
);

/// A [resultTable] that sorts itself, for the surfaces the rule names (#10).
///
/// > **A surface sorts unless its row order is itself data.**
///
/// So the queue ranking, the share of flow, the parts table and the summary
/// table sort — re-ranking is what a reader goes to those to do. The production
/// plan does not: its order is the release sequence. The float matrix does not:
/// row *r* means rank *r* in that column. No editable grid does: sequence order
/// is the record. *Rejected: every read-only table sorts* — simpler to state,
/// and clicking a heading on the plan or the matrix produces a table that looks
/// fine and says something false.
///
/// **State lives here, not in four call sites.** Each surface would otherwise
/// grow the same `int _sortColumn` / `bool _ascending` pair and the same
/// three-line `onSort`, which is four chances to get the toggle subtly
/// different.
///
/// [sortKeyOf] returns what a column compares, or **null for a column that does
/// not sort** — a name column with an icon in it, say. A null key leaves the
/// rows where they are rather than throwing, and the heading still shows no
/// arrow because [onSort] is never called for it.
class SortableResultTable<T> extends StatefulWidget {
  const SortableResultTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.cellAt,
    required this.sortKeyOf,
    this.initialColumn = 0,
    this.initialAscending = true,
    this.maxHeight = resultTableMaxHeight,
    this.fill = false,
  });

  final List<ResultColumn> columns;
  final List<T> rows;
  final Widget Function(T row, int column) cellAt;

  /// What column [column] compares on [row], or null if it does not sort.
  final Comparable<Object>? Function(T row, int column) sortKeyOf;

  /// Which column the surface arrives sorted on — **the order the metrics
  /// already computed**, so a table looks on arrival exactly as it did before
  /// it could sort at all.
  final int initialColumn;
  final bool initialAscending;

  final double? maxHeight;
  final bool fill;

  @override
  State<SortableResultTable<T>> createState() => _SortableResultTableState<T>();
}

class _SortableResultTableState<T> extends State<SortableResultTable<T>> {
  late int _column = widget.initialColumn;
  late bool _ascending = widget.initialAscending;

  @override
  Widget build(BuildContext context) {
    // **Sorted here rather than in the caller's list**, which is the run's own
    // ordering and is read by other surfaces. A copy costs one allocation per
    // build on tables of tens of rows.
    final rows = [...widget.rows];
    final sortable = widget.rows.isEmpty
        ? false
        : widget.sortKeyOf(widget.rows.first, _column) != null;
    if (sortable) {
      rows.sort((a, b) {
        final ka = widget.sortKeyOf(a, _column);
        final kb = widget.sortKeyOf(b, _column);
        if (ka == null || kb == null) return 0;
        final order = ka.compareTo(kb);
        return _ascending ? order : -order;
      });
    }

    return resultTable(
      columns: widget.columns,
      maxHeight: widget.maxHeight,
      fill: widget.fill,
      sortColumn: sortable ? _column : null,
      sortAscending: _ascending,
      onSort: (column) {
        // A column with no key is not offered: pressing it would move the
        // arrow onto a heading that sorts nothing.
        if (widget.rows.isEmpty) return;
        if (widget.sortKeyOf(widget.rows.first, column) == null) return;
        setState(() {
          if (_column == column) {
            _ascending = !_ascending;
          } else {
            _column = column;
            // **A new column starts ascending**, rather than inheriting the
            // previous column's direction — otherwise the first press on a
            // heading can sort it the way the reader did not ask for and the
            // second press is the one that looks like it worked.
            _ascending = true;
          }
        });
      },
      rowCount: rows.length,
      cellAt: (index, column) => widget.cellAt(rows[index], column),
    );
  }
}

class _ResultTable extends StatefulWidget {
  const _ResultTable({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.cellAt,
    required this.maxHeight,
    required this.fill,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
  });

  final List<ResultColumn> columns;
  final int rowCount;
  final Widget Function(int row, int column) cellAt;

  /// How tall the pane grows before the body scrolls, or **null** for a table
  /// that is simply as tall as it is.
  ///
  /// Null is for a table inside a page that already scrolls and can afford the
  /// length. A bounded pane there gives the reader two vertical bars a few
  /// pixels apart, one of which moves the table and one the page — which is not
  /// a thing anybody wants to have to tell apart. §12.6.
  final double? maxHeight;

  /// Widen the columns proportionally when the pane is wider than they need.
  ///
  /// Declared widths keep a heading over its own column; they do not oblige the
  /// table to leave the right-hand third of a wide window empty. When there is
  /// less room than the widths ask for, they are kept as declared and the table
  /// scrolls — so this is a way of using space, never of losing legibility.
  final bool fill;

  /// Which column the rows are ordered by, or null for a table that does not
  /// sort. **Presentation only**: the caller does the ordering and hands over
  /// rows already in it, so a table cannot claim an order its rows are not in.
  final int? sortColumn;
  final bool sortAscending;

  /// Called with the column the reader pressed. Null leaves the heading inert,
  /// which is what every table did before this existed.
  final void Function(int column)? onSort;

  @override
  State<_ResultTable> createState() => _ResultTableState();
}

class _ResultTableState extends State<_ResultTable> {
  final _vertical = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    super.dispose();
  }

  /// What each column is actually laid out at.
  ///
  /// The declared widths, unless [_ResultTable.fill] is set and there is more
  /// room than they ask for — in which case every column is stretched by the
  /// same factor, so the proportions a reader learns from one window are the
  /// ones they see in the next. Never *narrower* than declared: that would put
  /// the cap back on the columns the declared widths exist to keep off.
  List<double> _widths(double available) {
    final declared = [for (final column in widget.columns) column.width];
    if (!widget.fill || !available.isFinite) return declared;

    final natural = declared.fold<double>(0, (sum, w) => sum + w);
    // A pixel in hand, so rounding cannot leave a scroll view with one pixel
    // of extent and therefore a thumb on a table that fits.
    final room = available - 2 * _horizontalMargin - 1;
    if (room <= natural) return declared;
    return [for (final w in declared) w * room / natural];
  }

  /// Every participant in a column is exactly the same width, which is what
  /// makes the heading table and the body table compute the same layout.
  Widget _sized(ResultColumn column, double width, Widget child) => SizedBox(
    width: width,
    child: column.centred
        ? Center(child: child)
        : Align(alignment: AlignmentDirectional.centerStart, child: child),
  );

  Widget _heading(List<double> widths) => DataTable(
    horizontalMargin: _horizontalMargin,
    columnSpacing: _columnSpacing,
    headingRowHeight: _headingHeight,
    columns: [
      for (var i = 0; i < widget.columns.length; i++)
        DataColumn(
          label: _sized(
            widget.columns[i],
            widths[i],
            // Two lines and then an ellipsis. A declared width is a promise the
            // heading has to keep as well: `Theoretical lead time` in a 120 px
            // column would otherwise run past the heading row's height and
            // overflow, and a label that overflows is one nobody can read
            // anyway.
            _HeadingLabel(
              column: widget.columns[i],
              sorted: widget.sortColumn == i,
              ascending: widget.sortAscending,
              onSort: widget.onSort == null
                  ? null
                  : () => widget.onSort!(i),
            ),
          ),
        ),
    ],
    rows: const [],
  );

  Widget _body(List<double> widths) => DataTable(
    horizontalMargin: _horizontalMargin,
    columnSpacing: _columnSpacing,
    // The heading is drawn once, above. This one exists only so the column
    // widths are declared to the same table that lays the cells out — and a
    // bare box rather than the label, so the text is not in the tree twice for
    // a screen reader to find.
    headingRowHeight: 0,
    columns: [
      for (final width in widths) DataColumn(label: SizedBox(width: width)),
    ],
    rows: [
      for (var row = 0; row < widget.rowCount; row++)
        DataRow(
          cells: [
            for (var column = 0; column < widget.columns.length; column++)
              DataCell(
                _sized(
                  widget.columns[column],
                  widths[column],
                  widget.cellAt(row, column),
                ),
              ),
          ],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _build(context, constraints.maxWidth),
  );

  Widget _build(BuildContext context, double available) {
    final widths = _widths(available);
    final maxHeight = widget.maxHeight;

    final pane = HorizontalScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(widths),
          if (maxHeight == null)
            _body(widths)
          else
            // Loose, so a short table takes only the height it needs and a long
            // one stops at [maxHeight].
            Flexible(
              child: SingleChildScrollView(
                controller: _vertical,
                child: _body(widths),
              ),
            ),
          const SizedBox(height: _barGutter),
        ],
      ),
    );

    // Nothing to bound, so nothing to scroll vertically and no second bar. The
    // page this sits in is the one that scrolls, and it already has one.
    if (maxHeight == null) return pane;

    final media = MediaQuery.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      // Outside the horizontal scroll view, holding the inner controller:
      // nesting alone cannot pin both bars, but a Scrollbar can be placed
      // anywhere so long as it is handed the position it draws. Here that puts
      // the vertical bar on the pane's right edge instead of the table's,
      // which on a wide table is off screen.
      //
      // The cost of being outside is that the bar's track spans the heading
      // too, and drew its thumb beside rows that do not scroll. Material's
      // `Scrollbar` does not expose `RawScrollbar.padding`, but leaves it null
      // and falls back to the ambient `MediaQuery` — so the inset is handed to
      // the bar that way, and the real one is restored underneath so nothing
      // in a cell sees a window that is 56 px shorter than it is.
      child: MediaQuery(
        data: media.copyWith(
          padding: const EdgeInsets.only(
            top: _headingHeight,
            bottom: _barGutter,
          ),
        ),
        child: Scrollbar(
          controller: _vertical,
          thumbVisibility: true,
          // As in [HorizontalScroll]: a control, not an indicator.
          interactive: true,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.vertical,
          child: MediaQuery(data: media, child: pane),
        ),
      ),
    );
  }
}

/// A heading label, with a sort arrow when the table sorts.
///
/// **The arrow is inside the declared width**, like everything else in this
/// table — a heading that grew to fit an arrow would stop agreeing with the
/// body column beneath it, which is the one thing the two-table layout exists
/// to prevent.
class _HeadingLabel extends StatelessWidget {
  const _HeadingLabel({
    required this.column,
    required this.sorted,
    required this.ascending,
    required this.onSort,
  });

  final ResultColumn column;
  final bool sorted;
  final bool ascending;
  final VoidCallback? onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(
      column.label,
      textAlign: column.centred ? TextAlign.center : TextAlign.start,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    if (onSort == null) return label;

    return InkWell(
      onTap: onSort,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: column.centred
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Flexible(child: label),
          // Reserved whether or not this column is the sorted one, so pressing
          // a heading does not shuffle the labels either side of it.
          SizedBox(
            width: 18,
            child: sorted
                ? Icon(
                    ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: theme.colorScheme.primary,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
