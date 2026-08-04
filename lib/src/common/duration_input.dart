/// Reading and writing the durations a user types (DESIGN.md §12.4).
///
/// One parser, shared by every field and every grid cell, so `1.5h` means the
/// same thing wherever it is typed and a pasted column from Excel is read the
/// same way a hand-typed cell is.
library;

import '../data/database/enums.dart';
import 'unit_labels.dart';

/// `30:00:00`, `1:30`, `1.5h`, `90min`, `2d`, `45s`, or a bare number in
/// [bareUnit].
///
/// Returns null for anything else — including a negative number, which is a
/// validation failure the import preview and the grid both have to report
/// (§9), not something to clamp silently.
///
/// **Hours are unbounded in the colon form.** A 30-hour process time reads and
/// parses as `30:00:00`, the way the VSM process box writes it; only minutes
/// and seconds are held to 59.
Duration? parseDurationInput(
  String input, {
  DurationUnit bareUnit = DurationUnit.hours,
}) {
  final text = input.trim().toLowerCase().replaceAll(',', '.');
  if (text.isEmpty) return null;

  final clock = RegExp(r'^(\d+):([0-5]?\d)(?::([0-5]?\d))?$').firstMatch(text);
  if (clock != null) {
    return Duration(
      hours: int.parse(clock.group(1)!),
      minutes: int.parse(clock.group(2)!),
      seconds: int.parse(clock.group(3) ?? '0'),
    );
  }

  // `min` before `m` in the alternation, so `90min` is ninety minutes rather
  // than ninety of something followed by a stray `in`.
  final suffixed = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(d|h|min|m|s)?$',
  ).firstMatch(text);
  if (suffixed == null) return null;

  final unit = switch (suffixed.group(2)) {
    'd' => DurationUnit.days,
    'h' => DurationUnit.hours,
    'm' || 'min' => DurationUnit.minutes,
    's' => DurationUnit.seconds,
    _ => bareUnit,
  };
  return durationFrom(double.parse(suffixed.group(1)!), unit);
}

/// What a committed duration reads back as in a grid cell or a text field.
///
/// `HH:MM:SS` with hours running past 24, per §12.4 — the form a process time
/// is written in on a value-stream map. The adaptive `9.1 d` form is for
/// headline figures on the map, not for a number someone is about to edit.
String formatDurationInput(Duration duration) {
  final total = duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  return '${_two(hours)}:${_two(minutes)}:${_two(seconds)}';
}

String _two(int n) => n.toString().padLeft(2, '0');
