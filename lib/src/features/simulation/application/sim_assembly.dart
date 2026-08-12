/// Turning a project's stored rows into what the engine can run (DESIGN.md §7).
///
/// Pure: it takes rows and specs and returns [SimStudy] values. The repository
/// beside it does the loading; keeping the resolution here means "what does a
/// quantity buffer become" and "how fast do slots come round" are unit tests
/// rather than questions you answer by running the app.
library;

import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../demand/application/demand_table.dart';
import '../../flow/application/flow_view.dart' show flowStepTitle;
import '../../schedules/application/takt_schedule.dart';
import 'sim_model.dart';

/// Why a study cannot be run.
enum SimAssemblyProblem {
  /// No takt covers the run's start, so there is no release cadence (§7.2).
  noTakt,

  /// The sequence is empty; there is nothing to release.
  noOrders,

  /// A step targets neither a workcenter nor a pool, or its pool is empty
  /// (§11). The engine will not guess where the work goes.
  unboundStep,

  /// No step of the flow can pace the releases — every one of them is unbound.
  noPaceSetter,
}

/// One study's standing to take part in a run (DESIGN.md §11).
///
/// Carried per study rather than as one flat list, because the panel has to
/// name which study is not ready — "a step has no workcenter" is not actionable
/// until you know whose step it is.
class StudyReadiness {
  const StudyReadiness({
    required this.studyId,
    required this.name,
    required this.problems,
  });

  final String studyId;
  final String name;
  final List<SimAssemblyProblem> problems;

  bool get isReady => problems.isEmpty;
}

/// A project's run, as far as the stored rows allow it to be built.
///
/// **One resource model of the plant** (§7.7): each workcenter appears once in
/// [workcenters] however many of the [studies] point at it, which is what makes
/// line A's orders genuinely delay line B's.
class SimRunInput {
  const SimRunInput({
    required this.studies,
    required this.workcenters,
    required this.readiness,
    this.scheduleHorizon,
  });

  const SimRunInput.empty()
    : studies = const [],
      workcenters = const {},
      readiness = const [],
      scheduleHorizon = null;

  /// The studies that assembled. A study with problems is absent here and
  /// present in [readiness] — the engine is never handed a half-built one.
  final List<SimStudy> studies;

  final Map<String, SimWorkcenter> workcenters;

  /// Every flagged study, ready or not, in the order the sidebar shows them.
  final List<StudyReadiness> readiness;

  /// The last date **every** schedule this run uses is actually defined for
  /// (§11.1), or null when nothing has periods at all.
  ///
  /// The minimum of each schedule's own last end date, not the maximum: past
  /// the earliest of them, at least one schedule is being carried forward, and
  /// that is the point from which the run stops describing a plant anyone has
  /// defined.
  final DateTime? scheduleHorizon;

  /// Whether Simulate may be pressed (§11).
  ///
  /// Every flagged study has to be ready, not merely one of them: a run the
  /// user asked for over three studies that quietly ran two would report a
  /// plant that was never contended for.
  bool get canRun =>
      studies.isNotEmpty && readiness.every((study) => study.isReady);

  /// Nothing is flagged for a run (§10.1). Distinct from "not ready" — there
  /// is nothing wrong, there is just nothing selected.
  bool get isEmpty => readiness.isEmpty;
}

/// Everything the assembler needs about the plant, gathered once by the caller.
class SimResourceContext {
  const SimResourceContext({
    required this.workcenterNames,
    required this.poolNames,
    required this.poolMembers,
    required this.productivePerWorkingDay,
  });

  final Map<String, String> workcenterNames;
  final Map<String, String> poolNames;

  /// Pool id → member workcenter ids, in a stable order.
  final Map<String, List<String>> poolMembers;

  /// `open × availability` for each workcenter, read at the run's start.
  ///
  /// A takt in days means productive days of a station (§6.1), so resolving one
  /// into a duration needs this. Read once rather than per slot: §18.3 leaves
  /// mid-flight takt changes open, and the engine currently runs at one
  /// cadence throughout.
  final Map<String, Duration> productivePerWorkingDay;
}

/// Builds one study's engine input.
///
/// Returns null when it cannot be run; [problems] then says why, so the
/// readiness panel can name the reason rather than the run failing silently.
SimStudy? assembleSimStudy({
  required Study study,
  required List<FlowNode> nodes,
  required List<DemandPart> parts,
  required Map<String, Map<String, Duration>> processTimes,
  required List<DemandOrder> orders,
  required TaktScheduleSpec taktSchedule,
  required SimResourceContext resources,
  required DateTime asOf,
  List<SimAssemblyProblem>? problems,
}) {
  void report(SimAssemblyProblem problem) => problems?.add(problem);

  if (orders.isEmpty) {
    report(SimAssemblyProblem.noOrders);
    return null;
  }

  final takt = taktSchedule.taktOn(asOf);
  if (takt == null) {
    report(SimAssemblyProblem.noTakt);
    return null;
  }

  final simNodes = <SimNode>[];
  for (final node in nodes) {
    switch (node.kind) {
      case FlowNodeKind.step:
        final candidates = _candidatesFor(node, resources);
        if (candidates.isEmpty) {
          report(SimAssemblyProblem.unboundStep);
          return null;
        }
        simNodes.add(
          SimStep(
            id: node.id,
            position: node.position,
            title: flowStepTitle(
              node,
              workcenterName: resources.workcenterNames[node.workcenterId],
              poolName: resources.poolNames[node.poolId],
            ),
            candidates: candidates,
            demandKey: demandTargetOf(node)!,
            changeover: Duration(seconds: node.changeoverSeconds),
          ),
        );

      case FlowNodeKind.inventory:
        simNodes.add(_buffer(node));
    }
  }

  // Which station's clock the takt's days are measured in, and therefore how
  // often a slot comes round (§7.2). It must be one station's clock, and it
  // must not depend on a period, because a run spans years while §8.2's
  // occupation is monthly.
  //
  // **The study may name it**; the busiest step by work content is only the
  // default. The pacemaker gained a second job when lanes got capacity — §7.2
  // gates a release on whether its queue has room — and a station chosen
  // silently by summing batch sizes would be a gate that moves to another
  // machine because someone edited the demand, and tells nobody (§18.8).
  //
  // Computed after the loop above, so a flow with an unbound step is reported
  // as unbound rather than as having nothing to pace it — the second is true
  // but it is not the thing to go and fix.
  final paceNode =
      _chosenPaceSetter(nodes, study.paceSetterTargetId) ??
      _paceSetter(
        nodes: nodes,
        orders: orders,
        processTimes: processTimes,
        resources: resources,
      );
  final paceSetter = paceNode == null
      ? null
      : _firstCandidate(paceNode, resources);
  if (paceSetter == null) {
    report(SimAssemblyProblem.noPaceSetter);
    return null;
  }

  return SimStudy(
    id: study.id,
    name: study.name,
    nodes: simNodes,
    parts: {
      for (final part in parts)
        part.id: SimPart(
          id: part.id,
          partNumber: part.partNumber,
          description: part.description,
          processTimes: processTimes[part.id] ?? const {},
        ),
    },
    orders: [
      for (final order in orders)
        SimOrder(
          id: order.id,
          sequence: order.sequence,
          partId: order.partId,
          batchSize: order.batchSize,
          batchNumber: order.batchNumber,
          customerProject: order.customerProject,
          needDate: order.needDate,
          materialDate: order.materialDate,
        ),
    ],
    releaseInterval: takt.equivalentAt(
      resources.productivePerWorkingDay[paceSetter] ?? Duration.zero,
    ),
    releaseCalendarId: paceSetter,
    paceSetterNodeId: paceNode!.id,
    // Calendar days, which is what the column stores and what every surface
    // showing it says (§7.8, §17.4).
    startBuffer: Duration(days: study.startBufferDays),
    priority: study.priority,
    wipCap: study.wipCap,
  );
}

/// The workcenters a step may run on, in a stable order.
List<String> _candidatesFor(FlowNode node, SimResourceContext resources) {
  if (node.poolId != null) {
    return [...?resources.poolMembers[node.poolId]]..sort();
  }
  final workcenterId = node.workcenterId;
  return workcenterId == null ? const [] : [workcenterId];
}

/// A lane, which a run governs by but does not time (§5.5).
///
/// Its stored figure — pieces of stock, or a wait in days — is an observation
/// of a current state, and how long an order really waits is the question the
/// run exists to answer. Neither `inventorySeconds` nor `inventoryQuantity` is
/// read here; both stay on the node for the map's lead-time ladder.
///
/// What *is* read is the discipline and the capacity, which are rules rather
/// than observations. `lane_capacity` is deliberately a different column from
/// `inventory_quantity` for exactly that reason — they share a unit and mean
/// opposite things (§16.16).
SimBuffer _buffer(FlowNode node) => SimBuffer(
  id: node.id,
  position: node.position,
  name: node.label,
  rule: node.laneRule,
  capacity: node.laneCapacity,
);

/// The step the study named as its pacemaker, or null when it named none — or
/// named one that is no longer in the flow.
///
/// Falling back to the derivation rather than refusing to run: a study whose
/// pacemaker was deleted from the map still has a defensible cadence, and
/// stopping the run over it would make a node deletion look like a broken
/// study. The readiness panel has nothing to add that the Flow tab does not
/// already show by not highlighting anything.
FlowNode? _chosenPaceSetter(List<FlowNode> nodes, String? targetId) {
  if (targetId == null) return null;
  for (final node in nodes) {
    if (node.kind != FlowNodeKind.step) continue;
    if ((node.poolId ?? node.workcenterId) == targetId) return node;
  }
  return null;
}

/// The step whose work content across the whole demand is largest.
///
/// Returns the **node** rather than the workcenter it targets, because the
/// pacemaker is now a place in the flow as well as a clock: §7.2 gates a
/// release on the room in the lane in front of it, and a workcenter id cannot
/// say which of two appearances of one machine is meant.
FlowNode? _paceSetter({
  required List<FlowNode> nodes,
  required List<DemandOrder> orders,
  required Map<String, Map<String, Duration>> processTimes,
  required SimResourceContext resources,
}) {
  final work = <FlowNode, int>{};
  FlowNode? fallback;

  for (final node in nodes) {
    if (node.kind != FlowNodeKind.step) continue;
    if (_firstCandidate(node, resources) == null) continue;
    fallback ??= node;

    final key = demandTargetOf(node);
    if (key == null) continue;
    var total = 0;
    for (final order in orders) {
      final stored = processTimes[order.partId]?[key];
      if (stored != null) total += stored.inSeconds * order.batchSize;
    }
    work[node] = (work[node] ?? 0) + total;
  }

  if (work.isEmpty) return fallback;
  // Ties break by position, so two identically loaded steps do not make two
  // runs of the same study disagree (§4.4). Position rather than workcenter id
  // because the node is what is being chosen — and a step's position is the one
  // thing about it that is unique within a study by construction (§5.1).
  final best = work.entries.reduce(
    (a, b) =>
        b.value > a.value ||
            (b.value == a.value && b.key.position < a.key.position)
        ? b
        : a,
  );
  return best.value == 0 ? fallback : best.key;
}

String? _firstCandidate(FlowNode node, SimResourceContext resources) =>
    _candidatesFor(node, resources).firstOrNull;
