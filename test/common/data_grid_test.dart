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
}
