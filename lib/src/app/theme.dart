import 'package:flutter/material.dart';

import 'tokens.dart';

/// App theming, Material 3 from a single seed, corrected for the stock-M3 tells.
///
/// **The seed is a blueprint blue, and it used to be green** (`0xFF13906B`, the
/// VSM canvas's insertion affordance). It moved in v2.0 for a reason that is not
/// taste: green already meant *on time* in the delivery float, so the brand
/// colour and a reported state were the same colour. `FloatBand.green` resolved
/// to `primaryContainer`, which made "change the accent" and "change what a
/// delivery cell means" the same edit. Moving the seed off green frees green to
/// mean only one thing, and no reader has to learn that this green is a button
/// while that green is a delivery.
///
/// Blue rather than any other escape: FlowMap draws value-stream maps, and the
/// blue of an engineering drawing is the one hue that reads as *the tool* rather
/// than as another status.
///
/// **What the seed no longer decides.** Status colours, the occupation ramp and
/// the part palette are all chosen explicitly in `tokens.dart` and
/// `common/part_palette.dart`. In v1.0 they were `primary`, `secondary`,
/// `tertiary` and `error`, so the scheme's generated hues were carrying meanings
/// nobody had picked. The seed now governs chrome and nothing else.
class FlowMapTheme {
  const FlowMapTheme._();

  static const Color _seed = Color(0xFF1F5C8B);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      // Material 3 tints surfaces toward the seed; at rest that reads as dirty
      // grey rather than as a surface. A flat `surface` is the ground.
      scaffoldBackgroundColor: scheme.surface,
      // **A hairline rather than a shadow.** Stock cards float on elevation,
      // which in a screen that is mostly tables reads as a stack of unrelated
      // slabs. Real shadow is reserved for things that genuinely float — menus
      // and dialogs, which keep theirs.
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ),
      // Some M3 components default to 20–28 px, which is bubbly next to a dense
      // grid. Pulled onto the radius scale.
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      // Desktop, and the screens are dense tables: comfortable rather than
      // standard, which on Windows is otherwise laid out for touch.
      visualDensity: VisualDensity.comfortable,
    );
  }
}
