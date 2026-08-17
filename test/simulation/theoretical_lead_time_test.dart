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
    Duration stock = Duration.zero,
  }) => SimStep(
    id: 'node-$position',
    position: position,
    title: target,
    candidates: [target],
    demandKey: target,
    queue: SimQueue(targetId: target),
    queueStock: stock,
    setupValue: changeover == Duration.zero
        ? null
        : changeover.inSeconds.toDouble(),
    setupUnit: TaktUnit.seconds,
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

    test('a buffer costs nothing, because the run will not spend it', () {
      // **`workingTime` is work content and nothing else** — no changeover and
      // no stock, whatever `elapsed` beside it counts (§7.9). It is not a floor
      // under a run and nothing divides by it today; what it is, is the one
      // figure here that answers "how much work is in this order".
      //
      // Friday 06:00 and two hours of work. There is no buffer node to put
      // either side of it any more — a queue belongs to the step now — and the
      // point stands unchanged: what an order waits is not in this figure.
      final result = theoreticalLeadTime(
        nodes: [step(1, 'CLAD04')],
        workcenters: {'CLAD04': workcenter('CLAD04')},
        part: part({'CLAD04': const Duration(hours: 2)}),
        batchSize: 1,
        from: DateTime(2026, 8, 7, 6),
      );

      expect(result!.end, DateTime(2026, 8, 7, 8));
      expect(result.workingTime, const Duration(hours: 2));
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
      final nodes = [step(0, 'CLAD04'), step(2, 'TTAT')];
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

  group('the two walks invert each other (§7.9)', () {
    /// Forward from [from] with this plant, or null if it cannot be walked.
    DateTime? endOf(List<SimStep> nodes, DateTime from) => theoreticalLeadTime(
      nodes: nodes,
      workcenters: {'A': workcenter('A'), 'B': workcenter('B')},
      part: part({
        'A': const Duration(hours: 5),
        'B': const Duration(hours: 5),
      }),
      batchSize: 1,
      from: from,
    )?.end;

    DateTime? startFor(List<SimStep> nodes, DateTime need) => coldStartDate(
      nodes: nodes,
      workcenters: {'A': workcenter('A'), 'B': workcenter('B')},
      part: part({
        'A': const Duration(hours: 5),
        'B': const Duration(hours: 5),
      }),
      batchSize: 1,
      needDate: need,
    );

    // Tuesday 11 August 2026, 11:00 — mid-shift, so neither walk starts on a
    // boundary that could hide a rounding difference.
    final need = DateTime(2026, 8, 11, 11);

    test('a straight flow round-trips to the need date', () {
      final nodes = [step(0, 'A'), step(1, 'B')];
      final start = startFor(nodes, need);

      expect(start, isNotNull);
      expect(endOf(nodes, start!), need);
    });

    test('a flow that revisits a station round-trips too', () {
      // **The case the two walks used to disagree on.** `A → B → A` shares one
      // floor space at A, so the two days of stock there are charged once — and
      // the backward walk has to charge them at the step the forward walk does,
      // which is the *first* to reach A rather than the first it meets going
      // back. Charged at opposite ends, a wall-clock jump lands the following
      // work on a different side of the weekend and the walks come apart.
      final nodes = [
        step(0, 'A', stock: const Duration(days: 2)),
        step(1, 'B'),
        step(2, 'A', stock: const Duration(days: 2)),
      ];

      final start = startFor(nodes, need);

      expect(start, isNotNull);
      expect(
        endOf(nodes, start!),
        need,
        reason: 'the first order start date and its stated lead time have to '
            'add up to its need date, which is what row 1 of the plan shows',
      );
    });

    test('it holds wherever in the week the need date falls', () {
      // A weekend is what separates a wall-clock jump from an open-time one, so
      // the invariant is worth checking on every weekday rather than the one
      // that happened to be picked.
      final nodes = [
        step(0, 'A', stock: const Duration(days: 2)),
        step(1, 'B'),
        step(2, 'A', stock: const Duration(days: 2)),
      ];

      for (var day = 10; day <= 14; day++) {
        final target = DateTime(2026, 8, day, 11);
        final start = startFor(nodes, target);

        expect(start, isNotNull, reason: 'August $day');
        expect(endOf(nodes, start!), target, reason: 'August $day');
      }
    });

    test('the stock is charged once, not once per visit', () {
      // Two steps on one station, and the plant has one pile in front of it —
      // the dedup both walks share (§7.3). Two days of it, so charging it twice
      // would move the start date by two more.
      final once = startFor([
        step(0, 'A', stock: const Duration(days: 2)),
        step(1, 'A', stock: const Duration(days: 2)),
      ], need);
      final bare = startFor([step(0, 'A'), step(1, 'A')], need);

      expect(once, isNotNull);
      expect(bare, isNotNull);
      expect(bare!.difference(once!), const Duration(days: 2));
    });
  });
}
