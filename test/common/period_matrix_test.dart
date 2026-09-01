import 'package:flowmap/src/common/horizontal_scroll.dart';
import 'package:flowmap/src/common/period_matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shared period matrix (#10, #16).
///
/// **The two claims here are the ones that went wrong by being written down and
/// not asserted.** This file's own library comment has said *"with a frozen
/// first column"* since #10 while every column sat inside one scroll, and the
/// row height was a constant chosen for one caller and left wrong for the
/// other. Both are now properties rather than prose.
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 900, height: 600, child: child)),
  );

  PeriodMatrixCell cell(String text) => PeriodMatrixCell(
    text: text,
    background: const Color(0xFFEEEEEE),
    foreground: const Color(0xFF000000),
  );

  final months = [DateTime(2026), DateTime(2026, 2), DateTime(2026, 3)];

  Widget matrix({required List<PeriodMatrixRow> rows, double? monthWidth}) =>
      host(
        PeriodMatrix(
          months: months,
          headerLabel: 'WORKCENTER',
          rows: rows,
          monthWidth: monthWidth ?? PeriodMatrix.defaultMonthWidth,
          cellAt: (row, month) => cell('${row}x$month'),
        ),
      );

  /// The height of the box holding a row's label, which is what the reader sees
  /// as the row.
  double heightOfRowCarrying(WidgetTester tester, String label) {
    final box = find
        .ancestor(of: find.text(label), matching: find.byType(Container))
        .first;
    return tester.getSize(box).height;
  }

  group('the matrix measures its own row height (#16)', () {
    testWidgets('a row carrying a qualifier gets the taller row', (
      tester,
    ) async {
      // The Occupation grid: a line over the cell it sits in. The field
      // reported these cramped, and the fix is not a constant — it is the
      // widget noticing there is a second line to make room for.
      await tester.pumpWidget(
        matrix(
          rows: const [
            PeriodMatrixRow(label: 'Fluxo 11B', qualifier: 'Célula 11'),
            PeriodMatrixRow(label: 'Fluxo 11C', qualifier: 'Célula 11'),
          ],
        ),
      );

      expect(heightOfRowCarrying(tester, 'Fluxo 11B'), 60);
    });

    testWidgets('rows with nothing to qualify stay compact', (tester) async {
      // The float matrix: a bare rank. It was fine at 34 and the shared
      // constant of 48 was already costing it — 60 would have cost four ranks
      // a screen for a complaint that was never about this surface.
      await tester.pumpWidget(
        matrix(
          rows: const [
            PeriodMatrixRow(label: '1'),
            PeriodMatrixRow(label: '2'),
          ],
        ),
      );

      expect(heightOfRowCarrying(tester, '1'), 40);
    });

    testWidgets('one qualified row is enough to raise every row', (
      tester,
    ) async {
      // Ragged heights would break the alignment the frozen column depends on:
      // the gutter and the body are two separate Columns, and they line up only
      // because every row in both is the same height.
      await tester.pumpWidget(
        matrix(
          rows: const [
            PeriodMatrixRow(label: 'CEU27'),
            PeriodMatrixRow(label: 'CLAD07', qualifier: 'CLAD Pool'),
          ],
        ),
      );

      expect(heightOfRowCarrying(tester, 'CEU27'), 60);
      expect(heightOfRowCarrying(tester, 'CLAD07'), 60);
    });
  });

  group('the frozen column is real (#16)', () {
    testWidgets('there is exactly one horizontal scroller', (tester) async {
      // **The claim this file made and did not keep.** Everything used to sit
      // in one `DataTable` in one scroll, so the labels slid away with the
      // data — and #16 needed the gutter pinned for the chart's axis anyway.
      // Two would also mean two scrollbars, which is §12.6's recorded fault.
      await tester.pumpWidget(
        matrix(
          rows: const [PeriodMatrixRow(label: 'CEU27', qualifier: 'Pool')],
        ),
      );

      expect(find.byType(HorizontalScroll), findsOneWidget);
    });

    testWidgets('the row label is outside the scroller, the cells inside', (
      tester,
    ) async {
      await tester.pumpWidget(
        matrix(rows: const [PeriodMatrixRow(label: 'CEU27')]),
      );

      expect(
        find.descendant(
          of: find.byType(HorizontalScroll),
          matching: find.text('CEU27'),
        ),
        findsNothing,
        reason: 'the frozen label must not scroll with the months',
      );
      expect(
        find.descendant(
          of: find.byType(HorizontalScroll),
          matching: find.text('Jan/26'),
        ),
        findsOneWidget,
      );
    });
  });

  group('a month column is one declared width (#16)', () {
    testWidgets('every month column is the same, whatever the cell says', (
      tester,
    ) async {
      // The chart's bars are laid out to `months.length * monthWidth` and drawn
      // above these columns. A column that sized itself to its content would
      // move the moment the unit switch turned `81%` into `733/499`, and take
      // the bars out of alignment with the cells they describe.
      await tester.pumpWidget(
        host(
          PeriodMatrix(
            months: months,
            headerLabel: 'LINE',
            rows: const [PeriodMatrixRow(label: 'Fluxo 11B')],
            cellAt: (row, month) =>
                cell(month == 0 ? '9%' : '7331/4992 wider'),
          ),
        ),
      );

      final widths = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((box) => box.width == PeriodMatrix.defaultMonthWidth)
          .length;

      // Three headings and three cells, at the one declared width.
      expect(widths, greaterThanOrEqualTo(6));
    });
  });
}
