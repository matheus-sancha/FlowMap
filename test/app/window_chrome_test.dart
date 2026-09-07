import 'dart:convert';
import 'dart:io';
import 'dart:ui';

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
