import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/demand/application/demand_providers.dart';
import 'package:flowmap/src/features/demand/application/demand_table.dart';
import 'package:flowmap/src/features/demand/presentation/demand_tab.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounting tests for the Demand tab (DESIGN.md §16.3, §16.4).
///
/// Every UI failure this project has had was a mount-time one, invisible to
/// unit tests and silent in a release build. The grid is the most
/// layout-sensitive thing built so far — a `ListView` inside a horizontally
/// scrolling `SingleChildScrollView`, inside a `Column` — so it is pumped
/// rather than reasoned about.
///
/// The providers are overridden rather than fed by a real database: what a
/// block of cells *means* is tested in `demand_paste_test.dart` and what
/// reaches the tables in `demand_repository_test.dart`, so nothing here needs
/// Drift — and a Drift stream inside `fakeAsync` leaves timers pending that the
/// test binding then fails on.
void main() {
  final now = DateTime(2026, 8, 1);

  DemandPart part(String id, String number, {String? description}) => DemandPart(
    id: id,
    studyId: 'study-1',
    partNumber: number,
    description: description,
    createdAt: now,
    updatedAt: now,
  );

  DemandOrder order(String id, int sequence, String partId) => DemandOrder(
    id: id,
    studyId: 'study-1',
    partId: partId,
    sequence: sequence,
    batchSize: 4,
    needDate: DateTime(2026, 8, 13),
    createdAt: now,
    updatedAt: now,
  );

  final study = Study(
    id: 'study-1',
    projectId: 'project-1',
    productionCellId: 'cell-1',
    productionLineId: 'line-1',
    name: 'Current state',
    includeInSimulation: false,
    startBufferDays: 0,
    priority: 100,
    createdAt: now,
    updatedAt: now,
  );

  const columns = [
    DemandColumn(nodeId: 'node-0', targetId: 'wc-1', title: 'CLAD04'),
    DemandColumn(nodeId: 'node-1', targetId: 'wc-2', title: 'TTAT'),
  ];

  Future<void> pumpTab(
    WidgetTester tester, {
    required DemandTable table,
    List<DemandOrder> orders = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demandTableProvider(study.id).overrideWithValue(table),
          demandOrdersProvider(
            study.id,
          ).overrideWith((ref) => Stream.value(orders)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DemandTab(study: study)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the parts grid draws a column per flow step', (tester) async {
    await pumpTab(
      tester,
      table: DemandTable(
        parts: [part('p1', 'PN1', description: 'Housing')],
        columns: columns,
        times: {
          'p1': {
            'wc-1': const Duration(hours: 55),
            'wc-2': const Duration(hours: 3),
          },
        },
      ),
    );

    expect(find.text('CLAD04'), findsOneWidget);
    expect(find.text('TTAT'), findsOneWidget);
    expect(find.text('PN1'), findsOneWidget);
    expect(find.text('55:00:00'), findsOneWidget);
    // The Total column, derived rather than typed.
    expect(find.text('58:00:00'), findsOneWidget);
  });

  testWidgets('a step a part skips reads blank, not zero', (tester) async {
    await pumpTab(
      tester,
      table: DemandTable(
        parts: [part('p1', 'PN1')],
        columns: columns,
        times: {
          'p1': {'wc-1': const Duration(hours: 8)},
        },
      ),
    );

    // `00:00:00` would claim the step takes no time; the part does not go
    // there at all (§5.1).
    expect(find.text('00:00:00'), findsNothing);
    expect(find.text('08:00:00'), findsNWidgets(2)); // the cell and the total
  });

  testWidgets('a flow with no steps says so rather than drawing an empty grid', (
    tester,
  ) async {
    await pumpTab(
      tester,
      table: const DemandTable(parts: [], columns: [], times: {}),
    );

    expect(
      find.textContaining('no process steps yet'),
      findsOneWidget,
    );
  });

  testWidgets('an unbound step is drawn, and marked unusable', (tester) async {
    await pumpTab(
      tester,
      table: DemandTable(
        parts: [part('p1', 'PN1')],
        columns: const [
          DemandColumn(nodeId: 'node-0', targetId: null, title: '—'),
        ],
        times: const {},
      ),
    );

    // The hole is visible on the grid, not only in the readiness panel.
    expect(find.text('not bound'), findsOneWidget);
  });

  testWidgets('the sequence grid mounts and shows the order sequence', (
    tester,
  ) async {
    await pumpTab(
      tester,
      table: DemandTable(
        parts: [part('p1', 'PN1')],
        columns: columns,
        times: const {},
      ),
      orders: [order('o1', 0, 'p1'), order('o2', 1, 'p1')],
    );

    await tester.tap(find.text('Sequence'));
    await tester.pumpAndSettle();

    // Two rows of PN1, no order number column: a simulation identifies an
    // order by the row it is.
    expect(find.text('PN1'), findsNWidgets(2));
    expect(find.text('Need date'), findsOneWidget);
    expect(find.text('Order'), findsNothing);
  });

  testWidgets('the sequence grid says what it needs before it can be used', (
    tester,
  ) async {
    await pumpTab(
      tester,
      table: DemandTable(parts: const [], columns: columns, times: const {}),
    );

    await tester.tap(find.text('Sequence'));
    await tester.pumpAndSettle();

    expect(find.text('Add a part before adding orders.'), findsOneWidget);
  });
}
