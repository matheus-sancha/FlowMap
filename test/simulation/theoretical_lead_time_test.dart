import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart';
import 'package:flowmap/src/features/simulation/application/theoretical_lead_time.dart';
import 'package:flutter_test/flutter_test.dart';

/// What an order takes with the plant to itself (DESIGN.md §7.9), and where a
/// run therefore has to begin (§7.8).
void main() {
  /// Ten hours a day, Monday to Friday. Round numbers, and a weekend the walk
  /// has to step over.
  final weekdayTen = ShiftPatternSpec(
    name: 'Ten',
    cycleType: ShiftCycleType.fixedWeekly,
    workingWeekdays: ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5]),
    shifts: const [
      ShiftWindow(
        label: 'Day',
        position: 0,
        startMinute: 6 * 60,
        endMinute: 16 * 60,
        breakSeconds: 0,
      ),
    ],
  );

  SimWorkcenter workcenter(
    String id, {
    double availability = 1,
    double rework = 0,
  }) {
    final schedule = WorkcenterScheduleSpec([
      WorkcenterSchedulePeriodSpec(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        operatorsPerShift: const [1],
        availability: availability,
        rework: rework,
      ),
    ]);
    return SimWorkcenter(
      id: id,
      name: id,
      calendar: WorkingCalendar.scheduled(
        pattern: weekdayTen,
        staffing: schedule,
      ),
      schedule: schedule,
    );
  }

  SimStep step(
    int position,
    String target, {
    Duration changeover = Duration.zero,
  }) => SimStep(
    id: 'node-$position',
    position: position,
    title: target,
    candidates: [target],
    demandKey: target,
    changeover: changeover,
  );

  SimBuffer buffer(
    int position,
    Duration wait, {
    bool usesWorkingTime = false,
  }) => SimBuffer(
    id: 'node-$position',
    position: position,
    wait: wait,
    usesWorkingTime: usesWorkingTime,
  );

  SimPart part(Map<String, Duration> times) =>
      SimPart(id: 'p1', partNumber: 'PN1', processTimes: times);

  // Wednesday 5 August 2026, 06:00 — the start of a shift.
  final wednesday = DateTime(2026, 8, 5, 6);

  group('the walk', () {
    test('spends open time, and steps over a weekend', () {
      // 25 hours of work from Wednesday 06:00: 10 Wed, 10 Thu, 5 Fri, landing
      // Friday at 11:00.
      final result = theoreticalLeadTime(
        nodes: [step(0, 'CLAD04')],
        workcenters: {'CLAD04': workcenter('CLAD04')},
        part: part({'CLAD04': const Duration(hours: 25)}),
        batchSize: 1,
        from: wednesday,
      );

      expect(result!.end, DateTime(2026, 8, 7, 11));
      expect(result.workingTime, const Duration(hours: 25));
      // Elapsed is wall clock and longer than the work: that gap is the closed
      // time, and no ratio could produce it.
      expect(result.elapsed, const Duration(hours: 53));
    });

    test('batch size multiplies the work', () {
      final result = theoreticalLeadTime(
        nodes: [step(0, 'CLAD04')],
        workcenters: {'CLAD04': workcenter('CLAD04')},
        part: part({'CLAD04': const Duration(hours: 1)}),
        batchSize: 10,
        from: wednesday,
      );

      expect(result!.workingTime, const Duration(hours: 10));
    });

    test('availability and rework inflate the occupancy exactly once', () {
      final result = theoreticalLeadTime(
        nodes: [step(0, 'CLAD04')],
        workcenters: {
          'CLAD04': workcenter('CLAD04', availability: 0.5, rework: 0.1),
        },
        part: part({'CLAD04': const Duration(hours: 10)}),
        batchSize: 1,
        from: wednesday,
      );

      // 10 × 1.1 ÷ 0.5 = 22 hours (§4.4). The calendar does not derate its own
      // open time, so this is the only place availability appears.
      expect(result!.workingTime, const Duration(hours: 22));
    });

    test('changeover is excluded — it belongs to what ran before', () {
      final withSetup = theoreticalLeadTime(
        nodes: [step(0, 'CLAD04', changeover: const Duration(hours: 3))],
        workcenters: {'CLAD04': workcenter('CLAD04')},
        part: part({'CLAD04': const Duration(hours: 5)}),
        batchSize: 1,
        from: wednesday,
      );

      expect(withSetup!.workingTime, const Duration(hours: 5));
    });

    test('a calendar buffer runs on the wall clock, weekend included', () {
      // Friday 06:00 + a two-day cooling wait lands on Sunday, and the next
      // step picks up on Monday.
      final result = theoreticalLeadTime(
        nodes: [buffer(0, const Duration(days: 2)), step(1, 'CLAD04')],
        workcenters: {'CLAD04': workcenter('CLAD04')},
        part: part({'CLAD04': const Duration(hours: 2)}),
        batchSize: 1,
        from: DateTime(2026, 8, 7, 6),
      );

      expect(result!.end, DateTime(2026, 8, 10, 8));
    });

    test('a working-time buffer runs on the calendar of the step it feeds', () {
      // 12 open hours from Friday 06:00: 10 on Friday, 2 on Monday.
      final result = theoreticalLeadTime(
        nodes: [
          buffer(0, const Duration(hours: 12), usesWorkingTime: true),
          step(1, 'CLAD04'),
        ],
        workcenters: {'CLAD04': workcenter('CLAD04')},
        part: part({'CLAD04': const Duration(hours: 1)}),
        batchSize: 1,
        from: DateTime(2026, 8, 7, 6),
      );

      expect(result!.end, DateTime(2026, 8, 10, 9));
      // The buffer is waiting, not working, so it is not value-adding time.
      expect(result.workingTime, const Duration(hours: 1));
    });

    test('a part with no time at a step it must visit is not costed', () {
      final problems = <TheoreticalLeadTimeProblem>[];
      final result = theoreticalLeadTime(
        nodes: [step(0, 'CLAD04'), step(1, 'TTAT')],
        workcenters: {
          'CLAD04': workcenter('CLAD04'),
          'TTAT': workcenter('TTAT'),
        },
        part: part({'CLAD04': const Duration(hours: 5)}),
        batchSize: 1,
        from: wednesday,
        problems: problems,
      );

      expect(result, isNull);
      expect(problems, [TheoreticalLeadTimeProblem.noProcessTime]);
    });

    test('a station that never opens fails loudly rather than looping', () {
      final shut = WorkcenterScheduleSpec([
        WorkcenterSchedulePeriodSpec(
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
          operatorsPerShift: const [0],
        ),
      ]);
      final problems = <TheoreticalLeadTimeProblem>[];

      final result = theoreticalLeadTime(
        nodes: [step(0, 'SHUT')],
        workcenters: {
          'SHUT': SimWorkcenter(
            id: 'SHUT',
            name: 'SHUT',
            calendar: WorkingCalendar.scheduled(
              pattern: weekdayTen,
              staffing: shut,
            ),
            schedule: shut,
          ),
        },
        part: part({'SHUT': const Duration(hours: 1)}),
        batchSize: 1,
        from: wednesday,
        problems: problems,
      );

      expect(result, isNull);
      expect(problems, [TheoreticalLeadTimeProblem.neverOpen]);
    });
  });

  group('coldStartDate', () {
    test('is the walk run backwards, and lands where it started', () {
      final nodes = [
        step(0, 'CLAD04'),
        buffer(1, const Duration(days: 1)),
        step(2, 'TTAT'),
      ];
      final workcenters = {
        'CLAD04': workcenter('CLAD04'),
        'TTAT': workcenter('TTAT'),
      };
      final pn1 = part({
        'CLAD04': const Duration(hours: 14),
        'TTAT': const Duration(hours: 6),
      });

      final forward = theoreticalLeadTime(
        nodes: nodes,
        workcenters: workcenters,
        part: pn1,
        batchSize: 1,
        from: wednesday,
      )!;

      // The round trip is the property worth holding: a run begins where the
      // walk to the need date says it must (§7.8).
      final back = coldStartDate(
        nodes: nodes,
        workcenters: workcenters,
        part: pn1,
        batchSize: 1,
        needDate: forward.end,
      );

      expect(back, wednesday);
    });

    test('a weekend between is stepped over, not subtracted through', () {
      // 15 open hours ending Monday 11:00 is 5 on Monday and 10 on Friday, so
      // the walk begins Friday at 06:00 — not on the Saturday a wall-clock
      // subtraction would give.
      final start = coldStartDate(
        nodes: [step(0, 'CLAD04')],
        workcenters: {'CLAD04': workcenter('CLAD04')},
        part: part({'CLAD04': const Duration(hours: 15)}),
        batchSize: 1,
        needDate: DateTime(2026, 8, 10, 11),
      );

      expect(start, DateTime(2026, 8, 7, 6));
    });

    test('an order that cannot be costed has no start date', () {
      final problems = <TheoreticalLeadTimeProblem>[];
      final start = coldStartDate(
        nodes: [step(0, 'CLAD04')],
        workcenters: const {},
        part: part({'CLAD04': const Duration(hours: 1)}),
        batchSize: 1,
        needDate: wednesday,
        problems: problems,
      );

      expect(start, isNull);
      expect(problems, [TheoreticalLeadTimeProblem.unknownWorkcenter]);
    });
  });
}
