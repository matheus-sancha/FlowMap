import 'package:flowmap/src/common/data_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseTsv', () {
    test('splits a block the way Excel copies it', () {
      expect(parseTsv('PN1\t55:00:00\nPN2\t8:00:00'), [
        ['PN1', '55:00:00'],
        ['PN2', '8:00:00'],
      ]);
    });

    test('drops the trailing newline Excel appends', () {
      expect(parseTsv('PN1\t55\r\nPN2\t8\r\n'), [
        ['PN1', '55'],
        ['PN2', '8'],
      ]);
    });

    test('keeps empty cells, which are how a skipped step is pasted', () {
      // A blank in the middle of a row means "this part does not visit that
      // step" (§5.1), so it must survive as a cell rather than collapse.
      expect(parseTsv('PN1\t\t8'), [
        ['PN1', '', '8'],
      ]);
    });

    test('a plain value is a one-cell block', () {
      expect(parseTsv('55:00:00'), [
        ['55:00:00'],
      ]);
    });
  });

  group('DataGrid', () {
    /// Mounts a two-column grid over a mutable model, as the demand tab does.
    Future<List<String>> pump(
      WidgetTester tester, {
      required List<List<String>> model,
      String? Function(int row, int column, String raw)? errorAt,
    }) async {
      final commits = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DataGrid(
              columns: const [
                DataGridColumn(title: 'Part'),
                DataGridColumn(title: 'CLAD04'),
              ],
              rowCount: model.length,
              valueAt: (row, column) => model[row][column],
              errorAt: errorAt,
              onCommit: (row, column, block) {
                commits.add('$row:$column:${block.map((r) => r.join(",")).join("|")}');
                for (var r = 0; r < block.length; r++) {
                  for (var c = 0; c < block[r].length; c++) {
                    if (row + r >= model.length) continue;
                    if (column + c >= 2) continue;
                    model[row + r][column + c] = block[r][c];
                  }
                }
              },
            ),
          ),
        ),
      );
      return commits;
    }

    testWidgets('an edited cell commits when focus leaves it', (tester) async {
      final model = [
        ['PN1', '55:00:00'],
        ['PN2', '8:00:00'],
      ];
      final commits = await pump(tester, model: model);

      await tester.enterText(find.byType(TextField).at(1), '60:00:00');
      // Tab commits and moves on, the way a spreadsheet does.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.tap(find.byType(TextField).at(3));
      await tester.pumpAndSettle();

      expect(commits, contains('0:1:60:00:00'));
      expect(model[0][1], '60:00:00');
    });

    testWidgets('a cell that cannot be read is not written through', (
      tester,
    ) async {
      final model = [
        ['PN1', '55:00:00'],
      ];
      final commits = await pump(
        tester,
        model: model,
        errorAt: (row, column, raw) =>
            column == 1 && raw == 'n/a' ? 'Not a time' : null,
      );

      await tester.enterText(find.byType(TextField).at(1), 'n/a');
      await tester.pumpAndSettle();
      // The typed text stays on screen — the user has to be able to see what
      // was rejected — but nothing reaches the model.
      expect(find.text('n/a'), findsOneWidget);
      expect(commits, isEmpty);
      expect(model[0][1], '55:00:00');
    });

    testWidgets('escape puts back what was there', (tester) async {
      final model = [
        ['PN1', '55:00:00'],
      ];
      final commits = await pump(tester, model: model);

      await tester.enterText(find.byType(TextField).at(1), '60:00:00');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(commits, isEmpty);
      expect(model[0][1], '55:00:00');
    });
  });

  group('DataGrid with a frozen column', () {
    // Wide enough that the scrolling pane genuinely overflows a laptop window,
    // which is the case the freezing exists for.
    const columns = 8;
    const rows = 40;

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: DataGrid(
                frozenColumns: 1,
                rowHeaderWidth: 44,
                rowHeader: (row) => Text('#$row'),
                // Not decoration. The frozen pane carries the row header and
                // this one the actions, and an IconButton is taller than a
                // cell — which is exactly how the two panes came to drift.
                rowActions: (row) => const IconButton(
                  onPressed: null,
                  icon: Icon(Icons.delete_outline, size: 18),
                ),
                columns: [
                  const DataGridColumn(title: 'Part', width: 150),
                  for (var i = 1; i < columns; i++)
                    const DataGridColumn(title: 'WC', width: 132),
                ],
                rowCount: rows,
                valueAt: (row, column) => 'v$row-$column',
                onCommit: (row, column, block) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a row is one row across both panes', (tester) async {
      await pump(tester);

      // Every row, not just the first: the drift this catches was four pixels
      // per row and invisible until several rows down.
      for (final row in [0, 1, 2, 3, 4, 5]) {
        expect(
          tester.getRect(find.text('v$row-0')).top,
          moreOrLessEquals(
            tester.getRect(find.text('v$row-1')).top,
            epsilon: 0.5,
          ),
          reason: 'row $row: the frozen pane and the scrolling pane hold '
              'different widgets, so the row height has to be declared rather '
              'than measured',
        );
      }
    });

    // Row 5 rather than row 0 throughout: a hundred pixels is two rows, and a
    // ListView disposes what it has scrolled past — so row 0 stops existing
    // and the finder measures nothing rather than measuring a failure.
    testWidgets('the part number holds still while the rest scrolls', (
      tester,
    ) async {
      await pump(tester);

      final frozenBefore = tester.getRect(find.text('v5-0')).left;
      final scrollingBefore = tester.getRect(find.text('v5-1')).left;

      // Dragged by the heading, not by a cell: every cell is a TextField and a
      // horizontal drag inside one belongs to the caret. Which is also why the
      // bar matters — there is no drag-the-content escape hatch here.
      await tester.drag(find.text('WC').first, const Offset(-120, 0));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.text('v5-0')).left,
        frozenBefore,
        reason: 'the frozen pane must sit outside the horizontal scroll view',
      );
      expect(
        tester.getRect(find.text('v5-1')).left,
        lessThan(scrollingBefore - 1),
      );
    });

    testWidgets('the two panes scroll down together', (tester) async {
      await pump(tester);

      final before = tester.getRect(find.text('v5-1')).top;

      // Driven from the scrolling pane; the frozen one has to follow, or the
      // part number would end up beside the wrong row's times — which is worse
      // than not freezing it at all.
      await tester.drag(find.text('v5-1'), const Offset(0, -100));
      await tester.pumpAndSettle();

      final frozenAfter = tester.getRect(find.text('v5-0')).top;
      final scrollingAfter = tester.getRect(find.text('v5-1')).top;

      expect(scrollingAfter, lessThan(before - 1));
      expect(frozenAfter, moreOrLessEquals(scrollingAfter, epsilon: 0.5));
    });

    testWidgets('dragging the frozen pane brings the other with it', (
      tester,
    ) async {
      await pump(tester);

      final before = tester.getRect(find.text('v5-1')).top;

      await tester.drag(find.text('v5-0'), const Offset(0, -100));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.text('v5-1')).top,
        lessThan(before - 1),
        reason: 'the wheel has to work over either pane, so the follow is '
            'both ways — and both ways is what can loop',
      );
      expect(
        tester.getRect(find.text('v5-0')).top,
        moreOrLessEquals(tester.getRect(find.text('v5-1')).top, epsilon: 0.5),
      );
    });

    testWidgets('tab crosses the seam between the panes', (tester) async {
      await pump(tester);

      // The frozen cell is in one list and its neighbour in another, but a
      // focus node is keyed by absolute column, so the move does not know.
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final focused = tester.widgetList<TextField>(find.byType(TextField)).where(
        (field) => field.focusNode?.hasFocus ?? false,
      );
      expect(focused, hasLength(1));
      expect(focused.first.controller?.text, 'v0-1');
    });
  });
}
