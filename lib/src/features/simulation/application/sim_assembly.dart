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
  });

  const SimRunInput.empty()
    : studies = const [],
      workcenters = const {},
      readiness = const [];

  /// The studies that assembled. A study with problems is absent here and
  /// present in [readiness] — the engine is never handed a half-built one.
  final List<SimStudy> studies;

  final Map<String, SimWorkcenter> workcenters;

  /// Every flagged study, ready or not, in the order the sidebar shows them.
  final List<StudyReadiness> readiness;

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
        simNodes.add(
          _buffer(
            node: node,
            nodes: nodes,
            takt: takt,
            resources: resources,
          ),
        );
    }
  }

  // Which station's clock the takt's days are measured in, and therefore how
  // often a slot comes round (§7.2). The busiest step by work content across
  // the whole demand: it must be one station's clock, and it must not depend
  // on a period, because a run spans years while §8.2's occupation is monthly.
  //
  // Computed after the loop above, so a flow with an unbound step is reported
  // as unbound rather than as having nothing to pace it — the second is true
  // but it is not the thing to go and fix.
  final paceSetter = _paceSetter(
    nodes: nodes,
    orders: orders,
    processTimes: processTimes,
    resources: resources,
  );
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
          needDate: order.needDate,
          materialDate: order.materialDate,
        ),
    ],
    releaseInterval: takt.equivalentAt(
      resources.productivePerWorkingDay[paceSetter] ?? Duration.zero,
    ),
    releaseCalendarId: paceSetter,
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

/// A buffer's wait, resolved before the run (§5.5).
///
/// A fixed wait is what it says. A quantity buffer is `pieces × takt`, and the
/// takt is resolved on the day of the **step it drains into** — stock leaves at
/// the rate the next station consumes it.
SimBuffer _buffer({
  required FlowNode node,
  required List<FlowNode> nodes,
  required TaktPeriodSpec takt,
  required SimResourceContext resources,
}) {
  if (node.inventoryMode == InventoryMode.duration) {
    return SimBuffer(
      id: node.id,
      position: node.position,
      wait: Duration(seconds: node.inventorySeconds ?? 0),
      usesWorkingTime: node.inventoryUsesWorkingTime,
    );
  }

  final downstream = _nextStep(nodes, node.position);
  final target = downstream == null ? null : _firstCandidate(downstream, resources);
  final productive = resources.productivePerWorkingDay[target] ?? Duration.zero;

  return SimBuffer(
    id: node.id,
    position: node.position,
    wait: takt.equivalentAt(productive) * (node.inventoryQuantity ?? 0),
    // Pieces drain at the rate the line runs, which is working time.
    usesWorkingTime: true,
  );
}

/// The step whose work content across the whole demand is largest.
String? _paceSetter({
  required List<FlowNode> nodes,
  required List<DemandOrder> orders,
  required Map<String, Map<String, Duration>> processTimes,
  required SimResourceContext resources,
}) {
  final work = <String, int>{};
  String? fallback;

  for (final node in nodes) {
    if (node.kind != FlowNodeKind.step) continue;
    final workcenterId = _firstCandidate(node, resources);
    if (workcenterId == null) continue;
    fallback ??= workcenterId;

    final key = demandTargetOf(node);
    if (key == null) continue;
    var total = 0;
    for (final order in orders) {
      final stored = processTimes[order.partId]?[key];
      if (stored != null) total += stored.inSeconds * order.batchSize;
    }
    work[workcenterId] = (work[workcenterId] ?? 0) + total;
  }

  if (work.isEmpty) return fallback;
  // Ties break by id, so two identically loaded stations do not make two runs
  // of the same study disagree (§4.4).
  final best = work.entries.reduce(
    (a, b) => b.value > a.value || (b.value == a.value && b.key.compareTo(a.key) < 0)
        ? b
        : a,
  );
  return best.value == 0 ? fallback : best.key;
}

String? _firstCandidate(FlowNode node, SimResourceContext resources) =>
    _candidatesFor(node, resources).firstOrNull;

FlowNode? _nextStep(List<FlowNode> nodes, int afterPosition) {
  for (final node in nodes) {
    if (node.position > afterPosition && node.kind == FlowNodeKind.step) {
      return node;
    }
  }
  return null;
}
