import 'dart:typed_data';

import 'package:flutter/painting.dart' show Color, Size;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../app/flowmap_mark.dart';
import 'vector_pen.dart';

/// What every PDF FlowMap writes shares: an embedded font and one header (#27).

/// The embedded type, from bytes — which is what a test hands it.
///
/// **Embedded, always.** The VSM PDF used the `pdf` package's default, a
/// Helvetica declared under `WinAnsiEncoding` and not embedded, and it failed
/// silently: the em dash never reached the content stream, and the inventory
/// triangles did not draw. Accented Latin happened to survive, which is why the
/// trilingual text never showed the fault.
///
/// [fallback] carries what Roboto lacks and the app prints — `⇄`, the balanced
/// mark on a process box, and `→` — found by checking every rune of all three
/// ARB files against the font rather than by waiting for a page to lose one.
pw.ThemeData pdfThemeFrom(ByteData regular, ByteData bold, ByteData fallback) =>
    pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
      fontFallback: [pw.Font.ttf(fallback)],
    );

/// The embedded type, from the app's own assets.
Future<pw.ThemeData> loadPdfTheme() async => pdfThemeFrom(
  await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
);

/// The seed blue the mark's arrow is drawn in (#8).
const _seedBlue = Color(0xFF1F5C8B);

/// The mark, as vectors in the document (#33) — never a raster, because the
/// document holds none and a header image would be its first.
pw.Widget pdfMark({double height = 20}) => pw.SizedBox(
  width: height * FlowmapMark.aspect,
  height: height,
  child: pw.CustomPaint(
    size: PdfPoint(height * FlowmapMark.aspect, height),
    painter: (canvas, size) => FlowmapMarkPainter.trace(
      PdfPen(canvas, size.y),
      Size(size.x, size.y),
      barColor: const Color(0xFF161B23),
      arrowColor: _seedBlue,
    ),
  ),
);

/// The one header both PDFs carry: the mark, the title, and what it is of.
///
/// **One function, two callers** (#14): the VSM PDF and the simulation report
/// open the same way, so a reader holding either knows what they hold.
pw.Widget pdfHeader({required String title, required String subtitle}) =>
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pdfMark(),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10)),
      ],
    );

/// The build stamp every export carries (§13, #32), set small at the foot.
pw.Widget pdfStamp(String generated) => pw.Text(
  generated,
  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
);
