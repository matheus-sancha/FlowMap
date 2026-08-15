import 'dart:ui' show Size;

import 'package:drift/drift.dart' show Value;
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/flow/application/flow_layout.dart';
import 'package:flowmap/src/features/flow/application/flow_view.dart';
import 'package:flowmap/src/features/schedules/application/takt_schedule.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

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
    startBufferDays: 0,
    priority: 100,
    createdAt: now,
    updatedAt: now,
  );

  Workcenter workcenter(String id, {DateTime? archivedAt}) => Workcenter(
    id: id,
    plantId: 'plant-1',
    parallelCapacity: 1,
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
    bool usesWorkingTime = false,
    DispatchRule? laneRule,
    int? laneCapacity,
  }) => FlowNode(
    id: 'node-$position',
    studyId: 'study-1',
    position: position,
    kind: FlowNodeKind.inventory,
    changeoverSeconds: 0,
    inventoryMode: mode,
    inventoryQuantity: quantity,
    inventorySeconds: seconds,
    inventoryUsesWorkingTime: usesWorkingTime,
    laneRule: laneRule,
    laneCapacity: laneCapacity,
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
    String? typeName,
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
      typeName: typeName,
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
    int? wipCap,
  }) => buildFlowView(
    study: wipCap == null ? study() : study().copyWith(wipCap: Value(wipCap)),
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
      // How many workcenters stand behind the box, not a type — a pool has
      // none of its own.
      expect(step0.poolMemberCount, 1);
      expect(step0.typeName, isNull);
    });
  });

  group('what a box says about its target', () {
    test('a workcenter step carries its type, not its name twice', () {
      final view = build(
        nodes: [step(0, workcenterId: 'CLAD04')],
        contexts: {'CLAD04': context('CLAD04', typeName: 'Cladding')},
      );
      final step0 = view.steps.single;
      expect(step0.title, 'CLAD04');
      expect(step0.typeName, 'Cladding');
      expect(step0.poolMemberCount, isNull);
    });

    test('an untyped workcenter says nothing rather than repeating itself', () {
      final view = build(
        nodes: [step(0, workcenterId: 'CLAD04')],
        contexts: {'CLAD04': context('CLAD04')},
      );
      expect(view.steps.single.typeName, isNull);
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

    test('a calendar wait is measured in calendar days', () {
      // The bug this replaced: a 48-hour cooling wait was divided by the
      // station's 16.77-hour productive day and read as 2.9 d, so the map
      // disagreed with the "2 days" that had been typed into it.
      final view = build(
        nodes: [
          inventory(0, mode: InventoryMode.duration, seconds: 48 * 3600),
          step(1, workcenterId: 'WC'),
        ],
        contexts: {'WC': context('WC', availability: 0.74)},
      );
      final buffer = view.buffers.single;

      expect(buffer.isCalendarWait, isTrue);
      expect(
        buffer.referenceWorkingDay,
        isNull,
        reason: 'null makes the ladder fall back to 24-hour days',
      );
    });

    test('a working-time wait is measured in productive days', () {
      // It only advances while the station runs, so it is counted in the same
      // days that station's process time is.
      final view = build(
        nodes: [
          inventory(
            0,
            mode: InventoryMode.duration,
            seconds: 48 * 3600,
            usesWorkingTime: true,
          ),
          step(1, workcenterId: 'WC'),
        ],
        contexts: {'WC': context('WC', availability: 0.74)},
      );
      final buffer = view.buffers.single;

      expect(buffer.isCalendarWait, isFalse);
      expect(
        buffer.referenceWorkingDay!.inSeconds / 3600,
        closeTo(16.77, 0.01),
      );
    });

    test('a one-piece buffer reads the same as the step it feeds', () {
      // Both are one takt of the same station, so the triangle and the box
      // beside it must agree.
      final view = build(
        nodes: [
          inventory(0, mode: InventoryMode.quantity, quantity: 1),
          step(1, workcenterId: 'WC'),
        ],
        contexts: {'WC': context('WC', availability: 0.74)},
      );

      expect(view.buffers.single.wait, view.steps.single.processTime);
      expect(
        view.buffers.single.referenceWorkingDay,
        view.steps.single.referenceWorkingDay,
      );
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
      expect(view.leadTimeInDays, 0);
      expect(view.leadTimeWorkingDay, isNull);
    });

    test('the totals are the sum of the rungs above them', () {
      // Three steps, each one takt of its own station: 3 + 3 + 3 = 9 days,
      // whatever the stations' hours (DESIGN.md §17.4).
      final view = build(
        nodes: [
          step(0, workcenterId: 'THREE'),
          step(1, workcenterId: 'ONE'),
          step(2, workcenterId: 'THREE'),
        ],
        contexts: {
          'THREE': context('THREE'),
          'ONE': context('ONE', operators: const [1, 0, 0]),
        },
      );

      expect(view.processTimeInDays, closeTo(9, 1e-9));
      expect(view.leadTimeInDays, closeTo(9, 1e-9));
      // Not any one station's day: a weighted one that makes the total agree
      // with the rungs it totals.
      expect(
        view.leadTime.inSeconds / view.leadTimeWorkingDay!.inSeconds,
        closeTo(9, 1e-3),
      );
    });

    test('a calendar wait counts as the 24-hour days its rung reads', () {
      // 48 h of cooling is 2 days on the ladder, beside a step worth 3.
      final view = build(
        nodes: [
          step(0, workcenterId: 'WC'),
          inventory(1, mode: InventoryMode.duration, seconds: 48 * 3600),
        ],
        contexts: {'WC': context('WC')},
      );

      expect(view.leadTimeInDays, closeTo(5, 1e-9));
      expect(view.processTimeInDays, closeTo(3, 1e-9));
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

  group('the running-days walk', () {
    // The walk always starts at the first day of the viewed period, so every
    // case here begins 1 August 2026 — a Saturday. ABC works Monday to Friday,
    // so nothing moves until Monday the 3rd at 05:45, and each takt-day of
    // 22:40 spills into the following morning.
    FlowView withNodes(List<FlowNode> nodes, {double availability = 1}) =>
        buildFlowView(
          study: study(),
          nodes: nodes,
          contexts: {'WC': context('WC', availability: availability)},
          pools: const {},
          poolMembers: const {},
          taktSchedule: taktOf(1, TaktUnit.days),
          asOf: DateTime(2026, 8),
        );

    test('walks the real calendar from the first day of the period', () {
      // Three takt-days from Saturday the 1st: the weekend passes, then Monday
      // 05:45 → Tuesday 05:05 → Wednesday → Thursday the 6th.
      final view = withNodes([
        step(0, workcenterId: 'WC'),
        step(1, workcenterId: 'WC'),
        step(2, workcenterId: 'WC'),
      ]);

      expect(view.endDate!.month, 8);
      expect(view.endDate!.day, 6);
      // 1st to 6th inclusive.
      expect(view.runningDays, 6);
    });

    test('running days count the closed time that lead time does not', () {
      final view = withNodes([
        for (var i = 0; i < 6; i++) step(i, workcenterId: 'WC'),
      ]);

      // Six takt-days of working time, whatever the calendar does with them.
      expect(view.leadTime, const Duration(hours: 136));
      // But they span two weekends' worth of calendar.
      expect(view.runningDays, greaterThan(6));
      expect(
        view.runningDays! - 6,
        greaterThanOrEqualTo(4),
        reason: 'the gap is the weekends, and is the reason to show both',
      );
    });

    test('working days are the open subset of running days (§17.2)', () {
      // 1 August 2026 is a Saturday and ABC works Monday to Friday. Three
      // takt-days finish on Thursday the 6th, so the walk spans six calendar
      // days of which the first two are the weekend.
      final view = withNodes([
        for (var i = 0; i < 3; i++) step(i, workcenterId: 'WC'),
      ]);

      expect(view.runningDays, 6);
      expect(view.workingDays, 4);
    });

    test('the ratio falls out of the week rather than being imposed', () {
      // The field asked for `running = 1.4 × working`, and 1.4 is 7 ÷ 5. Taking
      // both figures off one walk gets that for free on a five-day week — and
      // gets the right answer instead of 1.4 on a plant that is not, which a
      // literal factor could not (§17.2).
      final long = withNodes([
        for (var i = 0; i < 20; i++) step(i, workcenterId: 'WC'),
      ]);

      final ratio = long.runningDays! / long.workingDays!;
      expect(ratio, closeTo(1.4, 0.12));
    });

    test('a day any station is open is a working day', () {
      // The union, not a nominated station. `WC` keeps ABC's five-day week;
      // `ALL` runs every day — so every day of the span becomes a working one
      // and the two figures converge. That reads like the feature is broken and
      // is in fact the rule working: the line could make progress on a Sunday.
      final continuous = ShiftPatternSpec(
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
      final schedule = WorkcenterScheduleSpec([
        WorkcenterSchedulePeriodSpec(
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
          operatorsPerShift: const [1],
          availability: 1,
          rework: 0,
        ),
      ]);

      final view = buildFlowView(
        study: study(),
        nodes: [
          step(0, workcenterId: 'WC'),
          step(1, workcenterId: 'ALL'),
        ],
        contexts: {
          'WC': context('WC'),
          'ALL': WorkcenterContext(
            workcenter: workcenter('ALL'),
            calendar: WorkingCalendar.scheduled(
              pattern: continuous,
              staffing: schedule,
            ),
            schedule: schedule,
          ),
        },
        pools: const {},
        poolMembers: const {},
        taktSchedule: taktOf(1, TaktUnit.days),
        asOf: DateTime(2026, 8),
      );

      expect(view.workingDays, view.runningDays);
    });

    test('working days never exceed running days', () {
      for (final count in [1, 3, 8, 15]) {
        final view = withNodes([
          for (var i = 0; i < count; i++) step(i, workcenterId: 'WC'),
        ]);
        expect(view.workingDays, lessThanOrEqualTo(view.runningDays!));
        expect(view.workingDays, greaterThan(0));
      }
    });

    test('a longer flow ends later', () {
      final short = withNodes([step(0, workcenterId: 'WC')]);
      final long = withNodes([
        for (var i = 0; i < 4; i++) step(i, workcenterId: 'WC'),
      ]);
      expect(long.endDate!.isAfter(short.endDate!), isTrue);
      expect(long.runningDays!, greaterThan(short.runningDays!));
    });

    test('running days stay consistent with the end date', () {
      final view = withNodes([
        step(0, workcenterId: 'WC'),
        inventory(1, mode: InventoryMode.duration, seconds: 24 * 3600),
        step(2, workcenterId: 'WC'),
      ]);
      expect(
        view.runningDays,
        view.endDate!.difference(view.asOf).inDays + 1,
      );
    });

    test('a calendar buffer spends the weekend; a working one waits it out',
        () {
      final calendarWait = withNodes([
        for (var i = 0; i < 4; i++) step(i, workcenterId: 'WC'),
        inventory(4, mode: InventoryMode.duration, seconds: 48 * 3600),
        step(5, workcenterId: 'WC'),
      ]);
      final workingWait = withNodes([
        for (var i = 0; i < 4; i++) step(i, workcenterId: 'WC'),
        inventory(
          4,
          mode: InventoryMode.duration,
          seconds: 48 * 3600,
          usesWorkingTime: true,
        ),
        step(5, workcenterId: 'WC'),
      ]);

      // Both wait 48 h, but only the working-time one has to skip the weekend
      // to spend them.
      expect(
        workingWait.endDate!.isAfter(calendarWait.endDate!),
        isTrue,
        reason: 'the wall clock runs through a weekend; working time does not',
      );
    });

    test('a trailing working-time buffer still uses a calendar', () {
      // It feeds nothing, so it falls back to the station it just left rather
      // than silently spending its hours on the wall clock.
      final trailing = withNodes([
        step(0, workcenterId: 'WC'),
        inventory(
          1,
          mode: InventoryMode.duration,
          seconds: 48 * 3600,
          usesWorkingTime: true,
        ),
      ]);
      final onTheClock = withNodes([
        step(0, workcenterId: 'WC'),
        inventory(1, mode: InventoryMode.duration, seconds: 48 * 3600),
      ]);
      expect(trailing.endDate!.isAfter(onTheClock.endDate!), isTrue);
    });

    test('an uncostable step yields a dash, not a guess', () {
      final view = withNodes([step(0)]);
      expect(view.endDate, isNull);
      expect(view.runningDays, isNull);
    });

    test('a workcenter that never opens does not hang the walk', () {
      final view = buildFlowView(
        study: study(),
        nodes: [step(0, workcenterId: 'WC')],
        contexts: {'WC': context('WC', operators: const [0, 0, 0])},
        pools: const {},
        poolMembers: const {},
        taktSchedule: taktOf(1, TaktUnit.days),
        asOf: DateTime(2026, 8),
      );
      // The calendar can never supply the time, so the walk reports nothing
      // rather than searching to its ten-year limit and throwing.
      expect(view.endDate, isNull);
      expect(view.runningDays, isNull);
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

    test('every + sits on the middle of its own arrow', () {
      // It was on the middle of the *gap*, which is the same point everywhere
      // except beside a buffer: the arrow there is inset by bufferInset on the
      // triangle's side, so its midpoint is 28px away and the button sat
      // visibly off the line it belongs to.
      final layout = layoutFlow(
        build(
          nodes: [
            step(0, workcenterId: 'CLAD04'),
            inventory(1, mode: InventoryMode.duration, seconds: 48 * 3600),
            step(2, workcenterId: 'CEU27'),
          ],
          contexts: {'CLAD04': context('CLAD04'), 'CEU27': context('CEU27')},
        ),
      );

      expect(layout.insertionPoints, hasLength(layout.connections.length));
      for (var i = 0; i < layout.connections.length; i++) {
        final connection = layout.connections[i];
        expect(
          layout.insertionPoints[i].center.x,
          (connection.from.dx + connection.to.dx) / 2,
        );
        // And on the spine, which is where the arrow is drawn.
        expect(layout.insertionPoints[i].center.y, connection.from.dy);
      }

      // The two links either side of the buffer really are inset, so the test
      // above is exercising the case it was written for rather than passing
      // because every segment happens to be a plain gap.
      expect(
        layout.connections[1].to.dx - layout.connections[1].from.dx,
        greaterThan(FlowMetrics.gap),
      );
    });

    test('an empty flow still lays out its endpoints', () {
      final layout = layoutFlow(build(nodes: const [], contexts: {}));
      expect(layout.nodes, isEmpty);
      expect(layout.insertionPoints, hasLength(1));
      expect(layout.size.width, greaterThan(0));
    });
  });

  group('what an arrow is (§5.2)', () {
    /// Two stations with a lane between them, so the link the rule governs is
    /// a real one. The rule lives on the lane now (§5.5), which is also the
    /// node a reader can see it on.
    List<FlowConnectionKind> kinds({DispatchRule? laneRule, int? wipCap}) =>
        layoutFlow(
          build(
            nodes: [
              step(0, workcenterId: 'CLAD04'),
              inventory(
                1,
                mode: InventoryMode.quantity,
                quantity: 0,
                laneRule: laneRule,
              ),
              step(2, workcenterId: 'CEU27'),
            ],
            contexts: {
              'CLAD04': context('CLAD04'),
              'CEU27': context('CEU27'),
            },
            wipCap: wipCap,
          ),
        ).connections.map((c) => c.kind).toList();

    test('an uncapped flow is push all the way through', () {
      // Which is honest rather than lazy: with no supermarkets in the model
      // (§5.5) and no WIP cap, nothing here is pulled.
      expect(kinds(), everyElement(FlowConnectionKind.push));
    });

    test('a CONWIP cap pulls the whole spine', () {
      // A release requiring a completion (§7.3) is the only real pull lever
      // FlowMap has, and it is study-wide — so it reaches every link.
      expect(kinds(wipCap: 4), everyElement(FlowConnectionKind.pull));
    });

    test('a lane set to FIFO draws itself as one', () {
      // Supplier -> CLAD04 -> lane -> CEU27 -> customer. Only the link out of
      // the lane into the station it feeds is a lane, because that is the one
      // the rule describes.
      expect(kinds(laneRule: DispatchRule.fifo), [
        FlowConnectionKind.push,
        FlowConnectionKind.push,
        FlowConnectionKind.fifoLane,
        FlowConnectionKind.push,
      ]);
    });

    test('a lane following the run draws no lane', () {
      // The whole point of storing only overrides (§7.4): under the default
      // rule every queue in the plant is FIFO, so "is it FIFO" would be true
      // everywhere and a lane on every link would say nothing.
      expect(kinds(), isNot(contains(FlowConnectionKind.fifoLane)));
    });

    test('a lane beats the cap on the link it marks', () {
      // The cap describes the flow; the lane describes one queue in it. Where
      // both apply the more specific one is drawn, and the rest stay pull.
      expect(kinds(wipCap: 4, laneRule: DispatchRule.fifo), [
        FlowConnectionKind.pull,
        FlowConnectionKind.pull,
        FlowConnectionKind.fifoLane,
        FlowConnectionKind.pull,
      ]);
    });
  });

  group('refitting the canvas (§12.2)', () {
    const small = Size(800, 600);
    const wide = Size(1080, 600);
    const content = Size(1400, 900);

    final fitted = Matrix4.identity()..scaleByDouble(0.5, 0.5, 1, 1);
    final zoomed = Matrix4.identity()..scaleByDouble(2, 2, 1, 1);

    bool refit({
      Size viewport = wide,
      Size contentSize = content,
      Size? lastViewport = small,
      Size? lastContent = content,
      Matrix4? fittedMatrix,
      Matrix4? current,
    }) => shouldRefitCanvas(
      viewport: viewport,
      content: contentSize,
      lastViewport: lastViewport,
      lastContent: lastContent,
      fitted: fittedMatrix ?? fitted,
      current: current ?? fitted,
    );

    test('the first frame fits, having nothing to preserve', () {
      expect(
        refit(lastViewport: null, lastContent: null, fittedMatrix: null),
        isTrue,
      );
    });

    test('the sidebar collapsing refits an untouched map', () {
      // 280px of sidebar goes away and the viewport widens. Nobody has zoomed,
      // so the map is still the canvas's to arrange.
      expect(refit(), isTrue);
    });

    test('adding a step refits, because the drawing grew', () {
      expect(
        refit(viewport: small, contentSize: const Size(1600, 900)),
        isTrue,
      );
    });

    test('an unchanged size does not refit — this is the loop guard', () {
      // Fitting calls setState, which rebuilds, which asks this again. If the
      // answer at the same size were yes the canvas would never stop fitting,
      // and the app would hang rather than misdraw.
      expect(refit(viewport: small), isFalse);
    });

    test('a map the user has zoomed is left alone', () {
      // The complaint `_zoomBy` was written to answer, arriving from the other
      // direction: resizing the window must not throw away a deliberate zoom
      // onto the sixth step of a flow.
      expect(refit(current: zoomed), isFalse);
    });

    test('pressing Fit hands the map back', () {
      // Fit installs a new matrix as both `fitted` and `current`, so the two
      // agree again and later resizes resume following the viewport.
      expect(refit(fittedMatrix: zoomed, current: zoomed), isTrue);
    });

    test('a viewport with no width yet fits nothing', () {
      expect(refit(viewport: const Size(0, 600)), isFalse);
      expect(refit(viewport: const Size(double.infinity, 600)), isFalse);
    });
  });
}
