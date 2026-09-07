import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/database.dart';
import '../../../data/database/database_providers.dart';
import '../../demand/application/demand_providers.dart';
import '../../diagnostics/application/diagnostics.dart';
import '../../projects/application/projects_providers.dart';
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

/// The project's stored runs, newest first, each with what it dispatched by
/// (§7.10, §7.3).
final projectRunsProvider = StreamProvider.family<List<RunListing>, String>(
  (ref, projectId) =>
      ref.watch(simulationRunsRepositoryProvider).watchRuns(projectId),
);

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

  // **The plant itself, which this watched nothing of until §7.4 made it
  // load-bearing.** A workcenter's *type* is the identity a balance group is
  // formed on, so typing CLAD06 `Cladding` changes what every order costs at it
  // — and with none of these watched, the assembled input stayed cached and
  // Simulate silently re-ran the plant as it was before the edit. The map got it
  // right the whole time, because `flowViewProvider` has always watched these
  // four; the two surfaces disagreeing about one plant is exactly what §12.6
  // warns about.
  //
  // Watched rather than gated on: a null project is `assembleRun`'s own empty
  // case, and returning early here would make the readiness panel go blank
  // while the stream is still warming up.
  final project = ref.watch(projectProvider(projectId)).value;
  if (project != null) {
    ref.watch(workcentersProvider(project.plantId));
    ref.watch(poolsProvider(project.plantId));
    ref.watch(poolMembershipProvider(project.plantId));
  }
  ref.watch(workcenterTypesProvider);
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
    return ref
        .read(simulationRunsRepositoryProvider)
        .loadRun(runs.first.run.id);
  }

  /// Assembles, runs and stores. Does nothing if the run is not ready (§11) —
  /// the button is disabled for the same reason, and this is the guard behind
  /// it rather than a second opinion.
  Future<void> run() async {
    final assembled = await ref.read(simRunInputProvider(projectId).future);
    if (!assembled.canRun) return;

    final runs = ref.read(simulationRunsRepositoryProvider);

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final started = DateTime.now();
      // Off the UI isolate (§7.1). `SimStudy` and `SimWorkcenter` carry no
      // database handle precisely so they can cross — an isolate can only be
      // passed things that hold no open connection.
      final result = await compute(runSimulationOffThread, (
        studies: assembled.studies,
        workcenters: assembled.workcenters,
        scheduledStations: assembled.scheduledStations,
        scheduleHorizon: assembled.scheduleHorizon,
      ));
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
        result: result,
        studies: assembled.studies,
        // The union, not the resource model: the result now carries capacity
        // for scheduled stations the routings never reach (phase 9), and each
        // still has to be stored under its own name and type.
        workcenters: {
          ...assembled.workcenters,
          ...assembled.scheduledStations,
        },
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
  Map<String, SimWorkcenter> scheduledStations,
  DateTime? scheduleHorizon,
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
  scheduledStations: request.scheduledStations,
  scheduleHorizon: request.scheduleHorizon,
);
