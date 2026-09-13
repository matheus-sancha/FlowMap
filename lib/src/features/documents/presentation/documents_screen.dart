import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../common/dialogs.dart';
import '../../../app/drop_files.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/documents_providers.dart';
import '../data/document_lock.dart';
import '../data/documents_directory.dart';
import '../data/flowmap_document.dart';
import '../data/new_document.dart';
import '../data/recent_documents.dart';
import 'opening_screen.dart';

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
    // **What is open, said on the screen you return to.** It read *No project
    // open* while one was, so a document opened from here looked like nothing
    // had happened, and a second click met the document's own lock.
    final session = ref.watch(openDocumentProvider);

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
              Text(
                session == null
                    ? l10n.documentsNone
                    : l10n.documentsIsOpen(session.projectName),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // The primary action is whichever one gets the reader back to
                  // work: into the open project if there is one, else Open.
                  if (session != null)
                    FilledButton.icon(
                      onPressed: () => _goToOpenProject(context, ref),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(l10n.documentsGoToProject),
                    ),
                  if (session == null)
                    FilledButton.icon(
                      onPressed: () => _open(context, ref),
                      icon: const Icon(Icons.folder_open),
                      label: Text(l10n.documentsOpen),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _open(context, ref),
                      icon: const Icon(Icons.folder_open),
                      label: Text(l10n.documentsOpen),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _create(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.documentsNew),
                  ),
                ],
              ),
              // **The example, offered by name while there is nothing else**
              // (#28). It opens as the reader's own copy in their documents
              // folder: the zip's file stays the original, a program folder may
              // not be writable, and the next drop would overwrite it anyway.
              if (shippedFile(exampleFileName) != null &&
                  (recents.value?.isEmpty ?? false)) ...[
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.factory_outlined),
                    title: Text(l10n.documentsExample),
                    subtitle: Text(l10n.documentsExampleHelp),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openExample(context, ref),
                  ),
                ),
              ],
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

  Future<void> _openExample(BuildContext context, WidgetRef ref) async {
    final example = shippedFile(exampleFileName);
    if (example == null) return;
    final l10n = AppLocalizations.of(context);
    final directory = await documentsDirectory();
    await directory.create(recursive: true);
    // A copy that already exists is reopened rather than replaced: it is the
    // reader's work now.
    final copy = File(p.join(directory.path, l10n.documentsExampleFile));
    if (!copy.existsSync()) await example.copy(copy.path);
    if (!context.mounted) return;
    await openDocumentAt(context, ref, copy.path);
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

    // **The plant is named by the person, never by the app** (field report,
    // 2026-09-13): it was `Plant` in every new document, a word nobody chose.
    // Asked after the file because the project's name comes from the file, and
    // cancelling here writes nothing.
    final plantName = await promptForName(
      context,
      title: l10n.plantNew,
      label: l10n.fieldName,
    );
    if (plantName == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      // A new document starts with the seeded reference data and nothing else.
      // A reference *plant* is something you open and Save As — a copy the user
      // chose, rather than content the app pressed on them.
      final outcome = await whileOpening(
        context,
        NewDocument.projectNameFor(path),
        () => ref
            .read(openDocumentProvider.notifier)
            .create(
              path,
              projectName: NewDocument.projectNameFor(path),
              plantName: plantName,
              user: _user(),
              machine: Platform.localHostname,
            ),
      );
      if (outcome.unsaved) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.documentsCurrentUnsaved)),
        );
        return;
      }
      _reportConflictCopy(messenger, l10n, outcome.conflictCopy);
      if (outcome.taken) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.documentsTakenHelp)),
        );
        return;
      }
      if (context.mounted) _goToOpenProject(context, ref);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.documentsOpenFailed)));
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
    final outcome = await whileOpening(
      context,
      NewDocument.projectNameFor(path),
      () => ref
          .read(openDocumentProvider.notifier)
          .open(path, user: _user(), machine: Platform.localHostname),
    );

    if (outcome.unsaved) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.documentsCurrentUnsaved)),
      );
      return;
    }
    _reportConflictCopy(messenger, l10n, outcome.conflictCopy);
    if (outcome.taken) {
      // **Held by this account on this computer** is not a colleague: it is
      // another FlowMap window, or this one before it crashed. A message naming
      // the reader as the one in their own way reads as a bug.
      final here =
          holder != null &&
          holder.user == _user() &&
          holder.machine == Platform.localHostname;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            here
                ? l10n.documentsTakenHere
                : '${l10n.documentsTaken(holder?.describe() ?? '')}\n'
                      '${l10n.documentsTakenHelp}',
          ),
        ),
      );
      return;
    }
    // **Opening a document goes to it**, which 201290c said of both paths and
    // gave to New project only. Open and every recent entry come through here,
    // and they loaded the project while leaving the reader on this screen.
    if (context.mounted) _goToOpenProject(context, ref);
  } on DocumentFormatException catch (error) {
    // The message is the point: these are the first errors in this app read by
    // someone who cannot ask the author what they mean.
    messenger.showSnackBar(
      SnackBar(content: Text('${l10n.documentsOpenFailed}\n${error.message}')),
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.documentsOpenFailed)));
  }
}

/// Says where work went when its file had been replaced on disk, if it did.
///
/// A copy nobody is told about is a copy nobody finds.
void reportConflictCopy(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  File? copy,
) {
  if (copy == null) return;
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 10),
      content: Text(l10n.documentsConflictKept(p.basename(copy.path))),
    ),
  );
}

void _reportConflictCopy(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  File? copy,
) => reportConflictCopy(messenger, l10n, copy);

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
    final session = ref.watch(openDocumentProvider);

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
              final isOpen =
                  session != null &&
                  isSameDocument(session.file.path, document.path);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  here ? Icons.description_outlined : Icons.cloud_off_outlined,
                  color: here ? null : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(document.name),
                selected: isOpen,
                subtitle: Text(
                  here
                      ? '${document.folder} · ${dates.format(document.openedAt)}'
                      : '${l10n.documentsMissing} · ${document.folder}',
                ),
                // Instead of Forget: nobody means to forget the document they
                // are working on, and the row has to say which one that is.
                trailing: isOpen
                    ? Chip(label: Text(l10n.documentsOpenNow))
                    : IconButton(
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
