/// Mapping a spreadsheet onto the demand grids, and saying what will not go in
/// (DESIGN.md §9).
///
/// Two steps, both pure: a **mapping** from the file's columns to ours, then a
/// **validation** that reports row by row. Nothing here writes; the caller
/// hands the resulting plan to the repository only once the user has accepted
/// it, which is what makes "nothing is written until accepted" true rather than
/// aspirational.
library;

import '../../../common/date_input.dart';
import '../../../common/duration_input.dart';
import '../data/demand_repository.dart';
import 'demand_paste.dart';
import 'demand_table.dart';

/// Which grid an import is filling.
enum ImportTarget { parts, sequence }

/// One destination column an import can fill.
class ImportColumn {
  const ImportColumn({
    required this.gridColumn,
    required this.title,
    this.required = false,
    this.synonyms = const [],
  });

  /// Index in the destination grid's own column list, so the planners below
  /// speak the same coordinates as a paste does.
  final int gridColumn;

  /// What the mapping step calls it — for a step column, the process box's own
  /// title, which is how a workcenter column is matched by name.
  final String title;

  /// A row missing this cannot be imported at all.
  final bool required;

  /// Other headings that mean the same thing, so the usual export does not
  /// need mapping by hand.
  final List<String> synonyms;
}

/// The destination columns of the parts grid: the two fixed ones, then the
/// flow's steps.
List<ImportColumn> partsImportColumns(
  DemandTable table, {
  required String partNumberTitle,
  required String projectTitle,
  required String descriptionTitle,
}) => [
  ImportColumn(
    gridColumn: partNumberColumn,
    title: partNumberTitle,
    required: true,
    synonyms: const ['part', 'part no', 'part number', 'pn', 'item', 'sku'],
  ),
  ImportColumn(
    gridColumn: partProjectColumn,
    title: projectTitle,
    synonyms: const ['project', 'programme', 'program', 'job', 'contract'],
  ),
  ImportColumn(
    gridColumn: partDescriptionColumn,
    title: descriptionTitle,
    synonyms: const ['description', 'desc', 'name'],
  ),
  for (var i = 0; i < table.columns.length; i++)
    ImportColumn(
      gridColumn: firstStepColumn + i,
      title: table.columns[i].title,
    ),
];

/// The destination columns of the sequence grid.
/// **`batch` and `lot` on their own match nothing here.** They are exactly what
/// a column of batch *numbers* is headed and exactly what a column of batch
/// *sizes* is headed, and guessing wrong writes someone's lot identifier into
/// a quantity — silently, in every row, which is the one failure §11 will not
/// tolerate. An ambiguous heading is listed for the user to place by hand,
/// which is §9.2's rule about position applied to names.
List<ImportColumn> sequenceImportColumns({
  required String partNumberTitle,
  required String projectTitle,
  required String batchNumberTitle,
  required String batchTitle,
  required String needDateTitle,
  required String materialDateTitle,
}) => [
  ImportColumn(
    gridColumn: orderPartColumn,
    title: partNumberTitle,
    required: true,
    synonyms: const ['part', 'part no', 'part number', 'pn', 'item', 'sku'],
  ),
  ImportColumn(
    gridColumn: orderProjectColumn,
    title: projectTitle,
    synonyms: const ['project', 'programme', 'program', 'job', 'contract'],
  ),
  ImportColumn(
    gridColumn: orderBatchNumberColumn,
    title: batchNumberTitle,
    synonyms: const [
      'batch number',
      'batch no',
      'batch id',
      'lot number',
      'lot no',
      'lot id',
    ],
  ),
  ImportColumn(
    gridColumn: orderBatchColumn,
    title: batchTitle,
    synonyms: const ['batch size', 'lot size', 'qty', 'quantity', 'size'],
  ),
  ImportColumn(
    gridColumn: orderNeedColumn,
    title: needDateTitle,
    required: true,
    synonyms: const ['need date', 'due date', 'due', 'required date'],
  ),
  ImportColumn(
    gridColumn: orderMaterialColumn,
    title: materialDateTitle,
    synonyms: const [
      'material date',
      'material',
      'material delivery',
      'release date',
    ],
  ),
];

/// Guesses which source column feeds each of ours, by heading.
///
/// Case- and punctuation-insensitive, exact match first and then the synonyms,
/// so `PART_NO` finds Part number and `CLAD04` finds the CLAD04 step. A column
/// it cannot place is left unmapped and listed for the user rather than
/// guessed at by position — a file whose columns happen to be in our order is
/// not evidence that they mean what we think.
Map<int, int?> guessMapping({
  required List<String> headers,
  required List<ImportColumn> columns,
}) {
  final normalized = [for (final header in headers) _normalize(header)];
  final taken = <int>{};
  final mapping = <int, int?>{};

  int? findExact(String text) {
    final key = _normalize(text);
    if (key.isEmpty) return null;
    for (var i = 0; i < normalized.length; i++) {
      if (!taken.contains(i) && normalized[i] == key) return i;
    }
    return null;
  }

  for (final column in columns) {
    var found = findExact(column.title);
    for (final synonym in column.synonyms) {
      if (found != null) break;
      found = findExact(synonym);
    }
    if (found != null) taken.add(found);
    mapping[column.gridColumn] = found;
  }
  return mapping;
}

String _normalize(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Why a row cannot be imported, or should be looked at first.
enum ImportIssueKind {
  /// No part number at all — there is nothing to key the row to.
  missingPartNumber,

  /// A part number the study does not carry. Blocking on the sequence, where
  /// an order must point at a part; on the parts grid it simply creates one.
  unknownPart,

  /// Two rows of the file claim the same part.
  duplicatePartNumber,

  /// A date that cannot be read, or a negative or unreadable time.
  badDate,
  badTime,
  badBatchSize,

  /// A need date before the material is on hand — buildable, but not on time
  /// (§11: a warning, not an error).
  needBeforeMaterial,

  /// A required cell left empty.
  missingRequired,
}

class ImportIssue {
  const ImportIssue({
    required this.kind,
    required this.gridColumn,
    required this.blocking,
  });

  final ImportIssueKind kind;

  /// Which destination column it is about, or null for the whole row.
  final int? gridColumn;

  /// Blocking rows are skipped; the rest are imported and reported.
  final bool blocking;
}

/// One row of the file, mapped and checked.
class ImportRow {
  const ImportRow({
    required this.sourceRow,
    required this.cells,
    required this.issues,
  });

  /// One-based line in the file, so the preview names the row the user can go
  /// and look at.
  final int sourceRow;

  /// Destination column → raw text. Only mapped columns are present; a column
  /// the file does not carry is absent, and absent means "leave alone" rather
  /// than "clear".
  final Map<int, String> cells;

  final List<ImportIssue> issues;

  bool get isBlocked => issues.any((issue) => issue.blocking);
  bool get hasWarnings => issues.any((issue) => !issue.blocking);

  String? cell(int gridColumn) {
    final value = cells[gridColumn]?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }
}

/// Applies [mapping] to the file's data rows.
List<Map<int, String>> applyMapping({
  required List<List<String>> dataRows,
  required Map<int, int?> mapping,
}) => [
  for (final row in dataRows)
    {
      for (final entry in mapping.entries)
        if (entry.value case final source?)
          if (source < row.length) entry.key: row[source],
    },
];

/// Checks rows destined for the parts grid.
List<ImportRow> validatePartsImport({
  required List<Map<int, String>> rows,
  required DemandTable table,
  required int firstSourceRow,
}) {
  final seen = <String>{};
  final checked = <ImportRow>[];

  for (var i = 0; i < rows.length; i++) {
    final cells = rows[i];
    final issues = <ImportIssue>[];
    final row = ImportRow(
      sourceRow: firstSourceRow + i,
      cells: cells,
      issues: issues,
    );

    final partNumber = row.cell(partNumberColumn);
    if (partNumber == null) {
      issues.add(
        const ImportIssue(
          kind: ImportIssueKind.missingPartNumber,
          gridColumn: partNumberColumn,
          blocking: true,
        ),
      );
    } else if (!seen.add(partNumber.toLowerCase())) {
      // Two rows for one part would silently make the second win. Blocking, so
      // the user fixes the file rather than discovering which one landed.
      issues.add(
        const ImportIssue(
          kind: ImportIssueKind.duplicatePartNumber,
          gridColumn: partNumberColumn,
          blocking: true,
        ),
      );
    }

    for (var c = 0; c < table.columns.length; c++) {
      final gridColumn = firstStepColumn + c;
      final raw = row.cell(gridColumn);
      if (raw == null) continue;
      if (parseDurationInput(raw) == null) {
        issues.add(
          ImportIssue(
            kind: ImportIssueKind.badTime,
            gridColumn: gridColumn,
            blocking: true,
          ),
        );
      }
    }

    checked.add(row);
  }
  return checked;
}

/// Checks rows destined for the sequence grid.
List<ImportRow> validateSequenceImport({
  required List<Map<int, String>> rows,
  required DemandTable table,
  required String locale,
  required int firstSourceRow,
}) {
  final known = {
    for (final part in table.parts)
      partKeyOf(part.customerProject, part.partNumber): part.id,
  };
  final checked = <ImportRow>[];

  for (var i = 0; i < rows.length; i++) {
    final cells = rows[i];
    final issues = <ImportIssue>[];
    final row = ImportRow(
      sourceRow: firstSourceRow + i,
      cells: cells,
      issues: issues,
    );

    final partNumber = row.cell(orderPartColumn);
    if (partNumber == null) {
      issues.add(
        const ImportIssue(
          kind: ImportIssueKind.missingRequired,
          gridColumn: orderPartColumn,
          blocking: true,
        ),
      );
    } else if (!known.containsKey(
      partKeyOf(row.cell(orderProjectColumn) ?? '', partNumber),
    )) {
      // An order for a part the study has never heard of is the commonest
      // import failure there is, and inventing the part would hide a typo.
      issues.add(
        const ImportIssue(
          kind: ImportIssueKind.unknownPart,
          gridColumn: orderPartColumn,
          blocking: true,
        ),
      );
    }

    final needRaw = row.cell(orderNeedColumn);
    final needDate = needRaw == null ? null : parseDateInput(needRaw, locale);
    if (needRaw == null) {
      issues.add(
        const ImportIssue(
          kind: ImportIssueKind.missingRequired,
          gridColumn: orderNeedColumn,
          blocking: true,
        ),
      );
    } else if (needDate == null) {
      issues.add(
        const ImportIssue(
          kind: ImportIssueKind.badDate,
          gridColumn: orderNeedColumn,
          blocking: true,
        ),
      );
    }

    final materialRaw = row.cell(orderMaterialColumn);
    final materialDate = materialRaw == null
        ? null
        : parseDateInput(materialRaw, locale);
    if (materialRaw != null && materialDate == null) {
      issues.add(
        const ImportIssue(
          kind: ImportIssueKind.badDate,
          gridColumn: orderMaterialColumn,
          blocking: true,
        ),
      );
    } else if (needDate != null &&
        materialDate != null &&
        needDate.isBefore(materialDate)) {
      // Wanted before the material arrives. Real data, and late by
      // construction — a warning, not a refusal (§11).
      issues.add(
        const ImportIssue(
          kind: ImportIssueKind.needBeforeMaterial,
          gridColumn: orderNeedColumn,
          blocking: false,
        ),
      );
    }

    final batchRaw = row.cell(orderBatchColumn);
    if (batchRaw != null) {
      final batch = int.tryParse(batchRaw);
      if (batch == null || batch <= 0) {
        issues.add(
          const ImportIssue(
            kind: ImportIssueKind.badBatchSize,
            gridColumn: orderBatchColumn,
            blocking: true,
          ),
        );
      }
    }

    checked.add(row);
  }
  return checked;
}

/// What the accepted rows ask of the parts grid.
///
/// **An unmapped column is left alone, never cleared.** That is the one way an
/// import differs from a paste: a paste's blank cell is a deliberate erasure,
/// and a file that simply does not carry a column has said nothing about it.
DemandPartsPlan planPartsImport({
  required List<ImportRow> rows,
  required DemandTable table,
}) {
  // Keyed by project **and** number: the same part number under two customer
  // projects is two parts (§9.3).
  final existing = {
    for (final part in table.parts)
      partKeyOf(part.customerProject, part.partNumber): part,
  };
  final parts = <PartWrite>[];
  final times = <PartTimeWrite>[];

  for (final row in rows) {
    if (row.isBlocked) continue;
    final partNumber = row.cell(partNumberColumn);
    if (partNumber == null) continue;

    final project = row.cell(partProjectColumn) ?? '';
    final description = row.cell(partDescriptionColumn);
    final partKey = partKeyOf(project, partNumber);
    final was = existing[partKey];

    if (was == null) {
      parts.add(
        PartWrite(
          id: null,
          partNumber: partNumber,
          customerProject: project,
          description: description,
        ),
      );
    } else if (description != null && description != was.description) {
      parts.add(
        PartWrite(
          id: was.id,
          partNumber: was.partNumber,
          // An unmapped column is left alone, never cleared (§9.2).
          customerProject: was.customerProject,
          description: description,
        ),
      );
    }

    for (var c = 0; c < table.columns.length; c++) {
      final targetId = table.columns[c].targetId;
      final raw = row.cell(firstStepColumn + c);
      if (targetId == null || raw == null) continue;
      final parsed = parseDurationInput(raw);
      if (parsed == null) continue;
      times.add(
        PartTimeWrite(partKey: partKey, targetId: targetId, time: parsed),
      );
    }
  }

  return DemandPartsPlan(parts: parts, times: times);
}

/// What the accepted rows ask of the sequence.
///
/// Every row **appends**: an import is a batch of new orders, not an edit of
/// the ones already sequenced. Replacing the sequence is a delete away, and
/// making it implicit would destroy work nobody asked to lose.
List<OrderWrite> planSequenceImport({
  required List<ImportRow> rows,
  required DemandTable table,
  required String locale,
}) {
  final known = {
    for (final part in table.parts)
      partKeyOf(part.customerProject, part.partNumber): part.id,
  };
  final writes = <OrderWrite>[];

  for (final row in rows) {
    if (row.isBlocked) continue;

    final partId = known[partKeyOf(
      row.cell(orderProjectColumn) ?? '',
      row.cell(orderPartColumn)!,
    )];
    final needDate = parseDateInput(row.cell(orderNeedColumn)!, locale);
    if (partId == null || needDate == null) continue;

    final materialRaw = row.cell(orderMaterialColumn);
    // An unmapped column is absent from the row and leaves the field empty —
    // never cleared, because a file that does not carry a column has said
    // nothing about it (§9.2).
    final batchNumber = row.cell(orderBatchNumberColumn)?.trim();
    writes.add(
      OrderWrite(
        id: null,
        partId: partId,
        needDate: needDate,
        batchNumber: (batchNumber?.isEmpty ?? true) ? null : batchNumber,
        materialDate: materialRaw == null
            ? null
            : parseDateInput(materialRaw, locale),
        batchSize: int.tryParse(row.cell(orderBatchColumn) ?? '') ?? 1,
      ),
    );
  }

  return writes;
}

/// Part numbers in the file the study does not carry — what §9's mapping step
/// lists so the user can see what will be skipped before committing to it.
List<String> unknownPartNumbers({
  required List<ImportRow> rows,
  required DemandTable table,
  required int gridColumn,
}) {
  final known = {
    for (final part in table.parts) part.partNumber.toLowerCase(),
  };
  final missing = <String>{};
  for (final row in rows) {
    final partNumber = row.cell(gridColumn);
    if (partNumber != null && !known.contains(partNumber.toLowerCase())) {
      missing.add(partNumber);
    }
  }
  return missing.toList()..sort();
}
