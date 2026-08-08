import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flowmap/src/features/demand/data/import_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reading a file into rows of text (DESIGN.md §9).
void main() {
  group('parseDelimited', () {
    test('reads a plain comma file', () {
      expect(parseDelimited('Part,CLAD04\nPN1,55:00:00\n'), [
        ['Part', 'CLAD04'],
        ['PN1', '55:00:00'],
      ]);
    });

    test('sniffs the semicolon a European Excel writes', () {
      // Asking the user which of their own punctuation marks they use is a
      // question the file already answers.
      expect(parseDelimited('Part;CLAD04\nPN1;55:00:00'), [
        ['Part', 'CLAD04'],
        ['PN1', '55:00:00'],
      ]);
    });

    test('keeps a comma inside a quoted field', () {
      expect(parseDelimited('Part,Description\nPN1,"Housing, upper"'), [
        ['Part', 'Description'],
        ['PN1', 'Housing, upper'],
      ]);
    });

    test('reads a doubled quote as one literal quote', () {
      expect(parseDelimited('a\n"say ""hi"""'), [
        ['a'],
        ['say "hi"'],
      ]);
    });

    test('keeps empty cells, which are how a skipped step arrives', () {
      expect(parseDelimited('a,b,c\nPN1,,8'), [
        ['a', 'b', 'c'],
        ['PN1', '', '8'],
      ]);
    });

    test('drops trailing blank lines', () {
      expect(parseDelimited('a,b\n1,2\n\n\n'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('a file of nothing is no rows at all', () {
      expect(parseDelimited(''), isEmpty);
      expect(parseDelimited('   \n  \n'), isEmpty);
    });
  });

  group('readImportFile', () {
    test('strips the BOM Excel writes on "CSV UTF-8"', () {
      final bytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode('Part,Desc\nPN1,Housing'),
      ]);
      final sheet = readImportFile('demand.csv', bytes).single;
      // Without this the first heading is `﻿Part` and matches nothing.
      expect(sheet.rows.first.first, 'Part');
    });

    test('falls back to Latin-1 rather than throwing on cp1252', () {
      // A CSV out of a German or Brazilian ERP is often still cp1252, and a
      // hard UTF-8 decode turns a row the user could fix into an exception.
      final bytes = Uint8List.fromList([
        ...utf8.encode('Part,Desc\nPN1,Geh'),
        0xE4, // 'ä' in cp1252, invalid on its own in UTF-8
        ...utf8.encode('use'),
      ]);
      final sheet = readImportFile('demand.csv', bytes).single;
      expect(sheet.rows.last.last, 'Gehäuse');
    });

    test('refuses a file type it cannot read', () {
      expect(
        () => readImportFile('demand.pdf', Uint8List(0)),
        throwsA(isA<ImportReadException>()),
      );
    });

    test('reads an xlsx, with dates as ISO and numbers as typed', () {
      final workbook = Excel.createExcel();
      final sheet = workbook[workbook.getDefaultSheet()!];
      sheet.appendRow([
        TextCellValue('Part'),
        TextCellValue('Need date'),
        TextCellValue('Batch'),
      ]);
      sheet.appendRow([
        TextCellValue('PN1'),
        DateCellValue(year: 2026, month: 8, day: 3),
        IntCellValue(4),
      ]);

      final read = readImportFile(
        'demand.xlsx',
        Uint8List.fromList(workbook.encode()!),
      ).firstWhere((s) => s.rows.length >= 2);

      // ISO, deliberately: a spreadsheet date has no locale of its own, and
      // guessing one is how 03/08 becomes the wrong day.
      expect(read.rows[1][1], '2026-08-03');
      expect(read.rows[1][2], '4');
    });
  });
}
