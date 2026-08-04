/// Reading and writing the dates a user types into a grid (DESIGN.md §12.4).
///
/// Dates render per app locale — `dd/MM/yyyy` under pt and es — and are stored
/// as local dates, because a shift calendar is inherently local. A need date is
/// a day, not an instant.
library;

import 'package:intl/intl.dart';

/// Parses a date in the app's own rendering, or in ISO `yyyy-MM-dd`.
///
/// **ISO is accepted everywhere, whatever the locale.** It is what a database
/// export and half the spreadsheets in circulation produce, and it cannot be
/// read two ways — unlike `03/08/2026`, which is two different days depending
/// on who wrote it. The locale form is tried second so a Brazilian user's
/// `03/08/2026` still means 3 August.
///
/// Returns null rather than throwing: this runs on every keystroke, and an
/// unreadable date is something to show the user, not to crash on.
DateTime? parseDateInput(String input, String locale) {
  final text = input.trim();
  if (text.isEmpty) return null;

  if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(text)) {
    final iso = DateTime.tryParse(text);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
  }

  try {
    final parsed = DateFormat.yMd(locale).parseStrict(text);
    return DateTime(parsed.year, parsed.month, parsed.day);
  } on FormatException {
    return null;
  }
}

/// What a stored date reads back as, in the app's locale.
String formatDateInput(DateTime? date, String locale) =>
    date == null ? '' : DateFormat.yMd(locale).format(date);
