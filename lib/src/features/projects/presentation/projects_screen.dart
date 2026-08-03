import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/dialogs.dart';
import '../../../common/resource_row_menu.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../resources/application/resources_providers.dart';
import '../application/projects_providers.dart';

/// The Projects list. A project is one plant plus one shift pattern, and the
/// container every schedule and study hangs off (DESIGN.md §3).
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final projects = ref.watch(projectsListProvider);
    final plants = ref.watch(plantsProvider).value ?? const <Plant>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navProjects),
        actions: [
          IconButton(
            tooltip: l10n.resourcesShowArchived,
            isSelected: ref.watch(showArchivedProvider),
            icon: const Icon(Icons.inventory_outlined),
            selectedIcon: const Icon(Icons.inventory),
            onPressed: () => ref.read(showArchivedProvider.notifier).toggle(),
          ),
        ],
      ),
      floatingActionButton: plants.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _createProject(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.projectNew),
            ),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (projects) {
          if (plants.isEmpty) return const _NoPlantYet();
          if (projects.isEmpty) {
            return _NoProjectYet(onCreate: () => _createProject(context, ref));
          }
          return ListView(
            children: [
              for (final project in projects)
                _ProjectTile(project: project, plants: plants),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectTile extends ConsumerWidget {
  const _ProjectTile({required this.project, required this.plants});

  final Project project;
  final List<Plant> plants;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(projectsRepositoryProvider);
    final plant = plants.where((p) => p.id == project.plantId).firstOrNull;
    final patterns = ref.watch(shiftPatternsProvider).value ?? const [];
    final pattern = patterns
        .where((p) => p.id == project.shiftPatternId)
        .firstOrNull;

    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: ResourceTitle(
        text: project.name,
        isArchived: project.archivedAt != null,
      ),
      subtitle: Text([plant?.name ?? '—', pattern?.name ?? '—'].join(' · ')),
      onTap: () => context.go('/projects/${project.id}'),
      trailing: ResourceRowMenu(
        isArchived: project.archivedAt != null,
        editLabel: l10n.actionRename,
        onEdit: () async {
          final name = await promptForName(
            context,
            title: l10n.actionRename,
            label: l10n.fieldName,
            initialValue: project.name,
          );
          if (name != null) {
            await repository.updateProject(
              project.id,
              name: name,
              shiftPatternId: project.shiftPatternId,
              notes: project.notes,
            );
          }
        },
        onSetArchived: (archived) =>
            repository.setProjectArchived(project.id, archived),
        onDelete: () async {
          final confirmed = await confirmAction(
            context,
            title: l10n.confirmDeleteTitle(project.name),
            message: l10n.projectDeleteBody,
            confirmLabel: l10n.actionDelete,
            destructive: true,
          );
          if (confirmed) await repository.deleteProject(project.id);
        },
      ),
    );
  }
}

class _NoPlantYet extends StatelessWidget {
  const _NoPlantYet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.factory_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(l10n.projectNeedsPlant, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => GoRouter.of(context).go('/resources'),
            icon: const Icon(Icons.arrow_forward),
            label: Text(l10n.navResources),
          ),
        ],
      ),
    );
  }
}

class _NoProjectYet extends StatelessWidget {
  const _NoProjectYet({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(l10n.projectsEmpty, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: Text(l10n.projectNew),
          ),
        ],
      ),
    );
  }
}

Future<void> _createProject(BuildContext context, WidgetRef ref) async {
  final plants = ref.read(plantsProvider).value ?? const <Plant>[];
  final patterns =
      ref.read(shiftPatternsProvider).value ?? const <ShiftPattern>[];
  final existing = ref.read(projectsListProvider).value ?? const <Project>[];
  if (plants.isEmpty || patterns.isEmpty) return;

  final draft = await showDialog<_ProjectDraft>(
    context: context,
    builder: (context) => _ProjectDialog(
      plants: plants,
      patterns: patterns,
      takenNames: existing.map((p) => p.name.toLowerCase()).toSet(),
    ),
  );
  if (draft == null) return;

  final id = await ref
      .read(projectsRepositoryProvider)
      .createProject(
        name: draft.name,
        plantId: draft.plantId,
        shiftPatternId: draft.shiftPatternId,
      );
  if (context.mounted) context.go('/projects/$id');
}

class _ProjectDraft {
  const _ProjectDraft({
    required this.name,
    required this.plantId,
    required this.shiftPatternId,
  });

  final String name;
  final String plantId;
  final String shiftPatternId;
}

class _ProjectDialog extends StatefulWidget {
  const _ProjectDialog({
    required this.plants,
    required this.patterns,
    required this.takenNames,
  });

  final List<Plant> plants;
  final List<ShiftPattern> patterns;
  final Set<String> takenNames;

  @override
  State<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<_ProjectDialog> {
  final _name = TextEditingController();
  late String _plantId = widget.plants.first.id;
  late String _patternId = widget.patterns.first.id;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = _name.text.trim();
    final taken = widget.takenNames.contains(value.toLowerCase());

    return AlertDialog(
      title: Text(l10n.projectNew),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                errorText: taken ? l10n.validationNameTaken : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _plantId,
              decoration: InputDecoration(
                labelText: l10n.plant,
                // The plant cannot be changed later: every study, schedule and
                // flow node in the project points at its workcenters.
                helperText: l10n.projectPlantHelp,
                helperMaxLines: 3,
              ),
              items: [
                for (final plant in widget.plants)
                  DropdownMenuItem(value: plant.id, child: Text(plant.name)),
              ],
              onChanged: (id) => setState(() => _plantId = id!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _patternId,
              decoration: InputDecoration(
                labelText: l10n.shiftPattern,
                helperText: l10n.projectPatternHelp,
                helperMaxLines: 3,
              ),
              items: [
                for (final pattern in widget.patterns)
                  DropdownMenuItem(
                    value: pattern.id,
                    child: Text(pattern.name),
                  ),
              ],
              onChanged: (id) => setState(() => _patternId = id!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: value.isEmpty || taken
              ? null
              : () => Navigator.of(context).pop(
                  _ProjectDraft(
                    name: value,
                    plantId: _plantId,
                    shiftPatternId: _patternId,
                  ),
                ),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
