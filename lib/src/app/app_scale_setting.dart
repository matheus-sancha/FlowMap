/// The scale the app is running at, and the one way to change it (#48).
///
/// **Seeded before the first frame, not corrected after it.** The sibling
/// window-chrome provider, `StudiesPaneCollapsed`, starts at a default and
/// fixes itself when the file arrives — a pane that appears and then collapses
/// is a small wrong. A *scale* that does that is the whole app snapping size on
/// every launch, so the value is read in `main` and handed in here instead.
/// That is the reason the scale is in `window.json` at all rather than beside
/// the theme in `app_settings`: a json file can be read with `dart:io` before
/// `runApp`, and the database cannot be read until it is open.
///
/// **Optimistic, like the pane.** Setting a scale moves the app immediately and
/// the write follows. A disk write that fails leaves the app at the scale the
/// reader picked for this session, and Diag has the error; making the whole
/// tree wait on a file write would be worse than forgetting by tomorrow.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/diagnostics/application/diagnostics.dart';
import 'app_scale.dart';
import 'window_geometry.dart';

part 'app_scale_setting.g.dart';

/// The scale `main` read from `window.json`, overridden in the `ProviderScope`.
///
/// Left at [AppScale.noScale] when nothing overrides it, which is what every
/// widget test and the non-desktop path get: the app as drawn.
final initialAppScaleProvider = Provider<double>(
  (ref) => AppScale.noScale,
  name: 'initialAppScale',
);

@Riverpod(keepAlive: true)
class AppScaleSetting extends _$AppScaleSetting {
  @override
  double build() => AppScale.clamp(ref.watch(initialAppScaleProvider));

  /// Moves the app to [scale] now, and remembers it.
  ///
  /// Clamped on the way in as well as on the way out, so a caller that has not
  /// taken its value from [AppScale.steps] cannot put the app somewhere the
  /// menu could not bring it back from.
  void set(double scale) {
    final next = AppScale.clamp(scale);
    if (next == state) return;
    state = next;
    WindowChrome.setScale(next);
    // The floor moves with the scale (#50), so the window's minimum has to be
    // re-applied here rather than only at launch. Not awaited and failures
    // swallowed, as in `CloseGuard`: under `flutter test` there is no window
    // plugin, and the scale must still change if the window will not listen.
    unawaited(
      WindowGeometry.applyMinimumFor(next).catchError((Object error, StackTrace s) {
        Diag.error('window.minimum', error, s);
      }),
    );
  }
}
