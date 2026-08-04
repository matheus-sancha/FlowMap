import '../../../data/database/enums.dart';

// The exception enums are part of this library's public surface — callers build
// [ScopedCalendarException]s with them — so they are re-exported rather than
// leaving every call site to import the schema's enum file as well.
export '../../../data/database/enums.dart'
    show CalendarExceptionKind, CalendarExceptionScope;

/// Pure value objects describing when a workcenter is open.
///
/// Deliberately free of Drift: the calendar is the most-tested code in the app
/// (DESIGN.md §15) and every one of its cases must be expressible in a test
/// without a database. Repositories build these from rows.

/// One shift window in a pattern, as clock readings rather than instants.
class ShiftWindow {
  const ShiftWindow({
    required this.label,
    required this.position,
    required this.startMinute,
    required this.endMinute,
    this.breakSeconds = 0,
  });

  final String label;

  /// Order within the day. Also the index into a workcenter's
  /// operators-per-shift list (DESIGN.md §4.2).
  final int position;

  /// Minutes from midnight, 0–1439.
  final int startMinute;
  final int endMinute;

  /// Unpaid break inside the window.
  final int breakSeconds;

  /// A shift whose end reading is not after its start runs into the next day.
  ///
  /// Derived rather than stored: a flag beside the times can disagree with
  /// them, and the times are the thing the user edits.
  bool get crossesMidnight => endMinute <= startMinute;

  /// Wall-clock span before the break is taken out.
  Duration get grossDuration => Duration(
    minutes: crossesMidnight
        ? (24 * 60 - startMinute) + endMinute
        : endMinute - startMinute,
  );

  /// Span the workcenter is actually available, break removed.
  Duration get netDuration => grossDuration - Duration(seconds: breakSeconds);
}

/// How a plant divides its day, with the shifts in order.
class ShiftPatternSpec {
  ShiftPatternSpec({
    required this.name,
    required this.cycleType,
    required this.workingWeekdays,
    required List<ShiftWindow> shifts,
  }) : shifts = List.unmodifiable(
         [...shifts]..sort((a, b) => a.position.compareTo(b.position)),
       );

  final String name;
  final ShiftCycleType cycleType;

  /// Bitmask, Monday = bit 0 … Sunday = bit 6.
  final int workingWeekdays;

  final List<ShiftWindow> shifts;

  /// Whether [weekday] (a `DateTime.weekday` value, Monday = 1) is a base
  /// working day. A rotating pattern runs every day by definition.
  bool worksOnWeekday(int weekday) =>
      cycleType == ShiftCycleType.rotating ||
      workingWeekdays & (1 << (weekday - 1)) != 0;

  static int weekdayMask(Iterable<int> weekdays) =>
      weekdays.fold(0, (mask, day) => mask | (1 << (day - 1)));
}

/// An exception as the user entered it, before it is resolved against a
/// particular workcenter.
class ScopedCalendarException {
  const ScopedCalendarException({
    required this.date,
    required this.kind,
    required this.scope,
    this.scopeId,
    this.operatorsPerShift,
  });

  /// Local date; the time component is ignored.
  final DateTime date;
  final CalendarExceptionKind kind;
  final CalendarExceptionScope scope;

  /// The line or workcenter this applies to. Null for [
  /// CalendarExceptionScope.plant].
  final String? scopeId;

  /// Staffing for an [CalendarExceptionKind.extraWorking] day, indexed by shift
  /// position. Null means "the same staffing as an ordinary working day".
  final List<int>? operatorsPerShift;
}

/// An exception already narrowed to one workcenter.
class ResolvedCalendarException {
  const ResolvedCalendarException({required this.kind, this.operatorsPerShift});

  final CalendarExceptionKind kind;
  final List<int>? operatorsPerShift;
}

/// Narrows [exceptions] to the ones that reach a workcenter, keeping the most
/// specific entry per day.
///
/// Precedence is workcenter > production line > plant, so "the plant is closed
/// on Saturday, except CLAD04 runs extra hours" resolves the way it reads. Two
/// exceptions at the same scope on the same day is a data error the readiness
/// panel reports (DESIGN.md §11); here the later one in the list wins, so the
/// function stays total.
Map<DateTime, ResolvedCalendarException> resolveExceptions(
  Iterable<ScopedCalendarException> exceptions, {
  required String workcenterId,
  Set<String> productionLineIds = const {},
}) {
  const rank = {
    CalendarExceptionScope.plant: 0,
    CalendarExceptionScope.productionLine: 1,
    CalendarExceptionScope.workcenter: 2,
  };

  final winners = <DateTime, ScopedCalendarException>{};
  for (final exception in exceptions) {
    final applies = switch (exception.scope) {
      CalendarExceptionScope.plant => true,
      // A workcenter is drawn under a *set* of lines, so a line-scoped
      // exception reaches it if any of them match. `CLAD04` shared by two
      // lines is closed when either line shuts.
      CalendarExceptionScope.productionLine =>
        productionLineIds.contains(exception.scopeId),
      CalendarExceptionScope.workcenter => exception.scopeId == workcenterId,
    };
    if (!applies) continue;

    final day = dateOnly(exception.date);
    final current = winners[day];
    if (current == null || rank[exception.scope]! >= rank[current.scope]!) {
      winners[day] = exception;
    }
  }

  return {
    for (final entry in winners.entries)
      entry.key: ResolvedCalendarException(
        kind: entry.value.kind,
        operatorsPerShift: entry.value.operatorsPerShift,
      ),
  };
}

/// Strips the time of day, keeping the local calendar date.
///
/// Built from components rather than by subtracting a Duration: shift times are
/// wall-clock readings, and component construction is what keeps a day boundary
/// at midnight through a daylight-saving change.
DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
