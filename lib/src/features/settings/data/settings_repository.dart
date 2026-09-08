/// App-wide preferences, in the key/value table that has existed since M1
/// (DESIGN.md §12.4).
///
/// **Not project-scoped.** How a date is written is a property of the person
/// reading the screen, not of the plant being modelled — two projects open on
/// one machine should not disagree about what `03/08/2026` means.
library;

import 'package:drift/drift.dart';

import '../../../common/app_language.dart';
import '../../../common/app_theme_mode.dart';
import '../../../common/date_input.dart';
import '../../../data/database/database.dart';

/// The `app_settings` key the date format lives under.
///
/// Namespaced, because this table already holds a seed stamp and will hold
/// whatever the Settings screen grows next.
const dateFormatKey = 'display.dateFormat';

/// The `app_settings` key the chosen language lives under (§8.7).
const languageKey = 'display.language';

/// The `app_settings` key the chosen theme lives under.
const themeModeKey = 'display.themeMode';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  /// The chosen format, or [DateFormatSetting.locale] when nothing is stored.
  ///
  /// A stream, so every date on screen re-renders the moment the setting
  /// changes rather than on the next rebuild that happens for another reason.
  Stream<DateFormatSetting> watchDateFormat() =>
      (_db.select(_db.appSettings)..where((s) => s.key.equals(dateFormatKey)))
          .watchSingleOrNull()
          .map((row) => DateFormatSetting.fromStored(row?.value));

  /// The chosen language, or [AppLanguage.system] when nothing is stored.
  ///
  /// A stream for the same reason the format is one: the whole app re-renders
  /// the moment it changes, rather than on the next rebuild that happens for
  /// another reason. There is more riding on it here — every string in the
  /// tree rather than every date.
  Stream<AppLanguage> watchLanguage() =>
      (_db.select(_db.appSettings)..where((s) => s.key.equals(languageKey)))
          .watchSingleOrNull()
          .map((row) => AppLanguage.fromStored(row?.value));

  /// The chosen theme, or [AppThemeMode.system] when nothing is stored.
  ///
  /// A stream for the reason the other two are: the whole tree repaints the
  /// moment it changes. Cheaper than the language — the same widgets in
  /// different colours rather than different strings — but read every bit as
  /// widely, so it gets the same treatment.
  Stream<AppThemeMode> watchThemeMode() =>
      (_db.select(_db.appSettings)..where((s) => s.key.equals(themeModeKey)))
          .watchSingleOrNull()
          .map((row) => AppThemeMode.fromStored(row?.value));

  Future<void> setThemeMode(AppThemeMode mode) =>
      _db
          .into(_db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: themeModeKey,
              value: Value(mode.name),
              updatedAt: DateTime.now(),
            ),
          );

  Future<void> setLanguage(AppLanguage language) =>
      _db
          .into(_db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: languageKey,
              value: Value(language.name),
              updatedAt: DateTime.now(),
            ),
          );

  Future<void> setDateFormat(DateFormatSetting setting) =>
      _db
          .into(_db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: dateFormatKey,
              value: Value(setting.name),
              updatedAt: DateTime.now(),
            ),
          );
}
