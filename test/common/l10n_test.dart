import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every user-facing string reaches all three locales (#11).
///
/// **Turning a habit into a build failure.** Both of this map's executed tickets
/// translated as they went, but that was practice rather than a rule, and the
/// navigation phase churns five tab names, a mode switch and two renamed views
/// in one batch — which is exactly where a habit lapses and nothing says so.
///
/// **It costs nothing to check, because `gen-l10n` already does it.**
/// `l10n.yaml` sets `untranslated-messages-file`, so every run writes the report
/// this reads. Nothing was asserting it.
///
/// Renders nothing, like `part_palette_test`: the property is what is asserted,
/// not the pixels.
void main() {
  test('every key reaches es and pt', () {
    final report = File('lib/src/l10n/untranslated.json');
    expect(
      report.existsSync(),
      isTrue,
      reason:
          'lib/src/l10n/untranslated.json is written by `flutter gen-l10n`. '
          'If it is missing, gen-l10n has not been run since the ARB files '
          'changed — which is the same failure this test exists to catch.',
    );

    final missing = jsonDecode(report.readAsStringSync()) as Map<String, dynamic>;

    // Named rather than counted: `{es: [occupationGap, occupationHours]}` says
    // which strings to write, where a bare count says only that there is work.
    expect(
      missing,
      isEmpty,
      reason:
          'These keys are in app_en.arb and missing from another locale. '
          'A phase lands its strings in en, es and pt together.',
    );
  });
}
