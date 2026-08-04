import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/database.dart';
import '../../../data/database/database_providers.dart';
import '../../flow/application/flow_providers.dart';
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

/// The demand grid: the study's parts, the flow's current steps as columns, and
/// the times between them.
///
/// Watches the flow view rather than the raw nodes, because a column's header
/// is the process box's own label — a step renamed on the map renames the
/// column, and the grid can never show a step the map does not.
final demandTableProvider = Provider.family<DemandTable?, String>((
  ref,
  studyId,
) {
  final view = ref.watch(flowViewProvider(studyId)).value;
  final parts = ref.watch(demandPartsProvider(studyId)).value;
  final times = ref.watch(processTimesProvider(studyId)).value;
  if (view == null || parts == null || times == null) return null;

  return DemandTable(
    parts: parts,
    columns: demandColumnsOf(view),
    times: times,
  );
});
