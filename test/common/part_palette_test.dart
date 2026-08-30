import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flowmap/src/app/theme.dart';
import 'package:flowmap/src/common/part_palette.dart';
import 'package:flutter_test/flutter_test.dart';

/// The palette is legible against both themes *and* separable from itself,
/// asserted rather than intended (DESIGN.md §8.6).
///
/// `app.dart` sets no `themeMode`, so the app follows the system and both
/// surfaces are real. A hue that reads well on paper-white can disappear on the
/// dark surface, and nothing about writing the hex down catches it.
///
/// **The separation half of this file is a repair.** It used to measure hue
/// angle in HSL and require 35°, and it passed the shipped palette while gold
/// and lime sat ΔE 1.6 apart to a deuteranope — indistinguishable. Hue angle is
/// not a perceptual distance, so the test agreed with a premise that was wrong.
/// It now measures OKLab ΔE under simulated colour vision, which is the property
/// the palette actually needs, and the numbers match `dataviz`'s validator.
void main() {
  // ── colour maths ─────────────────────────────────────────────────────────
  // Kept here rather than in `lib/`: this is measurement apparatus for the test,
  // and nothing the app renders needs it.

  /// sRGB channel to linear light.
  double toLinear(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  List<double> linear(Color c) => [
    toLinear((c.r * 255.0).roundToDouble() / 255.0),
    toLinear((c.g * 255.0).roundToDouble() / 255.0),
    toLinear((c.b * 255.0).roundToDouble() / 255.0),
  ];

  /// WCAG relative contrast. `computeLuminance` is the WCAG luminance, so this
  /// is the whole formula.
  double contrast(Color a, Color b) {
    final x = a.computeLuminance();
    final y = b.computeLuminance();
    final lighter = x > y ? x : y;
    final darker = x > y ? y : x;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Linear-light RGB to OKLab. Perceptually uniform, so Euclidean distance in
  /// it is a distance a reader would agree with — which HSL hue angle is not.
  List<double> oklab(List<double> rgb) {
    final l = math.pow(
      0.4122214708 * rgb[0] + 0.5363325363 * rgb[1] + 0.0514459929 * rgb[2],
      1 / 3,
    ).toDouble();
    final m = math.pow(
      0.2119034982 * rgb[0] + 0.6806995451 * rgb[1] + 0.1073969566 * rgb[2],
      1 / 3,
    ).toDouble();
    final s = math.pow(
      0.0883024619 * rgb[0] + 0.2817188376 * rgb[1] + 0.6299787005 * rgb[2],
      1 / 3,
    ).toDouble();
    return [
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    ];
  }

  /// Machado et al.'s severity-1.0 dichromacy matrices, applied in linear light.
  /// The same ones `dataviz/scripts/validate_palette.js` uses, so a figure here
  /// can be checked against the validator directly.
  const cvd = <String, List<List<double>>>{
    'protan': [
      [0.152286, 1.052583, -0.204868],
      [0.114503, 0.786281, 0.099216],
      [-0.003882, -0.048116, 1.051998],
    ],
    'deutan': [
      [0.367322, 0.860646, -0.227968],
      [0.280085, 0.672501, 0.047413],
      [-0.011820, 0.042940, 0.968881],
    ],
  };

  List<double> simulate(List<double> rgb, String? kind) {
    if (kind == null) return rgb;
    final m = cvd[kind]!;
    return [
      for (final row in m)
        math.max(
          0.0,
          math.min(1.0, row[0] * rgb[0] + row[1] * rgb[1] + row[2] * rgb[2]),
        ),
    ];
  }

  /// Euclidean distance in OKLab, ×100. A null [kind] is unsimulated vision.
  double deltaE(Color a, Color b, [String? kind]) {
    final x = oklab(simulate(linear(a), kind));
    final y = oklab(simulate(linear(b), kind));
    return 100 *
        math.sqrt(
          math.pow(x[0] - y[0], 2) +
              math.pow(x[1] - y[1], 2) +
              math.pow(x[2] - y[2], 2),
        );
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
    // A bar wide enough to carry its part number has to be readable. The eight
    // no longer sit at one luminance, so four say white and four say black —
    // which is why `onFill` is stated per entry rather than assumed.
    for (var i = 0; i < partPalette.length; i++) {
      expect(
        contrast(partPalette[i].fill, partPalette[i].onFill),
        greaterThanOrEqualTo(4.5),
        reason: 'partPalette[$i] label',
      );
    }
  });

  test('neighbouring hues stay apart under colour-blind vision', () {
    // **The test that had to be rewritten.** Its predecessor required 35° of HSL
    // hue angle and passed a palette whose gold and lime were ΔE 1.6 apart to a
    // deuteranope. Hue angle is not a perceptual distance; OKLab ΔE is.
    //
    // Adjacent pairs rather than all pairs, which is the floor this palette is
    // built to and is legal only because identity is never carried by colour
    // alone here — the bar label, the legend and the hover card each name the
    // part. Assignment order is therefore load-bearing: re-ordering
    // `partPalette` moves which pairs this measures.
    for (var i = 0; i < partPalette.length - 1; i++) {
      final a = partPalette[i].fill;
      final b = partPalette[i + 1].fill;
      for (final kind in cvd.keys) {
        expect(
          deltaE(a, b, kind),
          greaterThanOrEqualTo(8.0),
          reason: 'partPalette[$i] and partPalette[${i + 1}] under $kind',
        );
      }
    }
  });

  test('neighbouring hues stay apart under ordinary vision too', () {
    // The colour-blind floor protects dichromat readers; this protects everyone
    // else. A pair can clear the simulated gate and still be two shades of the
    // same colour to someone with full colour vision — which is what ΔE 8.7
    // between the old gold and lime was.
    for (var i = 0; i < partPalette.length - 1; i++) {
      expect(
        deltaE(partPalette[i].fill, partPalette[i + 1].fill),
        greaterThanOrEqualTo(15.0),
        reason: 'partPalette[$i] and partPalette[${i + 1}] under normal vision',
      );
    }
  });

  test('no fill is so grey that its hue stops meaning anything', () {
    // The other half of the same argument: a palette of near-greys can satisfy a
    // distance floor along the lightness axis alone and still read as one
    // colour. Measured as OKLab chroma, against `dataviz`'s 0.10 floor.
    for (var i = 0; i < partPalette.length; i++) {
      final lab = oklab(linear(partPalette[i].fill));
      final chroma = math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]);
      expect(
        chroma,
        greaterThan(0.10),
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
