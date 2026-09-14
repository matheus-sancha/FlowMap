import 'dart:ui';

import 'package:flowmap/src/app/window_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// The window opened with its caption bar above the top of the screen, so the
/// minimise, maximise and close buttons were not there (field report,
/// 2026-09-14). The reporter got at it by snapping the window to one side,
/// which resizes it to the work area and drags the caption back into view.
///
/// **The cause was arithmetic, not the window plugin.** [WindowGeometry
/// .defaultSize] is 1600x1000 *logical* pixels and was centred without ever
/// being compared to the screen. Windows' own recommended display scaling on
/// an ordinary 1080p laptop leaves a work area of 1536x824 at 125% or 1280x680
/// at 150% — so the default was taller than the screen, and centring something
/// taller than the screen puts its top edge above the screen:
///
///     top = (680 - 1000) / 2 = -160
///
/// **No pixel is drawn here.** Where a window lands is arithmetic over two
/// rectangles, and asserting it needs neither a display nor a plugin — which
/// is the point, because the machine the suite runs on is not the machine that
/// had the bug.
void main() {
  // The work areas of real hardware, taskbar already subtracted.
  const scaled150 = Rect.fromLTWH(0, 0, 1280, 680); // 1080p at 150%
  const scaled125 = Rect.fromLTWH(0, 0, 1536, 824); // 1080p at 125%
  const unscaled = Rect.fromLTWH(0, 0, 1920, 1040); // 1080p at 100%
  const secondary = Rect.fromLTWH(1920, 0, 1280, 680); // one to the right

  group('fitSize', () {
    test('shrinks the default to a work area smaller than it', () {
      final size = WindowGeometry.fitSize(WindowGeometry.defaultSize, scaled150);
      expect(size.width, 1280);
      // 680 would fit the screen, but the canvas cannot lay out below 700.
      expect(size.height, WindowGeometry.minimumSize.height);
    });

    test('leaves the default alone when the work area is larger', () {
      expect(
        WindowGeometry.fitSize(WindowGeometry.defaultSize, unscaled),
        WindowGeometry.defaultSize,
      );
    });

    test('never returns anything below the minimum the canvas needs', () {
      const tiny = Rect.fromLTWH(0, 0, 400, 300);
      final size = WindowGeometry.fitSize(WindowGeometry.defaultSize, tiny);
      expect(size, WindowGeometry.minimumSize);
    });
  });

  group('defaultBoundsIn', () {
    test('centres on a work area that can hold it', () {
      final bounds = WindowGeometry.defaultBoundsIn(unscaled);
      expect(bounds, const Rect.fromLTWH(160, 20, 1600, 1000));
    });

    test('centres within the display it is given, not the desktop', () {
      final bounds = WindowGeometry.defaultBoundsIn(secondary);
      expect(bounds.left, greaterThanOrEqualTo(secondary.left));
      expect(bounds.top, secondary.top);
    });

    // The regression. Both of these centred to a negative top before the fix.
    for (final area in [scaled150, scaled125]) {
      test('keeps the caption on screen at ${area.width}x${area.height}', () {
        final bounds = WindowGeometry.defaultBoundsIn(area);
        expect(bounds.top, greaterThanOrEqualTo(area.top));
        expect(bounds.left, greaterThanOrEqualTo(area.left));
        expect(bounds.width, lessThanOrEqualTo(area.width));
      });
    }

    test('hangs off the bottom rather than off the top when too short', () {
      final bounds = WindowGeometry.defaultBoundsIn(scaled150);
      // The canvas minimum wins over the screen, so it does overflow — but
      // downwards, where the caption is still reachable.
      expect(bounds.height, WindowGeometry.minimumSize.height);
      expect(bounds.bottom, greaterThan(scaled150.bottom));
      expect(bounds.top, scaled150.top);
    });
  });

  group('withCaptionOnScreen', () {
    test('pushes down a frame whose caption is above the work area', () {
      const stored = Rect.fromLTWH(-160, -160, 1600, 1000);
      final fixed = WindowGeometry.withCaptionOnScreen(stored, [scaled150]);
      expect(fixed.top, scaled150.top);
      // Only the top moves: the rest is a position a user can reach.
      expect(fixed.left, stored.left);
      expect(fixed.size, stored.size);
    });

    test('leaves a window parked off the right and bottom alone', () {
      const parked = Rect.fromLTWH(1000, 600, 1600, 1000);
      expect(
        WindowGeometry.withCaptionOnScreen(parked, [unscaled]),
        parked,
      );
    });

    test('leaves a window straddling two displays alone', () {
      const straddling = Rect.fromLTWH(1500, 100, 1600, 600);
      expect(
        WindowGeometry.withCaptionOnScreen(straddling, [unscaled, secondary]),
        straddling,
      );
    });

    test('corrects against the display the window sits in most', () {
      // Mostly on the secondary, caption above both.
      const stored = Rect.fromLTWH(2000, -50, 1000, 600);
      final fixed = WindowGeometry.withCaptionOnScreen(stored, [
        unscaled,
        secondary,
      ]);
      expect(fixed.top, secondary.top);
    });

    test('changes nothing when no display could be measured', () {
      const stored = Rect.fromLTWH(-160, -160, 1600, 1000);
      expect(WindowGeometry.withCaptionOnScreen(stored, const []), stored);
    });
  });

  group('isOnSomeWorkArea', () {
    test('a frame left behind by an unplugged monitor is not usable', () {
      const geometry = WindowGeometry(
        bounds: Rect.fromLTWH(-1500, -900, 1600, 1000),
        maximized: false,
      );
      expect(geometry.isOnSomeWorkArea(const [unscaled]), isFalse);
    });

    test('a frame hanging slightly off an edge still is', () {
      const geometry = WindowGeometry(
        bounds: Rect.fromLTWH(-100, 50, 1600, 1000),
        maximized: false,
      );
      expect(geometry.isOnSomeWorkArea(const [unscaled]), isTrue);
    });

    test('a frame on the second display is, and on neither is not', () {
      const onSecond = WindowGeometry(
        bounds: Rect.fromLTWH(2000, 100, 1100, 700),
        maximized: false,
      );
      expect(onSecond.isOnSomeWorkArea(const [unscaled, secondary]), isTrue);
      expect(onSecond.isOnSomeWorkArea(const [unscaled]), isFalse);
    });
  });
}
