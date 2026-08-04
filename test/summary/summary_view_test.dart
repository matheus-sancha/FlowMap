import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/demand/application/demand_table.dart';
import 'package:flowmap/src/features/flow/application/flow_view.dart';
import 'package:flowmap/src/features/schedules/application/takt_schedule.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flowmap/src/features/summary/application/summary_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// Occupation, operators and demand takt (DESIGN.md §8).
void main() {
  final now = DateTime(2026, 8, 1);

  /// A pattern open exactly ten hours on every day of the week, so a month's
  /// available hours are a number that can be checked by hand.
  final tenHoursDaily = ShiftPatternSpec(
    name: 'Ten',
    cycleType: ShiftCycleType.rotating,
    workingWeekdays: ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5, 6, 7]),
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

  Study study() => Study(
    id: 'study-1',
    projectId: 'project-1',
    productionCellId: 'cell-1',
    productionLineId: 'line-1',
    name: 'Current state',
    includeInSimulation: false,
    priority: 100,
    createdAt: now,
    updatedAt: now,
  );

  FlowNode step(int position, String workcenterId, {int changeover = 0}) =>
      FlowNode(
        id: 'node-$position',
        studyId: 'study-1',
        position: position,
        kind: FlowNodeKind.step,
        workcenterId: workcenterId,
        changeoverSeconds: changeover,
        inventoryUsesWorkingTime: false,
        createdAt: now,
        updatedAt: now,
      );

  WorkcenterContext context(
    String id, {
    List<int> operators = const [1],
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
        name: id,
        createdAt: now,
        updatedAt: now,
      ),
      calendar: WorkingCalendar.scheduled(
        pattern: tenHoursDaily,
        staffing: schedule,
      ),
      schedule: schedule,
    );
  }

  FlowView flowOf({
    required List<FlowNode> nodes,
    required Map<String, WorkcenterContext> contexts,
  }) => buildFlowView(
    study: study(),
    nodes: nodes,
    contexts: contexts,
    pools: const {},
    poolMembers: const {},
    taktSchedule: TaktScheduleSpec([
      TaktPeriodSpec(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        value: 1,
        unit: TaktUnit.days,
      ),
    ]),
    // August 2026: 31 days, ten open hours each = 310 hours.
    asOf: DateTime(2026, 8, 1),
  );

  DemandPart part(String id, String number) => DemandPart(
    id: id,
    studyId: 'study-1',
    partNumber: number,
    customerProject: '',
    createdAt: now,
    updatedAt: now,
  );

  DemandOrder order(
    String id,
    int sequence,
    String partId, {
    int batch = 1,
    int day = 15,
    int month = 8,
  }) => DemandOrder(
    id: id,
    studyId: 'study-1',
    partId: partId,
    sequence: sequence,
    batchSize: batch,
    needDate: DateTime(2026, month, day),
    createdAt: now,
    updatedAt: now,
  );

  const oneColumn = [
    DemandColumn(nodeId: 'node-0', targetId: 'CLAD04', title: 'CLAD04'),
  ];

  group('occupation', () {
    test('required over available productive hours', () {
      final summary = buildSummary(
        flow: flowOf(
          nodes: [step(0, 'CLAD04')],
          contexts: {'CLAD04': context('CLAD04')},
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1')],
          columns: oneColumn,
          times: {
            'p1': {'CLAD04': const Duration(hours: 10)},
          },
        ),
        orders: [
          for (var i = 0; i < 20; i++) order('o$i', i, 'p1'),
        ],
      );

      final target = summary.targets.single;
      // 31 days x 10 h = 310 available; 20 orders x 10 h = 200 required.
      expect(target.availableProductive, const Duration(hours: 310));
      expect(target.required, const Duration(hours: 200));
      expect(target.occupation, closeTo(200 / 310, 0.0001));
      expect(target.isOverloaded, isFalse);
    });

    test('availability derates the hours once, never twice', () {
      final summary = buildSummary(
        flow: flowOf(
          nodes: [step(0, 'CLAD04')],
          contexts: {'CLAD04': context('CLAD04', availability: 0.5)},
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1')],
          columns: oneColumn,
          times: {
            'p1': {'CLAD04': const Duration(hours: 10)},
          },
        ),
        orders: [order('o0', 0, 'p1')],
      );

      final target = summary.targets.single;
      expect(target.availableProductive, const Duration(hours: 155));
      // The part's own time is untouched: dividing by availability here as
      // well is §4.4's oldest trap.
      expect(target.required, const Duration(hours: 10));
    });

    test('rework is charged against the work, not the hours', () {
      final summary = buildSummary(
        flow: flowOf(
          nodes: [step(0, 'CLAD04')],
          contexts: {'CLAD04': context('CLAD04', rework: 0.037)},
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1')],
          columns: oneColumn,
          times: {
            'p1': {'CLAD04': const Duration(hours: 100)},
          },
        ),
        orders: [order('o0', 0, 'p1')],
      );

      expect(
        summary.targets.single.work,
        Duration(seconds: (100 * 3600 * 1.037).round()),
      );
    });

    test('batch size multiplies the work', () {
      final summary = buildSummary(
        flow: flowOf(
          nodes: [step(0, 'CLAD04')],
          contexts: {'CLAD04': context('CLAD04')},
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1')],
          columns: oneColumn,
          times: {
            'p1': {'CLAD04': const Duration(hours: 1)},
          },
        ),
        orders: [order('o0', 0, 'p1', batch: 10)],
      );

      expect(summary.targets.single.work, const Duration(hours: 10));
    });

    test('only orders due in the period count', () {
      final summary = buildSummary(
        flow: flowOf(
          nodes: [step(0, 'CLAD04')],
          contexts: {'CLAD04': context('CLAD04')},
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1')],
          columns: oneColumn,
          times: {
            'p1': {'CLAD04': const Duration(hours: 10)},
          },
        ),
        orders: [
          order('o0', 0, 'p1', month: 7),
          order('o1', 1, 'p1', month: 8),
          order('o2', 2, 'p1', month: 9),
        ],
      );

      expect(summary.ordersInPeriod, 1);
      expect(summary.targets.single.work, const Duration(hours: 10));
    });

    test('a station two steps visit carries both visits', () {
      final summary = buildSummary(
        flow: flowOf(
          nodes: [
            step(0, 'CLAD04'),
            step(1, 'TTAT'),
            step(2, 'CLAD04'),
          ],
          contexts: {
            'CLAD04': context('CLAD04'),
            'TTAT': context('TTAT'),
          },
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1')],
          columns: const [
            DemandColumn(nodeId: 'node-0', targetId: 'CLAD04', title: 'CLAD04'),
            DemandColumn(nodeId: 'node-1', targetId: 'TTAT', title: 'TTAT'),
            DemandColumn(nodeId: 'node-2', targetId: 'CLAD04', title: 'CLAD04'),
          ],
          times: {
            'p1': {
              'CLAD04': const Duration(hours: 10),
              'TTAT': const Duration(hours: 1),
            },
          },
        ),
        orders: [order('o0', 0, 'p1')],
      );

      final clad = summary.targets.firstWhere((t) => t.targetId == 'CLAD04');
      expect(clad.visits, 2);
      // One machine, two passes: 20 hours against one set of 310.
      expect(clad.work, const Duration(hours: 20));
      expect(summary.bottleneck?.title, 'CLAD04');
    });

    test('a station with no hours is not ranked as the bottleneck', () {
      final summary = buildSummary(
        flow: flowOf(
          nodes: [step(0, 'OPEN'), step(1, 'SHUT')],
          contexts: {
            'OPEN': context('OPEN'),
            'SHUT': context('SHUT', operators: const [0]),
          },
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1')],
          columns: const [
            DemandColumn(nodeId: 'node-0', targetId: 'OPEN', title: 'OPEN'),
            DemandColumn(nodeId: 'node-1', targetId: 'SHUT', title: 'SHUT'),
          ],
          times: {
            'p1': {
              'OPEN': const Duration(hours: 10),
              'SHUT': const Duration(hours: 10),
            },
          },
        ),
        orders: [order('o0', 0, 'p1')],
      );

      // A division by zero dressed up as "infinitely busy" would rank a shut
      // station first and hide the real constraint.
      final shut = summary.targets.firstWhere((t) => t.targetId == 'SHUT');
      expect(shut.occupation, isNull);
      expect(summary.bottleneck?.targetId, 'OPEN');
    });

    test('a part with no time here is reported, not treated as free', () {
      final summary = buildSummary(
        flow: flowOf(
          nodes: [step(0, 'CLAD04')],
          contexts: {'CLAD04': context('CLAD04')},
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1'), part('p2', 'PN2')],
          columns: oneColumn,
          times: {
            'p1': {'CLAD04': const Duration(hours: 10)},
          },
        ),
        orders: [order('o0', 0, 'p1'), order('o1', 1, 'p2')],
      );

      expect(summary.targets.single.partsWithoutTimes, 1);
    });
  });

  group('changeover', () {
    Duration requiredWith(List<String> sequence, {int changeover = 3600}) {
      final summary = buildSummary(
        flow: flowOf(
          nodes: [step(0, 'CLAD04', changeover: changeover)],
          contexts: {'CLAD04': context('CLAD04')},
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1'), part('p2', 'PN2')],
          columns: oneColumn,
          times: {
            'p1': {'CLAD04': const Duration(hours: 1)},
            'p2': {'CLAD04': const Duration(hours: 1)},
          },
        ),
        orders: [
          for (var i = 0; i < sequence.length; i++)
            order('o$i', i, sequence[i]),
        ],
      );
      return summary.targets.single.changeoverTime;
    }

    test('is charged only when the part changes', () {
      // Like with like is genuinely cheaper, which is what makes the sequence
      // worth optimising (§7.6, §6.3).
      expect(requiredWith(['p1', 'p1', 'p1']), Duration.zero);
      expect(requiredWith(['p1', 'p2', 'p1']), const Duration(hours: 2));
    });

    test('the first order of the period is compared with the one before it', () {
      final summary = buildSummary(
        flow: flowOf(
          nodes: [step(0, 'CLAD04', changeover: 3600)],
          contexts: {'CLAD04': context('CLAD04')},
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1'), part('p2', 'PN2')],
          columns: oneColumn,
          times: {
            'p1': {'CLAD04': const Duration(hours: 1)},
            'p2': {'CLAD04': const Duration(hours: 1)},
          },
        ),
        orders: [
          // July's last order, then August's — a different part, so August
          // pays for the change even though July is out of the period.
          order('o0', 0, 'p1', month: 7),
          order('o1', 1, 'p2', month: 8),
        ],
      );

      expect(summary.targets.single.changeovers, 1);
    });
  });

  group('operators', () {
    test('needed is allocated at this load', () {
      final summary = buildSummary(
        flow: flowOf(
          nodes: [step(0, 'CLAD04')],
          contexts: {
            'CLAD04': context('CLAD04', operators: const [2]),
          },
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1')],
          columns: oneColumn,
          times: {
            'p1': {'CLAD04': const Duration(hours: 310)},
          },
        ),
        orders: [order('o0', 0, 'p1')],
      );

      final target = summary.targets.single;
      expect(target.operatorsAllocated, 2);
      // Exactly full: the crew it has is the crew it needs.
      expect(target.occupation, closeTo(1.0, 0.0001));
      expect(target.operatorsNeeded, closeTo(2.0, 0.0001));
    });
  });

  group('demand takt', () {
    test('raw counts orders, adjusted counts equivalents', () {
      final summary = buildSummary(
        flow: flowOf(
          nodes: [step(0, 'CLAD04')],
          contexts: {'CLAD04': context('CLAD04')},
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1'), part('p2', 'PN2')],
          columns: oneColumn,
          times: {
            // The takt is one day = 10 productive hours here, so PN1 is worth
            // one equivalent and PN2 three.
            'p1': {'CLAD04': const Duration(hours: 10)},
            'p2': {'CLAD04': const Duration(hours: 30)},
          },
        ),
        orders: [order('o0', 0, 'p1'), order('o1', 1, 'p2')],
      );

      final takt = summary.demandTakt!;
      expect(takt.paceSetterTitle, 'CLAD04');
      expect(takt.available, const Duration(hours: 310));
      expect(takt.orders, 2);
      expect(takt.equivalents, closeTo(4.0, 0.0001));

      // What a visitor expects: 310 h for two orders.
      expect(takt.raw, const Duration(hours: 155));
      // What actually matters: 310 h for four takts of work.
      expect(takt.adjusted, const Duration(minutes: 4650));
      expect(takt.configured, const Duration(hours: 10));
    });

    test('no orders due means no demand takt to state', () {
      final summary = buildSummary(
        flow: flowOf(
          nodes: [step(0, 'CLAD04')],
          contexts: {'CLAD04': context('CLAD04')},
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1')],
          columns: oneColumn,
          times: {
            'p1': {'CLAD04': const Duration(hours: 10)},
          },
        ),
        orders: [order('o0', 0, 'p1', month: 9)],
      );

      expect(summary.demandTakt!.raw, isNull);
      expect(summary.demandTakt!.adjusted, isNull);
    });
  });

  test('a flow with no bound steps has nothing to rank', () {
    final summary = buildSummary(
      flow: flowOf(nodes: const [], contexts: const {}),
      demand: const DemandTable(parts: [], columns: [], times: {}),
      orders: const [],
    );

    expect(summary.targets, isEmpty);
    expect(summary.bottleneck, isNull);
    expect(summary.demandTakt, isNull);
  });

  group('a pool is measured against the whole pool (§3.1)', () {
    /// Two lathes behind one step, and enough work to fill one of them.
    SummaryView poolSummary({required int members}) {
      final ids = [for (var i = 0; i < members; i++) 'LAT0$i'];
      return buildSummary(
        flow: buildFlowView(
          study: study(),
          nodes: [
            FlowNode(
              id: 'node-0',
              studyId: 'study-1',
              position: 0,
              kind: FlowNodeKind.step,
              poolId: 'pool-1',
              changeoverSeconds: 0,
              inventoryUsesWorkingTime: false,
              createdAt: now,
              updatedAt: now,
            ),
          ],
          contexts: {for (final id in ids) id: context(id)},
          pools: {
            'pool-1': WorkcenterPool(
              id: 'pool-1',
              plantId: 'plant-1',
              name: 'CNC Lathes',
              createdAt: now,
              updatedAt: now,
            ),
          },
          poolMembers: {'pool-1': ids},
          taktSchedule: TaktScheduleSpec([
            TaktPeriodSpec(
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 12, 31),
              value: 1,
              unit: TaktUnit.days,
            ),
          ]),
          asOf: DateTime(2026, 8, 1),
        ),
        demand: DemandTable(
          parts: [part('p1', 'PN1')],
          columns: const [
            DemandColumn(
              nodeId: 'node-0',
              targetId: 'pool-1',
              title: 'CNC Lathes',
            ),
          ],
          times: {
            'p1': {'pool-1': const Duration(hours: 310)},
          },
        ),
        orders: [order('o0', 0, 'p1')],
      );
    }

    test('two lathes carry the load of two lathes, not of one', () {
      // 310 h of work against a month of 31 ten-hour days.
      final alone = poolSummary(members: 1);
      expect(alone.targets.single.occupation, closeTo(1.0, 0.0001));

      // Adding a second lathe halves the occupation. Measuring the pool
      // against one member read a full pool as twice as busy as it is —
      // reported from the field.
      final pair = poolSummary(members: 2);
      expect(pair.targets.single.availableProductive, const Duration(hours: 620));
      expect(pair.targets.single.occupation, closeTo(0.5, 0.0001));
    });

    test('operators are summed across the members too', () {
      expect(poolSummary(members: 1).targets.single.operatorsAllocated, 1);
      expect(poolSummary(members: 3).targets.single.operatorsAllocated, 3);
    });

    test('the flow equivalent still measures one machine', () {
      // FE_pt is one takt of a *machine's* capacity (§6.1): the dummy part is
      // one piece, and one piece runs on one lathe however many there are.
      final view = buildFlowView(
        study: study(),
        nodes: [
          FlowNode(
            id: 'node-0',
            studyId: 'study-1',
            position: 0,
            kind: FlowNodeKind.step,
            poolId: 'pool-1',
            changeoverSeconds: 0,
            inventoryUsesWorkingTime: false,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        contexts: {'LAT00': context('LAT00'), 'LAT01': context('LAT01')},
        pools: {
          'pool-1': WorkcenterPool(
            id: 'pool-1',
            plantId: 'plant-1',
            name: 'CNC Lathes',
            createdAt: now,
            updatedAt: now,
          ),
        },
        poolMembers: const {
          'pool-1': ['LAT00', 'LAT01'],
        },
        taktSchedule: TaktScheduleSpec([
          TaktPeriodSpec(
            startDate: DateTime(2026, 1, 1),
            endDate: DateTime(2026, 12, 31),
            value: 1,
            unit: TaktUnit.days,
          ),
        ]),
        asOf: DateTime(2026, 8, 1),
      );

      expect(
        view.steps.single.equivalentProcessTime,
        const Duration(hours: 10),
      );
      // But the capacity behind it is both lathes'.
      expect(view.steps.single.capacityInPeriod, const Duration(hours: 620));
    });
  });

}
