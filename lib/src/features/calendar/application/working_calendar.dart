import 'shift_pattern_spec.dart';
import 'staffing_schedule.dart';

/// A span during which a workcenter is available.
class OpenInterval {
  const OpenInterval(this.start, this.end);

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  @override
  String toString() => 'OpenInterval($start -> $end)';
}

/// When one workcenter is open, and how to do arithmetic in its time.
///
/// **This is the foundation the rest of FlowMap stands on** (DESIGN.md §4).
/// Occupation, theoretical lead time and every duration in the simulation are
/// computed by walking a calendar, so an error here is an error in every number
/// the app displays. It is pure — pattern, staffing and already-resolved
/// exceptions in, instants out — which is what makes it exhaustively testable.
///
/// Three rules shape the model:
///
/// * **A workcenter is a single server** (DESIGN.md §7.5), so overlapping
///   shifts count once. Two crews overlapping for a 47-minute handover do not
///   make the machine available twice over, so intervals are merged into a
///   union rather than summed.
/// * **A break shortens the end of its shift.** Nothing in this app records
///   *when* a break is taken, and inventing a placement would put a fictional
///   gap in the middle of every shift. Taking it off the end keeps wall-clock
///   time and capacity identical without pretending to know more than we do.
/// * **Days are stepped by component, never by adding 24 hours.** Shift times
///   are clock readings; a daylight-saving change must move the instant, not
///   the reading.
class WorkingCalendar {
  /// One staffing for all time — the common case in tests and in the shift
  /// pattern preview.
  WorkingCalendar({
    required ShiftPatternSpec pattern,
    required List<int> operatorsPerShift,
    Map<DateTime, ResolvedCalendarException> exceptions = const {},
  }) : this.scheduled(
         pattern: pattern,
         staffing: ConstantStaffing(operatorsPerShift),
         exceptions: exceptions,
       );

  /// Staffing that changes between schedule periods — what a project actually
  /// has (DESIGN.md §4.2).
  WorkingCalendar.scheduled({
    required this.pattern,
    required this.staffing,
    Map<DateTime, ResolvedCalendarException> exceptions = const {},
  }) : exceptions = Map.unmodifiable(exceptions);

  final ShiftPatternSpec pattern;

  /// Operators on each shift for a given day, indexed by [ShiftWindow.position].
  /// Zero means the workcenter is closed for that shift (DESIGN.md §4.2); a
  /// list shorter than the pattern's shifts reads as zero for the rest.
  final StaffingSchedule staffing;

  /// Holidays, shutdowns and extra hours, already narrowed to this workcenter
  /// by [resolveExceptions] and keyed by [dateOnly].
  final Map<DateTime, ResolvedCalendarException> exceptions;

  /// How far [advance] and [nextOpen] will search before giving up.
  ///
  /// A calendar with no staffed shift at all — every operator count zero, or
  /// every day excepted — would otherwise spin forever. The simulation's own
  /// abort guard (DESIGN.md §7.8) depends on this failing loudly instead.
  static const _searchLimitDays = 3660;

  /// Whether the workcenter has any open time at all.
  bool get isEverOpen =>
      staffing.isEverStaffed ||
      exceptions.values.any(
        (e) =>
            e.kind == CalendarExceptionKind.extraWorking &&
            (e.operatorsPerShift ?? const <int>[]).any((o) => o > 0),
      );

  /// Nominal open time on an ordinary working day under the staffing in force
  /// on [onDate] — break removed, overlapping shifts counted once.
  ///
  /// Takes a date because staffing changes between schedule periods, but
  /// computed in pure minute arithmetic rather than against that date's real
  /// intervals: this is the *nominal* capacity used by the flow equivalent
  /// (DESIGN.md §6.1) and by occupation, and it should not wobble by an hour
  /// twice a year because a daylight-saving change fell inside the window.
  /// It is also independent of whether [onDate] is itself a working day.
  ///
  /// Note it does **not** apply availability. Availability is applied exactly
  /// once in the app, when deriving effective process time (DESIGN.md §4.4);
  /// derating capacity here as well would count it twice.
  Duration openTimePerWorkingDay(DateTime onDate) {
    final spans = <_SecondSpan>[];
    for (final shift in _staffedShifts(staffing.operatorsOn(onDate))) {
      final start = shift.startMinute * 60;
      final end = start + shift.netDuration.inSeconds;
      if (end > start) spans.add(_SecondSpan(start, end));
    }
    return Duration(seconds: _mergedSeconds(spans));
  }

  /// The open intervals of the shifts that *start* on [date].
  ///
  /// A night shift belongs to the day it starts on, which is how a plant counts
  /// its own shifts — so a Friday night shift running to Saturday morning is
  /// Friday's capacity, and a Saturday shutdown does not cut it short.
  List<OpenInterval> intervalsStartingOn(DateTime date) {
    final day = dateOnly(date);
    final exception = exceptions[day];

    if (exception?.kind == CalendarExceptionKind.nonWorking) {
      return const [];
    }

    final List<int> operators;
    if (exception?.kind == CalendarExceptionKind.extraWorking) {
      // Extra hours may bring their own staffing; null means "as an ordinary
      // working day", which is the common case of simply opening a Saturday.
      exception!;
      operators = exception.operatorsPerShift ?? staffing.operatorsOn(day);
    } else if (pattern.worksOnWeekday(day.weekday)) {
      operators = staffing.operatorsOn(day);
    } else {
      return const [];
    }

    final intervals = <OpenInterval>[];
    for (final shift in _staffedShifts(operators)) {
      final start = _at(day, shift.startMinute);
      // Built from components so the end lands on the clock reading the user
      // typed, whatever the offset does in between.
      final grossEnd = shift.crossesMidnight
          ? _at(_nextDay(day), shift.endMinute)
          : _at(day, shift.endMinute);
      final end = grossEnd.subtract(Duration(seconds: shift.breakSeconds));
      if (end.isAfter(start)) intervals.add(OpenInterval(start, end));
    }

    return _merge(intervals);
  }

  /// Open time attributed to [date] — the capacity of that day's shifts.
  Duration openTimeOnDate(DateTime date) => intervalsStartingOn(
    date,
  ).fold(Duration.zero, (total, interval) => total + interval.duration);

  bool isOpenAt(DateTime t) {
    // The previous day too: a shift that started at 23:40 yesterday is what
    // makes 02:00 today open.
    for (final interval in _intervalsAround(t)) {
      if (interval.contains(t)) return true;
    }
    return false;
  }

  /// The first instant at or after [from] when the workcenter is open.
  ///
  /// Throws [StateError] if there is none within [_searchLimitDays].
  DateTime nextOpen(DateTime from) {
    var day = _previousDay(dateOnly(from));
    for (var i = 0; i <= _searchLimitDays; i++) {
      for (final interval in intervalsStartingOn(day)) {
        if (interval.end.isAfter(from)) {
          return interval.start.isAfter(from) ? interval.start : from;
        }
      }
      day = _nextDay(day);
    }
    throw StateError(
      'No open time found for ${pattern.name} within $_searchLimitDays days '
      'of $from. Check that at least one shift has operators assigned.',
    );
  }

  /// Open time between [from] and [to]. Zero if [to] is not after [from].
  Duration openTimeBetween(DateTime from, DateTime to) {
    if (!to.isAfter(from)) return Duration.zero;
    var total = Duration.zero;
    var day = _previousDay(dateOnly(from));
    final last = dateOnly(to);
    // `to` may fall inside a shift that started on its own day, so the loop
    // runs through `to`'s date inclusive.
    while (!day.isAfter(last)) {
      for (final interval in intervalsStartingOn(day)) {
        final start = interval.start.isBefore(from) ? from : interval.start;
        final end = interval.end.isAfter(to) ? to : interval.end;
        if (end.isAfter(start)) total += end.difference(start);
      }
      day = _nextDay(day);
    }
    return total;
  }

  /// The instant at which [work] of open time has elapsed, starting no earlier
  /// than [from].
  ///
  /// `advance(t, Duration.zero)` is [nextOpen] — the moment work would begin.
  /// Throws [StateError] if the calendar cannot supply that much open time
  /// within [_searchLimitDays].
  DateTime advance(DateTime from, Duration work) {
    if (work.isNegative) {
      throw ArgumentError.value(work, 'work', 'must not be negative');
    }
    var remaining = work;
    var cursor = from;
    var day = _previousDay(dateOnly(from));

    for (var i = 0; i <= _searchLimitDays; i++) {
      for (final interval in intervalsStartingOn(day)) {
        if (!interval.end.isAfter(cursor)) continue;
        final start = interval.start.isAfter(cursor) ? interval.start : cursor;
        final available = interval.end.difference(start);
        if (remaining <= available) return start.add(remaining);
        remaining -= available;
        cursor = interval.end;
      }
      day = _nextDay(day);
    }
    throw StateError(
      'Could not advance ${work.inMinutes} min of open time from $from on '
      '${pattern.name} within $_searchLimitDays days. Check that at least one '
      'shift has operators assigned.',
    );
  }

  /// Shifts with at least one operator, in position order.
  Iterable<ShiftWindow> _staffedShifts(List<int> operators) =>
      pattern.shifts.where((shift) {
        final count = shift.position < operators.length
            ? operators[shift.position]
            : 0;
        return count > 0;
      });

  List<OpenInterval> _intervalsAround(DateTime t) {
    final day = dateOnly(t);
    return [
      ...intervalsStartingOn(_previousDay(day)),
      ...intervalsStartingOn(day),
    ];
  }

  static DateTime _at(DateTime day, int minuteOfDay) => DateTime(
    day.year,
    day.month,
    day.day,
    minuteOfDay ~/ 60,
    minuteOfDay % 60,
  );

  static DateTime _nextDay(DateTime day) =>
      DateTime(day.year, day.month, day.day + 1);

  static DateTime _previousDay(DateTime day) =>
      DateTime(day.year, day.month, day.day - 1);

  /// Merges overlapping or touching intervals — the single-server rule.
  static List<OpenInterval> _merge(List<OpenInterval> intervals) {
    if (intervals.length < 2) return intervals;
    final sorted = [...intervals]..sort((a, b) => a.start.compareTo(b.start));
    final merged = <OpenInterval>[sorted.first];
    for (final interval in sorted.skip(1)) {
      final last = merged.last;
      if (!interval.start.isAfter(last.end)) {
        if (interval.end.isAfter(last.end)) {
          merged[merged.length - 1] = OpenInterval(last.start, interval.end);
        }
      } else {
        merged.add(interval);
      }
    }
    return merged;
  }

  static int _mergedSeconds(List<_SecondSpan> spans) {
    if (spans.isEmpty) return 0;
    final sorted = [...spans]..sort((a, b) => a.start.compareTo(b.start));
    var total = 0;
    var start = sorted.first.start;
    var end = sorted.first.end;
    for (final span in sorted.skip(1)) {
      if (span.start <= end) {
        if (span.end > end) end = span.end;
      } else {
        total += end - start;
        start = span.start;
        end = span.end;
      }
    }
    return total + (end - start);
  }
}

/// Seconds from midnight, for the nominal per-day computation.
class _SecondSpan {
  const _SecondSpan(this.start, this.end);

  final int start;
  final int end;
}
