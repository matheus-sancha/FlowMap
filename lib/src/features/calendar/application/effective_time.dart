/// How long work actually holds a workcenter (DESIGN.md §4.4, §7.6).
///
/// The other half of the calendar: the calendar says *when* a workcenter is
/// open, this says *how much* of that open time a piece of work consumes.
library;

/// Occupancy of one order at one step, before any queueing.
///
/// ```
/// effective = process_time_per_piece × batch × (1 + rework) ÷ availability
/// ```
///
/// A 10 h piece, batch 1, on a 74 % available workcenter with 3.7 % rework
/// holds it for 14.0 h of open working time.
///
/// **Availability appears exactly once in the whole app, and this is it.** The
/// calendar deliberately does not derate its open time (see
/// [WorkingCalendar.openTimePerWorkingDay]); doing both would count the loss
/// twice.
///
/// _Rejected: sampling breakdowns against availability._ Realistic queue
/// behaviour, but it needs replication counts, seeds and confidence intervals
/// on every metric, and makes two runs of the same study disagree — which is
/// unacceptable when the output is a headcount decision.
Duration effectiveProcessTime({
  required Duration processTimePerPiece,
  required int batchSize,
  required double availability,
  double rework = 0,
}) {
  if (batchSize < 1) {
    throw ArgumentError.value(batchSize, 'batchSize', 'must be at least 1');
  }
  if (availability <= 0 || availability > 1) {
    throw ArgumentError.value(
      availability,
      'availability',
      'must be greater than 0 and at most 1',
    );
  }
  if (rework < 0) {
    throw ArgumentError.value(rework, 'rework', 'must not be negative');
  }
  return processTimePerPiece * (batchSize * (1 + rework) / availability);
}
