/// App-wide preferences, in the key/value table that has existed since M1
/// (DESIGN.md §12.4).
///
/// **Not project-scoped.** How a date is written is a property of the person
/// reading the screen, not of the plant being modelled — two projects open on
/// one machine should not disagree about what `03/08/2026` means.
library;

import 'package:drift/drift.dart';

import '../../../common/date_input.dart';
import '../../../data/database/database.dart';

/// The `app_settings` key the date format lives under.
///
/// Namespaced, because this table already holds a seed stamp and will hold
/// whatever the Settings screen grows next.
const dateFormatKey = 'display.dateFormat';

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
