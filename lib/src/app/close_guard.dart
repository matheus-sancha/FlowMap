import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../features/diagnostics/application/diagnostics.dart';
import '../features/documents/application/documents_providers.dart';

/// Closes the open document before the window goes (drive, 2026-09-13).
///
/// **Closing the window used to end the process with the document still open.**
/// Nothing between the close button and the exit ran `DocumentSession.close`, so
/// two things were lost every time: the edits still inside the two-second save
/// debounce, and the lock, which stayed on the file for five minutes and told
/// the same person on the next launch that someone had it open. The lock is
/// the visible half; the lost edit is the half nobody would ever notice until
/// the number was wrong.
///
/// So the window refuses to close on its own, and this closes the document —
/// flush, then release — and only then lets it go.
///
/// **Bounded**: a document on a share that has gone away can take its write
/// with it, and a close button that never closes is worse than the lock it was
/// protecting. After [flushFor] the window goes regardless; the work is still
/// in the working database, and the lock goes stale on its own.
class CloseGuard extends ConsumerStatefulWidget {
  const CloseGuard({super.key, required this.child});

  final Widget child;

  static const flushFor = Duration(seconds: 8);

  @override
  ConsumerState<CloseGuard> createState() => _CloseGuardState();
}

class _CloseGuardState extends ConsumerState<CloseGuard> with WindowListener {
  bool _closing = false;

  bool get _desktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (!_desktop) return;
    windowManager.addListener(this);
    // Not awaited, and failures swallowed: under `flutter test` there is no
    // window plugin, and a guard that could stop the app starting is worse
    // than none.
    unawaited(windowManager.setPreventClose(true).catchError((Object _) {}));
  }

  @override
  void dispose() {
    if (_desktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    if (_closing) return;
    _closing = true;
    final open = ref.read(openDocumentProvider) != null;
    Diag.event('app.close', open ? 'closing document' : 'nothing open');
    try {
      await ref
          .read(openDocumentProvider.notifier)
          .close()
          .timeout(CloseGuard.flushFor);
    } catch (error, stack) {
      Diag.error('app.close', error, stack);
    }
    Diag.event('app.closed');
    // The log appends through a chained future; destroying first would end the
    // process with the last lines of the session still unwritten.
    try {
      await Diag.log?.flush().timeout(const Duration(seconds: 2));
    } catch (_) {}
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
