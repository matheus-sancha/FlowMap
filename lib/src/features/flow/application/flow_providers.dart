import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/database.dart';
import '../../../data/database/database_providers.dart';
import '../../calendar/application/shift_pattern_spec.dart' show dateOnly;
import '../../demand/application/demand_providers.dart';
import '../../projects/application/projects_providers.dart';
import '../../resources/application/resources_providers.dart';
import '../../schedules/application/schedules_providers.dart';
import '../../studies/application/studies_providers.dart';
import '../data/flow_queues_repository.dart';
import 'flow_view.dart';

part 'flow_providers.g.dart';

/// The queue in front of each dispatch target, for one project (§7.3).
final flowQueuesRepositoryProvider = Provider(
  (ref) => FlowQueuesRepository(ref.watch(appDatabaseProvider)),
);

/// Every queue the project has, by target — a workcenter id or a pool id.
///
/// Watched whole rather than per step: two studies through CLAD07 read the same
/// row, and a per-target family would open one subscription per box on the map.
final projectQueuesProvider =
    StreamProvider.family<Map<String, ProjectQueue>, String>(
      (ref, projectId) =>
          ref.watch(flowQueuesRepositoryProvider).watchQueues(projectId),
    );

/// The span the map is showing, and how wide it is.
class ViewedPeriodState {
  const ViewedPeriodState(this.anchor, this.granularity);

  /// The first day of the span.
  final DateTime anchor;
  final PeriodGranularity granularity;
}

/// The period the map is showing (`Aug 2026`, `Q3 2026`, `2026`).
///
/// Every derived number on the map is period-dependent — takt, staffing,
/// availability — so the map needs a span to be about. Kept per study so
/// switching between two studies does not reset the other's period.
@riverpod
class ViewedPeriod extends _$ViewedPeriod {
  @override
  ViewedPeriodState build(String studyId) => ViewedPeriodState(
    PeriodGranularity.month.startOf(DateTime.now()),
    PeriodGranularity.month,
  );

  /// Keeps the moment in view when the width changes: switching from `Aug 2026`
  /// to quarters lands on `Q3 2026`, not on January.
  void setGranularity(PeriodGranularity granularity) =>
      state = ViewedPeriodState(granularity.startOf(state.anchor), granularity);

  void previous() => state = ViewedPeriodState(
    state.granularity.shift(state.anchor, -1),
    state.granularity,
  );

  void next() => state = ViewedPeriodState(
    state.granularity.shift(state.anchor, 1),
    state.granularity,
  );
}

/// Which numbers the process boxes show.
///
/// The flow equivalent is the default because it is the only one that needs no
/// demand: a study opens showing something true about its own capacity before
/// a single part has been typed.
@riverpod
class FlowDataSourceSelection extends _$FlowDataSourceSelection {
  @override
  FlowDataSource build(String studyId) => FlowDataSource.flowEquivalent;

  void select(FlowDataSource source) => state = source;
}

/// A batch size typed on the Flow toolbar, or null to follow the demand table.
///
/// **Null is a real state rather than a missing one.** It means "whatever this
/// part's orders actually use", so switching parts follows the new part instead
/// of carrying the last one's lot across — and typing a number is the lot-sizing
/// experiment §7.6 says Batch Size exists to be. Held in memory per study, like
/// the period and the data source: it is a question being asked of the map, not
/// a property of the study.
@riverpod
class FlowBatchOverride extends _$FlowBatchOverride {
  @override
  int? build(String studyId) => null;

  void set(int? batch) => state = batch;
}

/// The batch the selected part's orders actually use.
///
/// **The most common one**, not the first and not the mean: a part ordered in
/// tens with one sample of one should read ten. Ties break to the larger, which
/// is the more conservative statement of what a station is occupied for.
int modalBatchSize(Iterable<int> batches) {
  final counts = <int, int>{};
  for (final batch in batches) {
    if (batch >= 1) counts[batch] = (counts[batch] ?? 0) + 1;
  }
  if (counts.isEmpty) return 1;
  var best = 1;
  var bestCount = 0;
  for (final entry in counts.entries) {
    if (entry.value > bestCount ||
        (entry.value == bestCount && entry.key > best)) {
      best = entry.key;
      bestCount = entry.value;
    }
  }
  return best;
}

/// What the map reads out of the demand table for a study at one period.
///
/// Empty under [FlowDataSource.flowEquivalent] — assembling a mix nothing will
/// read would make every map redraw on every demand edit.
final flowDemandProvider = Provider.family<FlowDemandInput, String>((
  ref,
  studyId,
) {
  final source = ref.watch(flowDataSourceSelectionProvider(studyId));
  if (!source.isDemandPart) return const FlowDemandInput();

  final table = ref.watch(demandTableProvider(studyId));
  if (table == null) return const FlowDemandInput();

  // Null means "the first part", resolved here rather than stored, so a
  // deleted part cannot leave the map pointing at nothing.
  final selectedId = ref.watch(selectedDemandPartProvider(studyId));
  final selected =
      table.parts.where((p) => p.id == selectedId).firstOrNull ??
      table.parts.firstOrNull;

  final period = ref.watch(viewedPeriodProvider(studyId));
  final start = period.granularity.startOf(period.anchor);
  final end = period.granularity.endOf(period.anchor);

  // Pieces, not orders: process times are per piece (§7.6), so an order of ten
  // weighs ten times as much in the mix as one of one.
  final pieces = <String, int>{};
  if (source == FlowDataSource.weightedVariants) {
    for (final order in ref.watch(demandOrdersProvider(studyId)).value ??
        const <DemandOrder>[]) {
      final due = dateOnly(order.needDate);
      if (due.isBefore(start) || due.isAfter(end)) continue;
      pieces[order.partId] = (pieces[order.partId] ?? 0) + order.batchSize;
    }
  }

  // One order's worth, because that is what a run charges and what §7.9 walks.
  // The flow equivalent stays one piece: its dummy part *is* one piece (§6.1),
  // and multiplying a takt by a lot size would state a cadence no line runs at.
  final orders = ref.watch(demandOrdersProvider(studyId)).value ??
      const <DemandOrder>[];
  final batch = source == FlowDataSource.singlePart
      ? (ref.watch(flowBatchOverrideProvider(studyId)) ??
            modalBatchSize([
              for (final order in orders)
                if (order.partId == selected?.id) order.batchSize,
            ]))
      : (ref.watch(flowBatchOverrideProvider(studyId)) ??
            modalBatchSize([for (final order in orders) order.batchSize]));

  return FlowDemandInput(
    processTimes: table.times,
    piecesDueInPeriod: pieces,
    selectedPartId: selected?.id,
    selectedPartNumber: selected?.partNumber,
    batchSize: batch,
  );
});

/// The assembled map.
///
/// Watches every stream that can change a number on it — the flow itself, the
/// schedules, the takt, the resource rows and the exceptions — then does the
/// asynchronous gathering of calendars in one pass. Anything the user edits
/// anywhere redraws the map, with no manual invalidation.
final flowViewProvider = FutureProvider.family<FlowView?, String>((
  ref,
  studyId,
) async {
  final study = ref.watch(studyProvider(studyId)).value;
  if (study == null) return null;

  final project = ref.watch(projectProvider(study.projectId)).value;
  if (project == null) return null;

  final nodes = ref.watch(flowNodesProvider(studyId)).value;
  if (nodes == null) return null;

  // Watched purely so an edit to any of them rebuilds this provider. The
  // values themselves are re-read below through the repositories, which is
  // also where the calendars are assembled.
  ref.watch(projectSchedulesProvider(project.id));
  ref.watch(calendarExceptionsProvider(project.id));
  ref.watch(shiftPatternsProvider);

  final workcenters = ref.watch(workcentersProvider(project.plantId)).value;
  final pools = ref.watch(poolsProvider(project.plantId)).value;
  final membership = ref.watch(poolMembershipProvider(project.plantId)).value;
  final types = ref.watch(workcenterTypesProvider).value;
  if (workcenters == null ||
      pools == null ||
      membership == null ||
      types == null) {
    return null;
  }

  final taktPeriods = ref.watch(
    taktPeriodsProvider((
      projectId: project.id,
      productionLineId: study.productionLineId,
    )),
  );
  if (!taktPeriods.hasValue) return null;

  final queues = ref.watch(projectQueuesProvider(project.id)).value;
  if (queues == null) return null;

  final schedules = ref.watch(schedulesRepositoryProvider);
  final period = ref.watch(viewedPeriodProvider(studyId));
  final dataSource = ref.watch(flowDataSourceSelectionProvider(studyId));
  final demand = ref.watch(flowDemandProvider(studyId));

  // Only the workcenters this map actually touches, directly or through a
  // pool — a plant may have fifty and a study ten.
  final needed = <String>{};
  for (final node in nodes) {
    if (node.workcenterId != null) needed.add(node.workcenterId!);
    if (node.poolId != null) needed.addAll(membership[node.poolId] ?? const []);
  }

  final byId = {for (final w in workcenters) w.id: w};
  final typeNames = {for (final t in types) t.id: t.name};
  final contexts = <String, WorkcenterContext>{};
  for (final id in needed) {
    final workcenter = byId[id];
    if (workcenter == null) continue;
    final calendar = await schedules.loadWorkcenterCalendar(
      projectId: project.id,
      workcenterId: id,
    );
    if (calendar == null) continue;
    contexts[id] = WorkcenterContext(
      workcenter: workcenter,
      calendar: calendar,
      schedule: await schedules.loadWorkcenterSchedule(project.id, id),
      typeName: typeNames[workcenter.typeId],
    );
  }

  return buildFlowView(
    study: study,
    nodes: nodes,
    contexts: contexts,
    pools: {for (final p in pools) p.id: p},
    poolMembers: membership,
    queues: queues,
    taktSchedule: await schedules.loadTaktSchedule(
      project.id,
      study.productionLineId,
    ),
    asOf: period.anchor,
    granularity: period.granularity,
    dataSource: dataSource,
    demand: demand,
  );
});

/// The workcenters and pools a step may target, for the step editor.
final flowTargetsProvider =
    FutureProvider.family<
      ({List<Workcenter> workcenters, List<WorkcenterPool> pools}),
      String
    >((ref, studyId) async {
      final study = ref.watch(studyProvider(studyId)).value;
      if (study == null) {
        return (workcenters: <Workcenter>[], pools: <WorkcenterPool>[]);
      }
      final project = ref.watch(projectProvider(study.projectId)).value;
      if (project == null) {
        return (workcenters: <Workcenter>[], pools: <WorkcenterPool>[]);
      }
      return (
        workcenters:
            ref.watch(workcentersProvider(project.plantId)).value ?? [],
        pools: ref.watch(poolsProvider(project.plantId)).value ?? [],
      );
    });
