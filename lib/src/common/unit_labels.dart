import '../data/database/enums.dart';
import '../features/simulation/data/simulation_runs_repository.dart'
    show RunQueues;
import '../l10n/generated/app_localizations.dart';

/// Localized names for the takt units.
///
/// Shared by the takt editor, the canvas footer and the PDF so the same takt
/// never reads as `3 d` in one place and `3 days` in another.
///
/// _Rejected: `TaktUnit.name`._ It is an **extension** getter, so it resolves
/// statically — calling it through a `dynamic` receiver compiles and then
/// throws `NoSuchMethodError` at runtime, which is what greyed out the flow
/// screen the first time a takt was saved. An exhaustive switch cannot fail
/// that way, and the compiler checks it when a unit is added.
String taktUnitLabel(AppLocalizations l10n, TaktUnit unit) => switch (unit) {
  TaktUnit.days => l10n.unitDays,
  TaktUnit.hours => l10n.unitHours,
  TaktUnit.minutes => l10n.unitMinutes,
  TaktUnit.seconds => l10n.unitSeconds,
};

/// What a dispatch rule is called (DESIGN.md §7.4).
///
/// Here rather than on the Simulation tab, because a station's own rule is now
/// set on the flow map too and both have to name it the same way.
String dispatchRuleLabel(AppLocalizations l10n, DispatchRule rule) =>
    switch (rule) {
      DispatchRule.fifo => l10n.dispatchFifo,
      DispatchRule.lifo => l10n.dispatchLifo,
      DispatchRule.earliestDueDate => l10n.dispatchEarliestDueDate,
      DispatchRule.shortestProcessing => l10n.dispatchShortestProcessing,
    };

/// What a whole run dispatched by, in one line (§7.3): the type every station
/// shared, or `mixed` when they differed.
///
/// Null when the run recorded nothing to name — and every caller drops the
/// clause rather than inventing FIFO for a run that never claimed one.
///
/// Beside [dispatchRuleLabel] for its reason, one level up: three places label a
/// run — the history menu, the run header and the Excel stamp — and they sit in
/// two files that must not import each other, so a run could otherwise read
/// `FIFO` in the menu and `mixed` in the header it opens.
String? runQueueLabel(AppLocalizations l10n, RunQueues queues) => queues.label(
  name: (rule) => dispatchRuleLabel(l10n, rule),
  mixed: l10n.simRunQueuesMixed,
);

/// The abbreviation the footer band and the process boxes use.
String taktUnitShort(AppLocalizations l10n, TaktUnit unit) => switch (unit) {
  TaktUnit.days => l10n.unitDaysShort,
  TaktUnit.hours => l10n.unitHoursShort,
  TaktUnit.minutes => l10n.unitMinutesShort,
  TaktUnit.seconds => l10n.unitSecondsShort,
};

String durationUnitLabel(AppLocalizations l10n, DurationUnit unit) =>
    switch (unit) {
      DurationUnit.days => l10n.unitDays,
      DurationUnit.hours => l10n.unitHours,
      DurationUnit.minutes => l10n.unitMinutes,
      DurationUnit.seconds => l10n.unitSeconds,
    };

/// Seconds in one of [unit]. A day is 24 hours here — see [DurationUnit].
int secondsPerDurationUnit(DurationUnit unit) => switch (unit) {
  DurationUnit.days => 24 * 60 * 60,
  DurationUnit.hours => 60 * 60,
  DurationUnit.minutes => 60,
  DurationUnit.seconds => 1,
};

/// A stored duration expressed in [unit], e.g. `2` for 48 h in days.
double durationIn(Duration duration, DurationUnit unit) =>
    duration.inSeconds / secondsPerDurationUnit(unit);

/// The inverse: what a user typing `2 days` meant.
Duration durationFrom(double value, DurationUnit unit) =>
    Duration(seconds: (value * secondsPerDurationUnit(unit)).round());

/// A duration in the largest unit that keeps it readable: `9.1 d`, `5.4 h`,
/// `42 min`, `30 s`.
///
/// Totals on a value-stream map span six orders of magnitude — a changeover of
/// forty minutes and a lead time of nine days appear on the same screen — and
/// `HH:MM:SS` serves neither: `218:24:00` has to be divided in the reader's
/// head, and `0.0007 d` says nothing. A day here is 24 hours; these are
/// headline figures, not capacity arithmetic.
String formatAdaptiveDuration(
  AppLocalizations l10n,
  Duration duration, {
  Duration? workingDay,
}) {
  final seconds = duration.inSeconds.abs();
  final sign = duration.isNegative ? '-' : '';

  // Where a working day is known, a "day" means one of *those* — so a 3-day
  // takt on the lead-time ladder reads `3.0 d`, not `2.8 d` measured against a
  // 24-hour day the plant never works.
  if (workingDay != null &&
      workingDay.inSeconds > 0 &&
      seconds >= workingDay.inSeconds) {
    return '$sign${(seconds / workingDay.inSeconds).toStringAsFixed(1)} '
        '${l10n.unitDaysShort}';
  }

  if (seconds >= 24 * 3600) {
    return '$sign${(seconds / (24 * 3600)).toStringAsFixed(1)} '
        '${l10n.unitDaysShort}';
  }
  if (seconds >= 3600) {
    return '$sign${(seconds / 3600).toStringAsFixed(1)} ${l10n.unitHoursShort}';
  }
  if (seconds >= 60) {
    return '$sign${seconds ~/ 60} ${l10n.unitMinutesShort}';
  }
  return '$sign$seconds ${l10n.unitSecondsShort}';
}
