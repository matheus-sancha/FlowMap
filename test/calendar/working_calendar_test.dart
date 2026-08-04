import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every expected value here is hand-computed from the clock readings, not
/// produced by running the code. The calendar is what every other number in
/// FlowMap is built on (DESIGN.md §15), so its tests must be able to disagree
/// with it.
void main() {
  // The seeded ABC pattern (DESIGN.md §4.1):
  //   A 05:45–15:13, break 40 min  →  gross 9:28, net 8:48, ends 14:33
  //   B 14:26–23:40, break 40 min  →  gross 9:14, net 8:34, ends 23:00
  //   C 23:40–05:45, break 40 min  →  gross 6:05, net 5:25, ends 05:05 (+1d)
  final abc = ShiftPatternSpec(
    name: 'ABC',
    cycleType: ShiftCycleType.fixedWeekly,
    workingWeekdays: ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5]),
    shifts: const [
      ShiftWindow(
        label: 'A',
        position: 0,
        startMinute: 5 * 60 + 45,
        endMinute: 15 * 60 + 13,
        breakSeconds: 40 * 60,
      ),
      ShiftWindow(
        label: 'B',
        position: 1,
        startMinute: 14 * 60 + 26,
        endMinute: 23 * 60 + 40,
        breakSeconds: 40 * 60,
      ),
      ShiftWindow(
        label: 'C',
        position: 2,
        startMinute: 23 * 60 + 40,
        endMinute: 5 * 60 + 45,
        breakSeconds: 40 * 60,
      ),
    ],
  );

  // The seeded ABCD pattern: two 12-hour windows, every day, no break.
  final abcd = ShiftPatternSpec(
    name: 'ABCD',
    cycleType: ShiftCycleType.rotating,
    workingWeekdays: ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5, 6, 7]),
    shifts: const [
      ShiftWindow(
        label: 'Day',
        position: 0,
        startMinute: 7 * 60,
        endMinute: 19 * 60,
      ),
      ShiftWindow(
        label: 'Night',
        position: 1,
        startMinute: 19 * 60,
        endMinute: 7 * 60,
      ),
    ],
  );

  // A pattern whose night shift overruns the next morning's start by an hour —
  // a generous handover, and the case that used to make a day worth 25 hours.
  //   Day   06:00–18:00           → 12:00
  //   Night 18:00–07:00 (+1d)     → 13:00
  // Laid end to end that is 25 hours; the machine is one server, so the real
  // coverage is the whole 24-hour day and no more.
  final handover = ShiftPatternSpec(
    name: 'handover',
    cycleType: ShiftCycleType.rotating,
    workingWeekdays: ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5, 6, 7]),
    shifts: const [
      ShiftWindow(
        label: 'Day',
        position: 0,
        startMinute: 6 * 60,
        endMinute: 18 * 60,
      ),
      ShiftWindow(
        label: 'Night',
        position: 1,
        startMinute: 18 * 60,
        endMinute: 7 * 60,
      ),
    ],
  );

  // 2026-08-03 is a Monday; the whole suite is anchored to that week.
  final monday = DateTime(2026, 8, 3);
  final saturday = DateTime(2026, 8, 8);
  final sunday = DateTime(2026, 8, 9);

  group('ShiftWindow', () {
    test('gross and net duration of a daytime shift', () {
      const shift = ShiftWindow(
        label: 'A',
        position: 0,
        startMinute: 5 * 60 + 45,
        endMinute: 15 * 60 + 13,
        breakSeconds: 40 * 60,
      );
      expect(shift.crossesMidnight, isFalse);
      expect(shift.grossDuration, const Duration(hours: 9, minutes: 28));
      expect(shift.netDuration, const Duration(hours: 8, minutes: 48));
    });

    test('a shift ending at or before its start reading crosses midnight', () {
      const shift = ShiftWindow(
        label: 'C',
        position: 2,
        startMinute: 23 * 60 + 40,
        endMinute: 5 * 60 + 45,
        breakSeconds: 40 * 60,
      );
      expect(shift.crossesMidnight, isTrue);
      expect(shift.grossDuration, const Duration(hours: 6, minutes: 5));
      expect(shift.netDuration, const Duration(hours: 5, minutes: 25));
    });

    test('a 24-hour shift crosses midnight rather than reading as empty', () {
      const shift = ShiftWindow(
        label: 'Continuous',
        position: 0,
        startMinute: 360,
        endMinute: 360,
      );
      expect(shift.crossesMidnight, isTrue);
      expect(shift.grossDuration, const Duration(hours: 24));
    });
  });

  group('sanity', () {
    test('the anchor dates are the weekdays the suite assumes', () {
      expect(monday.weekday, DateTime.monday);
      expect(saturday.weekday, DateTime.saturday);
      expect(sunday.weekday, DateTime.sunday);
    });
  });

  group('openTimePerWorkingDay', () {
    test('three shifts, overlapping handover counted once', () {
      // A 05:45→14:33 and B 14:26→23:00 overlap by 7 minutes, so the union is
      // 05:45→23:00 = 17:15, plus C 23:40→05:05 = 5:25. Total 22:40.
      final calendar = WorkingCalendar(
        pattern: abc,
        operatorsPerShift: const [1, 1, 1],
      );
      expect(
        calendar.openTimePerWorkingDay(monday),
        const Duration(hours: 22, minutes: 40),
      );
    });

    test('one shift is that shift net of its break', () {
      final calendar = WorkingCalendar(
        pattern: abc,
        operatorsPerShift: const [1, 0, 0],
      );
      expect(
        calendar.openTimePerWorkingDay(monday),
        const Duration(hours: 8, minutes: 48),
      );
    });

    test('unstaffed shifts contribute nothing, whichever they are', () {
      final calendar = WorkingCalendar(
        pattern: abc,
        operatorsPerShift: const [0, 1, 1],
      );
      // B 14:26→23:00 = 8:34, C 23:40→05:05 = 5:25. No overlap. 13:59.
      expect(
        calendar.openTimePerWorkingDay(monday),
        const Duration(hours: 13, minutes: 59),
      );
    });

    test('a staffing list shorter than the pattern reads as unstaffed', () {
      final calendar = WorkingCalendar(
        pattern: abc,
        operatorsPerShift: const [1],
      );
      expect(
        calendar.openTimePerWorkingDay(monday),
        const Duration(hours: 8, minutes: 48),
      );
    });

    test('two touching 12-hour windows make a full 24 hours', () {
      final calendar = WorkingCalendar(
        pattern: abcd,
        operatorsPerShift: const [1, 1],
      );
      expect(calendar.openTimePerWorkingDay(monday), const Duration(hours: 24));
    });

    test('operators above one do not add capacity to a single-server WC', () {
      final one = WorkingCalendar(
        pattern: abc,
        operatorsPerShift: const [1, 1, 1],
      );
      final three = WorkingCalendar(
        pattern: abc,
        operatorsPerShift: const [3, 3, 3],
      );
      expect(
        three.openTimePerWorkingDay(monday),
        one.openTimePerWorkingDay(monday),
      );
    });
  });

  group('intervalsStartingOn', () {
    test('merges the overlapping A and B shifts into one interval', () {
      final calendar = WorkingCalendar(
        pattern: abc,
        operatorsPerShift: const [1, 1, 1],
      );
      final intervals = calendar.intervalsStartingOn(monday);
      expect(intervals, hasLength(2));
      expect(intervals[0].start, DateTime(2026, 8, 3, 5, 45));
      expect(intervals[0].end, DateTime(2026, 8, 3, 23, 0));
      expect(intervals[1].start, DateTime(2026, 8, 3, 23, 40));
      expect(intervals[1].end, DateTime(2026, 8, 4, 5, 5));
    });

    test('a weekend is closed under a fixed weekly pattern', () {
      final calendar = WorkingCalendar(
        pattern: abc,
        operatorsPerShift: const [1, 1, 1],
      );
      expect(calendar.intervalsStartingOn(saturday), isEmpty);
      expect(calendar.intervalsStartingOn(sunday), isEmpty);
    });

    test('a rotating pattern works every day', () {
      final calendar = WorkingCalendar(
        pattern: abcd,
        operatorsPerShift: const [1, 1],
      );
      expect(calendar.intervalsStartingOn(sunday), hasLength(1));
      expect(calendar.openTimeOnDate(sunday), const Duration(hours: 24));
    });

    test(
      'a break longer than its shift drops the shift rather than inverting',
      () {
        final pattern = ShiftPatternSpec(
          name: 'Broken',
          cycleType: ShiftCycleType.fixedWeekly,
          workingWeekdays: ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5]),
          shifts: const [
            ShiftWindow(
              label: 'A',
              position: 0,
              startMinute: 8 * 60,
              endMinute: 9 * 60,
              breakSeconds: 2 * 60 * 60,
            ),
          ],
        );
        final calendar = WorkingCalendar(
          pattern: pattern,
          operatorsPerShift: const [1],
        );
        expect(calendar.intervalsStartingOn(monday), isEmpty);
        expect(calendar.openTimePerWorkingDay(monday), Duration.zero);
      },
    );
  });

  group('isOpenAt', () {
    final calendar = WorkingCalendar(
      pattern: abc,
      operatorsPerShift: const [1, 1, 1],
    );

    test('inside a shift', () {
      expect(calendar.isOpenAt(DateTime(2026, 8, 3, 9, 0)), isTrue);
    });

    test('during the break taken off the end of the last shift', () {
      // B's net end is 23:00; 23:20 is inside neither B nor C.
      expect(calendar.isOpenAt(DateTime(2026, 8, 3, 23, 20)), isFalse);
    });

    test('before the first shift starts', () {
      expect(calendar.isOpenAt(DateTime(2026, 8, 3, 5, 0)), isFalse);
    });

    test(
      "a night shift keeps the next morning open before the day's shift",
      () {
        // Monday's C runs to 05:05 Tuesday; Tuesday's A starts 05:45.
        expect(calendar.isOpenAt(DateTime(2026, 8, 4, 2, 0)), isTrue);
        expect(calendar.isOpenAt(DateTime(2026, 8, 4, 5, 30)), isFalse);
      },
    );

    test('a night shift starting on Friday spills into Saturday', () {
      // Friday 2026-08-07's C shift runs to 05:05 on Saturday, even though
      // Saturday itself is not a working day.
      expect(calendar.isOpenAt(DateTime(2026, 8, 8, 3, 0)), isTrue);
      expect(calendar.isOpenAt(DateTime(2026, 8, 8, 6, 0)), isFalse);
    });

    test('an interval is half-open: its end instant is already closed', () {
      expect(calendar.isOpenAt(DateTime(2026, 8, 3, 23, 0)), isFalse);
      expect(calendar.isOpenAt(DateTime(2026, 8, 3, 22, 59, 59)), isTrue);
    });
  });

  group('nextOpen', () {
    final calendar = WorkingCalendar(
      pattern: abc,
      operatorsPerShift: const [1, 0, 0],
    );

    test('returns the instant itself when already open', () {
      final t = DateTime(2026, 8, 3, 9, 0);
      expect(calendar.nextOpen(t), t);
    });

    test('jumps to the start of the next shift', () {
      expect(
        calendar.nextOpen(DateTime(2026, 8, 3, 20, 0)),
        DateTime(2026, 8, 4, 5, 45),
      );
    });

    test('jumps over a weekend', () {
      expect(
        calendar.nextOpen(DateTime(2026, 8, 8, 9, 0)),
        DateTime(2026, 8, 10, 5, 45),
      );
    });

    test('fails loudly rather than looping when nothing is ever staffed', () {
      final closed = WorkingCalendar(
        pattern: abc,
        operatorsPerShift: const [0, 0, 0],
      );
      expect(closed.isEverOpen, isFalse);
      expect(() => closed.nextOpen(monday), throwsStateError);
    });
  });

  group('advance', () {
    final dayShift = WorkingCalendar(
      pattern: abc,
      operatorsPerShift: const [1, 0, 0],
    );

    test('within a single shift', () {
      expect(
        dayShift.advance(DateTime(2026, 8, 3, 6, 0), const Duration(hours: 2)),
        DateTime(2026, 8, 3, 8, 0),
      );
    });

    test('zero work is the moment work would start', () {
      expect(
        dayShift.advance(DateTime(2026, 8, 3, 3, 0), Duration.zero),
        DateTime(2026, 8, 3, 5, 45),
      );
      expect(
        dayShift.advance(DateTime(2026, 8, 3, 3, 0), Duration.zero),
        dayShift.nextOpen(DateTime(2026, 8, 3, 3, 0)),
      );
    });

    test('starting before the shift opens does not consume closed time', () {
      // 02:00 Monday + 1 h of work: the hour is taken from 05:45 onward.
      expect(
        dayShift.advance(DateTime(2026, 8, 3, 2, 0), const Duration(hours: 1)),
        DateTime(2026, 8, 3, 6, 45),
      );
    });

    test('spills into the next working day', () {
      // A is 8:48 long. 10 h from 05:45 Monday: 8:48 on Monday leaves 1:12,
      // taken from Tuesday 05:45 → 06:57.
      expect(
        dayShift.advance(
          DateTime(2026, 8, 3, 5, 45),
          const Duration(hours: 10),
        ),
        DateTime(2026, 8, 4, 6, 57),
      );
    });

    test('skips the weekend', () {
      // Friday 2026-08-07 05:45 + 10 h: 8:48 Friday, 1:12 on Monday the 10th.
      expect(
        dayShift.advance(
          DateTime(2026, 8, 7, 5, 45),
          const Duration(hours: 10),
        ),
        DateTime(2026, 8, 10, 6, 57),
      );
    });

    test('a full week of a one-shift calendar is 5 × 8:48', () {
      const week = Duration(hours: 44); // 5 × 8:48
      expect(
        dayShift.advance(DateTime(2026, 8, 3, 5, 45), week),
        DateTime(2026, 8, 7, 14, 33),
      );
    });

    test(
      'lands exactly on a shift end rather than rolling to the next day',
      () {
        expect(
          dayShift.advance(
            DateTime(2026, 8, 3, 5, 45),
            const Duration(hours: 8, minutes: 48),
          ),
          DateTime(2026, 8, 3, 14, 33),
        );
      },
    );

    test('rejects negative work', () {
      expect(
        () => dayShift.advance(monday, const Duration(hours: -1)),
        throwsArgumentError,
      );
    });

    test('24/7 coverage advances in plain wall-clock time', () {
      final continuous = WorkingCalendar(
        pattern: abcd,
        operatorsPerShift: const [1, 1],
      );
      expect(
        continuous.advance(
          DateTime(2026, 8, 3, 10, 0),
          const Duration(hours: 48),
        ),
        DateTime(2026, 8, 5, 10, 0),
      );
    });
  });

  group('openTimeBetween', () {
    final calendar = WorkingCalendar(
      pattern: abc,
      operatorsPerShift: const [1, 1, 1],
    );

    test('a full working week is 5 × 22:40', () {
      // Monday 00:00 to Saturday 00:00 counts Monday–Friday's day and evening
      // shifts, plus four nights that finish before Saturday, but Friday's
      // night shift runs past the boundary and only counts to 00:00.
      final total = calendar.openTimeBetween(monday, saturday);
      // 5 × 17:15 (A+B union) = 86:15, plus 4 × 5:25 nights = 21:40, plus
      // Friday night 23:40 → 00:00 = 0:20. Total 108:15.
      expect(total, const Duration(hours: 108, minutes: 15));
    });

    test('a window inside one shift', () {
      expect(
        calendar.openTimeBetween(
          DateTime(2026, 8, 3, 8, 0),
          DateTime(2026, 8, 3, 12, 0),
        ),
        const Duration(hours: 4),
      );
    });

    test('a window entirely inside closed time is zero', () {
      expect(
        calendar.openTimeBetween(
          DateTime(2026, 8, 8, 8, 0),
          DateTime(2026, 8, 9, 8, 0),
        ),
        Duration.zero,
      );
    });

    test('a reversed or empty window is zero', () {
      expect(calendar.openTimeBetween(saturday, monday), Duration.zero);
      expect(calendar.openTimeBetween(monday, monday), Duration.zero);
    });

    test('agrees with advance over the same span', () {
      final from = DateTime(2026, 8, 3, 6, 0);
      const work = Duration(hours: 30);
      final to = calendar.advance(from, work);
      expect(calendar.openTimeBetween(from, to), work);
    });
  });

  group('a night shift that overruns the next morning', () {
    final calendar = WorkingCalendar(
      pattern: handover,
      operatorsPerShift: const [1, 1],
    );
    final tuesday = DateTime(2026, 8, 4);
    final wednesday = DateTime(2026, 8, 5);

    test('a day is worth a day, not the sum of its windows', () {
      // 12:00 + 13:00 = 25:00 laid end to end. One server, so 24:00.
      expect(calendar.openTimePerWorkingDay(monday), const Duration(hours: 24));
    });

    test('a 24-hour window cannot hold more than 24 hours of open time', () {
      expect(
        calendar.openTimeBetween(tuesday, wednesday),
        const Duration(hours: 24),
      );
    });

    test('the overrun is credited to the day whose shift reached it', () {
      // Tuesday's own shifts span 06:00 Tue → 07:00 Wed, but Monday's night
      // shift already claimed 00:00–07:00 on Tuesday.
      expect(calendar.openTimeOnDate(tuesday), const Duration(hours: 24));
    });

    test('the days of a week sum to the week', () {
      var summed = Duration.zero;
      for (var i = 0; i < 7; i++) {
        summed += calendar.openTimeOnDate(DateTime(2026, 8, 3 + i));
      }
      expect(
        summed,
        calendar.openTimeBetween(monday, DateTime(2026, 8, 10)),
      );
      expect(summed, const Duration(hours: 24 * 7));
    });

    test('advance spends the shared hour once', () {
      // Open continuously, so 24 hours of work is 24 hours of wall clock.
      expect(
        calendar.advance(DateTime(2026, 8, 4, 6), const Duration(hours: 24)),
        DateTime(2026, 8, 5, 6),
      );
    });

    test('a handover that only touches loses nothing', () {
      // The seeded ABCD windows meet exactly at 07:00 and 19:00: nothing
      // overlaps, so nothing may be trimmed.
      final touching = WorkingCalendar(
        pattern: abcd,
        operatorsPerShift: const [1, 1],
      );
      expect(touching.openTimeOnDate(monday), const Duration(hours: 24));
      expect(
        touching.openTimeBetween(monday, DateTime(2026, 8, 10)),
        const Duration(hours: 24 * 7),
      );
    });
  });

  group('exceptions', () {
    final calendar = WorkingCalendar(
      pattern: abc,
      operatorsPerShift: const [1, 1, 1],
      exceptions: {
        // Holiday on Wednesday.
        DateTime(2026, 8, 5): const ResolvedCalendarException(
          kind: CalendarExceptionKind.nonWorking,
        ),
        // Extra hours on Saturday, day shift only.
        DateTime(2026, 8, 8): const ResolvedCalendarException(
          kind: CalendarExceptionKind.extraWorking,
          operatorsPerShift: [1, 0, 0],
        ),
      },
    );

    test('a non-working exception closes a base working day', () {
      expect(calendar.intervalsStartingOn(DateTime(2026, 8, 5)), isEmpty);
      expect(calendar.openTimeOnDate(DateTime(2026, 8, 5)), Duration.zero);
    });

    test(
      'a shift started the evening before still finishes on a closed day',
      () {
        // Tuesday's C runs to 05:05 Wednesday. The Wednesday shutdown stops
        // Wednesday's shifts from starting; it does not cut short a shift that
        // began on a working day.
        expect(calendar.isOpenAt(DateTime(2026, 8, 5, 2, 0)), isTrue);
        expect(calendar.isOpenAt(DateTime(2026, 8, 5, 9, 0)), isFalse);
      },
    );

    test('extra hours open a Saturday with their own staffing', () {
      final intervals = calendar.intervalsStartingOn(saturday);
      expect(intervals, hasLength(1));
      expect(intervals.single.start, DateTime(2026, 8, 8, 5, 45));
      expect(intervals.single.end, DateTime(2026, 8, 8, 14, 33));
    });

    test('extra hours without staffing use an ordinary day', () {
      final sundayOpen = WorkingCalendar(
        pattern: abc,
        operatorsPerShift: const [1, 1, 1],
        exceptions: {
          DateTime(2026, 8, 9): const ResolvedCalendarException(
            kind: CalendarExceptionKind.extraWorking,
          ),
        },
      );
      expect(
        sundayOpen.openTimeOnDate(sunday),
        const Duration(hours: 22, minutes: 40),
      );
    });

    test('advance walks around a holiday', () {
      final dayShift = WorkingCalendar(
        pattern: abc,
        operatorsPerShift: const [1, 0, 0],
        exceptions: {
          DateTime(2026, 8, 5): const ResolvedCalendarException(
            kind: CalendarExceptionKind.nonWorking,
          ),
        },
      );
      // Tuesday 05:45 + 10 h: 8:48 Tuesday, Wednesday is closed, 1:12 lands on
      // Thursday.
      expect(
        dayShift.advance(
          DateTime(2026, 8, 4, 5, 45),
          const Duration(hours: 10),
        ),
        DateTime(2026, 8, 6, 6, 57),
      );
    });
  });

  group('resolveExceptions', () {
    final plantShutdown = ScopedCalendarException(
      date: DateTime(2026, 8, 8),
      kind: CalendarExceptionKind.nonWorking,
      scope: CalendarExceptionScope.plant,
    );
    final lineExtra = ScopedCalendarException(
      date: DateTime(2026, 8, 8),
      kind: CalendarExceptionKind.extraWorking,
      scope: CalendarExceptionScope.productionLine,
      scopeId: 'line-1',
    );
    final workcenterExtra = ScopedCalendarException(
      date: DateTime(2026, 8, 8),
      kind: CalendarExceptionKind.extraWorking,
      scope: CalendarExceptionScope.workcenter,
      scopeId: 'wc-1',
      operatorsPerShift: [1, 0, 0],
    );

    test('a plant exception reaches every workcenter', () {
      final resolved = resolveExceptions([plantShutdown], workcenterId: 'wc-9');
      expect(
        resolved[DateTime(2026, 8, 8)]?.kind,
        CalendarExceptionKind.nonWorking,
      );
    });

    test('a line exception reaches only workcenters on that line', () {
      expect(
        resolveExceptions(
          [lineExtra],
          workcenterId: 'wc-1',
          productionLineIds: {'line-1'},
        ),
        isNotEmpty,
      );
      expect(
        resolveExceptions(
          [lineExtra],
          workcenterId: 'wc-1',
          productionLineIds: {'line-2'},
        ),
        isEmpty,
      );
      expect(resolveExceptions([lineExtra], workcenterId: 'wc-1'), isEmpty);
    });

    test('the most specific scope wins, whatever the list order', () {
      final resolved = resolveExceptions(
        [workcenterExtra, plantShutdown, lineExtra],
        workcenterId: 'wc-1',
        productionLineIds: {'line-1'},
      );
      final day = resolved[DateTime(2026, 8, 8)]!;
      expect(day.kind, CalendarExceptionKind.extraWorking);
      expect(day.operatorsPerShift, [1, 0, 0]);
    });

    test('a plant shutdown still applies to a workcenter with no override', () {
      final resolved = resolveExceptions([
        workcenterExtra,
        plantShutdown,
      ], workcenterId: 'wc-2');
      expect(
        resolved[DateTime(2026, 8, 8)]?.kind,
        CalendarExceptionKind.nonWorking,
      );
    });

    test('the time of day on an exception date is ignored', () {
      final resolved = resolveExceptions([
        ScopedCalendarException(
          date: DateTime(2026, 8, 8, 17, 30),
          kind: CalendarExceptionKind.nonWorking,
          scope: CalendarExceptionScope.plant,
        ),
      ], workcenterId: 'wc-1');
      expect(resolved.containsKey(DateTime(2026, 8, 8)), isTrue);
    });
  });
}
