import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/database.dart';
import '../../../data/database/database_providers.dart';
import '../data/resources_repository.dart';

part 'resources_providers.g.dart';

@riverpod
ResourcesRepository resourcesRepository(Ref ref) =>
    ResourcesRepository(ref.watch(appDatabaseProvider));

// The stream providers below are hand-written rather than generated. Both
// riverpod_generator and drift_dev run in the same build_runner pass, and the
// ordering between builders is not guaranteed — so a generated provider whose
// return type is a Drift class (`Plant`, `Workcenter`, …) cannot be emitted
// reliably. The generator only inspects @riverpod-annotated elements, so these
// are invisible to it. Do not "fix" them back.

final plantsProvider = StreamProvider<List<Plant>>(
  (ref) => ref
      .watch(resourcesRepositoryProvider)
      .watchPlants(includeArchived: ref.watch(showArchivedProvider)),
);

final cellsProvider = StreamProvider.family<List<ProductionCell>, String>(
  (ref, plantId) => ref
      .watch(resourcesRepositoryProvider)
      .watchCells(plantId, includeArchived: ref.watch(showArchivedProvider)),
);

final plantLinesProvider = StreamProvider.family<List<PlantLine>, String>(
  (ref, plantId) => ref
      .watch(resourcesRepositoryProvider)
      .watchPlantLines(
        plantId,
        includeArchived: ref.watch(showArchivedProvider),
      ),
);

final workcentersProvider = StreamProvider.family<List<Workcenter>, String>(
  (ref, plantId) => ref
      .watch(resourcesRepositoryProvider)
      .watchWorkcenters(
        plantId,
        includeArchived: ref.watch(showArchivedProvider),
      ),
);

final workcenterTypesProvider = StreamProvider<List<WorkcenterType>>(
  (ref) => ref
      .watch(resourcesRepositoryProvider)
      .watchWorkcenterTypes(includeArchived: ref.watch(showArchivedProvider)),
);

final poolsProvider = StreamProvider.family<List<WorkcenterPool>, String>(
  (ref, plantId) => ref
      .watch(resourcesRepositoryProvider)
      .watchPools(plantId, includeArchived: ref.watch(showArchivedProvider)),
);

final poolMembershipProvider =
    StreamProvider.family<Map<String, List<String>>, String>(
      (ref, plantId) =>
          ref.watch(resourcesRepositoryProvider).watchPoolMembership(plantId),
    );

final poolMembersProvider = StreamProvider.family<List<Workcenter>, String>(
  (ref, poolId) =>
      ref.watch(resourcesRepositoryProvider).watchPoolMembers(poolId),
);

final shiftPatternsProvider = StreamProvider<List<ShiftPattern>>(
  (ref) => ref
      .watch(resourcesRepositoryProvider)
      .watchShiftPatterns(includeArchived: ref.watch(showArchivedProvider)),
);

final patternShiftsProvider = StreamProvider.family<List<PatternShift>, String>(
  (ref, patternId) =>
      ref.watch(resourcesRepositoryProvider).watchPatternShifts(patternId),
);

/// Whether archived resources are listed.
///
/// Archiving would otherwise be one-way: a row that leaves every list has no
/// affordance left to restore it. One toggle covers every list at once, which
/// is why the stream providers above all read it rather than taking a flag.
@riverpod
class ShowArchived extends _$ShowArchived {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// The plant the Resources screen is showing.
///
/// A project specifies one plant (DESIGN.md §3), but Resources spans them all,
/// so the screen needs its own selection. Null means "the first one", resolved
/// where it is read so the initial load needs no write.
@riverpod
class SelectedPlant extends _$SelectedPlant {
  @override
  String? build() => null;

  void select(String? plantId) => state = plantId;
}
