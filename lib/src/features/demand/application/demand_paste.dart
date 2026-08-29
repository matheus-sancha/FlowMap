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
///
/// The customer project was here until v14 and is not a property of a part
/// (§9.3), so it went to the sequence with the orders. That shifted
/// [partDescriptionColumn] 2 -> 1 and [firstStepColumn] 3 -> 2, so a paste
/// block a user habitually anchored at a column now lands one to the left.
const partNumberColumn = 0;
const partDescriptionColumn = 1;
const firstStepColumn = 2;

/// Columns of the sequence grid.
///
/// There is still no order number: a simulation identifies an order by the row
/// it is (§7.2), and asking a planner to retype a works order number they
/// already hold in their own system was work for nothing.
///
/// [orderBatchNumberColumn] is a different thing and arrived later — the
/// planner's own label for *this batch of this part*, which a printed
/// production plan has to carry so it can be matched against their paperwork
/// (§8.5). It sits before the size, the order the plan reads in, which pushed
/// the three columns after it along by one.
const orderPartColumn = 0;
const orderProjectColumn = 1;
const orderBatchNumberColumn = 2;
const orderBatchColumn = 3;
const orderNeedColumn = 4;
const orderMaterialColumn = 5;

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

  // Part key → the part it names. Grows as the block names new parts, so a
  // block naming the same part twice creates it once, and a re-paste of rows
  // already in the table writes into them rather than colliding with the
  // unique key.
  //
  // Keyed by number alone since v14: a part number means one part inside a
  // study, and the project it is ordered for lives on the order (§9.3).
  final known = <String, String>{
    for (final part in table.parts) partKeyOf(part.partNumber): part.partNumber,
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

    final String partKey;
    if (existing == null) {
      if (typedNumber == null || typedNumber.isEmpty) continue;

      partKey = partKeyOf(typedNumber);
      if (!known.containsKey(partKey)) {
        parts.add(
          PartWrite(
            id: null,
            partNumber: typedNumber,
            description: (typedDescription?.isEmpty ?? true)
                ? null
                : typedDescription,
          ),
        );
        known[partKey] = typedNumber;
      }
    } else {
      final number = (typedNumber == null || typedNumber.isEmpty)
          ? existing.partNumber
          : typedNumber;
      final wanted = partKeyOf(number);
      final was = partKeyOf(existing.partNumber);

      // Renaming onto a number the study already carries would hit the unique
      // key inside an async callback, where the user sees nothing happen. The
      // cell reports it; the plan keeps what was there.
      final collides = wanted != was && known.containsKey(wanted);
      final renamed = wanted != was && !collides;
      final redescribed =
          typedDescription != null &&
          typedDescription != (existing.description ?? '');

      partKey = renamed ? wanted : was;

      if (renamed || redescribed) {
        parts.add(
          PartWrite(
            id: existing.id,
            partNumber: renamed ? number : existing.partNumber,
            description: redescribed
                ? (typedDescription.isEmpty ? null : typedDescription)
                : existing.description,
          ),
        );
        if (renamed) {
          known.remove(was);
          known[wanted] = number;
        }
      }
    }

    for (var c = 0; c < table.columns.length; c++) {
      final raw = cellAt(firstStepColumn + c);
      final column = table.columns[c];
      // An unbound step has nothing to run the work on, so its column is
      // read-only and a pasted value for it is dropped (§11) — **the guard is
      // still the target even though the write is keyed by the node** (§9).
      if (raw == null || column.targetId == null) continue;

      final text = raw.trim();
      if (text.isEmpty) {
        times.add(
          PartTimeWrite(partKey: partKey, nodeId: column.nodeId, time: null),
        );
        continue;
      }
      final parsed = parseDurationInput(text);
      if (parsed == null) continue;
      times.add(
        PartTimeWrite(partKey: partKey, nodeId: column.nodeId, time: parsed),
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
  required DateStyle dateStyle,
}) {
  final byKey = {for (final part in parts) partKeyOf(part.partNumber): part.id};
  final byId = {for (final part in parts) part.id: part};
  final writes = <OrderWrite>[];

  for (var r = 0; r < block.length; r++) {
    final cells = block[r];
    final rowIndex = row + r;

    String? cellAt(int gridColumn) {
      final index = gridColumn - column;
      return index >= 0 && index < cells.length ? cells[index] : null;
    }

    final existing = rowIndex < orders.length ? orders[rowIndex] : null;

    // The part number alone says which part this order is for since v14. The
    // project no longer takes part in that lookup — it is a label on this row
    // (§9.3), read further down with the other optional cells.
    final was = existing == null ? null : byId[existing.partId];
    final typedPart = cellAt(orderPartColumn)?.trim();
    final number = (typedPart == null || typedPart.isEmpty)
        ? was?.partNumber
        : typedPart;
    final partId = number == null ? null : byKey[partKeyOf(number)];
    if (partId == null) continue;

    final typedNeed = cellAt(orderNeedColumn)?.trim();
    final needDate = typedNeed == null || typedNeed.isEmpty
        ? existing?.needDate
        : dateStyle.parse(typedNeed);
    if (needDate == null) continue;

    final typedMaterial = cellAt(orderMaterialColumn);
    final materialDate = typedMaterial == null
        ? existing?.materialDate
        : (typedMaterial.trim().isEmpty
              ? null
              : dateStyle.parse(typedMaterial.trim()) ??
                    existing?.materialDate);

    final typedBatch = cellAt(orderBatchColumn)?.trim();
    final batchSize =
        (typedBatch == null || typedBatch.isEmpty
            ? existing?.batchSize
            : int.tryParse(typedBatch)) ??
        1;
    if (batchSize <= 0) continue;

    // A cell the block does not reach leaves the stored label alone; a cell it
    // reaches and empties clears it. The same rule the material date follows,
    // and for the same reason: both are optional, so blank is a real value
    // rather than a failure to read one.
    final typedBatchNumber = cellAt(orderBatchNumberColumn);
    final batchNumber = typedBatchNumber == null
        ? existing?.batchNumber
        : (typedBatchNumber.trim().isEmpty ? null : typedBatchNumber.trim());

    // Same rule again, now that the project is a label like the batch number
    // rather than half of which part this is.
    final typedProject = cellAt(orderProjectColumn);
    final customerProject = typedProject == null
        ? existing?.customerProject
        : (typedProject.trim().isEmpty ? null : typedProject.trim());

    writes.add(
      OrderWrite(
        id: existing?.id,
        partId: partId,
        needDate: needDate,
        materialDate: materialDate,
        batchSize: batchSize,
        batchNumber: batchNumber,
        customerProject: customerProject,
      ),
    );
  }

  return writes;
}
