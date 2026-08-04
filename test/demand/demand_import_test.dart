import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/demand/application/demand_import.dart';
import 'package:flowmap/src/features/demand/application/demand_paste.dart';
import 'package:flowmap/src/features/demand/application/demand_table.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Mapping a spreadsheet onto the demand grids, and what it refuses
/// (DESIGN.md §9).
void main() {
  setUpAll(initializeDateFormatting);

  final now = DateTime(2026, 8, 1);

  DemandPart part(String id, String number, {String? description}) => DemandPart(
    id: id,
    studyId: 'study-1',
    partNumber: number,
    description: description,
    createdAt: now,
    updatedAt: now,
  );

  const columns = [
    DemandColumn(nodeId: 'node-0', targetId: 'wc-1', title: 'CLAD04'),
    DemandColumn(nodeId: 'node-1', targetId: 'wc-2', title: 'TTAT'),
  ];

  DemandTable tableWith(List<DemandPart> parts) =>
      DemandTable(parts: parts, columns: columns, times: const {});

  List<ImportColumn> partsColumns(DemandTable table) => partsImportColumns(
    table,
    partNumberTitle: 'Part number',
    descriptionTitle: 'Description',
  );

  final sequenceColumns = sequenceImportColumns(
    orderTitle: 'Order',
    partNumberTitle: 'Part number',
    batchTitle: 'Batch',
    needDateTitle: 'Need date',
    materialDateTitle: 'Material date',
  );

  group('guessMapping', () {
    test('matches a heading however it is punctuated', () {
      final mapping = guessMapping(
        headers: ['PART_NO', 'Description', 'CLAD 04'],
        columns: partsColumns(tableWith([])),
      );

      expect(mapping[partNumberColumn], 0);
      expect(mapping[partDescriptionColumn], 1);
      // Spaces are punctuation too, so `CLAD 04` finds the CLAD04 step.
      expect(mapping[firstStepColumn], 2);
    });

    test('matches a workcenter column by the step\'s own name', () {
      final mapping = guessMapping(
        headers: ['Part number', 'TTAT', 'CLAD04'],
        columns: partsColumns(tableWith([])),
      );

      expect(mapping[firstStepColumn], 2);
      expect(mapping[firstStepColumn + 1], 1);
    });

    test('leaves a column it cannot place unmapped, never by position', () {
      // A file whose columns happen to be in our order is not evidence that
      // they mean what we think.
      final mapping = guessMapping(
        headers: ['col a', 'col b', 'col c'],
        columns: partsColumns(tableWith([])),
      );

      expect(mapping.values.every((v) => v == null), isTrue);
    });

    test('does not give one source column to two of ours', () {
      final mapping = guessMapping(
        headers: ['Part'],
        columns: sequenceColumns,
      );

      final used = mapping.values.whereType<int>().toList();
      expect(used, hasLength(used.toSet().length));
    });

    test('finds the usual export headings through synonyms', () {
      final mapping = guessMapping(
        headers: ['WO', 'SKU', 'Qty', 'Due date', 'Material'],
        columns: sequenceColumns,
      );

      expect(mapping[orderNumberColumn], 0);
      expect(mapping[orderPartColumn], 1);
      expect(mapping[orderBatchColumn], 2);
      expect(mapping[orderNeedColumn], 3);
      expect(mapping[orderMaterialColumn], 4);
    });
  });

  group('applyMapping', () {
    test('an unmapped column is absent, not blank', () {
      // Absent means "leave alone"; blank would mean "clear", and a file that
      // does not carry a column has said nothing about it.
      final mapped = applyMapping(
        dataRows: [
          ['PN1', 'Housing'],
        ],
        mapping: {partNumberColumn: 0, partDescriptionColumn: null},
      );

      expect(mapped.single.containsKey(partNumberColumn), isTrue);
      expect(mapped.single.containsKey(partDescriptionColumn), isFalse);
    });

    test('a short row simply has fewer cells', () {
      final mapped = applyMapping(
        dataRows: [
          ['PN1'],
        ],
        mapping: {partNumberColumn: 0, partDescriptionColumn: 1},
      );

      expect(mapped.single.containsKey(partDescriptionColumn), isFalse);
    });
  });

  group('validatePartsImport', () {
    test('a row with no part number is blocked', () {
      final rows = validatePartsImport(
        rows: applyMapping(
          dataRows: [
            ['', '55:00:00'],
          ],
          mapping: {partNumberColumn: 0, firstStepColumn: 1},
        ),
        table: tableWith([]),
        firstSourceRow: 2,
      );

      expect(rows.single.isBlocked, isTrue);
      expect(rows.single.issues.single.kind, ImportIssueKind.missingPartNumber);
      expect(rows.single.sourceRow, 2);
    });

    test('the same part twice in one file is blocked, not silently merged', () {
      final rows = validatePartsImport(
        rows: applyMapping(
          dataRows: [
            ['PN1'],
            ['pn1'],
          ],
          mapping: {partNumberColumn: 0},
        ),
        table: tableWith([]),
        firstSourceRow: 2,
      );

      expect(rows.first.isBlocked, isFalse);
      expect(rows.last.isBlocked, isTrue);
      expect(
        rows.last.issues.single.kind,
        ImportIssueKind.duplicatePartNumber,
      );
    });

    test('an unreadable time blocks the row', () {
      final rows = validatePartsImport(
        rows: applyMapping(
          dataRows: [
            ['PN1', 'n/a'],
            ['PN2', '-5h'],
            ['PN3', '1.5h'],
          ],
          mapping: {partNumberColumn: 0, firstStepColumn: 1},
        ),
        table: tableWith([]),
        firstSourceRow: 2,
      );

      expect(rows.map((r) => r.isBlocked), [true, true, false]);
    });
  });

  group('validateSequenceImport', () {
    List<ImportRow> validate(List<List<String>> dataRows) =>
        validateSequenceImport(
          rows: applyMapping(
            dataRows: dataRows,
            mapping: {
              orderPartColumn: 0,
              orderBatchColumn: 1,
              orderNeedColumn: 2,
              orderMaterialColumn: 3,
            },
          ),
          table: tableWith([part('p1', 'PN1')]),
          locale: 'en_US',
          firstSourceRow: 2,
        );

    test('an order for a part the study never heard of is blocked', () {
      // Inventing the part would hide a typo — the commonest import failure
      // there is.
      final rows = validate([
        ['PN404', '1', '2026-08-13', ''],
      ]);

      expect(rows.single.isBlocked, isTrue);
      expect(rows.single.issues.single.kind, ImportIssueKind.unknownPart);
    });

    test('an unreadable or missing need date is blocked', () {
      final rows = validate([
        ['PN1', '1', 'soon', ''],
        ['PN1', '1', '', ''],
      ]);

      expect(rows.map((r) => r.isBlocked), [true, true]);
      expect(rows.first.issues.single.kind, ImportIssueKind.badDate);
      expect(rows.last.issues.single.kind, ImportIssueKind.missingRequired);
    });

    test('a need date before the material is a warning, not a refusal', () {
      // Real data, and late by construction: §11 makes this a warning.
      final rows = validate([
        ['PN1', '1', '2026-08-01', '2026-08-10'],
      ]);

      expect(rows.single.isBlocked, isFalse);
      expect(rows.single.hasWarnings, isTrue);
      expect(
        rows.single.issues.single.kind,
        ImportIssueKind.needBeforeMaterial,
      );
    });

    test('a batch size of zero or nonsense is blocked', () {
      final rows = validate([
        ['PN1', '0', '2026-08-13', ''],
        ['PN1', 'ten', '2026-08-13', ''],
        ['PN1', '', '2026-08-13', ''],
      ]);

      expect(rows.map((r) => r.isBlocked), [true, true, false]);
    });
  });

  group('planPartsImport', () {
    test('creates the parts the file names and writes their times', () {
      final table = tableWith([]);
      final rows = validatePartsImport(
        rows: applyMapping(
          dataRows: [
            ['PN1', 'Housing', '55:00:00', '3:00:00'],
          ],
          mapping: {
            partNumberColumn: 0,
            partDescriptionColumn: 1,
            firstStepColumn: 2,
            firstStepColumn + 1: 3,
          },
        ),
        table: table,
        firstSourceRow: 2,
      );

      final plan = planPartsImport(rows: rows, table: table);
      expect(plan.parts.single.partNumber, 'PN1');
      expect(plan.parts.single.description, 'Housing');
      expect(plan.times.map((t) => (t.targetId, t.time)), [
        ('wc-1', const Duration(hours: 55)),
        ('wc-2', const Duration(hours: 3)),
      ]);
    });

    test('an unmapped column is left alone, never cleared', () {
      // The one way an import differs from a paste: a paste's blank cell is a
      // deliberate erasure, and a file missing a column has said nothing.
      final table = tableWith([part('p1', 'PN1', description: 'Housing')]);
      final rows = validatePartsImport(
        rows: applyMapping(
          dataRows: [
            ['PN1', '55:00:00'],
          ],
          mapping: {partNumberColumn: 0, firstStepColumn: 1},
        ),
        table: table,
        firstSourceRow: 2,
      );

      final plan = planPartsImport(rows: rows, table: table);
      // No PartWrite at all: the description was not mentioned, so it stands.
      expect(plan.parts, isEmpty);
      expect(plan.times.single.targetId, 'wc-1');
      // And nothing asks TTAT to be cleared.
      expect(plan.times.map((t) => t.targetId), isNot(contains('wc-2')));
    });

    test('a blocked row contributes nothing', () {
      final table = tableWith([]);
      final rows = validatePartsImport(
        rows: applyMapping(
          dataRows: [
            ['PN1', 'n/a'],
            ['PN2', '3:00:00'],
          ],
          mapping: {partNumberColumn: 0, firstStepColumn: 1},
        ),
        table: table,
        firstSourceRow: 2,
      );

      final plan = planPartsImport(rows: rows, table: table);
      expect(plan.parts.map((p) => p.partNumber), ['PN2']);
      expect(plan.times.single.partNumber, 'PN2');
    });
  });

  group('planSequenceImport', () {
    test('every accepted row appends an order', () {
      // An import is a batch of new orders, not an edit of the sequence:
      // replacing it implicitly would destroy work nobody asked to lose.
      final table = tableWith([part('p1', 'PN1')]);
      final rows = validateSequenceImport(
        rows: applyMapping(
          dataRows: [
            ['SO-1', 'PN1', '4', '2026-08-13', '2026-08-01'],
            ['SO-2', 'PN9', '1', '2026-08-14', ''],
          ],
          mapping: {
            orderNumberColumn: 0,
            orderPartColumn: 1,
            orderBatchColumn: 2,
            orderNeedColumn: 3,
            orderMaterialColumn: 4,
          },
        ),
        table: table,
        locale: 'en_US',
        firstSourceRow: 2,
      );

      final writes = planSequenceImport(
        rows: rows,
        table: table,
        locale: 'en_US',
      );

      expect(writes, hasLength(1));
      expect(writes.single.isNew, isTrue);
      expect(writes.single.orderNumber, 'SO-1');
      expect(writes.single.batchSize, 4);
      expect(writes.single.needDate, DateTime(2026, 8, 13));
      expect(writes.single.materialDate, DateTime(2026, 8, 1));
    });

    test('a missing batch size is one, which is what an order without one is', () {
      final table = tableWith([part('p1', 'PN1')]);
      final rows = validateSequenceImport(
        rows: applyMapping(
          dataRows: [
            ['PN1', '2026-08-13'],
          ],
          mapping: {orderPartColumn: 0, orderNeedColumn: 1},
        ),
        table: table,
        locale: 'en_US',
        firstSourceRow: 2,
      );

      final writes = planSequenceImport(
        rows: rows,
        table: table,
        locale: 'en_US',
      );
      expect(writes.single.batchSize, 1);
    });
  });

  test('unknownPartNumbers lists what will be skipped, before committing', () {
    final table = tableWith([part('p1', 'PN1')]);
    final rows = validateSequenceImport(
      rows: applyMapping(
        dataRows: [
          ['PN1', '2026-08-13'],
          ['PN404', '2026-08-13'],
          ['PN405', '2026-08-13'],
          ['PN404', '2026-08-14'],
        ],
        mapping: {orderPartColumn: 0, orderNeedColumn: 1},
      ),
      table: table,
      locale: 'en_US',
      firstSourceRow: 2,
    );

    expect(
      unknownPartNumbers(
        rows: rows,
        table: table,
        gridColumn: orderPartColumn,
      ),
      ['PN404', 'PN405'],
    );
  });
}
