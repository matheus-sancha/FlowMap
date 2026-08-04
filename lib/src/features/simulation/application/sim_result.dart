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

  /// Time spent queueing — the difference between this run and the theoretical
  /// lead time, which excludes exactly this (§7.9).
  Duration get wait => processStart.difference(queueStart);

  /// Wall-clock time the workcenter was committed, closed hours included.
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

  /// Delivery float: negative is early, positive is late (§8).
  Duration? get float => delivered?.difference(needDate);

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

  /// Open time each workcenter actually spent running, for utilisation (§8.3).
  final Map<String, Duration> busyByWorkcenter;

  /// Open time each workcenter had available across the run — the denominator
  /// utilisation is measured against, and the thing that makes it different
  /// from occupation.
  final Map<String, Duration> openByWorkcenter;

  final SimAbortReason? abort;

  bool get completed => abort == null;

  Iterable<SimOrderOutcome> get undelivered =>
      orders.where((o) => o.delivered == null);

  /// Busy ÷ open, per workcenter — **utilisation**, a simulated output, which
  /// differs from occupation wherever sequencing or starvation got in the way
  /// (§8.3).
  Map<String, double> get utilisation => {
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
