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
  /// own capacity. Available as soon as takt and schedules exist.
  flowEquivalent,

  /// One demand part's own process times. Needs the demand table (M3).
  singlePart,

  /// Every part weighted by the demand mix. Needs the demand table (M3).
  weightedVariants,
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
}

sealed class FlowNodeView {
  const FlowNodeView(this.node);

  final FlowNode node;

  String get id => node.id;
  int get position => node.position;

  /// How long an order spends here, for the lead-time ladder.
  Duration get ladderTime;

  /// The working day the ladder renders [ladderTime] against, so a rung can
  /// read `3.8 d` the way a value-stream map draws it. Null — and the rung
  /// falls back to hours — when no schedule gives this node a working day.
  Duration? get referenceWorkingDay;

  /// [ladderTime] in the days its own rung is drawn in: this station's
  /// productive day, or a plain 24 hours where none applies (a calendar wait,
  /// or a step with no schedule).
  ///
  /// The footer totals are summed from these rather than from the durations,
  /// so `Lead time` is the sum of the rungs above it even when the steps
  /// differ in how long their day is (DESIGN.md §17.4).
  double get ladderDays {
    final day = referenceWorkingDay ?? const Duration(hours: 24);
    return day.inSeconds == 0 ? 0 : ladderTime.inSeconds / day.inSeconds;
  }
}

/// A process box.
class FlowStepView extends FlowNodeView {
  const FlowStepView(
    super.node, {
    required this.title,
    required this.subtitle,
    required this.processTime,
    required this.changeover,
    required this.openPerWorkingDay,
    required this.productivePerWorkingDay,
    required this.operatorsPerShift,
    required this.availability,
    required this.problems,
    this.usesLocalEquivalent = false,
    this.scheduleCarriedForward = false,
  });

  /// `CLAD04` or the pool's name — what the box is labelled.
  final String title;

  /// The workcenter type, or the pool's member count.
  final String subtitle;

  /// The flow equivalent's process time here — one takt of this station's
  /// productive capacity, or the step's own override (DESIGN.md §6.1).
  ///
  /// ```
  /// takt × (open_hours_per_working_day × availability)
  /// ```
  ///
  /// **Availability is in it; rework is not.** Availability is a property of
  /// the station's capacity, so it belongs here; rework is a loss on the work a
  /// *part* requires, so it attaches to demand process times instead.
  ///
  /// The box, the lead-time ladder and the footer totals all read this one
  /// figure, so a step never reports two different times and PCE stays a ratio
  /// of like with like.
  ///
  /// Null when [problems] is non-empty: a step that cannot be costed shows a
  /// dash rather than a plausible zero.
  final Duration? processTime;

  /// Whether [processTime] came from this step's own override rather than the
  /// line's takt — marked on the box, because a reader comparing two steps
  /// needs to know one of them is not measured in takts.
  final bool usesLocalEquivalent;

  final Duration changeover;

  /// What the calendar says the station is open, before any loss.
  final Duration openPerWorkingDay;

  /// `open × availability` — the 16.77 h of a 22:40 station at 74 %.
  ///
  /// The divisor the ladder renders days against, which is what makes one takt
  /// read as exactly the takt: `50.32 h ÷ 16.77 h = 3.0 d`.
  final Duration productivePerWorkingDay;

  final List<int> operatorsPerShift;
  final double? availability;
  final List<StepProblem> problems;

  /// The schedule period in force was carried forward past its end
  /// (DESIGN.md §11.1) — a warning, not an error.
  final bool scheduleCarriedForward;

  int get staffedShiftCount => operatorsPerShift.where((o) => o > 0).length;

  bool get isCostable => processTime != null;

  @override
  Duration get ladderTime => processTime ?? Duration.zero;

  @override
  Duration? get referenceWorkingDay =>
      productivePerWorkingDay == Duration.zero ? null : productivePerWorkingDay;
}

/// An inventory triangle.
class FlowInventoryView extends FlowNodeView {
  const FlowInventoryView(
    super.node, {
    required this.wait,
    required this.label,
    this.quantity,
    this.downstreamWorkingDay,
    this.waitUnit,
  });

  /// The working day of the step this buffer drains into — the rate that sets
  /// how long its pieces sit there.
  final Duration? downstreamWorkingDay;

  /// The unit a fixed wait was typed in, so the triangle reads `2 days` rather
  /// than converting it to something the user did not write.
  final DurationUnit? waitUnit;

  /// How long an order waits here. For a quantity buffer this is
  /// `pieces × takt`, resolved through the following step's capacity.
  final Duration wait;

  /// Pieces, for a [InventoryMode.quantity] buffer.
  final int? quantity;

  final String label;

  @override
  Duration get ladderTime => wait;

  /// A fixed wait measured on the wall clock — cooling, transport — that does
  /// not stop for the weekend.
  bool get isCalendarWait =>
      node.inventoryMode == InventoryMode.duration &&
      !node.inventoryUsesWorkingTime;

  @override
  Duration? get referenceWorkingDay {
    // A calendar wait is measured in calendar days: 48 h of cooling is two
    // days, not the 2.9 productive days it would be if divided by a 16.77-hour
    // working day. Only a working-time wait, and a quantity buffer — whose
    // wait is takt-derived — use the station's productive day.
    if (isCalendarWait) return null;
    return downstreamWorkingDay == Duration.zero ? null : downstreamWorkingDay;
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
    this.endDate,
    this.runningDays,
  });

  /// When one order that started on [asOf] would finish, walked through the
  /// real calendars rather than converted.
  ///
  /// Null when the walk cannot be made — an unbound step, a workcenter with no
  /// staffed shift. A dash is honest; a converted figure would not be.
  final DateTime? endDate;

  /// Calendar days that walk spans, weekends and shutdowns included.
  ///
  /// The companion to [leadTime], which counts working time only. The two
  /// answer different questions and the gap between them **is** the closed
  /// time — which is the thing worth seeing.
  final int? runningDays;

  final Study study;
  final List<FlowNodeView> nodes;

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

  /// The takt in force, or null if none is defined for [asOf].
  final TaktPeriodSpec? takt;

  final bool taktMissing;
  final bool taktCarriedForward;

  Iterable<FlowStepView> get steps => nodes.whereType<FlowStepView>();

  Iterable<FlowInventoryView> get buffers =>
      nodes.whereType<FlowInventoryView>();

  /// Total process time across the steps — the `Process time` footer figure.
  Duration get processTime => steps.fold(
    Duration.zero,
    (total, step) => total + (step.processTime ?? Duration.zero),
  );

  /// Process plus waiting — the `Lead time` footer figure.
  Duration get leadTime =>
      nodes.fold(Duration.zero, (total, node) => total + node.ladderTime);

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
      nodes.fold(0, (total, node) => total + node.ladderDays);

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

  bool get hasBlockingProblems =>
      taktMissing || steps.any((s) => s.problems.isNotEmpty);
}

/// Everything the view needs about one workcenter, gathered by the repository.
class WorkcenterContext {
  const WorkcenterContext({
    required this.workcenter,
    required this.calendar,
    required this.schedule,
  });

  final Workcenter workcenter;
  final WorkingCalendar calendar;
  final WorkcenterScheduleSpec schedule;
}

/// Builds the map (DESIGN.md §5.4, §6.1).
///
/// [contexts] is keyed by workcenter id, [poolMembers] by pool id. Both are
/// loaded in one pass by the repository so this stays a pure function.
FlowView buildFlowView({
  required Study study,
  required List<FlowNode> nodes,
  required Map<String, WorkcenterContext> contexts,
  required Map<String, WorkcenterPool> pools,
  required Map<String, List<String>> poolMembers,
  required TaktScheduleSpec taktSchedule,
  required DateTime asOf,
  PeriodGranularity granularity = PeriodGranularity.month,
  FlowDataSource dataSource = FlowDataSource.flowEquivalent,
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

  final views = <FlowNodeView>[];
  for (final node in nodes) {
    views.add(switch (node.kind) {
      FlowNodeKind.step => _buildStep(
        node: node,
        contexts: contexts,
        pools: pools,
        poolMembers: poolMembers,
        takt: takt,
        asOf: start,
      ),
      FlowNodeKind.inventory => _buildInventory(
        node: node,
        nodes: nodes,
        contexts: contexts,
        pools: pools,
        poolMembers: poolMembers,
        takt: takt,
        asOf: start,
      ),
    });
  }

  final walk = _walkCalendar(
    views: views,
    nodes: nodes,
    contexts: contexts,
    poolMembers: poolMembers,
    from: start,
  );

  return FlowView(
    study: study,
    nodes: views,
    asOf: start,
    periodEnd: end,
    endDate: walk,
    runningDays: walk == null
        ? null
        // Inclusive of both ends: a flow that starts and finishes on the same
        // day spans one running day, not zero.
        : dateOnly(walk).difference(dateOnly(start)).inDays + 1,
    granularity: granularity,
    dataSource: dataSource,
    takt: takt,
    taktMissing: taktLookup.isMissing,
    taktCarriedForward: taktLookup.isCarriedForward,
    scheduleVariesInPeriod: varies,
  );
}

FlowStepView _buildStep({
  required FlowNode node,
  required Map<String, WorkcenterContext> contexts,
  required Map<String, WorkcenterPool> pools,
  required Map<String, List<String>> poolMembers,
  required TaktPeriodSpec? takt,
  required DateTime asOf,
}) {
  final problems = <StepProblem>[];
  final changeover = Duration(seconds: node.changeoverSeconds);

  // A pool step reads the capacity of its members. Members are interchangeable
  // by definition (DESIGN.md §3.1), so the first one stands for the pool; a
  // pool whose members differ in staffing is a resource-modelling error, not
  // something to average away here.
  String? targetId = node.workcenterId;
  var title = '';
  var subtitle = '';

  if (node.poolId != null) {
    final pool = pools[node.poolId];
    final members = poolMembers[node.poolId] ?? const <String>[];
    title = pool?.name ?? '';
    subtitle = '${members.length}';
    if (members.isEmpty) {
      problems.add(StepProblem.emptyPool);
    } else {
      targetId = members.first;
    }
  } else if (targetId == null) {
    problems.add(StepProblem.unbound);
  }

  final context = targetId == null ? null : contexts[targetId];
  if (node.poolId == null) {
    if (context != null) {
      final workcenter = context.workcenter;
      title = workcenter.name;
      subtitle = workcenter.name;
      if (workcenter.archivedAt != null) {
        problems.add(StepProblem.archivedTarget);
      }
    } else if (targetId != null) {
      problems.add(StepProblem.archivedTarget);
    }
  }

  if (node.label != null && node.label!.isNotEmpty) title = node.label!;

  var openPerDay = Duration.zero;
  List<int> operators = const [];
  // Read and shown on the box, but deliberately not folded into any duration —
  // losses belong to a demand part's process time (M3), not to the flow
  // equivalent's capacity.
  double? availability;
  var carriedForward = false;

  if (context != null) {
    final lookup = context.schedule.lookup(asOf);
    if (lookup.isMissing) {
      problems.add(StepProblem.noSchedule);
    } else {
      carriedForward = lookup.isCarriedForward;
      operators = lookup.period!.operatorsPerShift;
      availability = lookup.period!.availability;
      openPerDay = context.calendar.openTimePerWorkingDay(asOf);
    }
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
  final localEquivalent = node.equivalentValue == null
      ? null
      : TaktPeriodSpec(
          startDate: asOf,
          endDate: asOf,
          value: node.equivalentValue!,
          unit: node.equivalentUnit ?? TaktUnit.hours,
        );

  final Duration? processTime;
  if (problems.isNotEmpty) {
    processTime = null;
  } else if (localEquivalent != null) {
    processTime = localEquivalent.equivalentAt(productivePerDay);
  } else if (takt != null) {
    processTime = takt.equivalentAt(productivePerDay);
  } else {
    processTime = null;
  }

  return FlowStepView(
    node,
    title: title.isEmpty ? '—' : title,
    subtitle: subtitle,
    processTime: processTime,
    usesLocalEquivalent: localEquivalent != null,
    changeover: changeover,
    openPerWorkingDay: openPerDay,
    productivePerWorkingDay: productivePerDay,
    operatorsPerShift: operators,
    availability: availability,
    problems: problems,
    scheduleCarriedForward: carriedForward,
  );
}

FlowInventoryView _buildInventory({
  required FlowNode node,
  required List<FlowNode> nodes,
  required Map<String, WorkcenterContext> contexts,
  required Map<String, WorkcenterPool> pools,
  required Map<String, List<String>> poolMembers,
  required TaktPeriodSpec? takt,
  required DateTime asOf,
}) {
  final mode = node.inventoryMode ?? InventoryMode.quantity;
  final label = node.label ?? '';

  final downstream = _nextStep(nodes, node.position);
  final context = downstream == null
      ? null
      : contexts[_targetOf(downstream, poolMembers)];

  // Productive hours, not raw open hours: the same divisor the steps use, so a
  // buffer and the step beside it measure a day the same way.
  final lookup = context?.schedule.lookup(asOf);
  final productivePerDay = (lookup == null || lookup.isMissing)
      ? null
      : context!.calendar.openTimePerWorkingDay(asOf) *
            lookup.period!.availability;

  if (mode == InventoryMode.duration) {
    return FlowInventoryView(
      node,
      wait: Duration(seconds: node.inventorySeconds ?? 0),
      label: label,
      downstreamWorkingDay: productivePerDay,
      waitUnit: node.inventoryUnit,
    );
  }

  // A quantity buffer is `pieces × takt` (DESIGN.md §5.5) — days of stock at
  // the rate the parts drain.
  //
  // The **line's** takt, deliberately, never a downstream step's own equivalent:
  // stock drains at the rate units leave the line, and a step's equivalent is a
  // yardstick for balancing the equivalent part, not a local production rate.
  final quantity = node.inventoryQuantity ?? 0;
  final perPiece = takt == null || productivePerDay == null
      ? Duration.zero
      : takt.equivalentAt(productivePerDay);

  return FlowInventoryView(
    node,
    wait: perPiece * quantity,
    quantity: quantity,
    label: label,
    downstreamWorkingDay: productivePerDay,
  );
}

/// Walks one order through the flow from [from], returning when it finishes.
///
/// A **walk, not a conversion**: process time is spent in its own station's
/// open hours, a working-time buffer in the hours of the station it feeds, and
/// a calendar buffer on the wall clock, weekends included. That is the whole
/// point — the gap between this and the working-time lead time is the closed
/// time, and no ratio can produce it.
///
/// Returns null rather than throwing if any step cannot be costed or its
/// calendar can never open: the map still draws, and the footer shows a dash.
DateTime? _walkCalendar({
  required List<FlowNodeView> views,
  required List<FlowNode> nodes,
  required Map<String, WorkcenterContext> contexts,
  required Map<String, List<String>> poolMembers,
  required DateTime from,
}) {
  var cursor = from;
  try {
    for (final view in views) {
      switch (view) {
        case FlowStepView(:final processTime):
          if (processTime == null) return null;
          final calendar = contexts[_targetOf(view.node, poolMembers)]?.calendar;
          if (calendar == null) return null;
          cursor = calendar.advance(cursor, processTime);

        case FlowInventoryView(:final wait):
          if (view.isCalendarWait) {
            cursor = cursor.add(wait);
          } else {
            // Working-time waits run on the calendar of the step they feed —
            // the same station whose day their `d` is measured in. A buffer at
            // the end of the flow feeds nothing, so it falls back to the
            // station it just left; only a flow of buffers alone has no
            // calendar at all, and then the wall clock is all that is left.
            final neighbour =
                _nextStep(nodes, view.position) ??
                _previousStep(nodes, view.position);
            final calendar = neighbour == null
                ? null
                : contexts[_targetOf(neighbour, poolMembers)]?.calendar;
            cursor = calendar == null
                ? cursor.add(wait)
                : calendar.advance(cursor, wait);
          }
      }
    }
  } on StateError {
    // A calendar that can never supply the time — every shift unstaffed.
    return null;
  }
  return cursor;
}

FlowNode? _previousStep(List<FlowNode> nodes, int beforePosition) {
  FlowNode? found;
  for (final node in nodes) {
    if (node.position < beforePosition && node.kind == FlowNodeKind.step) {
      found = node;
    }
  }
  return found;
}

FlowNode? _nextStep(List<FlowNode> nodes, int afterPosition) {
  for (final node in nodes) {
    if (node.position > afterPosition && node.kind == FlowNodeKind.step) {
      return node;
    }
  }
  return null;
}

String? _targetOf(FlowNode step, Map<String, List<String>> poolMembers) {
  if (step.workcenterId != null) return step.workcenterId;
  final members = poolMembers[step.poolId] ?? const <String>[];
  return members.isEmpty ? null : members.first;
}
