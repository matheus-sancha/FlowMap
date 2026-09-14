/// Which brightness the app draws itself in (DESIGN.md §12.4).
library;

import 'package:flutter/material.dart' show ThemeMode;

/// The chosen theme, or [system] to follow the platform.
///
/// **The app had two themes and no way to reach either.** `app.dart` handed
/// `MaterialApp` a `theme:` and a `darkTheme:` and no `themeMode:`, so the
/// brightness was whatever Windows said — and the only way to see the light
/// palette was to change an OS-wide personalisation setting and change it
/// back. Light mode escaped four drive sittings in a row partly because
/// looking at it cost more than looking at anything else on the sheet.
///
/// **[system] is the default, and is exactly what the app did before.** An
/// install that never opens Settings is unchanged by this existing — the same
/// bargain [AppLanguage.system] and [DateFormatSetting.locale] both make.
///
/// The values are named for the `ThemeMode` they hand `MaterialApp`, because
/// that is the whole of what this enum decides.
enum AppThemeMode {
  /// Resolve against the platform, as `MaterialApp` does when given no mode.
  system,

  light,
  dark;

  /// What is stored in `app_settings`, and what an unknown value falls back to.
  ///
  /// Written by name rather than by index so reordering this enum cannot
  /// silently change what an existing install reads back — the rule
  /// [AppLanguage.fromStored] already follows.
  static AppThemeMode fromStored(String? stored) =>
      AppThemeMode.values.firstWhere(
        (mode) => mode.name == stored,
        orElse: () => AppThemeMode.system,
      );

  /// The mode to hand `MaterialApp`.
  ///
  /// Unlike [AppLanguage.locale] this has no null case: `ThemeMode.system` is
  /// itself the *follow the platform* answer, so there is nothing to leave
  /// unsaid.
  ThemeMode get themeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}
