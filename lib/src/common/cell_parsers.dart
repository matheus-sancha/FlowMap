/// What a typed cell accepts, for the grids the schedules are entered in
/// (DESIGN.md §9.2, §12.6).
///
/// **Forgiving in, canonical out.** A cell takes anything unambiguous and is
/// redisplayed in one form once committed, so a block pasted out of a
/// spreadsheet lands and the table still reads consistently afterwards. That is
/// what `DataGrid` is for: every column is text precisely so a paste from Excel
/// works, and what a cell *means* is decided by the parser its caller supplies.
///
/// **Forgiving is not guessing.** §9.2 refuses to place an import column by
/// position and refuses an ambiguous header rather than assuming — the same rule
/// here means anything genuinely ambiguous is rejected and left on screen as an
/// error, never quietly reinterpreted. Writing a lot number into a quantity is
/// §11's one intolerable class of bug and it arrives this way too.
library;

import '../data/database/enums.dart';

/// Every spelling of a [TaktUnit] this app will accept, in all three of its
/// languages plus the abbreviations a planner actually types.
///
/// **Language-independent on purpose.** A Portuguese user pasting a block out of
/// an English spreadsheet is the case paste exists for, so the parser accepts
/// every language's word regardless of which one the UI is in. Only the
/// *display* follows the UI language (`taktUnitLabel`).
const _taktUnitWords = <String, TaktUnit>{
  'd': TaktUnit.days,
  'day': TaktUnit.days,
  'days': TaktUnit.days,
  'dia': TaktUnit.days,
  'dias': TaktUnit.days,
  'día': TaktUnit.days,
  'días': TaktUnit.days,
  'h': TaktUnit.hours,
  'hr': TaktUnit.hours,
  'hrs': TaktUnit.hours,
  'hour': TaktUnit.hours,
  'hours': TaktUnit.hours,
  'hora': TaktUnit.hours,
  'horas': TaktUnit.hours,
  'm': TaktUnit.minutes,
  'min': TaktUnit.minutes,
  'mins': TaktUnit.minutes,
  'minute': TaktUnit.minutes,
  'minutes': TaktUnit.minutes,
  'minuto': TaktUnit.minutes,
  'minutos': TaktUnit.minutes,
  's': TaktUnit.seconds,
  'sec': TaktUnit.seconds,
  'secs': TaktUnit.seconds,
  'second': TaktUnit.seconds,
  'seconds': TaktUnit.seconds,
  'segundo': TaktUnit.seconds,
  'segundos': TaktUnit.seconds,
};

/// The unit [input] names, or null when it names none.
///
/// Case- and accent-tolerant, so `Días`, `dias` and `DIAS` are one answer —
/// which matters because a Spanish keyboard is not a given on the shop floor.
TaktUnit? parseTaktUnit(String input) {
  final text = input.trim().toLowerCase();
  if (text.isEmpty) return null;
  return _taktUnitWords[text] ?? _taktUnitWords[_stripAccents(text)];
}

String _stripAccents(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final index = from.indexOf(String.fromCharCode(rune));
    buffer.write(index < 0 ? String.fromCharCode(rune) : to[index]);
  }
  return buffer.toString();
}

/// A fraction between 0 and 1, from `74%`, `74` or `0.74`.
///
/// **All three are unambiguous, which is why all three are taken.** The ranges
/// do not overlap in any way that matters: a plant running at 0.74 % is not a
/// case worth reserving syntax for, and one running at 74 % is the common one.
/// So a value at or below 1 is read as a fraction and anything above it as a
/// percentage — with `1` itself meaning 100 %, since a station at 1 % is not
/// what anyone means either.
///
/// A comma is a decimal point. Both other languages write `0,74`, and rejecting
/// it would make the parser wrong in two of the three locales this app ships in.
///
/// Null when it is not a number, or lands outside 0…100 %.
double? parseFraction(String input) {
  var text = input.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  final hadSign = text.endsWith('%');
  if (hadSign) text = text.substring(0, text.length - 1).trim();

  final value = double.tryParse(text);
  if (value == null || value < 0) return null;

  // An explicit sign says what it is and is believed: `0.5%` is half a percent,
  // however unlikely, because the user wrote the symbol.
  final fraction = hadSign ? value / 100 : (value <= 1 ? value : value / 100);
  return fraction > 1 ? null : fraction;
}

/// A fraction as the grid redisplays it: `74 %`, `3.7 %`.
///
/// One decimal only when it has one, so a whole percentage does not read as
/// `74.0 %` in a column being scanned for the odd one out.
String formatFraction(double fraction) {
  final percent = fraction * 100;
  final rounded = double.parse(percent.toStringAsFixed(1));
  return rounded == rounded.roundToDouble()
      ? '${rounded.round()} %'
      : '$rounded %';
}

/// A positive number, with a comma accepted as a decimal point.
///
/// Null when it is not one, so a caller can treat "unparseable" and "not
/// positive" as the same refusal — which they are, everywhere this is used.
double? parsePositive(String input) {
  final value = double.tryParse(input.trim().replaceAll(',', '.'));
  return value != null && value > 0 ? value : null;
}

/// `3` rather than `3.0` — a takt is written the way it is spoken.
String formatNumber(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : '$value';
