import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/dialogs.dart';
import '../../../common/resource_row_menu.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/resources_providers.dart';
import '../data/resources_repository.dart';
import 'workcenter_editor.dart';

/// The Plant → Cells → Lines → Workcenters tree.
///
/// Three streams feed the whole tree — cells, every line in the plant, every
/// workcenter in the plant — and the nesting is done here. A stream per node
/// would multiply subscriptions with the tree for data that is one join away.
class PlantStructureView extends ConsumerWidget {
  const PlantStructureView({super.key, required this.plantId});

  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cells = ref.watch(cellsProvider(plantId));
    final lines = ref.watch(plantLinesProvider(plantId));
    final workcenters = ref.watch(workcentersProvider(plantId));

    if (cells.isLoading || lines.isLoading || workcenters.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = cells.error ?? lines.error ?? workcenters.error;
    if (error != null) return Center(child: Text('$error'));

    final cellList = cells.requireValue;
    final lineList = lines.requireValue;
    final workcenterList = workcenters.requireValue;

    final linesByCell = <String, List<PlantLine>>{};
    for (final line in lineList) {
      linesByCell.putIfAbsent(line.cell.id, () => []).add(line);
    }
    final workcentersByLine = <String?, List<Workcenter>>{};
    for (final workcenter in workcenterList) {
      workcentersByLine
          .putIfAbsent(workcenter.homeLineId, () => [])
          .add(workcenter);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        for (final cell in cellList)
          _CellTile(
            plantId: plantId,
            cell: cell,
            lines: linesByCell[cell.id] ?? const [],
            workcentersByLine: workcentersByLine,
            allLines: lineList,
          ),
        _UnassignedSection(
          plantId: plantId,
          workcenters: workcentersByLine[null] ?? const [],
          allLines: lineList,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _createCell(context, ref, plantId, cellList),
              icon: const Icon(Icons.add),
              label: Text(l10n.productionCellNew),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _createCell(
  BuildContext context,
  WidgetRef ref,
  String plantId,
  List<ProductionCell> existing,
) async {
  final l10n = AppLocalizations.of(context);
  final taken = existing.map((c) => c.name.toLowerCase()).toSet();
  final name = await promptForName(
    context,
    title: l10n.productionCellNew,
    label: l10n.fieldName,
    validate: (value) =>
        taken.contains(value.toLowerCase()) ? l10n.validationNameTaken : null,
  );
  if (name == null) return;
  await ref
      .read(resourcesRepositoryProvider)
      .createCell(plantId: plantId, name: name);
}

class _CellTile extends ConsumerWidget {
  const _CellTile({
    required this.plantId,
    required this.cell,
    required this.lines,
    required this.workcentersByLine,
    required this.allLines,
  });

  final String plantId;
  final ProductionCell cell;
  final List<PlantLine> lines;
  final Map<String?, List<Workcenter>> workcentersByLine;
  final List<PlantLine> allLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(resourcesRepositoryProvider);

    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.hub_outlined),
      title: ResourceTitle(
        text: cell.name,
        isArchived: cell.archivedAt != null,
      ),
      subtitle: Text(l10n.productionCell),
      trailing: ResourceRowMenu(
        isArchived: cell.archivedAt != null,
        editLabel: l10n.actionRename,
        onEdit: () async {
          final name = await promptForName(
            context,
            title: l10n.actionRename,
            label: l10n.fieldName,
            initialValue: cell.name,
          );
          if (name != null) await repository.renameCell(cell.id, name);
        },
        onSetArchived: (archived) =>
            repository.setCellArchived(cell.id, archived),
        onDelete: () async {
          final confirmed = await confirmAction(
            context,
            title: l10n.confirmDeleteTitle(cell.name),
            message: l10n.confirmDeleteBody,
            confirmLabel: l10n.actionDelete,
            destructive: true,
          );
          if (confirmed) await repository.deleteCell(cell.id);
        },
      ),
      children: [
        for (final line in lines)
          _LineTile(
            plantId: plantId,
            line: line,
            workcenters: workcentersByLine[line.line.id] ?? const [],
            allLines: allLines,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 4, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final taken = lines
                    .map((l) => l.line.name.toLowerCase())
                    .toSet();
                final name = await promptForName(
                  context,
                  title: l10n.productionLineNew,
                  label: l10n.fieldName,
                  validate: (value) => taken.contains(value.toLowerCase())
                      ? l10n.validationNameTaken
                      : null,
                );
                if (name != null) {
                  await repository.createLine(cellId: cell.id, name: name);
                }
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.productionLineNew),
            ),
          ),
        ),
      ],
    );
  }
}

class _LineTile extends ConsumerWidget {
  const _LineTile({
    required this.plantId,
    required this.line,
    required this.workcenters,
    required this.allLines,
  });

  final String plantId;
  final PlantLine line;
  final List<Workcenter> workcenters;
  final List<PlantLine> allLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(resourcesRepositoryProvider);

    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.linear_scale_outlined),
        title: ResourceTitle(
          text: line.line.name,
          isArchived: line.line.archivedAt != null,
        ),
        subtitle: Text(l10n.productionLine),
        trailing: ResourceRowMenu(
          isArchived: line.line.archivedAt != null,
          editLabel: l10n.actionRename,
          onEdit: () async {
            final name = await promptForName(
              context,
              title: l10n.actionRename,
              label: l10n.fieldName,
              initialValue: line.line.name,
            );
            if (name != null) await repository.renameLine(line.line.id, name);
          },
          onSetArchived: (archived) =>
              repository.setLineArchived(line.line.id, archived),
          onDelete: () async {
            final confirmed = await confirmAction(
              context,
              title: l10n.confirmDeleteTitle(line.line.name),
              message: l10n.confirmDeleteBody,
              confirmLabel: l10n.actionDelete,
              destructive: true,
            );
            if (confirmed) await repository.deleteLine(line.line.id);
          },
        ),
        children: [
          for (final workcenter in workcenters)
            _WorkcenterTile(
              plantId: plantId,
              workcenter: workcenter,
              allLines: allLines,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 4, 16, 12),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _addWorkcenter(
                    context,
                    ref,
                    plantId: plantId,
                    allLines: allLines,
                    initialLineId: line.line.id,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.workcenterNew),
                ),
                const SizedBox(width: 8),
                // A workcenter belongs to the plant, not to this line, so an
                // existing one can be shown here instead of being recreated
                // under a second name — which is what a plant-unique name
                // forces otherwise.
                TextButton.icon(
                  onPressed: () => _showExistingWorkcenter(
                    context,
                    ref,
                    plantId: plantId,
                    lineId: line.line.id,
                  ),
                  icon: const Icon(Icons.playlist_add),
                  label: Text(l10n.workcenterAddExisting),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Moves an existing plant workcenter under this line in the tree.
///
/// This changes **where it is drawn, not what may use it**: any study of any
/// line can already target any workcenter of the plant, and that sharing is
/// what a combined simulation contends over (DESIGN.md §7.7).
Future<void> _showExistingWorkcenter(
  BuildContext context,
  WidgetRef ref, {
  required String plantId,
  required String lineId,
}) async {
  final l10n = AppLocalizations.of(context);
  final all = ref.read(workcentersProvider(plantId)).value ?? const [];
  final candidates = all.where((w) => w.homeLineId != lineId).toList();

  if (candidates.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.workcenterNoneToAdd)));
    return;
  }

  final chosen = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.workcenterAddExisting),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Text(
            l10n.workcenterAddExistingHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final workcenter in candidates)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(workcenter.id),
            child: Text(workcenter.name),
          ),
      ],
    ),
  );
  if (chosen == null) return;

  await ref
      .read(resourcesRepositoryProvider)
      .setWorkcenterHomeLine(chosen, lineId);
}

class _UnassignedSection extends ConsumerWidget {
  const _UnassignedSection({
    required this.plantId,
    required this.workcenters,
    required this.allLines,
  });

  final String plantId;
  final List<Workcenter> workcenters;
  final List<PlantLine> allLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ExpansionTile(
      initiallyExpanded: workcenters.isNotEmpty,
      leading: const Icon(Icons.inventory_2_outlined),
      title: Text(l10n.resourcesUnassigned),
      subtitle: Text(l10n.resourcesUnassignedHelp),
      children: [
        for (final workcenter in workcenters)
          _WorkcenterTile(
            plantId: plantId,
            workcenter: workcenter,
            allLines: allLines,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 4, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addWorkcenter(
                context,
                ref,
                plantId: plantId,
                allLines: allLines,
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.workcenterNew),
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkcenterTile extends ConsumerWidget {
  const _WorkcenterTile({
    required this.plantId,
    required this.workcenter,
    required this.allLines,
  });

  final String plantId;
  final Workcenter workcenter;
  final List<PlantLine> allLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(resourcesRepositoryProvider);
    final types = ref.watch(workcenterTypesProvider).value ?? const [];
    final type = types.where((t) => t.id == workcenter.typeId).firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: ListTile(
        leading: const Icon(Icons.precision_manufacturing_outlined),
        title: ResourceTitle(
          text: workcenter.name,
          isArchived: workcenter.archivedAt != null,
        ),
        subtitle: Text(type?.name ?? l10n.workcenterTypeUnset),
        trailing: ResourceRowMenu(
          isArchived: workcenter.archivedAt != null,
          onEdit: () async {
            final workcenters =
                ref.read(workcentersProvider(plantId)).value ?? const [];
            final draft = await showWorkcenterEditor(
              context,
              lines: allLines,
              types: types,
              takenNames: workcenters
                  .where((w) => w.id != workcenter.id)
                  .map((w) => w.name.toLowerCase())
                  .toSet(),
              existing: workcenter,
            );
            if (draft != null) {
              await repository.updateWorkcenter(
                workcenter.id,
                name: draft.name,
                typeId: draft.typeId,
                homeLineId: draft.homeLineId,
              );
            }
          },
          onSetArchived: (archived) =>
              repository.setWorkcenterArchived(workcenter.id, archived),
          onDelete: () async {
            final confirmed = await confirmAction(
              context,
              title: l10n.confirmDeleteTitle(workcenter.name),
              message: l10n.confirmDeleteBody,
              confirmLabel: l10n.actionDelete,
              destructive: true,
            );
            if (confirmed) await repository.deleteWorkcenter(workcenter.id);
          },
        ),
      ),
    );
  }
}

Future<void> _addWorkcenter(
  BuildContext context,
  WidgetRef ref, {
  required String plantId,
  required List<PlantLine> allLines,
  String? initialLineId,
}) async {
  final types = ref.read(workcenterTypesProvider).value ?? const [];
  final existing = ref.read(workcentersProvider(plantId)).value ?? const [];
  final draft = await showWorkcenterEditor(
    context,
    lines: allLines,
    types: types,
    takenNames: existing.map((w) => w.name.toLowerCase()).toSet(),
    initialLineId: initialLineId,
  );
  if (draft == null) return;
  await ref
      .read(resourcesRepositoryProvider)
      .createWorkcenter(
        plantId: plantId,
        name: draft.name,
        typeId: draft.typeId,
        homeLineId: draft.homeLineId,
      );
}
