import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// The scale target, run rather than assumed (DESIGN.md §14).
///
/// One plant, ~10 steps, ~2000 orders over a multi-year horizon.
///
/// **This cannot verify §14's "well under a second".** `flutter test` runs
/// unoptimised Dart with assertions on, several times slower than the shipped
/// build; the figure quoted in §16.9 was measured separately. What these tests
/// catch is an *algorithmic* regression — a run going from seconds to minutes,
/// or cost starting to scale with the horizon instead of with the events in
/// it, which is the property §7.1 rests on.
void main() {
  final abc = ShiftPatternSpec(
    name: 'ABC',
    cycleType: ShiftCycleType.fixedWeekly,
    workingWeekdays: ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5]),
    shifts: const [
      ShiftWindow(
        label: 'A',
        position: 0,
        startMinute: 6 * 60,
        endMinute: 14 * 60,
        breakSeconds: 30 * 60,
      ),
      ShiftWindow(
        label: 'B',
        position: 1,
        startMinute: 14 * 60,
        endMinute: 22 * 60,
        breakSeconds: 30 * 60,
      ),
    ],
  );

  SimWorkcenter workcenter(String id) {
    final schedule = WorkcenterScheduleSpec([
      WorkcenterSchedulePeriodSpec(
        startDate: DateTime(2020),
        endDate: DateTime(2035),
        operatorsPerShift: const [1, 1],
        availability: 0.9,
        rework: 0.02,
      ),
    ]);
    return SimWorkcenter(
      id: id,
      name: id,
      calendar: WorkingCalendar.scheduled(pattern: abc, staffing: schedule),
      schedule: schedule,
    );
  }

  test('2000 orders through 10 steps runs well under a second', () {
    const stepCount = 10;
    const orderCount = 2000;

    final workcenters = {
      for (var i = 0; i < stepCount; i++) 'W$i': workcenter('W$i'),
    };

    final nodes = <SimStep>[
      for (var i = 0; i < stepCount; i++)
        SimStep(
          id: 'node-$i',
          position: i,
          title: 'W$i',
          candidates: ['W$i'],
          demandKey: 'W$i',
          queue: SimQueue(targetId: 'W$i'),
          setupValue: 1200,
          setupUnit: TaktUnit.seconds,
        ),
    ];

    // Five parts round-robined, so changeover is incurred often and the
    // changeover branch is exercised at scale rather than skipped.
    final parts = {
      for (var p = 0; p < 5; p++)
        'p$p': SimPart(
          id: 'p$p',
          partNumber: 'PN$p',
          processTimes: {
            for (var i = 0; i < stepCount; i++)
              'W$i': Duration(minutes: 20 + (p * 7 + i * 3) % 40),
          },
        ),
    };

    final start = DateTime(2026);
    final orders = [
      for (var i = 0; i < orderCount; i++)
        SimOrder(
          id: 'o$i',
          sequence: i,
          partId: 'p${i % 5}',
          batchSize: 1 + i % 3,
          needDate: start.add(Duration(hours: 6 * i)),
        ),
    ];

    final stopwatch = Stopwatch()..start();
    final result = runSimulation(
      studies: [
        SimStudy(
          id: 'study-1',
          name: 'Current state',
          nodes: nodes,
          parts: parts,
          orders: orders,
          releaseInterval: const Duration(hours: 5),
          releaseCalendarId: 'W0',
        ),
      ],
      workcenters: workcenters,
      start: start,
    );
    stopwatch.stop();

    expect(result.completed, isTrue, reason: 'the guard should not have fired');
    expect(result.undelivered, isEmpty);
    expect(result.steps, hasLength(orderCount * stepCount));

    // Generous on purpose: an unoptimised test VM on an unknown machine. The
    // regression worth catching is an order of magnitude, not a second.
    expect(
      stopwatch.elapsed,
      lessThan(const Duration(seconds: 20)),
      reason: 'took ${stopwatch.elapsedMilliseconds} ms',
    );
  });

  test('a four-times-longer horizon costs events, not time', () {
    // §7.1: cost scales with events, not with horizon length. The same demand
    // spread over four times the calendar should not cost four times as much.
    SimRunResult runWithSpacing(Duration gap) => runSimulation(
      studies: [
        SimStudy(
          id: 'study-1',
          name: 'Current state',
          nodes: [
            SimStep(
              id: 'node-0',
              position: 0,
              title: 'W0',
              candidates: const ['W0'],
              demandKey: 'W0',
              queue: SimQueue(targetId: 'W0'),
            ),
          ],
          parts: {
            'p1': SimPart(
              id: 'p1',
              partNumber: 'PN1',
              processTimes: const {'W0': Duration(minutes: 30)},
            ),
          },
          orders: [
            for (var i = 0; i < 300; i++)
              SimOrder(
                id: 'o$i',
                sequence: i,
                partId: 'p1',
                needDate: DateTime(2026).add(gap * (i + 40)),
              ),
          ],
          releaseInterval: gap,
          releaseCalendarId: 'W0',
        ),
      ],
      workcenters: {'W0': workcenter('W0')},
      start: DateTime(2026),
    );

    final tight = Stopwatch()..start();
    final a = runWithSpacing(const Duration(hours: 4));
    tight.stop();

    final loose = Stopwatch()..start();
    final b = runWithSpacing(const Duration(hours: 16));
    loose.stop();

    expect(a.completed, isTrue);
    expect(b.completed, isTrue);
    expect(a.steps, hasLength(b.steps.length));
    // Same event count, so the wider horizon must not cost meaningfully more.
    expect(
      loose.elapsedMicroseconds,
      lessThan(tight.elapsedMicroseconds * 6 + 200000),
      reason:
          'tight ${tight.elapsedMilliseconds} ms, '
          'loose ${loose.elapsedMilliseconds} ms',
    );
  });
}
