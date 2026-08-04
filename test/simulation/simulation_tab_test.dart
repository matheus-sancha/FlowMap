import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_assembly.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/application/simulation_providers.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flowmap/src/features/simulation/presentation/simulation_tab.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounting tests for the Simulation tab (DESIGN.md §12.1, §11, §8).
///
/// What these are for is the gate: Simulate must be dead while a study cannot
/// run, and the panel must name which study and why. A run that starts against
/// a half-built plant is the failure §11 exists to prevent.
void main() {
  final now = DateTime(2026, 8, 1);

  final project = Project(
    id: 'project-1',
    name: 'H2 2026',
    plantId: 'plant-1',
    shiftPatternId: 'pattern-1',
    createdAt: now,
    updatedAt: now,
  );

  SimRunInput input({
    required List<StudyReadiness> readiness,
    bool ready = true,
  }) => SimRunInput(
    studies: ready
        ? [
            for (final study in readiness)
              SimStudy(
                id: study.studyId,
                name: study.name,
                nodes: const [],
                parts: const {},
                orders: const [],
                releaseInterval: const Duration(hours: 6),
              ),
          ]
        : const [],
    workcenters: const {},
    readiness: readiness,
  );

  StoredRun storedRun({
    SimAbortReason? abort,
    int orders = 4,
    int onTime = 3,
  }) {
    final result = SimRunResult(
      start: DateTime(2026, 8, 3),
      end: DateTime(2026, 8, 28),
      guard: DateTime(2027),
      steps: const [],
      orders: [
        for (var i = 0; i < orders; i++)
          SimOrderOutcome(
            studyId: 'study-1',
            orderId: 'o$i',
            sequence: i,
            partId: 'part-1',
            needDate: DateTime(2026, 8, 20),
            released: DateTime(2026, 8, 3),
            // The last few miss their need date, so on-time is not trivially 1.
            delivered: i < onTime
                ? DateTime(2026, 8, 19)
                : DateTime(2026, 8, 25),
          ),
      ],
      emptySlots: const [],
      busyByWorkcenter: const {'wc-1': Duration(hours: 60)},
      openByWorkcenter: const {'wc-1': Duration(hours: 100)},
      abort: abort,
    );

    return StoredRun(
      id: 'run-1',
      projectId: project.id,
      createdAt: now,
      dispatch: DispatchRule.earliestDueDate,
      studies: const [],
      result: result,
      metrics: summariseRun(
        result: result,
        partNumbers: const {'part-1': 'PN1'},
        workcenterNames: const {'wc-1': 'CLAD04'},
        theoreticalByOrder: const {},
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required SimRunInput assembled,
    StoredRun? run,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          simRunInputProvider(project.id).overrideWith((ref) async => assembled),
          simulationRunnerProvider(
            project.id,
          ).overrideWith(() => _StubRunner(run)),
          projectRunsProvider(
            project.id,
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SimulationTab(project: project)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool simulateEnabled(WidgetTester tester) => tester
      .widget<FilledButton>(
        find.ancestor(
          of: find.text('Simulate'),
          matching: find.byType(FilledButton),
        ),
      )
      .onPressed !=
      null;

  testWidgets('nothing flagged says so rather than showing an empty run', (
    tester,
  ) async {
    await pump(tester, assembled: const SimRunInput.empty());

    expect(find.text('No study is selected for a run'), findsOne);
    expect(simulateEnabled(tester), isFalse);
  });

  testWidgets('an unready study names itself and disables Simulate', (
    tester,
  ) async {
    await pump(
      tester,
      assembled: input(
        ready: false,
        readiness: const [
          StudyReadiness(
            studyId: 'study-1',
            name: 'Current state',
            problems: [SimAssemblyProblem.unboundStep],
          ),
        ],
      ),
    );

    expect(find.text('Not ready to run'), findsOne);
    expect(find.text('Current state'), findsOne);
    expect(
      find.text('• A step targets no workcenter, or its pool is empty.'),
      findsOne,
    );
    expect(simulateEnabled(tester), isFalse);
  });

  testWidgets('a ready project with no run yet offers the button', (
    tester,
  ) async {
    await pump(
      tester,
      assembled: input(
        readiness: const [
          StudyReadiness(
            studyId: 'study-1',
            name: 'Current state',
            problems: [],
          ),
        ],
      ),
    );

    expect(find.text('No run yet'), findsOne);
    expect(find.text('Not ready to run'), findsNothing);
    expect(simulateEnabled(tester), isTrue);
  });

  testWidgets('a finished run reports §8 and names the bottleneck', (
    tester,
  ) async {
    await pump(
      tester,
      assembled: input(
        readiness: const [
          StudyReadiness(studyId: 'study-1', name: 'Current state', problems: []),
        ],
      ),
      run: storedRun(),
    );

    // 3 of 4 on time.
    expect(find.text('On-time delivery: 75%'), findsOne);
    expect(find.textContaining('3 of 4 orders on time'), findsOne);
    // Both rankings, and the station named from the stored snapshot rather
    // than from a workcenter row that may no longer exist.
    expect(find.text('Ranked by queue time'), findsOne);
    expect(find.text('Ranked by share of the flow'), findsOne);
    expect(find.text('Per part number'), findsOne);
    expect(find.text('PN1'), findsOne);
  });

  testWidgets('an aborted run says why rather than just reading badly', (
    tester,
  ) async {
    await pump(
      tester,
      assembled: input(
        readiness: const [
          StudyReadiness(studyId: 'study-1', name: 'Current state', problems: []),
        ],
      ),
      run: storedRun(abort: SimAbortReason.horizonExceeded, onTime: 0),
    );

    expect(find.textContaining('Demand exceeds capacity'), findsOne);
  });
}

/// A runner that reports one stored run and never touches a database.
class _StubRunner extends SimulationRunner {
  _StubRunner(this._run);

  final StoredRun? _run;

  @override
  Future<StoredRun?> build(String projectId) async => _run;
}
