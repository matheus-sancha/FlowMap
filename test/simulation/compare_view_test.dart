import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/application/simulation_providers.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flowmap/src/features/simulation/presentation/compare_view.dart';
import 'package:flowmap/src/features/studies/application/studies_providers.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Compare, the third mode (#26): two studies of one cell and line. The
/// arithmetic is `run_comparison_test`'s; this holds down what the screen offers.
void main() {
  final now = DateTime(2026, 9, 13, 15, 30);
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

  Study study(String id, String line) => Study(
    id: id,
    projectId: 'doc',
    productionCellId: 'cell-11',
    productionLineId: line,
    name: id,
    includeInSimulation: false,
    startBufferDays: 0,
    createdAt: now,
    updatedAt: now,
  );

  StoredRun stored(String id, DateTime at, String studyId, int release) =>
      StoredRun(
        id: id,
        projectId: 'doc',
        createdAt: at,
        queues: const RunQueues([]),
        studies: [
          SimulationRunStudy(
            runId: id,
            studyId: studyId,
            name: studyId,
            releaseSeconds: release,
            startBufferDays: 0,
            productionCellName: 'Célula 11',
            productionLineName: 'Fluxo 11B',
          ),
        ],
        result: SimRunResult(
          start: at,
          end: at,
          guard: at,
          steps: const [],
          orders: const [],
          emptySlots: const [],
          busyByWorkcenter: const {},
          openByWorkcenter: const {},
        ),
        metrics: const RunMetrics(
          orders: 0,
          delivered: 0,
          onTime: 0,
          emptySlots: 0,
          averageFloat: null,
          averageLeadTime: null,
          theoreticalLeadTime: null,
          parts: [],
          workcenters: [],
        ),
        plan: const [],
      );

  RunListing listing(StoredRun run) => (
    run: SimulationRun(
      id: run.id,
      documentId: 'doc',
      dispatch: 'fifo',
      runStart: run.createdAt,
      runEnd: run.createdAt,
      guard: run.createdAt,
      createdAt: run.createdAt,
    ),
    queues: run.queues,
    studies: [
      for (final s in run.studies)
        (
          id: s.studyId,
          name: s.name,
          cellName: s.productionCellName,
          lineName: s.productionLineName,
        ),
    ],
  );

  Future<void> pump(
    WidgetTester tester, {
    required List<Study> studies,
    required List<StoredRun> runs,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studiesProvider('doc').overrideWith((ref) => Stream.value(studies)),
          projectRunsProvider('doc').overrideWith(
            (ref) => Stream.value([for (final r in runs) listing(r)]),
          ),
          for (final run in runs)
            storedRunProvider(run.id).overrideWith((ref) async => run),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // No scope needed: without one, dates fall back to the locale's format.
          home: Scaffold(body: CompareView(project: project)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('three studies on three lines say how to make a pair', (
    tester,
  ) async {
    // The live plant's shape.
    await pump(
      tester,
      studies: [study('11B', 'b'), study('11C', 'c'), study('11D', 'd')],
      runs: [stored('r1', now, '11B', 86400)],
    );
    expect(
      find.text('Compare needs two studies of one cell and line'),
      findsOneWidget,
    );
  });

  testWidgets('two studies of one line, each named with its latest run', (
    tester,
  ) async {
    await pump(
      tester,
      studies: [study('11B', 'b'), study('11B copy', 'b')],
      runs: [
        stored('r2', now, '11B copy', 43200),
        stored('r1', now.subtract(const Duration(hours: 2)), '11B', 86400),
      ],
    );

    // Name, date and time — no dispatch rule, no takt.
    expect(find.textContaining('11B copy · '), findsOneWidget);
    expect(find.textContaining('15:30'), findsOneWidget);
    expect(find.textContaining('FIFO'), findsNothing);
    expect(find.text('Célula 11 · Fluxo 11B'), findsOneWidget);
    // And what the two were given differently is named.
    expect(find.text('Release interval'), findsOneWidget);
  });
}
