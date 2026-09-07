import 'package:flowmap/src/common/horizontal_scroll.dart';
import 'package:flowmap/src/common/period_granularity.dart';
import 'package:flowmap/src/common/period_matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// The shared period matrix (#10, #16).
///
/// **The two claims here are the ones that went wrong by being written down and
/// not asserted.** This file's own library comment has said *"with a frozen
/// first column"* since #10 while every column sat inside one scroll, and the
/// row height was a constant chosen for one caller and left wrong for the
/// other. Both are now properties rather than prose.
void main() {
  Widget host(Widget child, {double width = 900}) => MaterialApp(
    home: Scaffold(
      body: SizedBox(width: width, height: 600, child: child),
    ),
  );

  PeriodMatrixCell cell(String text) => PeriodMatrixCell(
    text: text,
    background: const Color(0xFFEEEEEE),
    foreground: const Color(0xFF000000),
  );

  final months = [DateTime(2026), DateTime(2026, 2), DateTime(2026, 3)];

  Widget matrix({
    required List<PeriodMatrixRow> rows,
    double? monthWidth,
    double width = 900,
    String? trailingLabel,
  }) => host(
    PeriodMatrix(
      months: months,
      headerLabel: 'WORKCENTER',
      rows: rows,
      monthWidth: monthWidth ?? PeriodMatrix.defaultMonthWidth,
      cellAt: (row, month) => cell('${row}x$month'),
      trailingLabel: trailingLabel,
      trailingCellAt: trailingLabel == null ? null : (row) => cell('t$row'),
    ),
    width: width,
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
    // 150 pt of gutter and three 72 pt months need 366; a 300 pt pane cannot
    // hold them, which is the only state in which this matrix scrolls at all.
    const narrow = 300.0;

    testWidgets('there is exactly one horizontal scroller', (tester) async {
      // **The claim this file made and did not keep.** Everything used to sit
      // in one `DataTable` in one scroll, so the labels slid away with the
      // data — and #16 needed the gutter pinned for the chart's axis anyway.
      // Two would also mean two scrollbars, which is §12.6's recorded fault.
      await tester.pumpWidget(
        matrix(
          rows: const [PeriodMatrixRow(label: 'CEU27', qualifier: 'Pool')],
          width: narrow,
        ),
      );

      expect(find.byType(HorizontalScroll), findsOneWidget);
    });

    testWidgets('the row label is outside the scroller, the cells inside', (
      tester,
    ) async {
      await tester.pumpWidget(
        matrix(
          rows: const [PeriodMatrixRow(label: 'CEU27')],
          width: narrow,
        ),
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
            cellAt: (row, month) => cell(month == 0 ? '9%' : '7331/4992 wider'),
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

  group('the matrix only scrolls when it must (#14)', () {
    testWidgets('a matrix that fits carries no scroller at all', (
      tester,
    ) async {
      // A scrollbar under content that cannot move says the table is cut off
      // when it is not.
      await tester.pumpWidget(
        matrix(rows: const [PeriodMatrixRow(label: 'CEU27')]),
      );

      expect(find.byType(HorizontalScroll), findsNothing);
    });

    testWidgets('the trailing column sits next to the months, not the window', (
      tester,
    ) async {
      // **The gap the field reported**: *"the distance between the column and
      // the grid"*. The body was `Expanded` unconditionally, so it took every
      // spare pixel and drove the frozen TOTAL column against the right edge —
      // on a 1,920 pt window with fifteen months, roughly 700 pt of dead space
      // between the last month and the summary of it.
      //
      // 150 gutter + three 72 pt months = 366, so TOTAL must start there and
      // not at 900 - 84.
      await tester.pumpWidget(
        matrix(
          rows: const [PeriodMatrixRow(label: 'CEU27')],
          trailingLabel: 'TOTAL',
        ),
      );

      expect(tester.getTopLeft(find.text('TOTAL')).dx, lessThan(460));
    });

    testWidgets('a matrix too wide to fit still pins its trailing column', (
      tester,
    ) async {
      // The other half of the rule: once the months overflow, the summary has
      // to stay put or it becomes the one column a reader must hunt for.
      await tester.pumpWidget(
        matrix(
          rows: const [PeriodMatrixRow(label: 'CEU27')],
          trailingLabel: 'TOTAL',
          width: 300,
        ),
      );

      expect(find.byType(HorizontalScroll), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HorizontalScroll),
          matching: find.text('TOTAL'),
        ),
        findsNothing,
        reason: 'the summary must not scroll away with the months',
      );
    });
  });

  group('a cell can carry two figures (#14)', () {
    testWidgets('demand sits above capacity, and both are drawn', (
      tester,
    ) async {
      // **Not `733/499`.** That put two measurements behind the punctuation of
      // a single number and left the reader to work out which way round it was.
      await tester.pumpWidget(
        host(
          PeriodMatrix(
            months: months,
            headerLabel: 'LINE',
            rows: const [PeriodMatrixRow(label: 'Fluxo 11B')],
            cellAt: (row, month) => const PeriodMatrixCell(
              text: '733',
              subtext: '499',
              background: Color(0xFFEEEEEE),
              foreground: Color(0xFF000000),
            ),
          ),
        ),
      );

      expect(find.text('733'), findsNWidgets(3));
      expect(find.text('499'), findsNWidgets(3));

      // Demand above capacity, not beside or below it.
      expect(
        tester.getTopLeft(find.text('733').first).dy,
        lessThan(tester.getTopLeft(find.text('499').first).dy),
      );
    });

    testWidgets('a stacked cell forces the taller row, with no qualifier', (
      tester,
    ) async {
      // The matrix measures itself on the row header, and a two-line *cell* is
      // the other thing that needs the height. Per workcenter, a plant whose
      // stations are all outside a pool has no qualifier anywhere — so without
      // this the Hours unit would overflow every row.
      await tester.pumpWidget(
        host(
          PeriodMatrix(
            months: months,
            headerLabel: 'STATION',
            rows: const [PeriodMatrixRow(label: 'CEU27')],
            cellAt: (row, month) => const PeriodMatrixCell(
              text: '733',
              subtext: '499',
              background: Color(0xFFEEEEEE),
              foreground: Color(0xFF000000),
            ),
          ),
        ),
      );

      expect(heightOfRowCarrying(tester, 'CEU27'), 60);
    });
  });

  group('a row label gets the room it needs (#14)', () {
    /// The width the label actually paints at, against the width it wants.
    ///
    /// **Compared to an unconstrained render of the same string**, rather than
    /// to a number: the test font's metrics are not the shipping font's, and a
    /// hard-coded pixel count would pass here and clip on a real machine.
    Future<(double drawn, double natural)> widths(
      WidgetTester tester,
      String label,
      double headerWidth,
    ) async {
      double measure(double width) => tester.getSize(find.text(label)).width;

      Widget at(double w) => host(
        PeriodMatrix(
          months: months,
          headerLabel: '#',
          headerWidth: w,
          rows: const [PeriodMatrixRow(label: '1')],
          cellAt: (row, month) => cell('x'),
          aggregate: PeriodMatrixRow(label: label, emphasis: true),
          aggregateCellAt: (month) => cell('y'),
        ),
        width: 1200,
      );

      await tester.pumpWidget(at(headerWidth));
      final drawn = measure(headerWidth);
      await tester.pumpWidget(at(400));
      final natural = measure(400);
      return (drawn, natural);
    }

    for (final label in const ['AVG', 'PROM', 'MÉD']) {
      testWidgets('the float matrix fits its aggregate label: $label', (
        tester,
      ) async {
        // **The float matrix's gutter was 40**, chosen when every row header in
        // it was a rank. #14 put a word in that column and the widest of the
        // three locales did not fit, so the label ellipsised to nothing useful.
        final (drawn, natural) = await widths(tester, label, 72);

        expect(drawn, natural, reason: '$label is clipped at a 72 pt gutter');
      });
    }

    testWidgets('and 40 would not have been enough, which is why it moved', (
      tester,
    ) async {
      // Recorded so the constant cannot quietly go back.
      final (drawn, natural) = await widths(tester, 'PROM', 40);

      expect(drawn, lessThan(natural));
    });
  });

  group('a column is as wide as the heading its grain writes', () {
    // The field reported `Q4 2...`. What can be asserted here is the *rule* —
    // the pixel fit is a visual question and this map settles those by driving
    // the app, which is where the number came from.

    test('a quarter and a semester get more room than a month', () {
      // `Q4 2026` is a character wider than `Aug 2026` has left over once the
      // sort-arrow slot is reserved.
      expect(
        PeriodMatrix.widthFor(PeriodGranularity.quarter),
        greaterThan(PeriodMatrix.widthFor(PeriodGranularity.month)),
      );
      expect(
        PeriodMatrix.widthFor(PeriodGranularity.semester),
        PeriodMatrix.widthFor(PeriodGranularity.quarter),
      );
    });

    test('a month and a year keep the width the cells were sized for', () {
      // Not a widening of everything: `733/499` still needs 72 and `2026` fits
      // it, so the two grains that were never broken do not move.
      expect(
        PeriodMatrix.widthFor(PeriodGranularity.month),
        PeriodMatrix.defaultMonthWidth,
      );
      expect(
        PeriodMatrix.widthFor(PeriodGranularity.year),
        PeriodMatrix.defaultMonthWidth,
      );
    });

    testWidgets('the matrix lays its columns out to the width it is given', (
      tester,
    ) async {
      // The half that matters for #16: whatever the width is, the grid uses it
      // — so the chart handed the same number sits over its own cells.
      const width = 96.0;
      await tester.pumpWidget(
        matrix(rows: const [PeriodMatrixRow(label: 'CEU27')], monthWidth: width),
      );

      final heading = find
          .ancestor(
            of: find.text(DateFormat('MMM/yy').format(months.first)),
            matching: find.byType(SizedBox),
          )
          .first;
      expect(tester.getSize(heading).width, width);
    });
  });

  group('a heading is centred over its column', () {
    testWidgets('an unsortable column centres its label exactly', (
      tester,
    ) async {
      // The float matrix declines sorting (#10), so it reserves no arrow and
      // its headings are centred with nothing to offset them.
      await tester.pumpWidget(
        matrix(rows: const [PeriodMatrixRow(label: 'CEU27')]),
      );

      final label = find.text(DateFormat('MMM/yy').format(months.first));
      final column = find
          .ancestor(of: label, matching: find.byType(SizedBox))
          .first;

      final labelBox = tester.getRect(label);
      final columnBox = tester.getRect(column);

      expect(
        labelBox.center.dx,
        moreOrLessEquals(columnBox.center.dx, epsilon: 0.5),
      );
    });

    testWidgets('a sortable column centres the label and its arrow slot', (
      tester,
    ) async {
      // The Occupation grid sorts, so 16 pt of arrow rides inside the centred
      // group and the label sits half of that left of geometric centre. The
      // alternative is reserving the same on both sides, which at a month's
      // width would leave the widest heading less room than it needs.
      await tester.pumpWidget(
        host(
          PeriodMatrix(
            months: months,
            headerLabel: 'WORKCENTER',
            rows: const [PeriodMatrixRow(label: 'CEU27')],
            cellAt: (row, month) => cell('x'),
            onSortMonth: (_) {},
          ),
          width: 900,
        ),
      );

      final label = find.text(DateFormat('MMM/yy').format(months.first));
      final column = find
          .ancestor(of: label, matching: find.byType(SizedBox))
          .first;

      final offset =
          tester.getRect(column).center.dx - tester.getRect(label).center.dx;

      // Left of centre, by half the arrow slot and no more.
      expect(offset, greaterThan(0));
      expect(offset, lessThanOrEqualTo(8.5));
    });
  });
}
