import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app/app.dart';
import 'src/app/app_scale.dart';
import 'src/app/app_scale_setting.dart';
import 'src/app/window_geometry.dart';
import 'package:flutter/foundation.dart';

import 'src/app/build_info.dart';
import 'src/app/window_geometry_observer.dart';
import 'src/features/diagnostics/application/diagnostics.dart';

/// Wiring only, and the order is load-bearing.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before anything else: a release build that cannot say which build it is
  // must not reach a machine nobody can inspect (#32).
  assertBuildIsStamped(isReleaseMode: kReleaseMode);
  // Loads intl's date symbols for every locale up front. PDF and Excel exports
  // format dates outside the widget tree (DESIGN.md §13), so we cannot rely on
  // the symbols flutter_localizations lazily loads for the active one.
  await initializeDateFormatting();
  // First, so the session header precedes anything worth logging and the error
  // hooks are in place before any code that could trip them (DESIGN.md §15).
  await Diag.install();

  // Desktop only: Windows does not remember a window's size, position or
  // maximised state for an application, so the app does it.
  var scale = AppScale.noScale;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    final windowObserver = WindowGeometryObserver();
    windowManager.addListener(windowObserver);
    // Before runApp, so the window is placed while it is still hidden and the
    // runner's first-frame callback reveals it already in the right spot.
    // Seeding the observer matters: a user whose first action is to maximise
    // has no stored frame yet, so nothing would be saved at all.
    windowObserver.rememberNormalBounds(await WindowGeometry.restore());
    // Beside the geometry and for the same reason: the window is placed while
    // it is still hidden, and the scale it will be drawn at has to be known by
    // then too. Read here rather than from a provider inside the tree so the
    // first frame is already the right size — a scale that arrived later would
    // snap the whole app on every launch (#48).
    scale = await WindowChrome.scale();
  }

  runApp(
    ProviderScope(
      observers: const [DiagnosticsObserver()],
      overrides: [initialAppScaleProvider.overrideWithValue(scale)],
      child: const FlowMapApp(),
    ),
  );
}
