import '../../../data/database/enums.dart';
import 'schedule_periods.dart';

/// What a [TaktUnit] value is worth at a station whose ordinary working day is
/// [workingDay] (DESIGN.md §6.1).
///
/// **`days` is the only unit that has to ask.** A 3-day takt at a station open
/// 22:40 a day is 68 hours and at a single-shift station 26:24, and both are
/// "three days of that station's own capacity". Hours, minutes and seconds are
/// literal and resolve identically everywhere.
///
/// One definition, because three separate things are now expressed this way and
/// they sit in the same dialog: the line's takt, a step's Process Specific Takt
/// (§6.1.1), and a step's setup and teardown (§7.6). Two of them meaning
/// slightly different days is §17.4's scar, and the surest way to prevent it is
/// for there to be nowhere else to write the arithmetic.
///
/// Callers pass the **productive** day — open hours already derated by
/// availability — because §6.1 applies that loss exactly once and this is where
/// it has already been applied.
Duration taktUnitDuration(double value, TaktUnit unit, Duration workingDay) =>
    switch (unit) {
      TaktUnit.days => Duration(
        seconds: (value * workingDay.inSeconds).round(),
      ),
      TaktUnit.hours => Duration(seconds: (value * 3600).round()),
      TaktUnit.minutes => Duration(seconds: (value * 60).round()),
      TaktUnit.seconds => Duration(seconds: value.round()),
    };

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
  Duration equivalentAt(Duration openPerWorkingDay) =>
      taktUnitDuration(value, unit, openPerWorkingDay);

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

  /// When the takt next becomes a **different figure** after [from], and what it
  /// becomes (DESIGN.md §7.7.3).
  ///
  /// Null where it never does — one period, or several that all state the same
  /// takt. A schedule that reads 4 d, 4 d, 5 d changes once, at the third
  /// period's start, because a period boundary is not a change if the number
  /// either side of it is the same.
  ///
  /// **What both of §7.7.3's captions are built from.** The map says which takt
  /// it is showing when the viewed span crosses one of these, and a run says the
  /// same about its own span — §18.3 keeps a run at a single cadence, so the
  /// change is a caveat on the figures rather than something the engine acts on.
  TaktChange? changeAfter(DateTime from) {
    final current = taktOn(from);
    if (current == null) return null;
    for (final period in periods) {
      if (!period.startDate.isAfter(from)) continue;
      if (period.value == current.value && period.unit == current.unit) {
        continue;
      }
      return (at: period.startDate, from: current, to: period);
    }
    return null;
  }
}

/// The moment a line's takt stops being one figure and starts being another.
typedef TaktChange = ({
  DateTime at,
  TaktPeriodSpec from,
  TaktPeriodSpec to,
});
