import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/dialogs.dart';
import '../../../common/resource_row_menu.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/resources_providers.dart';

/// The editable workcenter type picklist. Seeded with the spec's nine types;
/// the user adds their own.
class WorkcenterTypesView extends ConsumerWidget {
  const WorkcenterTypesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final types = ref.watch(workcenterTypesProvider);
    final repository = ref.read(resourcesRepositoryProvider);

    return types.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (types) => ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          for (final type in types)
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: ResourceTitle(
                text: type.name,
                isArchived: type.archivedAt != null,
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) async {
                  switch (action) {
                    case 'rename':
                      final taken = types
                          .where((t) => t.id != type.id)
                          .map((t) => t.name.toLowerCase())
                          .toSet();
                      final name = await promptForName(
                        context,
                        title: l10n.actionRename,
                        label: l10n.fieldName,
                        initialValue: type.name,
                        validate: (value) => taken.contains(value.toLowerCase())
                            ? l10n.validationNameTaken
                            : null,
                      );
                      if (name != null) {
                        await repository.renameWorkcenterType(type.id, name);
                      }
                    case 'archive':
                      await repository.setWorkcenterTypeArchived(
                        type.id,
                        type.archivedAt == null,
                      );
                    case 'delete':
                      if (!context.mounted) return;
                      final confirmed = await confirmAction(
                        context,
                        title: l10n.confirmDeleteTitle(type.name),
                        // Workcenters referencing it keep working: the column
                        // is set to null, not orphaned (Workcenters.typeId).
                        message: l10n.workcenterTypeDeleteBody,
                        confirmLabel: l10n.actionDelete,
                        destructive: true,
                      );
                      if (confirmed) {
                        await repository.deleteWorkcenterType(type.id);
                      }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(l10n.actionRename),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(
                      type.archivedAt == null
                          ? l10n.actionArchive
                          : l10n.actionRestore,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.actionDelete),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final taken = types.map((t) => t.name.toLowerCase()).toSet();
                  final name = await promptForName(
                    context,
                    title: l10n.workcenterTypeNew,
                    label: l10n.fieldName,
                    validate: (value) => taken.contains(value.toLowerCase())
                        ? l10n.validationNameTaken
                        : null,
                  );
                  if (name != null) {
                    await repository.createWorkcenterType(name);
                  }
                },
                icon: const Icon(Icons.add),
                label: Text(l10n.workcenterTypeNew),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
