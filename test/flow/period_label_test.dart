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
    testWidgets('a month is numeric in the heading and spelled in the hover', (
      tester,
    ) async {
      // The field asked for `08/26`. `Aug 2026` spells out the part a grid of
      // twelve makes obvious from position, and the year is what tells them
      // apart.
      final august = await labels(tester, DateTime(2026, 8), PeriodGranularity.month);

      expect(august.short, '08/26');
      expect(august.long, 'Aug 2026');
    });

    testWidgets('a leading zero is kept, so the columns line up', (
      tester,
    ) async {
      final january = await labels(
        tester,
        DateTime(2026),
        PeriodGranularity.month,
      );

      expect(january.short, '01/26');
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

    testWidgets('the numeric month needs no translating', (tester) async {
      // `MMM` is `ago` in both Spanish and Portuguese for August, and the
      // abbreviations collide differently in each. A number does not.
      for (final locale in const [Locale('en'), Locale('es'), Locale('pt')]) {
        final august = await labels(
          tester,
          DateTime(2026, 8),
          PeriodGranularity.month,
          locale: locale,
        );
        expect(august.short, '08/26', reason: locale.languageCode);
      }
    });
  });
}
