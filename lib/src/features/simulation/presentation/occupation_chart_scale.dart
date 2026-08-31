/// The Occupation chart's vertical scale and its hours axis (#13).
///
/// **Pure, and in its own file so it can be asserted.** Nothing in the suite
/// renders a pixel, and the chart is a `CustomPainter` — but *where a tick
/// lands* and *what a tick is called* are arithmetic, and the repo's standing
/// rule is to reach for the property before reaching for a drive. What is left
/// over — whether the dotted gridlines read as gridlines rather than as the
/// capacity line — is genuinely only feel, and that is what the drive is for.
library;

import 'dart:math' as math;

import 'package:intl/intl.dart' show NumberFormat;

/// One labelled tick on the hours axis.
class HoursTick {
  const HoursTick({required this.seconds, required this.label});

  final int seconds;

  /// Already formatted for the reader's locale — a thousands separator is the
  /// locale's, and a `CustomPainter` has no `BuildContext` to ask.
  final String label;
}

/// The vertical scale the plot and its axis both read.
///
/// **Shared rather than computed twice.** The axis lives in a fixed column and
/// the plot in a horizontal scroll, so they are two `CustomPaint`s of the same
/// height; if each derived its own mapping from seconds to pixels, a rounding
/// difference would put the 8,000 h tick a pixel off the bar that is at
/// 8,000 h — and the whole point of an axis is that it can be trusted to that
/// pixel.
class ChartScale {
  const ChartScale({required this.peakSeconds, required this.ticks});

  /// Room above the tallest bar for its own `%` label.
  ///
  /// **Reserved in the scale rather than clamped at paint time.** The bar that
  /// reaches the top of the scale is by definition the one a reader is looking
  /// for, and a label clamped to the canvas edge would sit *on* it.
  static const headroom = 18.0;

  /// Room below the plot for the month labels.
  static const axis = 28.0;

  /// Wide enough for `8,000` at 10 pt, plus the tick and its gap.
  static const axisWidth = 56.0;

  /// The tallest bar or the tallest capacity line, whichever is higher — a
  /// scale fitted to the bars alone would push the capacity line off the top on
  /// a quiet month and make an under-loaded plant look overloaded.
  final int peakSeconds;

  final List<HoursTick> ticks;

  /// Where the zero line sits in a plot of [height].
  double floorOf(double height) => height - axis;

  /// Where [seconds] sits in a plot of [height].
  double y(double height, int seconds) {
    final bottom = floorOf(height);
    if (peakSeconds <= 0) return bottom;
    return headroom + (bottom - headroom) * (1 - seconds / peakSeconds);
  }
}

/// Ticks at a round number of hours, four to six of them.
///
/// **Rounded to 1, 2, 2.5, 5 or 10 times a power of ten** rather than to the
/// peak divided by five: an axis reading 1,877 / 3,754 / 5,630 is
/// arithmetically correct and unreadable, and the figure a planner carries away
/// from this chart is *"about eight thousand hours"*.
///
/// **2.5 is on the ladder because leaving it off broke the axis**, and a test
/// caught it before anything was drawn: a 12,345 h peak normalises to 2.469,
/// which without 2.5 rounds up to 5 and gives a step of 5,000 — an axis of
/// three ticks, `0 / 5,000 / 10,000`, for a plant asking twelve thousand hours.
List<HoursTick> hoursTicks(int peakSeconds, String locale) {
  if (peakSeconds <= 0) return const [];
  final hours = peakSeconds / 3600;
  final raw = hours / 5;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final normalised = raw / magnitude;
  final step =
      (normalised <= 1
          ? 1.0
          : normalised <= 2
          ? 2.0
          : normalised <= 2.5
          ? 2.5
          : normalised <= 5
          ? 5.0
          : 10.0) *
      magnitude;

  // A sub-hour step needs a decimal, or every tick of a tiny plant rounds to
  // the same label — `0 / 0 / 0 / 1 / 1 / 1` for a step of 0.2 h.
  final format = NumberFormat.decimalPattern(locale)
    ..maximumFractionDigits = step < 1 ? 1 : 0;

  return [
    // The epsilon is the accumulator's, not the data's: adding 0.2 five times
    // lands on 0.9999999999999999, which would drop the topmost tick.
    for (var h = 0.0; h <= hours + step * 1e-9; h += step)
      HoursTick(seconds: (h * 3600).round(), label: format.format(h)),
  ];
}
