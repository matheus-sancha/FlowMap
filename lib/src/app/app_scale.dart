import 'package:flutter/widgets.dart';

/// Scales the whole app, by lying to it about how big the window is.
///
/// FlowMap is cramped on a 14" laptop — 1920x1080 at Windows' default 150 %
/// scaling is **1280x720 logical pixels**, against a `WindowGeometry.minimumSize`
/// of 1100x700 and a `WindowGeometry.defaultSize` of 1600x1000 that such a
/// machine cannot open at all. This is the mechanism that answers it (#47).
///
/// **The lie is the whole design.** The tree is told the window is
/// `size / scale` and the result is drawn back through a [Transform], so at
/// 80 % a 1280x720 window lays out as 1600x900 — and every hardcoded pixel in
/// the app multiplies for free. `simulation_tab.dart`'s `maxWidth < 1100`
/// branch, `result_table.dart`'s 110-150 column widths and `gantt_view.dart`'s
/// `_labelWidth` all behave as they do on a large monitor without being
/// touched. *Rejected: scaling the design tokens*, which would have reached
/// only the values that go through `tokens.dart` and left every stray literal
/// fixed — turning the per-screen sweep from verification into a rewrite.
///
/// **Not a bitmap stretch.** [Transform] is left with its default null
/// `filterQuality` on purpose: passing one forces the child through an image
/// filter, which is exactly the blur this must not have. Left null, the
/// transform is a layer matrix, text and vectors are rasterised at the final
/// on-screen scale, and a 70 % view is as sharp as a 100 % one.
///
/// **At [noScale] this widget is not in the tree at all** — no [MediaQuery]
/// override, no [Transform], no layer. A feature nobody has switched on should
/// cost nothing, and it means the default path is the one that shipped.
///
/// What still sees the *real* window, and now disagrees with the tree:
/// `window_manager`'s minimum size, `WindowGeometryObserver` and the bounds it
/// writes to `window.json`, `screen_retriever`'s work areas, and the native
/// caption bar — which is not ours and never scales. That disagreement is
/// deliberate: those all describe the window, and this describes what is drawn
/// inside it. What the minimum and default sizes should *become* is #50.
class AppScale extends StatelessWidget {
  const AppScale({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  /// The identity. Compared against exactly, so the widget can take itself out
  /// of the tree rather than installing a no-op transform.
  static const noScale = 1.0;

  /// A permissive guard, not the range a user may pick.
  ///
  /// This exists so a corrupt or hand-edited value cannot make the app
  /// unreadable or invisible — the same reason `window.json`'s numbers are
  /// type-tested rather than cast. **The range actually offered is #49's
  /// question**, decided by looking at a 1280x720 window rather than by
  /// argument, and it will be narrower than this at both ends.
  static const minScale = 0.5;
  static const maxScale = 2.0;

  /// The scale to run at, until there is somewhere to store one (#48) and a
  /// control to set it (#51).
  ///
  /// Overridable from the command line so the mechanism can be driven without
  /// a rebuild per step — which is what #49's walk and #52's sweep both need:
  ///
  /// ```
  /// flutter run -d windows --dart-define=flowmap.scale=0.8
  /// ```
  /// Parsed rather than `const`: there is no `double.fromEnvironment`, only
  /// the three `String`/`int`/`bool` forms, so the value arrives as text. An
  /// unparseable one is [noScale] rather than a crash — a mistyped
  /// `--dart-define` should start the app, not refuse to.
  static final double configured =
      double.tryParse(const String.fromEnvironment('flowmap.scale')) ?? noScale;

  /// [scale] brought inside [minScale]..[maxScale], and never NaN.
  ///
  /// A NaN reaching the transform paints nothing at all — a blank window with
  /// no error, on a machine belonging to someone who cannot read a stack
  /// trace — so it is turned into [noScale] rather than clamped, because NaN
  /// compares false against every bound.
  static double clamp(double scale) =>
      scale.isNaN ? noScale : scale.clamp(minScale, maxScale);

  @override
  Widget build(BuildContext context) {
    final effective = clamp(scale);
    if (effective == noScale) return child;

    final media = MediaQuery.of(context);
    final size = media.size / effective;

    return MediaQuery(
      // Every measurement in logical pixels is divided, not just the size: an
      // inset left at its real value would be the wrong number of *scaled*
      // pixels, and the scrollbar gutters in `result_table.dart` are laid out
      // against exactly these. `devicePixelRatio` and `textScaler` are left
      // alone on purpose — the first is the physical truth the transform does
      // not change, and the second is the user's own accessibility choice,
      // which this must not quietly multiply.
      data: media.copyWith(
        size: size,
        padding: media.padding / effective,
        viewPadding: media.viewPadding / effective,
        viewInsets: media.viewInsets / effective,
        systemGestureInsets: media.systemGestureInsets / effective,
      ),
      // **The constraints that arrive here are tight**, so a plain `SizedBox`
      // is ignored and the app would be laid out at the window's real size and
      // merely *drawn* smaller — the one thing this must not do. Something has
      // to loosen them.
      //
      // **The obvious way drops taps, and was caught by a test rather than by
      // reading.** `Transform.scale` with an `OverflowBox` inside it to do the
      // loosening: at 70 % the app draws perfectly and only its top-left
      // corner answers the mouse. `RenderTransform` deliberately does not
      // bounds-check itself — *"it's confusing to think about how the
      // untransformed size and the child's transformed position interact"* —
      // but the `OverflowBox` within it has no such scruple, and its own size
      // is the **real** window while its child is larger. Every tap past
      // 1280x720 in child space is discarded before it reaches anything.
      //
      // Moving the `OverflowBox` outside the transform fixes it, in both
      // directions; that arrangement was measured and works. `FittedBox` is
      // chosen over it because it does both jobs in one widget — it lays its
      // child out unbounded *and* applies the scale — leaving no second render
      // object whose size has to be reasoned about every time this is read.
      //
      // `filterQuality` is left null, here as on `Transform`: passing one
      // forces the child through an image filter, which is exactly the blur
      // this must not have.
      child: FittedBox(
        // Exact, rather than `contain`: [size] is the window divided by the
        // scale, so filling it back reproduces [effective] uniformly on both
        // axes with no letterboxing to reason about.
        fit: BoxFit.fill,
        // Top-left, so the app's origin stays the window's origin.
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    );
  }
}
