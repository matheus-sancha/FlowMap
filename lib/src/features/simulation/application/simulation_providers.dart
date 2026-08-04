import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/database.dart';
import '../../../data/database/database_providers.dart';
import '../../demand/application/demand_providers.dart';
import '../../diagnostics/application/diagnostics.dart';
import '../../resources/application/resources_providers.dart';
import '../../schedules/application/schedules_providers.dart';
import '../../studies/application/studies_providers.dart';
import '../data/simulation_repository.dart';
import '../data/simulation_runs_repository.dart';
import 'engine.dart';
import 'sim_assembly.dart';
import 'sim_model.dart';
import 'sim_result.dart';

part 'simulation_providers.g.dart';

@riverpod
SimulationRepository simulationRepository(Ref ref) => SimulationRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(resourcesRepositoryProvider),
  ref.watch(schedulesRepositoryProvider),
  ref.watch(studiesRepositoryProvider),
  ref.watch(demandRepositoryProvider),
);

@riverpod
SimulationRunsRepository simulationRunsRepository(Ref ref) =>
    SimulationRunsRepository(ref.watch(appDatabaseProvider));

// Hand-written, not generated: riverpod_generator cannot emit a provider whose
// return type is a Drift class from the same build pass.

/// The studies flagged for the next run (DESIGN.md §10.1).
final flaggedStudiesProvider = StreamProvider.family<List<Study>, String>(
  (ref, projectId) =>
      ref.watch(studiesRepositoryProvider).watchFlaggedStudies(projectId),
);

/// The project's stored runs, newest first (§7.10).
final projectRunsProvider = StreamProvider.family<List<SimulationRun>, String>(
  (ref, projectId) =>
      ref.watch(simulationRunsRepositoryProvider).watchRuns(projectId),
);

/// Which rule the workcenters dispatch by (§7.4).
///
/// Per project and held in memory, not stored: it is the knob the experiment
/// turns, and a run records the rule it was made with, so the answer to "what
/// did EDD do here" lives on the run rather than on the project.
@riverpod
class DispatchRuleSelection extends _$DispatchRuleSelection {
  @override
  DispatchRule build(String projectId) => DispatchRule.fifo;

  void select(DispatchRule rule) => state = rule;
}

/// The assembled run, rebuilt whenever anything it reads changes (§11).
///
/// This is the readiness panel's source: it carries the problems as well as
/// the studies, so Simulate is disabled by the same pass that would have built
/// the run. Watching is deliberate and wide — a step rebound in the Flow tab
/// has to clear its error here without the user pressing anything.
final simRunInputProvider = FutureProvider.family<SimRunInput, String>((
  ref,
  projectId,
) async {
  final flagged = ref.watch(flaggedStudiesProvider(projectId)).value;
  if (flagged == null) return const SimRunInput.empty();

  // Watched purely so an edit to any of them reassembles. The values are
  // re-read through the repositories below, which is also where the calendars
  // are built.
  ref.watch(projectSchedulesProvider(projectId));
  ref.watch(calendarExceptionsProvider(projectId));
  ref.watch(shiftPatternsProvider);
  for (final study in flagged) {
    ref.watch(flowNodesProvider(study.id));
    ref.watch(demandOrdersProvider(study.id));
    ref.watch(processTimesProvider(study.id));
    ref.watch(
      taktPeriodsProvider((
        projectId: projectId,
        productionLineId: study.productionLineId,
      )),
    );
  }

  return ref.watch(simulationRepositoryProvider).assembleRun(projectId);
});

/// The run being looked at, and the button that makes a new one.
///
/// Opening the tab shows the run that was last made rather than an empty
/// screen — most of what storing a run buys (§7.10). Pressing Simulate stores
/// a new one, the list stream emits, and this rebuilds onto it.
@riverpod
class SimulationRunner extends _$SimulationRunner {
  @override
  Future<StoredRun?> build(String projectId) async {
    final runs = ref.watch(projectRunsProvider(projectId)).value;
    if (runs == null || runs.isEmpty) return null;
    return ref.read(simulationRunsRepositoryProvider).loadRun(runs.first.id);
  }

  /// Assembles, runs and stores. Does nothing if the run is not ready (§11) —
  /// the button is disabled for the same reason, and this is the guard behind
  /// it rather than a second opinion.
  Future<void> run() async {
    final assembled = await ref.read(simRunInputProvider(projectId).future);
    if (!assembled.canRun) return;

    final dispatch = ref.read(dispatchRuleSelectionProvider(projectId));
    final runs = ref.read(simulationRunsRepositoryProvider);

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final started = DateTime.now();
      // Off the UI isolate (§7.1). `SimStudy` and `SimWorkcenter` carry no
      // database handle precisely so they can cross — an isolate can only be
      // passed things that hold no open connection.
      final result = await compute(
        runSimulationOffThread,
        (
          studies: assembled.studies,
          workcenters: assembled.workcenters,
          dispatch: dispatch,
        ),
      );
      // The measurement §14 is still short of, recorded where a field report
      // will carry it (§16.9).
      Diag.event(
        'sim.run',
        '${assembled.studies.length} studies, ${result.orders.length} orders, '
            '${result.steps.length} steps in '
            '${DateTime.now().difference(started).inMilliseconds} ms'
            '${result.abort == null ? '' : ' — aborted: ${result.abort!.name}'}',
      );

      final id = await runs.saveRun(
        projectId: projectId,
        dispatch: dispatch,
        result: result,
        studies: assembled.studies,
        workcenters: assembled.workcenters,
      );
      return runs.loadRun(id);
    });
  }

  /// Shows an earlier run instead of the newest one.
  Future<void> show(String runId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(simulationRunsRepositoryProvider).loadRun(runId),
    );
  }

  Future<void> delete(String runId) =>
      ref.read(simulationRunsRepositoryProvider).deleteRun(runId);
}

/// What crosses to the background isolate.
typedef SimRunRequest = ({
  List<SimStudy> studies,
  Map<String, SimWorkcenter> workcenters,
  DispatchRule dispatch,
});

/// The run, on a background isolate (DESIGN.md §7.1).
///
/// Top-level and public for two reasons: `compute` needs a function that
/// closes over nothing, and whether these inputs can *cross* an isolate at all
/// is the one thing about the run that no in-process test would catch —
/// `SimStudy` and `SimWorkcenter` are plain values precisely so they can, and
/// a test calls this the same way the button does.
SimRunResult runSimulationOffThread(SimRunRequest request) => runSimulation(
  studies: request.studies,
  workcenters: request.workcenters,
  dispatch: request.dispatch,
);
