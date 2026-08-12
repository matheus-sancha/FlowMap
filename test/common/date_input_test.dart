import 'package:flowmap/src/common/date_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// How dates read and parse (DESIGN.md §12.4).
///
/// The pair matters more than either half: a display format that moved without
/// its parser would make every date field reject what it had just shown, so
/// most of what is asserted here is that the two agree.
void main() {
  // `DateFormat.yMd` throws on any locale whose data has not been loaded, and
  // only `en_US` is there by default. The app gets this from
  // `flutter_localizations`; a pure test has to ask.
  setUpAll(initializeDateFormatting);

  // 3 August 2026 — a day whose two readings are different days, which is the
  // whole reason the setting exists. A date like the 20th would pass every
  // test below under any format.
  final thirdOfAugust = DateTime(2026, 8, 3);

  group('formatting', () {
    test('each setting writes the day it says it does', () {
      String written(DateFormatSetting setting) =>
          DateStyle(locale: 'en_US', setting: setting).format(thirdOfAugust);

      expect(written(DateFormatSetting.dayMonthYear), '03/08/2026');
      expect(written(DateFormatSetting.monthDayYear), '08/03/2026');
      expect(written(DateFormatSetting.isoDate), '2026-08-03');
    });

    test('the default follows the locale, as the app did before', () {
      expect(const DateStyle(locale: 'en_US').format(thirdOfAugust), '8/3/2026');
      expect(
        const DateStyle(locale: 'pt_BR').format(thirdOfAugust),
        '03/08/2026',
      );
    });

    test('the format is independent of the language', () {
      // English UI with Brazilian dates, which is the combination a locale
      // picker cannot reach and this setting exists to allow.
      expect(
        const DateStyle(
          locale: 'en_US',
          setting: DateFormatSetting.dayMonthYear,
        ).format(thirdOfAugust),
        '03/08/2026',
      );
    });

    test('null is empty, not a placeholder', () {
      expect(const DateStyle(locale: 'en_US').format(null), '');
    });
  });

  group('parsing', () {
    test('what a setting writes, the same setting reads back', () {
      // The contract that has to hold in the same commit. Asserted over every
      // setting rather than the one being added, so a fifth cannot be landed
      // with only half of it wired.
      for (final setting in DateFormatSetting.values) {
        final style = DateStyle(locale: 'en_US', setting: setting);
        expect(
          style.parse(style.format(thirdOfAugust)),
          thirdOfAugust,
          reason: 'round trip under $setting',
        );
      }
    });

    test('ISO is accepted whatever the setting', () {
      // It is what a database export and half the spreadsheets in circulation
      // produce, and it cannot be read two ways.
      for (final setting in DateFormatSetting.values) {
        expect(
          DateStyle(locale: 'en_US', setting: setting).parse('2026-08-03'),
          thirdOfAugust,
          reason: 'ISO under $setting',
        );
      }
    });

    test('a pinned format still reads what the locale would have written', () {
      // A user who pinned dd/MM/yyyy on an en_US machine, typing the way the
      // app used to render. Nothing is lost by accepting it: it is a string
      // the app itself would have produced a moment earlier.
      const style = DateStyle(
        locale: 'en_US',
        setting: DateFormatSetting.dayMonthYear,
      );
      expect(style.parse('12/25/2026'), DateTime(2026, 12, 25));
    });

    test('the chosen format wins where the two disagree', () {
      // `03/08/2026` is a real date under both readings, so nothing but the
      // setting can decide it — which is exactly the case a planner complained
      // about.
      expect(
        const DateStyle(
          locale: 'en_US',
          setting: DateFormatSetting.dayMonthYear,
        ).parse('03/08/2026'),
        DateTime(2026, 8, 3),
      );
      expect(
        const DateStyle(
          locale: 'en_US',
          setting: DateFormatSetting.monthDayYear,
        ).parse('03/08/2026'),
        DateTime(2026, 3, 8),
      );
    });

    test('unreadable is null, not an exception', () {
      // This runs on every keystroke.
      const style = DateStyle(locale: 'en_US');
      expect(style.parse(''), isNull);
      expect(style.parse('   '), isNull);
      expect(style.parse('not a date'), isNull);
      expect(style.parse('99/99/2026'), isNull);
    });
  });

  group('the Excel pattern', () {
    test('says the same thing the screen does', () {
      String excel(DateFormatSetting setting) =>
          DateStyle(locale: 'en_US', setting: setting).excelPattern;

      expect(excel(DateFormatSetting.dayMonthYear), 'dd/mm/yyyy');
      expect(excel(DateFormatSetting.monthDayYear), 'mm/dd/yyyy');
      expect(excel(DateFormatSetting.isoDate), 'yyyy-mm-dd');
    });

    test('is derived, so it follows a locale no table here knows', () {
      // The point of deriving it: under the default there is no chosen pattern
      // to look up, and the file must still say what the screen says.
      expect(const DateStyle(locale: 'pt_BR').excelPattern, 'dd/mm/yyyy');
      expect(const DateStyle(locale: 'en_US').excelPattern, 'mm/dd/yyyy');
    });

    test('widths are padded, so a spreadsheet never shows 8/3/26', () {
      // `intl` gives en_US the pattern `M/d/y`, which reaches Excel as a
      // two-digit year unless it is widened here.
      expect(const DateStyle(locale: 'en_US').excelPattern, contains('yyyy'));
      expect(const DateStyle(locale: 'en_US').excelPattern, isNot(contains('/d/')));
    });
  });

  group('the stored value', () {
    test('reads back by name', () {
      for (final setting in DateFormatSetting.values) {
        expect(DateFormatSetting.fromStored(setting.name), setting);
      }
    });

    test('anything else is the locale default', () {
      // A value written by a later version, or a row that was never there.
      expect(DateFormatSetting.fromStored(null), DateFormatSetting.locale);
      expect(DateFormatSetting.fromStored(''), DateFormatSetting.locale);
      expect(
        DateFormatSetting.fromStored('someFutureFormat'),
        DateFormatSetting.locale,
      );
    });
  });
}
