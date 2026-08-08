import 'package:flutter/material.dart';

import 'package:flowmap/src/app/theme.dart';
import 'package:flowmap/src/common/part_palette.dart';
import 'package:flutter_test/flutter_test.dart';

/// The palette is legible against both themes, asserted rather than intended
/// (DESIGN.md §8.6).
///
/// `app.dart` sets no `themeMode`, so the app follows the system and both
/// surfaces are real. A hue that reads well on paper-white can disappear on the
/// dark surface, and nothing about writing the hex down catches it — so this
/// does, against the four surfaces the fills actually sit on: the page and the
/// card, in each brightness.
void main() {
  /// WCAG relative contrast. `computeLuminance` is the WCAG luminance, so this
  /// is the whole formula.
  double contrast(Color a, Color b) {
    final x = a.computeLuminance();
    final y = b.computeLuminance();
    final lighter = x > y ? x : y;
    final darker = x > y ? y : x;
    return (lighter + 0.05) / (darker + 0.05);
  }

  final light = FlowMapTheme.light().colorScheme;
  final dark = FlowMapTheme.dark().colorScheme;

  /// What a fill is seen against: the page, and the card the tables sit in.
  final surfaces = <String, Color>{
    'light surface': light.surface,
    'light card': light.surfaceContainerLow,
    'dark surface': dark.surface,
    'dark card': dark.surfaceContainerLow,
  };

  test('every hue clears 3:1 against both themes', () {
    for (var i = 0; i < partPalette.length; i++) {
      for (final surface in surfaces.entries) {
        expect(
          contrast(partPalette[i].fill, surface.value),
          greaterThanOrEqualTo(3.0),
          reason: 'partPalette[$i] against ${surface.key}',
        );
      }
    }
  });

  test('every label clears 4.5:1 against its own fill', () {
    // A bar wide enough to carry its part number has to be readable. At this
    // luminance white clears it on all eight and black on none, so all eight
    // say white — stated per entry rather than assumed, because a hue that
    // moves may not, and this is what would catch that.
    for (var i = 0; i < partPalette.length; i++) {
      expect(
        contrast(partPalette[i].fill, partPalette[i].onFill),
        greaterThanOrEqualTo(4.5),
        reason: 'partPalette[$i] label',
      );
    }
  });

  test('the hues sit at least 35° apart', () {
    // Not a WCAG rule — a categorical palette's own requirement. Two hues a
    // reader cannot tell apart are one colour with two meanings, which is the
    // failure that made hue rotation off the seed unusable past six parts.
    //
    // Measured as hue angle rather than as distance between the two RGB
    // triples, and that is the point of the test rather than an implementation
    // detail: every fill is at the same luminance by construction, so RGB
    // distance mostly measures the lightness difference that is not there. It
    // passed a first draft whose brown and olive were, perceptually, vermillion
    // and gold again.
    for (var i = 0; i < partPalette.length; i++) {
      for (var j = i + 1; j < partPalette.length; j++) {
        final a = HSLColor.fromColor(partPalette[i].fill).hue;
        final b = HSLColor.fromColor(partPalette[j].fill).hue;
        final raw = (a - b).abs();
        final separation = raw > 180 ? 360 - raw : raw;
        expect(
          separation,
          greaterThanOrEqualTo(35.0),
          reason:
              'partPalette[$i] (${a.round()}°) and '
              'partPalette[$j] (${b.round()}°) are too close',
        );
      }
    }
  });

  test('no fill is so grey that its hue stops meaning anything', () {
    // The other half of the same argument. A 35° gap between two near-greys is
    // not a gap anyone can see, so the spacing above only holds while every
    // entry is actually chromatic.
    for (var i = 0; i < partPalette.length; i++) {
      expect(
        HSLColor.fromColor(partPalette[i].fill).saturation,
        greaterThan(0.35),
        reason: 'partPalette[$i] is too desaturated to be told apart by hue',
      );
    }
  });

  group('assignment', () {
    test('is by position, so one run always colours the same way', () {
      expect(partColour(0).fill, partPalette[0].fill);
      expect(partColour(7).fill, partPalette[7].fill);
    });

    test('wraps past eight rather than running out', () {
      // A ninth part is a run to colour, not an error. The legend and the hover
      // card are what separate the two parts sharing the hue.
      expect(partColour(8).fill, partPalette[0].fill);
      expect(partColour(11).fill, partPalette[3].fill);
    });

    test('folds a negative index rather than throwing', () {
      // A caller handing over an `indexWhere` miss gets a colour, not a crash.
      expect(partColour(-1).fill, partPalette[1].fill);
    });
  });
}
