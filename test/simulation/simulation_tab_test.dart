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
import 'package:flowmap/src/features/simulation/presentation/gantt_view.dart';
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
      floatRedDays: 0,
      floatGreenDays: 30,
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
    RunQueues queues = const RunQueues([
      (name: 'CLAD04', rule: DispatchRule.earliestDueDate),
    ]),
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
      queues: queues,
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
      queues: const RunQueues([(name: 'CLAD04', rule: DispatchRule.fifo)]),
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

  /// Two studies, and a plan row for each — `twoStudyRun`'s plan is empty, and
  /// an empty plan cannot show a plan table ignoring a filter.
  StoredRun twoStudyPlanRun() {
    final base = twoStudyRun();
    return StoredRun(
      id: base.id,
      projectId: base.projectId,
      createdAt: base.createdAt,
      queues: base.queues,
      studies: base.studies,
      result: base.result,
      metrics: base.metrics,
      plan: [
        for (final outcome in base.result.orders)
          ProductionPlanRow(
            outcome: outcome,
            partNumber: outcome.studyId == 'study-1' ? 'KEPT-1' : 'DROPPED-2',
            partDescription: null,
            customerProject: null,
            batchNumber: null,
            batchSize: null,
            materialDate: null,
            theoreticalLeadTime: const Duration(hours: 6),
          ),
      ],
    );
  }

  /// Opens the filter bar's picker labelled [label].
  ///
  /// **`ensureVisible` first, because the bar scrolls now.** §7.5 put three more
  /// controls on it, so on an 800 px test surface the later ones start off the
  /// right-hand edge — and a tap computed against an off-screen centre lands on
  /// whatever is there instead, which is a test that fails for a reason that has
  /// nothing to do with what it is asserting.
  Future<void> openPicker(WidgetTester tester, String label) async {
    final button = find.textContaining(label);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
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
          studiesProvider(
            project.id,
          ).overrideWith((ref) => Stream.value(const [])),
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

  testWidgets('the run header names the queue every station shared', (
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
      run: storedRun(
        queues: const RunQueues([
          (name: 'CLAD04', rule: DispatchRule.fifo),
          (name: 'MILL02', rule: DispatchRule.fifo),
        ]),
      ),
    );

    expect(find.textContaining('FIFO'), findsOne);
    // And nothing beneath it. Repeating one shared rule per station is the
    // same word twice, and the header used to carry a count of overrides of a
    // rule the run no longer has (§7.3).
    expect(find.textContaining('CLAD04:'), findsNothing);
  });

  testWidgets('a run whose stations differ says mixed, and says which', (
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
      run: storedRun(
        queues: const RunQueues([
          (name: 'CLAD04', rule: DispatchRule.earliestDueDate),
          (name: 'MILL02', rule: DispatchRule.fifo),
        ]),
      ),
    );

    // `mixed` alone would say the run is not one thing without saying what it
    // is, which is the complaint the old override count answered badly.
    expect(find.textContaining('mixed'), findsOne);
    expect(find.textContaining('CLAD04: Earliest need date'), findsOne);
    expect(find.textContaining('MILL02: FIFO'), findsOne);
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
        queues: run.queues,
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

  testWidgets('the run switches between three views of itself (§8.6, §10.3)', (
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

    // And the third, added by §10.3. This fixture's run carries no monthly
    // capacity — which is every run made before v25 — so the view says why
    // rather than drawing an empty chart.
    await tester.tap(find.text('Occupation'));
    await tester.pumpAndSettle();

    expect(find.text('Production plan — orders over time'), findsNothing);
    expect(
      find.textContaining('cannot be graphed'),
      findsOne,
      reason: 'a pre-v25 run says why it has no chart',
    );
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

  testWidgets('a study filter narrows every table on the page', (tester) async {
    // **The workspace's first end-to-end test** (§3.7). The field reported the
    // filter doing nothing; `run_filter.dart` is covered and correct, so what
    // this pins is the wiring between the filter and what is on screen.
    final run = twoStudyRun();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          simRunInputProvider(project.id).overrideWith(
            (ref) async => input(
              readiness: const [
                StudyReadiness(
                  studyId: 'study-1',
                  name: 'Celula 11B',
                  problems: [],
                ),
              ],
            ),
          ),
          simulationRunnerProvider(
            project.id,
          ).overrideWith(() => _StubRunner(run)),
          projectRunsProvider(
            project.id,
          ).overrideWith((ref) => Stream.value(const [])),
          studiesProvider(
            project.id,
          ).overrideWith((ref) => Stream.value(const [])),
          plantLinesProvider(
            project.plantId,
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SimulationWorkspace(
              project: project,
              // Arriving from a study drives the same filter the picker sets,
              // and states the expectation without a menu interaction.
              initialStudyId: 'study-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Two orders in the run, one in the study. Every figure on the page is
    // supposed to be about the slice, so the other study's section heading must
    // not be on it — and the headline must count one order, not two.
    expect(find.text('Celula 12A'), findsNothing);
    expect(find.textContaining('1 of 1'), findsWidgets);
  });

  testWidgets('the production plan lists the slice, not the whole run', (
    tester,
  ) async {
    // **The bug the field reported.** `FilteredRun` has carried a correctly
    // filtered plan since the combined view was built, and the table read
    // `run.plan` instead — so the largest table on the page ignored the filter
    // while the headline above it obeyed, and the page disagreed with itself.
    final run = twoStudyPlanRun();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          simRunInputProvider(project.id).overrideWith(
            (ref) async => input(
              readiness: const [
                StudyReadiness(
                  studyId: 'study-1',
                  name: 'Celula 11B',
                  problems: [],
                ),
              ],
            ),
          ),
          simulationRunnerProvider(
            project.id,
          ).overrideWith(() => _StubRunner(run)),
          projectRunsProvider(
            project.id,
          ).overrideWith((ref) => Stream.value(const [])),
          studiesProvider(
            project.id,
          ).overrideWith((ref) => Stream.value(const [])),
          plantLinesProvider(
            project.plantId,
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SimulationWorkspace(
              project: project,
              initialStudyId: 'study-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // One study's part number is on the plan and the other's is not. Both rows
    // exist in `run.plan`; only one belongs to the slice.
    expect(find.text('KEPT-1'), findsWidgets);
    expect(find.text('DROPPED-2'), findsNothing);
  });

  testWidgets('checking a study in the picker narrows the page', (
    tester,
  ) async {
    // **Through the control, not around it.** The test above sets the filter
    // from the route and proves the plumbing; the field says the picker still
    // does nothing, so this drives the picker.
    //
    // **The names come off the run, not off `studiesProvider`** (§7.6). The
    // overrides below are what the screen around the bar needs; the picker
    // itself reads `run.studies`, which is why this taps the accented `Célula
    // 11B` the run recorded rather than the plain one the project has today.
    // That is §7.10 working as intended: a run says what it was made of.
    final run = twoStudyPlanRun();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          simRunInputProvider(project.id).overrideWith(
            (ref) async => input(
              readiness: const [
                StudyReadiness(
                  studyId: 'study-1',
                  name: 'Celula 11B',
                  problems: [],
                ),
              ],
            ),
          ),
          simulationRunnerProvider(
            project.id,
          ).overrideWith(() => _StubRunner(run)),
          projectRunsProvider(
            project.id,
          ).overrideWith((ref) => Stream.value(const [])),
          // The picker offers the project's live studies, so this is what
          // decides whether the menu has anything in it at all.
          studiesProvider(project.id).overrideWith(
            (ref) => Stream.value([
              Study(
                id: 'study-1',
                projectId: project.id,
                productionCellId: 'cell-1',
                productionLineId: 'line-1',
                name: 'Celula 11B',
                includeInSimulation: true,
                startBufferDays: 0,
                createdAt: now,
                updatedAt: now,
              ),
              Study(
                id: 'study-2',
                projectId: project.id,
                productionCellId: 'cell-1',
                productionLineId: 'line-2',
                name: 'Celula 12A',
                includeInSimulation: true,
                startBufferDays: 0,
                createdAt: now,
                updatedAt: now,
              ),
            ]),
          ),
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

    // Unfiltered: both studies' parts are on the plan.
    expect(find.text('KEPT-1'), findsWidgets);
    expect(find.text('DROPPED-2'), findsWidgets);

    // Open the Studies picker and check the first study.
    await tester.tap(find.textContaining('Studies'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Célula 11B'));
    await tester.pumpAndSettle();

    expect(find.text('KEPT-1'), findsWidgets);
    expect(find.text('DROPPED-2'), findsNothing);
  });

  /// §7.5's three, driven through their controls.
  ///
  /// `run_filter_test` asserts what they *mean*; these assert that the bar is
  /// wired to them — which is the half the field reported missing the last time
  /// a picker was added and did nothing.
  group('the project, part and order filters (§7.5)', () {
    /// The two-study plan run with the two orders booked to different customer
    /// projects, and one left unbooked would be a third study — so this keeps
    /// to two and the unbooked case stays in `run_filter_test`.
    /// **Its metrics and its plan agree about the part numbers**, which
    /// `twoStudyPlanRun` deliberately does not: that one calls both parts `PN2`
    /// in the metrics to exercise §8.1.2's Study column while naming them
    /// differently on the plan. A part filter reads the metrics and the plan
    /// table shows the plan, so a fixture where the two disagree can only assert
    /// its own inconsistency. `loadRun` builds both from one set of rows.
    StoredRun bookedPlanRun() {
      final base = twoStudyPlanRun();
      const numbers = {'part-1': 'KEPT-1', 'part-2': 'DROPPED-2'};
      return StoredRun(
        id: base.id,
        projectId: base.projectId,
        createdAt: base.createdAt,
        queues: base.queues,
        studies: base.studies,
        result: base.result,
        metrics: summariseRun(
          result: base.result,
          partNumbers: numbers,
          workcenterNames: const {'wc-1': 'CLAD04'},
          theoreticalByOrder: const {},
        ),
        plan: [
          for (final row in base.plan.orders)
            ProductionPlanRow(
              outcome: row.outcome,
              partNumber: numbers[row.outcome.partId]!,
              partDescription: row.partDescription,
              customerProject: row.outcome.studyId == 'study-1'
                  ? 'MANIFOLD'
                  : 'Global 23',
              batchNumber: row.batchNumber,
              batchSize: row.batchSize,
              materialDate: row.materialDate,
              theoreticalLeadTime: row.theoreticalLeadTime,
            ),
        ],
      );
    }

    /// The booked run with a step per order, so the Gantt has something to
    /// draw. `twoStudyRun` carries no steps — right for the tables, and it makes
    /// the chart empty, which is the one thing a test about the chart cannot
    /// use.
    StoredRun bookedSteppedRun() {
      final base = bookedPlanRun();
      final result = SimRunResult(
        start: base.result.start,
        end: base.result.end,
        guard: base.result.guard,
        orders: base.result.orders,
        steps: [
          for (final outcome in base.result.orders)
            SimOrderStep(
              studyId: outcome.studyId,
              orderId: outcome.orderId,
              nodeId: 'node-1',
              workcenterId: 'wc-1',
              queueStart: DateTime(2026, 8, 3),
              processStart: DateTime(2026, 8, 4),
              processEnd: DateTime(2026, 8, 5),
              changeoverIncurred: false,
            ),
        ],
        emptySlots: const [],
        busyByWorkcenter: base.result.busyByWorkcenter,
        openByWorkcenter: base.result.openByWorkcenter,
      );

      return StoredRun(
        id: base.id,
        projectId: base.projectId,
        createdAt: base.createdAt,
        queues: base.queues,
        studies: base.studies,
        result: result,
        plan: base.plan,
        metrics: summariseRun(
          result: result,
          partNumbers: const {'part-1': 'KEPT-1', 'part-2': 'DROPPED-2'},
          workcenterNames: const {'wc-1': 'CLAD04'},
          theoreticalByOrder: const {},
        ),
      );
    }

    Future<void> pumpBooked(WidgetTester tester) => pump(
      tester,
      assembled: input(
        readiness: const [
          StudyReadiness(studyId: 'study-1', name: 'Celula 11B', problems: []),
        ],
      ),
      run: bookedPlanRun(),
    );

    testWidgets('checking a project narrows the page', (tester) async {
      await pumpBooked(tester);

      expect(find.text('KEPT-1'), findsWidgets);
      expect(find.text('DROPPED-2'), findsWidgets);

      await openPicker(tester, 'Projects');
      // **Through the menu item, not through the text.** The plan table has a
      // Project column, so `MANIFOLD` is on screen twice and the plain finder
      // was tapping a table cell — a filter that never applied, failing as
      // though the wiring were wrong.
      await tester.tap(find.widgetWithText(CheckboxMenuButton, 'MANIFOLD'));
      await tester.pumpAndSettle();

      expect(find.text('KEPT-1'), findsWidgets);
      expect(find.text('DROPPED-2'), findsNothing);
    });

    testWidgets('the projects offered are the run s, not the plant s', (
      tester,
    ) async {
      await pumpBooked(tester);

      await openPicker(tester, 'Projects');

      // Both, and nothing else — in particular no `(no project)`, because every
      // order in this run is booked to one.
      expect(find.widgetWithText(CheckboxMenuButton, 'MANIFOLD'), findsOne);
      expect(find.widgetWithText(CheckboxMenuButton, 'Global 23'), findsOne);
      expect(
        find.widgetWithText(CheckboxMenuButton, '(no project)'),
        findsNothing,
      );
    });

    testWidgets('checking a part number narrows the page', (tester) async {
      await pumpBooked(tester);

      await openPicker(tester, 'Part numbers');
      await tester.tap(find.widgetWithText(CheckboxMenuButton, 'KEPT-1'));
      await tester.pumpAndSettle();

      // **Close it before looking.** The menu deliberately stays open so several
      // can be ticked in one visit, and `DROPPED-2` is one of its own entries —
      // so asserting over the whole tree with it open is asserting about the
      // menu rather than about the page under it.
      await openPicker(tester, 'Part numbers');

      expect(find.text('DROPPED-2'), findsNothing);
      expect(find.text('KEPT-1'), findsWidgets);
    });

    testWidgets('typing an order number narrows the page, and one number is '
        'two orders', (tester) async {
      // Both orders in this run are `sequence: 0`, so both are order 1 — the
      // collision §7.5 found in the database, reproduced in a fixture.
      await pumpBooked(tester);

      await tester.enterText(find.byKey(orderFilterFieldKey), '1');
      await tester.pumpAndSettle();

      // One number, both studies' orders — and the field says why.
      expect(find.text('KEPT-1'), findsWidgets);
      expect(find.text('DROPPED-2'), findsWidgets);
      expect(find.textContaining('repeat in every study'), findsOne);

      // Order 2 is nobody, and an empty slice is empty rather than whole.
      await tester.enterText(find.byKey(orderFilterFieldKey), '2');
      await tester.pumpAndSettle();

      expect(find.text('KEPT-1'), findsNothing);
      expect(find.text('DROPPED-2'), findsNothing);
    });

    testWidgets('filtering while reading the Gantt stays on the Gantt', (
      tester,
    ) async {
      // **The field: "when I'm in the gantt view and filter something it goes
      // back to the results".** `RunResults` was keyed on the slice signature,
      // so every filter change threw its state away — including which of the two
      // views the reader had chosen. The zoom that key existed to reset is reset
      // by `GanttView.didUpdateWidget` anyway, which compares the same
      // signature.
      await pumpBooked(tester);

      // `IndexedStack.index` is the view: 0 results, 1 Gantt. Both children are
      // built either way, so nothing found by type could tell them apart.
      int? shownView() =>
          tester.widget<IndexedStack>(find.byType(IndexedStack).first).index;

      expect(shownView(), 0);

      await tester.tap(find.text('Gantt'));
      await tester.pumpAndSettle();
      expect(shownView(), 1);

      await openPicker(tester, 'Projects');
      await tester.tap(find.widgetWithText(CheckboxMenuButton, 'MANIFOLD'));
      await tester.pumpAndSettle();

      expect(shownView(), 1);
    });

    testWidgets('a project filter alone rebuilds the Gantt', (tester) async {
      // **The field: the three "only work when a single study is filtered".**
      // Every table moved and the chart did not, because `FilteredRun.signature`
      // read back through a filter holding the picker's live set — so the slice
      // being replaced reported the identity of the slice replacing it, and
      // `GanttView.didUpdateWidget` returned early. The study segment was the
      // only one built fresh, which is why touching Studies appeared to fix it.
      //
      // Asserted on the painter because the bars are painted: there is no widget
      // per bar for a finder to reach.
      await pump(
        tester,
        assembled: input(
          readiness: const [
            StudyReadiness(
              studyId: 'study-1',
              name: 'Celula 11B',
              problems: [],
            ),
          ],
        ),
        run: bookedSteppedRun(),
      );

      await tester.tap(find.text('Gantt'));
      await tester.pumpAndSettle();

      Set<String> partsDrawn() =>
          (tester.widget<CustomPaint>(find.byKey(ganttCanvasKey)).painter!
                  as GanttPainter)
              .layout
              .chart
              .parts
              .map((p) => p.partNumber)
              .toSet();

      expect(partsDrawn(), {'KEPT-1', 'DROPPED-2'});

      // No study touched — only a project.
      await openPicker(tester, 'Projects');
      await tester.tap(find.widgetWithText(CheckboxMenuButton, 'MANIFOLD'));
      await tester.pumpAndSettle();

      expect(partsDrawn(), {'KEPT-1'});
    });

    testWidgets('clearing the filters empties the order field too', (
      tester,
    ) async {
      await pumpBooked(tester);

      await tester.enterText(find.byKey(orderFilterFieldKey), '2');
      await tester.pumpAndSettle();
      expect(find.text('KEPT-1'), findsNothing);

      await tester.ensureVisible(find.text('Clear filters'));
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      // The text went with the filter. A field still reading `2` over an
      // unfiltered page is the two-write-paths disagreement §12.6 warns about,
      // one level down.
      expect(find.text('KEPT-1'), findsWidgets);
      expect(find.text('DROPPED-2'), findsWidgets);
    });
  });
}

/// A runner that reports one stored run and never touches a database.
class _StubRunner extends SimulationRunner {
  _StubRunner(this._run);

  final StoredRun? _run;

  @override
  Future<StoredRun?> build(String projectId) async => _run;
}


/// The plan's order rows, for tests that are about orders (§8.5).
///
/// The plan carries empty release slots too since they became rows; a test
/// asserting on part numbers wants the orders, and saying so is better than
/// indexing past a slot.
extension PlanOrders on List<PlanEntry> {
  List<ProductionPlanRow> get orders => whereType<ProductionPlanRow>().toList();
}
