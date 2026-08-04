/// Formatting shared by more than one feature (DESIGN.md §12.4).
library;

/// A clock reading, `05:45`, from minutes since midnight.
///
/// Deliberately 24-hour and locale-independent. A shift boundary is a number
/// the plant has written on a board; rendering it as `5:45 AM` for an
/// en-US user would make the app disagree with the shop floor. Dates, which
/// carry no such convention, do follow the locale.
String formatMinuteOfDay(int minuteOfDay) {
  final normalized = minuteOfDay % (24 * 60);
  final hours = normalized ~/ 60;
  final minutes = normalized % 60;
  return '${_two(hours)}:${_two(minutes)}';
}

/// `HH:MM:SS`, with hours running past 24 — a 30-hour process time reads
/// `30:00:00`, as in the VSM process box.
String formatDurationHms(Duration duration) {
  final negative = duration.isNegative;
  final total = duration.abs();
  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60);
  final seconds = total.inSeconds.remainder(60);
  return '${negative ? '-' : ''}${_two(hours)}:${_two(minutes)}:${_two(seconds)}';
}

/// Parses `HH:MM`, `H:MM` or `HHMM` into minutes since midnight, or null if it
/// is not a clock reading. Returns null rather than throwing: this runs on
/// every keystroke in a text field.
int? parseMinuteOfDay(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  final match = RegExp(r'^(\d{1,2})[:h.]?(\d{2})$').firstMatch(text);
  if (match == null) return null;

  final hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  if (hours > 23 || minutes > 59) return null;
  return hours * 60 + minutes;
}

String _two(int n) => n.toString().padLeft(2, '0');
