import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/dialogs.dart';
import '../../../common/resource_row_menu.dart';
import '../../../common/workcenter_icons.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/resources_providers.dart';
import 'workcenter_type_editor.dart';

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
              leading: Icon(
                type.icon == null
                    ? Icons.category_outlined
                    : workcenterIconGlyph(type.icon!),
              ),
              title: ResourceTitle(
                text: type.name,
                isArchived: type.archivedAt != null,
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) async {
                  switch (action) {
                    case 'rename':
                      final draft = await showWorkcenterTypeEditor(
                        context,
                        takenNames: types
                            .where((t) => t.id != type.id)
                            .map((t) => t.name.toLowerCase())
                            .toSet(),
                        initialName: type.name,
                        initialIcon: type.icon,
                        initialLabourPaced: type.isLabourPaced,
                      );
                      if (draft != null) {
                        await repository.updateWorkcenterType(
                          type.id,
                          name: draft.name,
                          icon: draft.icon,
                          labourPaced: draft.labourPaced,
                        );
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
                    child: Text(l10n.actionEdit),
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
                  final draft = await showWorkcenterTypeEditor(
                    context,
                    takenNames: types.map((t) => t.name.toLowerCase()).toSet(),
                  );
                  if (draft != null) {
                    await repository.createWorkcenterType(
                      draft.name,
                      icon: draft.icon,
                      labourPaced: draft.labourPaced,
                    );
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
