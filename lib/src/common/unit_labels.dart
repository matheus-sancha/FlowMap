import '../data/database/enums.dart';
import '../features/simulation/application/sim_result.dart'
    show EmptySlotReason;
import '../data/database/database.dart' show SimulationRunStudy;
import '../features/simulation/data/simulation_runs_repository.dart'
    show RunQueues, taktSequences;
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

/// A takt written the way it is spoken — `4 days`, not `4.0 days`.
///
/// Here rather than on any one surface because §7.7 gave three of them the same
/// sentence to write: the map's caption when a viewed span crosses a change, the
/// run header's `Ran at 4 days`, and the runs-history picker. Three copies of
/// one format is how `4 d` and `4.0 days` end up on screen together.
String taktLabel(AppLocalizations l10n, double value, TaktUnit unit) =>
    '${value == value.roundToDouble() ? value.round() : value} '
    '${taktUnitLabel(l10n, unit)}';

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

/// Why a release slot produced nothing (DESIGN.md §7.2).
///
/// The three gates §7.2 checks, named rather than counted: *which* one held the
/// line is the thing a planner acts on, and "8 empty slots" is not.
String emptySlotReasonLabel(AppLocalizations l10n, EmptySlotReason reason) =>
    switch (reason) {
      EmptySlotReason.awaitingMaterial => l10n.simEmptySlotAwaitingMaterial,
      EmptySlotReason.wipCap => l10n.simEmptySlotWipCap,
      EmptySlotReason.laneFull => l10n.simEmptySlotLaneFull,
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

/// What a stored run ran at, or null where it never recorded one (§7.7.2).
///
/// **`mixed` where a run's studies ran at different takts**, which is honest on
/// a multi-line run: takt is keyed by production line, so two studies on two
/// lines legitimately have two. The same word [runQueueLabel] uses for the same
/// reason, and beside it for the same reason again — the history menu and the
/// run header must not disagree about what a run was.
///
/// Null on every run made before v20, which means *made before a run said this*
/// rather than *ran at no takt*.
String? runTaktLabel(
  AppLocalizations l10n,
  List<SimulationRunStudy> studies,
) => taktLabelForValues(l10n, [
  for (final study in studies)
    if (study.taktValue case final value?) [(value, study.taktUnit)],
]);

/// What a run's studies ran at: one figure where they all held one, `a → b`
/// where they all crossed the same change, `mixed` otherwise, and null where
/// none was recorded (§7.7.2, §7.9).
///
/// **Takes one ordered sequence per study** rather than study rows, because the
/// runs-history menu reads takt out of a lighter listing than the run header
/// does — a menu that labels every row cannot afford each run's full snapshot.
/// Both build their sequences with [taktSequences], so the menu and the header
/// it opens cannot name a run's takt two different ways.
///
/// **`mixed` is the answer to anything that is not one shared sequence of one or
/// two figures.** Three regimes in a run, or two studies that disagree, do not
/// fit a menu row — and a row that flattened them would claim a run was simpler
/// than it was, which is the half-truth this whole round is about.
String? taktLabelForValues(
  AppLocalizations l10n,
  List<List<(double, String?)>> sequences,
) {
  final present = [
    for (final sequence in sequences)
      if (sequence.isNotEmpty) sequence,
  ];
  if (present.isEmpty) return null;

  final first = present.first;
  final shared = present.every(
    (sequence) =>
        sequence.length == first.length &&
        [
          for (var i = 0; i < sequence.length; i++)
            if (sequence[i] != first[i]) i,
        ].isEmpty,
  );
  if (!shared || first.length > 2) return l10n.simRunTaktMixed;

  final labels = [
    for (final (value, unit) in first)
      if (TaktUnit.values.where((u) => u.name == unit).firstOrNull
          case final parsed?)
        taktLabel(l10n, value, parsed),
  ];
  if (labels.length != first.length) return null;
  return labels.length == 1 ? labels.single : '${labels.first} → ${labels.last}';
}

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
