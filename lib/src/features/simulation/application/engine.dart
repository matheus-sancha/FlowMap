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

    final candidate = coldStartDate(
      nodes: study.nodes,
      workcenters: workcenters,
      part: part,
      batchSize: first.batchSize,
      needDate: first.needDate,
    );
    if (candidate == null) continue;
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

/// A workcenter's state during a run.
class _Server {
  _Server(this.workcenter);

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

  bool get isIdle => busyUntil == null;
}

/// An order waiting at a step.
class _Waiting {
  _Waiting({
    required this.study,
    required this.order,
    required this.nodeIndex,
    required this.step,
    required this.since,
    required this.perPiece,
  });

  final SimStudy study;
  final SimOrder order;
  final int nodeIndex;
  final SimStep step;
  final DateTime since;

  /// Per-piece process time at this step, kept for the SPT rule.
  final Duration perPiece;

  Duration get work => perPiece * order.batchSize;
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

  int _seq = 0;
  late DateTime _now = start;

  SimRunResult run() {
    for (final entry in workcenters.entries) {
      _servers[entry.key] = _Server(entry.value);
    }
    for (final study in studies) {
      _studies[study.id] = study;
      _open[study.id] = 0;
      _head[study.id] = 0;
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

  void _onArrive(_Event event) {
    final study = _studyById(event.key!);
    final order = _orders['${study.id}/${event.orderId}']!;
    var index = event.index!;

    // Buffers are pure delay, so walk through as many as follow before parking
    // the order in a queue (§5.5).
    while (index < study.nodes.length) {
      final node = study.nodes[index];
      if (node is! SimBuffer) break;

      final until = node.usesWorkingTime
          ? _bufferCalendar(study, node)?.advance(_now, node.wait)
          : _now.add(node.wait);
      _schedule(
        until ?? _now.add(node.wait),
        _EventKind.arrive,
        key: study.id,
        orderId: order.id,
        index: index + 1,
      );
      return;
    }

    if (index >= study.nodes.length) {
      _deliver(study, order);
      return;
    }

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
      ),
    );
  }

  /// A working-time buffer runs on the clock of the step it feeds, or at the
  /// end of a flow the one it just left (§17.2).
  dynamic _bufferCalendar(SimStudy study, SimBuffer buffer) {
    SimStep? neighbour;
    for (final node in study.nodes) {
      if (node.position > buffer.position && node is SimStep) {
        neighbour = node;
        break;
      }
    }
    if (neighbour == null) {
      for (final node in study.nodes) {
        if (node.position < buffer.position && node is SimStep) {
          neighbour = node;
        }
      }
    }
    return workcenters[neighbour?.candidates.firstOrNull]?.calendar;
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

      final idle = _servers.values
          .where((s) => s.isIdle && !s.dead)
          .toList()
        ..sort((a, b) {
          final busy = a.busy.compareTo(b.busy);
          if (busy != 0) return busy;
          return a.workcenter.name.compareTo(b.workcenter.name);
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
            _schedule(openAt, _EventKind.wake, key: server.workcenter.id);
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

  _Waiting? _pick(_Server server) {
    // The station's own rule if it has one, otherwise the run's (§7.4). Read
    // once per pick rather than per comparison: it cannot change while the
    // server chooses, and a comparator whose rule could vary mid-sort would
    // not be ordering anything.
    final rule = server.workcenter.dispatch ?? dispatch;

    _Waiting? best;
    for (final candidate in _waiting) {
      if (!candidate.step.candidates.contains(server.workcenter.id)) continue;
      if (best == null || _prefers(candidate, best, rule)) best = candidate;
    }
    return best;
  }

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
    _running[server.workcenter.id] = waiting;

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
      ),
    );

    _schedule(end, _EventKind.finish, key: server.workcenter.id);
  }

  void _onFinish(String workcenterId) {
    final server = _servers[workcenterId]!;
    final waiting = _running.remove(workcenterId);
    server.busyUntil = null;
    if (waiting == null) return;

    _schedule(
      _now,
      _EventKind.arrive,
      key: waiting.study.id,
      orderId: waiting.order.id,
      index: waiting.nodeIndex + 1,
    );
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
    final open = <String, Duration>{};
    for (final entry in _servers.entries) {
      try {
        open[entry.key] = entry.value.workcenter.calendar.openTimeBetween(
          start,
          _now,
        );
      } on StateError {
        open[entry.key] = Duration.zero;
      }
    }

    return SimRunResult(
      start: start,
      end: _now,
      guard: guard,
      steps: _rows,
      orders: outcomes,
      emptySlots: _empties,
      busyByWorkcenter: {
        for (final entry in _servers.entries) entry.key: entry.value.busy,
      },
      openByWorkcenter: open,
      abort: abort,
    );
  }
}
