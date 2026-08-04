import 'package:flowmap/src/common/workcenter_icons.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/data/database/seed_data.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The icon library behind a workcenter type (DESIGN.md §12.1).
void main() {
  test('every icon has a glyph, and they are all distinct', () {
    final glyphs = {
      for (final icon in WorkcenterIcon.values) icon: workcenterIconGlyph(icon),
    };

    expect(glyphs, hasLength(WorkcenterIcon.values.length));
    // Two library entries drawn identically are one entry with two names, and
    // a picker showing the same glyph twice reads as a bug.
    expect(
      glyphs.values.toSet(),
      hasLength(WorkcenterIcon.values.length),
      reason: 'each library entry needs its own glyph',
    );
  });

  test('the glyphs are const, so tree-shaking keeps them', () {
    // A codepoint read out of the database would build an IconData the
    // compiler never sees, which renders as a blank box in release and
    // correctly in debug. Every glyph here comes from a const `Icons.*`.
    for (final icon in WorkcenterIcon.values) {
      final glyph = workcenterIconGlyph(icon);
      expect(glyph.fontFamily, 'MaterialIcons');
    }
  });

  testWidgets('every icon has a name in every language', (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final icon in WorkcenterIcon.values) {
        final label = workcenterIconLabel(l10n, icon);
        expect(label.trim(), isNotEmpty, reason: '${icon.name} in $locale');
      }
    }
  });

  group('guessWorkcenterIcon', () {
    test('places every seeded type', () {
      // The nine seeds are named in English, which is what the guesser reads,
      // so all of them should arrive with a glyph rather than a default.
      for (final name in workcenterTypeSeeds) {
        expect(
          guessWorkcenterIcon(name),
          isNotNull,
          reason: 'the seeded type "$name" should not arrive blank',
        );
      }
    });

    test('reads the seeds as the shop floor writes them', () {
      expect(guessWorkcenterIcon('Cladding'), WorkcenterIcon.cladding);
      expect(guessWorkcenterIcon('Welding'), WorkcenterIcon.welding);
      expect(guessWorkcenterIcon('Heat Treatment'), WorkcenterIcon.heatTreatment);
      expect(guessWorkcenterIcon('Inspection'), WorkcenterIcon.inspection);
    });

    test('matches inside a longer name, and ignores case', () {
      expect(guessWorkcenterIcon('CNC LATHE 04'), WorkcenterIcon.lathe);
      expect(guessWorkcenterIcon('Robotic welding cell'), isNotNull);
    });

    test('gives up rather than guessing wildly', () {
      // A wrong guess costs one click in the picker; a guess for a name it has
      // no business reading would be worse than the default.
      expect(guessWorkcenterIcon('Zone 4'), isNull);
      expect(guessWorkcenterIcon(''), isNull);
    });
  });
}
