import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/dialogs.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/resources_providers.dart';
import 'plant_structure_view.dart';
import 'pools_view.dart';
import 'shift_patterns_view.dart';
import 'workcenter_types_view.dart';

/// The Resources area (DESIGN.md §12.1).
///
/// Everything here is plant-scoped except shift patterns and workcenter types,
/// which are plant-independent by design: a pattern is picked by a project and
/// a type is a picklist, so both would be duplicated needlessly if they hung
/// off a plant.
class ResourcesScreen extends ConsumerWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final plants = ref.watch(plantsProvider);

    return plants.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.resourcesTitle)),
        body: Center(child: Text('$error')),
      ),
      data: (plants) {
        if (plants.isEmpty) return const _NoPlantYet();

        // Null selection resolves to the first plant here rather than by
        // writing a default on load: a read should not have a side effect, and
        // the list can change under a stored id at any time.
        final selectedId = ref.watch(selectedPlantProvider);
        final plant = plants.firstWhere(
          (p) => p.id == selectedId,
          orElse: () => plants.first,
        );

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: _PlantSelector(plants: plants, selected: plant),
              actions: [
                IconButton(
                  tooltip: l10n.resourcesShowArchived,
                  isSelected: ref.watch(showArchivedProvider),
                  icon: const Icon(Icons.inventory_outlined),
                  selectedIcon: const Icon(Icons.inventory),
                  onPressed: () =>
                      ref.read(showArchivedProvider.notifier).toggle(),
                ),
                IconButton(
                  tooltip: l10n.plantNew,
                  icon: const Icon(Icons.add_business_outlined),
                  onPressed: () => _createPlant(context, ref, plants),
                ),
                _PlantMenu(plant: plant),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(text: l10n.plant),
                  Tab(text: l10n.workcenterPools),
                  Tab(text: l10n.shiftPatterns),
                  Tab(text: l10n.workcenterTypes),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                PlantStructureView(plantId: plant.id),
                PoolsView(plantId: plant.id),
                const ShiftPatternsView(),
                const WorkcenterTypesView(),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _createPlant(
  BuildContext context,
  WidgetRef ref,
  List<Plant> existing,
) async {
  final l10n = AppLocalizations.of(context);
  final taken = existing.map((p) => p.name.toLowerCase()).toSet();
  final name = await promptForName(
    context,
    title: l10n.plantNew,
    label: l10n.fieldName,
    validate: (value) =>
        taken.contains(value.toLowerCase()) ? l10n.validationNameTaken : null,
  );
  if (name == null) return;
  final id = await ref
      .read(resourcesRepositoryProvider)
      .createPlant(name: name);
  ref.read(selectedPlantProvider.notifier).select(id);
}

class _NoPlantYet extends ConsumerWidget {
  const _NoPlantYet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resourcesTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.factory_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(l10n.resourcesEmpty, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _createPlant(context, ref, const []),
              icon: const Icon(Icons.add),
              label: Text(l10n.plantNew),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantSelector extends ConsumerWidget {
  const _PlantSelector({required this.plants, required this.selected});

  final List<Plant> plants;
  final Plant selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plants.length == 1) return Text(selected.name);
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selected.id,
        onChanged: (id) => ref.read(selectedPlantProvider.notifier).select(id),
        items: [
          for (final plant in plants)
            DropdownMenuItem(value: plant.id, child: Text(plant.name)),
        ],
      ),
    );
  }
}

class _PlantMenu extends ConsumerWidget {
  const _PlantMenu({required this.plant});

  final Plant plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      onSelected: (action) async {
        final repository = ref.read(resourcesRepositoryProvider);
        switch (action) {
          case 'rename':
            final name = await promptForName(
              context,
              title: l10n.actionRename,
              label: l10n.fieldName,
              initialValue: plant.name,
            );
            if (name != null) {
              await repository.updatePlant(
                plant.id,
                name: name,
                code: plant.code,
              );
            }
          case 'archive':
            await repository.setPlantArchived(
              plant.id,
              plant.archivedAt == null,
            );
            ref.read(selectedPlantProvider.notifier).select(null);
          case 'delete':
            if (!context.mounted) return;
            final confirmed = await confirmAction(
              context,
              title: l10n.confirmDeleteTitle(plant.name),
              message: l10n.confirmDeleteBody,
              confirmLabel: l10n.actionDelete,
              destructive: true,
            );
            if (confirmed) {
              await repository.deletePlant(plant.id);
              ref.read(selectedPlantProvider.notifier).select(null);
            }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'rename', child: Text(l10n.actionRename)),
        PopupMenuItem(
          value: 'archive',
          child: Text(
            plant.archivedAt == null ? l10n.actionArchive : l10n.actionRestore,
          ),
        ),
        PopupMenuItem(value: 'delete', child: Text(l10n.actionDelete)),
      ],
    );
  }
}
