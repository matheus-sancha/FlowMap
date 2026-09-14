import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../data/app_directory.dart';
import '../features/diagnostics/application/diagnostics.dart';

/// Remembers where the window was, and puts it back.
///
/// Windows does not remember a window's size, position or maximised state for
/// an application — the app must. Without this, every launch opens at the
/// hardcoded size from `windows/runner/main.cpp` and begins with a manual
/// maximise, several times a day, for months.
///
/// Stored as a small json file beside the database rather than in the settings
/// table: window chrome is not domain state, and it would otherwise mean a
/// schema migration every time a field is added to it.
class WindowGeometry {
  const WindowGeometry({required this.bounds, required this.maximized});

  /// The window's frame in logical pixels, as last seen unmaximised. Kept even
  /// when [maximized] is true, so unmaximising restores somewhere sensible
  /// rather than the default.
  final Rect bounds;
  final bool maximized;

  static const fileName = 'window.json';

  /// Below this the VSM canvas and the demand grids cannot lay out, so the
  /// window refuses to go smaller rather than presenting an unusable workspace.
  static const minimumSize = Size(1100, 700);

  /// Used on a first run, and whenever a stored position no longer lands on a
  /// display that exists.
  static const defaultSize = Size(1600, 1000);

  /// How much of the window must overlap a display for the position to be
  /// considered usable. A title bar's worth: enough to grab and drag.
  static const _minimumVisible = Size(200, 40);

  Map<String, Object?> toJson() => {
    'left': bounds.left,
    'top': bounds.top,
    'width': bounds.width,
    'height': bounds.height,
    'maximized': maximized,
  };

  static WindowGeometry? fromJson(Map<String, Object?> json) {
    // Type-tested rather than cast: this file is plain text in a folder users
    // are told to open when sending diagnostics, so a hand-edited value has to
    // be *rejected*, not thrown on.
    double? number(String key) {
      final value = json[key];
      return value is num ? value.toDouble() : null;
    }

    final left = number('left');
    final top = number('top');
    final width = number('width');
    final height = number('height');
    if (left == null || top == null || width == null || height == null) {
      return null;
    }
    return WindowGeometry(
      bounds: Rect.fromLTWH(left, top, width, height),
      maximized: json['maximized'] == true,
    );
  }

  static Future<File> _file() async =>
      File(p.join((await appDataDirectory()).path, fileName));

  /// The file as it stands, or an empty map if there is not one to read.
  static Future<Map<String, Object?>> _readAll() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return {};
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? decoded.cast<String, Object?>() : {};
    } catch (error, stack) {
      Diag.error('window.readAll', error, stack);
      return {};
    }
  }

  static Future<void> _writeMerged(Map<String, Object?> changes) async {
    final merged = await _readAll()
      ..addAll(changes);
    await (await _file()).writeAsString(jsonEncode(merged), flush: true);
  }

  static Future<WindowGeometry?> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      return fromJson(decoded.cast<String, Object?>());
    } catch (error, stack) {
      // A corrupt or unreadable geometry file must never stop the app from
      // opening — it just opens where it would have before.
      Diag.error('window.load', error, stack);
      return null;
    }
  }

  /// **Merges rather than overwrites** (#18). This file gained a second writer
  /// when the studies pane's collapse moved into it, and a plain write here on
  /// the next window move would have silently dropped it — a fault that would
  /// only ever show up as *"it forgot again, sometimes"*.
  Future<void> save() async {
    try {
      await _writeMerged(toJson());
    } catch (error, stack) {
      Diag.error('window.save', error, stack);
    }
  }

  /// A display's work area — what is left of it once the taskbar is out of the
  /// way — as a rectangle, which is all any of the arithmetic below needs.
  static Rect workAreaOf(Display display) {
    final origin = display.visiblePosition ?? Offset.zero;
    final size = display.visibleSize ?? display.size;
    return Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
  }

  static List<Rect> workAreasOf(List<Display> displays) => [
    for (final display in displays) workAreaOf(display),
  ];

  /// [desired], shrunk to fit [workArea], but never below [minimumSize].
  ///
  /// **[defaultSize] is bigger than a great many real work areas**, which is
  /// the whole reason this exists (field report, 2026-09-14). It is 1600x1000
  /// *logical* pixels, and Windows' own recommended scaling on a 1080p laptop
  /// leaves 1536x824 at 125% or 1280x680 at 150% — so the default overflowed
  /// the screen on ordinary hardware, and centring something taller than the
  /// screen puts its top edge *above* the screen.
  ///
  /// [minimumSize] wins over the work area, because §12 says the canvas and
  /// the demand grids cannot lay out below it. On a screen too short for even
  /// that, the window hangs off the **bottom** — where the caption bar is
  /// still reachable, which is the thing that must never be given up.
  static Size fitSize(Size desired, Rect workArea) => Size(
    math.max(minimumSize.width, math.min(desired.width, workArea.width)),
    math.max(minimumSize.height, math.min(desired.height, workArea.height)),
  );

  /// Where a window with no remembered position should open on [workArea]:
  /// [defaultSize] fitted to it, and centred.
  ///
  /// Centred by arithmetic rather than by `windowManager.center()`, because
  /// centring a window larger than the screen is exactly what produced a
  /// negative top. The offsets are floored at zero, so an oversized window
  /// starts at the work area's own corner instead of outside it.
  static Rect defaultBoundsIn(Rect workArea) {
    final size = fitSize(defaultSize, workArea);
    return Rect.fromLTWH(
      workArea.left + math.max(0.0, (workArea.width - size.width) / 2),
      workArea.top + math.max(0.0, (workArea.height - size.height) / 2),
      size.width,
      size.height,
    );
  }

  /// [bounds] with the one correction a user could not have made themselves.
  ///
  /// **Windows will not let a caption bar be dragged above the top of a work
  /// area.** So a frame sitting there was never parked — it was computed — and
  /// the minimise, maximise and close buttons are off the screen with no way
  /// to drag them back. It is pushed down until the caption is visible.
  ///
  /// Nothing else is touched. Hanging off the left, the right or the bottom,
  /// and straddling two displays, are all positions a user reaches on purpose
  /// and can undo by hand, so they are left exactly as they were found.
  static Rect withCaptionOnScreen(Rect bounds, List<Rect> workAreas) {
    if (workAreas.isEmpty) return bounds;
    // The work area the window sits in most. Which one wins only matters when
    // a window straddles two, and then either answer puts the caption on a
    // screen the user is looking at.
    var best = workAreas.first;
    var most = -1.0;
    for (final area in workAreas) {
      final overlap = area.intersect(bounds);
      final covered = overlap.width <= 0 || overlap.height <= 0
          ? 0.0
          : overlap.width * overlap.height;
      if (covered > most) {
        most = covered;
        best = area;
      }
    }
    if (bounds.top >= best.top) return bounds;
    return Rect.fromLTWH(bounds.left, best.top, bounds.width, bounds.height);
  }

  /// Whether [bounds] still lands on a display that exists.
  ///
  /// This is the check that stops a laptop undocked from a second monitor
  /// opening entirely offscreen — where the window is unreachable and the app
  /// looks like it failed to launch. Only a corner needs to be reachable, so a
  /// window straddling two displays or hanging slightly off an edge is still
  /// accepted; users park windows like that deliberately.
  bool isOnSomeDisplay(List<Display> displays) =>
      isOnSomeWorkArea(workAreasOf(displays));

  /// [isOnSomeDisplay] over work areas already measured — the form the tests
  /// drive, and the form [restore] has to hand anyway.
  bool isOnSomeWorkArea(List<Rect> workAreas) {
    for (final screen in workAreas) {
      final overlap = screen.intersect(bounds);
      if (overlap.width >= _minimumVisible.width &&
          overlap.height >= _minimumVisible.height) {
        return true;
      }
    }
    return false;
  }

  /// Applies saved geometry, or sensible defaults.
  ///
  /// **Deliberately does not show the window.** `windows/runner/win32_window.cpp`
  /// creates it without `WS_VISIBLE`, and `flutter_window.cpp` shows it from the
  /// first-frame callback — so it is already hidden while this runs, and
  /// revealed only once there is something painted to see. Calling
  /// `windowManager.show()` here would reveal an *empty* window a moment early,
  /// which is the very flash this is meant to avoid. Do not add it back.
  ///
  /// Returns the unmaximised frame the window ended up with, for
  /// [WindowGeometryObserver.rememberNormalBounds].
  static Future<Rect> restore() async {
    final saved = await load();

    // **The displays are read before the size is chosen, not after.** The
    // default is larger than a great many work areas once display scaling is
    // on (see [fitSize]), so choosing it first and centring it second is what
    // put the caption bar off the top of the screen.
    var workAreas = const <Rect>[];
    Rect? primary;
    try {
      workAreas = workAreasOf(await screenRetriever.getAllDisplays());
      primary = workAreaOf(await screenRetriever.getPrimaryDisplay());
    } catch (error, stack) {
      // If the displays cannot be enumerated, trust the saved position rather
      // than second-guessing it: being wrong here costs a window in an odd
      // place, and refusing costs the user their layout every launch.
      Diag.error('window.displays', error, stack);
    }

    // Null only when the displays could not be read at all, and then there is
    // nothing to fit to and centring blind is the best that can be done.
    final fitted = primary == null ? null : defaultBoundsIn(primary);

    Rect? target;
    if (saved != null &&
        (workAreas.isEmpty || saved.isOnSomeWorkArea(workAreas))) {
      target = withCaptionOnScreen(saved.bounds, workAreas);
    } else {
      if (saved != null) {
        Diag.event('window.offscreen', 'ignoring saved position');
      }
      target = fitted;
    }

    final options = WindowOptions(
      size: target?.size ?? defaultSize,
      minimumSize: minimumSize,
      center: target == null,
      title: 'FlowMap',
    );

    // No callback: `waitUntilReadyToShow` invokes it *without awaiting*, so
    // anything asynchronous inside races the caller. Awaiting the options pass
    // and then doing the rest inline is deterministic.
    await windowManager.waitUntilReadyToShow(options);
    if (target != null) await windowManager.setBounds(target);

    // Read back before maximising — while maximised, getBounds() is the
    // screen. Only needed when centring blind, since otherwise the frame is
    // the one just set.
    final normal = target ?? await windowManager.getBounds();
    if (saved?.maximized ?? false) await windowManager.maximize();
    return normal;
  }
}


/// Window chrome that is not geometry, in the same file and for the same
/// reason (#18).
///
/// `window.json` exists because window chrome is not domain state and would
/// otherwise cost a schema migration for every field. A collapsed studies pane
/// is exactly that: a layout choice, made once, that a reader expects to still
/// hold tomorrow — the same expectation `maximized` next door already meets.
///
/// **Reads and writes are merged**, so this and [WindowGeometry.save] can both
/// own the file without either dropping the other's key.
///
/// Failure is always *not collapsed*: a missing, corrupt or unreadable file
/// opens the workspace with its study list showing, which is the state a reader
/// can act on. Hiding the list because a json file could not be parsed would be
/// the app losing a pane for a reason nobody can see.
abstract final class WindowChrome {
  static const _paneKey = 'studiesPaneCollapsed';

  static Future<bool> studiesPaneCollapsed() async =>
      (await WindowGeometry._readAll())[_paneKey] == true;

  static Future<void> setStudiesPaneCollapsed(bool collapsed) async {
    try {
      await WindowGeometry._writeMerged({_paneKey: collapsed});
    } catch (error, stack) {
      Diag.error('window.pane', error, stack);
    }
  }
}
