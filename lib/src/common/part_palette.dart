/// The app's categorical palette: one colour per part (DESIGN.md §8.6).
///
/// **Fixed, and the same in both themes.** A part is assigned a colour by its
/// position in the run's sorted part list, so the same run always colours the
/// same way and a screenshot taken in light mode names the colours a reader
/// sees in dark. Past eight it wraps; two parts then share a hue, and the bar
/// label, the legend and the hover card still say which is which.
///
/// **All eight sit at one luminance**, and that is the whole constraint rather
/// than a matter of taste. `app.dart` sets no `themeMode`, so the app follows
/// the system and both surfaces are real: light is near-white, dark is
/// near-black, and a hue clears 3:1 against *both* only inside a narrow band —
/// roughly 0.13 to 0.28 relative luminance. Too light and it vanishes on
/// paper-white; too dark and it vanishes on the dark surface. These were solved
/// to ≈0.165, which clears every surface by at least 3.5:1 and leaves white
/// legible on all of them; `part_palette_test` asserts it against the four
/// surfaces they actually sit on, so the next person to swap a hue is told
/// immediately rather than in the field.
///
/// **That is also why they are separated by hue and not by lightness.** At one
/// luminance the only axes left are hue and chroma, so the eight are spread
/// around the wheel at ≥ 35° and none of them is a low-chroma colour. The first
/// draft used brown and olive; at a fixed luminance those are desaturated
/// oranges, and they collapsed onto vermillion and gold. The test caught it,
/// which is the argument for having one.
///
/// [PartColour.onFill] is what can be written on the fill — the part number on a
/// bar wide enough to hold it. At this luminance white clears 4.5:1 on all eight
/// and black clears none of them, so all eight say white; it is stated per entry
/// rather than assumed, because a hue that moves may not.
///
/// _Rejected: rotating hue off the seed colour._ It never runs out and stays in
/// the app's family — but adjacent hues stop being distinguishable past six or
/// seven parts, and adding a part would recolour a run that has not changed.
///
/// _Rejected: separate light and dark sets._ More headroom per theme, at the
/// cost of sixteen values to keep in step and a colour that means one thing in
/// a screenshot and another on screen.
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

/// The eight, in assignment order.
///
/// Ordered so that a run with two or three parts — the common case — gets the
/// hues furthest apart: blue, then orange-red, then green. The hue angle of
/// each is in the comment, because the spacing is the property under test and
/// a hex says nothing about it.
const partPalette = <PartColour>[
  PartColour(Color(0xFF476AD4), _white), // blue, 225°
  PartColour(Color(0xFFBC502C), _white), // vermillion, 15°
  PartColour(Color(0xFF1E823F), _white), // green, 140°
  PartColour(Color(0xFFA342D3), _white), // purple, 280°
  PartColour(Color(0xFF1F7D85), _white), // teal, 185°
  PartColour(Color(0xFFCD307E), _white), // magenta, 330°
  PartColour(Color(0xFF81711E), _white), // gold, 50°
  PartColour(Color(0xFF467F1E), _white), // lime, 95°
];

/// The colour for the part at [index] of the run's sorted part list.
///
/// Wraps rather than running out or throwing: a run with nine parts is a run to
/// colour, not an error. Negative indices are folded too, so a caller that
/// hands over an `indexWhere` miss gets a colour instead of a crash.
PartColour partColour(int index) =>
    partPalette[index.remainder(partPalette.length).abs()];
