import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../data/app_directory.dart';
import '../data/database/database_providers.dart';
import '../features/about/presentation/about_screen.dart' show revealFolder;
import '../features/diagnostics/application/diagnostics.dart';
import '../l10n/generated/app_localizations.dart';
import 'flowmap_mark.dart';

/// Resolves when the database has opened and every migration has run.
///
/// The database is lazy (`LazyDatabase`), so the first query is what opens it,
/// copies it aside and migrates it. Asking once here, before any screen does,
/// is what gives that moment a face of its own instead of a failed stream in
/// whichever screen happened to query first.
final databaseReadyProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  try {
    await db.customSelect('SELECT 1').get();
  } catch (error, stack) {
    Diag.error('startup.database', error, stack);
    rethrow;
  }
});

/// The first data load and its failure, in front of everything else (#33).
///
/// **There is no splash, because there is no gap**: the window stays hidden
/// until its first frame is drawn, so a branded pause would decorate an instant
/// moment. The wait that exists is this one — opening a 170 MB file and running
/// whatever migrations it needs — and **it is the one that can fail**. So the
/// effort goes here: a quiet state if it is slow, and a failure a person who
/// cannot read a stack trace can act on.
///
/// _Rejected: a native pre-Flutter splash, and an in-app splash held until data
/// arrives._ Both brand a moment that is usually too short to see, and neither
/// says anything when the moment goes wrong.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key, required this.child});

  final Widget child;

  /// How long an open may take before the waiting state appears. Shorter, and
  /// an ordinary launch flashes a sentence nobody can read.
  static const quietFor = Duration(milliseconds: 700);

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  bool _slow = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(StartupGate.quietFor, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(databaseReadyProvider);
    return switch (ready) {
      AsyncData() => widget.child,
      AsyncError(:final error) => _StartupFailure(
        error: error,
        onRetry: () {
          // The connection too, not only the probe: a database that failed to
          // open is not asked again by querying the same failed handle.
          ref.invalidate(appDatabaseProvider);
          ref.invalidate(databaseReadyProvider);
        },
      ),
      _ =>
        _slow
            ? const _StartupWaiting()
            : const ColoredBox(color: Colors.transparent),
    };
  }
}

class _StartupWaiting extends StatelessWidget {
  const _StartupWaiting();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlowmapMark(size: 40),
            const SizedBox(height: 24),
            const SizedBox(width: 160, child: LinearProgressIndicator()),
            const SizedBox(height: 16),
            Text(l10n.startupOpening, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.startupOpeningHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What someone sees when their data will not open.
///
/// **Three things they can do, and no stack trace**: open the folder (where the
/// log and the pre-update copy both are), copy the details to paste into a
/// message, and try again. The error text is behind *Copy details* rather than
/// on screen, because on screen it reads as the app's answer and it is not one
/// a reader can use.
///
/// _Rejected: a Restore button._ #28 declined it for About, and the reason is
/// stronger here: a destructive action on the one screen a confused user is
/// already poking at.
class _StartupFailure extends StatefulWidget {
  const _StartupFailure({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  State<_StartupFailure> createState() => _StartupFailureState();
}

class _StartupFailureState extends State<_StartupFailure> {
  String? _folder;
  String? _backup;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  /// The folder, and the newest pre-update copy in it if there is one.
  Future<void> _locate() async {
    try {
      final dir = await appDataDirectory();
      final backups =
          dir
              .listSync()
              .whereType<File>()
              .where(
                (f) => RegExp(
                  r'^flowmap\.pre-v\d+\.sqlite$',
                ).hasMatch(p.basename(f.path)),
              )
              .toList()
            ..sort(
              (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
            );
      if (!mounted) return;
      setState(() {
        _folder = dir.path;
        _backup = backups.isEmpty ? null : p.basename(backups.first.path);
      });
    } catch (_) {
      // The screen still says what to do without the folder's name.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 40,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(l10n.startupFailed, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(l10n.startupFailedHelp, style: theme.textTheme.bodyLarge),
                if (_backup case final backup?) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.startupFailedBackup(backup),
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
                if (_folder case final folder?) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    folder,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                      label: Text(l10n.aboutOpenFolder),
                      onPressed: _folder == null
                          ? null
                          : () => revealFolder(_folder!),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: Text(l10n.startupCopyDetails),
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: '${widget.error}'),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onRetry,
                      child: Text(l10n.startupRetry),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
