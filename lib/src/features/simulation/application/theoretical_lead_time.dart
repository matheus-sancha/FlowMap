/// What an order would take with the plant to itself (DESIGN.md §7.9).
///
/// ```
/// theoretical_LT = Σ_steps (part_pt × batch ÷ availability × (1 + rework))
/// ```
///
/// **Excludes queueing**, which is the point of the measure: it is the
/// denominator of Lead Time Efficiency, and the gap between it and what a run
/// actually observes *is* the queueing. **Excludes changeover** too, because
/// changeover depends on what ran before and is therefore not a property of the
/// part.
///
/// **Excludes inventory**, which it did not until the model was driven against
/// a real plant. This figure has to stay a floor under what a run observes, or
/// the efficiency it feeds inverts its meaning — so it can only count what the
/// engine can also charge, and §5.5's buffers no longer delay a run at all. On
/// célula 11B they were 14 of both figures' days; counted here and not there,
/// theoretical would have come out at 35.1 d against an actual of 25.8 d.
///
/// Walked through the working calendar rather than summed, so it lands on real
/// dates: forty open hours off a Monday morning is the previous Tuesday, not
/// the previous Saturday.
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
  required List<SimNode> nodes,
  required Map<String, SimWorkcenter> workcenters,
  required SimPart part,
  required int batchSize,
  required DateTime from,
  List<TheoreticalLeadTimeProblem>? problems,
}) {
  void report(TheoreticalLeadTimeProblem problem) => problems?.add(problem);

  var cursor = from;
  var working = Duration.zero;

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

          // Read on the day the step starts, not once for the whole run: a
          // walk may cross a schedule boundary where availability changes.
          final occupancy = effectiveProcessTime(
            processTimePerPiece: perPiece,
            batchSize: batchSize,
            availability: workcenter.schedule.availabilityOn(cursor),
            rework: workcenter.schedule.reworkOn(cursor),
          );

          cursor = workcenter.calendar.advance(cursor, occupancy);
          working += occupancy;

        // Costs nothing: the engine no longer charges for one either, and this
        // figure is only meaningful as a floor under what the engine observes.
        case SimBuffer():
          continue;
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
  required List<SimNode> nodes,
  required Map<String, SimWorkcenter> workcenters,
  required SimPart part,
  required int batchSize,
  required DateTime needDate,
  List<TheoreticalLeadTimeProblem>? problems,
}) {
  var cursor = needDate;

  try {
    for (final node in nodes.reversed) {
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
            ),
          );

        // As above: the run will not spend it, so the cold start must not
        // reserve it (§7.8).
        case SimBuffer():
          continue;
      }
    }
  } on StateError {
    problems?.add(TheoreticalLeadTimeProblem.neverOpen);
    return null;
  }

  return cursor;
}
