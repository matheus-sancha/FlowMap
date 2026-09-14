import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/database/database_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/documents_providers.dart';
import '../application/templates_providers.dart';

/// The templates shelf.
///
/// **This fills the last placeholder in the app** — `/templates` has pointed at
/// a `PlaceholderScreen` since M1.
///
/// It lists a folder rather than a table: a template is a file, so dropping one
/// in installs it and deleting it removes it, with no list to keep in step.
/// Every fact on a row comes from the manifest, which is its own entry in the
/// zip and is read without touching a single study.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final templates = ref.watch(templatesProvider);
    final hasDocument = ref.watch(openDocumentProvider) != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navTemplates)),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (found) {
          if (found.isEmpty) {
            return _Empty(
              title: l10n.templatesEmpty,
              body: l10n.templatesEmptyHelp,
            );
          }

          final dates = DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          );

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Applying needs a plant to bind against, so with nothing open
              // the screen says why rather than offering a button that fails.
              if (!hasDocument)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    l10n.templatesNeedDocument,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final template in found)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.dashboard_outlined),
                    // A study is written `name (cell · line)` wherever it
                    // stands beside one (#29) — and a template always does,
                    // because the cell and line are what it binds.
                    title: Text(template.manifest.describe),
                    subtitle: Text(
                      [
                        l10n.templatesStepCount(
                          template.manifest.counts['flow_nodes'] ?? 0,
                        ),
                        template.manifest.includesDemand
                            ? l10n.templatesWithDemand
                            : l10n.templatesNoDemand,
                        dates.format(template.manifest.written),
                      ].join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: hasDocument
                              ? () => _apply(context, ref, template)
                              : null,
                          child: Text(l10n.templatesApply),
                        ),
                        IconButton(
                          tooltip: l10n.templatesDelete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await template.file.delete();
                            ref.invalidate(templatesProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    TemplateOnDisk template,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final session = ref.read(openDocumentProvider);

    try {
      if (session == null) return;
      final result = await applyTemplate(
        ref.read(appDatabaseProvider),
        projectId: session.projectId,
        file: template.file,
      );

      // The report is the screen §10.2 described: what matched and what was
      // made, in one line, rather than a binding wizard nobody has to use
      // because nothing was left unbound (#23).
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.templatesApplied(result.studyName)}\n'
            '${l10n.templatesAppliedDetail(result.matched.length, result.created.length)}',
          ),
        ),
      );
      router.go('/projects/${session.projectId}/studies/${result.studyId}');
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dashboard_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks §10.2's one question at save time, and returns null when cancelled.
///
/// **A checkbox rather than a yes/no pair**, because Cancel has to mean *stop*
/// rather than *save without demand* — the two are different answers and a
/// confirm dialog can only carry one of them.
Future<bool?> askIncludeDemand(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  var include = false;

  return showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.templatesSaveStudy),
        content: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: include,
          // Demand is a plant's orders rather than its shape, so a template is
          // flow-only unless someone says otherwise (§10.2).
          onChanged: (value) => setState(() => include = value ?? false),
          title: Text(l10n.templatesIncludeDemand),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(include),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    ),
  );
}
