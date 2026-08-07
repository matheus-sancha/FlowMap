import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/flow_layout.dart';
import '../application/flow_view.dart';

/// The standard VSM symbols, drawn rather than imported.
///
/// A font or an image set would tie the map's look to an asset that cannot be
/// recoloured for a dark theme or re-rendered into a vector PDF. These are a
/// few dozen lines of geometry each and scale to any size.
///
/// **The PDF does not share them**, though a comment here long claimed it did.
/// `flow_pdf.dart` builds its map out of the `pdf` package's own widgets —
/// bordered boxes and glyphs — so that text stays selectable and the document
/// stays vector without this file's paths being replayed into it. Where a
/// distinction lives in a shape here, that file has to carry it another way,
/// and §5.2's arrow kinds are the first case: the canvas hatches a shaft, the
/// printed map writes the word.
abstract final class VsmSymbols {
  /// The factory: a rectangle under a three-tooth sawtooth roof. Supplier and
  /// customer are the same symbol; position on the map says which.
  static Path factory(Rect rect) {
    final roofHeight = rect.height * 0.42;
    final body = Rect.fromLTRB(
      rect.left,
      rect.top + roofHeight,
      rect.right,
      rect.bottom,
    );
    final path = Path()..addRect(body);

    const teeth = 3;
    final toothWidth = rect.width / teeth;
    for (var i = 0; i < teeth; i++) {
      final left = rect.left + i * toothWidth;
      path
        ..moveTo(left, rect.top + roofHeight)
        ..lineTo(left, rect.top + roofHeight * 0.35)
        ..lineTo(left + toothWidth, rect.top)
        ..lineTo(left + toothWidth, rect.top + roofHeight);
    }
    return path;
  }

  /// The inventory triangle, point up, with room beneath for its count.
  static Path inventoryTriangle(Rect rect) {
    final side = rect.width.clamp(0.0, rect.height);
    final centre = rect.center;
    final half = side / 2;
    return Path()
      ..moveTo(centre.dx, centre.dy - half)
      ..lineTo(centre.dx + half, centre.dy + half)
      ..lineTo(centre.dx - half, centre.dy + half)
      ..close();
  }

  /// A material-flow arrow, drawn as the [kind] it is (DESIGN.md §5.2).
  ///
  /// **Push and pull share one shaft; a FIFO lane is its own figure.** This
  /// file long said all three shared a shaft and were told apart by what went
  /// inside it, which was a principle invented to describe an implementation
  /// rather than the notation. A reader of a real value stream map recognises a
  /// FIFO lane as a channel, not as a decorated arrow, so it is drawn as one:
  ///
  /// * **push** — a broad barbed arrow spanning the gap, hatched. The stripes
  ///   *are* the mark of a push; without a supermarket in the model (§5.5) this
  ///   is what an uncapped flow honestly is.
  /// * **pull** — the same shaft, bare. A CONWIP cap (§7.3) makes a release
  ///   wait for a completion, so nothing is being pushed anywhere.
  /// * **fifoLane** — two rails with `FIFO` between them, a tick inside the
  ///   entry and a solid triangle at the exit. Material enters one end in the
  ///   order it arrived and leaves the other in that same order, which is what
  ///   the channel draws and what an arrow cannot.
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
  }) {
    final span = to.dx - from.dx;
    if (span <= 1) return;

    // Not a variant of the shaft below, so it leaves before the shaft is built.
    if (kind == FlowConnectionKind.fifoLane) {
      _fifoLane(canvas, from, to, color: color);
      return;
    }

    // A gap narrower than the head is all head: better a small arrowhead than
    // a shaft folded back on itself.
    final head = math.min(headLength, span);
    final shaftRight = to.dx - head;
    final half = thickness / 2;
    final barb = thickness * 0.42;

    final outline = Path()
      ..moveTo(from.dx, from.dy - half)
      ..lineTo(shaftRight, from.dy - half)
      ..lineTo(shaftRight, from.dy - half - barb)
      ..lineTo(to.dx, from.dy)
      ..lineTo(shaftRight, from.dy + half + barb)
      ..lineTo(shaftRight, from.dy + half)
      ..lineTo(from.dx, from.dy + half)
      ..close();

    canvas.drawPath(
      outline,
      Paint()
        ..color = color
        ..strokeWidth = 1.1
        ..style = PaintingStyle.stroke,
    );

    if (shaftRight <= from.dx) return;

    switch (kind) {
      case FlowConnectionKind.push:
        // The stripes, clipped to the shaft so none escapes into the head.
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(from.dx, from.dy - half, shaftRight, from.dy + half),
        );
        final stripe = Paint()
          ..color = color.withValues(alpha: 0.45)
          ..strokeWidth = 1;
        for (var x = from.dx; x < shaftRight + thickness; x += 7) {
          canvas.drawLine(
            Offset(x, from.dy + half),
            Offset(x - thickness, from.dy - half),
            stripe,
          );
        }
        canvas.restore();

      case FlowConnectionKind.pull:
        // Nothing inside it. A bare shaft is the whole point.
        break;

      case FlowConnectionKind.fifoLane:
        // Handled above — it is not this shape at all.
        break;
    }
  }

  /// The FIFO lane: two rails, `FIFO` between them, a tick in and a point out.
  ///
  /// The channel is what carries the meaning. Everything a queue in arrival
  /// order needs to say is in the picture — a fixed width, so it holds a
  /// sequence rather than a pile; an entry and an exit that are different marks,
  /// so it has a direction; and the word, because a lane that is not labelled
  /// is just a line.
  ///
  /// Sized to fit the 64 px gap `FlowMetrics` leaves between nodes: the tick and
  /// the point take about 9 px each and `FIFO` at 8 pt takes about 22, so the
  /// three sit inside the narrowest gap the layout ever produces. A lane too
  /// short to hold them drops the label rather than overrunning its own rails.
  static void _fifoLane(
    Canvas canvas,
    Offset from,
    Offset to, {
    required Color color,
    double height = 18,
  }) {
    final half = height / 2;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas
      ..drawLine(
        Offset(from.dx, from.dy - half),
        Offset(to.dx, from.dy - half),
        stroke,
      )
      ..drawLine(
        Offset(from.dx, from.dy + half),
        Offset(to.dx, from.dy + half),
        stroke,
      );

    const mark = 9.0;
    final span = to.dx - from.dx;

    // Entry: a short bar, thicker than the rails so it reads as a mark on the
    // lane rather than as a rail that stopped early.
    canvas.drawLine(
      Offset(from.dx + 2, from.dy),
      Offset(from.dx + math.min(mark, span / 2), from.dy),
      Paint()
        ..color = color
        ..strokeWidth = 2.4,
    );

    // Exit: a filled triangle. Solid rather than stroked, because it is the one
    // part of the figure that says which way the queue runs.
    final apex = to.dx - 2;
    final base = apex - math.min(mark - 2, span / 3);
    canvas.drawPath(
      Path()
        ..moveTo(apex, from.dy)
        ..lineTo(base, from.dy - 4)
        ..lineTo(base, from.dy + 4)
        ..close(),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    // Between the two marks, not between the rail ends, so the word stays
    // clear of both. Dropped entirely when the lane is too short to hold it.
    final inner = base - (from.dx + mark);
    if (inner >= 24) {
      _label(
        canvas,
        'FIFO',
        Offset((from.dx + mark + base) / 2, from.dy),
        color,
        centreVertically: true,
      );
    }
  }

  /// The pool badge: a stroked square carrying `#N` (DESIGN.md §3.1).
  ///
  /// A pool is several machines behind one box, and a reader comparing two
  /// boxes has to know which one is four stations. This was a Material chip —
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
    _label(canvas, '#$count', rect.center, color, size: 9, centreVertically: true);
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
          Offset(
            painter.width / 2,
            centreVertically ? painter.height / 2 : 0,
          ),
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
