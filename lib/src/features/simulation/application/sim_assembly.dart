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
import '../../flow/application/takt_balance.dart';
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
    this.queues = const {},
    this.cellNames = const {},
    this.lineNames = const {},
    this.workcenterTypeNames = const {},
  });

  final Map<String, String> workcenterNames;
  final Map<String, String> poolNames;

  /// Workcenter id → the name of its type, which is the identity §7.4 forms a
  /// balance group on.
  ///
  /// Defaulted to empty because a run with no types is a run where no two
  /// adjacent stations are alike, which is what every flow was before this rule
  /// existed — so the balance simply finds no groups.
  final Map<String, String> workcenterTypeNames;

  /// Cell and line id → name, so a study can copy where it sat into the run
  /// (§7.10) rather than leaving a filter to join back to the plant.
  ///
  /// Defaulted to empty because nothing the engine does depends on them: a run
  /// with no names still runs, and the filter simply falls back to the ids.
  final Map<String, String> cellNames;
  final Map<String, String> lineNames;

  /// Pool id → member workcenter ids, in a stable order.
  final Map<String, List<String>> poolMembers;

  /// The queue in front of each dispatch target, by target id (§5.5).
  ///
  /// One row per `{project, target}`, so two studies stepping on CLAD07 are
  /// handed the *same* queue — which is what stopped the engine contending over
  /// two floor spaces the plant does not have. A target with no row yet gets an
  /// uncapped FIFO, which is what every lane was before it could say otherwise.
  final Map<String, SimQueue> queues;

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

  final simNodes = <SimStep>[];
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
            // **The node, since §9** — a process time belongs to the step
            // rather than to the station, so two steps on one workcenter cost
            // what each of them was given.
            demandKey: node.id,
            // **The queue of what this step targets**, shared with every other
            // step naming it. Absent means nobody has set one, which is an
            // uncapped FIFO — what a shop floor does, and what every lane was
            // before a rule could be typed (§7.4).
            queue:
                resources.queues[demandTargetOf(node)!] ??
                SimQueue(targetId: demandTargetOf(node)!),
            // Resolved here rather than on the queue, because a quantity is
            // `pieces × takt` and the takt belongs to *this* study's line while
            // the queue is shared with every study that reaches the target
            // (§7.3). At this step's own productive day, which is the arithmetic
            // the map draws — so the two report the same days of stock.
            queueStock: _stockAt(
              resources.queues[demandTargetOf(node)!],
              takt: takt,
              productiveDay:
                  resources.productivePerWorkingDay[candidates.first] ??
                  Duration.zero,
            ),
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
        // **Read no more.** An inventory node was a queue belonging to one
        // study's spine; the queue now belongs to the target the next step
        // names (§5.5). The rows are kept rather than deleted — they are the
        // recovery path for anything v19's fold discarded — and nothing here
        // looks at them.
        break;
    }
  }

  // **Rebalance each run of adjacent like machines against the takt** (§7.4),
  // once per part, and hand each step its share.
  //
  // After the loop because a group is a property of the *sequence* — which
  // steps sit next to which — and the loop above sees one node at a time. Per
  // part because the work content being split is a part's, and two parts of one
  // flow legitimately balance differently.
  //
  // **One split per distinct takt the line ever states** (§7.9), because an
  // order takes the takt it opened under and a run spans as many as its
  // releases reach. The map differs only in balancing against the *viewed*
  // period's takt — both call the same function, so they can differ by their
  // takt and never by their arithmetic.
  //
  // Every period, not only the ones this run reaches: the run's span is not
  // known here, the set collapses by figure anyway, and a schedule of six
  // periods stating two takts costs two splits.
  final balanced = _balanceSteps(
    simNodes,
    nodes: nodes,
    parts: parts,
    processTimes: processTimes,
    takts: {
      (value: takt.value, unit: takt.unit),
      for (final period in taktSchedule.periods)
        (value: period.value, unit: period.unit),
    },
    resources: resources,
  );
  if (balanced.isNotEmpty) {
    for (var i = 0; i < simNodes.length; i++) {
      final shares = balanced[simNodes[i].id];
      if (shares != null) simNodes[i] = simNodes[i].withBalance(shares);
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
    // **The whole cadence, not just the one in force at the start** (§7.9).
    // Resolved here for the same reason the single interval was: `days` means
    // productive days of the pace setter, and the engine is handed durations
    // rather than a schedule to interpret.
    //
    // Against *one* productive day — the pace setter's at [asOf] — rather than
    // re-reading its staffing period by period. That axis is unchanged by this
    // round: `productivePerWorkingDay` has always been resolved once, and a
    // station whose staffing changes mid-run already reports one figure here.
    taktPeriods: [
      for (final period in taktSchedule.periods)
        SimTaktPeriod(
          start: period.startDate,
          end: period.endDate,
          value: period.value,
          unit: period.unit,
          interval: period.equivalentAt(
            resources.productivePerWorkingDay[paceSetter] ?? Duration.zero,
          ),
        ),
    ],
    releaseCalendarId: paceSetter,
    // The takt as it was typed, beside the interval it resolves to (§7.7.2) —
    // **the one this study first releases at**, since §7.9 made the takt the
    // order's rather than the run's. [asOf] is the study's start on the second
    // assembly pass, which is where its first slot falls.
    taktValue: takt.value,
    taktUnit: takt.unit,
    // And when it stops being that figure — the boundary the run crosses now
    // rather than one it ignores (§7.7.3, §7.9).
    nextTaktChange: taktSchedule.changeAfter(asOf)?.at,
    paceSetterNodeId: paceNode!.id,
    // Calendar days, which is what the column stores and what every surface
    // showing it says (§7.8, §17.4).
    startBuffer: Duration(days: study.startBufferDays),
    priority: study.priority,
    wipCap: study.wipCap,
  );
}

/// The share each step of each balance group takes, as
/// `step id → {part id → duration}` (§7.4).
///
/// Empty where no two adjacent steps share a workcenter type, which is every
/// flow that existed before this rule — so a run with no groups is byte for byte
/// the run it was.
///
/// **A pool step is in no group.** Its members are interchangeable and the pool
/// is one target with one queue (§3.1), so "the first workcenter and the last of
/// the same type in the sequence" names nothing inside it. Typed as null here,
/// which is what keeps it out.
Map<String, Map<SimTakt, Map<String, Duration>>> _balanceSteps(
  List<SimStep> steps, {
  required List<FlowNode> nodes,
  required List<DemandPart> parts,
  required Map<String, Map<String, Duration>> processTimes,
  required Set<SimTakt> takts,
  required SimResourceContext resources,
}) {
  // Pinned out of its group by the user (§7.7.4), by node id — the run has to
  // honour it or the map and the Gantt would place work differently.
  final pinned = {
    for (final node in nodes)
      if (node.balanceDisabled ?? false) node.id,
  };
  final types = [
    for (final step in steps)
      step.poolId != null
          ? null
          : resources.workcenterTypeNames[step.candidates.firstOrNull],
  ];
  if (types.every((t) => t == null)) return const {};

  final shares = <String, Map<SimTakt, Map<String, Duration>>>{};
  for (final takt in takts) {
    // One takt of each station's own capacity — the cap it fills to, and the
    // same figure the map calls the step's flow-equivalent time (§6.1).
    final caps = [
      for (final step in steps)
        resources.productivePerWorkingDay[step.candidates.firstOrNull] == null
            ? null
            : taktUnitDuration(
                takt.value,
                takt.unit,
                resources.productivePerWorkingDay[step.candidates.first]!,
              ),
    ];

    for (final part in parts) {
      final measured = processTimes[part.id] ?? const <String, Duration>{};
      final derived = balancedProcessTimes([
        for (var i = 0; i < steps.length; i++)
          (
            typeName: types[i],
            measured: measured[steps[i].demandKey],
            takt: caps[i],
            pinned: pinned.contains(steps[i].id),
          ),
      ]);
      derived.forEach((i, duration) {
        ((shares[steps[i].id] ??= {})[takt] ??= {})[part.id] = duration;
      });
    }
  }
  return shares;
}

/// The workcenters a step may run on, in a stable order.
List<String> _candidatesFor(FlowNode node, SimResourceContext resources) {
  if (node.poolId != null) {
    return [...?resources.poolMembers[node.poolId]]..sort();
  }
  final workcenterId = node.workcenterId;
  return workcenterId == null ? const [] : [workcenterId];
}

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


/// How long the stock in [queue] represents (§5.5).
///
/// A fixed wait is what was typed. A quantity is `pieces × takt` — days of stock
/// at the rate the parts drain — resolved at the station the queue feeds, which
/// is how the map reads it. Zero where nothing is standing there, and zero when
/// no schedule gives the station a productive day to measure a takt against.
Duration _stockAt(
  SimQueue? queue, {
  required TaktPeriodSpec takt,
  required Duration productiveDay,
}) {
  if (queue == null) return Duration.zero;
  if (queue.stockMode == InventoryMode.duration) {
    return Duration(seconds: queue.stockSeconds ?? 0);
  }
  final pieces = queue.stockQuantity ?? 0;
  if (pieces <= 0 || productiveDay == Duration.zero) return Duration.zero;
  return takt.equivalentAt(productiveDay) * pieces;
}
