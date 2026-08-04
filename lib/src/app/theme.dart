import 'package:flutter/material.dart';

/// App theming, Material 3 from a single seed.
///
/// The seed is the green of the VSM canvas's insertion affordance — the one
/// accent in an otherwise monochrome map, so the diagram stays readable when
/// printed and the accent still means "you can act here".
class FlowMapTheme {
  const FlowMapTheme._();

  static const Color _seed = Color(0xFF13906B);

  static ThemeData light() => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    useMaterial3: true,
  );

  static ThemeData dark() => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}
