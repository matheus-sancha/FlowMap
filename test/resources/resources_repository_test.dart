// `package:drift/drift.dart` is deliberately not imported: it exports `isNull`
// and `isNotNull` as column expressions, which collide with the matchers of the
// same name.
import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/data/database/seed_data.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/resources/data/resources_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ResourcesRepository repository;

  /// Staffing is constant in these tests, so any date reads the same capacity.
  final monday = DateTime(2026, 8, 3);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = ResourcesRepository(db);
  });

  tearDown(() => db.close());

  group('seeding', () {
    test('a fresh database has the spec\'s workcenter types', () async {
      final types = await repository.watchWorkcenterTypes().first;
      expect(types.map((t) => t.name), containsAll(workcenterTypeSeeds));
      expect(types.every((t) => t.isBuiltIn), isTrue);
    });

    test('a fresh database has the ABC and ABCD patterns', () async {
      final patterns = await repository.watchShiftPatterns().first;
      expect(patterns.map((p) => p.name), containsAll(['ABC', 'ABCD']));

      final abc = patterns.firstWhere((p) => p.name == 'ABC');
      expect(abc.cycleType, ShiftCycleType.fixedWeekly);
      // Monday-Friday.
      expect(abc.workingWeekdays, 1 | 2 | 4 | 8 | 16);

      final abcd = patterns.firstWhere((p) => p.name == 'ABCD');
      expect(abcd.cycleType, ShiftCycleType.rotating);
      // Two windows, not four crews — four would count each day twice.
      final shifts = await repository.watchPatternShifts(abcd.id).first;
      expect(shifts, hasLength(2));
    });

    test('re-seeding does not duplicate', () async {
      await db.seedReferenceData();
      await db.seedReferenceData();
      final types = await repository.watchWorkcenterTypes().first;
      expect(types.where((t) => t.name == 'Machining'), hasLength(1));
      final patterns = await repository.watchShiftPatterns().first;
      expect(patterns.where((p) => p.name == 'ABC'), hasLength(1));
    });

    test('a deliberately deleted seed row is not resurrected', () async {
      final types = await repository.watchWorkcenterTypes().first;
      final bending = types.firstWhere((t) => t.name == 'Bending');
      await repository.deleteWorkcenterType(bending.id);

      await db.seedReferenceData();

      final after = await repository.watchWorkcenterTypes().first;
      expect(after.map((t) => t.name), isNot(contains('Bending')));
    });

    test('an emptied table is refilled', () async {
      final types = await repository.watchWorkcenterTypes().first;
      for (final type in types) {
        await repository.deleteWorkcenterType(type.id);
      }
      expect(await repository.watchWorkcenterTypes().first, isEmpty);

      await db.seedReferenceData();

      final after = await repository.watchWorkcenterTypes().first;
      expect(after.map((t) => t.name), containsAll(workcenterTypeSeeds));
    });
  });

  group('the seeded ABC pattern feeds the calendar', () {
    test('is worth 22:40 a day with all three shifts staffed', () async {
      final patterns = await repository.watchShiftPatterns().first;
      final abc = patterns.firstWhere((p) => p.name == 'ABC');
      final spec = await repository.loadPatternSpec(abc.id);

      expect(spec, isNotNull);
      final calendar = WorkingCalendar(
        pattern: spec!,
        operatorsPerShift: const [1, 1, 1],
      );
      // Same hand-computed figure as the calendar suite, but reached through
      // the seed and the repository — so a bad seed cannot pass silently.
      expect(
        calendar.openTimePerWorkingDay(monday),
        const Duration(hours: 22, minutes: 40),
      );
    });

    test('ABCD is continuous', () async {
      final patterns = await repository.watchShiftPatterns().first;
      final abcd = patterns.firstWhere((p) => p.name == 'ABCD');
      final spec = await repository.loadPatternSpec(abcd.id);

      final calendar = WorkingCalendar(
        pattern: spec!,
        operatorsPerShift: const [1, 1],
      );
      expect(calendar.openTimePerWorkingDay(monday), const Duration(hours: 24));
      // Sunday included: a rotating pattern works every day.
      expect(
        calendar.openTimeOnDate(DateTime(2026, 8, 9)),
        const Duration(hours: 24),
      );
    });

    test('loadPatternSpec returns null for an unknown pattern', () async {
      expect(await repository.loadPatternSpec('nope'), isNull);
    });
  });

  group('the resource tree', () {
    late String plantId;

    setUp(() async {
      plantId = await repository.createPlant(name: 'Plant 1', code: 'P1');
    });

    test('cells, lines and workcenters nest and read back', () async {
      final cellId = await repository.createCell(
        plantId: plantId,
        name: 'Cell A',
      );
      final lineId = await repository.createLine(
        cellId: cellId,
        name: 'Line 1',
      );
      await repository.createWorkcenter(
        plantId: plantId,
        name: 'Cladding 04',
        homeLineId: lineId,
      );

      final lines = await repository.watchPlantLines(plantId).first;
      expect(lines, hasLength(1));
      expect(lines.single.qualifiedName, 'Cell A · Line 1');

      final workcenters = await repository.watchWorkcenters(plantId).first;
      expect(workcenters.single.name, 'Cladding 04');
      expect(workcenters.single.homeLineId, lineId);
    });

    test('a workcenter needs no line — it belongs to the plant', () async {
      await repository.createWorkcenter(plantId: plantId, name: 'Shared oven');
      final workcenters = await repository.watchWorkcenters(plantId).first;
      expect(workcenters.single.homeLineId, isNull);
    });

    test('deleting a line leaves its workcenters on the plant', () async {
      final cellId = await repository.createCell(
        plantId: plantId,
        name: 'Cell A',
      );
      final lineId = await repository.createLine(
        cellId: cellId,
        name: 'Line 1',
      );
      await repository.createWorkcenter(
        plantId: plantId,
        name: 'Cladding 04',
        homeLineId: lineId,
      );

      await repository.deleteLine(lineId);

      final workcenters = await repository.watchWorkcenters(plantId).first;
      expect(
        workcenters,
        hasLength(1),
        reason: 'the line is where it is drawn, not what owns it',
      );
      expect(workcenters.single.homeLineId, isNull);
    });

    test('deleting a plant cascades to its cells and workcenters', () async {
      await repository.createCell(plantId: plantId, name: 'Cell A');
      await repository.createWorkcenter(plantId: plantId, name: 'WC');

      await repository.deletePlant(plantId);

      expect(await repository.watchCells(plantId).first, isEmpty);
      expect(await repository.watchWorkcenters(plantId).first, isEmpty);
    });

    test('deleting a workcenter type clears it from workcenters', () async {
      final types = await repository.watchWorkcenterTypes().first;
      final welding = types.firstWhere((t) => t.name == 'Welding');
      await repository.createWorkcenter(
        plantId: plantId,
        name: 'WC',
        typeId: welding.id,
      );

      await repository.deleteWorkcenterType(welding.id);

      final workcenters = await repository.watchWorkcenters(plantId).first;
      expect(
        workcenters.single.typeId,
        isNull,
        reason: 'foreign keys are on, and the reference is ON DELETE SET NULL',
      );
    });
  });

  group('archiving', () {
    test('archived rows leave the default read path but still exist', () async {
      final plantId = await repository.createPlant(name: 'Plant 1');
      final cellId = await repository.createCell(
        plantId: plantId,
        name: 'Cell A',
      );

      await repository.setCellArchived(cellId, true);
      expect(await repository.watchCells(plantId).first, isEmpty);
      expect(
        await repository.watchCells(plantId, includeArchived: true).first,
        hasLength(1),
      );

      await repository.setCellArchived(cellId, false);
      expect(await repository.watchCells(plantId).first, hasLength(1));
    });

    test('an archived line drops out of the plant line list', () async {
      final plantId = await repository.createPlant(name: 'Plant 1');
      final cellId = await repository.createCell(
        plantId: plantId,
        name: 'Cell A',
      );
      final lineId = await repository.createLine(
        cellId: cellId,
        name: 'Line 1',
      );

      await repository.setLineArchived(lineId, true);
      expect(await repository.watchPlantLines(plantId).first, isEmpty);
    });

    test('archiving a cell hides its lines too', () async {
      final plantId = await repository.createPlant(name: 'Plant 1');
      final cellId = await repository.createCell(
        plantId: plantId,
        name: 'Cell A',
      );
      await repository.createLine(cellId: cellId, name: 'Line 1');

      await repository.setCellArchived(cellId, true);
      expect(
        await repository.watchPlantLines(plantId).first,
        isEmpty,
        reason: 'a line in an archived cell is not selectable either',
      );
    });
  });

  group('pools', () {
    late String plantId;
    late String poolId;
    late String first;
    late String second;

    setUp(() async {
      plantId = await repository.createPlant(name: 'Plant 1');
      poolId = await repository.createPool(plantId: plantId, name: 'Lathes');
      first = await repository.createWorkcenter(
        plantId: plantId,
        name: 'LAT01',
      );
      second = await repository.createWorkcenter(
        plantId: plantId,
        name: 'LAT02',
      );
    });

    test('membership is replaced wholesale', () async {
      await repository.setPoolMembers(poolId, {first, second});
      expect(await repository.watchPoolMembers(poolId).first, hasLength(2));

      await repository.setPoolMembers(poolId, {second});
      final members = await repository.watchPoolMembers(poolId).first;
      expect(members.single.id, second);
    });

    test(
      'members come back ordered by name, the last dispatch tie break',
      () async {
        final third = await repository.createWorkcenter(
          plantId: plantId,
          name: 'AAA lathe',
        );
        await repository.setPoolMembers(poolId, {first, second, third});
        final members = await repository.watchPoolMembers(poolId).first;
        expect(members.map((w) => w.name), ['AAA lathe', 'LAT01', 'LAT02']);
      },
    );

    test('a workcenter may belong to several pools', () async {
      final other = await repository.createPool(
        plantId: plantId,
        name: 'Finishing',
      );
      await repository.setPoolMembers(poolId, {first});
      await repository.setPoolMembers(other, {first});

      expect(await repository.watchPoolMembers(poolId).first, hasLength(1));
      expect(await repository.watchPoolMembers(other).first, hasLength(1));
    });

    test('deleting a workcenter removes it from its pools', () async {
      await repository.setPoolMembers(poolId, {first, second});
      await repository.deleteWorkcenter(first);
      final members = await repository.watchPoolMembers(poolId).first;
      expect(members.single.id, second);
    });
  });

  group('shift patterns', () {
    test('setPatternShifts renumbers positions from the list order', () async {
      final id = await repository.createShiftPattern(
        name: 'Two shift',
        cycleType: ShiftCycleType.fixedWeekly,
        workingWeekdays: 1 | 2 | 4 | 8 | 16,
      );
      await repository.setPatternShifts(id, [
        _window('Late', position: 7, start: 14 * 60, end: 22 * 60),
        _window('Early', position: 3, start: 6 * 60, end: 14 * 60),
      ]);

      final shifts = await repository.watchPatternShifts(id).first;
      expect(shifts.map((s) => s.label), ['Late', 'Early']);
      expect(
        shifts.map((s) => s.position),
        [0, 1],
        reason: 'operators-per-shift indexes into these positions',
      );
    });

    test('replacing shifts leaves no orphans behind', () async {
      final id = await repository.createShiftPattern(
        name: 'One shift',
        cycleType: ShiftCycleType.fixedWeekly,
        workingWeekdays: 1,
      );
      await repository.setPatternShifts(id, [
        _window('A', position: 0, start: 6 * 60, end: 14 * 60),
        _window('B', position: 1, start: 14 * 60, end: 22 * 60),
      ]);
      await repository.setPatternShifts(id, [
        _window('A', position: 0, start: 6 * 60, end: 14 * 60),
      ]);

      expect(await repository.watchPatternShifts(id).first, hasLength(1));
    });

    test('two patterns cannot share a name', () async {
      await repository.createShiftPattern(
        name: 'Duplicate',
        cycleType: ShiftCycleType.fixedWeekly,
        workingWeekdays: 1,
      );
      expect(
        () => repository.createShiftPattern(
          name: 'Duplicate',
          cycleType: ShiftCycleType.fixedWeekly,
          workingWeekdays: 1,
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}

ShiftWindow _window(
  String label, {
  required int position,
  required int start,
  required int end,
}) => ShiftWindow(
  label: label,
  position: position,
  startMinute: start,
  endMinute: end,
);
