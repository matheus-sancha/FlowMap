import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// The discrete-event engine (DESIGN.md §7).
void main() {
  /// Open round the clock, every day. Removes the calendar from the picture so
  /// a test about dispatch is about dispatch.
  final always = ShiftPatternSpec(
    name: 'Continuous',
    cycleType: ShiftCycleType.rotating,
    workingWeekdays: ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5, 6, 7]),
    shifts: const [
      ShiftWindow(
        label: 'All day',
        position: 0,
        startMinute: 0,
        endMinute: 24 * 60,
        breakSeconds: 0,
      ),
    ],
  );

  /// Ten hours a day, weekdays only — for the tests that are about the clock.
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
    ShiftPatternSpec? pattern,
    double availability = 1,
    double rework = 0,
  }) {
    final schedule = WorkcenterScheduleSpec([
      WorkcenterSchedulePeriodSpec(
        startDate: DateTime(2020),
        endDate: DateTime(2030),
        operatorsPerShift: const [1],
        availability: availability,
        rework: rework,
      ),
    ]);
    return SimWorkcenter(
      id: id,
      name: id,
      calendar: WorkingCalendar.scheduled(
        pattern: pattern ?? always,
        staffing: schedule,
      ),
      schedule: schedule,
    );
  }

  SimStep step(
    int position,
    List<String> candidates, {
    Duration changeover = Duration.zero,
    String? demandKey,
  }) => SimStep(
    id: 'node-$position',
    position: position,
    title: candidates.first,
    candidates: candidates,
    demandKey: demandKey ?? candidates.first,
    changeover: changeover,
  );

  SimOrder order(
    int sequence,
    String partId, {
    int batch = 1,
    int needDay = 30,
    DateTime? material,
  }) => SimOrder(
    id: 'o$sequence',
    sequence: sequence,
    partId: partId,
    batchSize: batch,
    needDate: DateTime(2026, 8, needDay),
    materialDate: material,
  );

  SimStudy study({
    required List<SimNode> nodes,
    required Map<String, SimPart> parts,
    required List<SimOrder> orders,
    Duration release = const Duration(hours: 10),
    String? releaseCalendarId,
    int priority = 100,
    int? wipCap,
    String id = 'study-1',
  }) => SimStudy(
    id: id,
    name: id,
    nodes: nodes,
    parts: parts,
    orders: orders,
    releaseInterval: release,
    releaseCalendarId: releaseCalendarId,
    priority: priority,
    wipCap: wipCap,
  );

  SimPart part(String id, Map<String, Duration> times) =>
      SimPart(id: id, partNumber: id, processTimes: times);

  final aug1 = DateTime(2026, 8, 1);

  group('a single station', () {
    test('runs the sequence in order, one order at a time', () {
      final result = runSimulation(
        studies: [
          study(
            nodes: [step(0, ['W'])],
            parts: {'p1': part('p1', {'W': const Duration(hours: 2)})},
            orders: [order(0, 'p1'), order(1, 'p1'), order(2, 'p1')],
          ),
        ],
        workcenters: {'W': workcenter('W')},
        start: aug1,
      );

      expect(result.completed, isTrue);
      expect(result.steps, hasLength(3));
      // A workcenter is a single server (§7.5): the three runs do not overlap.
      final ends = result.steps.map((s) => s.processEnd).toList();
      final starts = result.steps.map((s) => s.processStart).toList();
      expect(starts[1].isBefore(ends[0]), isFalse);
      expect(starts[2].isBefore(ends[1]), isFalse);
      expect(result.orders.every((o) => o.delivered != null), isTrue);
    });

    test('releases on takt slots and no faster', () {
      // Work takes an hour; slots are ten hours apart. The station idles.
      final result = runSimulation(
        studies: [
          study(
            nodes: [step(0, ['W'])],
            parts: {'p1': part('p1', {'W': const Duration(hours: 1)})},
            orders: [order(0, 'p1'), order(1, 'p1'), order(2, 'p1')],
            release: const Duration(hours: 10),
          ),
        ],
        workcenters: {'W': workcenter('W')},
        start: aug1,
      );

      final starts = result.steps.map((s) => s.processStart).toList()..sort();
      expect(starts[0], aug1);
      expect(starts[1], aug1.add(const Duration(hours: 10)));
      expect(starts[2], aug1.add(const Duration(hours: 20)));
    });

    test('batch, rework and availability all reach the occupancy', () {
      final result = runSimulation(
        studies: [
          study(
            nodes: [step(0, ['W'])],
            parts: {'p1': part('p1', {'W': const Duration(hours: 1)})},
            orders: [order(0, 'p1', batch: 4)],
          ),
        ],
        workcenters: {'W': workcenter('W', availability: 0.5, rework: 0.25)},
        start: aug1,
      );

      // 1 h × 4 × 1.25 ÷ 0.5 = 10 h, and the station is open round the clock.
      expect(result.steps.single.occupied, const Duration(hours: 10));
    });

    test('busy time over open time is utilisation (§8.3)', () {
      final result = runSimulation(
        studies: [
          study(
            nodes: [step(0, ['W'])],
            parts: {'p1': part('p1', {'W': const Duration(hours: 1)})},
            orders: [order(0, 'p1'), order(1, 'p1')],
            release: const Duration(hours: 4),
          ),
        ],
        workcenters: {'W': workcenter('W')},
        start: aug1,
      );

      // Two one-hour jobs over a run that ends when the second finishes: five
      // hours of clock, two of work.
      expect(result.busyByWorkcenter['W'], const Duration(hours: 2));
      expect(result.openByWorkcenter['W'], const Duration(hours: 5));
      expect(result.utilisation['W'], closeTo(0.4, 0.0001));
    });
  });

  group('changeover (§7.6)', () {
    SimRunResult runSequence(List<String> partIds) => runSimulation(
      studies: [
        study(
          nodes: [
            step(0, ['W'], changeover: const Duration(hours: 1)),
          ],
          parts: {
            'p1': part('p1', {'W': const Duration(hours: 1)}),
            'p2': part('p2', {'W': const Duration(hours: 1)}),
          },
          orders: [
            for (var i = 0; i < partIds.length; i++) order(i, partIds[i]),
          ],
          release: const Duration(hours: 5),
        ),
      ],
      workcenters: {'W': workcenter('W')},
      start: aug1,
    );

    test('the first order of a run never pays a setup', () {
      // Cold start: there is no previous order, so no *different* part number.
      final result = runSequence(['p1']);
      expect(result.steps.single.changeoverIncurred, isFalse);
      expect(result.steps.single.occupied, const Duration(hours: 1));
    });

    test('like with like is genuinely cheaper', () {
      final same = runSequence(['p1', 'p1', 'p1']);
      final mixed = runSequence(['p1', 'p2', 'p1']);

      expect(same.steps.where((s) => s.changeoverIncurred), isEmpty);
      expect(mixed.steps.where((s) => s.changeoverIncurred), hasLength(2));
      // Which is what makes a smooth sequence worth chasing (§6.3).
      expect(
        mixed.busyByWorkcenter['W']! - same.busyByWorkcenter['W']!,
        const Duration(hours: 2),
      );
    });
  });

  group('release (§7.2)', () {
    test('a slot with no material goes out empty, and the head waits', () {
      final result = runSimulation(
        studies: [
          study(
            nodes: [step(0, ['W'])],
            parts: {'p1': part('p1', {'W': const Duration(hours: 1)})},
            orders: [
              order(0, 'p1', material: aug1.add(const Duration(hours: 15))),
              order(1, 'p1'),
            ],
            release: const Duration(hours: 10),
          ),
        ],
        workcenters: {'W': workcenter('W')},
        start: aug1,
      );

      // Material lands at hour 15, so the slots at 0 and 10 both go out empty
      // and the head waits for the one at 20. The sequence is not reordered to
      // fill them — that is the whole point of §7.2.
      expect(result.emptySlots.map((s) => s.at), [
        aug1,
        aug1.add(const Duration(hours: 10)),
      ]);
      expect(
        result.emptySlots.every(
          (s) => s.reason == EmptySlotReason.awaitingMaterial,
        ),
        isTrue,
      );
      expect(result.orders.first.released, aug1.add(const Duration(hours: 20)));
    });

    test('a CONWIP cap holds orders out until one completes (§7.3)', () {
      final capped = runSimulation(
        studies: [
          study(
            nodes: [step(0, ['W'])],
            parts: {'p1': part('p1', {'W': const Duration(hours: 25)})},
            orders: [order(0, 'p1'), order(1, 'p1'), order(2, 'p1')],
            release: const Duration(hours: 5),
            wipCap: 1,
          ),
        ],
        workcenters: {'W': workcenter('W')},
        start: aug1,
      );

      expect(
        capped.emptySlots.where((s) => s.reason == EmptySlotReason.wipCap),
        isNotEmpty,
      );
      // Nothing is lost — a release just waits for a completion.
      expect(capped.orders.every((o) => o.delivered != null), isTrue);
    });

    test('slots stop once the sequence is exhausted', () {
      final result = runSimulation(
        studies: [
          study(
            nodes: [step(0, ['W'])],
            parts: {'p1': part('p1', {'W': const Duration(hours: 1)})},
            orders: [order(0, 'p1')],
          ),
        ],
        workcenters: {'W': workcenter('W')},
        start: aug1,
      );

      // An idle plant does not accumulate empty slots for orders that do not
      // exist.
      expect(result.emptySlots, isEmpty);
    });
  });

  group('dispatch (§7.4)', () {
    /// Two orders queued behind a long first one, so the rule decides which of
    /// the two runs second.
    SimRunResult contend(DispatchRule rule) => runSimulation(
      dispatch: rule,
      studies: [
        study(
          nodes: [step(0, ['W'])],
          parts: {
            'slow': part('slow', {'W': const Duration(hours: 8)}),
            'quick': part('quick', {'W': const Duration(hours: 1)}),
            'blocker': part('blocker', {'W': const Duration(hours: 10)}),
          },
          orders: [
            order(0, 'blocker', needDay: 30),
            // Arrives second, wanted first.
            order(1, 'slow', needDay: 20),
            order(2, 'quick', needDay: 25),
          ],
          release: const Duration(hours: 1),
        ),
      ],
      workcenters: {'W': workcenter('W')},
      start: aug1,
    );

    String secondPart(SimRunResult result) {
      final ordered = [...result.steps]
        ..sort((a, b) => a.processStart.compareTo(b.processStart));
      return ordered[1].orderId;
    }

    test('FIFO takes them in arrival order', () {
      expect(secondPart(contend(DispatchRule.fifo)), 'o1');
    });

    test('EDD takes the one wanted soonest', () {
      expect(secondPart(contend(DispatchRule.earliestDueDate)), 'o1');
    });

    test('SPT takes the shortest job', () {
      expect(secondPart(contend(DispatchRule.shortestProcessing)), 'o2');
    });
  });

  group('pools (§3.1)', () {
    test('two members run two orders at once', () {
      final result = runSimulation(
        studies: [
          study(
            nodes: [
              step(0, ['LAT01', 'LAT02'], demandKey: 'pool'),
            ],
            parts: {'p1': part('p1', {'pool': const Duration(hours: 4)})},
            orders: [order(0, 'p1'), order(1, 'p1')],
            release: const Duration(hours: 1),
          ),
        ],
        workcenters: {
          'LAT01': workcenter('LAT01'),
          'LAT02': workcenter('LAT02'),
        },
        start: aug1,
      );

      // Real parallel capacity comes from a pool, not from operators (§7.5).
      expect(
        result.steps.map((s) => s.workcenterId).toSet(),
        {'LAT01', 'LAT02'},
      );
      expect(result.end, aug1.add(const Duration(hours: 5)));
    });

    test('a pool step reads the pool\'s process time, not a member\'s', () {
      final result = runSimulation(
        studies: [
          study(
            nodes: [
              step(0, ['LAT01', 'LAT02'], demandKey: 'pool'),
            ],
            parts: {
              'p1': part('p1', {
                'pool': const Duration(hours: 3),
                'LAT01': const Duration(hours: 99),
              }),
            },
            orders: [order(0, 'p1')],
          ),
        ],
        workcenters: {
          'LAT01': workcenter('LAT01'),
          'LAT02': workcenter('LAT02'),
        },
        start: aug1,
      );

      expect(result.steps.single.occupied, const Duration(hours: 3));
    });
  });

  group('contention between studies (§7.7)', () {
    test('one workcenter, two studies, and the queue is shared', () {
      final shared = {'W': workcenter('W')};
      final nodes = [step(0, ['W'])];
      final parts = {'p1': part('p1', {'W': const Duration(hours: 6)})};

      final result = runSimulation(
        studies: [
          study(
            id: 'A',
            nodes: nodes,
            parts: parts,
            orders: [order(0, 'p1')],
            priority: 1,
          ),
          study(
            id: 'B',
            nodes: nodes,
            parts: parts,
            orders: [order(0, 'p1')],
            priority: 2,
          ),
        ],
        workcenters: shared,
        start: aug1,
      );

      // Line A's order genuinely delays line B's — which is the reason a run
      // is a plant-level object rather than a study-level one.
      final byStudy = {
        for (final row in result.steps) row.studyId: row.processStart,
      };
      expect(byStudy['A'], aug1);
      expect(byStudy['B'], aug1.add(const Duration(hours: 6)));
    });

    test('study priority breaks the tie, reproducibly', () {
      SimRunResult runWith(int priorityOfB) => runSimulation(
        studies: [
          study(
            id: 'A',
            nodes: [step(0, ['W'])],
            parts: {'p1': part('p1', {'W': const Duration(hours: 3)})},
            orders: [order(0, 'p1')],
            priority: 5,
          ),
          study(
            id: 'B',
            nodes: [step(0, ['W'])],
            parts: {'p1': part('p1', {'W': const Duration(hours: 3)})},
            orders: [order(0, 'p1')],
            priority: priorityOfB,
          ),
        ],
        workcenters: {'W': workcenter('W')},
        start: aug1,
      );

      String firstStudy(SimRunResult r) {
        final ordered = [...r.steps]
          ..sort((a, b) => a.processStart.compareTo(b.processStart));
        return ordered.first.studyId;
      }

      expect(firstStudy(runWith(9)), 'A', reason: 'lower priority runs first');
      expect(firstStudy(runWith(1)), 'B');
    });
  });

  group('the calendar', () {
    test('work spills across a closed night onto the next shift', () {
      final result = runSimulation(
        studies: [
          study(
            nodes: [step(0, ['W'])],
            parts: {'p1': part('p1', {'W': const Duration(hours: 15)})},
            orders: [order(0, 'p1')],
          ),
        ],
        workcenters: {'W': workcenter('W', pattern: weekdayTen)},
        // Wednesday at the start of the shift.
        start: DateTime(2026, 8, 5, 6),
      );

      // Ten hours Wednesday, five Thursday.
      expect(result.steps.single.processEnd, DateTime(2026, 8, 6, 11));
    });

    test('a station shut for the whole run delivers nothing, and says so', () {
      final shut = WorkcenterScheduleSpec([
        WorkcenterSchedulePeriodSpec(
          startDate: DateTime(2020),
          endDate: DateTime(2030),
          operatorsPerShift: const [0],
        ),
      ]);

      final result = runSimulation(
        studies: [
          study(
            nodes: [step(0, ['SHUT'])],
            parts: {'p1': part('p1', {'SHUT': const Duration(hours: 1)})},
            orders: [order(0, 'p1')],
          ),
        ],
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
        start: aug1,
      );

      expect(result.steps, isEmpty);
      expect(result.undelivered, hasLength(1));
    });
  });

  group('the horizon guard (§7.8)', () {
    test('demand beyond capacity aborts rather than looping', () {
      // A slot every hour against a station that takes fifty hours an order:
      // the queue can only grow.
      final result = runSimulation(
        studies: [
          study(
            nodes: [step(0, ['W'])],
            parts: {'p1': part('p1', {'W': const Duration(hours: 50)})},
            orders: [
              for (var i = 0; i < 40; i++) order(i, 'p1', needDay: 2 + i ~/ 4),
            ],
            release: const Duration(hours: 1),
          ),
        ],
        workcenters: {'W': workcenter('W')},
        start: aug1,
      );

      expect(result.abort, SimAbortReason.horizonExceeded);
      expect(result.undelivered, isNotEmpty);
      expect(result.end.isAfter(result.guard), isFalse);
    });

    test('nothing to run is said plainly', () {
      final result = runSimulation(
        studies: [
          study(
            nodes: [step(0, ['W'])],
            parts: {'p1': part('p1', {'W': const Duration(hours: 1)})},
            orders: const [],
          ),
        ],
        workcenters: {'W': workcenter('W')},
      );

      expect(result.abort, SimAbortReason.nothingToRun);
    });
  });

  group('determinism (§4.4)', () {
    test('the same inputs give the same run, every time', () {
      SimRunResult once() => runSimulation(
        studies: [
          study(
            id: 'A',
            nodes: [
              step(0, ['LAT01', 'LAT02'], demandKey: 'pool'),
              SimBuffer(
                id: 'buffer',
                position: 1,
                wait: const Duration(hours: 3),
                usesWorkingTime: false,
              ),
              step(2, ['W'], changeover: const Duration(minutes: 30)),
            ],
            parts: {
              'p1': part('p1', {
                'pool': const Duration(hours: 2),
                'W': const Duration(hours: 1),
              }),
              'p2': part('p2', {
                'pool': const Duration(hours: 1),
                'W': const Duration(hours: 3),
              }),
            },
            orders: [
              order(0, 'p1'),
              order(1, 'p2'),
              order(2, 'p1'),
              order(3, 'p2'),
            ],
            release: const Duration(hours: 2),
          ),
        ],
        workcenters: {
          'LAT01': workcenter('LAT01'),
          'LAT02': workcenter('LAT02'),
          'W': workcenter('W', pattern: weekdayTen),
        },
        start: aug1,
      );

      final a = once();
      final b = once();

      // Two runs of the same study must not disagree — the output is a
      // headcount decision.
      expect(
        a.steps.map((s) => '${s.orderId}@${s.workcenterId}:${s.processStart}'),
        b.steps.map((s) => '${s.orderId}@${s.workcenterId}:${s.processStart}'),
      );
      expect(a.end, b.end);
    });
  });

  test('a buffer delays without occupying anything', () {
    final result = runSimulation(
      studies: [
        study(
          nodes: [
            step(0, ['W']),
            SimBuffer(
              id: 'cool',
              position: 1,
              wait: const Duration(hours: 12),
              usesWorkingTime: false,
            ),
            step(2, ['X']),
          ],
          parts: {
            'p1': part('p1', {
              'W': const Duration(hours: 1),
              'X': const Duration(hours: 1),
            }),
          },
          orders: [order(0, 'p1')],
        ),
      ],
      workcenters: {'W': workcenter('W'), 'X': workcenter('X')},
      start: aug1,
    );

    // An hour of work, twelve of cooling, an hour of work.
    expect(result.orders.single.delivered, aug1.add(const Duration(hours: 14)));
    expect(result.busyByWorkcenter['W'], const Duration(hours: 1));
    expect(result.busyByWorkcenter['X'], const Duration(hours: 1));
  });
}
