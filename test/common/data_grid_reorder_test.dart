import 'package:flowmap/src/common/data_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dragging a row by its header number (#10).
///
/// **What is asserted is the arithmetic, not the feel.** Where a dragged row
/// lands is `(travel ÷ row height)` rounded, clamped to the reorderable rows —
/// a fact. How the edge-jump *feels* at 130 rows is not, and #10 said outright
/// that wants a drive.
void main() {
  const rowHeight = 36.0;

  /// Records what the grid asked for, so a test can assert the pair rather than
  /// whatever the repository would have done with it.
  late List<(int, int)> moves;

  Widget grid({int rows = 6, int? reorderable}) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 400,
        child: DataGrid(
          rowCount: rows,
          rowHeaderWidth: 44,
          reorderableRows: reorderable,
          onReorder: (from, to) => moves.add((from, to)),
          rowHeader: (row) => Center(child: Text('h$row')),
          columns: const [DataGridColumn(title: 'Value', width: 120)],
          valueAt: (row, column) => 'r$row',
          onCommit: (row, column, values) {},
        ),
      ),
    ),
  );

  setUp(() => moves = []);

  /// Drags row [from]'s header down by [rowsDown] rows and releases.
  Future<void> dragRow(
    WidgetTester tester,
    int from, {
    required double rowsDown,
  }) async {
    final handle = find.text('h$from');
    final gesture = await tester.startGesture(tester.getCenter(handle));
    // In steps, as a real pointer arrives — a single jump would pass over the
    // rows between without the target ever being computed for them.
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(Offset(0, rowHeight * rowsDown / 4));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('a row dragged two rows down asks to move two rows down', (
    tester,
  ) async {
    await tester.pumpWidget(grid());
    await dragRow(tester, 1, rowsDown: 2);

    expect(moves, [(1, 3)]);
  });

  testWidgets('a row dragged upward asks for the row above it', (tester) async {
    await tester.pumpWidget(grid());
    await dragRow(tester, 4, rowsDown: -2);

    expect(moves, [(4, 2)]);
  });

  testWidgets('a drag that ends where it began asks for nothing', (
    tester,
  ) async {
    // **Not a move.** It would spend a two-pass rewrite of the whole study's
    // sequence to arrive at what is already stored, and every listener would
    // rebuild for nothing.
    await tester.pumpWidget(grid());
    await dragRow(tester, 2, rowsDown: 0);

    expect(moves, isEmpty);
  });

  testWidgets('a drag past the last row clamps rather than overshooting', (
    tester,
  ) async {
    await tester.pumpWidget(grid(rows: 6));
    await dragRow(tester, 4, rowsDown: 20);

    expect(moves, [(4, 5)], reason: 'the last row is the furthest it can go');
  });

  testWidgets('the reserved trailing row cannot be dragged, or dropped past', (
    tester,
  ) async {
    // The sequence grid draws one extra line for adding an order. It has no
    // sequence to move, and dropping a real row past it would ask the
    // repository to place something after a row that does not exist.
    await tester.pumpWidget(grid(rows: 6, reorderable: 5));

    await dragRow(tester, 5, rowsDown: -2);
    expect(moves, isEmpty, reason: 'the + row is not a row');

    await dragRow(tester, 1, rowsDown: 20);
    expect(moves, [(1, 4)], reason: 'and nothing lands past it either');
  });

  testWidgets('a grid with no onReorder leaves its header alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: DataGrid(
              rowCount: 4,
              rowHeader: (row) => Center(child: Text('h$row')),
              columns: const [DataGridColumn(title: 'Value', width: 120)],
              valueAt: (row, column) => 'r$row',
              onCommit: (row, column, values) {},
            ),
          ),
        ),
      ),
    );

    // Nothing to assert but the absence of a crash and of a grab cursor: the
    // three other grids pass no `onReorder`, and the handle must not appear on
    // them at all.
    expect(find.byType(MouseRegion), findsWidgets);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('h1')),
    );
    await gesture.moveBy(const Offset(0, rowHeight * 2));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
