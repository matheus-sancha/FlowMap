/// What a run produces (DESIGN.md §7.10).
///
/// **One row per order-step**, plus the per-order outcomes and the slots that
/// went out empty. Everything a report asks later — order Gantts, queue
/// histories, bottleneck evidence, "why was PN2 late" — is a query over these
/// rather than another run.
library;

import '../../../data/database/enums.dart';

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
    this.changeoverSeconds,
    this.processSeconds,
    this.processSecondsBeforeRework,
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

  /// What that changeover cost, in seconds of the station's open time.
  ///
  /// Null only on a run read back from before v17 — a fresh run always states
  /// it, including as zero. That is the distinction the column exists to keep:
  /// zero means nothing was charged, null means nobody recorded it.
  final int? changeoverSeconds;

  /// What the **work** cost here, in seconds of the station's open clock —
  /// changeover excluded (§7.4).
  ///
  /// [occupied] is the same work laid on the calendar and is therefore longer
  /// by whatever closed time it crossed; this is the figure that says what the
  /// station was asked to do, and the only one in which §7.4's balance is
  /// visible. Null on a run read back from before v21.
  final int? processSeconds;

  /// The same work **before rework is charged** — `per-piece × batch ÷
  /// availability` (§10.2).
  ///
  /// Carried beside [processSeconds] rather than derived from it: the two are
  /// fused by a rework fraction that lives on a schedule the plant may retune,
  /// and §7.10 forbids reading it back. Their difference is what rework cost,
  /// which is the middle segment of §10.3's bar.
  ///
  /// Null on a run read back from before v25.
  final int? processSecondsBeforeRework;

  /// [processSeconds] as a duration, or null where the run never recorded it.
  Duration? get process =>
      processSeconds == null ? null : Duration(seconds: processSeconds!);

  /// What rework cost at this step, or null where either figure is missing.
  ///
  /// **Subtracted rather than multiplied out**, so a station with no rework
  /// reads a true zero rather than a rounding of one.
  Duration? get reworkTime =>
      processSeconds == null || processSecondsBeforeRework == null
      ? null
      : Duration(seconds: processSeconds! - processSecondsBeforeRework!);

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
    this.taktValue,
    this.taktUnit,
  });

  final String studyId;
  final String orderId;
  final int sequence;
  final String partId;
  final DateTime needDate;

  /// The takt this order **opened** under, as it was typed (§7.9).
  ///
  /// **The cause of what every other figure here is the effect of.** Two orders
  /// of one part carry different work because they opened under different
  /// takts, and §7.10 forbids re-deriving that from a schedule the plant may
  /// have retuned since — so it travels with the order, exactly as the part
  /// number and the customer project do.
  ///
  /// Null where the order never opened, and on every run stored before v22.
  final double? taktValue;
  final TaktUnit? taktUnit;

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

/// A lane, as it stood when the run was made (§5.5, §7.10).
///
/// **Carried on the result so the chart never joins back to the flow.** §8.6
/// draws a lane row above the target it feeds, and it finds that target from
/// the steps that name the lane — not from anything stored here.
///
/// Deliberately not carrying the discipline: nothing that draws a lane reads
/// it, and a field nothing reads is the failure §1.5 found once already. The
/// run records the rule separately for the label that names the overrides.
class SimLane {
  const SimLane({
    required this.studyId,
    required this.nodeId,
    required this.position,
    this.name,
    this.capacity,
  });

  /// **Recovery-only. Do not read this for behaviour** (§16.20).
  ///
  /// v19 made a queue belong to a *target*, so a lane feeding a station two
  /// studies both step on is one row and this holds whichever study was written
  /// last — on the newest stored run, eight of ten lanes carry one study's id
  /// and two carry the other's. `filterRun` and the hover card each asked it
  /// anyway and each got a wrong answer (§7.5); lanes are kept by the steps that
  /// name them now, and a stay takes its study from the step.
  ///
  /// Kept rather than dropped because widening or removing a `NOT NULL` column
  /// rebuilds the table (§16.11), and because it is part of the only way back to
  /// what a pre-v19 run's flow looked like.
  final String studyId;

  /// The `flow_nodes` row it was, whether or not it still exists.
  final String nodeId;

  /// Its place on the spine at the time of the run.
  ///
  /// **Recovery-only, for the same reason as [studyId]** (§16.20). §8.6 places a
  /// lane by the target its steps name, so nothing reads this — and on a lane
  /// two studies share it is one study's position, which is not a fact about the
  /// other.
  final int position;

  /// `FIFO CEU27`, or null when the buffer was never labelled.
  final String? name;

  /// Orders it could hold, or null for unlimited — in which case §8.6 takes the
  /// row's depth from how full it actually got.
  final int? capacity;
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
    required this.stepNodeId,
    required this.enteredAt,
  });

  final String studyId;
  final String orderId;

  /// The workcenter or pool whose queue it is standing in (§7.3).
  final String laneNodeId;

  /// The flow node it is waiting *for* (§8.6). Two stays of one order in one
  /// station's queue are told apart by this and by nothing else.
  final String stepNodeId;

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
    this.openByWorkcenterMonth = const {},
    this.blockedByWorkcenter = const {},
    this.lanes = const [],
    this.openLaneVisits = const [],
    this.scheduleHorizon,
    this.abort,
    this.cadenceEndedByStudy = const {},
  });

  /// Study id → when its cadence ran out, for the studies whose did (§7.9.2).
  ///
  /// A line with no takt in force opens nothing, so a study whose schedule
  /// stops before its sequence does simply leaves the rest of it unreleased.
  /// **Without this the run reports the symptom and hides the cause**: orders
  /// that never opened look exactly like a jam, and the two want opposite
  /// responses.
  ///
  /// Absent for every study that released its whole sequence, which is every
  /// study on a plant whose takt table covers its demand.
  final Map<String, DateTime> cadenceEndedByStudy;

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

  /// The same open time **cut into the months the run spans** — workcenter id →
  /// first instant of the month → open seconds, units already multiplied in
  /// (§10.2).
  ///
  /// **One figure spanning eighteen months is no denominator for any of them**,
  /// which is `run_filter.dart`'s standing limitation said from the capacity
  /// side: §10.3 draws a capacity line per month and [openByWorkcenter] cannot
  /// answer it. Both are kept — the whole-run figure is what utilization is
  /// measured against and this is what a monthly bar is drawn under, and they
  /// sum to each other by construction.
  ///
  /// Empty on a result assembled before v25 and on one whose calendars could
  /// not be walked, which is the same empty a station with no schedule already
  /// reports as `Duration.zero` above.
  final Map<String, Map<DateTime, Duration>> openByWorkcenterMonth;

  /// Time each workcenter spent holding a finished order it could not put down,
  /// because the lane ahead was full (§5.5).
  ///
  /// **Not part of [busyByWorkcenter].** A blocked station is occupied and
  /// producing nothing; folding the two would let a jam read as output, and on
  /// a line whose constraint already sits at 86 % utilization that is not a
  /// rounding error. Empty on every run made before lanes had capacity.
  final Map<String, Duration> blockedByWorkcenter;

  /// Every lane in every study that ran, whether or not anything queued in it.
  ///
  /// Empty on runs made before lanes existed, which draws no lane rows — the
  /// honest reading of a run that had none.
  final List<SimLane> lanes;

  /// Orders still standing in a lane when the run ended.
  final List<SimOpenLaneVisit> openLaneVisits;

  /// The last date every schedule this run used was defined for (§11.1).
  ///
  /// Anything happening after it used a period carried forward from before it.
  /// That is the right behaviour — schedule periods are finite while a run goes
  /// until the last order completes, and refusing would make an overloaded
  /// plant unsimulatable exactly when the simulation is most informative — but
  /// it has to be **said**, because the reader cannot know how far to extend
  /// their periods until they have run it.
  ///
  /// Null on a run made before v16, and on one whose plant had no periods.
  final DateTime? scheduleHorizon;

  /// Orders that finished past [scheduleHorizon].
  ///
  /// Derived rather than stored beside the date, so the two cannot disagree
  /// about a set of orders both are describing.
  Iterable<SimOrderOutcome> get ordersPastHorizon {
    final horizon = scheduleHorizon;
    if (horizon == null) return const [];
    return orders.where(
      (o) => o.delivered != null && o.delivered!.isAfter(horizon),
    );
  }

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
