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

  /// The name printed under an endpoint's factory symbol.
  ///
  /// Here rather than as a literal in the canvas because the end stock's
  /// triangle hangs below it (§7.3), and two files guessing at the same offset
  /// is how a symbol comes to overlap the label it sits under.
  static const endpointLabelHeight = 24.0;

  /// A link that carries a queue — every link on the spine except the last.
  ///
  /// **The same width as a process box**, and that is the whole point: the
  /// lead-time ladder puts one rung over each link and one under each box, so
  /// equal slots make equal rungs. It also buys the queue room for its name and
  /// its capacity, which `FIFO COATING · max 2` does not fit into 64 px — the
  /// first build of §7.3 drew them into the gap below and they truncated to
  /// `FIFO COA…`.
  ///
  /// _Rejected: sizing the ladder independently of the map._ Rungs could then be
  /// equal at any gap width, but a rung that does not sit under the box or the
  /// link it measures reads as the wrong one's time — which is the rule the
  /// process rungs have been placed by since they were first drawn.
  static const queueSlot = nodeWidth;

  /// The one link that carries no queue: into the customer, which is not a
  /// station. Narrow, because there is nothing to put there — the flow's
  /// outbound stock is §7.3's own open item and is not a queue when it lands.
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

/// Stock at one end of the flow, and where its triangle sits (§7.3).
///
/// **Under its endpoint, not on a link.** A queue's triangle hangs below the
/// arrow it belongs to; these belong to the supplier and customer symbols
/// instead, which keeps the inbound pile clear of the first step's own queue —
/// two different piles that would otherwise land on the same link and read as
/// one.
class PlacedEndStock {
  const PlacedEndStock({required this.view, required this.rect});

  final FlowEndStockView view;

  /// The triangle's box, centred under the endpoint it belongs to.
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

/// Where a step dragged from [from] lands when it is dropped in the gap
/// [gap], in the terms `StudiesRepository.moveNode` takes — or **null when the
/// drop changes nothing** (§8.4).
///
/// **The two indices count different things**, which is the whole reason this
/// is a function rather than a subtraction at the call site. An
/// [InsertionPoint.position] is a gap in the list *as drawn*: five steps have
/// six gaps, and gap 5 is past the end. `moveNode`'s `to` is an index in the
/// list *after the dragged step has been taken out of it*, because that is what
/// `insert(to, removeAt(from))` means. So every gap to the right of the step
/// being dragged is one place further left than it looks.
///
/// **Two gaps are no-ops and both have to be caught here.** The gap immediately
/// before a step and the one immediately after it are where that step already
/// is; dropping into either should leave the map alone rather than write a
/// reorder that renumbers every node and touches the study for nothing.
int? dropTarget({required int from, required int gap}) {
  if (gap == from || gap == from + 1) return null;
  return gap > from ? gap - 1 : gap;
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
    this.inboundStock,
    this.outboundStock,
  });

  final Rect supplier;
  final List<PlacedNode> nodes;
  final Rect customer;

  /// The two end piles, or null where the study records none (§7.3).
  final PlacedEndStock? inboundStock;
  final PlacedEndStock? outboundStock;
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
  // Every link runs into a step and carries that step's queue — except the last
  // one, which runs into the customer. An empty flow is only that last link.
  x +=
      FlowMetrics.endpointWidth +
      (view.nodes.isEmpty ? FlowMetrics.gap : FlowMetrics.queueSlot);

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
    x +=
        FlowMetrics.nodeWidth +
        (i == view.nodes.length - 1
            ? FlowMetrics.gap
            : FlowMetrics.queueSlot);
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

  // The ladder: **one rung per link and one per box, strictly alternating and
  // all the same width**, because a link is a slot as wide as a box.
  //
  // Each rung is exactly the thing it measures — a queue rung spans its link, a
  // process rung spans its box — so no label can sit under something it does
  // not describe, and they tile edge to edge with nothing overlapping. The first
  // build of this overlapped them by half a gap, and `LeadTimeLadderPainter`
  // draws its riser at each rung's `left`: the path therefore doubled back 32 px
  // at every queue, which is what made the teeth stubby and misplaced.
  //
  // **A waiting rung is drawn even when it is zero.** Alternation is what makes
  // the comb regular, and a queue that holds nothing has a real answer — no time
  // is spent there — rather than no answer.
  //
  // A link whose queue is null contributes zero: an unbound step has no floor
  // space in front of it, and the *second* link into a station a flow visits
  // twice has already been counted at the first (`FlowConnection.queue` is null
  // there). That is what keeps the rungs summing to the footer's lead time,
  // which is §17.4's rule and the reason the totals are read off the rungs.
  final ladderTop = top + FlowMetrics.nodeHeight + FlowMetrics.ladderOffset;

  // **The ends get a rung each, over their own endpoint** (§7.3), so the comb
  // still tiles edge to edge and every rung still sits under the thing it
  // measures. They are the two rungs that are *not* drawn when there is nothing
  // to draw: a queue rung is always present because alternation is what makes
  // the comb regular, but an endpoint has no box after it to alternate with,
  // and a study that has never been asked about its ends should look exactly as
  // it did before this existed (§5.2 — the map draws decisions).
  if (view.inbound case final stock?) {
    ladder.add(
      LadderSegment(
        rect: Rect.fromLTWH(
          supplier.left,
          ladderTop,
          FlowMetrics.endpointWidth,
          FlowMetrics.ladderHeight,
        ),
        duration: stock.wait,
        isWaiting: true,
        referenceWorkingDay: stock.rungWorkingDay,
      ),
    );
  }
  for (var i = 0; i < nodes.length; i++) {
    final placed = nodes[i];
    final queue = connections[i].queue;
    ladder.add(
      LadderSegment(
        rect: Rect.fromLTWH(
          connections[i].from.dx,
          ladderTop,
          connections[i].to.dx - connections[i].from.dx,
          FlowMetrics.ladderHeight,
        ),
        duration: queue?.wait ?? Duration.zero,
        isWaiting: true,
        referenceWorkingDay: queue?.rungWorkingDay,
      ),
    );
    ladder.add(
      LadderSegment(
        rect: Rect.fromLTWH(
          placed.rect.left,
          ladderTop + FlowMetrics.ladderHeight,
          FlowMetrics.nodeWidth,
          FlowMetrics.ladderHeight,
        ),
        duration: placed.view.ladderTime,
        isWaiting: false,
        referenceWorkingDay: placed.view.referenceWorkingDay,
      ),
    );
  }
  if (view.outbound case final stock?) {
    ladder.add(
      LadderSegment(
        rect: Rect.fromLTWH(
          customer.left,
          ladderTop,
          FlowMetrics.endpointWidth,
          FlowMetrics.ladderHeight,
        ),
        duration: stock.wait,
        isWaiting: true,
        referenceWorkingDay: stock.rungWorkingDay,
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
    inboundStock: _placeEndStock(view.inbound, supplier),
    outboundStock: _placeEndStock(view.outbound, customer),
    insertionPoints: insertions,
    connections: connections,
    ladder: ladder,
    size: Size(
      width,
      ladderTop + FlowMetrics.ladderHeight * 2 + FlowMetrics.bottomPadding,
    ),
  );
}

/// Centres an end pile's triangle under the endpoint it belongs to.
///
/// Below the symbol rather than beside it, so a long supplier name and a wide
/// pile do not compete for the same horizontal room — and so the triangle sits
/// at the same depth as the queue triangles that hang below the spine, which is
/// what makes the row of them read as one kind of thing.
PlacedEndStock? _placeEndStock(FlowEndStockView? view, Rect endpoint) =>
    view == null
    ? null
    : PlacedEndStock(
        view: view,
        rect: Rect.fromLTWH(
          endpoint.center.dx - FlowMetrics.stockSymbol / 2,
          endpoint.bottom +
              FlowMetrics.endpointLabelHeight +
              FlowMetrics.stockOffset,
          FlowMetrics.stockSymbol,
          FlowMetrics.stockSymbol,
        ),
      );

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
