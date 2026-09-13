import 'dart:io';
import 'dart:ui' as ui;

import 'package:flowmap/src/app/flowmap_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nothing in this suite renders a pixel — except here, deliberately.
///
/// A mark is geometry, and geometry is one of the few visual things a test can
/// actually hold down: that both bars and the arrow are present, that they are
/// separable at 16 px, and that the bars change with the theme while the arrow
/// does not. What it cannot say is whether it *looks* right.
void main() {
  /// Rasterises the painter and returns its pixels.
  Future<ui.Image> render(
    FlowmapMarkPainter painter, {
    required double height,
  }) async {
    final width = height * FlowmapMark.aspect;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, Size(width, height));
    return recorder.endRecording().toImage(width.ceil(), height.ceil());
  }

  Future<List<int>> pixelsOf(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List().toList();
  }

  /// How many pixels carry each ink.
  Future<({int bar, int arrow})> inkCounts(
    double height, {
    bool compact = false,
  }) async {
    const barColor = Color(0xFF000000);
    const arrowColor = Color(0xFFFF0000);
    final image = await render(
      const FlowmapMarkPainter(
        barColor: barColor,
        arrowColor: arrowColor,
      ).copyWithCompact(compact),
      height: height,
    );
    final pixels = await pixelsOf(image);

    var bar = 0;
    var arrow = 0;
    for (var i = 0; i < pixels.length; i += 4) {
      final r = pixels[i];
      final g = pixels[i + 1];
      final b = pixels[i + 2];
      final a = pixels[i + 3];
      if (a < 200) continue;
      if (r > 200 && g < 60 && b < 60) {
        arrow++;
      } else if (r < 60 && g < 60 && b < 60) {
        bar++;
      }
    }
    return (bar: bar, arrow: arrow);
  }

  test('both bars and the arrow are drawn', () async {
    final ink = await inkCounts(256);
    expect(ink.bar, greaterThan(0));
    expect(ink.arrow, greaterThan(0));
  });

  test('it survives 16 px, which is where a taskbar draws it', () async {
    // The size nobody checks and every Windows icon meets. A mark that works at
    // 256 and dissolves at 16 is the ordinary failure (#33).
    final ink = await inkCounts(16, compact: true);
    expect(ink.bar, greaterThan(8), reason: 'the bars vanished at 16 px');
    expect(ink.arrow, greaterThan(8), reason: 'the arrow vanished at 16 px');
  });

  test('the bars take the theme colour and the arrow does not', () async {
    // The supplied raster could not do this: its bars are #161B23 and vanish on
    // a dark ground. One source, two colourways.
    final light = await render(
      const FlowmapMarkPainter(
        barColor: Color(0xFF000000),
        arrowColor: Color(0xFF1F5C8B),
      ),
      height: 64,
    );
    final dark = await render(
      const FlowmapMarkPainter(
        barColor: Color(0xFFFFFFFF),
        arrowColor: Color(0xFF1F5C8B),
      ),
      height: 64,
    );

    final a = await pixelsOf(light);
    final b = await pixelsOf(dark);
    expect(a, isNot(equals(b)), reason: 'the bars did not follow the theme');

    // And the arrow is in both, unchanged.
    bool hasSeedBlue(List<int> px) {
      for (var i = 0; i < px.length; i += 4) {
        if (px[i + 3] > 200 &&
            (px[i] - 0x1F).abs() < 12 &&
            (px[i + 1] - 0x5C).abs() < 12 &&
            (px[i + 2] - 0x8B).abs() < 12) {
          return true;
        }
      }
      return false;
    }

    expect(hasSeedBlue(a), isTrue);
    expect(hasSeedBlue(b), isTrue);
  });

  test('the proportions are the reference\'s', () {
    // Measured from docs/brand/flowmap-mark-reference.png rather than eyeballed
    // — 656 × 566.
    expect(FlowmapMark.aspect, closeTo(1.159, 0.002));
  });

  test('the reference art is still in the repo', () {
    // The mark is traced from it, so losing it would mean the next change to
    // the geometry has nothing to check against.
    expect(
      File('docs/brand/flowmap-mark-reference.png').existsSync(),
      isTrue,
    );
  });
}

extension on FlowmapMarkPainter {
  FlowmapMarkPainter copyWithCompact(bool compact) => FlowmapMarkPainter(
    barColor: barColor,
    arrowColor: arrowColor,
    compact: compact,
  );
}
