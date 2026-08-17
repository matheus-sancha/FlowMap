/// What an order would take with the plant to itself (DESIGN.md §7.9).
///
/// ```
/// theoretical_LT = Σ_steps (part_pt × batch ÷ availability × (1 + rework))
/// ```
///
/// **One walk, two answers**, because two questions are asked of it and they
/// want different contents:
///
/// * [TheoreticalLeadTime.elapsed] is **when an order has to start** — so it
///   counts the changeover each step charges and the stock already standing in
///   each queue, because both are real time an order spends between release and
///   delivery. This is what the map's headline lead time and the production
///   plan both report, and it is what the cold start is walked backwards from.
/// * [TheoreticalLeadTime.workingTime] is **the floor** — step work only. It is
///   the denominator of Lead Time Efficiency, and the gap between it and what a
///   run observes *is* the queueing.
///
/// **The two must not be confused, and the reason is on the record.** A run
/// charges nothing for stock (§5.5), so a span that counts it is not a floor
/// under that run: counting it in the floor once gave célula 11B 35.1
/// theoretical days against 25.8 actual — an efficiency above 1.0 that §8 says
/// cannot happen. Keeping both out of one traversal is what stops them drifting
/// while keeping each honest about its own question.
///
/// **Stock is counted once per target.** Two steps of one flow on one station
/// share a floor space, and the map dedupes it the same way — charging it twice
/// is the doubling §7.3 exists to undo.
///
/// Walked through the working calendar rather than summed, so it lands on real
/// dates: forty open hours off a Monday morning is the previous Tuesday, not
/// the previous Saturday. Stock is spent on the **wall clock**: it is standing
/// there over the weekend too.
library;

import '../../calendar/application/effective_time.dart';
import 'sim_model.dart';

/// Why an order cannot be costed without queueing.
enum TheoreticalLeadTimeProblem {
  /// A step whose target is not in the run's resource model.
  unknownWorkcenter,

  /// The part has no process time at a step it must visit — a blocking
  /// readiness error (§11), reported rather than treated as free.
  noProcessTime,

  /// A calendar that can never open: every shift unstaffed.
  neverOpen,
}

/// The walk's answer.
class TheoreticalLeadTime {
  const TheoreticalLeadTime({
    required this.start,
    required this.end,
    required this.workingTime,
  });

  final DateTime start;
  final DateTime end;

  /// Open time actually spent at the stations, buffers excluded — the
  /// value-adding part, for PCE.
  final Duration workingTime;

  /// Wall-clock span, weekends and shutdowns included.
  Duration get elapsed => end.difference(start);
}

/// Walks one order forward from [from] with no queueing.
///
/// Returns null when it cannot be walked; [problems] then says why. A null is
/// honest where a plausible number would be quietly wrong.
TheoreticalLeadTime? theoreticalLeadTime({
  required List<SimStep> nodes,
  required Map<String, SimWorkcenter> workcenters,
  required SimPart part,
  required int batchSize,
  required DateTime from,
  List<TheoreticalLeadTimeProblem>? problems,
}) {
  void report(TheoreticalLeadTimeProblem problem) => problems?.add(problem);

  var cursor = from;
  var working = Duration.zero;
  // One floor space per target, however many steps of this flow feed it.
  final counted = <String>{};

  try {
    for (final node in nodes) {
      switch (node) {
        case SimStep():
          // A pool step is costed on the member that would run it if the pool
          // were empty — its first, which is the same station the map draws
          // its capacity from. Members are interchangeable (§3.1), so which
          // one is not a question this measure has to answer.
          final workcenter = workcenters[node.candidates.firstOrNull];
          if (workcenter == null) {
            report(TheoreticalLeadTimeProblem.unknownWorkcenter);
            return null;
          }

          final perPiece = part.timeAt(node.demandKey);
          if (perPiece == null) {
            report(TheoreticalLeadTimeProblem.noProcessTime);
            return null;
          }

          // A changeover typed in `days` means this station's productive day
          // (§7.6), so it has to be resolved before either half is charged.
          // **Charged in full**: an order walking a plant it has to itself
          // starts cold, so nothing repeats.
          final productiveDay =
              workcenter.calendar.openTimePerWorkingDay(cursor) *
              workcenter.schedule.availabilityOn(cursor);

          // Read on the day the step starts, not once for the whole run: a
          // walk may cross a schedule boundary where availability changes.
          final occupancy = effectiveProcessTime(
            processTimePerPiece: perPiece,
            batchSize: batchSize,
            availability: workcenter.schedule.availabilityOn(cursor),
            rework: workcenter.schedule.reworkOn(cursor),
          );

          // The queue first: an order joins the line in front of the station
          // before the station touches it. On the wall clock, because stock
          // stands there whether or not the plant is open.
          if (counted.add(node.queue.targetId)) {
            cursor = cursor.add(node.queueStock);
          }

          cursor = workcenter.calendar.advance(
            cursor,
            occupancy +
                node.setupAt(productiveDay, repeated: false) +
                node.teardownAt(productiveDay, repeated: false),
          );
          // **The floor counts the work and nothing else.** Not the changeover,
          // which depends on what ran before and is not a property of the part;
          // not the stock, which a run never charges.
          working += occupancy;
      }
    }
  } on StateError {
    report(TheoreticalLeadTimeProblem.neverOpen);
    return null;
  }

  return TheoreticalLeadTime(start: from, end: cursor, workingTime: working);
}

/// When a run has to begin for its first order to be delivered on time
/// (DESIGN.md §7.8).
///
/// The plant is empty at the start, so the first order is limited only by its
/// own theoretical lead time. Walked **backwards** through the calendars rather
/// than subtracted, because a working day is not a fixed fraction of a calendar
/// one.
///
/// Returns null on the same grounds [theoreticalLeadTime] does.
DateTime? coldStartDate({
  required List<SimStep> nodes,
  required Map<String, SimWorkcenter> workcenters,
  required SimPart part,
  required int batchSize,
  required DateTime needDate,
  List<TheoreticalLeadTimeProblem>? problems,
}) {
  var cursor = needDate;

  // **The steps the forward walk charges stock at**, worked out from the
  // un-reversed list: the first step in flow order to reach each target.
  //
  // Going backwards, the first step to *meet* a target is the last one in flow
  // order, so charging it where it is met puts the stock at the wrong end of
  // the flow. That is not a rounding difference. Stock is spent on the wall
  // clock and work on the calendar (§7.9), so moving a two-day jump from the
  // front of a flow to the back changes which weekends the work after it
  // crosses: for `A → B → A` with two days at A, the walks landed 5 Jun → 10
  // Jun forwards and 10 Jun → 4 Jun backwards. The first order's start date and
  // its stated lead time then do not add up to its need date.
  final chargesStock = <int>{};
  final seen = <String>{};
  for (var i = 0; i < nodes.length; i++) {
    if (seen.add(nodes[i].queue.targetId)) chargesStock.add(i);
  }

  try {
    for (var i = nodes.length - 1; i >= 0; i--) {
      final node = nodes[i];
      switch (node) {
        case SimStep():
          final workcenter = workcenters[node.candidates.firstOrNull];
          if (workcenter == null) {
            problems?.add(TheoreticalLeadTimeProblem.unknownWorkcenter);
            return null;
          }

          final perPiece = part.timeAt(node.demandKey);
          if (perPiece == null) {
            problems?.add(TheoreticalLeadTimeProblem.noProcessTime);
            return null;
          }

          final productiveDay =
              workcenter.calendar.openTimePerWorkingDay(cursor) *
              workcenter.schedule.availabilityOn(cursor);

          cursor = workcenter.calendar.retreat(
            cursor,
            effectiveProcessTime(
              processTimePerPiece: perPiece,
              batchSize: batchSize,
              // Read at the far end of the step, which is where the cursor is
              // on the way back. A schedule boundary inside one order's time
              // at one station is not a case worth splitting a step over.
              availability: workcenter.schedule.availabilityOn(cursor),
              rework: workcenter.schedule.reworkOn(cursor),
            ) +
                node.setupAt(productiveDay, repeated: false) +
                node.teardownAt(productiveDay, repeated: false),
          );

          // And back through the queue it came out of, on the wall clock — at
          // the step the forward walk charges it at, so the two walks invert
          // each other exactly.
          if (chargesStock.contains(i)) {
            cursor = cursor.subtract(node.queueStock);
          }
      }
    }
  } on StateError {
    problems?.add(TheoreticalLeadTimeProblem.neverOpen);
    return null;
  }

  return cursor;
}
