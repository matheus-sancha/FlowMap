/// Turning a block of raw grid cells into what it asks the demand table to
/// become (DESIGN.md §9).
///
/// A typed cell is a 1×1 block and a paste from Excel is a rectangle, so both
/// arrive here. Pure and free of Drift, so every rule — which rows append, which
/// renames are refused, what an emptied cell means — is a unit test rather than
/// a widget one.
library;

import '../../../common/date_input.dart';
import '../../../common/duration_input.dart';
import '../../../data/database/database.dart';
import '../data/demand_repository.dart';
import 'demand_table.dart';

/// Fixed columns of the parts grid, before the flow's steps begin.
const partNumberColumn = 0;
const partDescriptionColumn = 1;
const firstStepColumn = 2;

/// Columns of the sequence grid.
const orderNumberColumn = 0;
const orderPartColumn = 1;
const orderBatchColumn = 2;
const orderNeedColumn = 3;
const orderMaterialColumn = 4;

/// Reads a block anchored at ([row], [column]) of the parts grid.
///
/// Rows past the end of the table append parts, and only when the block says
/// what they are called: without a part number there is nothing to key a
/// process time to, so such a row is skipped rather than guessed at.
///
/// A cell that cannot be read is left out of the plan. The grid is already
/// showing the user why, and writing a value nobody typed is the one failure
/// §11 will not tolerate.
DemandPartsPlan planPartsWrite({
  required DemandTable table,
  required int row,
  required int column,
  required List<List<String>> block,
}) {
  final parts = <PartWrite>[];
  final times = <PartTimeWrite>[];

  // Lower-cased part number → the part number as it is actually spelled.
  // Grows as the block names new parts, so a block naming the same part twice
  // creates it once, and a re-paste of rows already in the table writes into
  // them rather than colliding with the unique key.
  final known = {
    for (final part in table.parts)
      part.partNumber.toLowerCase(): part.partNumber,
  };

  for (var r = 0; r < block.length; r++) {
    final cells = block[r];
    final rowIndex = row + r;

    String? cellAt(int gridColumn) {
      final index = gridColumn - column;
      return index >= 0 && index < cells.length ? cells[index] : null;
    }

    final typedNumber = cellAt(partNumberColumn)?.trim();
    final typedDescription = cellAt(partDescriptionColumn)?.trim();
    final existing = rowIndex < table.parts.length
        ? table.parts[rowIndex]
        : null;

    final String partNumber;
    if (existing == null) {
      if (typedNumber == null || typedNumber.isEmpty) continue;

      final alreadyThere = known[typedNumber.toLowerCase()];
      partNumber = alreadyThere ?? typedNumber;
      if (alreadyThere == null) {
        parts.add(
          PartWrite(
            id: null,
            partNumber: typedNumber,
            description: (typedDescription?.isEmpty ?? true)
                ? null
                : typedDescription,
          ),
        );
        known[typedNumber.toLowerCase()] = typedNumber;
      }
    } else {
      final renamed =
          typedNumber != null &&
          typedNumber.isNotEmpty &&
          typedNumber.toLowerCase() != existing.partNumber.toLowerCase();
      // A rename onto a number the study already carries would hit the unique
      // key inside an async callback, where the user sees nothing happen. The
      // cell reports it; the plan simply keeps the old name.
      final collides = renamed && known.containsKey(typedNumber.toLowerCase());
      final redescribed =
          typedDescription != null &&
          typedDescription != (existing.description ?? '');

      partNumber = renamed && !collides ? typedNumber : existing.partNumber;

      if ((renamed && !collides) || redescribed) {
        parts.add(
          PartWrite(
            id: existing.id,
            partNumber: partNumber,
            description: redescribed
                ? (typedDescription.isEmpty ? null : typedDescription)
                : existing.description,
          ),
        );
        if (renamed && !collides) {
          known.remove(existing.partNumber.toLowerCase());
          known[partNumber.toLowerCase()] = partNumber;
        }
      }
    }

    for (var c = 0; c < table.columns.length; c++) {
      final raw = cellAt(firstStepColumn + c);
      final targetId = table.columns[c].targetId;
      // An unbound step has nothing to key a time to, so its column is
      // read-only and a pasted value for it is dropped (§11).
      if (raw == null || targetId == null) continue;

      final text = raw.trim();
      if (text.isEmpty) {
        times.add(
          PartTimeWrite(partNumber: partNumber, targetId: targetId, time: null),
        );
        continue;
      }
      final parsed = parseDurationInput(text);
      if (parsed == null) continue;
      times.add(
        PartTimeWrite(partNumber: partNumber, targetId: targetId, time: parsed),
      );
    }
  }

  return DemandPartsPlan(parts: parts, times: times);
}

/// Reads a block anchored at ([row], [column]) of the sequence grid.
///
/// A row past the end appends an order, and only when the block carries both a
/// part the study knows and a need date: those two are what an order *is*, and
/// §11 forbids defaulting either. An unreadable cell leaves the stored value
/// alone; an emptied optional cell clears it.
List<OrderWrite> planSequenceWrite({
  required List<DemandOrder> orders,
  required List<DemandPart> parts,
  required int row,
  required int column,
  required List<List<String>> block,
  required String locale,
}) {
  final byNumber = {
    for (final part in parts) part.partNumber.toLowerCase(): part.id,
  };
  final writes = <OrderWrite>[];

  for (var r = 0; r < block.length; r++) {
    final cells = block[r];
    final rowIndex = row + r;

    String? cellAt(int gridColumn) {
      final index = gridColumn - column;
      return index >= 0 && index < cells.length ? cells[index] : null;
    }

    final existing = rowIndex < orders.length ? orders[rowIndex] : null;

    final typedPart = cellAt(orderPartColumn)?.trim();
    final partId = typedPart == null || typedPart.isEmpty
        ? existing?.partId
        : byNumber[typedPart.toLowerCase()];
    if (partId == null) continue;

    final typedNeed = cellAt(orderNeedColumn)?.trim();
    final needDate = typedNeed == null || typedNeed.isEmpty
        ? existing?.needDate
        : parseDateInput(typedNeed, locale);
    if (needDate == null) continue;

    final typedMaterial = cellAt(orderMaterialColumn);
    final materialDate = typedMaterial == null
        ? existing?.materialDate
        : (typedMaterial.trim().isEmpty
              ? null
              : parseDateInput(typedMaterial.trim(), locale) ??
                    existing?.materialDate);

    final typedBatch = cellAt(orderBatchColumn)?.trim();
    final batchSize =
        (typedBatch == null || typedBatch.isEmpty
            ? existing?.batchSize
            : int.tryParse(typedBatch)) ??
        1;
    if (batchSize <= 0) continue;

    final typedNumber = cellAt(orderNumberColumn)?.trim();
    final orderNumber = typedNumber == null
        ? existing?.orderNumber
        : (typedNumber.isEmpty ? null : typedNumber);

    writes.add(
      OrderWrite(
        id: existing?.id,
        partId: partId,
        needDate: needDate,
        materialDate: materialDate,
        batchSize: batchSize,
        orderNumber: orderNumber,
      ),
    );
  }

  return writes;
}
