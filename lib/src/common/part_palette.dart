/// The app's categorical palette: one colour per part (DESIGN.md §8.6).
///
/// **Fixed, and the same in both themes.** A part is assigned a colour by its
/// position in the run's sorted part list, so the same run always colours the
/// same way and a screenshot taken in light mode names the colours a reader sees
/// in dark. Past eight it wraps; two parts then share a hue, and the bar label,
/// the legend and the hover card still say which is which.
///
/// ## Why these eight and not the first eight (v2.0)
///
/// The first set solved all eight to a *single* luminance (≈0.165) and spread
/// them ≥ 35° apart around the wheel. Both rules were held, and the palette
/// still shipped two colours nobody could tell apart: gold and lime, 45° apart
/// by hue angle, were **ΔE 1.6** to a deuteranope and **ΔE 8.7** to everyone
/// else — against floors of 8 and 15. Hue angle at a fixed luminance is simply
/// not a perceptual distance, which is the whole lesson: `part_palette_test`
/// asserted contrast *against surfaces* and hue separation *in HSL*, agreed with
/// both, and had nothing to say about the defect. It now measures the property
/// that actually matters (see the test's `deltaE`).
///
/// **Eight hues mutually separated at one luminance is infeasible, not
/// unlucky.** Searched against `dataviz`'s validator as the oracle over 200
/// restarts per configuration, under this file's own constraints, the best
/// all-pairs eight reaches ΔE 6.9 / 14.2 — under both floors of 8 and 15. Three
/// ways out were priced: six parts all-pairs (9.4 / 17.0), eight parts in two
/// per-theme sets (9.3 / 17.6), or eight with **adjacent-pair** separation,
/// which clears both floors several times over.
///
/// These eight are the third, re-searched against the app's *real* surfaces
/// rather than the validator's generic ones — `#f1f3f9` and `#181c20`, the
/// tighter of each theme's page/card pair — because the first candidate set
/// missed 3:1 on the light card by 0.005. They score **ΔE 20.7** under simulated
/// colour blindness and **36.3** under ordinary vision.
///
/// Adjacent-pairs is the validator's documented mode for stacks, bars and lines,
/// and it is legal only where identity is never carried by colour alone — which
/// is already true here, in this file's own words above: the bar label, the
/// legend and the hover card all name the part.
///
/// **The single-luminance rule is what had to go**, not the one-set rule. The
/// eight now span a band rather than sitting on a point, which is where the
/// separation came from; [PartColour.onFill] already recorded the readable ink
/// per entry precisely because a hue that moves may not keep white, and four of
/// the eight now take black.
///
/// _Rejected: rotating hue off the seed colour._ It never runs out and stays in
/// the app's family — but adjacent hues stop being distinguishable past six or
/// seven parts, and adding a part would recolour a run that has not changed.
///
/// _Rejected: separate light and dark sets._ More headroom per theme, at the
/// cost of sixteen values to keep in step and a colour that means one thing in a
/// screenshot and another on screen.
library;

import 'dart:ui' show Color;

/// One part's colour, and what can be written on it.
class PartColour {
  const PartColour(this.fill, this.onFill);

  /// The bar, and the legend swatch.
  final Color fill;

  /// Black or white, whichever is legible on [fill] — for the part number drawn
  /// on a bar wide enough to hold it.
  final Color onFill;
}

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

/// The eight, in assignment order.
///
/// **The order is the guarantee, not a preference.** The adjacent-pair floor is
/// measured along *this* sequence, so re-ordering these entries invalidates it;
/// the test measures the order as written. This sequence is the best of all
/// 40,320 orderings of these eight, at ΔE 20.7 (colour-blind) and 36.3 (normal).
///
/// **The old ordering rule was itself the trap.** v1.0 ordered them "so that a
/// run with two or three parts — the common case — gets the hues furthest
/// apart: blue, then orange-red, then green." Forcing that head onto these eight
/// scores **ΔE 3.6**, because red beside green is the single worst adjacent pair
/// for the commonest form of colour blindness. The rule optimised the common
/// case into the one arrangement a deuteranope cannot read at all.
const partPalette = <PartColour>[
  PartColour(Color(0xFF9B4FD3), _white), // violet
  PartColour(Color(0xFF3B9B20), _black), // green
  PartColour(Color(0xFFE046D1), _black), // magenta
  PartColour(Color(0xFF869310), _black), // olive
  PartColour(Color(0xFF6F57F1), _white), // indigo
  PartColour(Color(0xFFF52121), _black), // red
  PartColour(Color(0xFF0766EE), _white), // blue
  PartColour(Color(0xFFC67C0C), _black), // ochre
];

/// The colour for the part at [index] of the run's sorted part list.
///
/// Wraps rather than running out or throwing: a run with nine parts is a run to
/// colour, not an error. Negative indices are folded too, so a caller that hands
/// over an `indexWhere` miss gets a colour instead of a crash.
PartColour partColour(int index) =>
    partPalette[index.remainder(partPalette.length).abs()];
