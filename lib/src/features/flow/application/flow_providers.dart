import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/database.dart';
import '../../projects/application/projects_providers.dart';
import '../../resources/application/resources_providers.dart';
import '../../schedules/application/schedules_providers.dart';
import '../../studies/application/studies_providers.dart';
import 'flow_view.dart';

part 'flow_providers.g.dart';

/// The span the map is showing, and how wide it is.
class ViewedPeriodState {
  const ViewedPeriodState(this.anchor, this.granularity);

  /// The first day of the span.
  final DateTime anchor;
  final PeriodGranularity granularity;

  DateTime get end => granularity.endOf(anchor);
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
/// Only [FlowDataSource.flowEquivalent] is computable until the demand table
/// lands (M3); the others are offered but disabled, so the shape of the choice
/// is visible from the start.
@riverpod
class FlowDataSourceSelection extends _$FlowDataSourceSelection {
  @override
  FlowDataSource build(String studyId) => FlowDataSource.flowEquivalent;

  void select(FlowDataSource source) => state = source;
}

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

  final schedules = ref.watch(schedulesRepositoryProvider);
  final period = ref.watch(viewedPeriodProvider(studyId));
  final dataSource = ref.watch(flowDataSourceSelectionProvider(studyId));

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
    taktSchedule: await schedules.loadTaktSchedule(
      project.id,
      study.productionLineId,
    ),
    asOf: period.anchor,
    granularity: period.granularity,
    dataSource: dataSource,
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
