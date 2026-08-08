import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmap/src/common/horizontal_scroll.dart';
import 'package:flowmap/src/common/result_table.dart';

/// The result pane's four load-bearing facts, none of which the compiler can
/// hold: the heading lines up with the body, it pins in one axis and not the
/// other, and there is a bar you can drag.
void main() {
  const columnWidth = 100.0;
  const columns = 3;
  const paneWidth = 220.0;

  // Narrower than the table, so there is genuinely something to scroll to, and
  // enough rows to overflow the pane's height.
  Widget harness({int rowCount = 40, double maxHeight = 200}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: paneWidth,
          child: resultTable(
            columns: const [
              ResultColumn(label: 'H0', width: columnWidth),
              ResultColumn(label: 'H1', width: columnWidth),
              ResultColumn(label: 'H2', width: columnWidth),
            ],
            rowCount: rowCount,
            maxHeight: maxHeight,
            cellAt: (row, column) => Text('r${row}c$column'),
          ),
        ),
      ),
    ),
  );

  testWidgets('every heading sits over its own column', (tester) async {
    await tester.pumpWidget(harness());

    for (var column = 0; column < columns; column++) {
      final heading = tester.getRect(find.text('H$column'));
      final cell = tester.getRect(find.text('r0c$column'));
      expect(
        cell.center.dx,
        moreOrLessEquals(heading.center.dx, epsilon: 1),
        reason: 'column $column: heading and body disagree',
      );
    }
  });

  testWidgets('the heading holds still while the body scrolls under it', (
    tester,
  ) async {
    await tester.pumpWidget(harness());

    final headingBefore = tester.getRect(find.text('H0'));
    final rowBefore = tester.getRect(find.text('r0c0'));

    await tester.drag(find.text('r0c0'), const Offset(0, -60));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text('H0')).top, headingBefore.top);
    expect(
      tester.getRect(find.text('r0c0')).top,
      lessThan(rowBefore.top - 1),
      reason: 'the body did not move, so the heading holding still proves '
          'nothing',
    );
  });

  testWidgets('the heading tracks the body sideways', (tester) async {
    await tester.pumpWidget(harness());

    final headingBefore = tester.getRect(find.text('H0')).left;
    final rowBefore = tester.getRect(find.text('r0c0')).left;

    await tester.drag(find.text('r0c0'), const Offset(-60, 0));
    await tester.pumpAndSettle();

    final headingAfter = tester.getRect(find.text('H0')).left;
    final rowAfter = tester.getRect(find.text('r0c0')).left;

    expect(headingAfter, lessThan(headingBefore - 1));
    expect(
      headingBefore - headingAfter,
      moreOrLessEquals(rowBefore - rowAfter, epsilon: 1),
      reason: 'the heading must pin vertically only — a heading outside the '
          'horizontal scroll view would leave the labels behind their columns',
    );
  });

  testWidgets('the horizontal bar has a thumb, and dragging it scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    // The bar fades in rather than appearing, and a thumb at zero opacity is
    // not hit-testable — so a single pumped frame finds nothing to grab.
    await tester.pumpAndSettle();

    final pane = tester.getRect(find.byType(HorizontalScroll));
    final rowBefore = tester.getRect(find.text('r0c0')).left;

    // The bar Flutter draws inside the bottom edge of the viewport, and the
    // thumb starts at the left of its track because nothing has scrolled yet.
    await tester.dragFrom(
      Offset(pane.left + 16, pane.bottom - 4),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('r0c0')).left,
      lessThan(rowBefore - 1),
      reason: 'the scrollbar thumb did not move the content — a Scrollbar '
          'given no controller holds no position to drag',
    );
  });

  testWidgets('the vertical bar drives the body, not the pane', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final pane = tester.getRect(find.byType(HorizontalScroll));
    final rowBefore = tester.getRect(find.text('r0c0')).top;

    // Below the heading, because that is where the track was inset to start —
    // a thumb whose track spanned the pane would sit beside rows that do not
    // scroll, and this point would miss it.
    await tester.dragFrom(
      Offset(pane.right - 4, pane.top + 70),
      const Offset(0, 30),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('r0c0')).top,
      lessThan(rowBefore - 1),
      reason: 'the vertical bar is placed outside the horizontal scroll view '
          'so that it pins to the pane rather than the table — which only '
          'works while its predicate and its controller both hold',
    );
  });
}
