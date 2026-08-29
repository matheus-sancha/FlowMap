import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/data_grid.dart';
import '../../../common/date_input.dart';
import '../../../common/date_style_scope.dart';
import '../../../common/dialogs.dart';
import '../../../common/duration_input.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/demand_paste.dart';
import '../application/demand_providers.dart';
import '../application/demand_import.dart';
import '../application/demand_table.dart';
import 'import_dialog.dart';
import 'mm3_view.dart';

/// The Demand tab: the parts and their process times, and the order sequence
/// (DESIGN.md §9).
///
/// Two grids rather than one screen split in half — each wants the full height,
/// and they are read at different moments: the parts table is set up once, the
/// sequence is the thing the user reorders and watches MM3 respond to (§6.3).
class DemandTab extends ConsumerStatefulWidget {
  const DemandTab({super.key, required this.study});

  final Study study;

  @override
  ConsumerState<DemandTab> createState() => _DemandTabState();
}

enum _DemandView { parts, sequence, mm3 }

class _DemandTabState extends ConsumerState<DemandTab> {
  _DemandView _view = _DemandView.parts;

  Future<void> _deleteAllOrders(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.demandDeleteAll,
      message: l10n.demandDeleteAllBody,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (confirmed) {
      await ref
          .read(demandRepositoryProvider)
          .deleteAllOrders(widget.study.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final table = ref.watch(demandTableProvider(widget.study.id));

    if (table == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wraps rather than a Row: three controls do not fit a laptop
              // window side by side, and a toolbar that overflows is a toolbar
              // with a button nobody can reach.
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<_DemandView>(
                    segments: [
                      ButtonSegment(
                        value: _DemandView.parts,
                        label: Text(l10n.demandParts),
                        icon: const Icon(Icons.table_rows_outlined),
                      ),
                      ButtonSegment(
                        value: _DemandView.sequence,
                        label: Text(l10n.demandSequence),
                        icon: const Icon(Icons.low_priority),
                      ),
                      ButtonSegment(
                        value: _DemandView.mm3,
                        label: Text(l10n.mm3),
                        icon: const Icon(Icons.show_chart),
                      ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (selection) =>
                        setState(() => _view = selection.first),
                  ),
                  // Only the two grids can be imported into; MM3 is a reading
                  // of what they hold.
                  if (_view != _DemandView.mm3)
                    TextButton.icon(
                      onPressed: () => showDemandImport(
                        context,
                        ref,
                        study: widget.study,
                        table: table,
                        target: _view == _DemandView.parts
                            ? ImportTarget.parts
                            : ImportTarget.sequence,
                      ),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(l10n.actionImport),
                    ),
                  // Clearing the sequence is what a re-import starts with, so
                  // it sits beside Import rather than behind a row menu.
                  if (_view == _DemandView.sequence)
                    TextButton.icon(
                      onPressed: () => _deleteAllOrders(context),
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: Text(l10n.demandDeleteAll),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // On its own line and capped at two: in the toolbar row it wraps
              // as far as it likes and pushes the grid off the bottom of a
              // short window, which is what the mounting test caught.
              Text(
                switch (_view) {
                  _DemandView.parts => l10n.demandTimesHelp,
                  _DemandView.sequence => l10n.demandSequenceHelp,
                  _DemandView.mm3 => l10n.mm3Help,
                },
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: switch (_view) {
              _DemandView.parts => _PartsGrid(
                study: widget.study,
                table: table,
              ),
              _DemandView.sequence => _SequenceGrid(
                study: widget.study,
                table: table,
              ),
              _DemandView.mm3 => Mm3View(study: widget.study),
            },
          ),
        ),
      ],
    );
  }
}

// --- Parts ------------------------------------------------------------------

class _PartsGrid extends ConsumerWidget {
  const _PartsGrid({required this.study, required this.table});

  final Study study;
  final DemandTable table;

  int get _totalColumn => firstStepColumn + table.columns.length;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final parts = table.parts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (table.columns.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.demandNoSteps,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        Expanded(
          child: DataGrid(
            // One more row than there are parts: typing a part number into the
            // blank one appends a part, and a block pasted onto it appends as
            // many as it has rows. That is how a planner adds twenty parts.
            rowCount: parts.length + 1,
            rowHeaderWidth: 44,
            // The part number stays put. A study of fifteen workcenters is far
            // wider than the window, and scrolling out to the twelfth column
            // would otherwise take with it the only thing that says which part
            // the row you are typing into belongs to.
            frozenColumns: 1,
            rowHeader: (row) => Center(
              child: Text(
                row < parts.length ? '${row + 1}' : '+',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            rowActions: (row) => row >= parts.length
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: l10n.actionDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _deletePart(context, ref, parts[row]),
                  ),
            columns: [
              DataGridColumn(title: l10n.demandPartNumber, width: 150),
              DataGridColumn(title: l10n.demandDescription, width: 200),
              for (final column in table.columns)
                DataGridColumn(
                  title: column.title,
                  width: 132,
                  numeric: true,
                  // An unbound step has nothing to key a time to (§11). The
                  // column is still drawn, so the hole is visible on the grid
                  // and not only in the readiness panel.
                  readOnly: column.targetId == null,
                  helper: column.targetId == null ? l10n.demandUnbound : null,
                ),
              DataGridColumn(
                title: l10n.demandTotal,
                width: 132,
                numeric: true,
                readOnly: true,
              ),
            ],
            valueAt: (row, column) => _valueAt(row, column),
            errorAt: (row, column, raw) => _errorAt(l10n, row, column, raw),
            onCommit: (row, column, block) =>
                _commit(ref, row, column, block),
          ),
        ),
      ],
    );
  }

  String _valueAt(int row, int column) {
    if (row >= table.parts.length) return '';
    final part = table.parts[row];
    if (column == partNumberColumn) return part.partNumber;
    if (column == partDescriptionColumn) return part.description ?? '';
    if (column == _totalColumn) {
      return formatDurationInput(table.totalFor(part.id));
    }
    // **By the node, not the target** (§9). Passing the target compiles and
    // returns null, so every cell would read blank and every part would show
    // as uncosted — which is what this looked like before the key was fixed.
    final time = table.timeFor(
      part.id,
      table.columns[column - firstStepColumn].nodeId,
    );
    // Blank, not `00:00:00` — a part that skips a step has no time here, and
    // the two must not look alike (§5.1).
    return time == null ? '' : formatDurationInput(time);
  }

  String? _errorAt(AppLocalizations l10n, int row, int column, String raw) {
    final text = raw.trim();
    if (column == partNumberColumn) {
      if (text.isEmpty) {
        return row < table.parts.length ? l10n.validationRequired : null;
      }
      final clash = table.parts.indexWhere(
        (p) => p.partNumber.toLowerCase() == text.toLowerCase(),
      );
      return clash >= 0 && clash != row ? l10n.validationNameTaken : null;
    }
    if (column == partDescriptionColumn || column == _totalColumn) {
      return null;
    }
    if (text.isEmpty) return null;
    return parseDurationInput(text) == null ? l10n.validationNotADuration : null;
  }

  Future<void> _deletePart(
    BuildContext context,
    WidgetRef ref,
    DemandPart part,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.confirmDeleteTitle(part.partNumber),
      // Deleting a part takes its orders with it, so the sequence renumbers.
      // Said out loud rather than discovered on the other tab.
      message: l10n.demandPartDeleteBody,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (confirmed) {
      await ref
          .read(demandRepositoryProvider)
          .deletePart(study.id, part.id);
    }
  }

  /// Applies a typed cell or a pasted block.
  ///
  /// The reading is [planPartsWrite]'s, so what a block means is decided in a
  /// pure function with its own tests; this only carries the answer through.
  Future<void> _commit(
    WidgetRef ref,
    int row,
    int column,
    List<List<String>> block,
  ) async {
    final plan = planPartsWrite(
      table: table,
      row: row,
      column: column,
      block: block,
    );
    if (plan.isEmpty) return;
    await ref.read(demandRepositoryProvider).applyPartsPlan(study.id, plan);
  }
}

// --- Sequence ---------------------------------------------------------------

class _SequenceGrid extends ConsumerWidget {
  const _SequenceGrid({required this.study, required this.table});

  final Study study;
  final DemandTable table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dateStyle = DateStyleScope.of(context);
    final orders = ref.watch(demandOrdersProvider(study.id)).value;
    if (orders == null) return const Center(child: CircularProgressIndicator());

    if (table.parts.isEmpty) {
      return Center(
        child: Text(
          l10n.demandNeedsPart,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return DataGrid(
      rowCount: orders.length + 1,
      rowHeaderWidth: 44,
      rowActionsWidth: 48,
      rowHeader: (row) => Center(
        child: Text(
          row < orders.length ? '${row + 1}' : '+',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
      rowActions: (row) => row >= orders.length
          ? const SizedBox.shrink()
          : PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (action) async {
                final repository = ref.read(demandRepositoryProvider);
                switch (action) {
                  case 'up':
                    await repository.moveOrder(study.id, row, row - 1);
                  case 'down':
                    await repository.moveOrder(study.id, row, row + 1);
                  case 'delete':
                    await repository.deleteOrder(study.id, orders[row].id);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'up', child: Text(l10n.actionMoveUp)),
                PopupMenuItem(value: 'down', child: Text(l10n.actionMoveDown)),
                PopupMenuItem(value: 'delete', child: Text(l10n.actionDelete)),
              ],
            ),
      columns: [
        DataGridColumn(title: l10n.demandPartNumber, width: 150),
        // Editable, because the project is half of what identifies a part:
        // the same part number under two customer projects is two parts, and
        // the number alone cannot say which one an order is for (§9.3).
        DataGridColumn(title: l10n.demandProject, width: 150),
        // Before the size, the order a production plan reads in. A label, so
        // it is not `numeric: true` — `LOT-7A` is as valid as `12`.
        DataGridColumn(
          title: l10n.demandBatchNumber,
          width: 120,
          helper: l10n.demandBatchNumberHelp,
        ),
        DataGridColumn(title: l10n.demandBatchSize, width: 90, numeric: true),
        DataGridColumn(title: l10n.demandNeedDate, width: 130, numeric: true),
        DataGridColumn(
          title: l10n.demandMaterialDate,
          width: 130,
          numeric: true,
          helper: l10n.demandMaterialDateHelp,
        ),
      ],
      valueAt: (row, column) => _valueAt(orders, row, column, dateStyle),
      errorAt: (row, column, raw) =>
          _errorAt(l10n, dateStyle, orders, row, column, raw),
      onCommit: (row, column, block) =>
          _commit(ref, dateStyle, orders, row, column, block),
    );
  }

  String _valueAt(
    List<DemandOrder> orders,
    int row,
    int column,
    DateStyle dateStyle,
  ) {
    if (row >= orders.length) return '';
    final order = orders[row];
    final part = table.parts.where((p) => p.id == order.partId).firstOrNull;
    return switch (column) {
      orderPartColumn => part?.partNumber ?? '',
      orderProjectColumn => order.customerProject ?? '',
      orderBatchNumberColumn => order.batchNumber ?? '',
      orderBatchColumn => '${order.batchSize}',
      orderNeedColumn => dateStyle.format(order.needDate),
      _ => dateStyle.format(order.materialDate),
    };
  }

  String? _errorAt(
    AppLocalizations l10n,
    DateStyle dateStyle,
    List<DemandOrder> orders,
    int row,
    int column,
    String raw,
  ) {
    final text = raw.trim();
    final isNewRow = row >= orders.length;

    switch (column) {
      case orderPartColumn:
        // The number alone names the part since v14 (§9.3).
        if (text.isEmpty) {
          return isNewRow ? null : l10n.validationRequired;
        }
        return table.parts.any(
              (p) => p.partNumber.toLowerCase() == text.toLowerCase(),
            )
            ? null
            : l10n.validationUnknownPart;
      case orderProjectColumn:
        // Never an error, for the reason the batch number is not: it is the
        // planner's own label on this order, nothing matches on it, and blank
        // is a legitimate answer (§9.3).
        return null;
      case orderBatchNumberColumn:
        // Never an error. It is the planner's own label, nothing matches on
        // it, and blank is a legitimate answer — so an explicit arm rather
        // than falling through to the date parsing below (§9.1).
        return null;
      case orderBatchColumn:
        if (text.isEmpty) return isNewRow ? null : l10n.validationRequired;
        final batch = int.tryParse(text);
        return batch != null && batch > 0 ? null : l10n.validationPositiveWhole;
      case orderNeedColumn:
        if (text.isEmpty) return isNewRow ? null : l10n.validationRequired;
        return dateStyle.parse(text) == null
            ? l10n.validationNotADate
            : null;
      default:
        if (text.isEmpty) return null;
        return dateStyle.parse(text) == null
            ? l10n.validationNotADate
            : null;
    }
  }

  /// Applies a typed cell or a pasted block to the sequence.
  ///
  /// The reading is [planSequenceWrite]'s; this only carries the answer
  /// through.
  Future<void> _commit(
    WidgetRef ref,
    DateStyle dateStyle,
    List<DemandOrder> orders,
    int row,
    int column,
    List<List<String>> block,
  ) async {
    final writes = planSequenceWrite(
      orders: orders,
      parts: table.parts,
      row: row,
      column: column,
      block: block,
      dateStyle: dateStyle,
    );
    if (writes.isEmpty) return;
    await ref
        .read(demandRepositoryProvider)
        .applySequenceWrites(study.id, writes);
  }
}
