import 'package:flowmap/src/common/result_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sorting rule, as the parts of it that are arithmetic (#10).
///
/// **More is testable than it looks.** Phase 4 is an interaction round, but
/// which rows come out in which order is a fact, not a feel — and the two
/// mistakes worth catching are both assertable: a second column inheriting the
/// previous column's direction, and a column with no key silently sorting by
/// something.
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 600, height: 400, child: child)),
  );

  /// Three stations, deliberately not in any column's order, so no assertion
  /// below can pass by accident on the order they were handed in.
  const rows = [
    (name: 'CEU27', queue: 30, visits: 1),
    (name: 'BAN11', queue: 10, visits: 3),
    (name: 'TTAT', queue: 20, visits: 2),
  ];

  List<String> namesOn(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((t) => rows.any((r) => r.name == t))
      .toList();

  Widget table({int initialColumn = 0, bool initialAscending = true}) =>
      SortableResultTable<({String name, int queue, int visits})>(
        initialColumn: initialColumn,
        initialAscending: initialAscending,
        columns: const [
          ResultColumn(label: 'Station', width: 140),
          ResultColumn(label: 'Queue', width: 100),
          // The column with no key: a heading that must never sort.
          ResultColumn(label: 'Notes', width: 100),
        ],
        rows: rows,
        sortKeyOf: (row, column) => switch (column) {
          0 => row.name,
          1 => row.queue,
          _ => null,
        },
        cellAt: (row, column) => switch (column) {
          0 => Text(row.name),
          1 => Text('${row.queue}'),
          _ => const Text('—'),
        },
      );

  testWidgets('it arrives on the column and direction it was given', (
    tester,
  ) async {
    // The point of `initialColumn`: a table looks on arrival exactly as it did
    // before it could sort at all, which for the queue ranking is the order
    // `metrics.workcenters` already computed.
    await tester.pumpWidget(
      host(table(initialColumn: 1, initialAscending: false)),
    );
    expect(namesOn(tester), ['CEU27', 'TTAT', 'BAN11']);
  });

  testWidgets('pressing the same heading twice reverses it', (tester) async {
    await tester.pumpWidget(host(table()));
    expect(namesOn(tester), ['BAN11', 'CEU27', 'TTAT']);

    await tester.tap(find.text('Station'));
    await tester.pumpAndSettle();
    expect(namesOn(tester), ['TTAT', 'CEU27', 'BAN11']);
  });

  testWidgets('a new column starts ascending rather than inheriting', (
    tester,
  ) async {
    // **The one that fails silently.** A new column inheriting the previous
    // one's direction sorts it the way the reader did not ask for, and the
    // *second* press is the one that looks like it worked — so the arrow and
    // the rows agree throughout and the table is simply wrong on first press.
    await tester.pumpWidget(host(table()));
    await tester.tap(find.text('Station'));
    await tester.pumpAndSettle();
    expect(namesOn(tester), ['TTAT', 'CEU27', 'BAN11'], reason: 'descending');

    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();
    expect(
      namesOn(tester),
      ['BAN11', 'TTAT', 'CEU27'],
      reason: 'Queue ascending, not descending inherited from Station',
    );
  });

  testWidgets('a column with no sort key does not sort, and shows no arrow', (
    tester,
  ) async {
    await tester.pumpWidget(host(table(initialColumn: 1)));
    final before = namesOn(tester);

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();

    expect(
      namesOn(tester),
      before,
      reason: 'a heading that sorts nothing must not reorder the rows',
    );
    // And the arrow stayed on the column that is actually sorted.
    expect(find.byIcon(Icons.arrow_upward), findsOne);
  });

  testWidgets('an empty table does not sort and does not throw', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SortableResultTable<int>(
          columns: const [ResultColumn(label: 'Only', width: 100)],
          rows: const [],
          sortKeyOf: (row, column) => row,
          cellAt: (row, column) => Text('$row'),
        ),
      ),
    );

    // `sortKeyOf` is probed against the first row to decide whether a column
    // sorts, and there is no first row — so this is the path that would throw.
    await tester.tap(find.text('Only'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
