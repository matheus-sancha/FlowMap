import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../data/app_directory.dart';
import '../features/diagnostics/application/diagnostics.dart';
import 'app_scale.dart';

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
  ///
  /// **This is the floor at 100 %.** What the window may actually shrink to is
  /// [minimumSizeAt], because the scale changes how much the tree sees of a
  /// given window (#50).
  static const minimumSize = Size(1100, 700);

  /// [minimumSize] as it applies at [scale] — **shrinking only**.
  ///
  /// The reason for a floor is that the tree must still see 1100x700 to lay
  /// out, and at 80 % an 880 px window already does. So zooming out may lower
  /// the floor, and FlowMap can finally be half of a 1920 screen.
  ///
  /// **Zooming in does not raise it**, which is the whole reason for the
  /// `min(scale, 1)`. Proportional in both directions is the tidier rule and
  /// was rejected on a number: at 150 % it would demand 1650x1050, which is
  /// larger than the entire screen of the 14" laptop this effort exists for —
  /// so zooming in would have to either fail or drag the window out from under
  /// the reader. Someone who zooms in has asked for bigger text and accepted
  /// seeing less; that is a choice, not a fault to be corrected.
  static Size minimumSizeAt(double scale) {
    final factor = math.min(AppScale.noScale, AppScale.clamp(scale));
    return Size(minimumSize.width * factor, minimumSize.height * factor);
  }

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
  /// **[defaultSize] is not changed by the scale**, deliberately. It is how
  /// large a window to *open*, and shrinking it to the target screen is this
  /// function's job; the floor is what was wrong. With [minimumSizeAt] in
  /// place, a 1280x672 work area now yields a 1280x672 window rather than one
  /// 700 tall that hangs 28 px off the bottom (#50).
  static Size fitSize(Size desired, Rect workArea, {double scale = 1.0}) {
    final floor = minimumSizeAt(scale);
    return Size(
      math.max(floor.width, math.min(desired.width, workArea.width)),
      math.max(floor.height, math.min(desired.height, workArea.height)),
    );
  }

  /// Where a window with no remembered position should open on [workArea]:
  /// [defaultSize] fitted to it, and centred.
  ///
  /// Centred by arithmetic rather than by `windowManager.center()`, because
  /// centring a window larger than the screen is exactly what produced a
  /// negative top. The offsets are floored at zero, so an oversized window
  /// starts at the work area's own corner instead of outside it.
  static Rect defaultBoundsIn(Rect workArea, {double scale = 1.0}) {
    final size = fitSize(defaultSize, workArea, scale: scale);
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
  static Future<Rect> restore({double scale = 1.0}) async {
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
    final fitted = primary == null
        ? null
        : defaultBoundsIn(primary, scale: scale);

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
      minimumSize: minimumSizeAt(scale),
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

  /// Re-applies the window's minimum for [scale], and grows the window if it
  /// is now below it.
  ///
  /// Called when the scale changes while the app is running. Growing is the
  /// cost [WindowGeometry.minimumSizeAt] accepts knowingly: someone who
  /// shrank the window at 70 % and then picks 100 % has asked for a layout
  /// their window can no longer hold, and a window quietly overflowing its
  /// content is worse than one that moved because they told it to. It never
  /// grows past the work area.
  ///
  /// Failures are swallowed and not awaited, as in `CloseGuard`: under
  /// `flutter test` there is no window plugin, and a setting that could throw
  /// while being applied is worse than one that is merely not applied.
  static Future<void> applyMinimumFor(double scale) async {
    final floor = minimumSizeAt(scale);
    await windowManager.setMinimumSize(floor);

    final bounds = await windowManager.getBounds();
    if (bounds.width >= floor.width && bounds.height >= floor.height) return;

    var work = Rect.fromLTWH(0, 0, double.infinity, double.infinity);
    try {
      work = workAreaOf(await screenRetriever.getPrimaryDisplay());
    } catch (_) {
      // Without a work area the floor is still the better of the two numbers.
    }
    await windowManager.setSize(
      Size(
        math.min(math.max(bounds.width, floor.width), work.width),
        math.min(math.max(bounds.height, floor.height), work.height),
      ),
    );
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
  static const _scaleKey = 'scale';

  static Future<bool> studiesPaneCollapsed() async =>
      (await WindowGeometry._readAll())[_paneKey] == true;

  static Future<void> setStudiesPaneCollapsed(bool collapsed) async {
    try {
      await WindowGeometry._writeMerged({_paneKey: collapsed});
    } catch (error, stack) {
      Diag.error('window.pane', error, stack);
    }
  }

  /// The size the app is comfortable at, which is what the first-run scale is
  /// measured against (#48).
  ///
  /// **Derived from #49's walk rather than chosen.** That walk found 0.8 to be
  /// the scale at which a 1280x720 laptop stops scrolling the densest screen in
  /// the app, and 1280x720 at 0.8 lays out as exactly 1600x900. So this is not
  /// a fourth opinion about how big FlowMap wants to be — it is the measured
  /// one, written down.
  ///
  /// Deliberately **not** [WindowGeometry.defaultSize]'s 1600x1000: that is how
  /// large a window to *open*, which may be generous, while this is the size
  /// below which the app starts to hurt.
  static const comfortableSize = Size(1600, 840);

  /// The scale to open at on a screen whose work area is [workArea], when the
  /// user has never chosen one.
  ///
  /// The smaller of the two axes, snapped down to a step, and **never above
  /// [AppScale.noScale]**: a large monitor gets the app as drawn rather than an
  /// automatic zoom *in*, because wanting it bigger is a preference and not a
  /// fit problem, and guessing at a preference is how a setting gets a
  /// reputation for meddling.
  static double defaultScaleIn(Rect workArea) {
    final raw = math.min(
      workArea.width / comfortableSize.width,
      workArea.height / comfortableSize.height,
    );
    return math.min(AppScale.noScale, AppScale.snapDown(raw));
  }

  /// The scale to run at: the stored one, or a first-run default measured from
  /// the screen and then written down.
  ///
  /// **Read before `runApp`, which is the whole reason it is in this file and
  /// not in `app_settings`.** A scale that arrived from the database could not
  /// be applied until the database was open — so every launch would draw at
  /// 100 %, wait out a 170 MB open and its migrations, and then snap. A json
  /// file next to it is readable with plain `dart:io` in `main`, so the first
  /// frame is already right. That ordering is the argument; *window chrome is
  /// not domain state* is why the file was already there to put it in.
  ///
  /// **A stored value always wins**, so docking a laptop to a large panel and
  /// undocking it again never silently moves a scale the user chose. The
  /// measurement happens once, on the launch that finds nothing stored.
  ///
  /// Failure in either direction is [AppScale.noScale]: a hand-edited value
  /// that is not a number is treated as absent (the rule the geometry fields
  /// already follow), and a screen that cannot be measured is not guessed at.
  static Future<double> scale() async {
    try {
      final stored = (await WindowGeometry._readAll())[_scaleKey];
      if (stored is num) return AppScale.clamp(stored.toDouble());
    } catch (error, stack) {
      Diag.error('window.scale', error, stack);
      return AppScale.noScale;
    }

    try {
      final work = WindowGeometry.workAreaOf(
        await screenRetriever.getPrimaryDisplay(),
      );
      final derived = defaultScaleIn(work);
      Diag.event(
        'window.scale',
        'first run: ${work.width.round()}x${work.height.round()} -> $derived',
      );
      await setScale(derived);
      return derived;
    } catch (error, stack) {
      Diag.error('window.scale.derive', error, stack);
      return AppScale.noScale;
    }
  }

  static Future<void> setScale(double scale) async {
    try {
      await WindowGeometry._writeMerged({_scaleKey: AppScale.clamp(scale)});
    } catch (error, stack) {
      Diag.error('window.scale.save', error, stack);
    }
  }
}
