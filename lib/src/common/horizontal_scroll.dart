/// A pane whose content is wider than it is, with a bar that says so
/// (DESIGN.md §12.6).
///
/// Every wide table in the app already scrolled sideways before this existed —
/// what none of them had was a way to *drive* it. A plain wheel has a vertical
/// job everywhere (rows in the grid, the page on the Simulation tab), Flutter
/// only flips a wheel's axis while Shift is held, and mouse drag-to-scroll is
/// off by default on desktop. So the content was reachable only by a shortcut
/// nobody finds, and the table read as simply cut off.
///
/// The bar is therefore always present while there is anything to reach, and it
/// is draggable — which is why the controller lives here rather than being left
/// implicit. A horizontal [SingleChildScrollView] never attaches to the
/// `PrimaryScrollController`, so a `Scrollbar` given no controller of its own
/// holds no position and cannot drag one.
///
/// **The wheel is deliberately not touched.** Hijacking it would strand
/// whatever vertical scroll the pane sits in: park the pointer on a
/// thirteen-column production plan and the page below it could never be
/// reached.
library;

import 'package:flutter/material.dart';

class HorizontalScroll extends StatefulWidget {
  const HorizontalScroll({super.key, required this.child, this.controller});

  final Widget child;

  /// A controller to use instead of the one this would otherwise make, for the
  /// callers that have to *read or move* the offset rather than merely let the
  /// user drag it.
  ///
  /// The Gantt is the case (§8.6): zooming about the pane's centre has to put
  /// the offset back where the same instant is still centred, and the axis has
  /// to know which slice of a sixteen-million-pixel run is on screen so it can
  /// build ticks for that and nothing else. Ownership follows provision — a
  /// controller passed in is disposed by whoever passed it.
  final ScrollController? controller;

  @override
  State<HorizontalScroll> createState() => _HorizontalScrollState();
}

class _HorizontalScrollState extends State<HorizontalScroll> {
  ScrollController? _own;

  ScrollController get _controller =>
      widget.controller ?? (_own ??= ScrollController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _controller,
    thumbVisibility: true,
    // Stated rather than inherited. Material makes a scrollbar a read-only
    // indicator on Android and a control everywhere else, and this one is the
    // whole answer to "there is no way to scroll" — it is a control on purpose,
    // on every platform the tests happen to run as.
    interactive: true,
    // A vertically scrolling descendant reports through here as well — the
    // body of a result table, the rows of a `DataGrid` — and this bar is not
    // its bar. The default predicate keys on depth, which is a fact about how
    // deeply someone happened to nest the child; the axis is the actual
    // question being asked.
    notificationPredicate: (notification) =>
        notification.metrics.axis == Axis.horizontal,
    child: SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      child: widget.child,
    ),
  );
}
