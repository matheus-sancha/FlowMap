/// The scales every widget draws from (v2.0).
///
/// **One rule: if a value is not on a scale here, either it is wrong or the
/// scale is missing a step.** Fix the scale, not the widget. A `SizedBox(height:
/// 13)` or a one-off `Color(0xFF…)` in a widget is the thing this file exists to
/// prevent.
///
/// Most of [Space] is ratification rather than change: before it existed the
/// tree already used `8` fifty times, `12` forty-nine, `16` thirty-six, `4`
/// nineteen and `24` thirteen. Writing the scale down mostly names what was
/// already true — and exposes the strays, of which there was one worth folding
/// (`6`, thirteen uses).
///
/// **Colour is split three ways on purpose**, because FlowMap draws in three
/// different languages and v1.0 let them share four Material roles:
///
/// * [FlowStatus] — reserved states. Never a series, never decoration.
/// * `partPalette` (in `common/part_palette.dart`) — categorical identity.
///
/// **There was a third, `OccupationRamp`, and #9 retired it.** It was an
/// *ordered* quantity — one hue light-to-dark — and it existed to colour the
/// Occupation chart's four-segment stack. That chart is a station × month grid
/// now, its bands are [FlowStatus] good/warning/critical against the project's
/// own thresholds, and nothing else in the app draws an ordered quantity. It is
/// deleted rather than kept for a future caller: §17.5's own lesson is that
/// unreachable code with a plausible future consumer is not inert, it is a
/// loaded slot.
///
/// In v1.0 `tertiary` was literally assigned as `warning:` in one file and as
/// *rework* in another, and `primary` was the brand, the on-time float band and
/// the process segment at once. Material generates `secondary` and `tertiary`
/// automatically; nobody chose them, and they were carrying meaning.
library;

import 'package:flutter/material.dart';

/// Spacing — an 8-dp rhythm, with 4 for tight pairs.
///
/// Column widths (110–150) are a measurement scale rather than a spacing one
/// and are not on this scale.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const huge = 64.0;
}

/// Radius — one family, picked by component role rather than per whim.
abstract final class Radii {
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;

  /// Pills and avatars.
  static const full = 999.0;
}

/// Motion — three durations and one curve.
///
/// Enter and exit only, where it clarifies. The sidebar's collapse ran at 160 ms
/// before this scale existed; it snaps to [base].
abstract final class Motion {
  static const fast = Duration(milliseconds: 100);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 300);
  static const curve = Curves.easeOutCubic;
}

/// A reserved state, as the pair a cell actually needs.
///
/// [fill] is the cell or chip behind the value; [ink] is what is written on it,
/// and is also the colour for a stroke or a line that has to carry the same
/// meaning without a fill behind it — the over-capacity line on the occupation
/// chart is [FlowStatus.critical]'s ink.
class StatusColour {
  const StatusColour(this.fill, this.ink);

  final Color fill;
  final Color ink;
}

/// The four states FlowMap reports, chosen rather than derived.
///
/// **Chosen is the whole point.** In v1.0 these were `primaryContainer`,
/// `tertiaryContainer` and `errorContainer` — so re-seeding the brand for
/// aesthetic reasons silently moved the meaning of every delivery-float cell.
/// Now the seed can move and these cannot.
///
/// Every pair clears **5.78:1 or better** ink-on-fill and ink-on-surface in both
/// brightnesses, checked with `dataviz`'s validator rather than by eye.
///
/// [undelivered] is deliberately not a shade of [critical]: late by a month and
/// never finished are different findings, and colouring them alike hides the
/// second inside the first.
class FlowStatus {
  const FlowStatus({
    required this.good,
    required this.warning,
    required this.critical,
    required this.undelivered,
  });

  factory FlowStatus.of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  static const _light = FlowStatus(
    good: StatusColour(Color(0xFFD1F2D7), Color(0xFF00601C)),
    warning: StatusColour(Color(0xFFFCE4C4), Color(0xFF773C00)),
    critical: StatusColour(Color(0xFFFFDCD7), Color(0xFF892122)),
    undelivered: StatusColour(Color(0xFFEEEEEC), Color(0xFF5C5C58)),
  );

  static const _dark = FlowStatus(
    good: StatusColour(Color(0xFF14361D), Color(0xFF9CE6AB)),
    warning: StatusColour(Color(0xFF3F2903), Color(0xFFFBC77C)),
    critical: StatusColour(Color(0xFF47211E), Color(0xFFFFB5AD)),
    undelivered: StatusColour(Color(0xFF2A2A28), Color(0xFFA6A6A0)),
  );

  final StatusColour good;
  final StatusColour warning;
  final StatusColour critical;
  final StatusColour undelivered;
}

/// The occupation chart's stacked segments, as an ordered ramp.
///

