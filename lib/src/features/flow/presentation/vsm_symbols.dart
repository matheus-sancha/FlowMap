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
  /// All three share one shaft — a broad arrow spanning the whole gap between
  /// two nodes rather than a hairline, which is the VSM convention: material
  /// moving is a substantial thing on the map. What tells them apart is what
  /// the notation itself uses:
  ///
  /// * **push** — the shaft is hatched. The stripes *are* the mark of a push;
  ///   without a supermarket in the model (§5.5) this is what an uncapped flow
  ///   honestly is.
  /// * **pull** — the same shaft, bare. A CONWIP cap (§7.3) makes a release
  ///   wait for a completion, so nothing is being pushed anywhere.
  /// * **fifoLane** — a bare shaft with a divider down it and `FIFO` written
  ///   above, which is how a sequenced lane is labelled on a real map.
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
        canvas.drawLine(
          Offset(from.dx, from.dy),
          Offset(shaftRight, from.dy),
          Paint()
            ..color = color.withValues(alpha: 0.45)
            ..strokeWidth = 0.8,
        );
        _label(canvas, 'FIFO', Offset((from.dx + to.dx) / 2, from.dy - half - 11), color);
    }
  }

  /// Small centred text above the shaft. A lane that is not labelled is just a
  /// line, and the label is what the notation actually carries.
  static void _label(Canvas canvas, String text, Offset centre, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 8, letterSpacing: 0.3),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, centre - Offset(painter.width / 2, 0));
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
