import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/schedules/application/schedule_periods.dart';
import 'package:flowmap/src/features/schedules/application/takt_schedule.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// The period lookup rules of DESIGN.md §11.1: a gap inside the covered span is
/// a data hole, but the tail past the last period is carried forward.
void main() {
  WorkcenterSchedulePeriodSpec period(
    String start,
    String end, {
    List<int> operators = const [1, 1, 1],
    double availability = 1,
    double rework = 0,
  }) => WorkcenterSchedulePeriodSpec(
    startDate: DateTime.parse(start),
    endDate: DateTime.parse(end),
    operatorsPerShift: operators,
    availability: availability,
    rework: rework,
  );

  group('PeriodSchedule lookup', () {
    final schedule = WorkcenterScheduleSpec([
      period('2026-01-01', '2026-06-30', operators: [1, 1, 1]),
      period('2026-07-01', '2026-12-31', operators: [1, 1, 0]),
    ]);

    test('a date inside a period matches it exactly', () {
      final result = schedule.lookup(DateTime(2026, 3, 15));
      expect(result.match, PeriodMatch.exact);
      expect(result.period!.operatorsPerShift, [1, 1, 1]);
    });

    test('boundaries are inclusive at both ends', () {
      expect(schedule.lookup(DateTime(2026, 1, 1)).match, PeriodMatch.exact);
      expect(schedule.lookup(DateTime(2026, 6, 30)).period!.operatorsPerShift, [
        1,
        1,
        1,
      ]);
      expect(schedule.lookup(DateTime(2026, 7, 1)).period!.operatorsPerShift, [
        1,
        1,
        0,
      ]);
      expect(schedule.lookup(DateTime(2026, 12, 31)).match, PeriodMatch.exact);
    });

    test('the time of day on a lookup is ignored', () {
      expect(
        schedule.lookup(DateTime(2026, 6, 30, 23, 59)).match,
        PeriodMatch.exact,
      );
    });

    test('past the last period, the last one is carried forward', () {
      final result = schedule.lookup(DateTime(2027, 4, 1));
      expect(result.match, PeriodMatch.carriedForward);
      expect(
        result.period!.operatorsPerShift,
        [1, 1, 0],
        reason: 'an overloaded plant must stay simulatable past its schedule',
      );
    });

    test('before the first period is missing, not carried backward', () {
      final result = schedule.lookup(DateTime(2025, 12, 31));
      expect(result.match, PeriodMatch.missing);
      expect(result.period, isNull);
    });

    test('an empty schedule reports missing rather than throwing', () {
      final empty = WorkcenterScheduleSpec(const []);
      expect(empty.lookup(DateTime(2026, 3, 1)).match, PeriodMatch.missing);
      expect(empty.operatorsOn(DateTime(2026, 3, 1)), isEmpty);
      expect(empty.isEverStaffed, isFalse);
    });

    test('periods are sorted however they arrive', () {
      final unsorted = WorkcenterScheduleSpec([
        period('2026-07-01', '2026-12-31', operators: [1, 0, 0]),
        period('2026-01-01', '2026-06-30', operators: [1, 1, 1]),
      ]);
      expect(unsorted.periods.first.startDate, DateTime(2026, 1, 1));
      expect(unsorted.operatorsOn(DateTime(2026, 9, 1)), [1, 0, 0]);
    });
  });

  group('gap in the middle', () {
    final gapped = WorkcenterScheduleSpec([
      period('2026-01-01', '2026-03-31'),
      period('2026-05-01', '2026-12-31'),
    ]);

    test('a date in the gap is missing, not carried forward', () {
      final result = gapped.lookup(DateTime(2026, 4, 15));
      expect(
        result.match,
        PeriodMatch.missing,
        reason: 'April is a real data hole, not the open-ended tail',
      );
    });

    test('the gap is reported with its exact bounds', () {
      final gaps = gapped.schedule.internalGaps();
      expect(gaps, hasLength(1));
      expect(gaps.single.$1, DateTime(2026, 4, 1));
      expect(gaps.single.$2, DateTime(2026, 4, 30));
    });

    test('adjacent periods leave no gap', () {
      final contiguous = WorkcenterScheduleSpec([
        period('2026-01-01', '2026-06-30'),
        period('2026-07-01', '2026-12-31'),
      ]);
      expect(contiguous.schedule.internalGaps(), isEmpty);
    });
  });

  group('malformed periods are reported, not thrown on', () {
    test('overlapping periods are found in pairs', () {
      final overlapping = WorkcenterScheduleSpec([
        period('2026-01-01', '2026-07-31'),
        period('2026-07-01', '2026-12-31'),
      ]);
      expect(overlapping.schedule.overlaps(), hasLength(1));
      // Still total: the earlier period wins so nothing downstream explodes.
      expect(
        overlapping.lookup(DateTime(2026, 7, 15)).match,
        PeriodMatch.exact,
      );
    });

    test('a period ending before it starts is found', () {
      final inverted = WorkcenterScheduleSpec([
        period('2026-06-30', '2026-01-01'),
      ]);
      expect(inverted.schedule.inverted(), hasLength(1));
    });
  });

  group('availability and rework follow the period', () {
    final schedule = WorkcenterScheduleSpec([
      period('2026-01-01', '2026-06-30', availability: 0.74, rework: 0.037),
      period('2026-07-01', '2026-12-31', availability: 0.9, rework: 0.01),
    ]);

    test('read from the period in force', () {
      expect(schedule.availabilityOn(DateTime(2026, 3, 1)), 0.74);
      expect(schedule.reworkOn(DateTime(2026, 3, 1)), 0.037);
      expect(schedule.availabilityOn(DateTime(2026, 9, 1)), 0.9);
    });

    test('carried forward past the end with the last period', () {
      expect(schedule.availabilityOn(DateTime(2028, 1, 1)), 0.9);
    });

    test('fall back to no loss where nothing covers the date', () {
      expect(schedule.availabilityOn(DateTime(2020, 1, 1)), 1);
      expect(schedule.reworkOn(DateTime(2020, 1, 1)), 0);
    });
  });

  group('staffed shift count is derived', () {
    test('counts the shifts with operators, wherever they sit', () {
      expect(
        period(
          '2026-01-01',
          '2026-12-31',
          operators: [1, 1, 1],
        ).staffedShiftCount,
        3,
      );
      expect(
        period(
          '2026-01-01',
          '2026-12-31',
          operators: [1, 1, 0],
        ).staffedShiftCount,
        2,
      );
      expect(
        period(
          '2026-01-01',
          '2026-12-31',
          operators: [0, 1, 1],
        ).staffedShiftCount,
        2,
      );
      expect(
        period(
          '2026-01-01',
          '2026-12-31',
          operators: [0, 0, 0],
        ).staffedShiftCount,
        0,
      );
    });
  });

  group('takt', () {
    final workingDay = const Duration(hours: 22, minutes: 40);

    TaktPeriodSpec taktOf(double value, TaktUnit unit) => TaktPeriodSpec(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      value: value,
      unit: unit,
    );

    test("a 3-day takt is three of that workcenter's working days", () {
      // The same takt resolves differently at differently-staffed stations,
      // which is the whole point of the equivalency method (DESIGN.md §6.1).
      final threeDays = taktOf(3, TaktUnit.days);
      expect(threeDays.equivalentAt(workingDay), const Duration(hours: 68));
      expect(
        threeDays.equivalentAt(const Duration(hours: 8, minutes: 48)),
        const Duration(hours: 26, minutes: 24),
      );
      expect(threeDays.isWorkcenterRelative, isTrue);
    });

    test('hours, minutes and seconds resolve the same everywhere', () {
      for (final day in [workingDay, const Duration(hours: 8)]) {
        expect(
          taktOf(90, TaktUnit.minutes).equivalentAt(day),
          const Duration(minutes: 90),
        );
        expect(
          taktOf(2.5, TaktUnit.hours).equivalentAt(day),
          const Duration(hours: 2, minutes: 30),
        );
        expect(
          taktOf(45, TaktUnit.seconds).equivalentAt(day),
          const Duration(seconds: 45),
        );
      }
      expect(taktOf(90, TaktUnit.minutes).isWorkcenterRelative, isFalse);
    });

    test('a takt schedule reads the period in force', () {
      final schedule = TaktScheduleSpec([
        TaktPeriodSpec(
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 6, 30),
          value: 3,
          unit: TaktUnit.days,
        ),
        TaktPeriodSpec(
          startDate: DateTime(2026, 7, 1),
          endDate: DateTime(2026, 12, 31),
          value: 4,
          unit: TaktUnit.days,
        ),
      ]);
      expect(schedule.taktOn(DateTime(2026, 3, 1))!.value, 3);
      expect(schedule.taktOn(DateTime(2026, 9, 1))!.value, 4);
      expect(schedule.taktOn(DateTime(2025, 1, 1)), isNull);
      // Past the end, carried forward like any other period.
      expect(schedule.taktOn(DateTime(2027, 5, 1))!.value, 4);
    });

    test('a workcenter with no open time yields a zero equivalent', () {
      expect(
        taktOf(3, TaktUnit.days).equivalentAt(Duration.zero),
        Duration.zero,
      );
    });
  });
}
