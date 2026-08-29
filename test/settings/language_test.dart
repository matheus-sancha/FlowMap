// `package:drift/drift.dart` is deliberately not imported: it exports `isNull`
// and `isNotNull` as column expressions, which collide with the matchers of the
// same name.
import 'package:drift/native.dart';
import 'package:flowmap/src/common/app_language.dart';
import 'package:flowmap/src/common/date_input.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/settings/application/settings_providers.dart';
import 'package:flowmap/src/features/settings/data/settings_repository.dart';
import 'package:flowmap/src/features/settings/presentation/settings_screen.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The language picker (§8.7).
///
/// **The translations were never the missing piece.** es and pt shipped
/// complete and were unreachable, because `MaterialApp` was given
/// `supportedLocales` and no `locale:` — so what these pin is the wiring, from
/// a stored choice to the strings the tree is actually built from.
void main() {
  late AppDatabase db;
  late SettingsRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = SettingsRepository(db);
  });

  tearDown(() => db.close());

  group('AppLanguage', () {
    test('nothing stored means follow the platform', () {
      expect(AppLanguage.fromStored(null), AppLanguage.system);
      expect(AppLanguage.system.locale, isNull);
    });

    test('an unknown value falls back rather than throwing', () {
      // What an install downgraded from a build that knew more languages reads
      // back. Falling back to the platform is the one answer that cannot be
      // wrong for a reader whose language this build does not have.
      expect(AppLanguage.fromStored('kl'), AppLanguage.system);
    });

    test('a chosen language is a locale MaterialApp can resolve', () {
      expect(AppLanguage.es.locale, const Locale('es'));
      expect(AppLanguage.pt.locale, const Locale('pt'));
      expect(AppLanguage.en.locale, const Locale('en'));
    });

    test('every value round-trips through storage by name', () {
      for (final language in AppLanguage.values) {
        expect(AppLanguage.fromStored(language.name), language);
      }
    });
  });

  group('the repository', () {
    test('a fresh database follows the platform', () async {
      expect(await repository.watchLanguage().first, AppLanguage.system);
    });

    test('a choice is stored and streamed back', () async {
      await repository.setLanguage(AppLanguage.pt);
      expect(await repository.watchLanguage().first, AppLanguage.pt);
    });

    test('choosing again replaces rather than adding a row', () async {
      await repository.setLanguage(AppLanguage.pt);
      await repository.setLanguage(AppLanguage.es);
      expect(await repository.watchLanguage().first, AppLanguage.es);
      final rows = await db.select(db.appSettings).get();
      expect(rows.where((r) => r.key == languageKey).length, 1);
    });

    test('the language and the date format do not share a key', () async {
      // Both live in `app_settings`, which held one setting when it was
      // written. Storing one must not read back as the other.
      await repository.setLanguage(AppLanguage.es);
      expect(await repository.watchDateFormat().first, isNotNull);
      expect(await repository.watchLanguage().first, AppLanguage.es);
    });
  });

  group('the wiring, which is what was missing', () {
    // **Provider overrides rather than the database**, which is what
    // `simulation_tab_test.dart` does and for a reason worth stating: a live
    // drift subscription inside the widget tree does not come apart cleanly
    // when the test ends, and `tearDown`'s `db.close()` waits for a stream the
    // tree has not let go of. Every widget test after the first then reports
    // only that it "did not complete", which says nothing about the code.
    //
    // So the seam is tested from both sides instead. The group above proves a
    // choice is stored and streamed back; this one proves a streamed choice
    // reaches `MaterialApp` and moves every string in the tree. What joins
    // them is `languageSettingProvider`, which is the one line neither covers
    // and which has nothing in it.

    /// Mounts the Settings screen inside a `MaterialApp` wired exactly the way
    /// `FlowMapApp` wires it, with [language] already chosen.
    ///
    /// **This helper copies those two lines rather than mounting `FlowMapApp`,
    /// and that is a real gap**: delete `locale:` from `app.dart` and every
    /// test below still passes. Mounting the app itself needs the router, and
    /// the router needs the database — which is the arrangement this group
    /// exists to avoid. So what is proved here is that a locale reaching
    /// `MaterialApp` moves the strings; that `app.dart` is the thing handing
    /// it over is checked by driving, in §8.8.
    Future<void> pump(WidgetTester tester, AppLanguage language) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languageSettingProvider.overrideWith(
              (ref) => Stream.value(language),
            ),
            dateFormatSettingProvider.overrideWith(
              (ref) => Stream.value(DateFormatSetting.locale),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: ref
                  .watch(languageSettingProvider)
                  .maybeWhen(data: (l) => l.locale, orElse: () => null),
              home: const SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a stored language is what the app is drawn in', (
      tester,
    ) async {
      await pump(tester, AppLanguage.pt);

      // The screen's own title, in Portuguese. If the locale were not reaching
      // `MaterialApp` this would still read `Settings` — which is exactly what
      // the app did before §8.7, with pt sitting translated and unreachable.
      expect(find.text('Configurações'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('the whole tree moves, not just the control', (tester) async {
      await pump(tester, AppLanguage.es);

      // Three strings from three parts of the screen: the app bar, this card's
      // heading, and the other card's. A locale that reached only the widget
      // reading the setting would show one of them.
      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Idioma'), findsOneWidget);
      expect(find.text('Formato de fecha'), findsOneWidget);
    });

    testWidgets('following the platform is what it always did', (tester) async {
      await pump(tester, AppLanguage.system);

      // The test platform is en and `AppLanguage.system.locale` is null, so
      // `MaterialApp` resolves it exactly as it did before there was a setting.
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
    });

    testWidgets('every language is offered, and each names itself', (
      tester,
    ) async {
      await pump(tester, AppLanguage.pt);

      // Closed, the picker shows the current choice by its own name.
      expect(find.text('Português'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<AppLanguage>));
      await tester.pumpAndSettle();

      // **A language names itself in every list**, whatever the app is drawn
      // in — because the reader who needs this control is the one who cannot
      // read what is currently on screen. These read the same here, under pt,
      // as they would under en.
      expect(find.text('English'), findsWidgets);
      expect(find.text('Español'), findsWidgets);
      expect(find.text('Português'), findsWidgets);

      // The platform option is a sentence rather than a name, so it *is*
      // translated, and under pt it reads in Portuguese.
      expect(find.text('Seguir o sistema'), findsWidgets);
    });
  });
}
