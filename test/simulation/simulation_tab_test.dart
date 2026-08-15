import 'package:flowmap/src/common/part_palette.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_assembly.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/application/simulation_providers.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flowmap/src/features/projects/presentation/project_workspace_screen.dart';
import 'package:flowmap/src/features/resources/application/resources_providers.dart';
import 'package:flowmap/src/features/simulation/presentation/simulation_workspace.dart';
import 'package:flowmap/src/features/studies/application/studies_providers.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounting tests for where a run is read (DESIGN.md §12.1, §11, §8).
///
/// **This mounted the study's Simulation tab until that tab was deleted.** A run
/// spans studies and is read in one place now, so the assertions moved to the
/// workspace that replaced it — the figures are unchanged, because both were
/// always one `StoredRun` through one `RunFilter`.
///
/// The readiness assertions moved further, to [Readiness] itself: it is under
/// the Simulate button on the app bar now, and mounting the whole workspace
/// screen to read a list needs a database.
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

  StoredRun storedRun({SimAbortReason? abort, int orders = 4, int onTime = 3}) {
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
      dispatchOverrides: const [],
      studies: const [],
      result: result,
      plan: [
        for (final outcome in result.orders)
          ProductionPlanRow(
            outcome: outcome,
            partNumber: 'PN1',
            partDescription: 'PWB 10K',
            customerProject: 'Wing 7',
            batchNumber: 'B-00${outcome.sequence}',
            batchSize: 4,
            materialDate: DateTime(2026, 8, 1),
            theoreticalLeadTime: const Duration(hours: 6),
          ),
      ],
      metrics: summariseRun(
        result: result,
        partNumbers: const {'part-1': 'PN1'},
        workcenterNames: const {'wc-1': 'CLAD04'},
        theoreticalByOrder: const {},
      ),
    );
  }

  SimulationRunStudy study(String id, String name) => SimulationRunStudy(
    runId: 'run-1',
    studyId: id,
    name: name,
    releaseSeconds: const Duration(hours: 6).inSeconds,
    priority: 0,
    startBufferDays: 0,
  );

  /// A run across two lines whose parts are both called `PN2` (§8.1.2).
  ///
  /// Legal, because `DemandParts` is unique on `{studyId, partNumber}` (§16.15)
  /// — and the case the Study column exists for: without it the table shows two
  /// rows reading identically.
  StoredRun twoStudyRun() {
    final result = SimRunResult(
      start: DateTime(2026, 8, 3),
      end: DateTime(2026, 8, 28),
      guard: DateTime(2027),
      steps: const [],
      orders: [
        SimOrderOutcome(
          studyId: 'study-1',
          orderId: 'o-1',
          sequence: 0,
          partId: 'part-1',
          needDate: DateTime(2026, 8, 20),
          released: DateTime(2026, 8, 3),
          delivered: DateTime(2026, 8, 10),
        ),
        SimOrderOutcome(
          studyId: 'study-2',
          orderId: 'o-2',
          sequence: 0,
          partId: 'part-2',
          needDate: DateTime(2026, 8, 20),
          released: DateTime(2026, 8, 3),
          delivered: DateTime(2026, 8, 12),
        ),
      ],
      emptySlots: const [],
      busyByWorkcenter: const {'wc-1': Duration(hours: 60)},
      openByWorkcenter: const {'wc-1': Duration(hours: 100)},
    );

    return StoredRun(
      id: 'run-1',
      projectId: project.id,
      createdAt: now,
      dispatch: DispatchRule.fifo,
      dispatchOverrides: const [],
      studies: [study('study-1', 'Célula 11B'), study('study-2', 'Célula 12A')],
      result: result,
      plan: const [],
      metrics: summariseRun(
        result: result,
        partNumbers: const {'part-1': 'PN2', 'part-2': 'PN2'},
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
          simRunInputProvider(
            project.id,
          ).overrideWith((ref) async => assembled),
          simulationRunnerProvider(
            project.id,
          ).overrideWith(() => _StubRunner(run)),
          projectRunsProvider(
            project.id,
          ).overrideWith((ref) => Stream.value(const [])),
          // The filter bar offers studies, cells and lines from the plant
          // rather than from the run (§12.1), so it asks for both even on a
          // project that has never run.
          studiesProvider(project.id).overrideWith((ref) => Stream.value(const [])),
          plantLinesProvider(
            project.plantId,
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SimulationWorkspace(project: project)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Simulate itself is no longer on this tab — it is on the project's app bar
  // (§12.1), so it can be pressed from any of the six. What it is gated on,
  // `SimRunInput.canRun`, is a pure predicate covered eight ways in
  // `simulation_repository_test.dart`; what is left here is what the tab shows
  // about a run it cannot make.

  testWidgets('nothing flagged says so rather than showing an empty run', (
    tester,
  ) async {
    await pump(tester, assembled: const SimRunInput.empty());

    expect(find.text('No study is selected for a run'), findsOne);
  });

  testWidgets('an unready study names itself and says what is wrong', (
    tester,
  ) async {
    // **Mounted directly**, because this panel is now under the Simulate button
    // on the project's app bar (§12.1) rather than on a tab — and the whole
    // screen needs a database to reach. What is asserted is unchanged: a study
    // that cannot run is named, and the reason is a sentence rather than a
    // state.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Readiness(
            input: input(
              ready: false,
              readiness: const [
                StudyReadiness(
                  studyId: 'study-1',
                  name: 'Current state',
                  problems: [SimAssemblyProblem.unboundStep],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not ready to run'), findsOne);
    expect(find.text('Current state'), findsOne);
    expect(
      find.text('• A step targets no workcenter, or its pool is empty.'),
      findsOne,
    );
  });

  testWidgets('a ready study is not listed as a problem', (tester) async {
    // The other half, and the one that would fail silently: a panel that lists
    // every study rather than every unready one turns "one line is broken" into
    // a wall the reader has to scan.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Readiness(
            input: input(
              ready: false,
              readiness: const [
                StudyReadiness(
                  studyId: 'study-1',
                  name: 'Broken one',
                  problems: [SimAssemblyProblem.noTakt],
                ),
                StudyReadiness(
                  studyId: 'study-2',
                  name: 'Fine one',
                  problems: [],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Broken one'), findsOne);
    expect(find.text('Fine one'), findsNothing);
  });

  testWidgets('a ready project with no run yet says so', (tester) async {
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
  });

  testWidgets('a finished run reports §8 and names the bottleneck', (
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
    // Once in the per-part table and once per plan row below it.
    expect(find.text('PN1'), findsWidgets);
  });

  testWidgets('one study means no Study column on the per-part table', (
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
      run: storedRun(),
    );

    // §8.5's rule: every row would hold the same answer, so the column says
    // nothing the tab has not said.
    expect(find.text('Per part number'), findsOne);
    expect(find.text('Study'), findsNothing);
  });

  testWidgets('the Parts table carries the legend swatch (§8.6)', (
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
      run: storedRun(),
    );

    // One part, so the first colour — and the swatch is beside the number
    // rather than in a strip of its own.
    final swatch = tester.widget<Container>(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('PN1').first,
              matching: find.byType(Row),
            ),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = swatch.decoration! as BoxDecoration;
    expect(decoration.color, partPalette.first.fill);
  });

  testWidgets('two studies sharing a part number are told apart (§8.1.2)', (
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
      run: twoStudyRun(),
    );

    expect(find.text('Study'), findsOne);
    // Two rows, both `PN2`, and the only thing separating them is the column.
    expect(find.text('PN2'), findsExactly(2));
    // The names the studies had when the run was made (§7.10).
    expect(find.text('Célula 11B'), findsOne);
    expect(find.text('Célula 12A'), findsOne);
  });

  testWidgets('the production plan lists every order the run placed', (
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
      run: storedRun(),
    );

    expect(find.text('Production plan — orders over time'), findsOne);

    // The Order column is the sequence position, 1-based — the same number the
    // demand grid's row header shows, not a works order number (§9.1).
    expect(find.text('1'), findsWidgets);
    expect(find.text('4'), findsWidgets);

    // The demand half comes from the run's own snapshot, so a plan stays
    // readable after the sequence beneath it is edited (§7.10).
    expect(find.text('B-000'), findsOne);
    expect(find.text('B-003'), findsOne);
    expect(find.text('Wing 7'), findsWidgets);

    // The description rides in on the same snapshot, and is read from the run
    // rather than from the part it names (§16.14).
    expect(find.text('Description'), findsOne);
    expect(find.text('PWB 10K'), findsWidgets);

    // Both lead times, theoretical first. Actual is order end minus order
    // start, so it is not the stored figure beside it — the two disagreeing is
    // the queueing, which is the reason both columns are here.
    expect(find.text('Theoretical LT'), findsOne);
    expect(find.text('Actual LT'), findsOne);
    expect(find.text('Order end'), findsOne);
    expect(find.text('Delivery'), findsNothing);
  });

  testWidgets('a run stored before v12 shows dashes, not invented data', (
    tester,
  ) async {
    // The Célula 11B run: its order rows predate the four columns the plan
    // reads, and §16.13 chose a blank over a backfill from today's demand.
    final run = storedRun();
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
      run: StoredRun(
        id: run.id,
        projectId: run.projectId,
        createdAt: run.createdAt,
        dispatch: run.dispatch,
        dispatchOverrides: run.dispatchOverrides,
        studies: run.studies,
        result: run.result,
        metrics: run.metrics,
        plan: [
          for (final outcome in run.result.orders)
            ProductionPlanRow(
              outcome: outcome,
              partNumber: 'PN1',
              partDescription: null,
              customerProject: null,
              batchNumber: null,
              batchSize: null,
              materialDate: null,
              theoreticalLeadTime: null,
            ),
        ],
      ),
    );

    // Still a plan — the six columns the run did record are all there.
    expect(find.text('Production plan — orders over time'), findsOne);
    expect(find.text('—'), findsWidgets);
    expect(find.text('Wing 7'), findsNothing);
  });

  testWidgets('the run switches between two views of itself (§8.6)', (
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
      run: storedRun(),
    );

    // The header, the headline and the abort banner describe *the run*, so the
    // control switches only what is beneath them.
    expect(find.text('Results'), findsOne);
    expect(find.text('Gantt'), findsOne);
    expect(find.text('Production plan — orders over time'), findsOne);

    await tester.tap(find.text('Gantt'));
    await tester.pumpAndSettle();

    // The headline stays put across the switch; the tables do not.
    expect(find.text('On-time delivery: 75%'), findsOne);
    expect(find.text('Production plan — orders over time'), findsNothing);
    // This fixture stores no steps, which is exactly what a Gantt has nothing
    // to draw from.
    expect(
      find.text('This run recorded no steps, so there is nothing to draw.'),
      findsOne,
    );

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();

    expect(find.text('Production plan — orders over time'), findsOne);
  });

  testWidgets('an aborted run says why rather than just reading badly', (
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
