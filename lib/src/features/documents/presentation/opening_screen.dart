import 'package:flutter/material.dart';

import '../../../app/flowmap_mark.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Runs [work] behind a whole-window "Opening VSM 2026 Q1…" screen.
///
/// **Opening a project is not instant, and the start screen used to sit still
/// through it.** Reading the file, taking the lock, saving whatever was open
/// and loading every table can take seconds on a network share — with nothing
/// on screen changing, which reads as a click that did not land, and invites the
/// second click. The screen also covers the window, so nothing can be pressed
/// while the working tables are being replaced.
Future<T> whileOpening<T>(
  BuildContext context,
  String projectName,
  Future<T> Function() work,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var showing = true;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, _, _) => PopScope(
      canPop: false,
      child: _OpeningScreen(projectName: projectName),
    ),
  ).whenComplete(() => showing = false);

  try {
    return await work();
  } finally {
    if (showing) navigator.pop();
  }
}

class _OpeningScreen extends StatelessWidget {
  const _OpeningScreen({required this.projectName});

  final String projectName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The same shape as the startup screen, so opening a project looks like
    // the app it is rather than a dialog over it.
    return Material(
      color: theme.colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FlowmapMark(size: 40),
              const SizedBox(height: 24),
              const SizedBox(width: 160, child: LinearProgressIndicator()),
              const SizedBox(height: 16),
              Text(
                l10n.documentsOpening(projectName),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
