import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';

/// Where a drawing goes, so one geometry can reach two surfaces (#27).
///
/// The VSM symbols and the mark are a few dozen lines of geometry each, and
/// they were drawn twice: on the canvas as paths, and in the PDF as whatever
/// the `pdf` package's widgets could approximate — a bordered box for a
/// factory, the character `>` for an arrow, and `▽`/`▲` glyphs that the
/// document's unembedded Helvetica **could not draw at all**. Tracing through a
/// pen lets both surfaces replay the same moves, so the printed map and the
/// screen cannot drift apart in shape — #14's *one function, two callers*.
///
/// Coordinates are the canvas's: origin top-left, y down. [PdfPen] flips them.
///
/// _Rejected: rasterising the canvas into the PDF._ Reverses §13's vector
/// choice, and it is the image-asset approach `vsm_symbols.dart` rejects in its
/// first paragraph.
abstract class VectorPen {
  void moveTo(Offset point);
  void lineTo(Offset point);
  void quadTo(Offset control, Offset point);
  void close();
  void rect(Rect rect);
  void rrect(Rect rect, double radius);

  /// Fills the current path with [color], then starts a new one.
  void fill(Color color);

  /// Strokes the current path with [color] at [width], then starts a new one.
  void stroke(Color color, double width);

  /// Saves the state, clips to [rect]; undone by [restore].
  void clipRect(Rect rect);
  void restore();

  /// One straight stroke — the common case, spelled once.
  void line(Offset from, Offset to, Color color, double width) {
    moveTo(from);
    lineTo(to);
    stroke(color, width);
  }
}

/// Collects moves into a [Path], and paints it when a [canvas] is given.
///
/// Without a canvas it is how a widget that owns its own paint asks for the
/// shape alone (`VsmSymbols.factory`).
class CanvasPen extends VectorPen {
  CanvasPen([this.canvas]);

  final Canvas? canvas;
  Path path = Path();

  @override
  void moveTo(Offset point) => path.moveTo(point.dx, point.dy);
  @override
  void lineTo(Offset point) => path.lineTo(point.dx, point.dy);
  @override
  void quadTo(Offset control, Offset point) =>
      path.quadraticBezierTo(control.dx, control.dy, point.dx, point.dy);
  @override
  void close() => path.close();
  @override
  void rect(Rect rect) => path.addRect(rect);
  @override
  void rrect(Rect rect, double radius) =>
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

  @override
  void fill(Color color) {
    canvas?.drawPath(path, Paint()..color = color);
    path = Path();
  }

  @override
  void stroke(Color color, double width) {
    canvas?.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke,
    );
    path = Path();
  }

  @override
  void clipRect(Rect rect) {
    canvas
      ?..save()
      ..clipRect(rect);
  }

  @override
  void restore() => canvas?.restore();
}

/// Replays the moves into a PDF content stream, as vectors.
///
/// Built for `pw.CustomPaint`, whose origin is the box's **bottom**-left with y
/// up — so every y is flipped against [height].
class PdfPen extends VectorPen {
  PdfPen(this.graphics, this.height);

  final PdfGraphics graphics;
  final double height;
  Offset _current = Offset.zero;

  double _y(double y) => height - y;

  @override
  void moveTo(Offset point) {
    graphics.moveTo(point.dx, _y(point.dy));
    _current = point;
  }

  @override
  void lineTo(Offset point) {
    graphics.lineTo(point.dx, _y(point.dy));
    _current = point;
  }

  /// PDF has cubics only; a quadratic is the cubic with both controls two
  /// thirds of the way to its one.
  @override
  void quadTo(Offset control, Offset point) {
    final c1 = _current + (control - _current) * (2 / 3);
    final c2 = point + (control - point) * (2 / 3);
    graphics.curveTo(
      c1.dx,
      _y(c1.dy),
      c2.dx,
      _y(c2.dy),
      point.dx,
      _y(point.dy),
    );
    _current = point;
  }

  @override
  void close() => graphics.closePath();

  @override
  void rect(Rect rect) =>
      graphics.drawRect(rect.left, _y(rect.bottom), rect.width, rect.height);

  @override
  void rrect(Rect rect, double radius) => graphics.drawRRect(
    rect.left,
    _y(rect.bottom),
    rect.width,
    rect.height,
    radius,
    radius,
  );

  @override
  void fill(Color color) {
    graphics
      ..setFillColor(_pdfColor(color))
      ..fillPath();
  }

  @override
  void stroke(Color color, double width) {
    graphics
      ..setStrokeColor(_pdfColor(color))
      ..setLineWidth(width)
      ..strokePath();
  }

  @override
  void clipRect(Rect rect) {
    graphics
      ..saveContext()
      ..drawRect(rect.left, _y(rect.bottom), rect.width, rect.height)
      ..clipPath();
  }

  @override
  void restore() => graphics.restoreContext();

  /// **Translucency is blended against white**, because paper is white and a
  /// graphic-state opacity per stroke is a lot of document for a hatch line.
  static PdfColor _pdfColor(Color color) {
    final a = color.a;
    double mix(double channel) => channel * a + (1 - a);
    return PdfColor(mix(color.r), mix(color.g), mix(color.b));
  }
}
