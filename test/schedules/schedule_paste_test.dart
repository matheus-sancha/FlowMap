import 'package:flowmap/src/common/date_input.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/schedules/application/schedule_paste.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// What a block of typed or pasted cells asks a dated schedule to become
/// (DESIGN.md §12.6).
void main() {
  setUpAll(initializeDateFormatting);

  final now = DateTime(2026, 8, 15);
  const dates = DateStyle(
    locale: 'en',
    setting: DateFormatSetting.isoDate,
  );

  TaktPeriod takt(
    String id,
    DateTime start,
    DateTime end, {
    double value = 3,
    TaktUnit unit = TaktUnit.days,
  }) => TaktPeriod(
    id: id,
    projectId: 'proj-1',
    productionLineId: 'line-1',
    startDate: start,
    endDate: end,
    taktValue: value,
    taktUnit: unit,
    createdAt: now,
    updatedAt: now,
  );

  WorkcenterSchedulePeriod schedule(
    String id,
    DateTime start,
    DateTime end, {
    String operators = '1/1/1',
    double availability = 1,
    double rework = 0,
  }) => WorkcenterSchedulePeriod(
    id: id,
    projectId: 'proj-1',
    workcenterId: 'wc-1',
    startDate: start,
    endDate: end,
    operatorsPerShift: operators,
    availability: availability,
    rework: rework,
    createdAt: now,
    updatedAt: now,
  );

  group('the takt grid', () {
    final periods = [
      takt('p1', DateTime(2026, 1, 1), DateTime(2026, 6, 30)),
      takt('p2', DateTime(2026, 7, 1), DateTime(2026, 12, 31), value: 4),
    ];

    test('one typed cell updates one row and leaves the rest alone', () {
      final writes = planTaktWrite(
        periods: periods,
        row: 1,
        column: 2,
        block: [
          ['2.5'],
        ],
        dates: dates,
      );

      expect(writes, hasLength(1));
      expect(writes.single.id, 'p2');
      expect(writes.single.takt, 2.5);
      // Everything the block did not mention is carried over rather than
      // defaulted, which is what makes a single-cell edit a single-cell edit.
      expect(writes.single.unit, TaktUnit.days);
      expect(writes.single.startDate, DateTime(2026, 7, 1));
      expect(writes.single.endDate, DateTime(2026, 12, 31));
    });

    test('a pasted block writes each row once', () {
      // Four columns across two rows — the shape that arrives from Excel. Each
      // row is one write, so a row cannot land half-applied.
      final writes = planTaktWrite(
        periods: periods,
        row: 0,
        column: 0,
        block: [
          ['2026-01-01', '2026-03-31', '2', 'days'],
          ['2026-04-01', '2026-12-31', '90', 'min'],
        ],
        dates: dates,
      );

      expect(writes.map((w) => w.id), ['p1', 'p2']);
      expect(writes[0].endDate, DateTime(2026, 3, 31));
      expect(writes[1].takt, 90);
      expect(writes[1].unit, TaktUnit.minutes);
    });

    test('a block written in another language still lands', () {
      // The case paste exists for: a spreadsheet written in Portuguese, pasted
      // into an English UI. The parser is language-independent even though the
      // display is not (§9.2).
      final writes = planTaktWrite(
        periods: periods,
        row: 0,
        column: 3,
        block: [
          ['dias'],
          ['horas'],
        ],
        dates: dates,
      );

      expect(writes.map((w) => w.unit), [TaktUnit.days, TaktUnit.hours]);
    });

    test('a row past the end appends, with the suggestions the dialog made', () {
      final writes = planTaktWrite(
        periods: periods,
        row: 2,
        column: 2,
        block: [
          ['5'],
        ],
        dates: dates,
      );

      expect(writes.single.id, isNull, reason: 'a create, not an update');
      expect(writes.single.takt, 5);
      // The day after the last period ends, running to the end of that year —
      // exactly what the editor used to propose.
      expect(writes.single.startDate, DateTime(2027, 1, 1));
      expect(writes.single.endDate, DateTime(2027, 12, 31));
      expect(writes.single.unit, TaktUnit.days);
    });

    test('appending several rows staggers them', () {
      // Without carrying the end date forward, every appended row would take
      // the same suggested start and the schedule would be a stack of
      // overlapping periods nobody asked for.
      final writes = planTaktWrite(
        periods: periods,
        row: 2,
        column: 2,
        block: [
          ['1'],
          ['2'],
        ],
        dates: dates,
      );

      expect(writes, hasLength(2));
      expect(writes[0].startDate, DateTime(2027, 1, 1));
      expect(writes[1].startDate, DateTime(2028, 1, 1));
    });

    test('an unreadable cell changes nothing around it', () {
      // The grid is already showing the user why it is refused. Rewriting the
      // row around a cell that did not parse would write a value nobody typed,
      // which is §11's one intolerable failure.
      final writes = planTaktWrite(
        periods: periods,
        row: 0,
        column: 0,
        block: [
          ['not a date', '', 'not a number', 'weeks'],
        ],
        dates: dates,
      );

      expect(writes.single.startDate, DateTime(2026, 1, 1));
      expect(writes.single.endDate, DateTime(2026, 6, 30));
      expect(writes.single.takt, 3);
      expect(writes.single.unit, TaktUnit.days);
    });

    test('a blank row past the end creates nothing', () {
      // A paste one row too tall is the ordinary way this happens.
      final writes = planTaktWrite(
        periods: periods,
        row: 2,
        column: 0,
        block: [
          ['', '', '', ''],
        ],
        dates: dates,
      );

      expect(writes, isEmpty);
    });
  });

  group('a workcenter schedule grid', () {
    final periods = [
      schedule('s1', DateTime(2026, 1, 1), DateTime(2026, 12, 31)),
    ];

    test('availability accepts a percentage, a bare number or a fraction', () {
      for (final text in ['74%', '74', '0.74']) {
        final writes = planSchedulePeriodWrite(
          periods: periods,
          row: 0,
          column: 4,
          block: [
            [text],
          ],
          dates: dates,
          shiftCount: 3,
        );
        expect(writes.single.availability, closeTo(0.74, 1e-9), reason: text);
        expect(writes.single.rework, 0, reason: 'untouched by this block');
      }
    });

    test('a new row is staffed to the pattern, available, and rework-free', () {
      final writes = planSchedulePeriodWrite(
        periods: periods,
        row: 1,
        column: 0,
        block: [
          ['2027-01-01'],
        ],
        dates: dates,
        shiftCount: 3,
      );

      expect(writes.single.id, isNull);
      expect(writes.single.operatorsPerShift, [1, 1, 1]);
      expect(writes.single.availability, 1);
      expect(writes.single.rework, 0);
      // The plant as it would be on a good day, which is the honest thing to
      // assume before anyone has said otherwise.
    });

    test('the operators codec round-trips through a paste', () {
      final writes = planSchedulePeriodWrite(
        periods: periods,
        row: 0,
        column: 3,
        block: [
          ['2/1/0'],
        ],
        dates: dates,
        shiftCount: 3,
      );

      expect(writes.single.operatorsPerShift, [2, 1, 0]);
    });

    test('an emptied staffing cell keeps what was there', () {
      // Blank is not an instruction to unstaff a station: `staffing_codec`
      // reads an unreadable entry as zero operators, and letting a blank mean
      // that would take a station's capacity away by accident.
      final writes = planSchedulePeriodWrite(
        periods: periods,
        row: 0,
        column: 3,
        block: [
          [''],
        ],
        dates: dates,
        shiftCount: 3,
      );

      expect(writes.single.operatorsPerShift, [1, 1, 1]);
    });

    test('a block anchored past a column says nothing about the ones before', () {
      // Anchoring is what makes "supplied nothing" different from "supplied a
      // blank", and only the second is an instruction.
      final writes = planSchedulePeriodWrite(
        periods: periods,
        row: 0,
        column: 5,
        block: [
          ['3.7%'],
        ],
        dates: dates,
        shiftCount: 3,
      );

      expect(writes.single.rework, closeTo(0.037, 1e-9));
      expect(writes.single.availability, 1);
      expect(writes.single.startDate, DateTime(2026, 1, 1));
    });
  });
}
