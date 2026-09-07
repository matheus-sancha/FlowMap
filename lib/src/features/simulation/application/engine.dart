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
import '../../calendar/application/shift_pattern_spec.dart' show dateOnly;
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
  DateTime? start,
  DateTime? guard,
  /// Carried through untouched, for §11.1's warning. The engine never reads
  /// it: past the horizon a schedule is simply carried forward, which is what
  /// `PeriodSchedule` already does, and the run's job is to say that happened
  /// rather than to behave differently.
  DateTime? scheduleHorizon,
  /// **Every station with a schedule, not only the ones this run gave work to**
  /// — the set monthly capacity is written for (§10.2, phase 9).
  ///
  /// [workcenters] is what the routings reach, so capacity used to exist only
  /// where demand did and a station nobody routed to was invisible rather than
  /// idle. This set is the plant's own answer to *who is open*, and the two are
  /// **unioned** rather than swapped: a station can be routed to without a
  /// schedule of its own, and it keeps the rows it has always had.
  ///
  /// It is deliberately not folded into [workcenters], and the reason is
  /// [scheduleHorizon]: letting an unused station into the *resource model*
  /// would drag the horizon back to wherever its schedule happens to stop and
  /// fire §11.1's warning on runs with nothing wrong with them. The horizon is
  /// computed over the stations the run **uses**; capacity is written for the
  /// stations that are **open**.
  ///
  /// Empty means *the run's own stations*, which is what a caller with no
  /// plant-wide view can honestly say.
  Map<String, SimWorkcenter> scheduledStations = const {},
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

  // An explicit [start] moves the run's clock, and the studies **keep their
  // offsets from each other**: it says where the run begins, not that every
  // line begins together. With one study the shift is exactly [start], which is
  // what a caller overriding it means by it.
  final shift = plan.start == null
      ? Duration.zero
      : from.difference(plan.start!);
  final startByStudy = {
    for (final entry in plan.startByStudy.entries)
      entry.key: entry.value.add(shift),
  };

  return _Engine(
    studies: studies,
    workcenters: workcenters,
    scheduledStations: scheduledStations,
    start: from,
    startByStudy: startByStudy,
    guard: guard ?? plan.guardFrom(from),
    scheduleHorizon: scheduleHorizon,
  ).run();
}

/// Where a run begins and where it gives up (DESIGN.md §7.8).
class RunPlan {
  const RunPlan({
    required this.start,
    required this.lastNeedDate,
    this.startByStudy = const {},
  });

  /// The run's clock start — the **earliest** of [startByStudy], or null when
  /// no study has a costable first order.
  final DateTime? start;

  /// **Each study's own cold start**, keyed by study id (§7.8).
  ///
  /// A run may carry several studies and each is a line with its own flow, its
  /// own first order and its own need date. The run's clock has to begin
  /// somewhere, so [start] is the earliest of these — but a study whose own
  /// cold start is three months later does not release until then.
  ///
  /// This was collapsed to the minimum and every study was scheduled there. A
  /// study released three months early delivers three months early, so its
  /// float read as slack that did not exist and OTD was flattered; worse, its
  /// orders occupied **shared** stations for three months of simulated time
  /// they would never have been there, competing for capacity with the study
  /// that legitimately started. Measuring real contention is what a run is for
  /// (§7.7), so a multi-study run reported queueing that could not happen.
  final Map<String, DateTime> startByStudy;

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
  final byStudy = <String, DateTime>{};

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

    // **Which takt to walk the first order back at** (§7.9) — and this is the
    // one circularity the per-order takt leaves: the order takes the takt in
    // force when it opens, and when it opens is what this walk is computing.
    //
    // Broken the way §16.10 already breaks the same shape one level up: walk
    // from the need date, and if the start that produces sits under a different
    // takt, walk once more from there. **No third pass** — chasing a fixed
    // point across a boundary would let two takts argue over one order, which
    // is the mid-flight re-cadencing §18.3 rules out.
    var takt = study.taktKeyAt(first.needDate);
    var walked = coldStartDate(
      nodes: study.nodes,
      workcenters: workcenters,
      part: part,
      batchSize: first.batchSize,
      needDate: first.needDate,
      takt: takt,
    );
    if (walked == null) continue;

    // The study's own safety margin, on the wall clock (§7.8). Subtracted here
    // rather than inside the walk: the walk is the plan for one order and this
    // is a deliberate margin on top of it.
    var candidate = walked.subtract(study.startBuffer);

    final atStart = study.taktKeyAt(candidate);
    if (atStart != takt) {
      takt = atStart;
      final again = coldStartDate(
        nodes: study.nodes,
        workcenters: workcenters,
        part: part,
        batchSize: first.batchSize,
        needDate: first.needDate,
        takt: takt,
      );
      if (again != null) candidate = again.subtract(study.startBuffer);
    }

    // **And never before the material lands.** Starting earlier buys nothing:
    // §7.2 gates every release on `material date ≤ slot`, so slots opened ahead
    // of the delivery go out empty and the order waits anyway — the run simply
    // begins with a stretch of empty cadence it could not have used. Only the
    // first order's date matters here, because it is the one this offset is
    // walked back from.
    final material = first.materialDate;
    if (material != null && material.isAfter(candidate)) candidate = material;

    // Kept per study **and** folded into the run's clock start. The fold is
    // only for the clock: what each study releases from is its own entry.
    byStudy[study.id] = candidate;
    if (start == null || candidate.isBefore(start)) start = candidate;
  }

  return RunPlan(start: start, lastNeedDate: lastNeed, startByStudy: byStudy);
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

  /// The part it last ran, for the changeover rule (§7.6).
  ///
  /// Null at cold start, and since v17 that is **not** a free pass: an empty
  /// station is set up for nothing, so no previous order counts as not the same
  /// part and the first order pays in full. That removes the one special case
  /// the rule used to carry.
  String? lastPartId;

  /// The teardown this server still owes for the order it last ran (§7.6).
  ///
  /// **Teardown is charged with the next setup rather than at the end of the
  /// order that incurred it.** Setup looks backwards and `lastPartId` already
  /// answers it; teardown looks forwards — a station is only stripped because
  /// something different is coming — and at the moment an order finishes the
  /// engine has not picked the next one. So the debt is remembered and settled
  /// when the answer exists, which is what a changeover physically is.
  ///
  /// The last order at a station never pays it, and that is correct rather than
  /// an omission: nothing waits on it, so it moves no figure anyone reads.
  SimStep? teardownOwed;

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

  /// The queue it is standing in — the one belonging to the step's target, and
  /// shared with every other step that names it (§5.5).
  final SimQueue lane;

  Duration get work => perPiece * order.batchSize;
}

class _Engine {
  _Engine({
    required this.studies,
    required this.workcenters,
    required this.start,
    required this.guard,
    required this.scheduleHorizon,
    this.scheduledStations = const {},
    this.startByStudy = const {},
  });

  final List<SimStudy> studies;
  final Map<String, SimWorkcenter> workcenters;

  /// The stations monthly capacity is written for. See `runSimulation`; empty
  /// falls back to [workcenters].
  final Map<String, SimWorkcenter> scheduledStations;

  final DateTime start;

  /// Where each study's first release slot falls (§7.8). A study absent from
  /// here — no costable first order — falls back to [start].
  final Map<String, DateTime> startByStudy;

  final DateTime guard;

  /// Carried, never read: §11.1's horizon is reported rather than obeyed.
  final DateTime? scheduleHorizon;

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

  /// The takt each order opened under (§7.9), kept from its release until its
  /// last step is costed.
  ///
  /// **On the order, because that is what it is a property of.** An order takes
  /// the takt in force when it opens and keeps it the whole way down the plant,
  /// so a step reached in June is still worth what it was worth in March —
  /// re-reading the schedule at the moment of service is the mid-flight
  /// re-cadencing §18.3 rules out.
  final Map<String, SimTakt?> _takt = {};

  /// Why a study stopped opening orders before its sequence ran out, or absent
  /// where it did not (§7.9.2).
  ///
  /// Only ever *"the line has no takt from here"*: every other reason a slot
  /// goes unused spends the slot and comes round again, which is an empty slot
  /// (§18.5). This one ends the cadence, so there is no next slot to record.
  final Map<String, DateTime> _cadenceEnded = {};

  /// Orders currently in the flow, per study, for the CONWIP cap (§7.3).
  final Map<String, int> _open = {};

  /// How far down each study's sequence the releases have got.
  final Map<String, int> _head = {};

  /// The order a server is running, so a finish knows what it completed.
  final Map<String, _Waiting> _running = {};

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
      for (final order in study.orders) {
        _orders['${study.id}/${order.id}'] = order;
        _released[order.id] = null;
        _delivered[order.id] = null;
      }
      // **Its own cold start, not the run's** (§7.8): the run's clock begins at
      // the earliest study's, and a later line waits for its own.
      if (study.orders.isNotEmpty) {
        _schedule(
          startByStudy[study.id] ?? start,
          _EventKind.slot,
          key: study.id,
        );
      }
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

    // **A slot landing where the line has no takt opens nothing** (§7.9.2), and
    // the check is here rather than only where the next slot is placed: an
    // interval measured inside a period can carry the slot past its end, so the
    // question has to be asked when the slot comes round rather than when it
    // was booked.
    //
    // Not an empty slot either (§18.5). An empty slot is one that came round
    // and went unused — the cadence was there and the order was not ready. Here
    // there is no cadence, so there was never a slot to spend.
    if (study.taktPeriods.isNotEmpty && study.taktAt(_now) == null) {
      final resumes = study.cadenceResumesAfter(_now);
      if (resumes == null) {
        _cadenceEnded[study.id] = _now;
      } else {
        _schedule(resumes, _EventKind.slot, key: study.id);
      }
      return;
    }

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
    } else if (_gateIsFull(study, order, study.taktKeyAt(_now))) {
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
      // **The takt it opened under, fixed here and never read again** (§7.9).
      _takt[order.id] = study.taktKeyAt(_now);
      _schedule(_now, _EventKind.arrive, key: study.id, orderId: order.id, index: 0);
    }

    // The next slot comes whether this one was used or not — strict takt slots,
    // no skipping. Stop once the sequence is exhausted, so an idle plant does
    // not accumulate empty slots for orders that do not exist.
    if (_head[study.id]! < study.orders.length) {
      final next = _nextSlot(study);
      if (next == null) {
        // **The line has no takt from here on, so it opens nothing** (§7.9.2).
        // Not an empty slot: an empty slot is a slot that came round and went
        // unused, and there is no cadence left to bring one round.
        _cadenceEnded[study.id] = _now;
      } else {
        _schedule(next, _EventKind.slot, key: study.id);
      }
    }
  }

  /// When this study's next release slot falls, or **null where its cadence has
  /// ended** (§7.9.2).
  ///
  /// The takt is read at the current instant rather than once at the start: a
  /// takt period says how often orders open *in it*, so a run crossing 1 April
  /// opens at one rate before and another after. An instant no period covers
  /// has no cadence at all — the study looks again at the start of the next
  /// period, and stops for good where there is none.
  ///
  /// **That is what a schedule running out already means one level down**,
  /// where `WorkcenterScheduleSpec` leaves a station with no operators rather
  /// than carrying its last staffing forward.
  DateTime? _nextSlot(SimStudy study) {
    final interval = study.intervalAt(_now);
    if (interval == null) {
      // In a gap, or past the end. Resume at the next period's first day if the
      // line has one; the slot lands there rather than an interval past it,
      // because the new cadence starts when the period does.
      return study.cadenceResumesAfter(_now);
    }

    final calendar = workcenters[study.releaseCalendarId]?.calendar;
    if (calendar == null) return _now.add(interval);
    try {
      return calendar.advance(_now, interval);
    } on StateError {
      return _now.add(interval);
    }
  }

  // --- Movement --------------------------------------------------------------

  /// How many orders are standing in the queue of [targetId].
  ///
  /// **By target, across every study.** This counted `(study, stepIndex)` and so
  /// gave two lines feeding CLAD07 a floor space each. Counting by target is
  /// what makes a shared queue actually shared: an order from line B fills a
  /// slot line A can then not have, which is the contention §7.7 exists to
  /// model.
  ///
  /// Counted off `_waiting` rather than tracked separately, because that list
  /// *is* the queue: an order is in it from the moment it enters until a server
  /// pulls it out. A second counter would be a second truth to keep in step, and
  /// the run is small enough that scanning is not the cost — the events are
  /// (§16.9).
  int _queued(String targetId) =>
      _waiting.where((w) => w.lane.targetId == targetId).length;

  /// Whether the queue in front of [stepIndex] has room for one more.
  bool _hasRoom(SimStudy study, int stepIndex) {
    final queue = study.nodes[stepIndex].queue;
    final capacity = queue.capacity;
    return capacity == null || _queued(queue.targetId) < capacity;
  }

  /// The first step [order] lands on when it is released — not necessarily
  /// node 0, since §8.1 skips the steps its part does not visit.
  int? _entry(SimStudy study, SimOrder order, SimTakt? takt) =>
      _nextStep(study, order, takt, 0);

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
  bool _gateIsFull(SimStudy study, SimOrder order, SimTakt? takt) {
    if (_entry(study, order, takt) case final first?
        when !_hasRoom(study, first)) {
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
    return index < 0 ? null : index;
  }

  /// The next step [order] must visit from [from] on, or null when it has
  /// finished the flow.
  ///
  /// Buffers still cost nothing to pass through (§2.12): what they cost is
  /// *room*, and that is charged by [_hasRoom] at the step they feed rather
  /// than as a delay here.
  ///
  /// **A step worth zero to this order is not a step it visits** (§8.1). Zero
  /// is what a part's routing records where it does not go through a station —
  /// `SimulationRunSteps.processSeconds`' own doc says so — and the engine used
  /// to queue the order there anyway: it took a slot on the lane, occupied the
  /// station for no time, and stored a step row. On a capped lane that slot is
  /// one a real order needed, and on the Gantt those rows pushed every station
  /// behind them one place later, which is how CEU32 came to be drawn above
  /// CEU30 on a chart of a line that runs CEU30 first.
  ///
  /// **Judged under [takt], because zero-ness is not a property of the step.**
  /// `processTimeFor` prefers `balancedProcessTimes[takt]` over the part's own
  /// figure, and §7.4's rebalance is free to empty a station out of a routing
  /// at one takt and fill it at another — §7.9 measured exactly that, CEU32 at
  /// 0.0 h under a five-day takt and busy under four. So the takt an order
  /// opened under decides which steps it has, and it is fixed for that order's
  /// whole journey (§7.9).
  ///
  /// **A blank is a zero, since §9.7.** It used to be returned rather than
  /// skipped: null meant "the part is missing a figure it needs", [_admit]
  /// declined to admit the order, and the order never completed at all.
  ///
  /// That was overturned by the field on 2026-08-29, after §9 gave a flow a
  /// second visit to one station and left fifteen parts to be told, one cell
  /// at a time, that they cost `00:00:00` there. *"If it is empty consider
  /// 0."*
  ///
  /// **What it costs is on record rather than hidden**: a time nobody typed and
  /// a step a part genuinely skips are now the same thing to the engine, so a
  /// forgotten cell no longer stops the run — it quietly takes the station out
  /// of that part's routing, and every figure downstream is short by whatever
  /// should have been there. That was §11's *"one intolerable bug"* when the
  /// distinction was drawn; the field has weighed the typing against it and
  /// chosen. Listed in §11 so the trade is visible rather than inherited.
  int? _nextStep(SimStudy study, SimOrder order, SimTakt? takt, int from) {
    final part = study.parts[order.partId];
    for (var index = from; index < study.nodes.length; index++) {
      final perPiece = study.nodes[index].processTimeFor(
        order.partId,
        part,
        takt: takt,
      );
      if (perPiece != null && perPiece > Duration.zero) return index;
    }
    return null;
  }

  void _onArrive(_Event event) {
    final study = _studyById(event.key!);
    final order = _orders['${study.id}/${event.orderId}']!;
    final index = _nextStep(study, order, _takt[order.id], event.index!);

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
    final step = study.nodes[index];
    final perPiece = step.processTimeFor(
      order.partId,
      study.parts[order.partId],
      takt: _takt[order.id],
    );
    if (perPiece == null) {
      // **Unreachable through [_nextStep], which skips a blank as a zero
      // (§9.7).** Kept as the guard it always was rather than removed: nothing
      // else may call this with a step the part has no figure for, and a
      // `null!` here would be a crash where this is a no-op.
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
        lane: step.queue,
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

  /// How the lane this order stands in actually dispatches (§7.4).
  ///
  /// **[SimQueue.effectiveRule], which is where the FIFO default now lives**
  /// (v28). It used to be applied when the project was loaded, which erased the
  /// difference between a lane someone typed FIFO on and one nobody typed
  /// anything on before the run could copy it in. The engine is the only reader
  /// that wants the default, so it is the only one that applies it.
  DispatchRule _ruleFor(_Waiting waiting) => waiting.lane.effectiveRule;

  /// Whether [a] should run before [b] under [rule] (§7.4).
  ///
  /// Each rule adds its own first key; all of them fall through to arrival,
  /// then **need date**, then sequence number, so contention between two
  /// studies over a shared workcenter is reproducible.
  ///
  /// **The need date refills the slot study priority held** (#6, v28). Priority
  /// sat here, below arrival, which is why it could never expedite anything:
  /// two orders reaching a station at different times never get this far. What
  /// the slot actually decides is a *tie* on arrival — 78 of them in the live
  /// database's 189,623 step rows, and **27 were settled by comparing two
  /// UUIDs**, so *"why did this order go first?"* was unanswerable a third of
  /// the time.
  ///
  /// It is a **no-op on an EDD lane**, where the need date is already the first
  /// key, and on every pair that does not tie on arrival. So it fires exactly
  /// where FIFO, LIFO and SPT have nothing left to say, and makes the answer a
  /// planner's sentence: *"both hit CEU27 at 09:00; that one was due first."*
  ///
  /// The cost, stated plainly: a FIFO lane is no longer purely FIFO in its
  /// residue. Accepted, because that residue is a UUID today, which is not FIFO
  /// either — and §4.4 wants a run's output explicable, not merely repeatable.
  /// *Rejected: the study name*, which is editable, so fixing a typo in
  /// `Célula 11C` could silently reorder a run.
  bool _prefers(_Waiting a, _Waiting b, DispatchRule rule) {
    switch (rule) {
      case DispatchRule.earliestDueDate:
        final due = a.order.needDate.compareTo(b.order.needDate);
        if (due != 0) return due < 0;
      case DispatchRule.shortestProcessing:
        final work = a.work.compareTo(b.work);
        if (work != 0) return work < 0;
      case DispatchRule.lifo:
        // **The one rule that inverts the fall-through rather than adding a
        // key.** Every other rule breaks ties by arrival ascending; a stack is
        // arrival descending, so the last order to reach the queue is the one
        // on top of it.
        final last = b.since.compareTo(a.since);
        if (last != 0) return last < 0;
      case DispatchRule.fifo:
        break;
    }

    final arrival = a.since.compareTo(b.since);
    if (arrival != 0) return arrival < 0;

    final due = a.order.needDate.compareTo(b.order.needDate);
    if (due != 0) return due < 0;

    final sequence = a.order.sequence.compareTo(b.order.sequence);
    if (sequence != 0) return sequence < 0;

    // Two orders of one study cannot share a sequence number, so this only
    // separates orders of two studies that tied on arrival and are due the
    // same day.
    return a.order.id.compareTo(b.order.id) < 0;
  }

  void _start(_Server server, _Waiting waiting) {
    _waiting.remove(waiting);

    final schedule = server.workcenter.schedule;
    final availability = schedule.availabilityOn(_now);

    // **The crew on the shift this work starts in** (§7.5, v30), and only where
    // the station's type says the crew *is* its throughput. Read at `_now` and
    // held for the whole job, exactly as availability above is — a job
    // beginning at 22:00 under a two-operator night shift is costed at two even
    // if it runs into a three-operator morning. Letting the rate change
    // mid-process is a different engine, and one §4.4 already declines.
    final operators = server.workcenter.labourPaced
        ? server.workcenter.calendar.operatorsAt(_now)
        : 1;

    // A changeover is the teardown this server still owes plus the setup the
    // arriving order needs, charged together and discounted together when the
    // part has not changed (§7.6).
    //
    // **`days` resolves against this server's productive day**, which is why the
    // step carries a value and a unit rather than a duration: a pool's three
    // machines do not share a working day, and there is no representative one to
    // pick. Same day as the Process Specific Takt sitting beside it in the
    // editor, so the dialog has one kind of day (§17.4).
    final productiveDay =
        server.workcenter.calendar.openTimePerWorkingDay(_now) * availability;

    // No previous order counts as *not the same part*: an empty station at cold
    // start is set up for nothing.
    final repeated = server.lastPartId == waiting.order.partId;

    final changeover =
        (server.teardownOwed?.teardownAt(productiveDay, repeated: repeated) ??
            Duration.zero) +
        waiting.step.setupAt(productiveDay, repeated: repeated);

    // **Availability no longer derates the changeover.** It is applied exactly
    // once (§6.1), and since v17 it is applied inside `days` — a setup typed in
    // productive days has already had the loss taken out of the day it is
    // measured in, so derating the result as well would count it twice, which is
    // the trap §6.1 warns about from the capacity side. Rework attaches to the
    // part's work only.
    // Kept apart from the changeover rather than only summed, because the work
    // is what §7.4's balance moves between stations and a run had no way to
    // state it: the step rows bracket the work on the calendar, so a bigger
    // share and a longer weekend look identical (§7.10, v21).
    final work = effectiveProcessTime(
      processTimePerPiece: waiting.perPiece,
      batchSize: waiting.order.batchSize,
      availability: availability,
      rework: schedule.reworkOn(_now),
      operators: operators,
    );
    // **The same work in labour hours** — what the crew between them spent,
    // rather than how long the station was held (§7.5, v30). The two are the
    // same number everywhere but an operator-paced station, and there they
    // differ by the crew: three people hold a bench for four hours and spend
    // twelve.
    //
    // This is what a step *stores*, because it is the half §10.3 draws against
    // an operator-paced capacity — counting a crewed station's demand in
    // station-hours against a denominator in operator-hours would divide the
    // crew out twice. The span the station was actually held for is
    // `processStart → processEnd`, which is what the Gantt draws and what
    // `busyByWorkcenter` sums, so nothing that measures occupancy reads this.
    final labour = effectiveProcessTime(
      processTimePerPiece: waiting.perPiece,
      batchSize: waiting.order.batchSize,
      availability: availability,
      rework: schedule.reworkOn(_now),
    );
    // The same work with rework left off (§10.2). Computed rather than divided
    // back out of `work`: the two differ by a rounding otherwise, and a stacked
    // bar whose segments do not sum to the whole is the §7.6 failure again.
    final labourBeforeRework = effectiveProcessTime(
      processTimePerPiece: waiting.perPiece,
      batchSize: waiting.order.batchSize,
      availability: availability,
    );
    final occupancy = work + changeover;

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
      // The debt this order leaves behind, settled by whoever arrives next. It
      // replaces rather than accumulates: a station holds one job's tooling, so
      // there is only ever one strip-down outstanding.
      ..teardownOwed = waiting.step
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
        // What it actually cost, not merely that it happened (§7.10). A bool
        // was enough while the answer was all-or-nothing; a repeat charged at a
        // percentage is neither incurred nor not, and this is the only place the
        // new rule can be checked against what it did.
        changeoverSeconds: changeover.inSeconds,
        processSecondsBeforeRework: labourBeforeRework.inSeconds,
        // And what the work itself cost, which is the half §7.4 moves and the
        // one an elapsed span cannot be read back into (v21). **In labour
        // hours** since v30 — see `labour` above.
        processSeconds: labour.inSeconds,
        // The lane it was pulled out of, so the run can say where it stood
        // without joining back to a flow that may have been edited (§7.10).
        laneNodeId: waiting.lane.targetId,
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
    final next = _nextStep(
      study,
      waiting.order,
      _takt[waiting.order.id],
      waiting.nodeIndex + 1,
    );

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
            // The takt it opened under (§7.9), read off what the engine fixed
            // at release rather than looked up again — the two could not differ,
            // and only one of them is what the order was actually costed at.
            taktValue: _takt[order.id]?.value,
            taktUnit: _takt[order.id]?.unit,
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
    /// What a station offers between two instants, in the unit its pacing
    /// measures capacity in (§7.5, v30).
    ///
    /// **Machine-paced is station-hours × units** — how long the machines were
    /// open, which is what capacity has always meant here. **Operator-paced is
    /// operator-hours**: the same open time weighted by the crew standing in
    /// it, because at a bench the people are the capacity and adding one adds
    /// room. Both are *resource* hours; the resource differs.
    ///
    /// `units` does not multiply an operator-paced station: two benches with
    /// one crew between them are not two crews, and the crew is already
    /// counted. A station that is genuinely both says so with its type and its
    /// Orders at once, and this is where they would disagree.
    Duration capacityOf(
      SimWorkcenter station,
      DateTime from,
      DateTime to,
      int units,
    ) => station.labourPaced
        ? station.calendar.operatorTimeBetween(from, to)
        : station.calendar.openTimeBetween(from, to) * units;

    // **One station set, and it is a union** (phase 9). This used to be
    // [workcenters] — what the routings reach — so capacity existed only where
    // demand did and a scheduled station nobody routed to was invisible rather
    // than idle. Occupation is demand against capacity, and a denominator
    // clipped to its own numerator cannot show a plant with room to spare.
    //
    // A union rather than a replacement, because neither set contains the
    // other: a station can be routed to with no schedule of its own, and it
    // keeps the rows it has always had.
    final open = <String, Duration>{};
    final openByMonth = <String, Map<DateTime, Duration>>{};
    final capacityStations = scheduledStations.isEmpty
        ? workcenters
        : {...workcenters, ...scheduledStations};
    for (final entry in capacityStations.entries) {
      final units = entry.value.units < 1 ? 1 : entry.value.units;
      try {
        // **Station-hours, even at an operator-paced station.** This is
        // utilization's denominator (§8.3) and its numerator is how long the
        // machine was *held* — a question about the machine, so both halves
        // count the machine's clock. Occupation asks the other question and
        // gets the other unit, in the monthly rows below.
        open[entry.key] =
            entry.value.calendar.openTimeBetween(start, _now) * units;
      } on StateError {
        open[entry.key] = Duration.zero;
      }
    }

    // The same walk cut into months (§10.2), **bounded per station by its own
    // schedule** rather than by the run — so the grid goes ragged: a station
    // whose schedule stops a year earlier is *blank* past it rather than zero.
    // §10.2's own distinction — nobody has said is not the same claim as said
    // zero.
    for (final entry in capacityStations.entries) {
      final units = entry.value.units < 1 ? 1 : entry.value.units;
      final periods = entry.value.schedule.periods;
      // Sorted by start date, so the last period is not necessarily the one
      // that ends last.
      final DateTime from0;
      final DateTime to0;
      if (periods.isEmpty) {
        // No schedule to be bounded by — the run is all this station can be
        // asked about. Reached by callers that pass no [scheduledStations].
        from0 = start;
        to0 = _now;
      } else {
        from0 = dateOnly(periods.first.startDate);
        // `endDate` is inclusive (§11.1) and `openTimeBetween` is half-open,
        // so the last day of the schedule needs the day after it as the bound.
        to0 = dateOnly(
          periods.map((p) => p.endDate).reduce((a, b) => a.isAfter(b) ? a : b),
        ).add(const Duration(days: 1));
      }
      final months = <DateTime, Duration>{};
      for (var month = DateTime(from0.year, from0.month);
          month.isBefore(to0);
          month = DateTime(month.year, month.month + 1)) {
        final next = DateTime(month.year, month.month + 1);
        final from = month.isBefore(from0) ? from0 : month;
        final to = next.isAfter(to0) ? to0 : next;
        if (!to.isAfter(from)) continue;
        try {
          months[month] = capacityOf(entry.value, from, to, units);
        } on StateError {
          // A station with no staffed shift in that month has no open time in
          // it, which is a real answer and is drawn as a floor rather than as a
          // gap (§10.2).
          months[month] = Duration.zero;
        }
      }
      openByMonth[entry.key] = months;
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
      scheduleHorizon: scheduleHorizon,
      steps: _rows,
      orders: outcomes,
      emptySlots: _empties,
      cadenceEndedByStudy: Map.unmodifiable(_cadenceEnded),
      busyByWorkcenter: busy,
      openByWorkcenter: open,
      openByWorkcenterMonth: openByMonth,
      blockedByWorkcenter: blocked,
      // Every lane the run walked, so §8.6 can place a row for one that never
      // held anything — an empty lane between two busy stations is a fact
      // about the line, not a row to leave out.
      // **One row per target, not per study.** A queue belongs to the station it
      // stands in front of, so two studies feeding CLAD07 report the one queue
      // they actually share — which is what stopped the Gantt drawing it twice.
      // The first study to name a target reports it: arbitrary, stable, and what
      // matters is that the second does not report it again.
      lanes: [
        for (final entry in {
          for (final study in studies)
            for (final node in study.nodes)
              node.queue.targetId: (study: study, node: node),
        }.entries)
          SimLane(
            studyId: entry.value.study.id,
            nodeId: entry.key,
            position: entry.value.node.position,
            // **No name since v27** (#5): the caption is `<type> · <target>`
            // and both halves are already on the run, so it is derived at
            // render and reads in the reader's language rather than being
            // frozen in whoever's ran it.
            rule: entry.value.node.queue.rule,
            capacity: entry.value.node.queue.capacity,
          ),
      ],
      // Whatever is still standing in a lane. `_waiting` is the queue itself,
      // so what is left in it at the end is exactly what never got pulled.
      openLaneVisits: [
        for (final waiting in _waiting)
          SimOpenLaneVisit(
            studyId: waiting.study.id,
            orderId: waiting.order.id,
            laneNodeId: waiting.lane.targetId,
            stepNodeId: waiting.step.id,
            enteredAt: waiting.since,
          ),
      ],
      abort: abort,
    );
  }
}
