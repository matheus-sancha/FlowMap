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
/// 56 px spacing would put 672 px of air into a thirteen-column plan and make
/// `ResultColumn.width` a number that does not describe the column it names.
/// The breathing room belongs *inside* the declared width, where it can be seen.
///
/// **Not the Takt table.** It fits, and §12.5 deliberately stretches it to fill
/// its card — declared widths would end that stretch for no gain. It keeps
/// `centredColumn` / `centredCell` from `centred_table.dart`.
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
  double maxHeight = resultTableMaxHeight,
}) => _ResultTable(
  key: key,
  columns: columns,
  rowCount: rowCount,
  cellAt: cellAt,
  maxHeight: maxHeight,
);

class _ResultTable extends StatefulWidget {
  const _ResultTable({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.cellAt,
    required this.maxHeight,
  });

  final List<ResultColumn> columns;
  final int rowCount;
  final Widget Function(int row, int column) cellAt;
  final double maxHeight;

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

  /// Every participant in a column is exactly [ResultColumn.width] wide, which
  /// is what makes the heading table and the body table compute the same
  /// layout.
  Widget _sized(ResultColumn column, Widget child) => SizedBox(
    width: column.width,
    child: column.centred
        ? Center(child: child)
        : Align(alignment: AlignmentDirectional.centerStart, child: child),
  );

  Widget get _heading => DataTable(
    horizontalMargin: _horizontalMargin,
    columnSpacing: _columnSpacing,
    headingRowHeight: _headingHeight,
    columns: [
      for (final column in widget.columns)
        DataColumn(
          label: _sized(
            column,
            // Two lines and then an ellipsis. A declared width is a promise the
            // heading has to keep as well: `Theoretical lead time` in a 120 px
            // column would otherwise run past the heading row's height and
            // overflow, and a label that overflows is one nobody can read
            // anyway.
            Text(
              column.label,
              textAlign: column.centred ? TextAlign.center : TextAlign.start,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
    ],
    rows: const [],
  );

  Widget get _body => DataTable(
    horizontalMargin: _horizontalMargin,
    columnSpacing: _columnSpacing,
    // The heading is drawn once, above. This one exists only so the column
    // widths are declared to the same table that lays the cells out — and a
    // bare box rather than the label, so the text is not in the tree twice for
    // a screen reader to find.
    headingRowHeight: 0,
    columns: [
      for (final column in widget.columns)
        DataColumn(label: SizedBox(width: column.width)),
    ],
    rows: [
      for (var row = 0; row < widget.rowCount; row++)
        DataRow(
          cells: [
            for (var column = 0; column < widget.columns.length; column++)
              DataCell(
                _sized(widget.columns[column], widget.cellAt(row, column)),
              ),
          ],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final pane = HorizontalScroll(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading,
          // Loose, so a short table takes only the height it needs and a long
          // one stops at [maxHeight].
          Flexible(
            child: SingleChildScrollView(controller: _vertical, child: _body),
          ),
          const SizedBox(height: _barGutter),
        ],
      ),
    );

    final media = MediaQuery.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
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
