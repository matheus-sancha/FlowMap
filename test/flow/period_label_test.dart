import 'package:flowmap/src/common/period_granularity.dart';
import 'package:flowmap/src/features/flow/presentation/period_label.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// How a span is written, in the two places it is written differently.
void main() {
  /// Renders both labels for [anchor] so a test can read them back.
  Future<({String long, String short})> labels(
    WidgetTester tester,
    DateTime anchor,
    PeriodGranularity granularity, {
    Locale locale = const Locale('en'),
  }) async {
    late String long;
    late String short;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            long = periodLabel(context, anchor, granularity);
            short = periodColumnLabel(context, anchor, granularity);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return (long: long, short: short);
  }

  test('nothing here needs a running app', () {
    // A guard on the group below, which does: these are functions of a context
    // only because the locale is.
    expect(PeriodGranularity.values, hasLength(4));
  });

  group('a column heading is shorter than a caption', () {
    testWidgets('a month drops its century in the heading, not its name', (
      tester,
    ) async {
      // `Aug/26` — the same form the float matrix has always used, so the two
      // period matrices in the app write a month the same way.
      final august = await labels(
        tester,
        DateTime(2026, 8),
        PeriodGranularity.month,
      );

      expect(august.short, 'Aug/26');
      expect(august.long, 'Aug 2026');
    });

    testWidgets('the coarser grains are already as short as they go', (
      tester,
    ) async {
      // Nothing to shorten, and shortening `Q4 2026` is what produced
      // `Q4 2...` in the first place.
      for (final grain in const [
        PeriodGranularity.quarter,
        PeriodGranularity.semester,
        PeriodGranularity.year,
      ]) {
        final both = await labels(tester, DateTime(2026, 10), grain);
        expect(both.short, both.long, reason: grain.name);
      }
    });

    testWidgets('the month is written in the reader’s own language', (
      tester,
    ) async {
      // The float matrix's default did *not* do this until the two were
      // matched: it read `Intl`'s ambient locale rather than the app's, so it
      // wrote English months in a Portuguese app.
      const expected = {'en': 'Aug/26', 'es': 'ago/26', 'pt': 'ago./26'};
      for (final entry in expected.entries) {
        final august = await labels(
          tester,
          DateTime(2026, 8),
          PeriodGranularity.month,
          locale: Locale(entry.key),
        );
        expect(august.short, entry.value, reason: entry.key);
      }
    });

    testWidgets('and the widest of the three is not the English one', (
      tester,
    ) async {
      // Which is why the column is 80 rather than the 72 the cells wanted:
      // Spanish September is four letters and Portuguese carries a point.
      final widest = <String>[];
      for (final code in const ['en', 'es', 'pt']) {
        final september = await labels(
          tester,
          DateTime(2026, 9),
          PeriodGranularity.month,
          locale: Locale(code),
        );
        widest.add(september.short);
      }

      expect(widest, ['Sep/26', 'sept/26', 'set./26']);
      expect(
        widest.map((s) => s.length).reduce((a, b) => a > b ? a : b),
        greaterThan('Sep/26'.length),
        reason: 'English is not the one to size the column against',
      );
    });
  });
}
