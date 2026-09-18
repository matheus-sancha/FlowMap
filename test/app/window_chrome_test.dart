import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flowmap/src/app/app_scale.dart';
import 'package:flowmap/src/app/window_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// `window.json` gained a second writer (#18), and that is the whole risk.
///
/// The studies pane's collapse moved in beside `maximized` because the file
/// exists for exactly this — chrome that is not domain state and would
/// otherwise cost a schema migration per field. But [WindowGeometry.save] wrote
/// the file wholesale, so the next window move would have dropped the pane key
/// without a word. That fault would only ever have been reported as *"it
/// forgets, sometimes"*, which is the hardest kind of bug to be handed.
///
/// **No pixel is drawn here.** Whether a collapsed pane survives a mode switch
/// is a property of a file and a provider, which is what this ticket claimed
/// and what these assert.
void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('flowmap-chrome');
    PathProviderPlatform.instance = _FakePathProvider(temp.path);
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  File file() => File(p.join(temp.path, WindowGeometry.fileName));

  Map<String, Object?> onDisk() =>
      (jsonDecode(file().readAsStringSync()) as Map).cast<String, Object?>();

  const geometry = WindowGeometry(
    bounds: Rect.fromLTWH(100, 80, 1600, 1000),
    maximized: true,
  );

  test('a missing file reads as not collapsed', () async {
    // The state a reader can act on. Hiding the study list because there is no
    // json file yet would be the app losing a pane on a first run.
    expect(file().existsSync(), isFalse);
    expect(await WindowChrome.studiesPaneCollapsed(), isFalse);
  });

  test('the collapse round-trips through the file', () async {
    await WindowChrome.setStudiesPaneCollapsed(true);
    expect(await WindowChrome.studiesPaneCollapsed(), isTrue);

    await WindowChrome.setStudiesPaneCollapsed(false);
    expect(await WindowChrome.studiesPaneCollapsed(), isFalse);
  });

  test('saving geometry does not drop the pane', () async {
    // **The reason `save` merges.** Written the obvious way, the next window
    // move after a collapse would have quietly restored the pane.
    await WindowChrome.setStudiesPaneCollapsed(true);
    await geometry.save();

    expect(await WindowChrome.studiesPaneCollapsed(), isTrue);
    expect(onDisk()['maximized'], isTrue);
    expect(onDisk()['left'], 100);
  });

  test('setting the pane does not drop the geometry', () async {
    // And the other way round, which is the half that would have shown up as
    // the window forgetting where it was.
    await geometry.save();
    await WindowChrome.setStudiesPaneCollapsed(true);

    final restored = WindowGeometry.fromJson(onDisk());
    expect(restored, isNotNull);
    expect(restored!.bounds, geometry.bounds);
    expect(restored.maximized, isTrue);
    expect(onDisk()['studiesPaneCollapsed'], isTrue);
  });

  test('a hand-edited value is rejected rather than thrown on', () async {
    // Same rule `fromJson` already follows: this file is plain text in a folder
    // users are told to open when sending diagnostics.
    file().writeAsStringSync('{"studiesPaneCollapsed": "yes please"}');
    expect(await WindowChrome.studiesPaneCollapsed(), isFalse);
  });

  test('a corrupt file loses nothing but the file', () async {
    file().writeAsStringSync('{not json at all');
    expect(await WindowChrome.studiesPaneCollapsed(), isFalse);

    // And writing over it recovers, rather than failing forever.
    await WindowChrome.setStudiesPaneCollapsed(true);
    expect(await WindowChrome.studiesPaneCollapsed(), isTrue);
  });

  /// The scale moved in beside the pane (#48), and the file now has a third
  /// writer — which is the risk this whole file was written about.
  group('the scale', () {
    test('a stored value is read back, and wins', () async {
      await WindowChrome.setScale(0.8);
      expect(await WindowChrome.scale(), 0.8);
      expect(onDisk()['scale'], 0.8);
    });

    test('does not drop the keys beside it', () async {
      await geometry.save();
      await WindowChrome.setStudiesPaneCollapsed(true);
      await WindowChrome.setScale(0.9);

      final json = onDisk();
      expect(json['scale'], 0.9);
      expect(json['studiesPaneCollapsed'], isTrue);
      expect(json['maximized'], geometry.maximized);
      expect(json['width'], geometry.bounds.width);
    });

    test('and is not dropped BY the keys beside it', () async {
      await WindowChrome.setScale(0.7);
      // A window move writes geometry through a different path entirely.
      await geometry.save();
      expect(onDisk()['scale'], 0.7);
      expect(await WindowChrome.scale(), 0.7);
    });

    test('an out-of-range value is clamped, not honoured', () async {
      await WindowChrome.setScale(9);
      expect(await WindowChrome.scale(), AppScale.maxScale);
    });

    test('a hand-edited value that is not a number is treated as absent', () {
      // Absent means *derive from the screen*, which needs a display this test
      // has no way to provide — so the assertion is that it does not throw and
      // does not return the nonsense, rather than what it returns.
      file().writeAsStringSync('{"scale": "big please"}');
      expect(WindowChrome.scale(), completion(isNot('big please')));
    });
  });

  /// The first-run default (#48), which is arithmetic and needs no file.
  group('the scale a screen deserves', () {
    double forWorkArea(double w, double h) =>
        WindowChrome.defaultScaleIn(Rect.fromLTWH(0, 0, w, h));

    test('a 14-inch laptop opens at the scale #49 measured', () {
      // 1920x1080 at Windows' default 150 % scaling is a 1280x720 *screen*, and
      // a ~48 px taskbar leaves this **work area** — which is what the
      // derivation is handed. #50 lowered `comfortableSize`'s height to 840 for
      // exactly this: at 900 the height term dragged the target to 0.7, one
      // step below what #49 measured on this very screen.
      expect(forWorkArea(1280, 672), 0.8);
      // And the full-screen figure, for a machine with the taskbar hidden.
      expect(forWorkArea(1280, 720), 0.8);
    });

    test('other real screens, work area rather than panel', () {
      expect(forWorkArea(1366, 720), 0.8);
      expect(forWorkArea(1536, 816), 0.9);
      expect(forWorkArea(1920, 1032), AppScale.noScale);
    });

    test('never zooms in on a large monitor', () {
      // Wanting it bigger is a preference, not a fit problem, and guessing at a
      // preference is how a setting gets a reputation for meddling.
      expect(forWorkArea(2560, 1080), AppScale.noScale);
      expect(forWorkArea(3840, 2160), AppScale.noScale);
    });

    test('the short axis decides, not the wide one', () {
      // An ultrawide is not a big screen vertically, and height is what a short
      // work area is actually short of.
      expect(forWorkArea(3440, 900), AppScale.noScale);
      expect(forWorkArea(3440, 800), 0.9);
      expect(forWorkArea(3440, 640), 0.7);
    });

    test('a screen smaller than any step still gets the floor', () {
      expect(forWorkArea(800, 480), AppScale.steps.first);
    });
  });

  /// What the window may shrink to, now that the scale changes how much of the
  /// app a given window holds (#50).
  group('the floor moves with the scale, downwards only', () {
    test('zooming out lowers it', () {
      // Compared with a tolerance: 1100 * 0.7 is 770.0000000000001 in binary
      // floating point, and a window minimum does not care about the tail.
      void expectFloor(double scale, double w, double h) {
        final floor = WindowGeometry.minimumSizeAt(scale);
        expect(floor.width, moreOrLessEquals(w));
        expect(floor.height, moreOrLessEquals(h));
      }

      expectFloor(0.8, 880, 560);
      expectFloor(0.7, 770, 490);
    });

    test('at 100 % it is the floor this section always had', () {
      expect(
        WindowGeometry.minimumSizeAt(AppScale.noScale),
        WindowGeometry.minimumSize,
      );
    });

    test('zooming IN never raises it', () {
      // The reason for the min(scale, 1): proportional both ways would demand
      // 1650x1050 at 150 %, which is larger than the whole screen of the 14"
      // laptop this effort exists for.
      expect(WindowGeometry.minimumSizeAt(1.25), WindowGeometry.minimumSize);
      expect(WindowGeometry.minimumSizeAt(1.5), WindowGeometry.minimumSize);
    });

    test('a nonsense scale cannot lower the floor to nothing', () {
      expect(WindowGeometry.minimumSizeAt(double.nan), WindowGeometry.minimumSize);
      // Clamped to minScale rather than honoured, so the floor is half the
      // original and not nothing.
      expect(
        WindowGeometry.minimumSizeAt(0.0001).width,
        moreOrLessEquals(WindowGeometry.minimumSize.width * AppScale.minScale),
      );
    });

    test('FlowMap can now be half of a 1920 screen', () {
      // One of the cases that opened this map: 960 wide, beside a spreadsheet.
      // At 100 % the floor still refuses it, which is correct — the tree would
      // see 960 and the grids cannot lay out in that.
      const half = Rect.fromLTWH(0, 0, 960, 1032);
      expect(WindowGeometry.fitSize(const Size(1600, 1000), half).width, 1100);
      expect(
        WindowGeometry.fitSize(const Size(1600, 1000), half, scale: 0.8).width,
        960,
      );
    });

    test('the default no longer hangs off a short work area', () {
      // 1280x672 is the target laptop. At 100 % the 700 px floor won over the
      // work area and the window was 28 px taller than the screen — deliberate
      // once (the caption stays reachable) but no longer necessary, because the
      // machine opens at 80 % where the floor is 560.
      const work = Rect.fromLTWH(0, 0, 1280, 672);
      expect(WindowGeometry.fitSize(WindowGeometry.defaultSize, work).height, 700);
      expect(
        WindowGeometry.fitSize(WindowGeometry.defaultSize, work, scale: 0.8).height,
        672,
      );
    });
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
