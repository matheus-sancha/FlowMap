// `package:drift/drift.dart` is deliberately not imported, for the reason
// `language_test.dart` gives: it exports `isNull`/`isNotNull` as column
// expressions, which collide with the matchers of the same name.
import 'package:drift/native.dart';
import 'package:flowmap/src/common/app_language.dart';
import 'package:flowmap/src/common/app_theme_mode.dart';
import 'package:flowmap/src/common/date_input.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/settings/application/settings_providers.dart';
import 'package:flowmap/src/features/settings/data/settings_repository.dart';
import 'package:flowmap/src/features/settings/presentation/settings_screen.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The theme picker.
///
/// **The two themes were never the missing piece.** `FlowMapTheme.light()` and
/// `FlowMapTheme.dark()` both shipped and `MaterialApp` was handed both — with
/// no `themeMode:`, so the choice belonged to Windows and the only way to see
/// the light palette was an OS-wide setting changed and changed back. These
/// pin the wiring, exactly as the language tests pin `locale:`.
void main() {
  late AppDatabase db;
  late SettingsRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = SettingsRepository(db);
  });

  tearDown(() => db.close());

  group('AppThemeMode', () {
    test('nothing stored means follow the platform', () {
      expect(AppThemeMode.fromStored(null), AppThemeMode.system);
      expect(AppThemeMode.system.themeMode, ThemeMode.system);
    });

    test('an unknown value falls back rather than throwing', () {
      // What an install downgraded from a build that knew more modes reads
      // back. Following the platform is the one answer that cannot be wrong.
      expect(AppThemeMode.fromStored('sepia'), AppThemeMode.system);
    });

    test('every value round-trips through storage by name', () {
      for (final mode in AppThemeMode.values) {
        expect(AppThemeMode.fromStored(mode.name), mode);
      }
    });

    test('each value is the ThemeMode it is named for', () {
      expect(AppThemeMode.light.themeMode, ThemeMode.light);
      expect(AppThemeMode.dark.themeMode, ThemeMode.dark);
    });
  });

  group('the repository', () {
    test('a fresh database follows the platform', () async {
      expect(await repository.watchThemeMode().first, AppThemeMode.system);
    });

    test('a choice is stored and streamed back', () async {
      await repository.setThemeMode(AppThemeMode.light);
      expect(await repository.watchThemeMode().first, AppThemeMode.light);
    });

    test('choosing again replaces rather than adding a row', () async {
      await repository.setThemeMode(AppThemeMode.light);
      await repository.setThemeMode(AppThemeMode.dark);
      expect(await repository.watchThemeMode().first, AppThemeMode.dark);
      final rows = await db.select(db.appSettings).get();
      expect(rows.where((r) => r.key == themeModeKey).length, 1);
    });

    test('the three settings do not share a key', () async {
      // `app_settings` held one setting when it was written and holds three
      // now. Storing one must not read back as another.
      await repository.setThemeMode(AppThemeMode.dark);
      await repository.setLanguage(AppLanguage.es);
      await repository.setDateFormat(DateFormatSetting.isoDate);
      expect(await repository.watchThemeMode().first, AppThemeMode.dark);
      expect(await repository.watchLanguage().first, AppLanguage.es);
      expect(await repository.watchDateFormat().first, DateFormatSetting.isoDate);
    });
  });

  group('the wiring, which is what was missing', () {
    // Provider overrides rather than the database, for the reason
    // `language_test.dart` sets out at length: a live drift subscription
    // inside the widget tree does not come apart cleanly at `db.close()`.

    /// Mounts the Settings screen inside a `MaterialApp` wired the way
    /// `FlowMapApp` wires it, with [mode] already chosen.
    ///
    /// **This copies `app.dart`'s two lines rather than mounting `FlowMapApp`,
    /// and that is the same real gap the language helper names**: delete
    /// `themeMode:` from `app.dart` and every test below still passes. That
    /// `app.dart` is the thing handing it over is checked by driving.
    Future<void> pump(WidgetTester tester, AppThemeMode mode) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeModeSettingProvider.overrideWith((ref) => Stream.value(mode)),
            languageSettingProvider.overrideWith(
              (ref) => Stream.value(AppLanguage.system),
            ),
            dateFormatSettingProvider.overrideWith(
              (ref) => Stream.value(DateFormatSetting.locale),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(brightness: Brightness.light),
              darkTheme: ThemeData(brightness: Brightness.dark),
              themeMode: ref
                  .watch(themeModeSettingProvider)
                  .maybeWhen(
                    data: (m) => m.themeMode,
                    orElse: () => ThemeMode.system,
                  ),
              home: const SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The brightness the tree was actually built in — the question every test
    /// in this group is really asking.
    Brightness brightnessOf(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

    testWidgets('choosing light draws the tree light', (tester) async {
      await pump(tester, AppThemeMode.light);
      expect(brightnessOf(tester), Brightness.light);
    });

    testWidgets('choosing dark draws the tree dark', (tester) async {
      // The one that could not be checked without changing Windows.
      await pump(tester, AppThemeMode.dark);
      expect(brightnessOf(tester), Brightness.dark);
    });

    testWidgets('following the platform is what it always did', (tester) async {
      // The test platform reports light, and `ThemeMode.system` resolves
      // against it exactly as the app did before there was a setting.
      await pump(tester, AppThemeMode.system);
      expect(brightnessOf(tester), Brightness.light);
    });

    testWidgets('every mode is offered, and the current one shows closed', (
      tester,
    ) async {
      await pump(tester, AppThemeMode.dark);

      expect(find.text('Appearance'), findsOneWidget);
      // Closed, the picker shows the current choice.
      expect(find.text('Dark'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<AppThemeMode>));
      await tester.pumpAndSettle();

      expect(find.text('Follow the system'), findsWidgets);
      expect(find.text('Light'), findsWidgets);
      expect(find.text('Dark'), findsWidgets);
    });
  });
}
