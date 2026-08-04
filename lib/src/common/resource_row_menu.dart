import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// Edit / archive / delete — the same three actions on every resource row, so
/// they behave the same way on all of them.
///
/// Archive and Restore are the same menu slot rather than two: a row is only
/// ever in one of those states, and showing both would leave one of them inert.
class ResourceRowMenu extends StatelessWidget {
  const ResourceRowMenu({
    super.key,
    required this.isArchived,
    required this.onEdit,
    required this.onSetArchived,
    required this.onDelete,
    this.editLabel,
    this.extraActions = const [],
  });

  final bool isArchived;
  final VoidCallback onEdit;
  final void Function(bool archived) onSetArchived;
  final VoidCallback onDelete;
  final String? editLabel;

  /// Row-specific actions, above the three every row has. A workcenter drawn
  /// under a line offers "take out of this line" here — an action that only
  /// makes sense on that row, since the same workcenter may be filed elsewhere.
  final List<ResourceRowAction> extraActions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      onSelected: (action) {
        if (action.startsWith('extra:')) {
          extraActions[int.parse(action.substring(6))].onSelected();
          return;
        }
        switch (action) {
          case 'edit':
            onEdit();
          case 'archive':
            onSetArchived(!isArchived);
          case _:
            onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'edit', child: Text(editLabel ?? l10n.actionEdit)),
        for (var i = 0; i < extraActions.length; i++)
          PopupMenuItem(
            value: 'extra:$i',
            child: Text(extraActions[i].label),
          ),
        PopupMenuItem(
          value: 'archive',
          child: Text(isArchived ? l10n.actionRestore : l10n.actionArchive),
        ),
        PopupMenuItem(value: 'delete', child: Text(l10n.actionDelete)),
      ],
    );
  }
}

/// One row-specific menu entry.
class ResourceRowAction {
  const ResourceRowAction({required this.label, required this.onSelected});

  final String label;
  final VoidCallback onSelected;
}

/// Marks a row that is only visible because "show archived" is on.
class ArchivedBadge extends StatelessWidget {
  const ArchivedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          AppLocalizations.of(context).resourcesArchivedBadge,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A row title that shows its archived state inline.
class ResourceTitle extends StatelessWidget {
  const ResourceTitle({
    super.key,
    required this.text,
    required this.isArchived,
  });

  final String text;
  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    if (!isArchived) return Text(text);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const ArchivedBadge(),
      ],
    );
  }
}
