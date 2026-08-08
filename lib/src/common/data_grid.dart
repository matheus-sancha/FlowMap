/// The editable grid the demand tables are entered in (DESIGN.md §9).
///
/// One text field per cell, keyboard navigation, and multi-cell TSV paste from
/// Excel. Every column is text, deliberately: a dropdown or a date picker in a
/// column would make that column unpasteable, and pasting a block out of the
/// planner's spreadsheet is the way this data actually arrives. What a cell
/// means is decided by the parser the caller supplies, and anything unparseable
/// stays on screen as an error rather than being dropped.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'horizontal_scroll.dart';

/// One column of a [DataGrid].
class DataGridColumn {
  const DataGridColumn({
    required this.title,
    this.width = 128,
    this.numeric = false,
    this.readOnly = false,
    this.helper,
  });

  final String title;
  final double width;

  /// Right-aligns the cell — times, quantities, dates read better that way.
  final bool numeric;

  /// A column that can be read but not typed into: a derived total, or a step
  /// with no workcenter bound to key its values by.
  final bool readOnly;

  /// Shown under the header, for a unit or a format hint.
  final String? helper;
}

/// A rectangular block of raw cell text starting at one cell.
///
/// A typed cell is a 1×1 block and a paste is a rectangle, so a caller writes
/// one commit path and gets both. Cells past the end of the grid are the
/// caller's to append or ignore — the grid does not invent rows.
typedef DataGridCommit =
    void Function(int row, int column, List<List<String>> block);

class DataGrid extends StatefulWidget {
  const DataGrid({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.valueAt,
    required this.onCommit,
    this.errorAt,
    this.rowHeader,
    this.rowActions,
    this.rowHeaderWidth = 56,
    this.rowActionsWidth = 56,
    this.frozenColumns = 0,
  });

  final List<DataGridColumn> columns;
  final int rowCount;

  /// What the cell reads as when it is not being edited.
  final String Function(int row, int column) valueAt;

  final DataGridCommit onCommit;

  /// Why a cell's text cannot be accepted, or null if it can. Called on every
  /// keystroke, so it must be cheap and must not throw.
  final String? Function(int row, int column, String raw)? errorAt;

  /// The fixed left-hand cell of a row — a sequence number, usually.
  final Widget Function(int row)? rowHeader;

  /// The fixed right-hand cell of a row — delete, move up, move down.
  final Widget Function(int row)? rowActions;

  final double rowHeaderWidth;
  final double rowActionsWidth;

  /// How many leading columns stay put while the rest scroll sideways, the row
  /// header going with them.
  ///
  /// Zero means one pane and no synchronising, which is what the sequence grid
  /// wants: six columns fit, and a second scroll position that cannot disagree
  /// is better than one that merely does not. The parts grid freezes its part
  /// number, because a study of fifteen workcenters is 2 500 px wide and the
  /// column that says *which part this row is* would otherwise be the first
  /// thing to leave the window.
  final int frozenColumns;

  @override
  State<DataGrid> createState() => _DataGridState();
}

class _DataGridState extends State<DataGrid> {
  /// Live cell focus nodes, keyed `row:column`.
  ///
  /// Registered by the cells themselves as they are built and removed as they
  /// are disposed, so navigation only ever reaches a cell that exists. A row
  /// scrolled far out of the list is not in here, and Enter simply stops at the
  /// edge of what is built rather than throwing.
  final _nodes = <String, FocusNode>{};

  ({int row, int column})? _anchor;

  /// One vertical position per pane, kept equal.
  ///
  /// Two lists rather than one is the price of a frozen column: the frozen
  /// cells sit outside the horizontal scroll view — that is what makes them
  /// frozen — so they cannot be rows of the same list as the cells inside it.
  /// Both stay driveable, so the wheel works over either pane, and each pushes
  /// the other; [_syncing] is what stops that being a loop.
  final _frozenRows = ScrollController();
  final _scrollingRows = ScrollController();
  bool _syncing = false;

  bool get _frozen => widget.frozenColumns > 0;

  @override
  void initState() {
    super.initState();
    _frozenRows.addListener(() => _follow(_frozenRows, _scrollingRows));
    _scrollingRows.addListener(() => _follow(_scrollingRows, _frozenRows));
  }

  @override
  void dispose() {
    _frozenRows.dispose();
    _scrollingRows.dispose();
    super.dispose();
  }

  void _follow(ScrollController from, ScrollController to) {
    if (_syncing || !_frozen) return;
    if (!from.hasClients || !to.hasClients) return;
    // Clamped rather than trusted equal. The two panes hold the same rows at
    // the same heights, so their extents agree — but a jumpTo past the end
    // throws, and being wrong here would break scrolling rather than merely
    // misalign it.
    final target = from.offset.clamp(
      to.position.minScrollExtent,
      to.position.maxScrollExtent,
    );
    if (target == to.offset) return;
    _syncing = true;
    to.jumpTo(target);
    _syncing = false;
  }

  void _register(int row, int column, FocusNode node) =>
      _nodes['$row:$column'] = node;

  void _unregister(int row, int column, FocusNode node) {
    if (_nodes['$row:$column'] == node) _nodes.remove('$row:$column');
  }

  void _move(int deltaRow, int deltaColumn) {
    final anchor = _anchor;
    if (anchor == null) return;

    var row = anchor.row;
    var column = anchor.column;

    if (deltaColumn != 0) {
      column += deltaColumn;
      // Tabbing off the end wraps to the next row, as a spreadsheet does.
      while (column >= widget.columns.length) {
        column -= widget.columns.length;
        row++;
      }
      while (column < 0) {
        column += widget.columns.length;
        row--;
      }
    }
    row += deltaRow;

    if (row < 0 || row >= widget.rowCount) return;
    _nodes['$row:$column']?.requestFocus();
  }

  /// Pastes the clipboard as a block anchored at the focused cell.
  Future<void> _paste() async {
    final anchor = _anchor;
    if (anchor == null) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    widget.onCommit(anchor.row, anchor.column, parseTsv(text));
  }

  /// Room for the horizontal bar, which Flutter draws inside the viewport and
  /// would otherwise lay over the last row (§12.6).
  ///
  /// Both panes carry it, though only one has a bar: equal viewport heights are
  /// what make the two lists' scroll extents agree, and [_follow] is only exact
  /// while they do.
  static const _barGutter = 12.0;

  /// Declared, because the two panes hold different things and would otherwise
  /// measure differently.
  ///
  /// The frozen pane carries the row header and the scrolling one the row
  /// actions — and an `IconButton` is 48 px where a cell is 44, so the rows
  /// drifted four pixels further apart with every row down the grid. `itemExtent`
  /// also makes the two lists' scroll extents identical rather than merely
  /// similar, which is what [_follow] assumes.
  static const _rowHeight = 48.0;

  /// Likewise for the heading: a column with a `helper` under its title is two
  /// lines where a column without one is one, so a frozen part number beside a
  /// helper-bearing station would start its rows higher than the pane next to it.
  static const _headerHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frozen = widget.frozenColumns.clamp(0, widget.columns.length);

    return CallbackShortcuts(
      bindings: {
        // Above the app's own text-editing shortcuts in the tree, so this wins
        // while a cell has focus — which is what makes a block paste possible
        // at all: the field would otherwise swallow the whole clipboard into
        // one cell.
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): _paste,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _paste,
      },
      child: frozen == 0
          ? HorizontalScroll(
              child: _pane(
                theme,
                from: 0,
                to: widget.columns.length,
                leading: true,
                trailing: true,
                controller: _scrollingRows,
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _pane(
                  theme,
                  from: 0,
                  to: frozen,
                  leading: true,
                  trailing: false,
                  controller: _frozenRows,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: HorizontalScroll(
                    child: _pane(
                      theme,
                      from: frozen,
                      to: widget.columns.length,
                      leading: false,
                      trailing: true,
                      controller: _scrollingRows,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// One column of the grid's width: a heading, a rule, and the rows under it.
  ///
  /// [from] and [to] slice the columns; [leading] carries the row header and
  /// [trailing] the row actions. A cell keys its focus node by its *absolute*
  /// column, so Tab crosses the seam between the panes without knowing there is
  /// one.
  Widget _pane(
    ThemeData theme, {
    required int from,
    required int to,
    required bool leading,
    required bool trailing,
    required ScrollController controller,
  }) {
    final width =
        (leading && widget.rowHeader != null ? widget.rowHeaderWidth : 0.0) +
        widget.columns
            .sublist(from, to)
            .fold<double>(0, (sum, c) => sum + c.width) +
        (trailing && widget.rowActions != null ? widget.rowActionsWidth : 0.0);

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(theme, from: from, to: to, leading: leading,
              trailing: trailing),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemExtent: _rowHeight,
              itemCount: widget.rowCount,
              itemBuilder: (context, row) => _row(
                row,
                from: from,
                to: to,
                leading: leading,
                trailing: trailing,
              ),
            ),
          ),
          const SizedBox(height: _barGutter),
        ],
      ),
    );
  }

  Widget _header(
    ThemeData theme, {
    required int from,
    required int to,
    required bool leading,
    required bool trailing,
  }) => SizedBox(
    height: _headerHeight,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (leading && widget.rowHeader != null)
            SizedBox(width: widget.rowHeaderWidth),
          for (final column in widget.columns.sublist(from, to))
            SizedBox(
              width: column.width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  crossAxisAlignment: column.numeric
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      column.title,
                      style: theme.textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (column.helper != null)
                      Text(
                        column.helper!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          if (trailing && widget.rowActions != null)
            SizedBox(width: widget.rowActionsWidth),
        ],
      ),
    ),
  );

  Widget _row(
    int row, {
    required int from,
    required int to,
    required bool leading,
    required bool trailing,
  }) => Row(
    key: ValueKey('row-$row-$from'),
    children: [
      if (leading && widget.rowHeader != null)
        SizedBox(width: widget.rowHeaderWidth, child: widget.rowHeader!(row)),
      for (var column = from; column < to; column++)
        SizedBox(
          width: widget.columns[column].width,
          child: _GridCell(
            key: ValueKey('cell-$row-$column'),
            value: widget.valueAt(row, column),
            spec: widget.columns[column],
            error: (raw) => widget.errorAt?.call(row, column, raw),
            onRegister: (node) => _register(row, column, node),
            onUnregister: (node) => _unregister(row, column, node),
            onFocused: () => _anchor = (row: row, column: column),
            onCommit: (text) => widget.onCommit(row, column, [
              [text],
            ]),
            onMove: _move,
          ),
        ),
      if (trailing && widget.rowActions != null)
        SizedBox(width: widget.rowActionsWidth, child: widget.rowActions!(row)),
    ],
  );
}

class _GridCell extends StatefulWidget {
  const _GridCell({
    super.key,
    required this.value,
    required this.spec,
    required this.error,
    required this.onRegister,
    required this.onUnregister,
    required this.onFocused,
    required this.onCommit,
    required this.onMove,
  });

  final String value;
  final DataGridColumn spec;
  final String? Function(String raw) error;
  final void Function(FocusNode node) onRegister;
  final void Function(FocusNode node) onUnregister;
  final VoidCallback onFocused;
  final ValueChanged<String> onCommit;
  final void Function(int deltaRow, int deltaColumn) onMove;

  @override
  State<_GridCell> createState() => _GridCellState();
}

class _GridCellState extends State<_GridCell> {
  late final _controller = TextEditingController(text: widget.value);
  late final _focus = FocusNode()..addListener(_onFocusChanged);
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.onRegister(_focus);
  }

  @override
  void didUpdateWidget(_GridCell old) {
    super.didUpdateWidget(old);
    // A value that changed underneath — a paste, an undo, a recomputed total —
    // is adopted, but never while the user is typing into this cell.
    if (!_focus.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
      _error = null;
    }
  }

  @override
  void dispose() {
    widget.onUnregister(_focus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focus.hasFocus) {
      widget.onFocused();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    } else {
      _commit();
    }
  }

  /// Writes the cell through, unless it cannot be read.
  ///
  /// An unreadable cell keeps its text and its error rather than snapping back
  /// to the stored value: the user typed something, and hiding it leaves them
  /// with no idea what was rejected.
  void _commit() {
    final raw = _controller.text;
    if (raw == widget.value) return;
    if (widget.error(raw) != null) return;
    widget.onCommit(raw);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Focus(
        // Handled here rather than through the traversal policy: inside a text
        // field the arrow keys belong to the caret, so Enter moves down and Tab
        // moves across — the two a spreadsheet user already presses.
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final shift = HardwareKeyboard.instance.isShiftPressed;
          switch (event.logicalKey) {
            case LogicalKeyboardKey.enter:
            case LogicalKeyboardKey.numpadEnter:
              _commit();
              widget.onMove(shift ? -1 : 1, 0);
              return KeyEventResult.handled;
            case LogicalKeyboardKey.tab:
              _commit();
              widget.onMove(0, shift ? -1 : 1);
              return KeyEventResult.handled;
            case LogicalKeyboardKey.escape:
              _controller.text = widget.value;
              setState(() => _error = null);
              return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          enabled: !widget.spec.readOnly,
          textAlign: widget.spec.numeric ? TextAlign.end : TextAlign.start,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            border: const OutlineInputBorder(),
            errorText: null,
            errorStyle: const TextStyle(height: 0),
            enabledBorder: error == null
                ? null
                : OutlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.error),
                  ),
            focusedBorder: error == null
                ? null
                : OutlineInputBorder(
                    borderSide: BorderSide(
                      color: theme.colorScheme.error,
                      width: 2,
                    ),
                  ),
          ),
          onChanged: (raw) {
            final next = widget.error(raw);
            if (next != _error) setState(() => _error = next);
          },
        ),
      ),
    );
  }
}

/// Splits a clipboard payload from Excel into rows and cells.
///
/// Tab-separated, newline-delimited, with the trailing newline Excel appends to
/// a copied block dropped. Quoted cells containing tabs are **not** unwrapped:
/// nothing in a demand table — a part number, a time, a date — can contain one,
/// and a quote-aware parser would be code with no case to answer.
List<List<String>> parseTsv(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return [
    for (final line in lines) line.split('\t'),
  ];
}
