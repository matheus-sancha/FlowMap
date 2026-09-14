import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../common/vector_pen.dart';
import '../application/flow_layout.dart';
import '../application/flow_view.dart';

/// The standard VSM symbols, drawn rather than imported.
///
/// A font or an image set would tie the map's look to an asset that cannot be
/// recoloured for a dark theme or re-rendered into a vector PDF. These are a
/// few dozen lines of geometry each and scale to any size.
///
/// **The PDF shares them now** (#27). For a long while it did not, though a
/// comment here claimed it did: `flow_pdf.dart` built its map out of bordered
/// boxes and glyphs, so its arrow was the character `>` and its inventory
/// triangles did not draw at all under the document's unembedded Helvetica.
/// Every shape here is traced through a `VectorPen`, and the canvas and the
/// PDF each supply one — so the two drawings of one map share their geometry.
abstract final class VsmSymbols {
  /// The factory: a rectangle under a three-tooth sawtooth roof. Supplier and
  /// customer are the same symbol; position on the map says which.
  static Path factory(Rect rect) {
    final pen = CanvasPen();
    traceFactory(pen, rect);
    return pen.path;
  }

  static void traceFactory(VectorPen pen, Rect rect) {
    final roofHeight = rect.height * 0.42;
    pen.rect(
      Rect.fromLTRB(rect.left, rect.top + roofHeight, rect.right, rect.bottom),
    );

    const teeth = 3;
    final toothWidth = rect.width / teeth;
    for (var i = 0; i < teeth; i++) {
      final left = rect.left + i * toothWidth;
      pen
        ..moveTo(Offset(left, rect.top + roofHeight))
        ..lineTo(Offset(left, rect.top + roofHeight * 0.35))
        ..lineTo(Offset(left + toothWidth, rect.top))
        ..lineTo(Offset(left + toothWidth, rect.top + roofHeight));
    }
  }

  /// The inventory triangle, point up, with room beneath for its count.
  static Path inventoryTriangle(Rect rect) {
    final pen = CanvasPen();
    traceInventoryTriangle(pen, rect);
    return pen.path;
  }

  static void traceInventoryTriangle(VectorPen pen, Rect rect) {
    final side = rect.width.clamp(0.0, rect.height);
    final centre = rect.center;
    final half = side / 2;
    pen
      ..moveTo(Offset(centre.dx, centre.dy - half))
      ..lineTo(Offset(centre.dx + half, centre.dy + half))
      ..lineTo(Offset(centre.dx - half, centre.dy + half))
      ..close();
  }

  /// A material-flow arrow, drawn as the [kind] it is (DESIGN.md §5.2, §7.3).
  ///
  /// **Push and pull share one shaft; a queue with a discipline is its own
  /// figure.** This file long said all three shared a shaft and were told apart
  /// by what went inside it, which was a principle invented to describe an
  /// implementation rather than the notation. A reader of a real value stream
  /// map recognises a FIFO lane as a channel, not as a decorated arrow, so it is
  /// drawn as one:
  ///
  /// * **push** — a broad barbed arrow spanning the gap, hatched. The stripes
  ///   *are* the mark of a push; a queue nobody has given a discipline is a
  ///   pile, and this is what one honestly is.
  /// * **pull** — the same shaft, bare. A CONWIP cap (§7.3) makes a release
  ///   wait for a completion, so nothing is being pushed anywhere.
  /// * **the four channels** — two rails with the rule's word between them, a
  ///   tick inside the entry and a solid triangle at the exit. Material enters
  ///   one end and leaves the other in an order the word names, which is what
  ///   the channel draws and what an arrow cannot.
  ///
  /// **One channel shape for all four rules, labelled.** The FIFO symbol
  /// already *is* a channel with `FIFO` written in it, so `LIFO`, `EDD` and
  /// `SPT` in the same channel extend the convention rather than inventing three
  /// glyphs — and nothing can be misread as a standard symbol meaning something
  /// else. _Rejected: a colour per rule._ Cheap and legible on screen, and §13's
  /// PDF on a shop-floor wall is often greyscale, where colour carrying meaning
  /// alone does not survive.
  ///
  /// Horizontal only, which the spine always is (§5.1). Taking the general case
  /// would mean rotating the hatching for no drawing this app makes.
  static void drawConnection(
    Canvas canvas,
    Offset from,
    Offset to, {
    required FlowConnectionKind kind,
    required Color color,
    double thickness = 11,
    double headLength = 13,
  }) => traceConnection(
    CanvasPen(canvas),
    from,
    to,
    kind: kind,
    color: color,
    thickness: thickness,
    headLength: headLength,
    label: (text, centre) =>
        _label(canvas, text, centre, color, centreVertically: true),
  );

  /// [drawConnection] through any pen. A channel's word is handed to [label]
  /// with the point it centres on, because text is the one thing each surface
  /// has to set in its own type.
  static void traceConnection(
    VectorPen pen,
    Offset from,
    Offset to, {
    required FlowConnectionKind kind,
    required Color color,
    required void Function(String text, Offset centre) label,
    double thickness = 11,
    double headLength = 13,
  }) {
    final span = to.dx - from.dx;
    if (span <= 1) return;

    // Not a variant of the shaft below, so it leaves before the shaft is built.
    if (kind.channelLabel case final word?) {
      _queueChannel(pen, from, to, word: word, color: color, label: label);
      return;
    }

    // A gap narrower than the head is all head: better a small arrowhead than
    // a shaft folded back on itself.
    final head = math.min(headLength, span);
    final shaftRight = to.dx - head;
    final half = thickness / 2;
    final barb = thickness * 0.42;

    pen
      ..moveTo(Offset(from.dx, from.dy - half))
      ..lineTo(Offset(shaftRight, from.dy - half))
      ..lineTo(Offset(shaftRight, from.dy - half - barb))
      ..lineTo(Offset(to.dx, from.dy))
      ..lineTo(Offset(shaftRight, from.dy + half + barb))
      ..lineTo(Offset(shaftRight, from.dy + half))
      ..lineTo(Offset(from.dx, from.dy + half))
      ..close()
      ..stroke(color, 1.1);

    if (shaftRight <= from.dx) return;

    if (kind == FlowConnectionKind.push) {
      // The stripes, clipped to the shaft so none escapes into the head. A pull
      // is the same shaft bare — nothing inside it is the whole point — and a
      // channel never reaches here.
      pen.clipRect(
        Rect.fromLTRB(from.dx, from.dy - half, shaftRight, from.dy + half),
      );
      final stripe = color.withValues(alpha: 0.45);
      for (var x = from.dx; x < shaftRight + thickness; x += 7) {
        pen.line(
          Offset(x, from.dy + half),
          Offset(x - thickness, from.dy - half),
          stripe,
          1,
        );
      }
      pen.restore();
    }
  }

  /// A queue channel: two rails, the rule's word between them, a tick in and a
  /// point out.
  ///
  /// The channel is what carries the meaning. Everything a disciplined queue
  /// needs to say is in the picture — a fixed width, so it holds a sequence
  /// rather than a pile; an entry and an exit that are different marks, so it
  /// has a direction; and the word, because a lane that is not labelled is just
  /// a line, and four rules share this one shape.
  ///
  /// Sized to fit the 64 px gap `FlowMetrics` leaves between nodes: the tick and
  /// the point take about 9 px each and a four-letter word at 8 pt takes about
  /// 22, so the three sit inside the narrowest gap the layout ever produces. A
  /// lane too short to hold them drops the label rather than overrunning its own
  /// rails.
  static void _queueChannel(
    VectorPen pen,
    Offset from,
    Offset to, {
    required String word,
    required Color color,
    required void Function(String text, Offset centre) label,
    double height = 18,
  }) {
    final half = height / 2;
    pen
      ..line(
        Offset(from.dx, from.dy - half),
        Offset(to.dx, from.dy - half),
        color,
        1.2,
      )
      ..line(
        Offset(from.dx, from.dy + half),
        Offset(to.dx, from.dy + half),
        color,
        1.2,
      );

    const mark = 9.0;
    final span = to.dx - from.dx;

    // Entry: a short bar, thicker than the rails so it reads as a mark on the
    // lane rather than as a rail that stopped early.
    pen.line(
      Offset(from.dx + 2, from.dy),
      Offset(from.dx + math.min(mark, span / 2), from.dy),
      color,
      2.4,
    );

    // Exit: a filled triangle. Solid rather than stroked, because it is the one
    // part of the figure that says which way the queue runs.
    final apex = to.dx - 2;
    final base = apex - math.min(mark - 2, span / 3);
    pen
      ..moveTo(Offset(apex, from.dy))
      ..lineTo(Offset(base, from.dy - 4))
      ..lineTo(Offset(base, from.dy + 4))
      ..close()
      ..fill(color);

    // Between the two marks, not between the rail ends, so the word stays
    // clear of both. Dropped entirely when the lane is too short to hold it.
    final inner = base - (from.dx + mark);
    if (inner >= 24) {
      label(word, Offset((from.dx + mark + base) / 2, from.dy));
    }
  }

  /// The pool badge: a stroked square carrying `#N` (DESIGN.md §3.1).
  ///
  /// A pool is several machines behind one box, and a reader comparing two
  /// boxes has to know which one is four workcenters. This was a Material chip —
  /// a filled, rounded, `secondaryContainer` pill sitting inside a map drawn in
  /// thin strokes, which read as a piece of app furniture rather than part of
  /// the drawing. Same stroke and colour as the factory and the triangle now,
  /// so it belongs to the same picture.
  static void drawPoolBadge(
    Canvas canvas,
    Rect rect,
    int count, {
    required Color color,
  }) {
    canvas.drawRect(
      rect,
      Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
    _label(
      canvas,
      '#$count',
      rect.center,
      color,
      size: 9,
      centreVertically: true,
    );
  }

  /// Small centred text above the shaft. A lane that is not labelled is just a
  /// line, and the label is what the notation actually carries.
  static void _label(
    Canvas canvas,
    String text,
    Offset centre,
    Color color, {
    double size = 8,
    bool centreVertically = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, letterSpacing: 0.3),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centre -
          Offset(painter.width / 2, centreVertically ? painter.height / 2 : 0),
    );
  }
}

/// Draws the arrows and the lead-time ladder behind the node widgets.
///
/// Nodes themselves are real widgets (DESIGN.md §12.2) so hover, tooltips,
/// focus and hit testing come from the framework; only the connective tissue is
/// painted, because none of it is interactive.
class FlowConnectionsPainter extends CustomPainter {
  const FlowConnectionsPainter({
    required this.connections,
    required this.color,
  });

  /// Straight runs of the spine, each already knowing what it is (§5.2).
  final List<FlowConnection> connections;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final connection in connections) {
      VsmSymbols.drawConnection(
        canvas,
        connection.from,
        connection.to,
        kind: connection.kind,
        color: color,
      );
    }
  }

  @override
  bool shouldRepaint(FlowConnectionsPainter old) =>
      old.connections != connections || old.color != color;
}

/// The sawtooth timeline under the map: waiting high, processing low.
class LeadTimeLadderPainter extends CustomPainter {
  const LeadTimeLadderPainter({required this.rungs, required this.color});

  /// One rectangle per rung, in flow order. Whether a rung is waiting time is
  /// already in its `top`: the layout puts waiting high and processing low, so
  /// a separate flag here would be a second way to say the same thing, and the
  /// two could disagree.
  final List<Rect> rungs;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (rungs.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    var started = false;
    Rect? previous;
    for (final rect in rungs) {
      if (!started) {
        path.moveTo(rect.left, rect.top);
        started = true;
      } else if (previous != null && previous.top != rect.top) {
        // The vertical riser between a waiting rung and a processing one.
        path
          ..lineTo(rect.left, previous.top)
          ..lineTo(rect.left, rect.top);
      }
      path.lineTo(rect.right, rect.top);
      previous = rect;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(LeadTimeLadderPainter old) =>
      old.rungs != rungs || old.color != color;
}
