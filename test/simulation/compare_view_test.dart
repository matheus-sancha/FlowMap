import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/application/simulation_providers.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flowmap/src/features/simulation/presentation/compare_view.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Compare, the third mode (#26). The arithmetic is `run_comparison_test`'s;
/// this holds down what the screen does with it.
void main() {
  final now = DateTime(2026, 9, 13);
  final project = Project(
    id: 'doc',
    name: 'H2 2026',
    plantId: 'plant',
    shiftPatternId: 'abc',
    floatRedDays: 0,
    floatGreenDays: 5,
    occupationAmberPct: 85,
    occupationRedPct: 100,
    createdAt: now,
    updatedAt: now,
  );

  StoredRun stored(String id, {required int onTime, DispatchRule? rule}) =>
      StoredRun(
        id: id,
        projectId: 'doc',
        createdAt: now,
        queues: RunQueues([if (rule != null) (name: 'CLAD04', rule: rule)]),
        studies: const [
          SimulationRunStudy(
            runId: 'r',
            studyId: 's',
            name: 'Célula 11B',
            releaseSeconds: 86400,
            startBufferDays: 0,
          ),
        ],
        result: SimRunResult(
          start: now,
          end: now,
          guard: now,
          steps: const [],
          orders: const [],
          emptySlots: const [],
          busyByWorkcenter: const {},
          openByWorkcenter: const {},
        ),
        metrics: RunMetrics(
          orders: 10,
          delivered: 10,
          onTime: onTime,
          emptySlots: 0,
          averageFloat: null,
          averageLeadTime: null,
          theoreticalLeadTime: null,
          parts: const [],
          workcenters: const [],
        ),
        plan: const [],
      );

  RunListing listing(StoredRun run) => (
    run: SimulationRun(
      id: run.id,
      documentId: 'doc',
      dispatch: 'fifo',
      runStart: now,
      runEnd: now,
      guard: now,
      createdAt: run.createdAt,
    ),
    queues: run.queues,
    takts: const [],
  );

  Future<void> pump(WidgetTester tester, List<StoredRun> runs) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRunsProvider('doc').overrideWith(
            (ref) => Stream.value([for (final r in runs) listing(r)]),
          ),
          for (final run in runs)
            storedRunProvider(run.id).overrideWith((ref) async => run),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CompareView(project: project)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('one run says how to get a second', (tester) async {
    await pump(tester, [stored('a', onTime: 5)]);
    expect(find.text('Compare needs two runs'), findsOneWidget);
  });

  testWidgets('the newest run is After, the one before it Before', (
    tester,
  ) async {
    // Listed newest first, as `watchRuns` returns them.
    await pump(tester, [
      stored('newest', onTime: 9, rule: DispatchRule.earliestDueDate),
      stored('older', onTime: 6, rule: DispatchRule.fifo),
    ]);

    // The verdict reads before → after, in that order, and says by how much.
    expect(find.text('On-time delivery: 60% → 90%'), findsOneWidget);
    expect(find.text('+30 pts'), findsWidgets);
    // And the one thing that differed is named, in the app's own words.
    expect(find.text('CLAD04'), findsOneWidget);
    expect(find.text('Dispatch'), findsOneWidget);
  });
}
