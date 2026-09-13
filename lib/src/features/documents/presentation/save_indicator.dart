import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/document_session.dart';
import '../application/documents_providers.dart';

/// The whole of the app's save vocabulary: `saved 14:22`, `saving…`, or a
/// failure that says the work is not lost.
///
/// **There is no Save button and this is not one** (#37). Every edit commits to
/// the database as it always has; this only reports whether the file has caught
/// up. §12 has never had a Save, and unsaved work would be new vocabulary on
/// every screen for people who cannot be walked through recovery.
///
/// It shows nothing at all when no document is open, because there is then
/// nothing to be behind.
class SaveIndicator extends ConsumerWidget {
  const SaveIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(openDocumentProvider);
    if (session == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return StreamBuilder<SaveState>(
      stream: session.states,
      initialData: session.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? SaveState.saved;

        return switch (state) {
          SaveState.saving => _Line(
            icon: SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: muted),
            ),
            text: l10n.documentsSaving,
            color: muted,
          ),
          SaveState.saved => _Line(
            icon: Icon(Icons.cloud_done_outlined, size: 16, color: muted),
            text: l10n.documentsSaved(
              session.savedAt == null
                  ? ''
                  : DateFormat.Hm(
                      Localizations.localeOf(context).toString(),
                    ).format(session.savedAt!),
            ),
            color: muted,
          ),
          // **Never silent, and never alarming past what is true.** The work is
          // in the database; it is the file that is behind, and the next change
          // tries again.
          SaveState.failed => Tooltip(
            message: l10n.documentsSaveFailedHelp,
            child: _Line(
              icon: Icon(
                Icons.sync_problem_outlined,
                size: 16,
                color: theme.colorScheme.error,
              ),
              text: l10n.documentsSaveFailed,
              color: theme.colorScheme.error,
            ),
          ),
        };
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, required this.color});

  final Widget icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}
