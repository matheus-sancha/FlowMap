import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/database.dart';
import '../../../data/database/database_providers.dart';
import '../../projects/application/projects_providers.dart';
import '../../resources/application/resources_providers.dart';
import '../../studies/application/studies_providers.dart';
import '../data/demand_repository.dart';
import 'demand_table.dart';

part 'demand_providers.g.dart';

@riverpod
DemandRepository demandRepository(Ref ref) =>
    DemandRepository(ref.watch(appDatabaseProvider));

// Hand-written, not generated: riverpod_generator cannot emit a provider whose
// return type is a Drift class from the same build pass.

final demandPartsProvider = StreamProvider.family<List<DemandPart>, String>(
  (ref, studyId) => ref.watch(demandRepositoryProvider).watchParts(studyId),
);

final demandOrdersProvider = StreamProvider.family<List<DemandOrder>, String>(
  (ref, studyId) => ref.watch(demandRepositoryProvider).watchOrders(studyId),
);

final processTimesProvider =
    StreamProvider.family<Map<String, Map<String, Duration>>, String>(
      (ref, studyId) =>
          ref.watch(demandRepositoryProvider).watchProcessTimes(studyId),
    );

/// The part whose numbers the map shows under [FlowDataSource.singlePart].
///
/// Null means "the first one", resolved where the list is known — keeping a
/// concrete id here would go stale the moment that part was deleted.
@riverpod
class SelectedDemandPart extends _$SelectedDemandPart {
  @override
  String? build(String studyId) => null;

  void select(String? partId) => state = partId;
}

/// The demand grid: the study's parts, the flow's current steps as columns, and
/// the times between them.
///
/// Assembled from the nodes and the resource names rather than from the flow
/// view. The map now reads *this* to show a real part (§5.4), so watching the
/// view here would close a provider cycle.
final demandTableProvider = Provider.family<DemandTable?, String>((
  ref,
  studyId,
) {
  final study = ref.watch(studyProvider(studyId)).value;
  if (study == null) return null;

  final project = ref.watch(projectProvider(study.projectId)).value;
  if (project == null) return null;

  final nodes = ref.watch(flowNodesProvider(studyId)).value;
  final parts = ref.watch(demandPartsProvider(studyId)).value;
  final times = ref.watch(processTimesProvider(studyId)).value;
  final workcenters = ref.watch(workcentersProvider(project.plantId)).value;
  final pools = ref.watch(poolsProvider(project.plantId)).value;
  if (nodes == null ||
      parts == null ||
      times == null ||
      workcenters == null ||
      pools == null) {
    return null;
  }

  return DemandTable(
    parts: parts,
    columns: demandColumnsOf(
      nodes: nodes,
      workcenterNames: {for (final w in workcenters) w.id: w.name},
      poolNames: {for (final p in pools) p.id: p.name},
    ),
    times: times,
  );
});
