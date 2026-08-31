import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/demand/application/demand_table.dart';
import 'package:flowmap/src/features/demand/application/mm3.dart';
import 'package:flowmap/src/features/demand/application/mm3_providers.dart';
import 'package:flowmap/src/features/demand/presentation/mm3_view.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounting tests for the MM3 view (DESIGN.md §16.3, §16.4).
///
/// The chart is a `CustomPaint` sized by its parent inside a `Column` with an
/// `Expanded` table beneath it — the arrangement most likely to throw at layout
/// time and show a blank grey panel in a release build.
void main() {
  final now = DateTime(2026, 8, 1);

  final study = Study(
    id: 'study-1',
    projectId: 'project-1',
    productionCellId: 'cell-1',
    productionLineId: 'line-1',
    name: 'Current state',
    includeInSimulation: false,
    startBufferDays: 0,
    createdAt: now,
    updatedAt: now,
  );

  Mm3Point point(int i, double? average, {double? equivalence}) => Mm3Point(
    orderId: 'o$i',
    sequence: i,
    partNumber: 'PN$i',
    batchSize: 1,
    partEquivalence: equivalence, slotLoad: equivalence,
    movingAverage: average,
  );

  Future<void> pump(WidgetTester tester, Mm3Series series) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mm3SeriesProvider(study.id).overrideWithValue(series),
          mm3ScopesProvider(study.id).overrideWithValue(const [
            DemandColumn(nodeId: 'node-0', targetId: 'wc-1', title: 'CLAD04'),
          ]),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Mm3View(study: study)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('draws the chart, the headline and the table', (tester) async {
    await pump(
      tester,
      Mm3Series(
        scope: const Mm3Scope(targetId: 'wc-1', title: 'CLAD04'),
        points: [
          point(0, null, equivalence: 1.20),
          point(1, 1.11, equivalence: 1.13),
          point(2, 1.01, equivalence: 1.00),
          point(3, 0.97, equivalence: 0.90),
          point(4, null, equivalence: 1.01),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    // |0.11| + |0.01| + |0.03| over three = 0.05.
    expect(find.text('±5.0%'), findsOneWidget);
    expect(find.text('1.11'), findsOneWidget);
    expect(find.text('CLAD04'), findsWidgets);
  });

  testWidgets('an empty sequence says so rather than drawing an empty chart', (
    tester,
  ) async {
    await pump(
      tester,
      const Mm3Series(
        scope: Mm3Scope(targetId: null, title: ''),
        points: [],
      ),
    );

    expect(find.text('No orders in the sequence yet.'), findsOneWidget);
  });

  testWidgets('a sequence with nothing measurable explains itself', (
    tester,
  ) async {
    await pump(
      tester,
      Mm3Series(
        scope: const Mm3Scope(targetId: 'wc-1', title: 'CLAD04'),
        points: [point(0, null), point(1, null), point(2, null)],
      ),
    );

    expect(find.textContaining('Nothing to measure yet'), findsOneWidget);
    // The rows are still listed, so the user can see which parts are blank.
    expect(find.text('PN1'), findsOneWidget);
  });
}
