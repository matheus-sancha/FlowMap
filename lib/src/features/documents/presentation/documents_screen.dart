import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/documents_providers.dart';
import '../data/document_lock.dart';
import '../data/documents_directory.dart';
import '../data/flowmap_document.dart';
import '../data/new_document.dart';
import '../data/recent_documents.dart';

/// What the app shows when no project is open.
///
/// **This replaced the projects list.** A project used to be a row in the
/// database and this screen enumerated them; since #37 a project is a file, so
/// there is nothing to enumerate — only somewhere to open one from. The archive
/// toggle and the create-project dialog went with it: archiving a file is
/// deleting it, and creating one is choosing where it goes.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final recents = ref.watch(recentDocumentsProvider);

    // Kicks off the one-time conversion on the single machine that needs it.
    ref.watch(convertedDocumentsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              Text(l10n.documentsNone, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                l10n.documentsIntro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => _open(context, ref),
                    icon: const Icon(Icons.folder_open),
                    label: Text(l10n.documentsOpen),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _create(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.documentsNew),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              recents.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const SizedBox.shrink(),
                data: (documents) => documents.isEmpty
                    ? const SizedBox.shrink()
                    : _Recent(documents: documents),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'FlowMap', extensions: ['flowmap']),
      ],
      initialDirectory: (await documentsDirectory()).path,
    );
    if (file == null || !context.mounted) return;
    await openDocumentAt(context, ref, file.path);
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'FlowMap', extensions: ['flowmap']),
      ],
      initialDirectory: (await documentsDirectory()).path,
      suggestedName: '${l10n.documentsNew.replaceAll('…', '')}.flowmap',
    );
    if (location == null || !context.mounted) return;

    var path = location.path;
    if (!path.toLowerCase().endsWith('.flowmap')) path = '$path.flowmap';
    final messenger = ScaffoldMessenger.of(context);

    try {
      // A new document starts with the seeded reference data and nothing else.
      // A reference *plant* is something you open and Save As — a copy the user
      // chose, rather than content the app pressed on them.
      final outcome = await ref
          .read(openDocumentProvider.notifier)
          .create(
            path,
            projectName: NewDocument.projectNameFor(path),
            plantName: l10n.documentsDefaultPlant,
            user: _user(),
            machine: Platform.localHostname,
          );
      if (outcome.taken) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.documentsTakenHelp)),
        );
        return;
      }
      if (context.mounted) _goToOpenProject(context, ref);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.documentsOpenFailed)),
      );
    }
  }
}

/// Opens [path] and reports the two things that can go wrong in words.
///
/// Shared with anything else that opens a document, so the messages a person
/// sees do not depend on which button they pressed.
Future<void> openDocumentAt(
  BuildContext context,
  WidgetRef ref,
  String path,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  try {
    final holder = DocumentLock.holderOf(path);
    final outcome = await ref
        .read(openDocumentProvider.notifier)
        .open(path, user: _user(), machine: Platform.localHostname);

    if (outcome.taken) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.documentsTaken(holder?.describe() ?? '')}\n'
            '${l10n.documentsTakenHelp}',
          ),
        ),
      );
    }
  } on DocumentFormatException catch (error) {
    // The message is the point: these are the first errors in this app read by
    // someone who cannot ask the author what they mean.
    messenger.showSnackBar(
      SnackBar(content: Text('${l10n.documentsOpenFailed}\n${error.message}')),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.documentsOpenFailed)),
    );
  }
}

/// Navigates to the project the open document holds.
///
/// A document *is* one project, so there is exactly one place to go and no
/// choice to offer.
void _goToOpenProject(BuildContext context, WidgetRef ref) {
  final session = ref.read(openDocumentProvider);
  if (session == null || !context.mounted) return;
  context.go('/projects/${session.projectId}');
}

/// Who the lock will say is holding the document. Names the account rather than
/// a display name, because that is what a colleague will recognise on a share.
String _user() =>
    Platform.environment['USERNAME'] ??
    Platform.environment['USER'] ??
    'someone';

class _Recent extends ConsumerWidget {
  const _Recent({required this.documents});

  final List<RecentDocument> documents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = DateFormat.yMMMd(Localizations.localeOf(context).toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.documentsRecent, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final document in documents)
          Builder(
            builder: (context) {
              // Asked now rather than remembered: a document on a share is
              // missing whenever the drive is, which is a fact about this
              // minute and not about the work.
              final here = document.exists;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  here ? Icons.description_outlined : Icons.cloud_off_outlined,
                  color: here ? null : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(document.name),
                subtitle: Text(
                  here
                      ? '${document.folder} · ${dates.format(document.openedAt)}'
                      : '${l10n.documentsMissing} · ${document.folder}',
                ),
                trailing: IconButton(
                  tooltip: l10n.documentsForget,
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    await ref
                        .read(recentDocumentsStoreProvider)
                        .forget(document.path);
                    ref.invalidate(recentDocumentsProvider);
                  },
                ),
                onTap: here
                    ? () => openDocumentAt(context, ref, document.path)
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.documentsMissingHelp)),
                      ),
              );
            },
          ),
      ],
    );
  }
}
