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
    this.cellNames = const {},
    this.lineNames = const {},
  });

  final Map<String, String> workcenterNames;
  final Map<String, String> poolNames;

  /// Cell and line id → name, so a study can copy where it sat into the run
  /// (§7.10) rather than leaving a filter to join back to the plant.
  ///
  /// Defaulted to empty because nothing the engine does depends on them: a run
  /// with no names still runs, and the filter simply falls back to the ids.
  final Map<String, String> cellNames;
  final Map<String, String> lineNames;

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
            // What the machines below are collectively called, where they are
            // a pool at all. `candidates` cannot say it, and §7.10's copy-in
            // rule needs it before the plant can be re-grouped underneath a
            // finished run.
            poolId: node.poolId,
            poolName: resources.poolNames[node.poolId],
            // Carried unresolved: `days` is a productive day of whichever
            // server ends up running the order, and a pool's members do not
            // share one (§7.6).
            setupValue: node.setupValue,
            setupUnit: node.setupUnit,
            teardownValue: node.teardownValue,
            teardownUnit: node.teardownUnit,
            // Stored as a percentage because that is how it is typed; the
            // engine wants a fraction, and converting here means the engine
            // never has to remember which of the two it is holding. Null is
            // 0 %, which is the free-repeat rule every study had before v17.
            samePartFraction: (node.samePartPercent ?? 0) / 100,
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
    // Copied in at assembly, so the run reports where the study sat *when it
    // ran* rather than where it sits when someone opens the result (§7.10).
    productionCellId: study.productionCellId,
    productionCellName: resources.cellNames[study.productionCellId],
    productionLineId: study.productionLineId,
    productionLineName: resources.lineNames[study.productionLineId],
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

/// Which pool each station was dispatched through in this run (DESIGN.md §3.1,
/// §7.10), for [SimulationRunWorkcenters] to copy in.
///
/// **A station can be reached through more than one pool.**
/// `WorkcenterPoolMembers` is keyed `{poolId, workcenterId}`, so with two
/// studies in one run line A can step on CLAD07 through `CAL` while line B
/// reaches it through `All Lathes`. There is no single right answer for that
/// station, and picking one arbitrarily would group three machines under a
/// heading that describes only some of their work.
///
/// So: **exactly one pool is a grouping; none or several is a label.**
/// [StationPool.id] is what the views group by and is null in both the other
/// cases; [StationPool.name] carries the pools it served so a reader can still
/// see why it is loose. A station named directly by every step that used it is
/// absent from the map entirely.
///
/// Pure, and over the model the run was built from rather than over the plant —
/// the plant can be re-grouped tomorrow and this run must keep saying what it
/// observed.
Map<String, StationPool> stationPools(List<SimStudy> studies) {
  // Ordered, so a station reached through two pools names them the same way
  // twice running and two runs of one project cannot disagree about a label.
  final byStation = <String, Map<String, String>>{};

  for (final study in studies) {
    for (final node in study.nodes) {
      if (node is! SimStep) continue;
      final id = node.poolId;
      if (id == null) continue;
      for (final workcenterId in node.candidates) {
        byStation.putIfAbsent(workcenterId, () => <String, String>{})[id] =
            node.poolName ?? id;
      }
    }
  }

  return {
    for (final entry in byStation.entries)
      if (entry.value.length == 1)
        entry.key: StationPool(
          id: entry.value.keys.first,
          name: entry.value.values.first,
        )
      else
        entry.key: StationPool(
          id: null,
          // Sorted rather than in encounter order: the studies arrive in
          // whatever order the project lists them, and a label that depends on
          // that would change under a rename.
          name: (entry.value.values.toList()..sort()).join(' · '),
        ),
  };
}
