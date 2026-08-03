/// Looking a date up in a list of dated periods, and saying honestly what it
/// found (DESIGN.md §11.1).
///
/// Takt and workcenter schedules are both lists of `[start, end]` periods, and
/// both face the same three awkward cases: a date before the first period, a
/// date in a gap between two, and a date past the last one. They are not the
/// same kind of problem, so they do not get the same answer.
library;

import '../../calendar/application/shift_pattern_spec.dart' show dateOnly;

/// Anything with an inclusive local date range.
abstract class DatedPeriod {
  DateTime get startDate;
  DateTime get endDate;
}

/// Why a lookup returned what it did.
enum PeriodMatch {
  /// The date falls inside a defined period.
  exact,

  /// The date is past the last period, which was carried forward.
  ///
  /// Not an error: schedule periods are finite while a simulation runs until
  /// the last order completes, and refusing here would make an overloaded
  /// plant unsimulatable exactly when the simulation is most informative. The
  /// run reports it as a warning.
  carriedForward,

  /// No period covers the date and none can be carried forward — before the
  /// first period, or inside a gap between two. A real data hole; the
  /// readiness panel blocks on it rather than inventing capacity.
  missing,
}

/// The outcome of a period lookup.
class PeriodLookup<T extends DatedPeriod> {
  const PeriodLookup(this.match, this.period);

  final PeriodMatch match;

  /// Null only when [match] is [PeriodMatch.missing].
  final T? period;

  bool get isMissing => match == PeriodMatch.missing;
  bool get isCarriedForward => match == PeriodMatch.carriedForward;
}

/// Periods sorted by start date, with the lookup rules above.
///
/// Overlaps are a data error the readiness panel reports; this class stays
/// total by letting the earliest matching period win, so no caller has to
/// handle an exception mid-simulation.
class PeriodSchedule<T extends DatedPeriod> {
  PeriodSchedule(Iterable<T> periods)
    : periods = List.unmodifiable(
        [...periods]..sort((a, b) => a.startDate.compareTo(b.startDate)),
      );

  final List<T> periods;

  bool get isEmpty => periods.isEmpty;

  PeriodLookup<T> lookup(DateTime date) {
    if (periods.isEmpty) return const PeriodLookup(PeriodMatch.missing, null);

    final day = dateOnly(date);
    for (final period in periods) {
      final start = dateOnly(period.startDate);
      final end = dateOnly(period.endDate);
      if (!day.isBefore(start) && !day.isAfter(end)) {
        return PeriodLookup(PeriodMatch.exact, period);
      }
    }

    final last = periods.last;
    if (day.isAfter(dateOnly(last.endDate))) {
      return PeriodLookup(PeriodMatch.carriedForward, last);
    }
    // Before the first period, or in a gap between two.
    return const PeriodLookup(PeriodMatch.missing, null);
  }

  /// The period covering [date], carrying the last one forward past the end.
  /// Null where [lookup] reports [PeriodMatch.missing].
  T? at(DateTime date) => lookup(date).period;

  /// Pairs of periods whose date ranges overlap, for the readiness panel.
  List<(T, T)> overlaps() {
    final found = <(T, T)>[];
    for (var i = 0; i < periods.length - 1; i++) {
      final current = periods[i];
      final next = periods[i + 1];
      if (!dateOnly(next.startDate).isAfter(dateOnly(current.endDate))) {
        found.add((current, next));
      }
    }
    return found;
  }

  /// Gaps strictly inside the covered span — days no period covers, between two
  /// that do. The tail past the last period is not a gap (it is carried
  /// forward), and neither is the time before the first.
  List<(DateTime, DateTime)> internalGaps() {
    final found = <(DateTime, DateTime)>[];
    for (var i = 0; i < periods.length - 1; i++) {
      final endOfCurrent = dateOnly(periods[i].endDate);
      final startOfNext = dateOnly(periods[i + 1].startDate);
      final dayAfter = DateTime(
        endOfCurrent.year,
        endOfCurrent.month,
        endOfCurrent.day + 1,
      );
      if (startOfNext.isAfter(dayAfter)) {
        final dayBefore = DateTime(
          startOfNext.year,
          startOfNext.month,
          startOfNext.day - 1,
        );
        found.add((dayAfter, dayBefore));
      }
    }
    return found;
  }

  /// A period that ends before it starts — the other way a hand-typed range
  /// goes wrong.
  List<T> inverted() => [
    for (final period in periods)
      if (dateOnly(period.endDate).isBefore(dateOnly(period.startDate))) period,
  ];
}
