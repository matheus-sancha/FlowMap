/// The discrete-event simulation (DESIGN.md §7).
///
/// A priority queue of timestamped events advanced in absolute time, with every
/// duration spent through the §4 calendar. Cost scales with events rather than
/// with horizon length, so a three-year study of five hundred orders is the
/// same work as a three-month one.
///
/// **Deterministic** (§4.4): the same inputs always produce the same output, so
/// two scenarios differ only by what was changed. Every ordering decision here
/// — which event fires first at a shared instant, which free workcenter takes a
/// pool's next order, which waiting order it takes — falls back to keys that
/// cannot tie.
///
/// Pure: no Drift, no widgets, no clock of its own. That is what lets it run on
/// a background isolate (§7.1) and be driven from a test in three lines.
library;

import '../../calendar/application/effective_time.dart';
import '../../calendar/application/working_calendar.dart';
import 'sim_model.dart';
import 'sim_result.dart';
import 'theoretical_lead_time.dart';

/// Runs [studies] against one shared model of the plant (§7.7).
///
/// [start] and [guard] default to §7.8: a cold start at the earliest order's
/// need date minus its theoretical lead time, and a guard at five times the
/// horizon demand implies.
SimRunResult runSimulation({
  required List<SimStudy> studies,
  required Map<String, SimWorkcenter> workcenters,
  DispatchRule dispatch = DispatchRule.fifo,
  DateTime? start,
  DateTime? guard,
}) {
  final plan = planRun(studies: studies, workcenters: workcenters);
  final from = start ?? plan.start;
  if (from == null) {
    return SimRunResult(
      start: DateTime.fromMillisecondsSinceEpoch(0),
      end: DateTime.fromMillisecondsSinceEpoch(0),
      guard: DateTime.fromMillisecondsSinceEpoch(0),
      steps: const [],
      orders: const [],
      emptySlots: const [],
      busyByWorkcenter: const {},
      openByWorkcenter: const {},
      abort: SimAbortReason.nothingToRun,
    );
  }

  return _Engine(
    studies: studies,
    workcenters: workcenters,
    dispatch: dispatch,
    start: from,
    guard: guard ?? plan.guardFrom(from),
  ).run();
}

/// Where a run begins and where it gives up (DESIGN.md §7.8).
class RunPlan {
  const RunPlan({required this.start, required this.lastNeedDate});

  /// Cold start, or null when no study has a costable first order.
  final DateTime? start;

  /// The furthest need date in the demand.
  final DateTime? lastNeedDate;

  /// Five times the horizon demand implies. A run that reaches this has been
  /// told, by its own numbers, that demand exceeds capacity.
  DateTime guardFrom(DateTime start) {
    final last = lastNeedDate;
    final horizon = last == null || !last.isAfter(start)
        ? const Duration(days: 365)
        : last.difference(start);
    return start.add(horizon * 5);
  }
}

/// Works out the cold start and the horizon without running anything.
RunPlan planRun({
  required List<SimStudy> studies,
  required Map<String, SimWorkcenter> workcenters,
}) {
  DateTime? start;
  DateTime? lastNeed;

  for (final study in studies) {
    for (final order in study.orders) {
      if (lastNeed == null || order.needDate.isAfter(lastNeed)) {
        lastNeed = order.needDate;
      }
    }

    // The first order of the sequence, not the earliest need date: the plant is
    // empty when the sequence starts, and it is the head that sets the offset.
    final first = study.orders.firstOrNull;
    final part = first == null ? null : study.parts[first.partId];
    if (first == null || part == null) continue;

    final walked = coldStartDate(
      nodes: study.nodes,
      workcenters: workcenters,
      part: part,
      batchSize: first.batchSize,
      needDate: first.needDate,
    );
    if (walked == null) continue;

    // The study's own safety margin, on the wall clock (§7.8). Subtracted here
    // rather than inside the walk: the walk is the queue-free minimum and has
    // to stay comparable with what the run observes (§7.9), while this is a
    // deliberate margin on top of it.
    final candidate = walked.subtract(study.startBuffer);
    if (start == null || candidate.isBefore(start)) start = candidate;
  }

  return RunPlan(start: start, lastNeedDate: lastNeed);
}

// --- The engine -------------------------------------------------------------

enum _EventKind {
  /// A workcenter finished an order. First at a shared instant, so the freed
  /// server is visible to everything else happening then.
  finish,

  /// An order reached a node.
  arrive,

  /// A release slot came round.
  slot,

  /// A workcenter's shift opened and it may pick up work.
  wake,
}

class _Event implements Comparable<_Event> {
  _Event(this.at, this.kind, this.seq, {this.orderId, this.key, this.index});

  final DateTime at;
  final _EventKind kind;

  /// Insertion order, so two events that tie on everything else still order.
  final int seq;

  final String? orderId;

  /// Study id, or workcenter id, depending on [kind].
  final String? key;

  final int? index;

  @override
  int compareTo(_Event other) {
    final time = at.compareTo(other.at);
    if (time != 0) return time;
    final rank = kind.index.compareTo(other.kind.index);
    if (rank != 0) return rank;
    return seq.compareTo(other.seq);
  }
}

/// A binary heap, written rather than imported.
///
/// Forty lines against a dependency to keep current, and it puts the ordering
/// rule that makes the run deterministic in the same file as the run.
class _EventQueue {
  final List<_Event> _heap = [];

  bool get isEmpty => _heap.isEmpty;

  _Event get first => _heap.first;

  void add(_Event event) {
    _heap.add(event);
    var child = _heap.length - 1;
    while (child > 0) {
      final parent = (child - 1) ~/ 2;
      if (_heap[child].compareTo(_heap[parent]) >= 0) break;
      _swap(child, parent);
      child = parent;
    }
  }

  _Event removeFirst() {
    final first = _heap.first;
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = last;
      var parent = 0;
      while (true) {
        final left = parent * 2 + 1;
        final right = left + 1;
        var smallest = parent;
        if (left < _heap.length &&
            _heap[left].compareTo(_heap[smallest]) < 0) {
          smallest = left;
        }
        if (right < _heap.length &&
            _heap[right].compareTo(_heap[smallest]) < 0) {
          smallest = right;
        }
        if (smallest == parent) break;
        _swap(parent, smallest);
        parent = smallest;
      }
    }
    return first;
  }

  void _swap(int a, int b) {
    final tmp = _heap[a];
    _heap[a] = _heap[b];
    _heap[b] = tmp;
  }
}

/// One unit of a workcenter, during a run.
///
/// A station with `units > 1` has several of these, and they are independent in
/// every way that matters: each has its own clock, its own busy total and its
/// own [lastPartId], so two units of one machine pay changeovers separately —
/// which is what running two orders at once means (§3.1).
class _Server {
  _Server(this.id, this.workcenter);

  /// `wc-1#0`. Distinct from the workcenter id, which several servers share.
  final String id;

  final SimWorkcenter workcenter;

  /// Null when idle.
  DateTime? busyUntil;

  /// The part it last ran, for the changeover rule (§7.6). Null at cold start,
  /// which is why the first order of a run never pays a setup.
  String? lastPartId;

  Duration busy = Duration.zero;

  /// A wake already scheduled, so a settle pass does not queue a second.
  DateTime? wakeAt;

  /// The open window this server is in, or the next one ahead of it.
  ///
  /// Cached because the dispatcher asks after every event, and walking the
  /// calendar each time was the whole cost of a run: one question per shift
  /// instead of one per event (§14).
  OpenInterval? window;

  /// Its calendar can never open. Recorded once rather than rediscovered on
  /// every pass.
  bool dead = false;

  /// When it finished an order it could not put down, or null when it is not
  /// blocked (§5.5).
  ///
  /// A blocked server is **not idle**: it is holding a finished order and
  /// cannot start another. That is what makes blocking propagate backwards up
  /// the line, which is the whole behaviour a lane's capacity buys.
  DateTime? blockedSince;

  /// Total time spent holding finished orders with nowhere to put them.
  ///
  /// Kept apart from [busy] rather than added to it, so utilization keeps
  /// meaning "working" and a jam cannot be reported as output (§8.3).
  Duration blocked = Duration.zero;

  bool get isIdle => busyUntil == null;
}

/// An order standing in the queue in front of a step.
class _Waiting {
  _Waiting({
    required this.study,
    required this.order,
    required this.nodeIndex,
    required this.step,
    required this.since,
    required this.perPiece,
    required this.lane,
  });

  final SimStudy study;
  final SimOrder order;
  final int nodeIndex;
  final SimStep step;
  final DateTime since;

  /// Per-piece process time at this step, kept for the SPT rule.
  final Duration perPiece;

  /// The lane it is standing in, or null when the step has none in front of it
  /// and the order queues at the station (§5.5).
  final SimBuffer? lane;

  Duration get work => perPiece * order.batchSize;
}

/// What governs the queue in front of one step (§5.5).
///
/// **The lane immediately before the step, and only that one.** §5.1's spine
/// gives a step at most one, which is what keeps the ordering total: a machine
/// that is a candidate for its own step and for a pool's still has exactly one
/// comparator per queue, which a rule stored on the station could not promise.
///
/// A run of several buffers is collapsed to the last of them — the one the
/// station actually pulls from. The earlier ones stay what §2.12 made every
/// buffer: free to pass through. Two lanes in a row is a modelling oddity
/// rather than a case with an agreed meaning, and inventing one here would make
/// the capacity a reader typed mean something they did not ask for.
class _Gate {
  const _Gate({required this.stepIndex, required this.lane});

  final int stepIndex;
  final SimBuffer? lane;

  int? get capacity => lane?.capacity;
}

class _Engine {
  _Engine({
    required this.studies,
    required this.workcenters,
    required this.dispatch,
    required this.start,
    required this.guard,
  });

  final List<SimStudy> studies;
  final Map<String, SimWorkcenter> workcenters;
  final DispatchRule dispatch;
  final DateTime start;
  final DateTime guard;

  final _EventQueue _queue = _EventQueue();
  final Map<String, _Server> _servers = {};

  /// Studies and orders by id. Built once: an arrival event carries ids, and
  /// looking them up by scanning would make the run quadratic in the demand —
  /// sixteen thousand arrivals against two thousand orders at the scale
  /// target (§14).
  final Map<String, SimStudy> _studies = {};
  final Map<String, SimOrder> _orders = {};
  final List<_Waiting> _waiting = [];

  final List<SimOrderStep> _rows = [];
  final List<SimEmptySlot> _empties = [];
  final Map<String, DateTime?> _released = {};
  final Map<String, DateTime?> _delivered = {};

  /// Orders currently in the flow, per study, for the CONWIP cap (§7.3).
  final Map<String, int> _open = {};

  /// How far down each study's sequence the releases have got.
  final Map<String, int> _head = {};

  /// The order a server is running, so a finish knows what it completed.
  final Map<String, _Waiting> _running = {};

  /// Where each step's queue forms, per study, indexed by node position (§5.5).
  ///
  /// Resolved once at the start rather than walked backwards on every arrival:
  /// the answer cannot change during a run, and an arrival happens sixteen
  /// thousand times at the scale target (§14).
  final Map<String, List<_Gate?>> _gates = {};

  /// Which `_rows` entry belongs to the order a server is holding, so the block
  /// it is serving can be written onto that row when it ends.
  final Map<String, int> _rowOfServer = {};

  int _seq = 0;
  late DateTime _now = start;

  SimRunResult run() {
    for (final entry in workcenters.entries) {
      // One server per unit (§3.1). The id carries the index so a finish event
      // names the unit that finished rather than the station it belongs to —
      // two units of one machine can be busy with different orders, and a
      // station-keyed event could not say which had ended.
      final units = entry.value.units < 1 ? 1 : entry.value.units;
      for (var unit = 0; unit < units; unit++) {
        _servers['${entry.key}#$unit'] = _Server(
          '${entry.key}#$unit',
          entry.value,
        );
      }
    }
    for (final study in studies) {
      _studies[study.id] = study;
      _open[study.id] = 0;
      _head[study.id] = 0;
      _gates[study.id] = _gatesOf(study);
      for (final order in study.orders) {
        _orders['${study.id}/${order.id}'] = order;
        _released[order.id] = null;
        _delivered[order.id] = null;
      }
      if (study.orders.isNotEmpty) _schedule(start, _EventKind.slot, key: study.id);
    }

    SimAbortReason? abort;

    while (!_queue.isEmpty) {
      final at = _queue.first.at;
      if (at.isAfter(guard)) {
        abort = SimAbortReason.horizonExceeded;
        break;
      }
      _now = at;

      // **Every event at this instant, then one settle.** Dispatching after
      // each event in turn would let the order whose arrival happened to be
      // processed first take a free workcenter, which makes the queue's
      // insertion order beat the rules in §7.4 — two studies releasing at the
      // same slot would ignore their priorities. An event handled here may
      // schedule another at the same instant (a finish moves an order straight
      // to the next step); that is picked up by this loop, not left for the
      // next.
      while (!_queue.isEmpty && _queue.first.at == at) {
        final event = _queue.removeFirst();
        switch (event.kind) {
          case _EventKind.slot:
            _onSlot(_studyById(event.key!));
          case _EventKind.arrive:
            _onArrive(event);
          case _EventKind.finish:
            _onFinish(event.key!);
          case _EventKind.wake:
            _servers[event.key!]?.wakeAt = null;
        }
      }

      _settle();
    }

    return _result(abort);
  }

  SimStudy _studyById(String id) => _studies[id]!;

  void _schedule(
    DateTime at,
    _EventKind kind, {
    String? key,
    String? orderId,
    int? index,
  }) => _queue.add(
    _Event(at, kind, _seq++, key: key, orderId: orderId, index: index),
  );

  // --- Release ---------------------------------------------------------------

  /// A release slot (§7.2): look at the **head of the sequence only**, release
  /// it or record the slot empty, and never reorder.
  void _onSlot(SimStudy study) {
    final head = _head[study.id]!;
    if (head >= study.orders.length) return;

    final order = study.orders[head];
    final cap = study.wipCap;
    final material = order.materialDate;

    if (material != null && material.isAfter(_now)) {
      _empties.add(
        SimEmptySlot(
          studyId: study.id,
          at: _now,
          reason: EmptySlotReason.awaitingMaterial,
        ),
      );
    } else if (cap != null && _open[study.id]! >= cap) {
      _empties.add(
        SimEmptySlot(
          studyId: study.id,
          at: _now,
          reason: EmptySlotReason.wipCap,
        ),
      );
    } else if (_gateIsFull(study)) {
      // Nowhere to put it. Two lanes can say so, and both are places nothing
      // upstream can be blocked on behalf of: the lane at the head of the flow,
      // which has no station behind it, and the pacemaker's, which is where
      // lean injects the schedule and therefore what the release is really
      // pulled by. §7.2's slots are strict, so the slot is spent rather than
      // deferred.
      _empties.add(
        SimEmptySlot(
          studyId: study.id,
          at: _now,
          reason: EmptySlotReason.laneFull,
        ),
      );
    } else {
      _head[study.id] = head + 1;
      _open[study.id] = _open[study.id]! + 1;
      _released[order.id] = _now;
      _schedule(_now, _EventKind.arrive, key: study.id, orderId: order.id, index: 0);
    }

    // The next slot comes whether this one was used or not — strict takt slots,
    // no skipping. Stop once the sequence is exhausted, so an idle plant does
    // not accumulate empty slots for orders that do not exist.
    if (_head[study.id]! < study.orders.length) {
      _schedule(_nextSlot(study), _EventKind.slot, key: study.id);
    }
  }

  DateTime _nextSlot(SimStudy study) {
    final calendar = workcenters[study.releaseCalendarId]?.calendar;
    if (calendar == null) return _now.add(study.releaseInterval);
    try {
      return calendar.advance(_now, study.releaseInterval);
    } on StateError {
      return _now.add(study.releaseInterval);
    }
  }

  // --- Movement --------------------------------------------------------------

  /// Where each step's queue forms, by node position.
  ///
  /// A step's gate is the buffer immediately before it, or null when the node
  /// before it is another step and the order queues at the station itself. A
  /// run of buffers collapses to the last — see [_Gate].
  List<_Gate?> _gatesOf(SimStudy study) {
    final gates = List<_Gate?>.filled(study.nodes.length, null);
    for (var i = 0; i < study.nodes.length; i++) {
      if (study.nodes[i] is! SimStep) continue;
      final before = i > 0 ? study.nodes[i - 1] : null;
      gates[i] = _Gate(
        stepIndex: i,
        lane: before is SimBuffer ? before : null,
      );
    }
    return gates;
  }

  /// How many orders are standing in the queue in front of [stepIndex].
  ///
  /// Counted off `_waiting` rather than tracked separately, because that list
  /// *is* the queue: an order is in it from the moment it enters the lane until
  /// a server pulls it out. A second counter would be a second truth to keep in
  /// step, and the run is small enough that scanning is not the cost — the
  /// events are (§16.9).
  int _queued(String studyId, int stepIndex) => _waiting
      .where((w) => w.study.id == studyId && w.nodeIndex == stepIndex)
      .length;

  /// Whether the queue in front of [stepIndex] has room for one more.
  bool _hasRoom(SimStudy study, int stepIndex) {
    final capacity = _gates[study.id]![stepIndex]?.capacity;
    return capacity == null || _queued(study.id, stepIndex) < capacity;
  }

  /// The first step of a study's flow, which is where a release lands.
  int? _entry(SimStudy study) => _nextStep(study, 0);

  /// Whether a release has to be held back for want of room (§7.2, §5.5).
  ///
  /// **The pacemaker's lane as well as the entry lane.** Lean injects the
  /// schedule at the pacemaker, so the question "may another order start" is
  /// really "can the pacemaker take one" — and gating there makes the
  /// constraint govern the line directly rather than through a chain of blocked
  /// stations propagating backwards, which on célula 11B is four stations deep.
  /// The entry lane is checked too because nothing upstream of it can be
  /// blocked on its behalf.
  ///
  /// Both are no-ops on a lane with no capacity, which is every lane until
  /// someone types one.
  bool _gateIsFull(SimStudy study) {
    if (_entry(study) case final first? when !_hasRoom(study, first)) {
      return true;
    }
    final pacemaker = _paceSetterIndex(study);
    return pacemaker != null && !_hasRoom(study, pacemaker);
  }

  /// Where the pacemaker sits in the flow, or null when the study names none.
  int? _paceSetterIndex(SimStudy study) {
    final nodeId = study.paceSetterNodeId;
    if (nodeId == null) return null;
    final index = study.nodes.indexWhere((n) => n.id == nodeId);
    return index < 0 || study.nodes[index] is! SimStep ? null : index;
  }

  /// The next step an order at [from] must visit, or null when it has finished
  /// the flow.
  ///
  /// Buffers still cost nothing to pass through (§2.12): what they cost is
  /// *room*, and that is charged by [_hasRoom] at the step they feed rather
  /// than as a delay here.
  int? _nextStep(SimStudy study, int from) {
    var index = from;
    while (index < study.nodes.length && study.nodes[index] is SimBuffer) {
      index++;
    }
    return index >= study.nodes.length ? null : index;
  }

  void _onArrive(_Event event) {
    final study = _studyById(event.key!);
    final order = _orders['${study.id}/${event.orderId}']!;
    final index = _nextStep(study, event.index!);

    if (index == null) {
      _deliver(study, order);
      return;
    }

    _admit(study, order, index);
  }

  /// Puts [order] into the queue in front of the step at [index].
  ///
  /// The caller has already established there is room; this is the write.
  void _admit(SimStudy study, SimOrder order, int index) {
    final step = study.nodes[index] as SimStep;
    final perPiece = study.parts[order.partId]?.timeAt(step.demandKey);
    if (perPiece == null) {
      // A part with no time at a step it must visit is a blocking readiness
      // error (§11). The engine will not invent one; the order simply never
      // completes and the guard reports it.
      return;
    }

    _waiting.add(
      _Waiting(
        study: study,
        order: order,
        nodeIndex: index,
        step: step,
        since: _now,
        perPiece: perPiece,
        lane: _gates[study.id]![index]?.lane,
      ),
    );
  }

  void _deliver(SimStudy study, SimOrder order) {
    _delivered[order.id] = _now;
    _open[study.id] = _open[study.id]! - 1;
  }

  // --- Dispatch --------------------------------------------------------------

  /// Starts whatever can start now, until nothing more can.
  ///
  /// Free servers are tried in a deterministic order — least busy first, then
  /// by name — which is §3.1's pool tie-break: whichever member frees first
  /// takes the order, and a genuine tie goes to the least utilised.
  void _settle() {
    var progressed = true;
    while (progressed) {
      progressed = false;

      // **Unload before dispatching.** Taking an order out of a lane is what
      // makes room in it, so a station blocked on that lane can move the moment
      // the pick happens — and it must be offered the space before the next
      // order is admitted, or a jam would clear only when something else
      // happened to arrive. Held in the same settle loop as dispatch so one
      // release can cascade back up a line of blocked stations at one instant.
      for (final server in _servers.values.toList()) {
        if (server.blockedSince == null) continue;
        final waiting = _running[server.id];
        if (waiting == null) continue;
        _tryUnload(server, waiting);
        if (server.blockedSince == null) progressed = true;
      }

      final idle = _servers.values
          .where((s) => s.isIdle && !s.dead)
          .toList()
        ..sort((a, b) {
          final busy = a.busy.compareTo(b.busy);
          if (busy != 0) return busy;
          final name = a.workcenter.name.compareTo(b.workcenter.name);
          if (name != 0) return name;
          // Two units of one station share a name, so the id is what stops a
          // genuine tie between them being resolved by map order (§4.4).
          return a.id.compareTo(b.id);
        });

      for (final server in idle) {
        if (!_waiting.any((w) => w.step.candidates.contains(server.workcenter.id))) {
          continue;
        }

        var window = server.window;
        if (window == null || !window.end.isAfter(_now)) {
          window = server.workcenter.calendar.openWindowFrom(_now);
          if (window == null) {
            // Never opens again — recorded once rather than rediscovered on
            // every pass.
            server.dead = true;
            continue;
          }
          server.window = window;
        }

        final openAt = window.start;
        if (openAt.isAfter(_now)) {
          // Not open yet. Decide *then* rather than committing now, so an order
          // arriving overnight is not beaten to the shift by one that happened
          // to be queued first.
          if (server.wakeAt != openAt) {
            server.wakeAt = openAt;
            _schedule(openAt, _EventKind.wake, key: server.id);
          }
          continue;
        }

        final chosen = _pick(server);
        if (chosen == null) continue;
        _start(server, chosen);
        progressed = true;
      }
    }
  }

  /// The order this server takes next, by the rule of the lane it is taking it
  /// from (§5.5, §7.4).
  ///
  /// **The comparator comes from the queue, not from the machine.** A server may
  /// be a candidate for its own step and for a pool's, so it can face two
  /// queues; each is governed by the lane in front of *it*, and the two are
  /// compared only after their own rules have chosen a head. Ordering stays
  /// total because a step has at most one lane (§5.1) and a lane has one rule.
  _Waiting? _pick(_Server server) {
    _Waiting? best;
    for (final candidate in _waiting) {
      if (!candidate.step.candidates.contains(server.workcenter.id)) continue;
      if (best == null || _prefers(candidate, best, _ruleFor(candidate))) {
        best = candidate;
      }
    }
    return best;
  }

  /// The lane's rule, or the run's where a step has no lane (§7.4).
  DispatchRule _ruleFor(_Waiting waiting) => waiting.lane?.rule ?? dispatch;

  /// Whether [a] should run before [b] under [rule] (§7.4).
  ///
  /// Each rule adds its own first key; all of them fall through to arrival,
  /// then study priority, then sequence number, so contention between two
  /// studies over a shared workcenter is reproducible.
  bool _prefers(_Waiting a, _Waiting b, DispatchRule rule) {
    switch (rule) {
      case DispatchRule.earliestDueDate:
        final due = a.order.needDate.compareTo(b.order.needDate);
        if (due != 0) return due < 0;
      case DispatchRule.shortestProcessing:
        final work = a.work.compareTo(b.work);
        if (work != 0) return work < 0;
      case DispatchRule.fifo:
        break;
    }

    final arrival = a.since.compareTo(b.since);
    if (arrival != 0) return arrival < 0;

    final priority = a.study.priority.compareTo(b.study.priority);
    if (priority != 0) return priority < 0;

    final sequence = a.order.sequence.compareTo(b.order.sequence);
    if (sequence != 0) return sequence < 0;

    // Two orders of one study cannot share a sequence number, so this only
    // separates orders of two studies of equal priority.
    return a.order.id.compareTo(b.order.id) < 0;
  }

  void _start(_Server server, _Waiting waiting) {
    _waiting.remove(waiting);

    final schedule = server.workcenter.schedule;
    final availability = schedule.availabilityOn(_now);

    // Changeover only when the previous order on *this* workcenter was a
    // different part (§7.6). At cold start there is no previous order, so the
    // first job of a run never pays a setup.
    final changeover =
        server.lastPartId != null &&
            server.lastPartId != waiting.order.partId
        ? waiting.step.changeover
        : Duration.zero;

    // Availability derates the whole occupancy, setup included, which is what
    // makes this the same arithmetic as the Summary's occupation seen from the
    // other end (§8.4). Rework attaches to the part's work only (§6.1).
    final occupancy =
        effectiveProcessTime(
          processTimePerPiece: waiting.perPiece,
          batchSize: waiting.order.batchSize,
          availability: availability,
          rework: schedule.reworkOn(_now),
        ) +
        (changeover * (1 / availability));

    final DateTime end;
    try {
      end = server.workcenter.calendar.advance(_now, occupancy);
    } on StateError {
      server.dead = true;
      _waiting.add(waiting);
      return;
    }

    server
      ..busyUntil = end
      ..lastPartId = waiting.order.partId
      ..busy += occupancy;
    _running[server.id] = waiting;

    _rowOfServer[server.id] = _rows.length;
    _rows.add(
      SimOrderStep(
        studyId: waiting.study.id,
        orderId: waiting.order.id,
        nodeId: waiting.step.id,
        workcenterId: server.workcenter.id,
        queueStart: waiting.since,
        processStart: _now,
        processEnd: end,
        changeoverIncurred: changeover > Duration.zero,
        // The lane it was pulled out of, so the run can say where it stood
        // without joining back to a flow that may have been edited (§7.10).
        laneNodeId: waiting.lane?.id,
      ),
    );

    _schedule(end, _EventKind.finish, key: server.id);
  }

  /// A server has finished. It puts the order down if it can, and holds it if
  /// it cannot (§5.5).
  void _onFinish(String serverId) {
    final server = _servers[serverId]!;
    final waiting = _running[serverId];
    if (waiting == null) {
      server.busyUntil = null;
      return;
    }
    _tryUnload(server, waiting);
  }

  /// Moves the order a server has finished on to its next queue, or blocks.
  ///
  /// **Blocking is after service**, which is not a simplification but the
  /// physical case: a station cannot know whether the lane ahead will have room
  /// until it has something to put down. So it finishes, and then waits — and
  /// while it waits it is neither idle nor working, which is what carries the
  /// jam backwards up the line.
  void _tryUnload(_Server server, _Waiting waiting) {
    final study = waiting.study;
    final next = _nextStep(study, waiting.nodeIndex + 1);

    // Nothing ahead: the flow is finished and the customer is an unlimited
    // sink, so the last station can never block. That is also why a linear
    // spine cannot deadlock — the head of the chain always drains (§5.1).
    if (next != null && !_hasRoom(study, next)) {
      server.blockedSince ??= _now;
      return;
    }

    if (server.blockedSince case final since?) {
      final held = _now.difference(since);
      server.blocked += held;
      server.blockedSince = null;
      // Written onto the step that was blocked, not onto the one about to
      // start: the jam belongs to the order the station could not put down.
      if (_rowOfServer[server.id] case final index?) {
        final row = _rows[index];
        _rows[index] = SimOrderStep(
          studyId: row.studyId,
          orderId: row.orderId,
          nodeId: row.nodeId,
          workcenterId: row.workcenterId,
          queueStart: row.queueStart,
          processStart: row.processStart,
          processEnd: row.processEnd,
          changeoverIncurred: row.changeoverIncurred,
          laneNodeId: row.laneNodeId,
          blocked: held,
        );
      }
    }

    _running.remove(server.id);
    _rowOfServer.remove(server.id);
    server.busyUntil = null;

    if (next == null) {
      _deliver(study, waiting.order);
    } else {
      _admit(study, waiting.order, next);
    }
  }

  // --- Result ----------------------------------------------------------------

  SimRunResult _result(SimAbortReason? abort) {
    final outcomes = <SimOrderOutcome>[];
    for (final study in studies) {
      for (final order in study.orders) {
        outcomes.add(
          SimOrderOutcome(
            studyId: study.id,
            orderId: order.id,
            sequence: order.sequence,
            partId: order.partId,
            needDate: order.needDate,
            released: _released[order.id],
            delivered: _delivered[order.id],
          ),
        );
      }
    }

    // Open time each station had between the cold start and the last event —
    // utilization's denominator, and what makes it different from occupation.
    //
    // **Multiplied by the unit count**, because the numerator is summed across
    // units below: a two-unit station that ran both of them flat out is 100 %
    // utilised, and a denominator counting one clock would report it at 200 %.
    // Asked once per station rather than once per server — the calendar walk is
    // the expensive part (§16.9) and every unit of a station shares one.
    final open = <String, Duration>{};
    for (final entry in workcenters.entries) {
      final units = entry.value.units < 1 ? 1 : entry.value.units;
      try {
        open[entry.key] =
            entry.value.calendar.openTimeBetween(start, _now) * units;
      } on StateError {
        open[entry.key] = Duration.zero;
      }
    }

    // Busy time summed back across a station's units, so everything downstream
    // — the Queue table, the bottleneck ranking, the Summary — keeps reading one
    // row per station and never learns that servers exist.
    final busy = <String, Duration>{};
    final blocked = <String, Duration>{};
    for (final server in _servers.values) {
      busy[server.workcenter.id] =
          (busy[server.workcenter.id] ?? Duration.zero) + server.busy;
      // A server still holding an order when the run ends has been blocked
      // since `blockedSince` and will never be released. Closing the span here
      // rather than dropping it: the guard stopping a run is exactly the case
      // where the jam is the finding (§7.8).
      final open = server.blockedSince == null
          ? Duration.zero
          : _now.difference(server.blockedSince!);
      blocked[server.workcenter.id] =
          (blocked[server.workcenter.id] ?? Duration.zero) +
          server.blocked +
          open;
    }

    return SimRunResult(
      start: start,
      end: _now,
      guard: guard,
      steps: _rows,
      orders: outcomes,
      emptySlots: _empties,
      busyByWorkcenter: busy,
      openByWorkcenter: open,
      blockedByWorkcenter: blocked,
      // Every lane the run walked, so §8.6 can place a row for one that never
      // held anything — an empty lane between two busy stations is a fact
      // about the line, not a row to leave out.
      lanes: [
        for (final study in studies)
          for (final node in study.nodes)
            if (node is SimBuffer)
              SimLane(
                studyId: study.id,
                nodeId: node.id,
                position: node.position,
                name: node.name,
                capacity: node.capacity,
              ),
      ],
      // Whatever is still standing in a lane. `_waiting` is the queue itself,
      // so what is left in it at the end is exactly what never got pulled.
      openLaneVisits: [
        for (final waiting in _waiting)
          if (waiting.lane case final lane?)
            SimOpenLaneVisit(
              studyId: waiting.study.id,
              orderId: waiting.order.id,
              laneNodeId: lane.id,
              enteredAt: waiting.since,
            ),
      ],
      abort: abort,
    );
  }
}
