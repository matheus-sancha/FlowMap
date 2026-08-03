import 'schedule_periods.dart';

/// What is wrong with a set of schedule periods (DESIGN.md §11).
///
/// Computed as data rather than as sentences, so the readiness panel, the two
/// schedule tabs and — later — the simulation's pre-flight check all agree
/// about what counts as a problem, and each renders it in the user's language.
enum SchedulePeriodProblem {
  /// No period at all. Blocking: nothing downstream can be costed.
  empty,

  /// Two periods claim the same day. Blocking: which one applies is arbitrary.
  overlap,

  /// Days between two periods that neither covers. Blocking — a real data hole,
  /// unlike the open-ended tail past the last period, which is carried forward.
  gap,

  /// A period that ends before it starts.
  inverted,
}

/// One problem, with the dates that make it concrete.
class SchedulePeriodIssue {
  const SchedulePeriodIssue(this.problem, {this.from, this.to});

  final SchedulePeriodProblem problem;
  final DateTime? from;
  final DateTime? to;

  /// Every problem here is blocking. Warnings — occupation over 100%, a
  /// carried-forward tail — are reported elsewhere, because they do not stop a
  /// study being costed.
  bool get isBlocking => true;
}

/// Finds everything wrong with [schedule], in the order a user would fix it.
List<SchedulePeriodIssue> findSchedulePeriodIssues(
  PeriodSchedule<DatedPeriod> schedule,
) {
  if (schedule.isEmpty) {
    return const [SchedulePeriodIssue(SchedulePeriodProblem.empty)];
  }

  return [
    for (final period in schedule.inverted())
      SchedulePeriodIssue(
        SchedulePeriodProblem.inverted,
        from: period.startDate,
        to: period.endDate,
      ),
    for (final (first, second) in schedule.overlaps())
      SchedulePeriodIssue(
        SchedulePeriodProblem.overlap,
        from: second.startDate,
        to: first.endDate,
      ),
    for (final (from, to) in schedule.internalGaps())
      SchedulePeriodIssue(SchedulePeriodProblem.gap, from: from, to: to),
  ];
}
