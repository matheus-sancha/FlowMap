import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/dialogs.dart';
import '../../../common/resource_row_menu.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/resources_providers.dart';

/// Workcenter pools (DESIGN.md §3.1) — the mechanism by which two production
/// lines contend for the same capacity.
class PoolsView extends ConsumerWidget {
  const PoolsView({super.key, required this.plantId});

  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pools = ref.watch(poolsProvider(plantId));

    return pools.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (pools) => ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          for (final pool in pools) _PoolTile(plantId: plantId, pool: pool),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final taken = pools.map((p) => p.name.toLowerCase()).toSet();
                  final name = await promptForName(
                    context,
                    title: l10n.workcenterPoolNew,
                    label: l10n.fieldName,
                    validate: (value) => taken.contains(value.toLowerCase())
                        ? l10n.validationNameTaken
                        : null,
                  );
                  if (name == null) return;
                  await ref
                      .read(resourcesRepositoryProvider)
                      .createPool(plantId: plantId, name: name);
                },
                icon: const Icon(Icons.add),
                label: Text(l10n.workcenterPoolNew),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PoolTile extends ConsumerWidget {
  const _PoolTile({required this.plantId, required this.pool});

  final String plantId;
  final WorkcenterPool pool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(resourcesRepositoryProvider);
    final members = ref.watch(poolMembersProvider(pool.id)).value;

    return ListTile(
      leading: const Icon(Icons.workspaces_outlined),
      title: ResourceTitle(
        text: pool.name,
        isArchived: pool.archivedAt != null,
      ),
      subtitle: members == null
          ? null
          : members.isEmpty
          ? Text(l10n.workcenterPoolEmpty)
          : Text(members.map((w) => w.name).join(' · ')),
      onTap: () => _editMembers(context, ref, members ?? const []),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          switch (action) {
            case 'members':
              await _editMembers(context, ref, members ?? const []);
            case 'rename':
              final name = await promptForName(
                context,
                title: l10n.actionRename,
                label: l10n.fieldName,
                initialValue: pool.name,
              );
              if (name != null) await repository.renamePool(pool.id, name);
            case 'archive':
              await repository.setPoolArchived(
                pool.id,
                pool.archivedAt == null,
              );
            case 'delete':
              if (!context.mounted) return;
              final confirmed = await confirmAction(
                context,
                title: l10n.confirmDeleteTitle(pool.name),
                message: l10n.confirmDeleteBody,
                confirmLabel: l10n.actionDelete,
                destructive: true,
              );
              if (confirmed) await repository.deletePool(pool.id);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'members',
            child: Text(l10n.workcenterPoolMembers),
          ),
          PopupMenuItem(value: 'rename', child: Text(l10n.actionRename)),
          PopupMenuItem(
            value: 'archive',
            child: Text(
              pool.archivedAt == null ? l10n.actionArchive : l10n.actionRestore,
            ),
          ),
          PopupMenuItem(value: 'delete', child: Text(l10n.actionDelete)),
        ],
      ),
    );
  }

  Future<void> _editMembers(
    BuildContext context,
    WidgetRef ref,
    List<Workcenter> current,
  ) async {
    final candidates = ref.read(workcentersProvider(plantId)).value ?? const [];
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _PoolMembersDialog(
        poolName: pool.name,
        candidates: candidates,
        initiallySelected: current.map((w) => w.id).toSet(),
      ),
    );
    if (selected == null) return;
    await ref
        .read(resourcesRepositoryProvider)
        .setPoolMembers(pool.id, selected);
  }
}

class _PoolMembersDialog extends StatefulWidget {
  const _PoolMembersDialog({
    required this.poolName,
    required this.candidates,
    required this.initiallySelected,
  });

  final String poolName;
  final List<Workcenter> candidates;
  final Set<String> initiallySelected;

  @override
  State<_PoolMembersDialog> createState() => _PoolMembersDialogState();
}

class _PoolMembersDialogState extends State<_PoolMembersDialog> {
  late final Set<String> _selected = {...widget.initiallySelected};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.poolName),
      content: SizedBox(
        width: 420,
        height: 400,
        child: widget.candidates.isEmpty
            ? Center(child: Text(l10n.workcenterPoolNoCandidates))
            : ListView(
                children: [
                  for (final workcenter in widget.candidates)
                    CheckboxListTile(
                      value: _selected.contains(workcenter.id),
                      title: Text(workcenter.name),
                      onChanged: (checked) => setState(() {
                        if (checked ?? false) {
                          _selected.add(workcenter.id);
                        } else {
                          _selected.remove(workcenter.id);
                        }
                      }),
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
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
