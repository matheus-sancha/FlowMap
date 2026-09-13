@Tags(['tool'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flowmap/src/app/flowmap_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Writes `windows/runner/resources/app_icon.ico` from the mark's own geometry.
///
/// Run by hand when the mark changes:
///
/// ```
/// flutter test test/app/generate_app_icon_test.dart --tags tool
/// ```
///
/// **Not part of the suite**, because it writes a file into the repo and the
/// suite must not. It is a test only because the geometry can only be rasterised
/// inside a Flutter context — the same reason the PDF probe was one.
///
/// **The icon needs its own colourway, and this is where that is decided.** In
/// the app the bars take `onSurface` and follow the theme; an `.ico` cannot,
/// and the supplied artwork's near-black bars vanish on a dark Windows taskbar
/// — which is exactly what #33 found.
///
/// **A plateless icon was tried first and the measurement killed it.** Surviving
/// both a white and a near-black taskbar allows only mid-tones, and two
/// mid-tones cannot then differ from *each other*: slate bars against the
/// seed-blue arrow came out at **1.49:1**, which is mush rather than a mark.
///
/// So the icon sits on a plate and gets its own ground, which lets the
/// reference's own colours come back — near-black bars and the seed-blue arrow
/// on near-white. #33 rejected a plate once before, on the grounds that it read
/// as a white square at 16 px; that was the *supplied raster*, sitting too small
/// inside it. Drawn geometry is what lets the mark sit tight instead, and at a
/// 6 % inset all three elements are still separable at 16 px.
void main() {
  // **On a plate, and the numbers forced it.** A plateless icon must survive
  // both a white and a near-black taskbar, which allows only mid-tones — and
  // two mid-tones cannot then differ from *each other*: slate bars against the
  // seed-blue arrow measured **1.49:1**, so the mark turned to mush. The plate
  // gives the icon its own ground, and the reference's own colours come back.
  const plateColor = Color(0xFFF8FAFC);
  const barColor = Color(0xFF161B23);
  const arrowColor = Color(0xFF1F5C8B);

  /// Every size Windows reads out of one file. 16 is the title bar and the
  /// taskbar; 256 is the Explorer preview and the Start menu tile.
  const sizes = [256, 48, 32, 16];

  test('write app_icon.ico', () async {
    final pngs = <Uint8List>[];
    for (final size in sizes) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // The plate: a rounded square filling the icon, with the mark inset just
      // enough to breathe. **The inset is the whole argument** — the supplied
      // raster on a plate read as a white square at 16 px because it sat too
      // small inside it, and drawn geometry is what lets it sit tight instead.
      final d = size.toDouble();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, d, d),
          Radius.circular(d * 0.22),
        ),
        Paint()..color = plateColor,
      );

      const inset = 0.06;
      final markWidth = d * (1 - inset * 2);
      final markHeight = markWidth / FlowmapMark.aspect;
      canvas.translate(d * inset, (d - markHeight) / 2);
      FlowmapMarkPainter(
        barColor: barColor,
        arrowColor: arrowColor,
        compact: size < FlowmapMark.compactBelow,
      ).paint(canvas, Size(markWidth, markHeight));

      final image = await recorder.endRecording().toImage(size, size);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      pngs.add(data!.buffer.asUint8List());
    }

    final ico = _packIco(sizes, pngs);
    final file = File('windows/runner/resources/app_icon.ico');
    file.writeAsBytesSync(ico);

    // ignore: avoid_print
    print('wrote ${file.path} — ${sizes.join(', ')} px, ${ico.length} bytes');
    expect(file.lengthSync(), greaterThan(0));
  });
}

/// Packs PNGs into an `.ico`.
///
/// The format is a 6-byte directory header, one 16-byte entry per image, then
/// the images themselves. Entries may be PNG rather than BMP on Vista and
/// later, which is every Windows this ships to — and is why this is a few lines
/// rather than a bitmap encoder.
Uint8List _packIco(List<int> sizes, List<Uint8List> images) {
  final entries = BytesBuilder();
  final payload = BytesBuilder();
  var offset = 6 + images.length * 16;

  for (var i = 0; i < images.length; i++) {
    final png = images[i];
    final size = sizes[i];
    entries
      // 256 is written as 0: the field is one byte and 256 does not fit.
      ..addByte(size >= 256 ? 0 : size)
      ..addByte(size >= 256 ? 0 : size)
      ..addByte(0) // palette size, 0 for truecolour
      ..addByte(0) // reserved
      ..add(_u16(1)) // colour planes
      ..add(_u16(32)) // bits per pixel
      ..add(_u32(png.length))
      ..add(_u32(offset));
    payload.add(png);
    offset += png.length;
  }

  return Uint8List.fromList([
    ..._u16(0), // reserved
    ..._u16(1), // type: icon
    ..._u16(images.length),
    ...entries.takeBytes(),
    ...payload.takeBytes(),
  ]);
}

List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> _u32(int v) => [
  v & 0xFF,
  (v >> 8) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 24) & 0xFF,
];
