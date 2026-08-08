import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmap/src/common/centred_table.dart';

void main() {
  // A wide heading over a narrow cell, in a table of more than one column —
  // which is what every table in the app is. Under start alignment their *left*
  // edges line up; centred, their *centres* do. Asserting both is what tells
  // the two apart: either one alone passes under both alignments.
  //
  // The second column is not decoration. A `DataTable` whose single column
  // fills the whole table stretches that column, and a heading does not
  // participate in the stretch the way a cell does — so a one-column fixture
  // reports a centring that no real table would show.
  Widget table({required bool centred, bool scrolls = true}) {
    final content = DataTable(
      columns: centred
          ? [centredColumn('A much wider heading'), centredColumn('Second')]
          : const [
              DataColumn(label: Text('A much wider heading')),
              DataColumn(label: Text('Second')),
            ],
      rows: [
        DataRow(
          cells: centred
              ? [centredText('x'), centredText('yyyyyyyyyy')]
              : const [DataCell(Text('x')), DataCell(Text('yyyyyyyyyy'))],
        ),
      ],
    );

    return MaterialApp(
      home: Scaffold(
        body: scrolls
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: content,
              )
            : Card(child: content),
      ),
    );
  }

  testWidgets('a centred column puts its header and cell on one axis', (
    tester,
  ) async {
    await tester.pumpWidget(table(centred: true));

    final header = tester.getRect(find.text('A much wider heading'));
    final cell = tester.getRect(find.text('x'));

    expect(cell.center.dx, moreOrLessEquals(header.center.dx, epsilon: 1));
    // And is genuinely not start-aligned — the narrow cell has been pushed in.
    expect(cell.left, greaterThan(header.left + 1));
  });

  testWidgets('centring holds in a table that stretches to fill', (
    tester,
  ) async {
    // The takt schedule sits in a Card with no horizontal scroll view, so its
    // columns are widened to fill rather than sized to their content. Column
    // width is then not the heading's width, which is exactly the case a
    // wrapper that merely shrink-wraps its child would get wrong.
    await tester.pumpWidget(table(centred: true, scrolls: false));

    final header = tester.getRect(find.text('A much wider heading'));
    final cell = tester.getRect(find.text('x'));

    expect(cell.center.dx, moreOrLessEquals(header.center.dx, epsilon: 1));
  });

  testWidgets('an uncentred column does not, which is what is being fixed', (
    tester,
  ) async {
    await tester.pumpWidget(table(centred: false));

    final header = tester.getRect(find.text('A much wider heading'));
    final cell = tester.getRect(find.text('x'));

    // The default: left edges together, centres far apart.
    expect(cell.left, moreOrLessEquals(header.left, epsilon: 1));
    expect((cell.center.dx - header.center.dx).abs(), greaterThan(1));
  });
}
