/// Reading a `.xlsx` or `.csv` into rows of text (DESIGN.md §9).
///
/// In `data/` rather than `application/` because it is the boundary with the
/// outside world: everything above it works on `List<List<String>>` and never
/// learns what a workbook is.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

/// One sheet of a file, as text.
class ImportSheet {
  const ImportSheet({required this.name, required this.rows});

  final String name;

  /// Rows of cells, ragged: a short row is short, not padded. Callers read by
  /// index and treat a missing cell as blank.
  final List<List<String>> rows;

  bool get isEmpty => rows.isEmpty;
}

/// Thrown when a file cannot be read at all — as opposed to a row that cannot
/// be validated, which is the preview's business.
class ImportReadException implements Exception {
  const ImportReadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads [bytes] according to [fileName]'s extension.
List<ImportSheet> readImportFile(String fileName, Uint8List bytes) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.csv') || lower.endsWith('.txt')) {
    return [ImportSheet(name: fileName, rows: parseDelimited(_decode(bytes)))];
  }
  if (lower.endsWith('.xlsx')) return _readWorkbook(bytes);
  throw const ImportReadException('Unsupported file type');
}

/// Decodes bytes as UTF-8, falling back to Latin-1.
///
/// A CSV exported from a German or Brazilian ERP is often still cp1252, and a
/// hard UTF-8 decode turns `Gehäuse` into an exception rather than a row the
/// user can see and fix.
String _decode(Uint8List bytes) {
  // A BOM, which Excel writes on "CSV UTF-8", is not part of the first field.
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

List<ImportSheet> _readWorkbook(Uint8List bytes) {
  final Excel workbook;
  try {
    workbook = Excel.decodeBytes(bytes);
  } on Object catch (error) {
    throw ImportReadException('$error');
  }

  return [
    for (final entry in workbook.tables.entries)
      ImportSheet(
        name: entry.key,
        rows: [
          for (final row in entry.value.rows)
            [for (final cell in row) _cellText(cell?.value)],
        ],
      ),
  ];
}

/// A cell as the text the user would have typed.
///
/// **Dates come back as dates, and are rendered ISO**, which `parseDateInput`
/// reads in every locale — a spreadsheet date has no locale of its own, and
/// guessing one is how `03/08` becomes the wrong day.
String _cellText(CellValue? value) => switch (value) {
  null => '',
  TextCellValue() => value.value.text ?? '',
  IntCellValue() => '${value.value}',
  DoubleCellValue() => _trimZeros(value.value),
  BoolCellValue() => value.value ? 'true' : 'false',
  DateCellValue() =>
    '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}',
  DateTimeCellValue() =>
    '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}',
  // `07:30:00` — which is what a process time typed into Excel as a duration
  // arrives as, and exactly what `parseDurationInput` reads.
  TimeCellValue() =>
    '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}',
  FormulaCellValue() => value.formula,
};

String _trimZeros(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : '$value';

/// Parses delimited text — CSV proper, with quoted fields.
///
/// The delimiter is **sniffed** from the header line: a European Excel writes
/// `;` where an American one writes `,`, and asking the user which of their own
/// punctuation marks they use is a question the file already answers.
List<List<String>> parseDelimited(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (normalized.trim().isEmpty) return const [];

  final delimiter = _sniffDelimiter(normalized.split('\n').first);

  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;

  for (var i = 0; i < normalized.length; i++) {
    final char = normalized[i];

    if (quoted) {
      if (char == '"') {
        // A doubled quote inside a quoted field is one literal quote.
        if (i + 1 < normalized.length && normalized[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(char);
      }
      continue;
    }

    if (char == '"' && field.isEmpty) {
      quoted = true;
    } else if (char == delimiter) {
      row.add(field.toString());
      field.clear();
    } else if (char == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(char);
    }
  }

  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }

  // A trailing newline leaves one empty row; a file of nothing but blank lines
  // leaves several.
  while (rows.isNotEmpty &&
      rows.last.every((cell) => cell.trim().isEmpty)) {
    rows.removeLast();
  }
  return rows;
}

String _sniffDelimiter(String headerLine) {
  var best = ',';
  var bestCount = 0;
  for (final candidate in [',', ';', '\t', '|']) {
    final count = candidate.allMatches(headerLine).length;
    if (count > bestCount) {
      best = candidate;
      bestCount = count;
    }
  }
  return best;
}
