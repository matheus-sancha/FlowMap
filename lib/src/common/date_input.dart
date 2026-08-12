/// Reading and writing the dates a user types (DESIGN.md §12.4).
///
/// Dates follow **the user's setting, defaulting to the locale**, and are stored
/// as local dates, because a shift calendar is inherently local. A need date is
/// a day, not an instant.
///
/// One [DateStyle] is passed rather than a locale and a setting separately: the
/// two are only ever useful together, and a call site holding one without the
/// other is a call site that can render a date the app did not choose. It is
/// also what lets the Excel export derive its number format from the same
/// object the screen renders with, so the file and the app cannot disagree
/// about what a date looks like.
library;

import 'package:intl/intl.dart';

/// How the user wants dates written.
///
/// **Independent of the UI language, deliberately.** English with Brazilian
/// dates is a real combination — it is what an expat planner or an English
/// screenshot of a Brazilian plant needs — and it is not reachable through a
/// language picker.
enum DateFormatSetting {
  /// Whatever the app's locale says, which is what the app did before there was
  /// a setting. The default, so an install that never visits Settings is
  /// unchanged.
  locale,

  dayMonthYear,
  monthDayYear,

  /// `yyyy-MM-dd`. Already accepted on input everywhere (see [DateStyle.parse]);
  /// this is what makes it available on output too.
  isoDate;

  /// What is stored in `app_settings`, and what an unknown value falls back to.
  ///
  /// Written by name rather than by index so that reordering this enum cannot
  /// silently change what an existing install reads back.
  static DateFormatSetting fromStored(String? stored) =>
      DateFormatSetting.values.firstWhere(
        (setting) => setting.name == stored,
        orElse: () => DateFormatSetting.locale,
      );
}

/// The locale and the chosen format, together.
class DateStyle {
  const DateStyle({
    required this.locale,
    this.setting = DateFormatSetting.locale,
  });

  final String locale;
  final DateFormatSetting setting;

  DateFormat get _format => switch (setting) {
    DateFormatSetting.locale => DateFormat.yMd(locale),
    // Four-digit years on every explicit choice. A user who has gone to
    // Settings to pin the format has said they care which way round it is, and
    // `03/08/26` is the reading that goes wrong.
    DateFormatSetting.dayMonthYear => DateFormat('dd/MM/yyyy', locale),
    DateFormatSetting.monthDayYear => DateFormat('MM/dd/yyyy', locale),
    DateFormatSetting.isoDate => DateFormat('yyyy-MM-dd', locale),
  };

  /// What a stored date reads back as.
  String format(DateTime? date) => date == null ? '' : _format.format(date);

  /// Parses a date in the app's own rendering, or in ISO `yyyy-MM-dd`.
  ///
  /// **ISO is accepted whatever the setting.** It is what a database export and
  /// half the spreadsheets in circulation produce, and it cannot be read two
  /// ways — unlike `03/08/2026`, which is two different days depending on who
  /// wrote it. The chosen form is tried second, so a user who has pinned
  /// `dd/MM/yyyy` still has `03/08/2026` mean 3 August.
  ///
  /// **This has to move with [format], and in the same commit.** The two are
  /// one contract: a display format changed on its own would make every date
  /// field reject what it had just shown.
  ///
  /// Returns null rather than throwing: this runs on every keystroke, and an
  /// unreadable date is something to show the user, not to crash on.
  DateTime? parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(text)) {
      final iso = DateTime.tryParse(text);
      if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    }

    try {
      final parsed = _format.parseStrict(text);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } on FormatException {
      // The locale's own rendering, for a user who has pinned a format their
      // habits have not caught up with yet. Nothing is lost by trying: a string
      // this reads is a date the app itself would have written a moment ago.
      if (setting == DateFormatSetting.locale) return null;
      try {
        final parsed = DateFormat.yMd(locale).parseStrict(text);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } on FormatException {
        return null;
      }
    }
  }

  /// The same format, written the way a spreadsheet spells it (§13.1).
  ///
  /// **Derived from [_format] rather than listed per setting**, so the file and
  /// the screen cannot come apart — including under [DateFormatSetting.locale],
  /// where the pattern is whatever `intl` decided for that locale and no table
  /// here could have known it.
  ///
  /// `intl` and Excel agree on `d` and `y` and disagree on the month: `M` there
  /// is `m` here, which Excel reads as a month rather than a minute because it
  /// sits beside a day and a year. Widths are normalised to two digits and four
  /// so that a locale's `M/d/y` does not reach a planner as `8/3/26`.
  String get excelPattern => (_format.pattern ?? 'yyyy-MM-dd')
      .replaceAll(RegExp('y+'), 'yyyy')
      .replaceAll(RegExp('M+'), 'mm')
      .replaceAll(RegExp('d+'), 'dd');

  // By value, so `DateStyleScope` can tell a real change from a rebuild and
  // not repaint every date in the app on each frame.
  @override
  bool operator ==(Object other) =>
      other is DateStyle && other.locale == locale && other.setting == setting;

  @override
  int get hashCode => Object.hash(locale, setting);
}
