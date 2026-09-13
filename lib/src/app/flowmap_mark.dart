import 'package:flutter/material.dart';

/// FlowMap's mark, drawn rather than imported.
///
/// **Traced from `docs/brand/flowmap-mark-reference.png`**, which stays in the
/// repo as the reference and is not shipped. A single raster could not meet the
/// spec #33 set: its bars are `#161B23` and **vanish on a dark ground**, and a
/// bitmap cannot give the PDF header the paths #27's vector document needs. One
/// source gives both colourways, a compact form, and the `.ico`.
///
/// It follows `vsm_symbols.dart`'s argument exactly — *a font or an image set
/// would tie the look to an asset that cannot be recoloured for a dark theme or
/// re-rendered into a vector PDF* — and it is the same shape of thing: two
/// rounded bars and an arrow, a few dozen lines of geometry.
///
/// **Proportions are the reference's, measured rather than eyeballed.** Mark box
/// 656 × 566, aspect 1.159, with each element's extent taken from the image:
///
/// | element | y | height | x | width |
/// |---|---|---|---|---|
/// | top bar | 0.0–27.9 % | 27.9 % | 7.2–86.0 % | 78.8 % |
/// | arrow shaft | 39.8–62.4 % | **22.6 %** | 1.1–99.7 % | 98.6 % |
/// | arrow head | 32.9–68.7 % | 35.9 % | from 78 % | |
/// | bottom bar | 73.7–99.8 % | 26.1 % | 5.6–72.0 % | 66.3 % |
///
/// **The arrow row was measured column by column, not from its bounding box**,
/// and the box was misleading in three ways: the shaft is *thinner* than either
/// bar rather than thicker, the head reaches its full height only where it is
/// widest, and the tail **curves down to the left** — at x = 5 % the blue sits
/// at 45.4–73.3 % rather than centred. That curve is the mark's character, and
/// a straight tail measures identically while losing it.
///
/// The arrow and the bottom bar **touch** (0.4 %) while the top bar has a 3.4 %
/// gap. That asymmetry is in the reference and is kept rather than tidied.
class FlowmapMark extends StatelessWidget {
  const FlowmapMark({super.key, this.size = 32, this.barColor, this.arrowColor});

  /// The height in logical pixels. Width follows [aspect].
  final double size;

  /// Defaults to the theme's `onSurface`, which is what makes the mark work on
  /// both grounds — the failure the supplied raster could not avoid.
  final Color? barColor;

  /// Defaults to the app's seed blue, `#1F5C8B` (#8).
  final Color? arrowColor;

  static const aspect = 656 / 566;

  /// Below this the arrow's tail is thinner than a pixel at any sensible
  /// density, so the compact form drops it (#33).
  static const compactBelow = 24.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size * aspect,
      height: size,
      child: CustomPaint(
        painter: FlowmapMarkPainter(
          barColor: barColor ?? scheme.onSurface,
          arrowColor: arrowColor ?? const Color(0xFF1F5C8B),
          compact: size < compactBelow,
        ),
      ),
    );
  }
}

/// Draws the mark into any canvas, at any size.
///
/// Public so the `.ico` generator and the PDF header can use the one geometry
/// rather than each having their own — the *one function, two callers* rule
/// #14 names as the fix for a fault this codebase has had twice.
class FlowmapMarkPainter extends CustomPainter {
  const FlowmapMarkPainter({
    required this.barColor,
    required this.arrowColor,
    this.compact = false,
  });

  final Color barColor;
  final Color arrowColor;

  /// At very small sizes the arrow keeps its head and loses its tail, and the
  /// bars thicken to stay separable.
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void bar(double top, double height, double left, double right) {
      final rect = Rect.fromLTRB(w * left, h * top, w * right, h * (top + height));
      canvas.drawRRect(
        // Fully rounded ends: the radius is half the bar's height, which is
        // what keeps them reading as bars rather than as boxes at any size.
        RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
        Paint()..color = barColor,
      );
    }

    bar(0.000, compact ? 0.310 : 0.279, 0.072, 0.860);
    bar(compact ? 0.690 : 0.737, compact ? 0.310 : 0.261, 0.056, 0.720);

    // The arrow, from the reference measured column by column rather than
    // from the bounding box. Three things the box could not say, and all three
    // were wrong in the first trace:
    //
    //   * the shaft is **22.6 %** — *thinner* than either bar, not thicker
    //   * the head reaches **35.9 %**, and only where it is widest (x ≈ 82 %)
    //   * the tail **curves down to the left**: at x = 5 % the blue sits at
    //     45.4–73.3 % rather than centred on the shaft
    //
    // That last one is the mark's whole character — the flow sweeping in from
    // below — and a straight tail loses it while measuring identically.
    const shaftTop = 0.398;
    const shaftBottom = 0.624;
    const headTop = 0.329;
    const headBottom = 0.687;
    const headStart = 0.780;

    final midY = h * (shaftTop + shaftBottom) / 2;
    final tail = w * 0.011;
    final tip = w * 0.997;

    // The curve is dropped in the compact form: below 24 px it is a pixel of
    // wobble that only blurs the shaft.
    final arrow = Path()..moveTo(tail, h * (compact ? shaftTop : 0.454));
    if (compact) {
      arrow.lineTo(w * headStart, h * shaftTop);
    } else {
      arrow
        ..quadraticBezierTo(w * 0.09, h * shaftTop, w * 0.22, h * shaftTop)
        ..lineTo(w * headStart, h * shaftTop);
    }
    arrow
      ..lineTo(w * headStart, h * headTop)
      ..lineTo(tip, midY)
      ..lineTo(w * headStart, h * headBottom)
      ..lineTo(w * headStart, h * shaftBottom);
    if (compact) {
      arrow.lineTo(tail, h * shaftBottom);
    } else {
      arrow
        ..lineTo(w * 0.22, h * shaftBottom)
        ..quadraticBezierTo(w * 0.09, h * shaftBottom, tail, h * 0.733);
    }
    arrow.close();

    canvas.drawPath(arrow, Paint()..color = arrowColor);
  }

  @override
  bool shouldRepaint(FlowmapMarkPainter old) =>
      old.barColor != barColor ||
      old.arrowColor != arrowColor ||
      old.compact != compact;
}
