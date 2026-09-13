import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/documents_providers.dart';
import '../data/documents_directory.dart';

/// The two things you can do to the document itself: save a copy, or close it.
///
/// **There is no Save here and there never will be** (#37). The file follows
/// the database on its own; the only reason this menu exists is for the two
/// acts that are not editing — making a separate copy, and putting it down.
class DocumentMenu extends ConsumerWidget {
  const DocumentMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (ref.watch(openDocumentProvider) == null) return const SizedBox.shrink();

    return MenuAnchor(
      builder: (context, controller, _) => IconButton(
        tooltip: l10n.documentsTitle,
        icon: const Icon(Icons.description_outlined),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.save_as_outlined),
          onPressed: () => _saveAs(context, ref),
          child: Text(l10n.documentsSaveAs),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.close),
          onPressed: () => _close(context, ref),
          child: Text(l10n.documentsClose),
        ),
      ],
    );
  }

  Future<void> _saveAs(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final session = ref.read(openDocumentProvider);
    if (session == null) return;

    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'FlowMap', extensions: ['flowmap']),
      ],
      initialDirectory: (await documentsDirectory()).path,
      suggestedName: '${session.projectName}.flowmap',
    );
    if (location == null || !context.mounted) return;

    var path = location.path;
    if (!path.toLowerCase().endsWith('.flowmap')) path = '$path.flowmap';
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      // The copy is a separate project with its own id, so its runs are its own
      // — which is what makes "open a reference and save a copy" give you your
      // plant rather than a second window onto somebody else's.
      final outcome = await ref
          .read(openDocumentProvider.notifier)
          .saveAs(
            path,
            user:
                Platform.environment['USERNAME'] ??
                Platform.environment['USER'] ??
                'someone',
            machine: Platform.localHostname,
          );
      if (outcome.unsaved) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.documentsCurrentUnsaved)),
        );
        return;
      }
      if (outcome.taken) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.documentsTakenHelp)),
        );
        return;
      }
      final opened = ref.read(openDocumentProvider);
      if (opened != null) router.go('/projects/${opened.projectId}');
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.documentsOpenFailed)));
    }
  }

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    // Closing flushes and releases the lock before it returns, so the next
    // person opens a file that is current rather than one edit behind.
    await ref.read(openDocumentProvider.notifier).close();
    router.go('/projects');
  }
}
