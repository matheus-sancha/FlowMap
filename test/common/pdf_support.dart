import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flowmap/src/common/pdf_document.dart';
import 'package:pdf/widgets.dart' as pw;

/// The theme the app embeds, read off disk rather than out of the bundle.
pw.ThemeData testPdfTheme() {
  ByteData read(String name) =>
      ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync());
  return pdfThemeFrom(
    read('Roboto-Regular.ttf'),
    read('Roboto-Bold.ttf'),
    read('DejaVuSans.ttf'),
  );
}

/// Every Flate stream in [bytes], inflated.
///
/// **A PDF can be read back**, which `flow_pdf_test.dart` long said it could
/// not (#27). Inflating the streams is what found the `>` arrow, the undrawn
/// triangles and the dropped em dash — and it is what lets a test count the
/// path operators the symbols are made of.
List<String> contentStreams(Uint8List bytes) {
  final raw = latin1.decode(bytes);
  final streams = <String>[];
  final start = RegExp(r'stream\r?\n');
  var at = 0;
  while (true) {
    final match = start.firstMatch(raw.substring(at));
    if (match == null) break;
    final from = at + match.end;
    final to = raw.indexOf('endstream', from);
    if (to < 0) break;
    try {
      streams.add(
        latin1.decode(const ZLibDecoder().decodeBytes(bytes.sublist(from, to))),
      );
    } on Object {
      // Not Flate, or not a stream we can read — fonts and images, mostly.
    }
    at = to;
  }
  return streams;
}

/// How many times the path operator [op] appears across [streams].
int operatorCount(List<String> streams, String op) => streams
    .map(
      // Lookarounds, so `l l` counts twice rather than sharing its space.
      (s) => RegExp(
        '(?<=^|\\s)${RegExp.escape(op)}(?=\\s|\$)',
      ).allMatches(s).length,
    )
    .fold(0, (a, b) => a + b);
