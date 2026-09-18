import 'package:flowmap/src/app/app_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mechanism behind the app-wide zoom (#47), and the one claim it rests on.
///
/// The whole map is six tickets rather than forty because of a single promise:
/// the tree is told the window is `size / scale`, so **every hardcoded pixel in
/// the app multiplies for free** and the per-screen sweep becomes verification
/// rather than a rewrite. If that promise is false the map is mis-scoped, so it
/// is asserted here directly — `laysOutAtTheScaledSize` and
/// `flipsALayoutBranchThatWouldNotHaveFlipped` are the two that matter.
///
/// **Drawn smaller is not the same as laid out bigger**, and the difference is
/// invisible in a screenshot. A `Transform` alone would have produced a correct
/// looking 80 % view in which `maxWidth < 1100` still took the narrow branch —
/// the fault this file exists to catch.
void main() {
  /// A 1280x720 window: a 14" laptop at 1920x1080 with Windows' default 150 %
  /// scaling, which is the screen this whole effort is designed against.
  const window = Size(1280, 720);

  /// Half of a 1920 screen — FlowMap beside a spreadsheet. The current
  /// `WindowGeometry.minimumSize` of 1100x700 refuses this window outright,
  /// which is #50's question; it is used here because it is the width where a
  /// real layout branch in the app actually turns over.
  const halfScreen = Size(1000, 1000);

  /// Sizes the test's view in logical pixels, so `MediaQuery` comes from the
  /// view exactly as it does under `MaterialApp`.
  void sizeWindow(WidgetTester tester, [Size size = window]) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  final childKey = GlobalKey();

  Widget scaled(double scale, {Widget? child}) => AppScale(
    scale: scale,
    child: MaterialApp(
      home: SizedBox.expand(child: KeyedSubtree(key: childKey, child: child ?? const SizedBox())),
    ),
  );

  group('the lie', () {
    testWidgets('reports the window as bigger than it is', (tester) async {
      sizeWindow(tester);
      late Size reported;
      await tester.pumpWidget(
        scaled(
          0.8,
          child: Builder(
            builder: (context) {
              reported = MediaQuery.sizeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      // 1280x720 at 80 % lays out as 1600x900 — the number the map quotes.
      expect(reported, const Size(1600, 900));
    });

    testWidgets('laysOutAtTheScaledSize, not merely drawn smaller', (
      tester,
    ) async {
      sizeWindow(tester);
      await tester.pumpWidget(scaled(0.8));

      // The render box is genuinely 1600x900 of layout...
      final box = tester.renderObject<RenderBox>(find.byKey(childKey));
      expect(box.size, const Size(1600, 900));

      // ...and still covers exactly the real window on screen. getRect walks
      // the transform, so this is the painted rect, not the laid-out one.
      expect(
        tester.getRect(find.byKey(childKey)),
        rectMoreOrLessEquals(Offset.zero & window, epsilon: 0.01),
      );
    });

    testWidgets('flipsALayoutBranchThatWouldNotHaveFlipped', (tester) async {
      // The claim the whole map rests on, asserted against the app's own
      // threshold: `simulation_tab.dart` puts the queue and share cards side by
      // side above 1100 and stacks them below it.
      sizeWindow(tester, halfScreen);

      Widget probe() => LayoutBuilder(
        builder: (context, constraints) =>
            Text(constraints.maxWidth < 1100 ? 'stacked' : 'side by side'),
      );

      // At 1000 px the cards stack, and no amount of window dragging helps —
      // the app is already at the width the user has.
      await tester.pumpWidget(scaled(AppScale.noScale, child: probe()));
      expect(find.text('stacked'), findsOneWidget);

      // At 80 % the same window is 1250 wide to the tree, so they do not. The
      // branch was never touched; it was simply told a different number.
      await tester.pumpWidget(scaled(0.8, child: probe()));
      expect(find.text('side by side'), findsOneWidget);
    });

    testWidgets('divides the insets as well as the size', (tester) async {
      sizeWindow(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 40);
      late MediaQueryData media;
      await tester.pumpWidget(
        scaled(
          0.5,
          child: Builder(
            builder: (context) {
              media = MediaQuery.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      // An inset left at its real value would be the wrong number of *scaled*
      // pixels — and `result_table.dart` lays its scrollbar gutters against
      // exactly these.
      expect(media.viewInsets.bottom, 80);
      // The physical truth the transform does not change.
      expect(media.devicePixelRatio, 1.0);
    });
  });

  group('at 100 %', () {
    testWidgets('takes itself out of the tree entirely', (tester) async {
      sizeWindow(tester);
      await tester.pumpWidget(scaled(AppScale.noScale));

      // A feature nobody has switched on should cost nothing: no scaling box,
      // no layer, no MediaQuery override — the path that shipped.
      expect(find.byType(FittedBox), findsNothing);
      expect(tester.renderObject<RenderBox>(find.byKey(childKey)).size, window);
    });
  });

  group('a value nobody chose', () {
    test('NaN becomes the identity rather than a blank window', () {
      // NaN compares false against every bound, so clamp() would pass it
      // through and the transform would paint nothing at all — with no error,
      // on a machine belonging to someone who cannot read a stack trace.
      expect(AppScale.clamp(double.nan), AppScale.noScale);
    });

    test('is brought inside the guard rails', () {
      expect(AppScale.clamp(0.01), AppScale.minScale);
      expect(AppScale.clamp(99), AppScale.maxScale);
      expect(AppScale.clamp(0.8), 0.8);
    });

    testWidgets('an out-of-range scale still draws the whole window', (
      tester,
    ) async {
      sizeWindow(tester);
      await tester.pumpWidget(scaled(0.01));

      // Clamped to minScale, so the window is still fully covered rather than
      // showing a hundredth of the app in the corner.
      expect(
        tester.getRect(find.byKey(childKey)),
        rectMoreOrLessEquals(Offset.zero & window, epsilon: 0.01),
      );
    });
  });

  /// **This is what caught the first attempt at the widget.**
  ///
  /// It was a `Transform.scale` with an `OverflowBox` inside it to loosen the
  /// tight constraints, and at 70 % it drew perfectly while only the top-left
  /// corner of the app answered the mouse — the `OverflowBox`'s own size is the
  /// real window, and it discards anything past it before the child ever sees
  /// it. A screenshot cannot show that, and neither can reading the build
  /// method.
  ///
  /// Both directions are asserted because a scale below 1 lays the app out
  /// *larger* than the window and a scale above 1 lays it out *smaller*, and
  /// the two exercise opposite sides of every bounds check on the way down.
  group('taps land where things are drawn', () {
    Future<bool> tapTheFarCorner(WidgetTester tester, double scale) async {
      var tapped = false;
      await tester.pumpWidget(
        scaled(
          scale,
          child: Align(
            // The far corner is the worst case: the further from the scaling
            // origin, the bigger the error when the matrix is not applied.
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              onPressed: () => tapped = true,
              child: const Text('Simular'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Simular'));
      return tapped;
    }

    testWidgets('zoomed out, where the app is laid out larger than the window', (
      tester,
    ) async {
      sizeWindow(tester);
      expect(await tapTheFarCorner(tester, 0.7), isTrue);
    });

    testWidgets('zoomed in, where it is laid out smaller', (tester) async {
      sizeWindow(tester);
      expect(await tapTheFarCorner(tester, 1.5), isTrue);
    });
  });

  group('the steps a user may pick (#49)', () {
    test('are inside the guard rails, which are wider on purpose', () {
      // The clamp is a guard against a corrupt value, not the menu. Every
      // offered step must sit inside it, or the control could hand the widget
      // a scale it refuses.
      for (final step in AppScale.steps) {
        expect(AppScale.clamp(step), step, reason: '$step is outside the clamp');
      }
      expect(AppScale.minScale, lessThan(AppScale.steps.first));
      expect(AppScale.maxScale, greaterThan(AppScale.steps.last));
    });

    test('are ordered, and include the identity', () {
      expect(AppScale.steps, orderedEquals([...AppScale.steps]..sort()));
      // There is no Reset item; 100 % is reached by being in this list.
      expect(AppScale.steps, contains(AppScale.noScale));
    });
  });

  group('choosing a scale from a measurement (#48)', () {
    test('snaps down to a step, never up', () {
      // Up would pick a scale the screen was measured as too small for, which
      // is the one direction that puts the cramping back.
      expect(AppScale.snapDown(0.85), 0.8);
      expect(AppScale.snapDown(0.96), 0.9);
      expect(AppScale.snapDown(1.24), AppScale.noScale);
    });

    test('lands on a step that is already one', () {
      for (final step in AppScale.steps) {
        expect(AppScale.snapDown(step), step);
      }
    });

    test('a measurement below every step gets the floor', () {
      expect(AppScale.snapDown(0.1), AppScale.steps.first);
    });
  });
}
