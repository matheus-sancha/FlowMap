/// What the map draws, computed once and rendered twice — on the canvas and
/// into the PDF (DESIGN.md §12.2).
///
/// A pure function of the study, the period being viewed and the schedules, so
/// every number on a process box can be tested without a widget tree. Nothing
/// here is stored: a schedule edit changes the map because the map is derived
/// (DESIGN.md §5.4).
library;

import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../calendar/application/shift_pattern_spec.dart' show dateOnly;
import '../../calendar/application/working_calendar.dart';
import '../../schedules/application/takt_schedule.dart';
import '../../schedules/application/workcenter_schedule.dart';

/// How wide a span the period navigator steps through.
///
/// The map is always rendered **at the first day of the span**, not averaged
/// across it: takt and staffing change on dated boundaries, and an averaged map
/// would show a takt no period actually has. Choosing a wider span therefore
/// says "step a quarter at a time", and [FlowView.scheduleVariesInPeriod] warns
/// when the span is not uniform.
enum PeriodGranularity {
  month,
  quarter,
  semester,
  year;

  /// The first day of the span containing [date].
  DateTime startOf(DateTime date) => switch (this) {
    PeriodGranularity.month => DateTime(date.year, date.month),
    PeriodGranularity.quarter => DateTime(
      date.year,
      ((date.month - 1) ~/ 3) * 3 + 1,
    ),
    PeriodGranularity.semester => DateTime(date.year, date.month <= 6 ? 1 : 7),
    PeriodGranularity.year => DateTime(date.year),
  };

  /// The last day of that span.
  DateTime endOf(DateTime date) {
    final start = startOf(date);
    return DateTime(start.year, start.month + months, 0);
  }

  int get months => switch (this) {
    PeriodGranularity.month => 1,
    PeriodGranularity.quarter => 3,
    PeriodGranularity.semester => 6,
    PeriodGranularity.year => 12,
  };

  /// The span [steps] spans away, keeping the same granularity.
  DateTime shift(DateTime date, int steps) {
    final start = startOf(date);
    return DateTime(start.year, start.month + months * steps);
  }
}

/// Which numbers the process boxes show (DESIGN.md §5.4).
enum FlowDataSource {
  /// The dummy part whose process time at each step is one takt of that step's
  /// own capacity (§6.1). Available as soon as takt and schedules exist, and
  /// the yardstick every other source is measured against.
  flowEquivalent,

  /// One demand part's own process times, rework included (§6.2).
  singlePart,

  /// Every part that visits the step, weighted by the pieces due in the period.
  weightedVariants;

  /// Whether this source reads real process times out of the demand table, and
  /// therefore has an equivalence to report against the yardstick.
  bool get isDemandPart => this != FlowDataSource.flowEquivalent;
}

/// What the map needs from the demand table when the boxes are showing a real
/// part (DESIGN.md §5.4, §6.2).
///
/// A plain value type owned by the flow rather than the demand feature: the
/// demand grid's columns are these process boxes, so demand already depends on
/// the flow, and this keeps that one-way.
class FlowDemandInput {
  const FlowDemandInput({
    this.processTimes = const {},
    this.piecesDueInPeriod = const {},
    this.selectedPartId,
    this.selectedPartNumber,
    this.batchSize = 1,
  });

  /// How many pieces the boxes are costing at once (§7.6).
  ///
  /// **The map used to have no notion of a batch**, so a box showed one piece
  /// while the engine charged `pt × batch ÷ availability` — an order of ten read
  /// a tenth of what the run did, and the two screens could not be reconciled.
  /// It defaults to the batch the selected part's orders actually use and is
  /// overridable, which is what makes lot sizing something the map can be asked
  /// about (§7.6's "Batch Size is a real lever").
  ///
  /// One under [FlowDataSource.flowEquivalent]: the dummy part is one piece by
  /// definition (§6.1).
  final int batchSize;

  /// `partId → step target → stored per-piece time`, exactly as typed. Rework
  /// is applied here, not stored (§4.4).
  final Map<String, Map<String, Duration>> processTimes;

  /// Pieces of each part with a need date inside the viewed span — the mix that
  /// weights [FlowDataSource.weightedVariants].
  final Map<String, int> piecesDueInPeriod;

  final String? selectedPartId;
  final String? selectedPartNumber;
}

/// Why a step cannot be costed.
enum StepProblem {
  /// The step targets neither a workcenter nor a pool.
  unbound,

  /// The workcenter it targets has been archived out from under it.
  archivedTarget,

  /// No workcenter schedule period covers the date being viewed.
  noSchedule,

  /// The pool has no members, so there is no capacity to read.
  emptyPool,

  /// The part being shown has no process time here — a blocking readiness
  /// error when a step must be visited (DESIGN.md §11). Only ever raised by a
  /// demand data source; the flow equivalent needs no demand to be costed.
  noProcessTime,
}

/// What a process box is labelled: the step's own label if it has one, else the
/// workcenter's or the pool's name (DESIGN.md §5.4).
///
/// Shared with the demand grid, whose columns *are* these boxes — so a step
/// renamed on the map renames its column, and the two can never disagree about
/// which step is which.
String flowStepTitle(
  FlowNode step, {
  required String? workcenterName,
  required String? poolName,
}) {
  final label = step.label;
  if (label != null && label.isNotEmpty) return label;
  final name = step.poolId != null ? poolName : workcenterName;
  return (name == null || name.isEmpty) ? '—' : name;
}

/// How the material flow between two boxes is drawn (DESIGN.md §5.2, §7.3).
///
/// **The queue type chooses it, and the queue type is typed where it can be
/// validated.** Every link on the spine is explained by something stored — the
/// study's WIP cap, and the discipline on the queue in front of the step the
/// link runs into — which is §5.2's standing rule that drawing documents intent
/// while the number that drives the engine lives somewhere it can be checked.
/// The connector is where that queue is *drawn*; §7.3 makes it where the queue
/// is set, which is the same one source of truth reached from the picture.
enum FlowConnectionKind {
  /// The striped arrow: material moved downstream whether or not the next step
  /// asked for it, and piles up where it lands. The honest default — with no
  /// supermarkets in the model (§5.5) and no discipline set, everything here
  /// **is** a push.
  push,

  /// The open arrow: a release requires a completion, so the flow is pulled.
  /// A study-level CONWIP cap (§7.3) is the only real pull lever FlowMap has.
  pull,

  /// A sequenced lane, taken in arrival order (§7.4).
  fifoLane,

  /// The top of the stack first — a lane on a plant that stacks material
  /// rather than channelling it.
  lifoLane,

  /// Earliest need date first.
  eddLane,

  /// Shortest processing time first.
  sptLane;

  /// The word written inside the channel, or null for the two shapes that are
  /// arrows rather than channels.
  ///
  /// **Untranslated on purpose.** `FIFO` is the notation's own word, not a
  /// sentence about it, and a value-stream map read in three languages carries
  /// the same four marks — which is also what lets the printed map (§13) write
  /// what the canvas draws.
  String? get channelLabel => switch (this) {
    FlowConnectionKind.push || FlowConnectionKind.pull => null,
    FlowConnectionKind.fifoLane => 'FIFO',
    FlowConnectionKind.lifoLane => 'LIFO',
    FlowConnectionKind.eddLane => 'EDD',
    FlowConnectionKind.sptLane => 'SPT',
  };

  bool get isChannel => channelLabel != null;
}

/// What to draw on the link **into** [downstream].
///
/// The kind belongs to the arrow's destination, not its source: a queue forms
/// in front of a station, and it is that station's discipline the channel
/// describes. The last link of the spine runs into the customer, which is not a
/// station and has no queue, so it falls back to the study's own kind.
///
/// **A stored discipline is a decision; an unset one is not.** Every station
/// dispatches FIFO by default (§7.4), so drawing a channel wherever a queue
/// *behaves* as FIFO would put one on every link and say nothing. An unset rule
/// therefore draws the push arrow — which is what an uncontrolled pile is, and
/// what §7.3's table lists it as — and choosing FIFO in the editor is the
/// statement that the lane is sequenced.
FlowConnectionKind connectionKindInto(
  FlowStepView? downstream, {
  required bool hasWipCap,
}) => switch (downstream?.queue?.rule) {
  DispatchRule.fifo => FlowConnectionKind.fifoLane,
  DispatchRule.lifo => FlowConnectionKind.lifoLane,
  DispatchRule.earliestDueDate => FlowConnectionKind.eddLane,
  DispatchRule.shortestProcessing => FlowConnectionKind.sptLane,
  null => hasWipCap ? FlowConnectionKind.pull : FlowConnectionKind.push,
};

/// The queue standing in front of one step, as the map draws it (§7.3, §5.5).
///
/// **One per target, shared by every step that feeds it.** Two studies whose
/// flows both reach CLAD07 draw the same queue, because the plant has one floor
/// space there — which is the correction §7.3 exists for, and the reason this
/// is keyed by [targetId] rather than carried on the node.
///
/// The stock figure is an **observation of a current state**, not a delay the
/// engine charges (§5.5): it feeds the lead-time ladder and the days-of-stock a
/// current-state map exists to state, and a run measures the real wait itself.
class FlowQueueView {
  const FlowQueueView({
    required this.targetId,
    required this.targetName,
    required this.wait,
    this.name,
    this.rule,
    this.capacity,
    this.quantity,
    this.unit,
    this.isCalendarWait = false,
    this.referenceWorkingDay,
  });

  /// The workcenter or pool the queue stands in front of — the key it is stored
  /// under, and what the editor writes back to.
  final String targetId;

  /// `CLAD04` or `CAL Pool` — the station's own name, not the step's label.
  ///
  /// The editor names the target and says the queue is shared by every step
  /// that feeds it (§7.3), and a step's label is what *this* study calls its
  /// visit; the other study's step may call it something else, and both wait in
  /// the same line.
  final String targetName;

  /// `FIFO CEU27` — what the shop floor calls this floor space.
  final String? name;

  /// The discipline someone set, or null for an uncontrolled pile. Null is not
  /// the same as FIFO here even though the engine treats it so: see
  /// [connectionKindInto].
  final DispatchRule? rule;

  /// Orders it holds before the station behind it is blocked. Null is
  /// unlimited.
  final int? capacity;

  /// How long the stock standing here represents. For a quantity this is
  /// `pieces × takt`, resolved through the capacity of the step it feeds.
  final Duration wait;

  /// Pieces, for a quantity observation.
  final int? quantity;

  /// The unit a fixed wait was typed in, so the map reads `2 days` rather than
  /// converting it to something nobody wrote.
  final DurationUnit? unit;

  /// A wait measured on the wall clock — cooling, transport — that does not
  /// stop for the weekend.
  final bool isCalendarWait;

  /// The productive day this queue's rung is drawn in.
  final Duration? referenceWorkingDay;

  /// Whether there is anything standing here to draw a triangle for.
  bool get hasStock => wait > Duration.zero || (quantity ?? 0) > 0;

  /// [wait] in the days its own rung is drawn in (§17.4).
  double get waitDays {
    // A calendar wait is measured in calendar days: 48 h of cooling is two
    // days, not the 2.9 productive days it would be against a 16.77-hour
    // working day.
    final day = (isCalendarWait ? null : referenceWorkingDay) ??
        const Duration(hours: 24);
    return day.inSeconds == 0 ? 0 : wait.inSeconds / day.inSeconds;
  }

  /// The working day the rung's `d` is measured in, or null where the wall
  /// clock is.
  Duration? get rungWorkingDay =>
      isCalendarWait || referenceWorkingDay == Duration.zero
      ? null
      : referenceWorkingDay;
}

/// A process box, and the queue standing in front of it.
///
/// **The only kind of node the spine has now** (§7.3). An inventory used to be
/// a second kind, sitting between two boxes with its own name, discipline and
/// capacity — and two studies through one machine therefore had two of them.
/// The queue belongs to what a step targets, so it belongs to the step, and
/// `FlowNodeView`'s sealed hierarchy became a base class with one subclass.
class FlowStepView {
  const FlowStepView(
    this.node, {
    required this.title,
    required this.typeName,
    required this.poolMemberCount,
    required this.dataSource,
    required this.processTime,
    required this.equivalentProcessTime,
    required this.changeover,
    this.samePartFraction = 0,
    required this.openPerWorkingDay,
    required this.productivePerWorkingDay,
    required this.openInPeriod,
    required this.capacityInPeriod,
    required this.operatorsAllocated,
    required this.operatorsPerShift,
    required this.availability,
    required this.rework,
    required this.problems,
    this.usesLocalEquivalent = false,
    this.scheduleCarriedForward = false,
    this.queue,
  });

  final FlowNode node;

  String get id => node.id;
  int get position => node.position;

  /// The queue in front of this step (§7.3), or null when the step targets
  /// nothing and so stands in front of no floor space.
  ///
  /// Drawn on the link *into* this box rather than on the box, because that is
  /// where the queue is: between the station before it and this one.
  final FlowQueueView? queue;

  /// `CLAD04` or the pool's name — what the box is labelled.
  final String title;

  /// The targeted workcenter's type — `Cladding` — which is what the box says
  /// about itself beyond its name. Null for a pool, and for a workcenter with
  /// no type set.
  ///
  /// Kept as the type's own name rather than a ready-made sentence: this layer
  /// has no `BuildContext`, so composing anything for the reader here would put
  /// an untranslated string on the map.
  final String? typeName;

  /// How many workcenters the pool holds, or null when the step targets one
  /// workcenter directly.
  final int? poolMemberCount;

  /// Which numbers this box is showing — carried here so a step can say for
  /// itself whether it has an [equivalence] to report.
  final FlowDataSource dataSource;

  /// What the box shows, under the selected data source (DESIGN.md §5.4).
  ///
  /// [FlowDataSource.flowEquivalent] shows [equivalentProcessTime]; the other
  /// two show a real part's own time with its rework applied (§6.2). The box,
  /// the lead-time ladder and the footer totals all read this one figure, so a
  /// step never reports two different times and PCE stays a ratio of like with
  /// like.
  ///
  /// Null when [problems] is non-empty: a step that cannot be costed shows a
  /// dash rather than a plausible zero.
  final Duration? processTime;

  /// One takt of this station's productive capacity — the flow equivalent's
  /// process time here (DESIGN.md §6.1), or the step's own Process Specific
  /// Takt Time where it carries one (§6.1.1).
  ///
  /// ```
  /// takt × (open_hours_per_working_day × availability)
  /// ```
  ///
  /// **Availability is in it; rework is not.** Availability is a property of
  /// the station's capacity, so it belongs here; rework is a loss on the work a
  /// *part* requires, so it attaches to that part's process time instead.
  ///
  /// Computed whatever the data source, because it is the **yardstick**: it is
  /// what [equivalence] divides by, and a step's share of the flow means
  /// nothing without it.
  final Duration? equivalentProcessTime;

  /// `part_pt ÷ FE_pt` at this step — how many takts of this station's capacity
  /// the part being shown actually consumes (DESIGN.md §6.2).
  ///
  /// Null under [FlowDataSource.flowEquivalent], where it would be 1.0 by
  /// construction and would say nothing.
  double? get equivalence {
    if (!dataSource.isDemandPart) return null;
    final part = processTime;
    final yardstick = equivalentProcessTime;
    if (part == null || yardstick == null || yardstick.inSeconds == 0) {
      return null;
    }
    return part.inSeconds / yardstick.inSeconds;
  }

  /// Whether [equivalentProcessTime] came from this step's own override rather
  /// than the line's takt — marked on the box, because a reader comparing two
  /// steps needs to know one of them is not measured in takts.
  final bool usesLocalEquivalent;

  /// What one full changeover costs here — teardown then setup, as a part
  /// change pays it (§7.6).
  final Duration changeover;

  /// How much of that a repeat of the same part still pays, as a fraction.
  ///
  /// On the view rather than left in the database because §8.4's occupation has
  /// to charge repeats the same way the engine does, or the Summary and the run
  /// disagree about the same plant — which is the failure §1.2 and §2.2 both
  /// exist to prevent.
  final double samePartFraction;

  /// What the calendar says the station is open, before any loss.
  final Duration openPerWorkingDay;

  /// `open × availability` — the 16.77 h of a 22:40 station at 74 %.
  ///
  /// The divisor the ladder renders days against, which is what makes one takt
  /// read as exactly the takt: `50.32 h ÷ 16.77 h = 3.0 d`.
  final Duration productivePerWorkingDay;

  /// What the calendar says the station is open across the **whole** viewed
  /// span, weekends and exceptions accounted for — a walk of real dates, not
  /// [openPerWorkingDay] multiplied by a working-day count.
  ///
  /// The denominator of Occupation (§8.1, §8.3), which is why it is here rather
  /// than recomputed: the summary and the process box have to divide by the
  /// same hours, and the calendars are already loaded at this point.
  final Duration openInPeriod;

  /// `openInPeriod × availability` — the hours **one machine** can run in the
  /// period. What a single order's elapsed time is measured against.
  Duration get productiveInPeriod => openInPeriod * (availability ?? 1);

  /// The productive hours this step's target can supply across the period,
  /// **summed over a pool's members**.
  ///
  /// A pool of four lathes is four lathes' worth of hours: an order goes to
  /// whichever frees first (§3.1), so they share the load. Occupation divides
  /// by this (§8.1); dividing by one member's hours read a full pool as four
  /// times as busy as it is — reported from the field.
  ///
  /// The flow equivalent deliberately does **not** use it. `FE_pt` is one takt
  /// of a *machine's* capacity (§6.1), because the dummy part is one piece and
  /// one piece runs on one machine.
  final Duration capacityInPeriod;

  /// Operators across the target, summed over a pool's members for the same
  /// reason (§7.5).
  final int operatorsAllocated;

  final List<int> operatorsPerShift;
  final double? availability;

  /// Fraction of work redone here (§4.4). Not in [equivalentProcessTime] — it
  /// is a loss on the work a *part* requires, so it is applied to that part's
  /// process time and never to the yardstick.
  final double? rework;

  final List<StepProblem> problems;

  /// The schedule period in force was carried forward past its end
  /// (DESIGN.md §11.1) — a warning, not an error.
  final bool scheduleCarriedForward;

  int get staffedShiftCount => operatorsPerShift.where((o) => o > 0).length;

  /// How long an order spends *in this box* — its work **and its changeover**.
  ///
  /// **The changeover is in the rung since the map went per order.** It was on
  /// the box as a figure and in no total, so typing a setup moved one row and
  /// nothing else; the engine has always charged it as part of a station's
  /// occupancy (§7.6), and a ladder that left it out could not be compared with
  /// what a run reports. The queue's wait is its own rung above the link.
  Duration get ladderTime => (processTime ?? Duration.zero) + changeover;

  /// The working day the ladder renders [ladderTime] against, so a rung can
  /// read `3.8 d` the way a value-stream map draws it. Null — and the rung
  /// falls back to hours — when no schedule gives this station a working day.
  Duration? get referenceWorkingDay =>
      productivePerWorkingDay == Duration.zero ? null : productivePerWorkingDay;

  /// [ladderTime] in the days its own rung is drawn in.
  ///
  /// The footer totals are summed from these rather than from the durations,
  /// so `Lead time` is the sum of the rungs above it even when the steps
  /// differ in how long their day is (DESIGN.md §17.4).
  double get ladderDays {
    final day = referenceWorkingDay ?? const Duration(hours: 24);
    return day.inSeconds == 0 ? 0 : ladderTime.inSeconds / day.inSeconds;
  }
}

/// The whole map for one study at one moment.
class FlowView {
  const FlowView({
    required this.study,
    required this.nodes,
    required this.asOf,
    required this.periodEnd,
    required this.granularity,
    required this.dataSource,
    required this.takt,
    required this.taktMissing,
    required this.taktCarriedForward,
    required this.scheduleVariesInPeriod,
    this.selectedPartNumber,
    this.demandBatchSize = 1,
    this.endDate,
    this.runningDays,
    this.workingDays,
  });

  /// When one order that started on [asOf] would finish, walked through the
  /// real calendars rather than converted.
  ///
  /// Null when the walk cannot be made — an unbound step, a workcenter with no
  /// staffed shift. A dash is honest; a converted figure would not be.
  final DateTime? endDate;

  /// Calendar days that walk spans, weekends and shutdowns included.
  final int? runningDays;

  /// The subset of those on which at least one workcenter the flow uses was
  /// open (§17.2).
  ///
  /// **Three figures answer "how long", and they are not interchangeable.**
  /// [leadTime] is working *time*, summed in each station's own productive day,
  /// and is what [processCycleEfficiency] divides. These two are counts of
  /// calendar days. `running ÷ working` lands near 1.4 on a five-day week
  /// because that is 7 ÷ 5, and the ratio is derived rather than imposed
  /// precisely so it reads 1.0 on a seven-day plant and higher across a
  /// shutdown.
  final int? workingDays;

  final Study study;

  /// The process boxes, in flow order. Each carries the queue standing in
  /// front of it (§7.3), which is what the link into it is drawn as.
  final List<FlowStepView> nodes;

  /// The first day of the span the navigator is showing, and the day every
  /// figure on the map is read at.
  final DateTime asOf;

  /// The last day of that span.
  final DateTime periodEnd;

  final PeriodGranularity granularity;

  /// Whether a takt or schedule boundary falls inside the span, so the map is
  /// showing one state of several.
  ///
  /// Reported rather than averaged: the average of a 3-day and a 4-day takt is
  /// a takt the line never runs at.
  final bool scheduleVariesInPeriod;

  final FlowDataSource dataSource;

  /// The part whose numbers the boxes are showing, for the header of a printed
  /// map. Null unless [dataSource] is [FlowDataSource.singlePart].
  final String? selectedPartNumber;

  /// How many pieces the boxes were costed for (§7.6) — one under the flow
  /// equivalent. Carried so the toolbar can show what the map used and the
  /// printed map can say what it was drawn for.
  final int demandBatchSize;

  /// The takt in force, or null if none is defined for [asOf].
  final TaktPeriodSpec? takt;

  final bool taktMissing;
  final bool taktCarriedForward;

  Iterable<FlowStepView> get steps => nodes;

  /// The queues the flow stands in, in flow order.
  ///
  /// **Deduplicated by target**, because two steps of one study may feed the
  /// same station and the plant has one floor space there. Counting it twice is
  /// the doubling §7.3 exists to undo, and it would land in the lead-time
  /// ladder as well as in the picture.
  Iterable<FlowQueueView> get queues {
    final seen = <String>{};
    return [
      for (final step in nodes)
        if (step.queue case final queue?)
          if (seen.add(queue.targetId)) queue,
    ];
  }

  /// Time at the stations — the `Process time` footer figure, and the sum of
  /// the ladder's lower rungs (§17.4).
  ///
  /// **Work plus changeover**, because that is what an order occupies a station
  /// for and what §7.6 charges it. It is therefore the map's statement of the
  /// same quantity §7.9 walks as the theoretical lead time, and the gap between
  /// this and what a run observes is the queueing — which is the one thing a run
  /// exists to measure.
  Duration get processTime => steps.fold(
    Duration.zero,
    (total, step) => total + step.ladderTime,
  );

  /// Process plus what is standing in the queues — the `Lead time` footer
  /// figure.
  Duration get leadTime =>
      processTime +
      queues.fold(Duration.zero, (total, queue) => total + queue.wait);

  /// What the map multiplies working days by to state running days.
  ///
  /// **7 ÷ 5 — a planning convention, not a measurement.** The field asked for
  /// it after seeing the alternative on screen: a calendar walk was built first
  /// and rejected in use. So the running-days figure here is a restatement of
  /// the working-days one and the two cannot disagree, which is the point — it
  /// is the number a planner expects to see beside a working-day lead time.
  ///
  /// **It will not match the simulation**, and that is not a defect in either.
  /// A run walks each station's real calendar (§7.2), so it charges the
  /// weekends and shutdowns this plant actually has; the map states the
  /// convention. When they differ, the run is what happened.
  static const double runningDayFactor = 1.4;

  /// [leadTime] restated in running days (§17.2).
  Duration get leadTimeInRunningDays => leadTime * runningDayFactor;

  /// Process ÷ lead time: the fraction of elapsed time that is value-adding.
  double get processCycleEfficiency {
    final lead = leadTime.inSeconds;
    return lead == 0 ? 0 : processTime.inSeconds / lead;
  }

  /// The footer totals in ladder days — each node measured against its own
  /// rung's working day, then added up (DESIGN.md §17.4).
  double get processTimeInDays =>
      steps.fold(0, (total, step) => total + step.ladderDays);

  double get leadTimeInDays =>
      processTimeInDays +
      queues.fold<double>(0, (total, queue) => total + queue.waitDays);

  /// The working day that makes [processTime] read as [processTimeInDays], for
  /// the one formatter the boxes, rungs and footer all share.
  ///
  /// A derived divisor rather than a chosen one: the steps of a flow do not
  /// have to share a working day — a single-shift station and a three-shift one
  /// legitimately differ — so there is no one day to pick, only the one that
  /// makes the total agree with the rungs it is a total of. Null for an empty
  /// flow, where the formatter's own 24-hour fallback is as good an answer as
  /// any.
  Duration? get processTimeWorkingDay =>
      _workingDayFor(processTime, processTimeInDays);

  Duration? get leadTimeWorkingDay => _workingDayFor(leadTime, leadTimeInDays);

  static Duration? _workingDayFor(Duration total, double days) =>
      days <= 0 ? null : Duration(seconds: (total.inSeconds / days).round());

  /// The yardstick totalled across the flow — Σ FE_pt.
  Duration get equivalentProcessTime => steps.fold(
    Duration.zero,
    (total, step) => total + (step.equivalentProcessTime ?? Duration.zero),
  );

  /// `eq(part, flow) = Σ part_pt ÷ Σ FE_pt` (DESIGN.md §6.2).
  ///
  /// **A ratio of sums, not a mean of the per-step ratios.** The two differ
  /// whenever the steps are unequal, and only this one answers the question the
  /// measure exists for: how many takts of the whole flow's capacity this part
  /// consumes. A step where the part is unusually slow should weigh in
  /// proportion to how long that step is.
  ///
  /// Null under [FlowDataSource.flowEquivalent], where it is 1.0 by
  /// construction.
  double? get flowEquivalence {
    if (!dataSource.isDemandPart) return null;
    final yardstick = equivalentProcessTime.inSeconds;
    return yardstick == 0 ? null : processTime.inSeconds / yardstick;
  }

  bool get hasBlockingProblems =>
      taktMissing || steps.any((s) => s.problems.isNotEmpty);
}

/// Everything the view needs about one workcenter, gathered by the repository.
class WorkcenterContext {
  const WorkcenterContext({
    required this.workcenter,
    required this.calendar,
    required this.schedule,
    this.typeName,
  });

  final Workcenter workcenter;
  final WorkingCalendar calendar;
  final WorkcenterScheduleSpec schedule;

  /// The name of the workcenter's type, resolved by the repository. The
  /// workcenter itself carries only the type's id, and this layer cannot query.
  final String? typeName;
}

/// Builds the map (DESIGN.md §5.4, §6.1, §7.3).
///
/// [contexts] is keyed by workcenter id, [poolMembers] by pool id and [queues]
/// by dispatch target — a workcenter id **or** a pool id, which is the key the
/// queue is stored under. All three are loaded in one pass by the repository so
/// this stays a pure function.
FlowView buildFlowView({
  required Study study,
  required List<FlowNode> nodes,
  required Map<String, WorkcenterContext> contexts,
  required Map<String, WorkcenterPool> pools,
  required Map<String, List<String>> poolMembers,
  required TaktScheduleSpec taktSchedule,
  required DateTime asOf,
  Map<String, ProjectQueue> queues = const {},
  PeriodGranularity granularity = PeriodGranularity.month,
  FlowDataSource dataSource = FlowDataSource.flowEquivalent,
  FlowDemandInput demand = const FlowDemandInput(),
}) {
  final start = granularity.startOf(asOf);
  final end = granularity.endOf(asOf);

  final taktLookup = taktSchedule.lookup(start);
  final takt = taktLookup.period;

  // Uniform if every lookup gives the same period at both ends of the span.
  var varies = taktSchedule.lookup(end).period != takt;
  for (final context in contexts.values) {
    if (context.schedule.lookup(end).period !=
        context.schedule.lookup(start).period) {
      varies = true;
    }
  }

  // **Inventory nodes are skipped, not drawn** (§7.3). The rows stay on a v19
  // database as the recovery path for a name the fold discarded, and nothing
  // constructs one — but a spine that still drew them would show the floor
  // space twice: once as a triangle between two boxes and once as the queue on
  // the connector, which is the doubling this re-model exists to undo.
  final views = [
    for (final node in nodes)
      if (node.kind == FlowNodeKind.step)
        _buildStep(
          node: node,
          contexts: contexts,
          pools: pools,
          poolMembers: poolMembers,
          queues: queues,
          takt: takt,
          asOf: start,
          periodEnd: end,
          dataSource: dataSource,
          demand: demand,
        ),
  ];

  final walk = _walkCalendar(
    views: views,
    contexts: contexts,
    poolMembers: poolMembers,
    from: start,
  );

  return FlowView(
    study: study,
    nodes: views,
    asOf: start,
    periodEnd: end,
    endDate: walk?.end,
    runningDays: walk?.runningDays,
    workingDays: walk?.workingDays,
    granularity: granularity,
    dataSource: dataSource,
    takt: takt,
    taktMissing: taktLookup.isMissing,
    taktCarriedForward: taktLookup.isCarriedForward,
    scheduleVariesInPeriod: varies,
    selectedPartNumber: dataSource == FlowDataSource.singlePart
        ? demand.selectedPartNumber
        : null,
    demandBatchSize: dataSource.isDemandPart ? demand.batchSize : 1,
  );
}

FlowStepView _buildStep({
  required FlowNode node,
  required Map<String, WorkcenterContext> contexts,
  required Map<String, WorkcenterPool> pools,
  required Map<String, List<String>> poolMembers,

  /// Every queue the project has, by dispatch target (§7.3).
  required Map<String, ProjectQueue> queues,
  required TaktPeriodSpec? takt,
  required DateTime asOf,
  required DateTime periodEnd,
  required FlowDataSource dataSource,
  required FlowDemandInput demand,
}) {
  final problems = <StepProblem>[];

  // A pool step reads the capacity of its members. Members are interchangeable
  // by definition (DESIGN.md §3.1), so the first one stands for the pool; a
  // pool whose members differ in staffing is a resource-modelling error, not
  // something to average away here.
  String? targetId = node.workcenterId;
  String? poolName;
  String? typeName;
  int? poolMemberCount;

  if (node.poolId != null) {
    final pool = pools[node.poolId];
    final members = poolMembers[node.poolId] ?? const <String>[];
    poolName = pool?.name;
    poolMemberCount = members.length;
    if (members.isEmpty) {
      problems.add(StepProblem.emptyPool);
    } else {
      targetId = members.first;
    }
  } else if (targetId == null) {
    problems.add(StepProblem.unbound);
  }

  final context = targetId == null ? null : contexts[targetId];
  String? workcenterName;
  if (node.poolId == null) {
    if (context != null) {
      final workcenter = context.workcenter;
      workcenterName = workcenter.name;
      typeName = context.typeName;
      if (workcenter.archivedAt != null) {
        problems.add(StepProblem.archivedTarget);
      }
    } else if (targetId != null) {
      problems.add(StepProblem.archivedTarget);
    }
  }

  final title = flowStepTitle(
    node,
    workcenterName: workcenterName,
    poolName: poolName,
  );

  var openPerDay = Duration.zero;
  var openInPeriod = Duration.zero;
  var capacityInPeriod = Duration.zero;
  var operatorsAllocated = 0;
  List<int> operators = const [];
  // Availability is read here and folded into the productive day below; rework
  // is read here and charged against a *part's* time, never against the
  // yardstick (DESIGN.md §4.4, §6.1).
  double? availability;
  double? rework;
  var carriedForward = false;

  if (context != null) {
    final lookup = context.schedule.lookup(asOf);
    if (lookup.isMissing) {
      problems.add(StepProblem.noSchedule);
    } else {
      carriedForward = lookup.isCarriedForward;
      operators = lookup.period!.operatorsPerShift;
      availability = lookup.period!.availability;
      rework = lookup.period!.rework;
      openPerDay = context.calendar.openTimePerWorkingDay(asOf);
      // Exclusive upper bound: the span's last date runs to the following
      // midnight, so a shift that starts on the 31st is counted whole.
      openInPeriod = context.calendar.openTimeBetween(
        asOf,
        DateTime(periodEnd.year, periodEnd.month, periodEnd.day + 1),
      );
    }
  }

  // Capacity is summed across everything that can run this step. For a single
  // workcenter that is the same figure again; for a pool it is the whole
  // group, which is the point of having one.
  //
  // **A station's parallel units multiply here and nowhere else** (§3.1). A
  // pool of three is the precedent: its members raise this total while
  // `productivePerDay` below stays one machine's clock, so §8.4's occupation
  // halves for two units and §6.1's equivalent still reads per machine. Putting
  // units into the clock instead would also stretch the release cadence, since
  // §7.2 measures a takt in days on the pace setter's productive day — and how
  // many machines a station has is not how long its day is.
  final capacityMembers = node.poolId != null
      ? (poolMembers[node.poolId] ?? const <String>[])
      : [?targetId];
  final until = DateTime(periodEnd.year, periodEnd.month, periodEnd.day + 1);
  for (final memberId in capacityMembers) {
    final member = contexts[memberId];
    if (member == null) continue;
    final lookup = member.schedule.lookup(asOf);
    if (lookup.isMissing) continue;
    capacityInPeriod +=
        member.calendar.openTimeBetween(asOf, until) *
        lookup.period!.availability *
        member.workcenter.parallelCapacity;
    operatorsAllocated += lookup.period!.operatorsPerShift.fold(
      0,
      (sum, count) => sum + count,
    );
  }

  // The flow equivalent's process time at this step (DESIGN.md §6.1):
  //
  //     takt × (open_hours_per_working_day × availability)
  //
  // Availability is part of the station's capacity, so it is in here; rework is
  // a loss on the work a *part* needs, so it is not. A step may state this
  // itself instead of taking one takt — an inspection worth a fraction of a
  // takt, so the equivalent is not skewed at that step.
  //
  // Null rather than zero when anything is missing — a dash is honest, a zero
  // is a number someone will add up.
  final productivePerDay = openPerDay * (availability ?? 1);

  // The full changeover — teardown then setup — as a part change would pay it
  // (§7.6). Resolved here rather than at the top of this function because
  // `days` means this station's productive day, which is not known until the
  // schedule has been read.
  //
  // **The repeat percentage is deliberately not applied.** The box states what
  // a changeover costs, and how often one is paid is a property of the
  // *sequence* rather than of the step — §8.4's occupation is where that is
  // counted, over the orders actually due.
  final changeover =
      taktUnitDuration(
        node.setupValue ?? 0,
        node.setupUnit ?? TaktUnit.seconds,
        productivePerDay,
      ) +
      taktUnitDuration(
        node.teardownValue ?? 0,
        node.teardownUnit ?? TaktUnit.seconds,
        productivePerDay,
      );

  final localEquivalent = node.equivalentValue == null
      ? null
      : TaktPeriodSpec(
          startDate: asOf,
          endDate: asOf,
          value: node.equivalentValue!,
          unit: node.equivalentUnit ?? TaktUnit.hours,
        );

  final Duration? equivalentProcessTime;
  if (problems.isNotEmpty) {
    equivalentProcessTime = null;
  } else if (localEquivalent != null) {
    equivalentProcessTime = localEquivalent.equivalentAt(productivePerDay);
  } else if (takt != null) {
    equivalentProcessTime = takt.equivalentAt(productivePerDay);
  } else {
    equivalentProcessTime = null;
  }

  // What the box shows. The equivalent needs no demand at all; the other two
  // read a real part's stored time and charge this station's rework against it
  // (DESIGN.md §6.2).
  var processTime = equivalentProcessTime;
  if (dataSource.isDemandPart && problems.isEmpty) {
    processTime = _demandProcessTime(
      node: node,
      dataSource: dataSource,
      demand: demand,
      rework: rework ?? 0,
    );
    // A step the part being shown has no time for is a blocking readiness
    // error (§11) — not a zero, and not a quiet fall-back to the takt.
    if (processTime == null) problems.add(StepProblem.noProcessTime);
  }

  return FlowStepView(
    node,
    // **Keyed by what the step targets, not by the node in front of it**
    // (§7.3). A pool is a target in its own right, so `CAL Pool` has one queue
    // its three machines pull from — which is the shape §3.1 dispatches in and
    // what the Gantt heading already drew.
    queue: _buildQueue(
      targetId: node.poolId ?? node.workcenterId,
      targetName: poolName ?? workcenterName ?? title,
      queues: queues,
      takt: takt,
      productivePerWorkingDay: productivePerDay,
    ),
    title: title,
    typeName: typeName,
    poolMemberCount: poolMemberCount,
    dataSource: dataSource,
    processTime: processTime,
    equivalentProcessTime: equivalentProcessTime,
    usesLocalEquivalent: localEquivalent != null,
    changeover: changeover,
    samePartFraction: (node.samePartPercent ?? 0) / 100,
    openPerWorkingDay: openPerDay,
    productivePerWorkingDay: productivePerDay,
    openInPeriod: openInPeriod,
    capacityInPeriod: capacityInPeriod,
    operatorsAllocated: operatorsAllocated,
    operatorsPerShift: operators,
    availability: availability,
    rework: rework,
    problems: problems,
    scheduleCarriedForward: carriedForward,
  );
}

/// The queue in front of one step, resolved for the period being viewed
/// (§7.3, §5.5).
///
/// Null only when the step targets nothing: there is no floor space in front of
/// a step that names no station.
///
/// **A target with no stored row still has a queue**, with everything about it
/// unset. Every step has a queue in front of it (§7.3) — what differs is the
/// rule — so a target nobody has configured is an unlimited pile with nothing
/// standing in it, which is exactly what an absent row means. It is also what
/// gives the connector something to click before the first edit.
///
/// **An unset rule is not FIFO here.** The engine dispatches such a queue in
/// arrival order because a pile has to be taken in some order, but nobody has
/// *decided* that, and §5.2's rule is that the map draws decisions rather than
/// defaults.
FlowQueueView? _buildQueue({
  required String? targetId,
  required String targetName,
  required Map<String, ProjectQueue> queues,
  required TaktPeriodSpec? takt,
  required Duration productivePerWorkingDay,
}) {
  if (targetId == null) return null;
  final row = queues[targetId];

  final productive = productivePerWorkingDay == Duration.zero
      ? null
      : productivePerWorkingDay;
  final mode = row?.stockMode ?? InventoryMode.quantity;

  // A quantity is `pieces × takt` (§5.5) — days of stock at the rate the parts
  // drain. The **line's** takt, deliberately, never the step's own equivalent:
  // stock drains at the rate units leave the line, and a step's equivalent is a
  // yardstick for balancing the equivalent part rather than a local rate.
  final quantity = mode == InventoryMode.quantity
      ? (row?.stockQuantity ?? 0)
      : null;
  final perPiece = takt == null || productive == null
      ? Duration.zero
      : takt.equivalentAt(productive);

  return FlowQueueView(
    targetId: targetId,
    targetName: targetName,
    name: row?.name,
    rule: row?.rule,
    capacity: row?.capacity,
    wait: mode == InventoryMode.quantity
        ? perPiece * (quantity ?? 0)
        : Duration(seconds: row?.stockSeconds ?? 0),
    quantity: quantity,
    unit: row?.stockUnit,
    // A fixed wait is charged on the wall clock unless it is working time. The
    // per-queue flag the inventory node carried has not been re-modelled, so a
    // duration is a calendar wait — which is what cooling, curing and transport
    // are, and §5.5 leaves the other half open.
    isCalendarWait: mode == InventoryMode.duration,
    referenceWorkingDay: productive,
  );
}

/// A real part's process time at one step, with that station's rework charged
/// against it (DESIGN.md §6.2).
///
/// The demand table keys its cells by the **pool** where a step targets one,
/// never by the member standing in for it on the map (§3.1, §9).
Duration? _demandProcessTime({
  required FlowNode node,
  required FlowDataSource dataSource,
  required FlowDemandInput demand,
  required double rework,
}) {
  final key = node.poolId ?? node.workcenterId;
  if (key == null) return null;

  // **A whole order's work, in productive hours** (§7.6). This was one piece,
  // which is why a box read a tenth of what a run charged an order of ten.
  //
  // **Availability is deliberately not divided out here**, and the tests that
  // caught it doing so are §6.2's: the engine works in open-clock hours and
  // divides by availability to get there, while the map works in *productive*
  // hours throughout and divides the rung by a productive day. The two units
  // differ by exactly that factor, so applying it here would count the loss
  // twice — and it is why `pt × batch × (1 + rework)` over a productive day
  // lands on the same number of days §7.9 walks over an open one.
  Duration cost(Duration stored) => Duration(
    seconds:
        (stored.inSeconds *
                (demand.batchSize < 1 ? 1 : demand.batchSize) *
                (1 + rework))
            .round(),
  );

  switch (dataSource) {
    case FlowDataSource.flowEquivalent:
      return null;

    case FlowDataSource.singlePart:
      final partId = demand.selectedPartId;
      if (partId == null) return null;
      final stored = demand.processTimes[partId]?[key];
      return stored == null ? null : cost(stored);

    case FlowDataSource.weightedVariants:
      // Sigma(pt x pieces) / Sigma pieces, over the parts that actually visit
      // this step. A part that skips it is left out of the denominator too:
      // averaging its absence in would claim the station is faster than any
      // piece passing through it ever is (§5.1).
      var work = 0.0;
      var pieces = 0;
      for (final entry in demand.piecesDueInPeriod.entries) {
        if (entry.value <= 0) continue;
        final stored = demand.processTimes[entry.key]?[key];
        if (stored == null) continue;
        work += stored.inSeconds * entry.value;
        pieces += entry.value;
      }
      if (pieces == 0) return null;
      return cost(Duration(seconds: (work / pieces).round()));
  }
}

/// Walks one order through the flow from [from], returning when it finishes.
///
/// A **walk, not a conversion**: process time is spent in its own station's
/// open hours, and the stock standing in the queue in front of a step is spent
/// in that same station's hours — or on the wall clock where it is a fixed
/// wait. That is the whole point — the gap between this and the working-time
/// lead time is the closed time, and no ratio can produce it.
///
/// Returns null rather than throwing if any step cannot be costed or its
/// calendar can never open: the map still draws, and the footer shows a dash.
/// Walks the flow on the calendar, and reports both ways of counting the span.
///
/// **Running days is every day it touches; working days is only the days the
/// plant was open**, and the two come out of the same walk on purpose. The gap
/// between them is the closed time, which is what §17.2 already said no ratio
/// could produce — a five-day week gives about 1.4, a seven-day plant gives 1.0,
/// and a shutdown widens it, all of which a fixed factor gets wrong.
///
/// **A day is a working day when at least one workcenter the flow uses is open
/// on it.** The union rather than a nominated station: it reads as *a day the
/// line could make progress*, it needs no representative to be chosen, and it is
/// stable when a step is re-bound. A Saturday one station works counts; a Sunday
/// nobody works does not.
///
/// A flow containing one round-the-clock station therefore reports running and
/// working as the same number. That is true, and it is the first thing that will
/// look like a defect.
({DateTime end, int runningDays, int workingDays})? _walkCalendar({
  required List<FlowStepView> views,
  required Map<String, WorkcenterContext> contexts,
  required Map<String, List<String>> poolMembers,
  required DateTime from,
}) {
  var cursor = from;
  // A target already walked through, so a station two steps of one flow both
  // visit does not charge its queue twice (§7.3): the plant has one floor space
  // there, and an order passes through it once per visit but the *stock* stands
  // there once.
  final counted = <String>{};
  try {
    for (final view in views) {
      final calendar = contexts[_targetOf(view.node, poolMembers)]?.calendar;

      // The queue comes first: an order joins the line in front of the station
      // before the station touches it.
      if (view.queue case final queue? when counted.add(queue.targetId)) {
        if (queue.isCalendarWait || calendar == null) {
          cursor = cursor.add(queue.wait);
        } else {
          cursor = calendar.advance(cursor, queue.wait);
        }
      }

      if (view.processTime == null) return null;
      if (calendar == null) return null;
      cursor = calendar.advance(cursor, view.processTime!);
    }
  } on StateError {
    // A calendar that can never supply the time — every shift unstaffed.
    return null;
  }

  // The calendars this flow actually uses, deduplicated by target so a station
  // visited twice is asked once.
  final calendars = <String, WorkingCalendar>{};
  for (final view in views) {
    final target = _targetOf(view.node, poolMembers);
    final calendar = contexts[target]?.calendar;
    if (target != null && calendar != null) calendars[target] = calendar;
  }

  // Both counts are inclusive of both ends: a flow that starts and finishes on
  // one day spans one running day, not zero. The start day may itself be closed,
  // in which case it is a running day and not a working one.
  final last = dateOnly(cursor);
  var running = 0;
  var working = 0;
  for (
    var day = dateOnly(from);
    !day.isAfter(last);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    running++;
    // Short-circuits on the first open station, which on an ordinary weekday is
    // the first one asked. Built by day rather than by asking each calendar for
    // its whole span, because §16.9 makes local `DateTime` arithmetic the
    // expensive thing here and this way each day costs one construction.
    if (calendars.values.any((c) => c.openTimeOnDate(day) > Duration.zero)) {
      working++;
    }
  }

  return (end: cursor, runningDays: running, workingDays: working);
}

String? _targetOf(FlowNode step, Map<String, List<String>> poolMembers) {
  if (step.workcenterId != null) return step.workcenterId;
  final members = poolMembers[step.poolId] ?? const <String>[];
  return members.isEmpty ? null : members.first;
}
