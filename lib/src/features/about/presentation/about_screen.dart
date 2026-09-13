import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/build_info.dart';
import '../../../app/flowmap_mark.dart';
import '../../../data/app_directory.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../diagnostics/data/diagnostics_log.dart';
import '../../documents/data/documents_directory.dart';

/// What build this is, and where everything lives.
///
/// **This exists because the support channel is a sentence** (#32). Twenty
/// installs, and the only way a problem reaches the developer is somebody
/// saying what happened — which is unactionable without knowing which build
/// they are on, and unfixable without being able to get at their files. Two
/// instructions have to work over a phone call: *read me the build*, and *open
/// that folder and send me what is in it*.
///
/// **`kBuildLabel` is not new; a screen showing it is.** It has been stamped on
/// the diagnostics header and both exports since before v2.1 — nothing
/// displayed it.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navAbout)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              Row(
                children: [
                  // The mark on the one screen whose job is saying what this
                  // app is. Drawn, so it follows the theme (#33).
                  const FlowmapMark(size: 36),
                  const SizedBox(width: 12),
                  Text('FlowMap', style: theme.textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 24),

              _Section(title: l10n.aboutBuild),
              _Copyable(
                value: kBuildLabel,
                // A version somebody has to retype into a message gets retyped
                // wrong, so it is one tap to the clipboard.
                tooltip: l10n.aboutCopy,
              ),
              if (kBuildLabel == 'dev')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.aboutUnstamped,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              _Section(title: l10n.aboutYourWork),
              _FolderRow(
                future: documentsDirectory(),
                caption: l10n.aboutYourWorkHelp,
              ),

              const SizedBox(height: 24),
              _Section(title: l10n.aboutAppData),
              _FolderRow(
                future: appDataDirectory(),
                caption: l10n.aboutAppDataHelp,
              ),

              const SizedBox(height: 24),
              _Section(title: l10n.aboutDiagnostics),
              _DiagnosticsRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Copyable extends StatelessWidget {
  const _Copyable({required this.value, required this.tooltip});
  final String value;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Flexible(
          child: SelectableText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton(
          tooltip: tooltip,
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () => Clipboard.setData(ClipboardData(text: value)),
        ),
      ],
    );
  }
}

/// A folder, its path, and a button that opens it.
///
/// **The button is the point.** Nobody being supported can be walked to
/// `%APPDATA%\com.sancha\flowmap` over a phone call, and asking them to type it
/// is how a support call becomes an afternoon.
class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.future, required this.caption});

  final Future<Directory> future;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return FutureBuilder<Directory>(
      future: future,
      builder: (context, snapshot) {
        final dir = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: SelectableText(
                    dir?.path ?? '…',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: dir == null ? null : () => revealFolder(dir.path),
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(l10n.aboutOpenFolder),
                ),
              ],
            ),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DiagnosticsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return FutureBuilder<Directory>(
      future: appDataDirectory(),
      builder: (context, snapshot) {
        final dir = snapshot.data;
        final log = dir == null
            ? null
            : File('${dir.path}${Platform.pathSeparator}'
                  '${DiagnosticsLog.logFileName}');
        final exists = log?.existsSync() ?? false;

        return Row(
          children: [
            Flexible(
              child: Text(
                DiagnosticsLog.logFileName,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: exists ? () => revealFile(log!.path) : null,
              icon: const Icon(Icons.article_outlined, size: 18),
              label: Text(l10n.aboutOpenLog),
            ),
          ],
        );
      },
    );
  }
}

/// Opens a folder in the file manager.
///
/// Deliberately no dependency: one `explorer` call on Windows, and the
/// platform's own opener elsewhere. Failures are swallowed — a button that
/// cannot open a folder must not be a crash.
Future<void> revealFolder(String path) async {
  try {
    if (Platform.isWindows) {
      await Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else {
      await Process.run('xdg-open', [path]);
    }
  } catch (_) {}
}

/// Opens a file, selecting it in its folder on Windows.
Future<void> revealFile(String path) async {
  try {
    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', path]);
    } else {
      await revealFolder(path);
    }
  } catch (_) {}
}
