/// Where everything sits on the map.
///
/// **Derived from the node sequence, never stored** (DESIGN.md §5.3). That is
/// what makes it impossible for the drawing, the lead-time ladder and the
/// routing to disagree: there is only one ordering, and this reads it.
///
/// Pure geometry in logical pixels — no widgets, so the layout can be asserted
/// in a test without pumping a frame.
library;

import 'dart:ui' show Rect, Size;

import 'flow_view.dart';

/// Fixed sizes, in logical pixels. Tuned so a six-step flow fits a 1600px
/// window at 100% without scrolling.
abstract final class FlowMetrics {
  /// A process box, and the inventory triangle's bounding box.
  static const nodeWidth = 168.0;

  /// The header strip carrying the workcenter code.
  static const nodeHeaderHeight = 34.0;

  /// The most data rows a box can carry. Equivalent appears only under a demand
  /// data source (§6.2), so seven of these are always there and the eighth
  /// comes and goes.
  static const nodeDataRows = 8;

  /// One data row: `bodySmall` and the 1px padding either side of it.
  static const nodeDataRowHeight = 18.5;

  /// Above and below the rows.
  static const nodeDataPadding = 4.0;

  /// Tall enough for every row the box can carry, and **spelled as the sum**
  /// rather than as the number it comes to.
  ///
  /// It was a flat `186.0` under a comment claiming it fitted eight rows. It
  /// fitted seven: switching the map to a demand source added Equivalent and
  /// the box overflowed by two pixels, which a release build hides and a debug
  /// build paints in yellow stripes. Written this way, a ninth row is a
  /// one-character change that resizes the box with it.
  ///
  /// Fixed rather than sized to content, so changing the data source does not
  /// reflow the whole map under the reader.
  static const nodeHeight =
      nodeHeaderHeight + nodeDataPadding * 2 + nodeDataRows * nodeDataRowHeight;

  /// The inventory triangle's drawn size.
  ///
  /// A buffer occupies the same slot as a process box so the spine stays
  /// evenly spaced, but it *draws* a small symbol — so the arrows either side
  /// must reach that symbol rather than the empty slot around it, or they
  /// stop short of nothing.
  static const bufferSymbol = 56.0;

  /// How far in from a buffer's slot the arrows should stop.
  static double get bufferInset => (nodeWidth - bufferSymbol) / 2;

  /// The supplier and customer factory symbols.
  static const endpointWidth = 104.0;
  static const endpointHeight = 52.0;

  /// Between nodes — wide enough for the connecting arrow and the insertion
  /// affordance that sits on it.
  static const gap = 64.0;

  static const marginLeft = 32.0;
  static const marginTop = 48.0;

  /// From the bottom of the boxes to the top of the sawtooth ladder.
  static const ladderOffset = 220.0;

  /// The ladder's two levels: process time on the lower step, waiting on the
  /// upper one, as a VSM draws it.
  static const ladderHeight = 44.0;

  static const bottomPadding = 96.0;
}

/// One laid-out element.
class PlacedNode {
  const PlacedNode({required this.view, required this.rect});

  final FlowNodeView view;
  final Rect rect;
}

/// An insertion point between two nodes — the `+ Insert here` affordance.
class InsertionPoint {
  const InsertionPoint({required this.position, required this.center});

  /// The position a new node would take (DESIGN.md §5.3).
  final int position;

  /// Centre of the gap, in canvas coordinates.
  final ({double x, double y}) center;
}

/// One rung of the lead-time ladder.
class LadderSegment {
  const LadderSegment({
    required this.rect,
    required this.duration,
    required this.isWaiting,
    this.referenceWorkingDay,
  });

  final Rect rect;
  final Duration duration;

  /// The working day this rung's `d` is measured in, so a 3-day takt reads
  /// `3.0 d` rather than being divided by a 24-hour day the plant never works.
  final Duration? referenceWorkingDay;

  /// Waiting rides high, process time low — the shape that makes a
  /// value-stream map readable at a glance.
  final bool isWaiting;
}

/// The whole laid-out map.
class FlowLayout {
  const FlowLayout({
    required this.supplier,
    required this.nodes,
    required this.customer,
    required this.insertionPoints,
    required this.ladder,
    required this.size,
  });

  final Rect supplier;
  final List<PlacedNode> nodes;
  final Rect customer;
  final List<InsertionPoint> insertionPoints;
  final List<LadderSegment> ladder;
  final Size size;

  /// The vertical centre line the connecting arrows run along.
  double get spineY => FlowMetrics.marginTop + FlowMetrics.nodeHeight / 2;
}

/// Lays [view] out left to right.
FlowLayout layoutFlow(FlowView view) {
  final nodes = <PlacedNode>[];
  final insertions = <InsertionPoint>[];
  final ladder = <LadderSegment>[];

  const top = FlowMetrics.marginTop;
  var x = FlowMetrics.marginLeft;

  final supplier = Rect.fromLTWH(
    x,
    top + (FlowMetrics.nodeHeight - FlowMetrics.endpointHeight) / 2,
    FlowMetrics.endpointWidth,
    FlowMetrics.endpointHeight,
  );
  x += FlowMetrics.endpointWidth + FlowMetrics.gap;

  for (var i = 0; i < view.nodes.length; i++) {
    // The insertion point before this node.
    insertions.add(
      InsertionPoint(
        position: i,
        center: (
          x: x - FlowMetrics.gap / 2,
          y: top + FlowMetrics.nodeHeight / 2,
        ),
      ),
    );

    nodes.add(
      PlacedNode(
        view: view.nodes[i],
        rect: Rect.fromLTWH(
          x,
          top,
          FlowMetrics.nodeWidth,
          FlowMetrics.nodeHeight,
        ),
      ),
    );
    x += FlowMetrics.nodeWidth + FlowMetrics.gap;
  }

  // And one after the last node, so a flow can be extended at the end.
  insertions.add(
    InsertionPoint(
      position: view.nodes.length,
      center: (x: x - FlowMetrics.gap / 2, y: top + FlowMetrics.nodeHeight / 2),
    ),
  );

  final customer = Rect.fromLTWH(
    x,
    top + (FlowMetrics.nodeHeight - FlowMetrics.endpointHeight) / 2,
    FlowMetrics.endpointWidth,
    FlowMetrics.endpointHeight,
  );
  final width = x + FlowMetrics.endpointWidth + FlowMetrics.marginLeft;

  // The ladder sits under the nodes, each rung **centred on its node** and
  // reaching half a gap either side.
  //
  // Half a gap, not a whole one: it keeps the rungs edge to edge — so the
  // sawtooth stays one continuous timeline — while putting each rung's midpoint
  // exactly under its node's midpoint. Spanning the node plus the *following*
  // gap, as this first did, shifts every rung half a gap right, and its label
  // then sits between two steps and reads as the wrong one's time.
  final ladderTop = top + FlowMetrics.nodeHeight + FlowMetrics.ladderOffset;
  for (final placed in nodes) {
    final isWaiting = placed.view is FlowInventoryView;
    ladder.add(
      LadderSegment(
        rect: Rect.fromLTWH(
          placed.rect.left - FlowMetrics.gap / 2,
          isWaiting ? ladderTop : ladderTop + FlowMetrics.ladderHeight,
          FlowMetrics.nodeWidth + FlowMetrics.gap,
          FlowMetrics.ladderHeight,
        ),
        duration: placed.view.ladderTime,
        isWaiting: isWaiting,
        referenceWorkingDay: placed.view.referenceWorkingDay,
      ),
    );
  }

  return FlowLayout(
    supplier: supplier,
    nodes: nodes,
    customer: customer,
    insertionPoints: insertions,
    ladder: ladder,
    size: Size(
      width,
      ladderTop + FlowMetrics.ladderHeight * 2 + FlowMetrics.bottomPadding,
    ),
  );
}
