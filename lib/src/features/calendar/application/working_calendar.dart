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
///   union rather than summed — including across midnight, where a night shift
///   overruns the next morning's start.
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

  static const _secondsPerDay = 24 * 60 * 60;

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
  /// **The union is taken on the 24-hour circle, not on a line.** The pattern
  /// repeats daily, so a night shift running to 07:00 competes with the next
  /// morning's 06:00 start for the same single server; laid end to end those
  /// two windows would claim 25 hours out of a 24-hour day. Wrapping the
  /// overrun back to the start of the cycle is what keeps a day's capacity a
  /// day (DESIGN.md §6.1.1).
  ///
  /// Note it does **not** apply availability. Availability is applied exactly
  /// once in the app, when deriving effective process time (DESIGN.md §4.4);
  /// derating capacity here as well would count it twice.
  Duration openTimePerWorkingDay(DateTime onDate) {
    final spans = <_SecondSpan>[];
    for (final shift in _staffedShifts(staffing.operatorsOn(onDate))) {
      final length = shift.netDuration.inSeconds;
      if (length <= 0) continue;
      // A window at least a whole cycle long covers the circle by itself.
      if (length >= _secondsPerDay) return const Duration(days: 1);

      final start = shift.startMinute * 60;
      final end = start + length;
      if (end <= _secondsPerDay) {
        spans.add(_SecondSpan(start, end));
      } else {
        spans
          ..add(_SecondSpan(start, _secondsPerDay))
          ..add(_SecondSpan(0, end - _secondsPerDay));
      }
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
    // Keyed by epoch milliseconds rather than by the DateTime: an int hashes
    // and compares in a handful of instructions where a DateTime does not, and
    // this is the hottest lookup in a run.
    final key = day.millisecondsSinceEpoch;
    final cached = _intervalCache[key];
    if (cached != null) return cached;
    return _intervalCache[key] = _computeIntervalsStartingOn(day);
  }

  /// Memoised because a calendar is immutable and the callers ask the same
  /// question over and over: `advance`, `nextOpen` and `openTimeBetween` all
  /// walk day by day, and a simulation walks them tens of thousands of times
  /// (§7.1, §14). Recomputing a day's shift windows on every visit was the
  /// engine's whole cost.
  final Map<int, List<OpenInterval>> _intervalCache = {};

  /// Who is on each shift of [day], honouring its exception — or empty when the
  /// plant is shut.
  ///
  /// Extracted so [operatorsAt] and the interval walk cannot disagree about
  /// staffing: one asks *is this hour open*, the other *how many people are in
  /// it*, and two readings of the same day would be a fault of the shape §7.6
  /// has already paid for twice.
  List<int> _crewOn(DateTime day) {
    final exception = exceptions[day];
    if (exception?.kind == CalendarExceptionKind.nonWorking) return const [];
    if (exception?.kind == CalendarExceptionKind.extraWorking) {
      // Extra hours may bring their own staffing; null means "as an ordinary
      // working day", which is the common case of simply opening a Saturday.
      return exception!.operatorsPerShift ?? staffing.operatorsOn(day);
    }
    if (pattern.worksOnWeekday(day.weekday)) return staffing.operatorsOn(day);
    return const [];
  }

  /// How many operators are on the shift covering [t] (DESIGN.md §7.5, v30).
  ///
  /// **At a labour-paced station this is the throughput**, so it divides the
  /// work in `effectiveProcessTime`. Read at the instant work *starts* and held
  /// for the whole job, which is how availability already behaves — a job
  /// beginning at 22:00 under a two-operator night shift is costed at two even
  /// if it runs into a three-operator morning. Letting the rate change
  /// mid-process is a different engine, and §4.4 declines it for the same
  /// reason.
  ///
  /// **Never zero.** An instant inside no staffed shift returns 1, which costs
  /// the work exactly as the model did before this existed — the conservative
  /// answer, and unreachable from the simulation, which only ever starts work
  /// at an open instant.
  int operatorsAt(DateTime t) {
    // The previous day too: a shift that started at 23:40 yesterday is what
    // staffs 02:00 today.
    for (final day in [_previousDay(dateOnly(t)), dateOnly(t)]) {
      final crew = _crewOn(day);
      for (final shift in pattern.shifts) {
        final count = shift.position < crew.length ? crew[shift.position] : 0;
        if (count <= 0) continue;
        final start = _at(day, shift.startMinute);
        final grossEnd = shift.crossesMidnight
            ? _at(_nextDay(day), shift.endMinute)
            : _at(day, shift.endMinute);
        final end = grossEnd.subtract(Duration(seconds: shift.breakSeconds));
        if (!t.isBefore(start) && t.isBefore(end)) return count;
      }
    }
    return 1;
  }

  List<OpenInterval> _computeIntervalsStartingOn(DateTime day) {
    final exception = exceptions[day];

    if (exception?.kind == CalendarExceptionKind.nonWorking) {
      return const [];
    }

    final operators = _crewOn(day);
    if (operators.isEmpty) return const [];

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

  /// Open time attributed to [date] — the capacity that day's shifts add.
  ///
  /// "Add", not "hold": where the previous night's shift overruns into this
  /// day, that time was already counted as the previous day's, and a single
  /// server cannot be open twice over. Crediting it to the day whose shift
  /// reached it first is what keeps `Σ openTimeOnDate` equal to
  /// [openTimeBetween] across the same span.
  Duration openTimeOnDate(DateTime date) => _unclaimedIntervalsOn(
    dateOnly(date),
  ).fold(Duration.zero, (total, interval) => total + interval.duration);

  bool isOpenAt(DateTime t) {
    // The previous day too: a shift that started at 23:40 yesterday is what
    // makes 02:00 today open.
    for (final interval in _intervalsAround(t)) {
      if (interval.contains(t)) return true;
    }
    return false;
  }

  /// Open time between [from] and [to], **each hour weighted by the crew
  /// standing in it** — operator-hours rather than station-hours (§7.5, v30).
  ///
  /// **What a labour-paced station's capacity is measured in.** Where the
  /// machine-paced reading asks how long the station was open, this asks how
  /// much *work* could have been done in that time: a shift open eight hours
  /// with three people offers twenty-four, and doubling the crew doubles the
  /// answer. It is the same quantity `units` already produces for a station
  /// with two machines, counted in people instead.
  ///
  /// **Sliced at every shift boundary rather than merged**, because the crew is
  /// a property of the shift and a merged window spanning two of them has two
  /// answers. The slices come from the pattern's own start and end minutes, so
  /// the subdivision is exact rather than sampled — and the total open time it
  /// weights is [openTimeBetween]'s to the second, because it walks the same
  /// intervals.
  Duration operatorTimeBetween(DateTime from, DateTime to) {
    if (!to.isAfter(from)) return Duration.zero;
    var total = Duration.zero;
    var day = _previousDay(dateOnly(from));
    final last = dateOnly(to);
    while (!day.isAfter(last)) {
      for (final interval in _unclaimedIntervalsOn(day)) {
        final start = interval.start.isBefore(from) ? from : interval.start;
        final end = interval.end.isAfter(to) ? to : interval.end;
        if (!end.isAfter(start)) continue;
        for (final slice in _sliceAtShiftBoundaries(start, end)) {
          total += slice.duration * operatorsAt(slice.start);
        }
      }
      day = _nextDay(day);
    }
    return total;
  }

  /// [start, end) cut wherever a shift begins or ends inside it, so each piece
  /// has one crew.
  Iterable<OpenInterval> _sliceAtShiftBoundaries(DateTime start, DateTime end) {
    final cuts = <DateTime>{start, end};
    for (var day = _previousDay(dateOnly(start));
        !day.isAfter(dateOnly(end));
        day = _nextDay(day)) {
      for (final shift in pattern.shifts) {
        cuts.add(_at(day, shift.startMinute));
        final grossEnd = shift.crossesMidnight
            ? _at(_nextDay(day), shift.endMinute)
            : _at(day, shift.endMinute);
        cuts.add(grossEnd.subtract(Duration(seconds: shift.breakSeconds)));
      }
    }
    final inside =
        cuts.where((t) => !t.isBefore(start) && !t.isAfter(end)).toList()
          ..sort();
    return [
      for (var i = 0; i < inside.length - 1; i++)
        if (inside[i + 1].isAfter(inside[i]))
          OpenInterval(inside[i], inside[i + 1]),
    ];
  }

  /// The open window containing [from], or the next one after it.
  ///
  /// Null if there is none within [_searchLimitDays]. Where [nextOpen] answers
  /// "when could work start", this answers "and how long does that opening
  /// last" — which lets a caller that asks repeatedly, like the simulation's
  /// dispatcher, cache the answer until the window closes instead of walking
  /// the calendar on every event (§7.1, §14).
  OpenInterval? openWindowFrom(DateTime from) {
    var day = _previousDay(dateOnly(from));
    for (var i = 0; i <= _searchLimitDays; i++) {
      for (final interval in intervalsStartingOn(day)) {
        if (interval.end.isAfter(from)) return interval;
      }
      day = _nextDay(day);
    }
    return null;
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
    // runs through `to`'s date inclusive. Each day contributes only what the
    // day before did not already claim, so an overrunning night shift is
    // counted once rather than twice.
    while (!day.isAfter(last)) {
      for (final interval in _unclaimedIntervalsOn(day)) {
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

  /// The instant at which [work] of open time would have to **begin** to end
  /// no later than [until] — [advance] read backwards (DESIGN.md §7.8).
  ///
  /// A run starts at the first order's need date minus that part's theoretical
  /// lead time (§7.9), and "minus" there is a walk, not a subtraction: taking
  /// 40 open hours off a Monday morning lands on the previous Tuesday, not on
  /// the previous Saturday. Nothing else can answer that, because a working
  /// day is not a fixed fraction of a calendar one.
  ///
  /// Throws [StateError] if the calendar cannot supply that much open time
  /// within [_searchLimitDays], for the same reason [advance] does: a calendar
  /// with no staffed shift must fail loudly rather than loop.
  DateTime retreat(DateTime until, Duration work) {
    if (work.isNegative) {
      throw ArgumentError.value(work, 'work', 'must not be negative');
    }
    var remaining = work;
    var cursor = until;
    // One day ahead, so a window that started yesterday and runs past midnight
    // into `until` is seen; the mirror of [advance]'s step backwards.
    var day = _nextDay(dateOnly(until));

    for (var i = 0; i <= _searchLimitDays; i++) {
      // Latest first: walking backwards spends the time nearest the deadline
      // before reaching for anything earlier.
      for (final interval in intervalsStartingOn(day).reversed) {
        if (!interval.start.isBefore(cursor)) continue;
        final end = interval.end.isBefore(cursor) ? interval.end : cursor;
        final available = end.difference(interval.start);
        if (remaining <= available) return end.subtract(remaining);
        remaining -= available;
        cursor = interval.start;
      }
      day = _previousDay(day);
    }
    throw StateError(
      'Could not retreat ${work.inMinutes} min of open time from $until on '
      '${pattern.name} within $_searchLimitDays days. Check that at least one '
      'shift has operators assigned.',
    );
  }

  /// [day]'s intervals, minus whatever the day before already claimed.
  ///
  /// Only the previous day can reach in: a shift window is at most 24 hours
  /// long, so nothing starting earlier survives to touch [day].
  ///
  /// [advance] and [nextOpen] deliberately do **not** use this. They walk
  /// forward from a cursor that never moves backwards, so an overlapping
  /// interval from the following day is clipped to the cursor and its shared
  /// time spent once — the trimming here would be redundant, and doing it in
  /// [intervalsStartingOn] itself would make that method answer a question
  /// about two days rather than the one it is asked about.
  List<OpenInterval> _unclaimedIntervalsOn(DateTime day) {
    final today = intervalsStartingOn(day);
    if (today.isEmpty) return today;
    final yesterday = intervalsStartingOn(_previousDay(day));
    if (yesterday.isEmpty) return today;
    return _subtract(today, yesterday);
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

  /// [from] with every part covered by [remove] cut out. Both are merged and
  /// sorted; the result is too.
  static List<OpenInterval> _subtract(
    List<OpenInterval> from,
    List<OpenInterval> remove,
  ) {
    var pieces = from;
    for (final cut in remove) {
      final kept = <OpenInterval>[];
      for (final piece in pieces) {
        // Touching at an endpoint is not overlapping: a shift that ends at
        // 07:00 and one that starts at 07:00 are a handover, not a clash.
        if (!cut.start.isBefore(piece.end) || !piece.start.isBefore(cut.end)) {
          kept.add(piece);
          continue;
        }
        if (piece.start.isBefore(cut.start)) {
          kept.add(OpenInterval(piece.start, cut.start));
        }
        if (cut.end.isBefore(piece.end)) {
          kept.add(OpenInterval(cut.end, piece.end));
        }
      }
      pieces = kept;
    }
    return pieces;
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
