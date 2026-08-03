import 'package:flowmap/src/common/unit_labels.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for the grey flow screen.
///
/// The first build of the footer read the unit through a `dynamic` receiver and
/// called `TaktUnit.name` on it. `name` is an **extension** getter, so it
/// resolves statically and is simply absent at runtime on a dynamic call — the
/// footer threw `NoSuchMethodError` the moment a takt existed, which in a
/// release build is a blank grey panel with no message.
///
/// These labels now come from exhaustive switches over the enum, which the
/// compiler checks. The test is here so the shortcut cannot come back.
void main() {
  Future<void> pumpWithLocalizations(
    WidgetTester tester,
    void Function(AppLocalizations l10n) body, {
    Locale locale = const Locale('en'),
  }) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    body(l10n);
  }

  testWidgets('every takt unit has a label and an abbreviation', (
    tester,
  ) async {
    await pumpWithLocalizations(tester, (l10n) {
      for (final unit in TaktUnit.values) {
        expect(taktUnitLabel(l10n, unit), isNotEmpty, reason: '$unit');
        expect(taktUnitShort(l10n, unit), isNotEmpty, reason: '$unit');
      }
    });
  });

  testWidgets('the labels are distinct, so a takt cannot read ambiguously', (
    tester,
  ) async {
    await pumpWithLocalizations(tester, (l10n) {
      final labels = TaktUnit.values.map((u) => taktUnitLabel(l10n, u)).toSet();
      expect(labels, hasLength(TaktUnit.values.length));
    });
  });

  testWidgets('they are translated, not the enum names', (tester) async {
    await pumpWithLocalizations(
      tester,
      (l10n) => expect(taktUnitLabel(l10n, TaktUnit.days), 'dias'),
      locale: const Locale('pt'),
    );
  });

  group('formatAdaptiveDuration', () {
    testWidgets('picks the largest unit that stays readable', (tester) async {
      await pumpWithLocalizations(tester, (l10n) {
        expect(
          formatAdaptiveDuration(l10n, const Duration(hours: 216)),
          '9.0 d',
        );
        expect(
          formatAdaptiveDuration(l10n, const Duration(hours: 5, minutes: 24)),
          '5.4 h',
        );
        expect(
          formatAdaptiveDuration(l10n, const Duration(minutes: 42)),
          '42 min',
        );
        expect(
          formatAdaptiveDuration(l10n, const Duration(seconds: 30)),
          '30 s',
        );
      });
    });

    testWidgets('the boundaries fall on the larger unit', (tester) async {
      await pumpWithLocalizations(tester, (l10n) {
        // Exactly 24 h reads as a day, exactly an hour as an hour.
        expect(
          formatAdaptiveDuration(l10n, const Duration(hours: 24)),
          '1.0 d',
        );
        expect(
          formatAdaptiveDuration(l10n, const Duration(hours: 23, minutes: 59)),
          '24.0 h',
          reason: 'still hours below the day boundary, even when it rounds up',
        );
        expect(formatAdaptiveDuration(l10n, const Duration(hours: 1)), '1.0 h');
        expect(
          formatAdaptiveDuration(l10n, const Duration(minutes: 59)),
          '59 min',
        );
        expect(
          formatAdaptiveDuration(l10n, const Duration(minutes: 1)),
          '1 min',
        );
        expect(
          formatAdaptiveDuration(l10n, const Duration(seconds: 59)),
          '59 s',
        );
      });
    });

    testWidgets('a working day makes days mean working days', (tester) async {
      await pumpWithLocalizations(tester, (l10n) {
        const workingDay = Duration(hours: 22, minutes: 40);
        // A 3-day takt at a 22:40 station is 68 h, and must read as 3 days —
        // not the 2.8 it would be against a 24-hour day nobody works.
        expect(
          formatAdaptiveDuration(
            l10n,
            const Duration(hours: 68),
            workingDay: workingDay,
          ),
          '3.0 d',
        );
        // One working day is one day, even though it is under 24 h.
        expect(
          formatAdaptiveDuration(l10n, workingDay, workingDay: workingDay),
          '1.0 d',
        );
        // Below a working day it falls back to the ordinary units.
        expect(
          formatAdaptiveDuration(
            l10n,
            const Duration(hours: 4),
            workingDay: workingDay,
          ),
          '4.0 h',
        );
      });
    });

    testWidgets('a zero working day falls back rather than dividing by it', (
      tester,
    ) async {
      await pumpWithLocalizations(tester, (l10n) {
        expect(
          formatAdaptiveDuration(
            l10n,
            const Duration(hours: 48),
            workingDay: Duration.zero,
          ),
          '2.0 d',
        );
      });
    });

    testWidgets('zero and negatives do not produce nonsense', (tester) async {
      await pumpWithLocalizations(tester, (l10n) {
        expect(formatAdaptiveDuration(l10n, Duration.zero), '0 s');
        expect(
          formatAdaptiveDuration(l10n, const Duration(hours: -3)),
          '-3.0 h',
        );
      });
    });
  });
}
