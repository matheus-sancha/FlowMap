import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/summary/application/summary_providers.dart';
import 'package:flowmap/src/features/summary/application/summary_view.dart';
import 'package:flowmap/src/features/summary/presentation/summary_tab.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounting tests for the Summary tab (DESIGN.md §16.3, §16.4).
void main() {
  final now = DateTime(2026, 8, 1);

  final study = Study(
    id: 'study-1',
    projectId: 'project-1',
    productionCellId: 'cell-1',
    productionLineId: 'line-1',
    name: 'Current state',
    includeInSimulation: false,
    priority: 100,
    createdAt: now,
    updatedAt: now,
  );

  TargetOccupation target(
    String id, {
    required Duration work,
    required Duration available,
    int operators = 3,
    int visits = 1,
    int missing = 0,
  }) => TargetOccupation(
    targetId: id,
    title: id,
    visits: visits,
    work: work,
    changeovers: 2,
    changeoverTime: const Duration(hours: 1),
    availableProductive: available,
    operatorsAllocated: operators,
    partsWithoutTimes: missing,
  );

  Future<void> pump(WidgetTester tester, SummaryView summary) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [summaryViewProvider(study.id).overrideWithValue(summary)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SummaryTab(study: study)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('names the bottleneck and lists every station', (tester) async {
    await pump(
      tester,
      SummaryView(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
        ordersInPeriod: 20,
        targets: [
          target(
            'CLAD04',
            work: const Duration(hours: 349),
            available: const Duration(hours: 310),
          ),
          target(
            'TTAT',
            work: const Duration(hours: 99),
            available: const Duration(hours: 310),
          ),
        ],
        demandTakt: DemandTaktView(
          paceSetterTitle: 'CLAD04',
          paceSetterWorkingDay: const Duration(hours: 10),
          available: const Duration(hours: 310),
          orders: 20,
          equivalents: 24,
          configured: const Duration(hours: 10),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // 350 required over 310 available = 113 %.
    expect(find.text('Bottleneck: CLAD04 at 113%'), findsOneWidget);
    expect(find.textContaining('Above 100 %'), findsOneWidget);
    expect(find.text('TTAT'), findsOneWidget);
    expect(find.text('20 orders due'), findsOneWidget);
    expect(find.text('Raw demand takt'), findsOneWidget);
  });

  testWidgets('an empty study says what it is missing', (tester) async {
    await pump(
      tester,
      SummaryView(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
        ordersInPeriod: 0,
        targets: const [],
        demandTakt: null,
      ),
    );

    expect(find.textContaining('Nothing to rank yet'), findsOneWidget);
    expect(find.textContaining('No demand takt yet'), findsOneWidget);
  });

  testWidgets('a station short of process times is flagged', (tester) async {
    await pump(
      tester,
      SummaryView(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
        ordersInPeriod: 5,
        targets: [
          target(
            'CLAD04',
            work: const Duration(hours: 10),
            available: const Duration(hours: 310),
            missing: 3,
            visits: 2,
          ),
        ],
        demandTakt: null,
      ),
    );

    // The required hours are an understatement while a part due here has no
    // time, and the table has to say so rather than look merely quiet.
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
  });
}
