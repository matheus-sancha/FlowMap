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
      // 1920x1080 at Windows' default 150 % scaling, which is the screen this
      // whole effort is designed against. #49 walked the range on exactly this
      // window and found 0.8; nothing here was tuned to make that come out.
      expect(forWorkArea(1280, 720), 0.8);
    });

    test('other real screens', () {
      expect(forWorkArea(1366, 768), 0.8);
      expect(forWorkArea(1536, 864), 0.9);
      expect(forWorkArea(1920, 1080), AppScale.noScale);
    });

    test('never zooms in on a large monitor', () {
      // Wanting it bigger is a preference, not a fit problem, and guessing at a
      // preference is how a setting gets a reputation for meddling.
      expect(forWorkArea(2560, 1080), AppScale.noScale);
      expect(forWorkArea(3840, 2160), AppScale.noScale);
    });

    test('the short axis decides, not the wide one', () {
      // An ultrawide is not a big screen vertically, and height is what a 720
      // px laptop is actually short of.
      expect(forWorkArea(3440, 900), AppScale.noScale);
      expect(forWorkArea(3440, 800), 0.8);
    });

    test('a screen smaller than any step still gets the floor', () {
      expect(forWorkArea(800, 480), AppScale.steps.first);
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
