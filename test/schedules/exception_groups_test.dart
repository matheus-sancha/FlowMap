import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/schedules/presentation/exceptions_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// Folding stored exception days back into the ranges they were entered as
/// (DESIGN.md §4.3, §16.2).
///
/// Ranges are stored expanded, one row per day, so a fortnight's shutdown is
/// fourteen rows. Listing them one by one would bury the one Saturday that
/// matters.
void main() {
  final now = DateTime(2026, 8, 1);

  CalendarException day(
    String id,
    int date, {
    CalendarExceptionKind kind = CalendarExceptionKind.nonWorking,
    CalendarExceptionScope scope = CalendarExceptionScope.plant,
    String scopeId = '',
    String? operators,
    String? note,
    int month = 12,
  }) => CalendarException(
    id: id,
    projectId: 'project-1',
    date: DateTime(2026, month, date),
    kind: kind,
    scope: scope,
    scopeId: scopeId,
    operatorsPerShift: operators,
    note: note,
    createdAt: now,
  );

  test('consecutive days of one entry fold into a range', () {
    final groups = groupExceptions([
      day('a', 24),
      day('b', 25),
      day('c', 26),
      day('d', 27),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.from, DateTime(2026, 12, 24));
    expect(groups.single.to, DateTime(2026, 12, 27));
    expect(groups.single.days, 4);
    expect(groups.single.ids, ['a', 'b', 'c', 'd']);
  });

  test('a gap starts a new range', () {
    final groups = groupExceptions([day('a', 24), day('b', 26)]);

    expect(groups.map((g) => g.days), [1, 1]);
  });

  test('the same days at different scopes stay apart', () {
    // A plant-wide shutdown and a workcenter opened inside it are two
    // entries, and merging them would hide the override (§4.3).
    final groups = groupExceptions([
      day('a', 24),
      day('b', 25),
      day(
        'c',
        24,
        kind: CalendarExceptionKind.extraWorking,
        scope: CalendarExceptionScope.workcenter,
        scopeId: 'wc-1',
        operators: '1/0/0',
      ),
    ]);

    expect(groups, hasLength(2));
    final override = groups.firstWhere(
      (g) => g.scope == CalendarExceptionScope.workcenter,
    );
    expect(override.operatorsPerShift, [1, 0, 0]);
    expect(override.days, 1);
  });

  test('a change of staffing mid-range starts a new one', () {
    final groups = groupExceptions([
      day(
        'a',
        24,
        kind: CalendarExceptionKind.extraWorking,
        operators: '1/1/1',
      ),
      day(
        'b',
        25,
        kind: CalendarExceptionKind.extraWorking,
        operators: '1/0/0',
      ),
    ]);

    expect(groups, hasLength(2));
  });

  test('rows arrive in any order and still fold', () {
    final groups = groupExceptions([day('c', 26), day('a', 24), day('b', 25)]);

    expect(groups.single.days, 3);
    expect(groups.single.ids, ['a', 'b', 'c']);
  });

  test('groups come back in date order, whatever their scope', () {
    final groups = groupExceptions([
      day('a', 25, month: 12),
      day(
        'b',
        3,
        month: 10,
        scope: CalendarExceptionScope.workcenter,
        scopeId: 'wc-1',
      ),
    ]);

    expect(groups.map((g) => g.from.month), [10, 12]);
  });

  test('nothing is nothing', () {
    expect(groupExceptions(const []), isEmpty);
  });
}
