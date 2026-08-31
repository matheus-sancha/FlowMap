/// The editable grid the demand tables are entered in (DESIGN.md §9).
///
/// One text field per cell, keyboard navigation, and multi-cell TSV paste from
/// Excel. Every column is text, deliberately: a dropdown or a date picker in a
/// column would make that column unpasteable, and pasting a block out of the
/// planner's spreadsheet is the way this data actually arrives. What a cell
/// means is decided by the parser the caller supplies, and anything unparseable
/// stays on screen as an error rather than being dropped.
library;

import 'dart:async';

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

  /// Marks the column as holding a number.
  ///
  /// **Nothing reads it as of 2026-08-29.** It right-aligned the cell, and the
  /// heading above it, until §8.3's drive centred both — so this is now set at
  /// twelve call sites and consulted at none. Kept rather than deleted because
  /// what each caller meant by it is real information about the column, and a
  /// paste that wanted to know whether a cell should parse as a number would
  /// ask exactly this. **Listed in §10 so it is removed or used rather than
  /// quietly inherited.**
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
    this.onReorder,
    this.reorderableRows,
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

  /// Move the row at `from` so it sits at `to`, or null for a grid whose order
  /// is not the reader's to change (#10).
  ///
  /// **Optional, and exactly one caller passes it.** Reordering is a property
  /// of *one* table rather than of any ordered grid, and the database is what
  /// says so: `demand_orders` carries a `sequence` column and nothing else
  /// does. `demand_parts` has none — its row number is a display index — and
  /// takt and schedule periods are ordered by date. So this is not a capability
  /// every grid grew; it is one table's behaviour, offered here because the
  /// drag has to live where the rows are.
  ///
  /// The data layer needed nothing: `moveOrder(studyId, from, to)` already does
  /// an arbitrary insert with a two-pass rewrite to dodge the unique-per-study
  /// collision.
  final void Function(int from, int to)? onReorder;

  /// How many rows from the top may be dragged, or null for all of them.
  ///
  /// **The trailing `+` row is not a row.** The sequence grid draws one extra
  /// line for adding an order, which has no sequence number and nothing to
  /// reorder — dragging it, or dropping another row past it, would ask the
  /// repository to move something that does not exist.
  final int? reorderableRows;

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

  /// How tall this grid would be if nothing bounded it: the heading, the rule
  /// under it, [rowCount] rows at their fixed extent, and the gutter the
  /// horizontal scrollbar sits in.
  ///
  /// **Exact rather than an estimate**, because the rows are declared at a
  /// fixed `itemExtent` — the same declaration that keeps the frozen and
  /// scrolling panes' scroll extents identical.
  ///
  /// Public because a caller that bounds the grid is the only one that can
  /// tell when its bound is doing nothing. A card pinned to 320 px around two
  /// periods is 180 px of blank (§8.2), and the grid cannot know that: it is
  /// hand a height and fills it. So the policy — grow to the content, stop at
  /// a ceiling — belongs with whoever owns the ceiling.
  static double heightFor(int rowCount) =>
      _DataGridState._headerHeight +
      1 +
      rowCount * _DataGridState._rowHeight +
      _DataGridState._barGutter;
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

  /// The row being dragged by its header, and where it would land (#10).
  ///
  /// **Both panes read this**, so the insertion line is drawn across the whole
  /// grid rather than only over the frozen columns the handle lives in.
  int? _dragFrom;
  int? _dragTo;

  /// Where the drag began, in scroll offset and in pointer travel.
  ///
  /// **Two numbers, because the list moves under the pointer.** Edge
  /// auto-scroll changes the offset without the pointer moving at all, and a
  /// target computed from pointer travel alone would ignore every row that
  /// passed by underneath. The displacement is the sum of the two.
  double _dragStartOffset = 0;
  double _dragDy = 0;

  /// Runs while the pointer sits in an edge zone.
  ///
  /// **A timer rather than a scroll per drag event.** Dragging order 130 to
  /// position 3 crosses 127 rows, which is the case #10 named as the one drag
  /// is worst at — and scrolling only when the pointer *moves* makes the reader
  /// jiggle it to keep going. This scrolls while it is held still.
  Timer? _autoScroll;

  /// How many rows the reader may drag, which is [DataGrid.rowCount] unless the
  /// caller reserved trailing rows.
  int get _reorderable => widget.reorderableRows ?? widget.rowCount;

  bool get _frozen => widget.frozenColumns > 0;

  @override
  void initState() {
    super.initState();
    _frozenRows.addListener(() => _follow(_frozenRows, _scrollingRows));
    _scrollingRows.addListener(() => _follow(_scrollingRows, _frozenRows));
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
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
                // **Headings centre, and so do the cells under them**
                // (§8.3). The first pass moved only the headings; the drive
                // asked for the values too, and a column that agrees with
                // itself is what it now is.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
  }) {
    final theme = Theme.of(context);
    // **The insertion line, drawn on every pane** (#10). The handle is in the
    // frozen columns, but a line only over those would say where the row lands
    // for two columns out of fourteen.
    final to_ = _dragTo;
    final showsLine = to_ != null && _dragFrom != null && to_ == row;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showsLine
            ? Border(top: BorderSide(color: theme.colorScheme.primary, width: 2))
            : null,
        // The row being carried is dimmed where it came from, so the grid says
        // what is moving as well as where it would go.
        color: _dragFrom == row
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : null,
      ),
      child: Row(
        key: ValueKey('row-$row-$from'),
        children: [
          if (leading && widget.rowHeader != null)
            SizedBox(
              width: widget.rowHeaderWidth,
              child: _reorderHandle(row, child: widget.rowHeader!(row)),
            ),
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
            SizedBox(
              width: widget.rowActionsWidth,
              child: widget.rowActions!(row),
            ),
        ],
      ),
    );
  }

  /// The row-header number, made a drag handle (#10).
  ///
  /// **The handle is the header and nothing else.** It is already a frozen
  /// 44 pt slot showing the position, so making it the grab point leaves every
  /// cell undraggable — which is what keeps text selection inside a cell
  /// working. A grid with no `onReorder`, or a row past [_reorderable], gets
  /// the number back unchanged.
  Widget _reorderHandle(int row, {required Widget child}) {
    if (widget.onReorder == null || row >= _reorderable) return child;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => setState(() {
          _dragFrom = row;
          _dragTo = row;
          _dragDy = 0;
          _dragStartOffset = _scrollingRows.hasClients
              ? _scrollingRows.offset
              : 0;
        }),
        onVerticalDragUpdate: (details) {
          _dragDy += details.delta.dy;
          _autoScrollFor(details.globalPosition.dy);
          _updateDropTarget();
        },
        onVerticalDragEnd: (_) => _endDrag(commit: true),
        onVerticalDragCancel: () => _endDrag(commit: false),
        child: child,
      ),
    );
  }

  /// Where the carried row would land, from pointer travel **plus** whatever
  /// the list scrolled underneath it.
  void _updateDropTarget() {
    final from = _dragFrom;
    if (from == null) return;
    final scrolled = _scrollingRows.hasClients
        ? _scrollingRows.offset - _dragStartOffset
        : 0.0;
    final moved = ((_dragDy + scrolled) / _rowHeight).round();
    final target = (from + moved).clamp(0, _reorderable - 1);
    if (target != _dragTo) setState(() => _dragTo = target);
  }

  /// Scrolls while the pointer is held in the top or bottom band.
  ///
  /// Restarted rather than accumulated: each update either sets the direction
  /// or cancels, so leaving the band stops the scroll on the next event rather
  /// than at the end of the drag.
  void _autoScrollFor(double globalDy) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !_scrollingRows.hasClients) return;
    final local = box.globalToLocal(Offset(0, globalDy)).dy;
    final height = box.size.height;
    const band = 48.0;

    final direction = local < band
        ? -1
        : local > height - band
        ? 1
        : 0;
    if (direction == 0) {
      _autoScroll?.cancel();
      _autoScroll = null;
      return;
    }
    if (_autoScroll != null) return;
    _autoScroll = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scrollingRows.hasClients) return;
      final position = _scrollingRows.position;
      final next = (position.pixels + direction * 8).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next == position.pixels) return;
      _scrollingRows.jumpTo(next);
      _updateDropTarget();
    });
  }

  void _endDrag({required bool commit}) {
    _autoScroll?.cancel();
    _autoScroll = null;
    final from = _dragFrom;
    final to = _dragTo;
    setState(() {
      _dragFrom = null;
      _dragTo = null;
    });
    // **A move to where it already is is not a move.** It would spend a
    // two-pass rewrite of the whole study's sequence to arrive at what is
    // already stored, and every listener would rebuild for nothing.
    if (!commit || from == null || to == null || from == to) return;
    widget.onReorder!(from, to);
  }
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
  /// Whether Left has no caret left to move, and so should leave the cell.
  ///
  /// **A range selection is never at an edge**, in either direction: Left with
  /// `1250` selected collapses the selection the way every text field does, and
  /// a cell that jumped away instead would make selecting a value the one thing
  /// you cannot then arrow out of.
  ///
  /// An offset of -1 is a field that has focus but has never placed a caret —
  /// which is exactly the freshly-arrived-at cell — and that counts as both
  /// edges, so arrowing across an untouched row does not stall on every cell.
  bool get _caretAtStart {
    final selection = _controller.selection;
    if (!selection.isCollapsed) return false;
    return selection.baseOffset <= 0;
  }

  bool get _caretAtEnd {
    final selection = _controller.selection;
    if (!selection.isCollapsed) return false;
    final offset = selection.baseOffset;
    return offset < 0 || offset >= _controller.text.length;
  }

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
        //
        // **The arrows now move too, but only once the caret cannot** (#10).
        // The rule above is still true and is what shapes this: Left in the
        // middle of `1250` moves the caret and Left again at offset 0 moves to
        // the previous cell, so nothing is taken away from editing and there is
        // no mode to be in. Up and Down have no caret to move in a single-line
        // field, so they always change row.
        //
        // *Rejected: the true spreadsheet model* — arrows always move, typing
        // or F2 enters an edit mode. It is what Excel does and this data arrives
        // by pasting out of Excel, but it means cells stop being always-live
        // fields and the grid grows a selected-versus-editing state to show.
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
            case LogicalKeyboardKey.arrowUp:
              _commit();
              widget.onMove(-1, 0);
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowDown:
              _commit();
              widget.onMove(1, 0);
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowLeft:
              if (!_caretAtStart) return KeyEventResult.ignored;
              _commit();
              widget.onMove(0, -1);
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowRight:
              if (!_caretAtEnd) return KeyEventResult.ignored;
              _commit();
              widget.onMove(0, 1);
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
          // **Centred, like the heading over it** (§8.3, revised on the
          // 2026-08-29 drive). The first pass centred only the headings and
          // kept `end` for numeric cells, on the argument that a right edge is
          // what lets a column of percentages be scanned. Driven, the split
          // read as a misalignment rather than as a convention — a centred
          // heading over a right-aligned value looks like a mistake in a grid
          // whose columns are narrow and whose values are short. The field
          // asked for both, and driving beats reasoning (§2.0).
          textAlign: TextAlign.center,
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
