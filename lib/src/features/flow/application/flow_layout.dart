/// Where everything sits on the map.
///
/// **Derived from the node sequence, never stored** (DESIGN.md §5.3). That is
/// what makes it impossible for the drawing, the lead-time ladder and the
/// routing to disagree: there is only one ordering, and this reads it.
///
/// Pure geometry in logical pixels — no widgets, so the layout can be asserted
/// in a test without pumping a frame.
library;

import 'dart:ui' show Offset, Rect, Size;

import 'package:vector_math/vector_math_64.dart' show Matrix4;

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

  /// The inventory triangle a queue's stock is drawn as, hanging under the
  /// connector it belongs to (§7.3).
  ///
  /// **Under the link rather than in a slot of its own.** A buffer used to take
  /// a whole `nodeWidth` on the spine and draw a small symbol in the middle of
  /// it; the queue is a property of the link now, so the triangle sits below
  /// the arrow and the spine holds nothing but process boxes.
  static const stockSymbol = 26.0;

  /// How far below the spine the stock triangle's top edge sits, clear of the
  /// connector's own shaft.
  static const stockOffset = 12.0;

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

  final FlowStepView view;
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

/// One straight run of the spine, and what it is drawn as.
class FlowConnection {
  const FlowConnection({
    required this.from,
    required this.to,
    required this.kind,
    this.queue,
  });

  final Offset from;
  final Offset to;
  final FlowConnectionKind kind;

  /// The queue this link runs into (§7.3), or null on the link into the
  /// customer — which is not a station and stands in front of no floor space.
  ///
  /// Carried here rather than looked up again by the canvas, because this is
  /// where [kind] was decided from it: the symbol and the row it is drawn for
  /// have to be the same queue, and the click that edits it lands on this
  /// segment.
  final FlowQueueView? queue;
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
    required this.connections,
    required this.ladder,
    required this.size,
  });

  final Rect supplier;
  final List<PlacedNode> nodes;
  final Rect customer;
  final List<InsertionPoint> insertionPoints;

  /// The arrows, in flow order. Computed here rather than in the canvas so the
  /// geometry **and** the kind of every link can be asserted without pumping a
  /// frame, which is the whole argument for this file.
  final List<FlowConnection> connections;

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

  final customer = Rect.fromLTWH(
    x,
    top + (FlowMetrics.nodeHeight - FlowMetrics.endpointHeight) / 2,
    FlowMetrics.endpointWidth,
    FlowMetrics.endpointHeight,
  );
  final width = x + FlowMetrics.endpointWidth + FlowMetrics.marginLeft;

  // The arrows, each one drawn as the queue it runs into (§7.3). Built before
  // the ladder because the ladder's waiting rungs sit over them.
  final connections = <FlowConnection>[];
  final spine = FlowMetrics.marginTop + FlowMetrics.nodeHeight / 2;
  final hasWipCap = view.study.wipCap != null;
  // A target already given a connection, so a station two steps of one flow
  // both visit draws — and charges the ladder for — one queue rather than two.
  final drawn = <String>{};
  var previousRight = Offset(supplier.right, spine);
  for (final placed in nodes) {
    final step = placed.view;
    final queue = step.queue;
    connections.add(
      FlowConnection(
        from: previousRight,
        to: Offset(placed.rect.left, spine),
        kind: connectionKindInto(step, hasWipCap: hasWipCap),
        queue: queue == null || !drawn.add(queue.targetId) ? null : queue,
      ),
    );
    previousRight = Offset(placed.rect.right, spine);
  }
  // Into the customer, which is not a station and so has no queue of its own.
  connections.add(
    FlowConnection(
      from: previousRight,
      to: Offset(customer.left, spine),
      kind: connectionKindInto(null, hasWipCap: hasWipCap),
    ),
  );

  // The ladder. A process rung sits **centred on its box** and reaches half a
  // gap either side; a waiting rung sits over the link it belongs to.
  //
  // Half a gap, not a whole one: it keeps the process rungs edge to edge — so
  // the sawtooth stays one continuous timeline — while putting each rung's
  // midpoint exactly under its box's midpoint. Spanning the box plus the
  // *following* gap, as this first did, shifts every rung half a gap right, and
  // its label then sits between two steps and reads as the wrong one's time.
  //
  // **A waiting rung is drawn only where something is standing**, which is what
  // keeps the sawtooth meaningful: a flow with no stock anywhere reads as one
  // flat low line rather than as a row of zero-height teeth. It overlays the
  // process rungs either side of it rather than displacing them, because a
  // queue takes no room on the spine.
  final ladderTop = top + FlowMetrics.nodeHeight + FlowMetrics.ladderOffset;
  for (var i = 0; i < nodes.length; i++) {
    final placed = nodes[i];
    if (connections[i].queue case final queue? when queue.hasStock) {
      ladder.add(
        LadderSegment(
          rect: Rect.fromLTWH(
            connections[i].from.dx,
            ladderTop,
            connections[i].to.dx - connections[i].from.dx,
            FlowMetrics.ladderHeight,
          ),
          duration: queue.wait,
          isWaiting: true,
          referenceWorkingDay: queue.rungWorkingDay,
        ),
      );
    }
    ladder.add(
      LadderSegment(
        rect: Rect.fromLTWH(
          placed.rect.left - FlowMetrics.gap / 2,
          ladderTop + FlowMetrics.ladderHeight,
          FlowMetrics.nodeWidth + FlowMetrics.gap,
          FlowMetrics.ladderHeight,
        ),
        duration: placed.view.ladderTime,
        isWaiting: false,
        referenceWorkingDay: placed.view.referenceWorkingDay,
      ),
    );
  }

  // `+ Insert here`, one per link — centred on **the arrow it sits on**, not on
  // the gap. Derived from the connection so there is one place the arrow's
  // extent is decided and this reads it; the two used to be able to drift apart
  // when a buffer inset one end of a segment.
  for (var i = 0; i < connections.length; i++) {
    insertions.add(
      InsertionPoint(
        position: i,
        center: (
          x: (connections[i].from.dx + connections[i].to.dx) / 2,
          y: spine,
        ),
      ),
    );
  }

  return FlowLayout(
    supplier: supplier,
    nodes: nodes,
    customer: customer,
    insertionPoints: insertions,
    connections: connections,
    ladder: ladder,
    size: Size(
      width,
      ladderTop + FlowMetrics.ladderHeight * 2 + FlowMetrics.bottomPadding,
    ),
  );
}

/// Whether the canvas should refit itself to [viewport] (DESIGN.md §12.2).
///
/// Two questions, both of which have to be yes.
///
/// **Has anything changed size?** The sidebar collapsing, the window being
/// resized or maximised, a step being added to the flow. [lastViewport] and
/// [lastContent] are what the previous fit was computed against, and comparing
/// against them is also what stops a fit from feeding itself: fitting calls
/// `setState`, which rebuilds, which asks this again — and at an unchanged size
/// the answer has to be no, or the canvas never stops fitting.
///
/// **Is the view still the one the last fit installed?** [fitted] is the matrix
/// the canvas put there and [current] is what the controller holds now. If they
/// differ the user has zoomed or panned since, and the view is theirs: a
/// sidebar toggle must not discard a deliberate zoom onto the sixth step, which
/// is the same complaint the canvas's own `_zoomBy` exists to answer. Pressing
/// Fit installs a new matrix and hands ownership back.
///
/// A null [fitted] is the first frame, when there is nothing to preserve.
bool shouldRefitCanvas({
  required Size viewport,
  required Size content,
  required Size? lastViewport,
  required Size? lastContent,
  required Matrix4? fitted,
  required Matrix4 current,
}) {
  if (!viewport.width.isFinite || viewport.width <= 0) return false;
  if (viewport == lastViewport && content == lastContent) return false;
  return fitted == null || current == fitted;
}
