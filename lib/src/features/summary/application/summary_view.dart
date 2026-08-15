/// Occupation, operators and demand takt — what the plant is being asked to do
/// in a period against what it can (DESIGN.md §8).
///
/// Static: every figure here is available before any simulation is run, which
/// is the point. A constraint the Summary can already see is one the user can
/// fix before spending a run on it (§8.1).
///
/// Pure, like the rest of `application/`: it takes the assembled map, the
/// demand table and the sequence, and returns numbers.
library;

import '../../../data/database/database.dart';
import '../../calendar/application/shift_pattern_spec.dart' show dateOnly;
import '../../demand/application/demand_table.dart';
import '../../flow/application/flow_view.dart';
import '../../schedules/application/takt_schedule.dart';

/// One workcenter or pool's load in the viewed period (DESIGN.md §8.1, §8.3).
///
/// Keyed by **target, not by step.** Two steps of a flow may visit the same
/// station, and the station has one calendar and one set of hours: its load is
/// the sum of both visits, and both process boxes report that same figure.
class TargetOccupation {
  const TargetOccupation({
    required this.targetId,
    required this.title,
    required this.visits,
    required this.work,
    required this.changeovers,
    required this.changeoverTime,
    required this.availableProductive,
    required this.operatorsAllocated,
    required this.partsWithoutTimes,
  });

  final String targetId;
  final String title;

  /// How many steps of the flow route through this station.
  final int visits;

  /// `Σ part_pt × batch × (1 + rework)` over the orders due in the period, once
  /// per visit. Availability is **not** applied here — it is in
  /// [availableProductive], and applying it twice is §4.4's oldest trap.
  final Duration work;

  /// Orders whose part differed from the one before them at this station
  /// (§7.6). Sequence-dependent, and the sequence is known, so it is charged
  /// rather than ignored.
  final int changeovers;

  final Duration changeoverTime;

  /// `open time across the span × availability` — the hours the station can
  /// actually run. A walk of real dates, so a shutdown in the period reduces it.
  final Duration availableProductive;

  /// The crew the schedule buys per day: `1/1/1` is three.
  final int operatorsAllocated;

  /// Parts due in the period with no process time at this station. Reported
  /// rather than treated as zero: a part with no time at a step it must visit
  /// is a blocking readiness error (§11), and until it is fixed the required
  /// hours below are an understatement.
  final int partsWithoutTimes;

  Duration get required => work + changeoverTime;

  /// `required ÷ available productive` — the headline of §8.1. Above 1.0 is a
  /// hard constraint: the station cannot do it however the sequence is
  /// arranged.
  ///
  /// Null when the station is closed for the whole period; a division by zero
  /// dressed up as "infinitely busy" would rank a shut station as the
  /// bottleneck.
  double? get occupation => availableProductive.inSeconds == 0
      ? null
      : required.inSeconds / availableProductive.inSeconds;

  /// The headcount this load implies, against [operatorsAllocated] (§7.5).
  ///
  /// **This is occupation restated in people**, and deliberately so. A
  /// workcenter is a single server (§7.5) — a second operator on one CNC does
  /// not double its output — so the only honest thing "operators needed" can
  /// mean is the crew the current staffing pattern would have to become to
  /// carry this load. Putting it in headcount is what makes it actionable.
  double? get operatorsNeeded {
    final ratio = occupation;
    return ratio == null ? null : operatorsAllocated * ratio;
  }

  bool get isOverloaded => (occupation ?? 0) > 1;
}

/// The takt demand implies, against the one the line is configured for
/// (DESIGN.md §8.2).
class DemandTaktView {
  const DemandTaktView({
    required this.paceSetterTitle,
    required this.paceSetterWorkingDay,
    required this.available,
    required this.orders,
    required this.equivalents,
    required this.configured,
  });

  /// The station the figures are measured at, and the working day they are
  /// rendered in.
  final String paceSetterTitle;
  final Duration paceSetterWorkingDay;

  /// Available productive time at the pace-setter across the period.
  final Duration available;

  /// Orders with a need date in the period.
  final int orders;

  /// `Σ eq(part, flow) × batch` over those orders — the demand measured in
  /// takts rather than in units.
  final double equivalents;

  /// The line's configured takt, resolved at the pace-setter so all three
  /// figures are in the same hours.
  final Duration? configured;

  /// What a visitor expects: time available divided by units wanted.
  Duration? get raw => orders == 0
      ? null
      : Duration(seconds: available.inSeconds ~/ orders);

  /// What actually matters under a mixed part mix: an order worth two takts of
  /// work counts twice.
  Duration? get adjusted => equivalents <= 0
      ? null
      : Duration(seconds: (available.inSeconds / equivalents).round());
}

/// The Summary for one study at one period.
class SummaryView {
  const SummaryView({
    required this.start,
    required this.end,
    required this.targets,
    required this.ordersInPeriod,
    required this.demandTakt,
  });

  final DateTime start;
  final DateTime end;

  /// Ranked by occupation, busiest first — the §8.1 bottleneck ranking.
  final List<TargetOccupation> targets;

  final int ordersInPeriod;
  final DemandTaktView? demandTakt;

  /// The station the headline names. Null when nothing can be ranked.
  TargetOccupation? get bottleneck =>
      targets.where((t) => t.occupation != null).firstOrNull;

  /// Occupation by target, for the process boxes on the map.
  Map<String, double?> get occupationByTarget => {
    for (final target in targets) target.targetId: target.occupation,
  };
}

/// Builds the Summary (DESIGN.md §8).
///
/// [orders] is the **whole** sequence in order, not just the period's: a
/// changeover is charged against the order that ran before it at that station,
/// and that order may be in the month before (§7.6).
SummaryView buildSummary({
  required FlowView flow,
  required DemandTable demand,
  required List<DemandOrder> orders,
}) {
  final start = flow.asOf;
  final end = flow.periodEnd;

  bool dueInPeriod(DemandOrder order) {
    final due = dateOnly(order.needDate);
    return !due.isBefore(start) && !due.isAfter(end);
  }

  final inPeriod = orders.where(dueInPeriod).toList();

  // Steps grouped by the station they route through: a station visited twice
  // carries both visits' work against one set of hours.
  final byTarget = <String, List<FlowStepView>>{};
  for (final step in flow.steps) {
    final targetId = demandTargetOf(step.node);
    if (targetId == null) continue;
    (byTarget[targetId] ??= []).add(step);
  }

  final targets = <TargetOccupation>[];
  for (final entry in byTarget.entries) {
    final targetId = entry.key;
    final steps = entry.value;
    final first = steps.first;
    final rework = first.rework ?? 0;

    var work = Duration.zero;
    var missing = 0;
    final seenWithoutTime = <String>{};
    for (final order in inPeriod) {
      final stored = demand.times[order.partId]?[targetId];
      if (stored == null) {
        if (seenWithoutTime.add(order.partId)) missing++;
        continue;
      }
      work +=
          Duration(
            seconds: (stored.inSeconds * (1 + rework)).round(),
          ) *
          (order.batchSize * steps.length);
    }

    // A changeover per visit, charged in full when the part differs from the
    // order before it at this station and at the step's own percentage when it
    // does not (§7.6). Walked over the whole sequence so the first order of the
    // period is compared with the one that really preceded it.
    //
    // **No previous order counts as a change**, which is the engine's rule since
    // v17: an empty station is set up for nothing. Only the very first order of
    // a sequence takes that branch.
    var changeovers = 0;
    var repeats = 0;
    String? previousPart;
    for (final order in orders) {
      if (demand.times[order.partId]?[targetId] == null) continue;
      if (dueInPeriod(order)) {
        if (previousPart == order.partId) {
          repeats++;
        } else {
          changeovers++;
        }
      }
      previousPart = order.partId;
    }

    // Repeats are charged separately rather than folded into one count, because
    // each step carries its own percentage and they need not agree.
    var changeoverTime = Duration.zero;
    for (final step in steps) {
      changeoverTime +=
          step.changeover * changeovers +
          step.changeover * (repeats * step.samePartFraction);
    }

    targets.add(
      TargetOccupation(
        targetId: targetId,
        title: first.title,
        visits: steps.length,
        work: work,
        changeovers: changeovers * steps.length,
        changeoverTime: changeoverTime,
        // The whole target's hours, so a pool of four lathes is measured
        // against four lathes rather than against one of them.
        availableProductive: first.capacityInPeriod,
        operatorsAllocated: first.operatorsAllocated,
        partsWithoutTimes: missing,
      ),
    );
  }

  targets.sort((a, b) => (b.occupation ?? -1).compareTo(a.occupation ?? -1));

  return SummaryView(
    start: start,
    end: end,
    targets: targets,
    ordersInPeriod: inPeriod.length,
    demandTakt: _demandTakt(
      flow: flow,
      demand: demand,
      orders: inPeriod,
      paceSetter: targets.where((t) => t.occupation != null).firstOrNull,
    ),
  );
}

/// The demand takt, measured at the busiest station (DESIGN.md §8.2).
///
/// **The bottleneck sets the pace**, so its hours are the ones demand has to
/// fit into. "Available working time" cannot mean the line's, because a line is
/// a set of stations with different calendars and no single figure of its own;
/// picking the constraint is the reading that makes the comparison with the
/// configured takt mean something. Recorded as an open assumption (§18.8).
DemandTaktView? _demandTakt({
  required FlowView flow,
  required DemandTable demand,
  required List<DemandOrder> orders,
  required TargetOccupation? paceSetter,
}) {
  if (paceSetter == null) return null;

  final step = flow.steps.firstWhere(
    (s) => demandTargetOf(s.node) == paceSetter.targetId,
  );

  final yardstick = flow.equivalentProcessTime.inSeconds;
  var equivalents = 0.0;
  for (final order in orders) {
    if (yardstick == 0) break;
    var work = 0.0;
    for (final column in demand.columns) {
      final stored = demand.timeFor(order.partId, column.targetId);
      if (stored != null) work += stored.inSeconds;
    }
    equivalents += work / yardstick * order.batchSize;
  }

  return DemandTaktView(
    paceSetterTitle: paceSetter.title,
    paceSetterWorkingDay: step.productivePerWorkingDay,
    available: paceSetter.availableProductive,
    orders: orders.length,
    equivalents: equivalents,
    configured: _configuredTakt(flow.takt, step.productivePerWorkingDay),
  );
}

Duration? _configuredTakt(TaktPeriodSpec? takt, Duration productivePerDay) =>
    takt?.equivalentAt(productivePerDay);
