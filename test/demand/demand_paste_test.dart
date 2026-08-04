import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/demand/application/demand_paste.dart';
import 'package:flowmap/src/features/demand/application/demand_table.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// What a typed cell or a block pasted from Excel asks the demand table to
/// become (DESIGN.md §9).
void main() {
  // `DateFormat.yMd(locale)` needs its locale data. The app gets that from
  // flutter_localizations; a plain unit test has to ask.
  setUpAll(initializeDateFormatting);

  final now = DateTime(2026, 8, 1);

  DemandPart part(
    String id,
    String number, {
    String? description,
    String? project,
  }) => DemandPart(
    id: id,
    studyId: 'study-1',
    partNumber: number,
    customerProject: project,
    description: description,
    createdAt: now,
    updatedAt: now,
  );

  DemandOrder order(
    String id,
    int sequence,
    String partId, {
    int day = 13,
    int batchSize = 1,
    DateTime? materialDate,
  }) => DemandOrder(
    id: id,
    studyId: 'study-1',
    partId: partId,
    sequence: sequence,
    batchSize: batchSize,
    needDate: DateTime(2026, 8, day),
    materialDate: materialDate,
    createdAt: now,
    updatedAt: now,
  );

  const columns = [
    DemandColumn(nodeId: 'node-0', targetId: 'wc-1', title: 'CLAD04'),
    DemandColumn(nodeId: 'node-1', targetId: 'wc-2', title: 'TTAT'),
  ];

  DemandTable tableWith(
    List<DemandPart> parts, {
    Map<String, Map<String, Duration>> times = const {},
    List<DemandColumn> withColumns = columns,
  }) => DemandTable(parts: parts, columns: withColumns, times: times);

  group('planPartsWrite', () {
    test('a block on the blank last row appends parts', () {
      final plan = planPartsWrite(
        table: tableWith([]),
        row: 0,
        column: 0,
        block: [
          ['PN1', 'Wing 7', 'Housing', '55:00:00', '3:00:00'],
          ['PN2', '', '', '8:00:00', ''],
        ],
      );

      expect(plan.parts.map((p) => p.partNumber), ['PN1', 'PN2']);
      expect(plan.parts.every((p) => p.isNew), isTrue);
      expect(plan.parts.first.customerProject, 'Wing 7');
      expect(plan.parts.first.description, 'Housing');
      expect(plan.parts.last.customerProject, isNull);
      expect(plan.parts.last.description, isNull);

      expect(
        plan.times.map((t) => (t.partNumber, t.targetId, t.time)),
        [
          ('PN1', 'wc-1', const Duration(hours: 55)),
          ('PN1', 'wc-2', const Duration(hours: 3)),
          ('PN2', 'wc-1', const Duration(hours: 8)),
          // Blank in the middle of a pasted row means "skips this step", and
          // says so explicitly rather than being dropped (§5.1).
          ('PN2', 'wc-2', null),
        ],
      );
    });

    test('a row with no part number is skipped, not invented', () {
      final plan = planPartsWrite(
        table: tableWith([]),
        row: 0,
        column: 0,
        block: [
          ['', '', '', '55:00:00'],
        ],
      );

      expect(plan.isEmpty, isTrue);
    });

    test('a re-pasted block writes into the parts it names', () {
      final plan = planPartsWrite(
        table: tableWith([part('p1', 'PN1')]),
        // Anchored on the blank appending row, as a second paste would be.
        row: 1,
        column: 0,
        block: [
          ['PN1', '', '', '60:00:00'],
        ],
      );

      // No second PN1: the unique key would have refused it, and the user's
      // intent was plainly to update.
      expect(plan.parts, isEmpty);
      expect(plan.times.single.partNumber, 'PN1');
      expect(plan.times.single.time, const Duration(hours: 60));
    });

    test('a block naming the same new part twice creates it once', () {
      final plan = planPartsWrite(
        table: tableWith([]),
        row: 0,
        column: 0,
        block: [
          ['PN1', '', '', '55:00:00'],
          ['PN1', '', '', '60:00:00'],
        ],
      );

      expect(plan.parts, hasLength(1));
      expect(plan.times.map((t) => t.time), [
        const Duration(hours: 55),
        const Duration(hours: 60),
      ]);
    });

    test('a rename onto a number the study already carries is refused', () {
      final plan = planPartsWrite(
        table: tableWith([part('p1', 'PN1'), part('p2', 'PN2')]),
        row: 0,
        column: partNumberColumn,
        block: [
          ['PN2'],
        ],
      );

      // Silently keeping the old name would be wrong; so would a write that
      // throws inside an async callback where the user sees nothing happen.
      // The cell reports it and the plan asks for nothing.
      expect(plan.isEmpty, isTrue);
    });

    test('a rename onto a free number goes through', () {
      final plan = planPartsWrite(
        table: tableWith([part('p1', 'PN1', description: 'Housing')]),
        row: 0,
        column: partNumberColumn,
        block: [
          ['PN9'],
        ],
      );

      expect(plan.parts.single.id, 'p1');
      expect(plan.parts.single.partNumber, 'PN9');
      expect(
        plan.parts.single.description,
        'Housing',
        reason: 'a column the block did not touch keeps its value',
      );
    });

    test('a cell that cannot be read is left out', () {
      final plan = planPartsWrite(
        table: tableWith([part('p1', 'PN1')]),
        row: 0,
        column: firstStepColumn,
        block: [
          ['n/a', '3:00:00'],
        ],
      );

      expect(plan.times.map((t) => t.targetId), ['wc-2']);
    });

    test('an emptied time cell clears it', () {
      final plan = planPartsWrite(
        table: tableWith(
          [part('p1', 'PN1')],
          times: {
            'p1': {'wc-1': const Duration(hours: 55)},
          },
        ),
        row: 0,
        column: firstStepColumn,
        block: [
          [''],
        ],
      );

      expect(plan.times.single.time, isNull);
    });

    test('an unbound step takes nothing, wherever the block puts it', () {
      final plan = planPartsWrite(
        table: tableWith(
          [part('p1', 'PN1')],
          withColumns: const [
            DemandColumn(nodeId: 'node-0', targetId: null, title: '—'),
            DemandColumn(nodeId: 'node-1', targetId: 'wc-2', title: 'TTAT'),
          ],
        ),
        row: 0,
        column: firstStepColumn,
        block: [
          ['55:00:00', '3:00:00'],
        ],
      );

      expect(plan.times.map((t) => t.targetId), ['wc-2']);
    });

    test('a block anchored past the last column stops at the edge', () {
      final plan = planPartsWrite(
        table: tableWith([part('p1', 'PN1')]),
        row: 0,
        column: firstStepColumn + 1,
        block: [
          ['3:00:00', '99:00:00'],
        ],
      );

      // The second value falls on the read-only Total column and is dropped
      // rather than wrapping onto the next row.
      expect(plan.times.map((t) => (t.targetId, t.time)), [
        ('wc-2', const Duration(hours: 3)),
      ]);
    });
  });

  group('planSequenceWrite', () {
    final parts = [part('p1', 'PN1'), part('p2', 'PN2')];

    test('a block on the blank last row appends orders', () {
      final writes = planSequenceWrite(
        orders: const [],
        parts: parts,
        row: 0,
        column: 0,
        block: [
          ['PN1', '', '4', '2026-08-13', '2026-08-01'],
          ['PN2', '', '1', '2026-08-14', ''],
        ],
        locale: 'en',
      );

      expect(writes.every((w) => w.isNew), isTrue);
      expect(writes.map((w) => w.partId), ['p1', 'p2']);
      expect(writes.first.batchSize, 4);
      expect(writes.first.needDate, DateTime(2026, 8, 13));
      expect(writes.first.materialDate, DateTime(2026, 8, 1));
      expect(writes.last.materialDate, isNull);
    });

    test('a new row without a known part is skipped', () {
      final writes = planSequenceWrite(
        orders: const [],
        parts: parts,
        row: 0,
        column: 0,
        block: [
          ['PN404', '', '1', '2026-08-13'],
        ],
        locale: 'en',
      );

      expect(writes, isEmpty);
    });

    test('a new row without a need date is skipped, not dated today', () {
      // §11: gaps are never silently defaulted, and a need date invented here
      // would decide the study's start date (§7.8).
      final writes = planSequenceWrite(
        orders: const [],
        parts: parts,
        row: 0,
        column: 0,
        block: [
          ['PN1', '', '1', ''],
        ],
        locale: 'en',
      );

      expect(writes, isEmpty);
    });

    test('an existing row keeps the columns the block did not touch', () {
      final writes = planSequenceWrite(
        orders: [order('o1', 0, 'p1', batchSize: 4)],
        parts: parts,
        row: 0,
        column: orderBatchColumn,
        block: [
          ['10'],
        ],
        locale: 'en',
      );

      expect(writes.single.id, 'o1');
      expect(writes.single.batchSize, 10);
      expect(writes.single.partId, 'p1');
      expect(writes.single.needDate, DateTime(2026, 8, 13));
    });

    test('an emptied material date clears the constraint', () {
      final writes = planSequenceWrite(
        orders: [
          order('o1', 0, 'p1', materialDate: DateTime(2026, 8, 1)),
        ],
        parts: parts,
        row: 0,
        column: orderMaterialColumn,
        block: [
          [''],
        ],
        locale: 'en',
      );

      expect(writes.single.materialDate, isNull);
    });

    test('a batch size of zero is refused', () {
      final writes = planSequenceWrite(
        orders: [order('o1', 0, 'p1')],
        parts: parts,
        row: 0,
        column: orderBatchColumn,
        block: [
          ['0'],
        ],
        locale: 'en',
      );

      expect(writes, isEmpty);
    });

    test('a locale date is read the way that locale writes it', () {
      final ptBr = planSequenceWrite(
        orders: const [],
        parts: parts,
        row: 0,
        column: 0,
        block: [
          ['PN1', '', '1', '03/08/2026'],
        ],
        locale: 'pt_BR',
      );
      expect(ptBr.single.needDate, DateTime(2026, 8, 3));

      final enUs = planSequenceWrite(
        orders: const [],
        parts: parts,
        row: 0,
        column: 0,
        block: [
          ['PN1', '', '1', '03/08/2026'],
        ],
        locale: 'en_US',
      );
      expect(enUs.single.needDate, DateTime(2026, 3, 8));
    });
  });
}
