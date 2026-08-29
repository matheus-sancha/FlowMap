/// Which language the app draws itself in (DESIGN.md §12.4).
library;

import 'dart:ui' show Locale;

/// The chosen language, or [system] to follow the platform.
///
/// **The app shipped es and pt translated and unreachable.** `MaterialApp` was
/// given `supportedLocales` and no `locale:`, so the language was whatever
/// Windows said and Settings offered only the date format — which is why every
/// es/pt line in §0 stayed open from 2026-08-15 to the drive that found this:
/// they were written as checks and were never performable. §8.7.
///
/// **[system] is the default, and is exactly what the app did before.** An
/// install that never opens Settings is unchanged by this existing, which is
/// the same bargain [DateFormatSetting.locale] makes for dates.
///
/// The values are named for their language subtags because that is what
/// [locale] hands `MaterialApp` and what `supportedLocales` matches on. Adding
/// a language means an ARB file, a value here, and a name for it in all three
/// ARBs — nothing else.
enum AppLanguage {
  /// Resolve against the platform, as `MaterialApp` does when given no locale.
  system,

  en,
  es,
  pt;

  /// What is stored in `app_settings`, and what an unknown value falls back to.
  ///
  /// Written by name rather than by index so reordering this enum cannot
  /// silently change what an existing install reads back — the rule
  /// [DateFormatSetting.fromStored] already follows.
  static AppLanguage fromStored(String? stored) => AppLanguage.values.firstWhere(
    (language) => language.name == stored,
    orElse: () => AppLanguage.system,
  );

  /// The locale to hand `MaterialApp`, or **null to let it resolve the
  /// platform's** — which is what passing no locale at all did.
  ///
  /// Null rather than a guess at the system language: `MaterialApp` already
  /// knows how to match the platform against `supportedLocales`, including the
  /// fallbacks for a region it does not have, and reimplementing that here
  /// would be a second answer that could disagree with the first.
  Locale? get locale => this == AppLanguage.system ? null : Locale(name);
}
