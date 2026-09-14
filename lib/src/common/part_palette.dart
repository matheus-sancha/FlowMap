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
/// **Adjacent-pairs was the wrong test, and it hid two collapses.** The set
/// before this one was solved for *adjacent* separation, on the argument that
/// identity is never colour-alone here. But the Gantt interleaves orders of many
/// parts as thin bars and the per-part table lists them together, so any two
/// parts can be compared: **all-pairs** is the honest requirement. Measured that
/// way the previous eight scored **ΔE 0.5** (olive against green) under
/// simulated colour blindness and **8.0** under ordinary vision, against floors
/// of 8 and 15 — and it failed at *three* parts, not eight, its first collapse
/// being ΔE 4.4 among violet, green and magenta.
///
/// **Eight all-pairs hues do exist, which the previous search concluded they did
/// not** (#12; it recorded a best of ΔE 6.9 / 14.2 as infeasible). Searched
/// against `dataviz`'s validator as the oracle over a 13,646-colour pool under
/// this file's own constraints — one set for both themes, so OKLCH L inside the
/// *dark* band 0.48–0.67, chroma ≥ 0.10, and ≥ 3:1 against all four real
/// surfaces (`#f7f9ff`, `#f1f3f9`, `#101418`, `#181c20`) — these eight score
/// **ΔE 8.7** under simulated colour blindness and **16.6** under ordinary
/// vision. All checks pass in both modes.
///
/// **It did not need garish colours.** The feasibility edge is chroma ≈ 0.17: at
/// C ≤ 0.18 the best eight reach 8.7 / 16.6, at C ≤ 0.16 they fall to 7.8 / 14.5
/// and fail. These top out at C 0.179, barely above the previous olive's 0.140.
/// Headroom over the floors is 0.7 and 1.6, so **a hue changed here is
/// re-validated, never eyeballed** — that is what `part_palette_test` is for.
///
/// _Rejected: eight at higher chroma._ Letting C run to 0.25 buys 9.0 / 16.8,
/// which is 0.3 ΔE for a visibly louder chart beside a blueprint-blue app.
///
/// _Rejected: six parts and wrap at seven._ More separation, but it gives up
/// headroom now shown to be available and wraps on almost every real run anyway.
///
/// _Rejected: texture as a second channel._ Legitimate where hues run out, and
/// `dataviz` keeps it for exactly that — but the target is met without it, and
/// the Gantt's bars are frequently 2–6 px, where `gantt_layout`'s own floor
/// lives and a hatch reads as noise or as a lighter fill.
///
/// _Rejected: separate light and dark sets._ More headroom per theme, at the
/// cost of sixteen values to keep in step and a colour that means one thing in a
/// screenshot and another on screen. Unnecessary now that one set clears both.
///
/// _Rejected: rotating hue off the seed colour._ It never runs out and stays in
/// the app's family — but adjacent hues stop being distinguishable past six or
/// seven parts, and adding a part would recolour a run that has not changed.
///
/// ## Past eight, colour is a hint and not an identity
///
/// **Said plainly, because the numbers are not close.** 104 of the 146 stored
/// runs with steps have more than eight parts, and 76 of them have **28** — so
/// wrapping is the ordinary case, not the edge, and each hue is reused three or
/// four times on a majority of runs. On a real 28-part run the parts are also
/// evenly spread: the top eight carry only 46 % of the bars.
///
/// So on a large run a colour groups bars loosely; it does not name a part.
/// **The part number on the bar, the legend and the hover card are what name
/// it**, and they always have. That is a limit of eight colours rather than of
/// these eight — no palette fixes it.
///
/// _Rejected: folding the ninth part onward into one neutral "Other"_, which is
/// `dataviz`'s documented answer for a ninth series. It greys 54 % of a 28-part
/// Gantt, so the fold hides the majority rather than a tail.
///
/// _Rejected: colouring the bar by production line instead._ Every stored run
/// has exactly three studies, so it is trivially separable and matches the axis
/// the filter bar narrows by — but it takes part colour off the Gantt entirely,
/// which is a bigger change than the complaint asked for.
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
/// **The order is no longer the guarantee.** Under all-pairs every ordering
/// measures the same set of pairs, so the sequence cannot make the palette safe
/// or unsafe — which retires the 40,320-ordering search the previous set needed
/// and makes this list free to re-order for any other reason.
///
/// What it buys instead is *headroom on small runs*. Every prefix of a passing
/// all-pairs set also passes, so the order only decides how far above the floor
/// a two- or three-part run sits. Enumerated over all 40,320 orderings, this one
/// is joint-best at **ΔE 29.9 / 16.8 / 12.0** for the first two, three and four
/// slots — and putting the app's own blue in slot 1 costs exactly nothing, so a
/// single-part run reads in the family colour.
const partPalette = <PartColour>[
  PartColour(Color(0xFF1464C8), _white), // blue
  PartColour(Color(0xFF919100), _black), // olive
  PartColour(Color(0xFF009BAF), _black), // teal
  PartColour(Color(0xFF007846), _white), // green
  PartColour(Color(0xFF9178F0), _black), // periwinkle
  PartColour(Color(0xFFE65A8C), _black), // pink
  PartColour(Color(0xFF8C5587), _white), // plum
  PartColour(Color(0xFFBE3705), _white), // rust
];

/// The colour for the part at [index] of the run's sorted part list.
///
/// Wraps rather than running out or throwing: a run with nine parts is a run to
/// colour, not an error. Negative indices are folded too, so a caller that hands
/// over an `indexWhere` miss gets a colour instead of a crash.
PartColour partColour(int index) =>
    partPalette[index.remainder(partPalette.length).abs()];
