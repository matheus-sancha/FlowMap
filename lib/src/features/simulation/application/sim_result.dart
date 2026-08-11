/// What a run produces (DESIGN.md §7.10).
///
/// **One row per order-step**, plus the per-order outcomes and the slots that
/// went out empty. Everything a report asks later — order Gantts, queue
/// histories, bottleneck evidence, "why was PN2 late" — is a query over these
/// rather than another run.
library;

/// One order's visit to one step.
class SimOrderStep {
  const SimOrderStep({
    required this.studyId,
    required this.orderId,
    required this.nodeId,
    required this.workcenterId,
    required this.queueStart,
    required this.processStart,
    required this.processEnd,
    required this.changeoverIncurred,
    this.laneNodeId,
    this.blocked = Duration.zero,
  });

  final String studyId;
  final String orderId;
  final String nodeId;

  /// The workcenter that **actually** ran it, which for a pool step is only
  /// known once the run has happened (§3.1).
  final String workcenterId;

  /// When the order reached this step and started waiting.
  final DateTime queueStart;

  final DateTime processStart;
  final DateTime processEnd;

  /// Whether the order before this one on that workcenter was a different part
  /// (§7.6).
  final bool changeoverIncurred;

  /// The lane the order waited in before this step, or null when the step has
  /// none and the order queued at the station itself (§5.5).
  ///
  /// [queueStart] is when it entered that lane and [processStart] is when it was
  /// pulled out, so a lane's occupancy over time is readable off these rows
  /// without the engine keeping a second record of the same fact.
  final String? laneNodeId;

  /// How long the workcenter stood holding this order after finishing it,
  /// because the lane ahead was full (§5.5).
  ///
  /// Blocking is **after service**: a station cannot know whether there will be
  /// room until it has something to put down, so it finishes and then waits.
  /// [processEnd] is when the work stopped; `processEnd + blocked` is when the
  /// station was free again.
  final Duration blocked;

  /// Time spent queueing — the difference between this run and the theoretical
  /// lead time, which excludes exactly this (§7.9).
  Duration get wait => processStart.difference(queueStart);

  /// Wall-clock time the workcenter was committed, closed hours included.
  ///
  /// Work only. The blocked tail is [blocked] and is deliberately not folded in
  /// here: a jammed station is occupied and producing nothing, and adding the
  /// two would make utilization report the jam as output.
  Duration get occupied => processEnd.difference(processStart);
}

/// How one order fared.
class SimOrderOutcome {
  const SimOrderOutcome({
    required this.studyId,
    required this.orderId,
    required this.sequence,
    required this.partId,
    required this.needDate,
    required this.released,
    required this.delivered,
  });

  final String studyId;
  final String orderId;
  final int sequence;
  final String partId;
  final DateTime needDate;

  /// When it entered the flow, or null if it never did — the sequence ran out
  /// of slots before the guard stopped the run.
  final DateTime? released;

  /// When it finished its last semantic step (§18.1). Null if it never did.
  final DateTime? delivered;

  /// Delivery float — slack against the need date: **positive is early**, with
  /// that much time in hand, and negative is late by that much (§8).
  ///
  /// This was `delivered − need date` until the Production Plan put the figure
  /// in front of a planner, for whom float has meant slack since long before
  /// this app existed. The old sign made an over-committed sequence report
  /// `average float +230.7 d`, which reads as seven months of room to spare and
  /// meant the exact opposite. Defined once here, so the plan's column and the
  /// Simulation tab's headline cannot disagree about which way is good.
  Duration? get float =>
      delivered == null ? null : needDate.difference(delivered!);

  bool get isOnTime => delivered != null && !delivered!.isAfter(needDate);

  /// Wall-clock time in the flow.
  Duration? get leadTime => (released == null || delivered == null)
      ? null
      : delivered!.difference(released!);
}

/// A release slot that went out empty (§7.2).
///
/// Counted and dated rather than treated as an error: the sequence is the thing
/// under study, and the app must not silently repair a bad one.
class SimEmptySlot {
  const SimEmptySlot({
    required this.studyId,
    required this.at,
    required this.reason,
  });

  final String studyId;
  final DateTime at;
  final EmptySlotReason reason;
}

enum EmptySlotReason {
  /// The head of the sequence has no material yet.
  awaitingMaterial,

  /// The flow is already at its CONWIP cap (§7.3).
  wipCap,

  /// The lane the release would put the order into is full (§5.5).
  ///
  /// Distinct from [wipCap] on purpose: that one is a policy the user set for
  /// the whole flow, this one is the floor running out at one place. Counting
  /// them together would have made §18.5's empty-slot metric say "the line was
  /// held back" without ever saying by what.
  laneFull,
}

/// An order still standing in a lane when the run ended (§5.5).
///
/// Every other stay in a lane is readable off [SimOrderStep] — `queueStart` is
/// when the order entered and `processStart` is when it was pulled out — but an
/// order the guard caught mid-wait never produces a step, and dropping it would
/// draw the lane emptier than it was at exactly the moment a jam is the finding.
class SimOpenLaneVisit {
  const SimOpenLaneVisit({
    required this.studyId,
    required this.orderId,
    required this.laneNodeId,
    required this.enteredAt,
  });

  final String studyId;
  final String orderId;
  final String laneNodeId;
  final DateTime enteredAt;
}

/// Why a run stopped early, if it did.
enum SimAbortReason {
  /// The guard at ≈5× the horizon implied by demand fired: demand exceeds
  /// capacity and orders would never have completed (§7.8).
  horizonExceeded,

  /// Nothing could be started at all — every station's calendar is shut, or no
  /// study had a costable first order.
  nothingToRun,
}

/// A completed run.
class SimRunResult {
  const SimRunResult({
    required this.start,
    required this.end,
    required this.guard,
    required this.steps,
    required this.orders,
    required this.emptySlots,
    required this.busyByWorkcenter,
    required this.openByWorkcenter,
    this.blockedByWorkcenter = const {},
    this.openLaneVisits = const [],
    this.abort,
  });

  /// Cold start: the plant is empty here (§7.8).
  final DateTime start;

  /// The last event processed.
  final DateTime end;

  /// Where the run would have been abandoned.
  final DateTime guard;

  final List<SimOrderStep> steps;
  final List<SimOrderOutcome> orders;
  final List<SimEmptySlot> emptySlots;

  /// Open time each workcenter actually spent running, for utilization (§8.3).
  final Map<String, Duration> busyByWorkcenter;

  /// Open time each workcenter had available across the run — the denominator
  /// utilization is measured against, and the thing that makes it different
  /// from occupation.
  final Map<String, Duration> openByWorkcenter;

  /// Time each workcenter spent holding a finished order it could not put down,
  /// because the lane ahead was full (§5.5).
  ///
  /// **Not part of [busyByWorkcenter].** A blocked station is occupied and
  /// producing nothing; folding the two would let a jam read as output, and on
  /// a line whose constraint already sits at 86 % utilization that is not a
  /// rounding error. Empty on every run made before lanes had capacity.
  final Map<String, Duration> blockedByWorkcenter;

  /// Orders still standing in a lane when the run ended.
  final List<SimOpenLaneVisit> openLaneVisits;

  final SimAbortReason? abort;

  bool get completed => abort == null;

  Iterable<SimOrderOutcome> get undelivered =>
      orders.where((o) => o.delivered == null);

  /// Busy ÷ open, per workcenter — **utilization**, a simulated output, which
  /// differs from occupation wherever sequencing or starvation got in the way
  /// (§8.3).
  Map<String, double> get utilization => {
    for (final entry in openByWorkcenter.entries)
      if (entry.value.inSeconds > 0)
        entry.key:
            (busyByWorkcenter[entry.key] ?? Duration.zero).inSeconds /
            entry.value.inSeconds,
  };

  /// On-time deliveries ÷ total orders (§8).
  double get onTimeDelivery =>
      orders.isEmpty ? 0 : orders.where((o) => o.isOnTime).length / orders.length;
}
