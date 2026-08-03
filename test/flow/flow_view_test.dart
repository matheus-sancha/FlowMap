import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/flow/application/flow_layout.dart';
import 'package:flowmap/src/features/flow/application/flow_view.dart';
import 'package:flowmap/src/features/schedules/application/takt_schedule.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// The map's arithmetic, with no database and no widget tree — the seam that
/// makes "what does this box say" a unit test (DESIGN.md §5.4, §6.1).
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
    priority: 100,
    createdAt: now,
    updatedAt: now,
  );

  Workcenter workcenter(String id, {DateTime? archivedAt}) => Workcenter(
    id: id,
    plantId: 'plant-1',
    name: id,
    archivedAt: archivedAt,
    createdAt: now,
    updatedAt: now,
  );

  FlowNode step(
    int position, {
    String? workcenterId,
    String? poolId,
    int changeoverSeconds = 0,
    double? equivalentValue,
    TaktUnit? equivalentUnit,
    String? label,
  }) => FlowNode(
    id: 'node-$position',
    studyId: 'study-1',
    position: position,
    kind: FlowNodeKind.step,
    workcenterId: workcenterId,
    poolId: poolId,
    changeoverSeconds: changeoverSeconds,
    equivalentValue: equivalentValue,
    equivalentUnit: equivalentUnit,
    inventoryUsesWorkingTime: false,
    label: label,
    createdAt: now,
    updatedAt: now,
  );

  FlowNode inventory(
    int position, {
    required InventoryMode mode,
    int? quantity,
    int? seconds,
  }) => FlowNode(
    id: 'node-$position',
    studyId: 'study-1',
    position: position,
    kind: FlowNodeKind.inventory,
    changeoverSeconds: 0,
    inventoryMode: mode,
    inventoryQuantity: quantity,
    inventorySeconds: seconds,
    inventoryUsesWorkingTime: false,
    createdAt: now,
    updatedAt: now,
  );

  /// A workcenter open [operators] and covered by one schedule period for 2026.
  WorkcenterContext context(
    String id, {
    List<int> operators = const [1, 1, 1],
    double availability = 1,
    double rework = 0,
    bool scheduled = true,
    DateTime? archivedAt,
  }) {
    final schedule = WorkcenterScheduleSpec([
      if (scheduled)
        WorkcenterSchedulePeriodSpec(
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
          operatorsPerShift: operators,
          availability: availability,
          rework: rework,
        ),
    ]);
    return WorkcenterContext(
      workcenter: workcenter(id, archivedAt: archivedAt),
      calendar: WorkingCalendar.scheduled(pattern: abc, staffing: schedule),
      schedule: schedule,
    );
  }

  TaktScheduleSpec taktOf(double value, TaktUnit unit) => TaktScheduleSpec([
    TaktPeriodSpec(
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      value: value,
      unit: unit,
    ),
  ]);

  FlowView build({
    required List<FlowNode> nodes,
    required Map<String, WorkcenterContext> contexts,
    TaktScheduleSpec? takt,
    Map<String, WorkcenterPool> pools = const {},
    Map<String, List<String>> members = const {},
  }) => buildFlowView(
    study: study(),
    nodes: nodes,
    contexts: contexts,
    pools: pools,
    poolMembers: members,
    taktSchedule: takt ?? taktOf(3, TaktUnit.days),
    asOf: asOf,
  );

  group('the flow equivalent', () {
    test('a step costs one takt of its own capacity', () {
      final view = build(
        nodes: [step(0, workcenterId: 'CLAD04')],
        contexts: {'CLAD04': context('CLAD04')},
      );

      // Three shifts of ABC = 22:40 a day; a 3-day takt is 68 hours of it.
      expect(view.steps.single.processTime, const Duration(hours: 68));
      expect(
        view.steps.single.openPerWorkingDay,
        const Duration(hours: 22, minutes: 40),
      );
    });

    test('the same takt costs less at a workcenter with fewer shifts', () {
      final view = build(
        nodes: [
          step(0, workcenterId: 'THREE'),
          step(1, workcenterId: 'ONE'),
        ],
        contexts: {
          'THREE': context('THREE', operators: [1, 1, 1]),
          'ONE': context('ONE', operators: [1, 0, 0]),
        },
      );

      final steps = view.steps.toList();
      expect(steps[0].processTime, const Duration(hours: 68));
      // 8:48 a day × 3 = 26:24 — the imbalance the method exists to expose.
      expect(steps[1].processTime, const Duration(hours: 26, minutes: 24));
    });

    test('a takt in hours resolves the same everywhere', () {
      final view = build(
        nodes: [
          step(0, workcenterId: 'THREE'),
          step(1, workcenterId: 'ONE'),
        ],
        contexts: {
          'THREE': context('THREE', operators: [1, 1, 1]),
          'ONE': context('ONE', operators: [1, 0, 0]),
        },
        takt: taktOf(4, TaktUnit.hours),
      );
      expect(
        view.steps.map((s) => s.processTime),
        everyElement(const Duration(hours: 4)),
      );
    });

    test("reproduces the reference sheet's workcenter capacity", () {
      // The worked example, row for row:
      //   Takt 3 days, ABC 3 shifts 1/1/1, availability 74 %
      //   Hours per day w/availability  22:40 × 0.74 = 16.77 h
      //   Process time                  3 × 16.77     = 50.32 h
      final view = build(
        nodes: [step(0, workcenterId: 'WC')],
        contexts: {'WC': context('WC', availability: 0.74, rework: 0.037)},
      );
      final only = view.steps.single;

      expect(
        only.openPerWorkingDay,
        const Duration(hours: 22, minutes: 40),
        reason: 'the raw calendar figure, before any loss',
      );
      expect(
        only.productivePerWorkingDay.inSeconds / 3600,
        closeTo(16.77, 0.01),
      );
      expect(only.processTime!.inSeconds / 3600, closeTo(50.32, 0.01));
    });

    test('availability is in the capacity; rework is not', () {
      // Availability belongs to the station's capacity. Rework is a loss on the
      // work a *part* needs, so it attaches to demand process times (M3) and
      // must not move the equivalent.
      final derated = build(
        nodes: [step(0, workcenterId: 'WC')],
        contexts: {'WC': context('WC', availability: 0.74)},
      );
      final withRework = build(
        nodes: [step(0, workcenterId: 'WC')],
        contexts: {'WC': context('WC', availability: 0.74, rework: 0.037)},
      );

      expect(
        derated.steps.single.processTime!.inSeconds,
        closeTo(50.32 * 3600, 30),
      );
      expect(
        withRework.steps.single.processTime,
        derated.steps.single.processTime,
        reason: 'rework changes nothing on the capacity side',
      );
    });

    test('one takt reads as exactly the takt on the ladder', () {
      // Availability cancels: 50.32 h ÷ 16.77 h = 3.0 days. This is why a 3-day
      // takt must show 3 days however bad the station's uptime.
      for (final availability in [1.0, 0.74, 0.5]) {
        final view = build(
          nodes: [step(0, workcenterId: 'WC')],
          contexts: {'WC': context('WC', availability: availability)},
        );
        final only = view.steps.single;
        expect(
          only.ladderTime.inSeconds / only.referenceWorkingDay!.inSeconds,
          closeTo(3, 0.001),
          reason: 'availability $availability',
        );
      }
    });

    test('a step may state the equivalent itself, in hours', () {
      // The inspection case: a full takt there would drag every real part's
      // equivalence at that step toward zero.
      final view = build(
        nodes: [
          step(0, workcenterId: 'WC'),
          step(
            1,
            workcenterId: 'WC',
            equivalentValue: 4,
            equivalentUnit: TaktUnit.hours,
          ),
        ],
        contexts: {'WC': context('WC', availability: 0.74)},
      );
      final steps = view.steps.toList();

      expect(steps[0].processTime!.inSeconds / 3600, closeTo(50.32, 0.01));
      expect(steps[0].usesLocalEquivalent, isFalse);

      expect(steps[1].processTime, const Duration(hours: 4));
      expect(steps[1].usesLocalEquivalent, isTrue);
    });

    test('a step equivalent in days means productive days of that station', () {
      // `1 day` equals one takt-day, so a step overridden to the takt's own
      // value reads identically to one left alone.
      final view = build(
        nodes: [
          step(0, workcenterId: 'WC'),
          step(
            1,
            workcenterId: 'WC',
            equivalentValue: 3,
            equivalentUnit: TaktUnit.days,
          ),
          step(
            2,
            workcenterId: 'WC',
            equivalentValue: 0.5,
            equivalentUnit: TaktUnit.days,
          ),
        ],
        contexts: {'WC': context('WC', availability: 0.74)},
      );
      final steps = view.steps.toList();

      // Overridden to the takt's own value: identical to the default.
      expect(steps[1].processTime, steps[0].processTime);
      // Half a day is half of one takt-day, so six of them make the 3-day takt.
      expect(
        steps[2].processTime!.inSeconds * 6,
        closeTo(steps[0].processTime!.inSeconds, 6),
      );
      expect(
        steps[2].processTime!.inSeconds / 3600,
        closeTo(16.77 / 2, 0.01),
      );
    });

    test('an override survives a missing takt', () {
      // A step that states its own time can still be costed when the line has
      // no takt for the period — it does not depend on one.
      final view = build(
        nodes: [
          step(
            0,
            workcenterId: 'WC',
            equivalentValue: 4,
            equivalentUnit: TaktUnit.hours,
          ),
        ],
        contexts: {'WC': context('WC')},
        takt: TaktScheduleSpec(const []),
      );
      expect(view.steps.single.processTime, const Duration(hours: 4));
    });

    test('a quantity buffer keeps using the line takt, not a step override', () {
      // Stock drains at the rate units leave the line; a step's equivalent is a
      // yardstick, not a local production rate.
      final withOverride = build(
        nodes: [
          inventory(0, mode: InventoryMode.quantity, quantity: 2),
          step(
            1,
            workcenterId: 'WC',
            equivalentValue: 1,
            equivalentUnit: TaktUnit.hours,
          ),
        ],
        contexts: {'WC': context('WC')},
      );
      final without = build(
        nodes: [
          inventory(0, mode: InventoryMode.quantity, quantity: 2),
          step(1, workcenterId: 'WC'),
        ],
        contexts: {'WC': context('WC')},
      );
      expect(withOverride.buffers.single.wait, without.buffers.single.wait);
    });

    test('PCE compares like with like', () {
      final view = build(
        nodes: [
          step(0, workcenterId: 'WC'),
          inventory(1, mode: InventoryMode.duration, seconds: 68 * 3600),
        ],
        contexts: {'WC': context('WC')},
      );
      // Half process, half waiting: the box, the ladder and the totals all read
      // the one figure, so the ratio is of like with like.
      expect(view.processCycleEfficiency, closeTo(0.5, 0.0001));
    });

    test('one takt is one working day of the ladder, whatever the shifts', () {
      // The ladder renders days against the station's own working day, so a
      // 1-day takt reads 1.0 d on a three-shift station and on a one-shift one.
      for (final operators in [
        const [1, 1, 1],
        const [1, 0, 0],
      ]) {
        final view = build(
          nodes: [step(0, workcenterId: 'WC')],
          contexts: {'WC': context('WC', operators: operators)},
          takt: taktOf(1, TaktUnit.days),
        );
        final only = view.steps.single;
        expect(only.ladderTime, only.referenceWorkingDay);
      }
    });

    test('the capacity the takt is read against is open time, underated', () {
      // Availability is applied once — here, to the process time. The open
      // hours it is read against stay the raw calendar figure, or the loss
      // would be counted twice.
      final view = build(
        nodes: [step(0, workcenterId: 'WC')],
        contexts: {'WC': context('WC', availability: 0.5)},
      );
      expect(
        view.steps.single.openPerWorkingDay,
        const Duration(hours: 22, minutes: 40),
      );
    });
  });

  group('a step that cannot be costed shows a dash, not a zero', () {
    test('unbound', () {
      final view = build(nodes: [step(0)], contexts: {});
      expect(view.steps.single.problems, contains(StepProblem.unbound));
      expect(view.steps.single.processTime, isNull);
      expect(view.hasBlockingProblems, isTrue);
    });

    test('the target workcenter is archived', () {
      final view = build(
        nodes: [step(0, workcenterId: 'WC')],
        contexts: {'WC': context('WC', archivedAt: now)},
      );
      expect(view.steps.single.problems, contains(StepProblem.archivedTarget));
      expect(view.steps.single.processTime, isNull);
    });

    test('no schedule period covers the month', () {
      final view = build(
        nodes: [step(0, workcenterId: 'WC')],
        contexts: {'WC': context('WC', scheduled: false)},
      );
      expect(view.steps.single.problems, contains(StepProblem.noSchedule));
      expect(view.steps.single.processTime, isNull);
    });

    test('a pool with no members', () {
      final view = build(
        nodes: [step(0, poolId: 'pool-1')],
        contexts: {},
        pools: {
          'pool-1': WorkcenterPool(
            id: 'pool-1',
            plantId: 'plant-1',
            name: 'Lathes',
            createdAt: now,
            updatedAt: now,
          ),
        },
      );
      expect(view.steps.single.problems, contains(StepProblem.emptyPool));
      expect(view.steps.single.processTime, isNull);
    });

    test('no takt covers the month', () {
      final view = build(
        nodes: [step(0, workcenterId: 'WC')],
        contexts: {'WC': context('WC')},
        takt: TaktScheduleSpec(const []),
      );
      expect(view.taktMissing, isTrue);
      expect(view.steps.single.processTime, isNull);
      expect(view.hasBlockingProblems, isTrue);
    });
  });

  group('pools', () {
    test('a pool step reads its members capacity and shows the pool name', () {
      final view = build(
        nodes: [step(0, poolId: 'pool-1')],
        contexts: {
          'LAT01': context('LAT01', operators: [1, 1, 0]),
        },
        pools: {
          'pool-1': WorkcenterPool(
            id: 'pool-1',
            plantId: 'plant-1',
            name: 'Lathes',
            createdAt: now,
            updatedAt: now,
          ),
        },
        members: {
          'pool-1': ['LAT01'],
        },
      );
      final step0 = view.steps.single;
      expect(step0.problems, isEmpty);
      expect(step0.title, 'Lathes');
      // Two shifts: 05:45 → 23:00 = 17:15 a day, × 3 days = 51:45.
      expect(step0.processTime, const Duration(hours: 51, minutes: 45));
    });
  });

  group('inventory', () {
    test('a quantity buffer is pieces times the takt of what drains it', () {
      final view = build(
        nodes: [
          inventory(0, mode: InventoryMode.quantity, quantity: 2),
          step(1, workcenterId: 'WC'),
        ],
        contexts: {'WC': context('WC')},
      );
      // 2 pieces × a 68-hour takt at that step.
      expect(view.buffers.single.wait, const Duration(hours: 136));
      expect(view.buffers.single.quantity, 2);
    });

    test('a duration buffer is exactly what was entered', () {
      final view = build(
        nodes: [
          inventory(0, mode: InventoryMode.duration, seconds: 24 * 3600),
          step(1, workcenterId: 'WC'),
        ],
        contexts: {'WC': context('WC')},
      );
      expect(view.buffers.single.wait, const Duration(hours: 24));
    });

    test('a quantity buffer with nothing downstream waits no time', () {
      final view = build(
        nodes: [inventory(0, mode: InventoryMode.quantity, quantity: 5)],
        contexts: {},
      );
      expect(view.buffers.single.wait, Duration.zero);
    });
  });

  group('the footer figures', () {
    test('lead time is process plus waiting; PCE is their ratio', () {
      final view = build(
        nodes: [
          step(0, workcenterId: 'WC'),
          inventory(1, mode: InventoryMode.duration, seconds: 68 * 3600),
          step(2, workcenterId: 'WC'),
        ],
        contexts: {'WC': context('WC')},
      );

      expect(view.processTime, const Duration(hours: 136));
      expect(view.leadTime, const Duration(hours: 204));
      expect(view.processCycleEfficiency, closeTo(2 / 3, 0.0001));
    });

    test('an empty flow has no lead time and no division by zero', () {
      final view = build(nodes: const [], contexts: {});
      expect(view.leadTime, Duration.zero);
      expect(view.processCycleEfficiency, 0);
    });
  });

  group('the viewed period', () {
    test('each granularity snaps to the span containing the date', () {
      final august = DateTime(2026, 8, 17);
      expect(PeriodGranularity.month.startOf(august), DateTime(2026, 8));
      expect(PeriodGranularity.quarter.startOf(august), DateTime(2026, 7));
      expect(PeriodGranularity.semester.startOf(august), DateTime(2026, 7));
      expect(PeriodGranularity.year.startOf(august), DateTime(2026));

      expect(PeriodGranularity.month.endOf(august), DateTime(2026, 8, 31));
      expect(PeriodGranularity.quarter.endOf(august), DateTime(2026, 9, 30));
      expect(PeriodGranularity.semester.endOf(august), DateTime(2026, 12, 31));
      expect(PeriodGranularity.year.endOf(august), DateTime(2026, 12, 31));
    });

    test('the first half and first quarter land where they should', () {
      final february = DateTime(2026, 2, 3);
      expect(PeriodGranularity.quarter.startOf(february), DateTime(2026));
      expect(PeriodGranularity.quarter.endOf(february), DateTime(2026, 3, 31));
      expect(PeriodGranularity.semester.startOf(february), DateTime(2026));
      expect(PeriodGranularity.semester.endOf(february), DateTime(2026, 6, 30));
    });

    test('stepping moves a whole span and crosses the year end', () {
      expect(
        PeriodGranularity.month.shift(DateTime(2026, 12), 1),
        DateTime(2027),
      );
      expect(
        PeriodGranularity.quarter.shift(DateTime(2026, 8), 1),
        DateTime(2026, 10),
      );
      expect(
        PeriodGranularity.semester.shift(DateTime(2026, 8), 1),
        DateTime(2027),
      );
      expect(
        PeriodGranularity.year.shift(DateTime(2026, 8), -1),
        DateTime(2025),
      );
    });

    test('a uniform span is not flagged', () {
      final view = buildFlowView(
        study: study(),
        nodes: [step(0, workcenterId: 'WC')],
        contexts: {'WC': context('WC')},
        pools: const {},
        poolMembers: const {},
        taktSchedule: taktOf(3, TaktUnit.days),
        asOf: DateTime(2026, 8),
        granularity: PeriodGranularity.year,
      );
      expect(view.scheduleVariesInPeriod, isFalse);
      expect(view.asOf, DateTime(2026));
      expect(view.periodEnd, DateTime(2026, 12, 31));
    });

    test('a takt change inside the span is flagged, not averaged', () {
      final view = buildFlowView(
        study: study(),
        nodes: [step(0, workcenterId: 'WC')],
        contexts: {'WC': context('WC')},
        pools: const {},
        poolMembers: const {},
        taktSchedule: TaktScheduleSpec([
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
        ]),
        asOf: DateTime(2026, 3),
        granularity: PeriodGranularity.year,
      );

      expect(view.scheduleVariesInPeriod, isTrue);
      // The map still shows one real takt — the one in force on 1 January —
      // rather than an average the line never runs at.
      expect(view.takt!.value, 3);
    });

    test('a staffing change inside the span is flagged too', () {
      final schedule = WorkcenterScheduleSpec([
        WorkcenterSchedulePeriodSpec(
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 6, 30),
          operatorsPerShift: const [1, 1, 1],
        ),
        WorkcenterSchedulePeriodSpec(
          startDate: DateTime(2026, 7, 1),
          endDate: DateTime(2026, 12, 31),
          operatorsPerShift: const [1, 0, 0],
        ),
      ]);
      final view = buildFlowView(
        study: study(),
        nodes: [step(0, workcenterId: 'WC')],
        contexts: {
          'WC': WorkcenterContext(
            workcenter: workcenter('WC'),
            calendar: WorkingCalendar.scheduled(
              pattern: abc,
              staffing: schedule,
            ),
            schedule: schedule,
          ),
        },
        pools: const {},
        poolMembers: const {},
        taktSchedule: taktOf(3, TaktUnit.days),
        asOf: DateTime(2026, 3),
        granularity: PeriodGranularity.year,
      );
      expect(view.scheduleVariesInPeriod, isTrue);
    });

    test('the same change is not flagged when the span sits inside it', () {
      final view = buildFlowView(
        study: study(),
        nodes: [step(0, workcenterId: 'WC')],
        contexts: {'WC': context('WC')},
        pools: const {},
        poolMembers: const {},
        taktSchedule: TaktScheduleSpec([
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
        ]),
        asOf: DateTime(2026, 3),
        granularity: PeriodGranularity.quarter,
      );
      expect(view.scheduleVariesInPeriod, isFalse);
    });
  });

  group('layout', () {
    test(
      'nodes are placed in sequence with an insertion point between each',
      () {
        final view = build(
          nodes: [
            step(0, workcenterId: 'WC'),
            inventory(1, mode: InventoryMode.quantity, quantity: 1),
            step(2, workcenterId: 'WC'),
          ],
          contexts: {'WC': context('WC')},
        );
        final layout = layoutFlow(view);

        expect(layout.nodes, hasLength(3));
        // One before each node, and one after the last, so a flow can be
        // extended at either end.
        expect(layout.insertionPoints, hasLength(4));
        expect(layout.insertionPoints.map((i) => i.position), [0, 1, 2, 3]);

        // Strictly left to right, in position order.
        final lefts = layout.nodes.map((n) => n.rect.left).toList();
        expect(lefts, orderedEquals([...lefts]..sort()));
        expect(layout.supplier.right, lessThan(layout.nodes.first.rect.left));
        expect(layout.customer.left, greaterThan(layout.nodes.last.rect.right));
      },
    );

    test('each rung is centred on its own node', () {
      final view = build(
        nodes: [
          step(0, workcenterId: 'WC'),
          inventory(1, mode: InventoryMode.quantity, quantity: 1),
          step(2, workcenterId: 'WC'),
        ],
        contexts: {'WC': context('WC')},
      );
      final layout = layoutFlow(view);

      for (var i = 0; i < layout.nodes.length; i++) {
        expect(
          layout.ladder[i].rect.center.dx,
          closeTo(layout.nodes[i].rect.center.dx, 0.01),
          reason: 'a rung offset from its node reads as the wrong step\'s time',
        );
      }
    });

    test('the rungs stay edge to edge, so the sawtooth is continuous', () {
      final view = build(
        nodes: [
          step(0, workcenterId: 'WC'),
          step(1, workcenterId: 'WC'),
          step(2, workcenterId: 'WC'),
        ],
        contexts: {'WC': context('WC')},
      );
      final layout = layoutFlow(view);

      for (var i = 0; i < layout.ladder.length - 1; i++) {
        expect(
          layout.ladder[i + 1].rect.left,
          closeTo(layout.ladder[i].rect.right, 0.01),
        );
      }
    });

    test('the ladder puts waiting high and processing low', () {
      final view = build(
        nodes: [
          step(0, workcenterId: 'WC'),
          inventory(1, mode: InventoryMode.duration, seconds: 3600),
        ],
        contexts: {'WC': context('WC')},
      );
      final layout = layoutFlow(view);

      final processing = layout.ladder[0];
      final waiting = layout.ladder[1];
      expect(processing.isWaiting, isFalse);
      expect(waiting.isWaiting, isTrue);
      expect(waiting.rect.top, lessThan(processing.rect.top));
    });

    test('an empty flow still lays out its endpoints', () {
      final layout = layoutFlow(build(nodes: const [], contexts: {}));
      expect(layout.nodes, isEmpty);
      expect(layout.insertionPoints, hasLength(1));
      expect(layout.size.width, greaterThan(0));
    });
  });
}
