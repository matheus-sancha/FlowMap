import '../../../data/database/enums.dart';
import 'schedule_periods.dart';

/// A production line's takt over one date range (DESIGN.md §6.1).
///
/// The takt is a **value plus a unit**, not a duration. "3 days" only becomes a
/// duration once you say whose working day is meant, and the answer differs per
/// workcenter — a station on one shift and a station on three do not have the
/// same day. So the resolution happens at the workcenter, in [equivalentAt].
class TaktPeriodSpec implements DatedPeriod {
  const TaktPeriodSpec({
    required this.startDate,
    required this.endDate,
    required this.value,
    required this.unit,
  });

  @override
  final DateTime startDate;
  @override
  final DateTime endDate;

  /// `3` for a 3-day takt.
  final double value;
  final TaktUnit unit;

  /// One takt of a workcenter whose ordinary working day is [openPerWorkingDay]
  /// — the flow equivalent's process time at that step (DESIGN.md §6.1).
  ///
  /// A 3-day takt at a workcenter open 22:40 a day is 68 hours; the same takt
  /// at a single-shift workcenter open 8:48 a day is 26:24. Both are "one takt
  /// of that station's own capacity", which is the comparison the equivalency
  /// method exists to make.
  Duration equivalentAt(Duration openPerWorkingDay) => switch (unit) {
    TaktUnit.days => Duration(
      seconds: (value * openPerWorkingDay.inSeconds).round(),
    ),
    TaktUnit.hours => Duration(seconds: (value * 3600).round()),
    TaktUnit.minutes => Duration(seconds: (value * 60).round()),
    TaktUnit.seconds => Duration(seconds: value.round()),
  };

  /// Whether this takt resolves to the same duration everywhere. Days do not;
  /// the rest do.
  bool get isWorkcenterRelative => unit == TaktUnit.days;
}

/// One production line's takt across a project.
class TaktScheduleSpec {
  TaktScheduleSpec(Iterable<TaktPeriodSpec> periods)
    : schedule = PeriodSchedule(periods);

  final PeriodSchedule<TaktPeriodSpec> schedule;

  List<TaktPeriodSpec> get periods => schedule.periods;

  bool get isEmpty => schedule.isEmpty;

  TaktPeriodSpec? taktOn(DateTime date) => schedule.at(date);

  PeriodLookup<TaktPeriodSpec> lookup(DateTime date) => schedule.lookup(date);
}
