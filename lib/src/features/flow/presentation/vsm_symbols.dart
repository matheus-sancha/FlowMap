import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The standard VSM symbols, drawn rather than imported.
///
/// A font or an image set would tie the map's look to an asset that cannot be
/// recoloured for a dark theme or re-rendered into a vector PDF. These are a
/// few dozen lines of geometry each, scale to any size, and the PDF renderer
/// draws the same shapes from the same descriptions.
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

  /// A push arrow: the striped shaft of a material flow that is not pulled.
  static void drawArrow(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    double headSize = 7,
  }) {
    canvas.drawLine(from, to, paint);
    final direction = (to - from).direction;
    final head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - headSize * 1.6 * _cos(direction - 0.4),
        to.dy - headSize * 1.6 * _sin(direction - 0.4),
      )
      ..lineTo(
        to.dx - headSize * 1.6 * _cos(direction + 0.4),
        to.dy - headSize * 1.6 * _sin(direction + 0.4),
      )
      ..close();
    canvas.drawPath(head, Paint()..color = paint.color);
  }

  static double _cos(double radians) => math.cos(radians);
  static double _sin(double radians) => math.sin(radians);
}

/// Draws the arrows and the lead-time ladder behind the node widgets.
///
/// Nodes themselves are real widgets (DESIGN.md §12.2) so hover, tooltips,
/// focus and hit testing come from the framework; only the connective tissue is
/// painted, because none of it is interactive.
class FlowConnectionsPainter extends CustomPainter {
  const FlowConnectionsPainter({required this.segments, required this.color});

  /// Straight runs of the spine, as (from, to) pairs.
  final List<(Offset, Offset)> segments;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final (from, to) in segments) {
      VsmSymbols.drawArrow(canvas, from, to, paint);
    }
  }

  @override
  bool shouldRepaint(FlowConnectionsPainter old) =>
      old.segments != segments || old.color != color;
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
