import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a run reports (DESIGN.md §8), over runs small enough to check by hand.
void main() {
  /// Open round the clock, so a metric about queueing is about queueing.
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

  SimWorkcenter workcenter(String id) {
    final schedule = WorkcenterScheduleSpec([
      WorkcenterSchedulePeriodSpec(
        startDate: DateTime(2020),
        endDate: DateTime(2030),
        operatorsPerShift: const [1],
      ),
    ]);
    return SimWorkcenter(
      id: id,
      name: id,
      calendar: WorkingCalendar.scheduled(pattern: always, staffing: schedule),
      schedule: schedule,
    );
  }

  SimStep step(int position, String target, {Duration? changeover}) => SimStep(
    id: 'node-$position',
    position: position,
    title: target,
    candidates: [target],
    demandKey: target,
    changeover: changeover ?? Duration.zero,
  );

  final aug1 = DateTime(2026, 8, 1);

  ({List<SimStudy> studies, Map<String, SimWorkcenter> workcenters}) scenario({
    required List<SimNode> nodes,
    required Map<String, SimPart> parts,
    required List<SimOrder> orders,
    required Map<String, SimWorkcenter> workcenters,
    Duration release = const Duration(hours: 10),
  }) => (
    studies: [
      SimStudy(
        id: 'study-1',
        name: 'Current state',
        nodes: nodes,
        parts: parts,
        orders: orders,
        releaseInterval: release,
      ),
    ],
    workcenters: workcenters,
  );

  group('delivery', () {
    test('float, OTD and the late count', () {
      // Two orders, one hour of work each, released ten hours apart. The first
      // is wanted well after it finishes; the second is wanted before it does.
      final setup = scenario(
        nodes: [step(0, 'W')],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {'W': Duration(hours: 1)},
          ),
        },
        orders: [
          SimOrder(
            id: 'o0',
            sequence: 0,
            partId: 'p1',
            needDate: aug1.add(const Duration(hours: 5)),
          ),
          SimOrder(
            id: 'o1',
            sequence: 1,
            partId: 'p1',
            needDate: aug1.add(const Duration(hours: 5)),
          ),
        ],
        workcenters: {'W': workcenter('W')},
      );

      final result = runSimulation(
        studies: setup.studies,
        workcenters: setup.workcenters,
        start: aug1,
      );
      final metrics = computeRunMetrics(
        result: result,
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      // o0 finishes at +1 h against a +5 h need date: four hours early.
      // o1 releases at +10 h and finishes at +11 h: six hours late.
      expect(metrics.orders, 2);
      expect(metrics.delivered, 2);
      expect(metrics.onTime, 1);
      expect(metrics.late, 1);
      expect(metrics.onTimeDelivery, 0.5);
      // Float is slack, so early is positive: (+4 h − 6 h) ÷ 2 = −1 h. The two
      // orders are unchanged; only which way the sign points is.
      expect(metrics.averageFloat, const Duration(hours: -1));
    });

    test('an order that never came out is not on time', () {
      final shut = WorkcenterScheduleSpec([
        WorkcenterSchedulePeriodSpec(
          startDate: DateTime(2020),
          endDate: DateTime(2030),
          operatorsPerShift: const [0],
        ),
      ]);
      final setup = scenario(
        nodes: [step(0, 'SHUT')],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {'SHUT': Duration(hours: 1)},
          ),
        },
        orders: [
          SimOrder(
            id: 'o0',
            sequence: 0,
            partId: 'p1',
            needDate: aug1.add(const Duration(days: 400)),
          ),
        ],
        workcenters: {
          'SHUT': SimWorkcenter(
            id: 'SHUT',
            name: 'SHUT',
            calendar: WorkingCalendar.scheduled(
              pattern: always,
              staffing: shut,
            ),
            schedule: shut,
          ),
        },
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      // Its need date is far away, so a naive "delivered late?" test would
      // call it on time. OTD counts over every order, not the delivered ones.
      expect(metrics.delivered, 0);
      expect(metrics.onTime, 0);
      expect(metrics.onTimeDelivery, 0);
      expect(metrics.averageFloat, isNull);
    });
  });

  group('lead time', () {
    test('efficiency is 1.0 when nothing queues', () {
      final setup = scenario(
        nodes: [step(0, 'W'), step(1, 'X')],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {
              'W': Duration(hours: 1),
              'X': Duration(hours: 2),
            },
          ),
        },
        orders: [
          SimOrder(
            id: 'o0',
            sequence: 0,
            partId: 'p1',
            needDate: aug1.add(const Duration(hours: 10)),
          ),
        ],
        workcenters: {'W': workcenter('W'), 'X': workcenter('X')},
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      // One order alone in an empty plant waits for nothing, so the run and
      // the queue-free walk agree exactly.
      expect(metrics.averageLeadTime, const Duration(hours: 3));
      expect(metrics.theoreticalLeadTime, const Duration(hours: 3));
      expect(metrics.leadTimeEfficiency, closeTo(1.0, 0.0001));
    });

    test('queueing is exactly the excess over 1.0', () {
      // Three orders released an hour apart onto a station that takes four
      // hours each: the second and third wait.
      final setup = scenario(
        nodes: [step(0, 'W')],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {'W': Duration(hours: 4)},
          ),
        },
        orders: [
          for (var i = 0; i < 3; i++)
            SimOrder(
              id: 'o$i',
              sequence: i,
              partId: 'p1',
              needDate: aug1.add(const Duration(days: 2)),
            ),
        ],
        workcenters: {'W': workcenter('W')},
        release: const Duration(hours: 1),
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      // Lead times 4 h, 7 h, 10 h — average 7 — against a theoretical 4.
      expect(metrics.averageLeadTime, const Duration(hours: 7));
      expect(metrics.theoreticalLeadTime, const Duration(hours: 4));
      expect(metrics.leadTimeEfficiency, closeTo(1.75, 0.0001));
    });
  });

  group('per part (§8)', () {
    test('each part number is averaged on its own', () {
      final setup = scenario(
        nodes: [step(0, 'W')],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {'W': Duration(hours: 1)},
          ),
          'p2': SimPart(
            id: 'p2',
            partNumber: 'PN2',
            processTimes: const {'W': Duration(hours: 3)},
          ),
        },
        orders: [
          SimOrder(
            id: 'o0',
            sequence: 0,
            partId: 'p1',
            needDate: aug1.add(const Duration(days: 2)),
          ),
          SimOrder(
            id: 'o1',
            sequence: 1,
            partId: 'p2',
            needDate: aug1.add(const Duration(days: 2)),
          ),
        ],
        workcenters: {'W': workcenter('W')},
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      expect(metrics.parts.map((p) => p.partNumber), ['PN1', 'PN2']);
      expect(metrics.parts.first.averageLeadTime, const Duration(hours: 1));
      expect(metrics.parts.last.averageLeadTime, const Duration(hours: 3));
      expect(metrics.parts.every((p) => p.orders == 1), isTrue);
    });
  });

  group('the bottleneck rankings (§8.1)', () {
    test('the headline names the station orders wait at longest', () {
      // W is slow and orders pile up behind it; X is quick and never queues.
      final setup = scenario(
        nodes: [step(0, 'W'), step(1, 'X')],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {
              'W': Duration(hours: 5),
              'X': Duration(minutes: 10),
            },
          ),
        },
        orders: [
          for (var i = 0; i < 4; i++)
            SimOrder(
              id: 'o$i',
              sequence: i,
              partId: 'p1',
              needDate: aug1.add(const Duration(days: 3)),
            ),
        ],
        workcenters: {'W': workcenter('W'), 'X': workcenter('X')},
        release: const Duration(hours: 1),
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      expect(metrics.bottleneck!.name, 'W');
      expect(metrics.bottleneck!.queueTime, greaterThan(Duration.zero));
      expect(
        metrics.workcenters.firstWhere((w) => w.name == 'X').queueTime,
        Duration.zero,
      );

      // The second ranking agrees here, but is computed separately because
      // §8.1 wants the disagreement visible when it happens.
      expect(metrics.byContribution.first.name, 'W');
      expect(metrics.shareOfFlow(metrics.bottleneck!), greaterThan(0.9));
    });

    test('visits and changeovers are counted per station', () {
      final setup = scenario(
        nodes: [step(0, 'W', changeover: const Duration(minutes: 30))],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {'W': Duration(hours: 1)},
          ),
          'p2': SimPart(
            id: 'p2',
            partNumber: 'PN2',
            processTimes: const {'W': Duration(hours: 1)},
          ),
        },
        orders: [
          for (var i = 0; i < 4; i++)
            SimOrder(
              id: 'o$i',
              sequence: i,
              partId: i.isEven ? 'p1' : 'p2',
              needDate: aug1.add(const Duration(days: 3)),
            ),
        ],
        workcenters: {'W': workcenter('W')},
        release: const Duration(hours: 2),
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      final w = metrics.workcenters.single;
      expect(w.visits, 4);
      // Alternating parts: every order after the first pays a setup.
      expect(w.changeovers, 3);
      expect(w.utilisation, isNotNull);
    });

    test('a run that touched nothing has no bottleneck to name', () {
      final setup = scenario(
        nodes: [step(0, 'W')],
        parts: const {},
        orders: const [],
        workcenters: {'W': workcenter('W')},
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      expect(metrics.bottleneck, isNull);
      expect(metrics.orders, 0);
      expect(metrics.onTimeDelivery, 0);
      expect(metrics.leadTimeEfficiency, isNull);
    });
  });

  test('empty slots are carried through to the report (§7.2)', () {
    final setup = scenario(
      nodes: [step(0, 'W')],
      parts: {
        'p1': SimPart(
          id: 'p1',
          partNumber: 'PN1',
          processTimes: const {'W': Duration(hours: 1)},
        ),
      },
      orders: [
        SimOrder(
          id: 'o0',
          sequence: 0,
          partId: 'p1',
          needDate: aug1.add(const Duration(days: 2)),
          materialDate: aug1.add(const Duration(hours: 25)),
        ),
      ],
      workcenters: {'W': workcenter('W')},
    );

    final metrics = computeRunMetrics(
      result: runSimulation(
        studies: setup.studies,
        workcenters: setup.workcenters,
        start: aug1,
      ),
      studies: setup.studies,
      workcenters: setup.workcenters,
    );

    // Slots at 0, 10 and 20 all go out before the material lands at 25.
    expect(metrics.emptySlots, 3);
  });
}
