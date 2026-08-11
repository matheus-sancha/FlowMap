import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/flow/application/flow_view.dart';
import 'package:flowmap/src/features/schedules/application/takt_schedule.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// Part equivalence, and the two data sources that read the demand table
/// (DESIGN.md §6.2, §5.4).
///
/// The worked reference in §6.1 is the anchor: ABC on three shifts at 74 %, a
/// 3-day takt, a part at 55 h with 3.7 % rework.
void main() {
  final now = DateTime(2026, 8, 1);
  final asOf = DateTime(2026, 8, 1);

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

  Study study() => Study(
    id: 'study-1',
    projectId: 'project-1',
    productionCellId: 'cell-1',
    productionLineId: 'line-1',
    name: 'Current state',
    includeInSimulation: false,
    startBufferDays: 0,
    priority: 100,
    createdAt: now,
    updatedAt: now,
  );

  FlowNode step(int position, {String? workcenterId, String? poolId}) =>
      FlowNode(
        id: 'node-$position',
        studyId: 'study-1',
        position: position,
        kind: FlowNodeKind.step,
        workcenterId: workcenterId,
        poolId: poolId,
        changeoverSeconds: 0,
        inventoryUsesWorkingTime: false,
        createdAt: now,
        updatedAt: now,
      );

  WorkcenterContext context(
    String id, {
    List<int> operators = const [1, 1, 1],
    double availability = 1,
    double rework = 0,
  }) {
    final schedule = WorkcenterScheduleSpec([
      WorkcenterSchedulePeriodSpec(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        operatorsPerShift: operators,
        availability: availability,
        rework: rework,
      ),
    ]);
    return WorkcenterContext(
      workcenter: Workcenter(
        id: id,
        plantId: 'plant-1',
        parallelCapacity: 1,
        name: id,
        createdAt: now,
        updatedAt: now,
      ),
      calendar: WorkingCalendar.scheduled(pattern: abc, staffing: schedule),
      schedule: schedule,
    );
  }

  FlowView build({
    required List<FlowNode> nodes,
    required Map<String, WorkcenterContext> contexts,
    required FlowDataSource dataSource,
    FlowDemandInput demand = const FlowDemandInput(),
    Map<String, WorkcenterPool> pools = const {},
    Map<String, List<String>> members = const {},
    double takt = 3,
  }) => buildFlowView(
    study: study(),
    nodes: nodes,
    contexts: contexts,
    pools: pools,
    poolMembers: members,
    taktSchedule: TaktScheduleSpec([
      TaktPeriodSpec(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        value: takt,
        unit: TaktUnit.days,
      ),
    ]),
    asOf: asOf,
    dataSource: dataSource,
    demand: demand,
  );

  group('a single part', () {
    test('the worked reference in §6.1', () {
      final view = build(
        nodes: [step(0, workcenterId: 'CLAD04')],
        contexts: {
          'CLAD04': context('CLAD04', availability: 0.74, rework: 0.037),
        },
        dataSource: FlowDataSource.singlePart,
        demand: const FlowDemandInput(
          processTimes: {
            'p1': {'CLAD04': Duration(hours: 55)},
          },
          selectedPartId: 'p1',
        ),
      );

      final step0 = view.steps.single;

      // 22:40 open = 81600 s; × 0.74 = 60384 s = 16.77 h productive;
      // × 3 takt-days = 181152 s = exactly the 50.32 h the doc states.
      expect(step0.productivePerWorkingDay.inSeconds, 60384);
      expect(step0.equivalentProcessTime!.inSeconds, 181152);

      // 55 h × 1.037 = 57.035 h. Rework is charged against the *part*, never
      // against the yardstick (§6.1).
      expect(step0.processTime!.inSeconds, (55 * 3600 * 1.037).round());

      // 57.035 ÷ 50.32 = 1.13.
      expect(step0.equivalence, closeTo(1.13, 0.005));
      expect(view.flowEquivalence, closeTo(1.13, 0.005));

      // And the ladder measures it in productive days: 57.035 ÷ 16.77 = 3.40.
      expect(step0.ladderDays, closeTo(3.40, 0.005));
    });

    test('one takt of work is exactly 1.00 however bad the uptime', () {
      // The equivalent's own time, entered as a part. Availability cancels,
      // which is the property that makes the yardstick worth having.
      for (final availability in [1.0, 0.74, 0.4]) {
        final yardstick = build(
          nodes: [step(0, workcenterId: 'CLAD04')],
          contexts: {'CLAD04': context('CLAD04', availability: availability)},
          dataSource: FlowDataSource.flowEquivalent,
        ).steps.single.equivalentProcessTime!;

        final view = build(
          nodes: [step(0, workcenterId: 'CLAD04')],
          contexts: {'CLAD04': context('CLAD04', availability: availability)},
          dataSource: FlowDataSource.singlePart,
          demand: FlowDemandInput(
            processTimes: {
              'p1': {'CLAD04': yardstick},
            },
            selectedPartId: 'p1',
          ),
        );

        expect(view.steps.single.equivalence, closeTo(1.0, 0.0001));
      }
    });

    test('flow equivalence is a ratio of sums, not a mean of ratios', () {
      // Two steps of very different length: the part is twice as slow as the
      // takt on a short step and exactly on takt on a long one. The mean of the
      // ratios would be 1.5; the honest answer weights by how long each step is.
      final view = build(
        nodes: [
          step(0, workcenterId: 'SHORT'),
          step(1, workcenterId: 'LONG'),
        ],
        contexts: {
          // 8:48 a day × 3 = 26:24 = 95040 s.
          'SHORT': context('SHORT', operators: [1, 0, 0]),
          // 22:40 a day × 3 = 68 h = 244800 s.
          'LONG': context('LONG', operators: [1, 1, 1]),
        },
        dataSource: FlowDataSource.singlePart,
        demand: const FlowDemandInput(
          processTimes: {
            'p1': {
              'SHORT': Duration(seconds: 190080),
              'LONG': Duration(seconds: 244800),
            },
          },
          selectedPartId: 'p1',
        ),
      );

      expect(view.steps.first.equivalence, closeTo(2.0, 0.0001));
      expect(view.steps.last.equivalence, closeTo(1.0, 0.0001));
      expect(
        view.flowEquivalence,
        closeTo((190080 + 244800) / (95040 + 244800), 0.0001),
      );
      expect(view.flowEquivalence, closeTo(1.28, 0.005));
    });

    test('a step the part has no time for is a blocking problem', () {
      final view = build(
        nodes: [
          step(0, workcenterId: 'CLAD04'),
          step(1, workcenterId: 'TTAT'),
        ],
        contexts: {'CLAD04': context('CLAD04'), 'TTAT': context('TTAT')},
        dataSource: FlowDataSource.singlePart,
        demand: const FlowDemandInput(
          processTimes: {
            'p1': {'CLAD04': Duration(hours: 55)},
          },
          selectedPartId: 'p1',
        ),
      );

      final second = view.steps.last;
      expect(second.problems, [StepProblem.noProcessTime]);
      // A dash, not a quiet fall-back to the takt: a step with no time is a
      // hole in the data, and filling it with the yardstick would hide it.
      expect(second.processTime, isNull);
      expect(view.hasBlockingProblems, isTrue);
    });

    test('the yardstick survives even where the part has no time', () {
      final view = build(
        nodes: [step(0, workcenterId: 'CLAD04')],
        contexts: {'CLAD04': context('CLAD04')},
        dataSource: FlowDataSource.singlePart,
        demand: const FlowDemandInput(selectedPartId: 'p1'),
      );

      expect(view.steps.single.processTime, isNull);
      expect(view.steps.single.equivalentProcessTime, isNotNull);
      expect(view.steps.single.equivalence, isNull);
    });

    test('a pool step reads the pool\'s cell, not a member\'s', () {
      final view = build(
        nodes: [step(0, poolId: 'pool-1')],
        contexts: {'LAT01': context('LAT01'), 'LAT02': context('LAT02')},
        pools: {
          'pool-1': WorkcenterPool(
            id: 'pool-1',
            plantId: 'plant-1',
            name: 'CNC Lathes',
            createdAt: now,
            updatedAt: now,
          ),
        },
        members: const {
          'pool-1': ['LAT01', 'LAT02'],
        },
        dataSource: FlowDataSource.singlePart,
        demand: const FlowDemandInput(
          processTimes: {
            'p1': {
              'pool-1': Duration(hours: 10),
              // Deliberately different: a member's own key must not be read.
              'LAT01': Duration(hours: 99),
            },
          },
          selectedPartId: 'p1',
        ),
      );

      expect(view.steps.single.processTime, const Duration(hours: 10));
    });
  });

  group('weighted variants', () {
    FlowView weighted({
      required Map<String, Map<String, Duration>> times,
      required Map<String, int> pieces,
      double rework = 0,
    }) => build(
      nodes: [step(0, workcenterId: 'CLAD04')],
      contexts: {'CLAD04': context('CLAD04', rework: rework)},
      dataSource: FlowDataSource.weightedVariants,
      demand: FlowDemandInput(
        processTimes: times,
        piecesDueInPeriod: pieces,
      ),
    );

    test('weights by pieces due, not by order count', () {
      final view = weighted(
        times: {
          'p1': {'CLAD04': const Duration(hours: 10)},
          'p2': {'CLAD04': const Duration(hours: 20)},
        },
        // One order of ten pieces outweighs one of one, because process times
        // are per piece (§7.6).
        pieces: const {'p1': 10, 'p2': 1},
      );

      expect(
        view.steps.single.processTime,
        Duration(seconds: ((10 * 10 + 20 * 1) / 11 * 3600).round()),
      );
    });

    test('a part that skips the step is out of the average entirely', () {
      final view = weighted(
        times: {
          'p1': {'CLAD04': const Duration(hours: 10)},
          // p2 never comes here.
          'p2': {'TTAT': const Duration(hours: 20)},
        },
        pieces: const {'p1': 1, 'p2': 99},
      );

      // Counting p2's absence as zero would claim the station is faster than
      // any piece passing through it ever is (§5.1).
      expect(view.steps.single.processTime, const Duration(hours: 10));
    });

    test('no pieces due in the period is a dash, not a zero', () {
      final view = weighted(
        times: {
          'p1': {'CLAD04': const Duration(hours: 10)},
        },
        pieces: const {},
      );

      expect(view.steps.single.processTime, isNull);
      expect(view.steps.single.problems, [StepProblem.noProcessTime]);
    });

    test('rework is charged once, on the weighted result', () {
      final view = weighted(
        times: {
          'p1': {'CLAD04': const Duration(hours: 10)},
        },
        pieces: const {'p1': 1},
        rework: 0.037,
      );

      expect(
        view.steps.single.processTime,
        Duration(seconds: (10 * 3600 * 1.037).round()),
      );
    });
  });

  test('the flow equivalent reports no equivalence at all', () {
    final view = build(
      nodes: [step(0, workcenterId: 'CLAD04')],
      contexts: {'CLAD04': context('CLAD04')},
      dataSource: FlowDataSource.flowEquivalent,
    );

    // It would be 1.00 by construction, and a row of ones says nothing.
    expect(view.steps.single.equivalence, isNull);
    expect(view.flowEquivalence, isNull);
    expect(view.steps.single.processTime, view.steps.single.equivalentProcessTime);
  });
}
