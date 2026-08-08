import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/projects/data/projects_repository.dart';
import 'package:flowmap/src/features/resources/data/resources_repository.dart';
import 'package:flowmap/src/features/schedules/data/schedules_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The seam where M1's calendar engine meets project data
/// (`SchedulesRepository.loadWorkcenterCalendar`).
///
/// These are the tests that would catch a wiring mistake the pure calendar
/// suite cannot see: the wrong pattern, staffing that does not switch between
/// periods, an exception that reaches the wrong workcenter.
void main() {
  late AppDatabase db;
  late ResourcesRepository resources;
  late ProjectsRepository projects;
  late SchedulesRepository schedules;

  late String plantId;
  late String cellId;
  late String lineId;
  late String otherLineId;
  late String workcenterId;
  late String otherWorkcenterId;
  late String projectId;

  // 2026-08-03 is a Monday.
  final monday = DateTime(2026, 8, 3);
  final saturday = DateTime(2026, 8, 8);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    resources = ResourcesRepository(db);
    projects = ProjectsRepository(db);
    schedules = SchedulesRepository(db, resources);

    plantId = await resources.createPlant(name: 'Plant 1');
    cellId = await resources.createCell(plantId: plantId, name: 'Cell A');
    lineId = await resources.createLine(cellId: cellId, name: 'Line 1');
    otherLineId = await resources.createLine(cellId: cellId, name: 'Line 2');
    workcenterId = await resources.createWorkcenter(
      plantId: plantId,
      name: 'CLAD04',
      lineIds: {lineId},
    );
    otherWorkcenterId = await resources.createWorkcenter(
      plantId: plantId,
      name: 'TTAT',
      lineIds: {otherLineId},
    );

    final patterns = await resources.watchShiftPatterns().first;
    projectId = await projects.createProject(
      name: 'H2 2026',
      plantId: plantId,
      shiftPatternId: patterns.firstWhere((p) => p.name == 'ABC').id,
    );
  });

  tearDown(() => db.close());

  Future<void> schedulePeriod({
    required String start,
    required String end,
    required List<int> operators,
    double availability = 1,
    double rework = 0,
    String? forWorkcenter,
  }) => schedules.createWorkcenterSchedulePeriod(
    projectId: projectId,
    workcenterId: forWorkcenter ?? workcenterId,
    startDate: DateTime.parse(start),
    endDate: DateTime.parse(end),
    operatorsPerShift: operators,
    availability: availability,
    rework: rework,
  );

  test('the calendar uses the project\'s shift pattern', () async {
    await schedulePeriod(
      start: '2026-01-01',
      end: '2026-12-31',
      operators: [1, 1, 1],
    );

    final calendar = await schedules.loadWorkcenterCalendar(
      projectId: projectId,
      workcenterId: workcenterId,
    );

    expect(calendar, isNotNull);
    // The seeded ABC pattern, all three shifts: the same 22:40 the pure
    // calendar suite computes by hand.
    expect(
      calendar!.openTimePerWorkingDay(monday),
      const Duration(hours: 22, minutes: 40),
    );
    expect(calendar.intervalsStartingOn(saturday), isEmpty);
  });

  test('staffing switches at the schedule period boundary', () async {
    await schedulePeriod(
      start: '2026-01-01',
      end: '2026-06-30',
      operators: [1, 1, 1],
    );
    await schedulePeriod(
      start: '2026-07-01',
      end: '2026-12-31',
      operators: [1, 1, 0],
    );

    final calendar = (await schedules.loadWorkcenterCalendar(
      projectId: projectId,
      workcenterId: workcenterId,
    ))!;

    // Three shifts in H1: 22:40. Two in H2: A 05:45→14:33 ∪ B 14:26→23:00
    // = 05:45→23:00 = 17:15.
    expect(
      calendar.openTimePerWorkingDay(DateTime(2026, 3, 2)),
      const Duration(hours: 22, minutes: 40),
    );
    expect(
      calendar.openTimePerWorkingDay(DateTime(2026, 9, 7)),
      const Duration(hours: 17, minutes: 15),
    );
  });

  test(
    'a walk across the boundary spends the right capacity each side',
    () async {
      await schedulePeriod(
        start: '2026-01-01',
        end: '2026-06-30',
        operators: [1, 0, 0],
      );
      await schedulePeriod(
        start: '2026-07-01',
        end: '2026-12-31',
        operators: [1, 1, 0],
      );

      final calendar = (await schedules.loadWorkcenterCalendar(
        projectId: projectId,
        workcenterId: workcenterId,
      ))!;

      // 2026-06-30 is a Tuesday, so 06-30 and 07-01 are both working days.
      // One shift on the 30th (8:48), two on the 1st (17:15).
      expect(
        calendar.openTimeOnDate(DateTime(2026, 6, 30)),
        const Duration(hours: 8, minutes: 48),
      );
      expect(
        calendar.openTimeOnDate(DateTime(2026, 7, 1)),
        const Duration(hours: 17, minutes: 15),
      );
    },
  );

  test('a date no period covers is closed, not silently staffed', () async {
    await schedulePeriod(
      start: '2026-07-01',
      end: '2026-12-31',
      operators: [1, 1, 1],
    );

    final calendar = (await schedules.loadWorkcenterCalendar(
      projectId: projectId,
      workcenterId: workcenterId,
    ))!;

    expect(calendar.openTimeOnDate(DateTime(2026, 3, 2)), Duration.zero);
    // Past the end, the last period is carried forward (DESIGN.md §11.1).
    expect(
      calendar.openTimeOnDate(DateTime(2027, 3, 1)),
      const Duration(hours: 22, minutes: 40),
    );
  });

  group('exceptions reach the right workcenters', () {
    setUp(() async {
      await schedulePeriod(
        start: '2026-01-01',
        end: '2026-12-31',
        operators: [1, 1, 1],
      );
      await schedulePeriod(
        start: '2026-01-01',
        end: '2026-12-31',
        operators: [1, 1, 1],
        forWorkcenter: otherWorkcenterId,
      );
    });

    test('a plant shutdown closes every workcenter', () async {
      await schedules.addExceptionRange(
        projectId: projectId,
        from: DateTime(2026, 8, 3),
        to: DateTime(2026, 8, 5),
        kind: CalendarExceptionKind.nonWorking,
        scope: CalendarExceptionScope.plant,
      );

      for (final id in [workcenterId, otherWorkcenterId]) {
        final calendar = (await schedules.loadWorkcenterCalendar(
          projectId: projectId,
          workcenterId: id,
        ))!;
        expect(calendar.openTimeOnDate(monday), Duration.zero);
        expect(calendar.openTimeOnDate(DateTime(2026, 8, 5)), Duration.zero);
        expect(
          calendar.openTimeOnDate(DateTime(2026, 8, 6)),
          isNot(Duration.zero),
          reason: 'the range ended on the 5th',
        );
      }
    });

    test(
      'a line exception reaches only workcenters homed on that line',
      () async {
        await schedules.addExceptionRange(
          projectId: projectId,
          from: DateTime(2026, 8, 3),
          to: DateTime(2026, 8, 3),
          kind: CalendarExceptionKind.nonWorking,
          scope: CalendarExceptionScope.productionLine,
          scopeId: lineId,
        );

        final onLine = (await schedules.loadWorkcenterCalendar(
          projectId: projectId,
          workcenterId: workcenterId,
        ))!;
        final elsewhere = (await schedules.loadWorkcenterCalendar(
          projectId: projectId,
          workcenterId: otherWorkcenterId,
        ))!;

        expect(onLine.openTimeOnDate(monday), Duration.zero);
        expect(elsewhere.openTimeOnDate(monday), isNot(Duration.zero));
      },
    );

    test('extra hours on one workcenter beat a plant shutdown', () async {
      await schedules.addExceptionRange(
        projectId: projectId,
        from: saturday,
        to: saturday,
        kind: CalendarExceptionKind.nonWorking,
        scope: CalendarExceptionScope.plant,
      );
      await schedules.addExceptionRange(
        projectId: projectId,
        from: saturday,
        to: saturday,
        kind: CalendarExceptionKind.extraWorking,
        scope: CalendarExceptionScope.workcenter,
        scopeId: workcenterId,
        operatorsPerShift: [1, 0, 0],
      );

      final bottleneck = (await schedules.loadWorkcenterCalendar(
        projectId: projectId,
        workcenterId: workcenterId,
      ))!;
      final rest = (await schedules.loadWorkcenterCalendar(
        projectId: projectId,
        workcenterId: otherWorkcenterId,
      ))!;

      // "Plant closed Saturday, except CLAD04 runs a day shift."
      expect(
        bottleneck.openTimeOnDate(saturday),
        const Duration(hours: 8, minutes: 48),
      );
      expect(rest.openTimeOnDate(saturday), Duration.zero);
    });

    test(
      're-entering a range replaces the earlier answer for those days',
      () async {
        await schedules.addExceptionRange(
          projectId: projectId,
          from: saturday,
          to: saturday,
          kind: CalendarExceptionKind.extraWorking,
          scope: CalendarExceptionScope.plant,
          operatorsPerShift: [1, 0, 0],
        );
        await schedules.addExceptionRange(
          projectId: projectId,
          from: saturday,
          to: saturday,
          kind: CalendarExceptionKind.nonWorking,
          scope: CalendarExceptionScope.plant,
        );

        final rows = await schedules.watchExceptions(projectId).first;
        expect(rows, hasLength(1), reason: 'one exception per day per scope');
        expect(rows.single.kind, CalendarExceptionKind.nonWorking);
      },
    );

    test('a range is expanded to one row per day', () async {
      await schedules.addExceptionRange(
        projectId: projectId,
        from: DateTime(2026, 12, 24),
        to: DateTime(2026, 12, 27),
        kind: CalendarExceptionKind.nonWorking,
        scope: CalendarExceptionScope.plant,
        note: 'Christmas shutdown',
      );
      final rows = await schedules.watchExceptions(projectId).first;
      expect(rows, hasLength(4));
      expect(rows.first.date, DateTime(2026, 12, 24));
      expect(rows.last.date, DateTime(2026, 12, 27));
    });
  });

  group('takt schedule', () {
    test('reads back the period in force', () async {
      await schedules.createTaktPeriod(
        projectId: projectId,
        productionLineId: lineId,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 30),
        takt: 3,
        unit: TaktUnit.days,
      );
      await schedules.createTaktPeriod(
        projectId: projectId,
        productionLineId: lineId,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 12, 31),
        takt: 4,
        unit: TaktUnit.days,
      );

      final schedule = await schedules.loadTaktSchedule(projectId, lineId);
      expect(schedule.taktOn(DateTime(2026, 3, 1))!.value, 3);
      expect(schedule.taktOn(DateTime(2026, 9, 1))!.value, 4);
      // A 3-day takt at a 22:40 workcenter is 68 hours of its capacity.
      expect(
        schedule
            .taktOn(DateTime(2026, 3, 1))!
            .equivalentAt(const Duration(hours: 22, minutes: 40)),
        const Duration(hours: 68),
      );
    });

    test('is scoped to its production line', () async {
      await schedules.createTaktPeriod(
        projectId: projectId,
        productionLineId: lineId,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        takt: 3,
        unit: TaktUnit.days,
      );

      final other = await schedules.loadTaktSchedule(projectId, otherLineId);
      expect(other.isEmpty, isTrue);
    });
  });

  test('a project whose pattern is gone yields no calendar', () async {
    final calendar = await schedules.loadWorkcenterCalendar(
      projectId: 'nope',
      workcenterId: workcenterId,
    );
    expect(calendar, isNull);
  });
}
