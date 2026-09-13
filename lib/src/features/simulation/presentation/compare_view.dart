import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/tokens.dart';
import '../../../common/date_style_scope.dart';
import '../../../common/result_table.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../studies/application/studies_providers.dart';
import '../application/run_comparison.dart';
import '../application/simulation_providers.dart';
import '../data/simulation_runs_repository.dart';

/// One stored run, loaded whole — the two halves of a comparison.
final storedRunProvider = FutureProvider.autoDispose.family<StoredRun?, String>(
  (ref, runId) => ref.watch(simulationRunsRepositoryProvider).loadRun(runId),
);

/// A moment as a run is named by: the date in the reader's chosen format, then
/// the 24-hour time. Two runs made the same day are told apart by the time.
String runMoment(BuildContext context, DateTime at) =>
    '${DateStyleScope.of(context).format(at)} '
    '${DateFormat.Hm(Localizations.localeOf(context).toString()).format(at)}';

/// How a run is named wherever one is picked: **the studies it covered and when
/// it was made** (drive, 2026-09-13).
///
/// It was the date, the dispatch rule and the takt — so every run of the live
/// plant read `FIFO — by arrival`, a caption naming nothing a person chose,
/// while the fact that tells runs apart at a glance, which studies were in it,
/// was missing.
String runListingLabel(BuildContext context, RunListing listing) {
  final names = listing.studies.map((s) => s.name).join(', ');
  final when = runMoment(context, listing.run.createdAt);
  return names.isEmpty ? when : '$names · $when';
}

/// The third mode: two studies of one cell and line, each at its latest run
/// (#26).
///
/// **Two studies again, not two runs**, by the developer's call after driving
/// the runs version: the question is *which version of this line is better*.
/// The cost is that nothing appears until a line has two simulated studies —
/// none in the live plant does — so the empty state says how to make one.
///
/// **It amends #7**, which settled on two modes after four driven rounds.
class CompareView extends ConsumerStatefulWidget {
  const CompareView({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<CompareView> createState() => _CompareViewState();
}

class _CompareViewState extends ConsumerState<CompareView> {
  String? _line;
  String? _before;
  String? _after;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final runs = ref.watch(projectRunsProvider(widget.project.id)).value;
    final studies = ref.watch(studiesProvider(widget.project.id)).value;

    if (runs == null || studies == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final lines = comparableLines(studies, runs);
    if (lines.isEmpty) {
      return _Empty(
        title: l10n.compareNeedsTwo,
        detail: l10n.compareNeedsTwoHelp,
      );
    }

    // A pick that no longer exists — a study deleted, a run removed — falls
    // back to the default rather than to an error.
    String keyOf(ComparableLine l) => '${l.cellId}|${l.lineId}';
    final line = lines.firstWhere(
      (l) => keyOf(l) == _line,
      orElse: () => lines.first,
    );
    bool has(String? id) => line.studies.any((s) => s.studyId == id);
    // The two most recently simulated, newest on the right.
    final after = has(_after) ? _after! : line.studies[0].studyId;
    final before = has(_before)
        ? _before!
        : line.studies.firstWhere((s) => s.studyId != after).studyId;
    LatestStudyRun pick(String id) =>
        line.studies.firstWhere((s) => s.studyId == id);

    DropdownButton<String> studyPicker(
      String value,
      ValueChanged<String> onPick,
    ) => DropdownButton<String>(
      value: value,
      isExpanded: true,
      items: [
        for (final study in line.studies)
          DropdownMenuItem(
            value: study.studyId,
            child: Text(
              '${study.name} · ${runMoment(context, study.runAt)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) {
        if (id != null) onPick(id);
      },
    );

    final a = ref.watch(storedRunProvider(pick(before).runId));
    final b = ref.watch(storedRunProvider(pick(after).runId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _Labelled(
            label: l10n.compareLine,
            child: DropdownButton<String>(
              value: keyOf(line),
              items: [
                for (final l in lines)
                  DropdownMenuItem(value: keyOf(l), child: Text(l.label)),
              ],
              onChanged: (key) => setState(() {
                _line = key;
                _before = null;
                _after = null;
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _Labelled(
                label: l10n.study,
                child: studyPicker(
                  before,
                  (id) => setState(() => _before = id),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Icon(Icons.arrow_forward),
            ),
            Expanded(
              child: _Labelled(
                label: l10n.study,
                child: studyPicker(after, (id) => setState(() => _after = id)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (before == after)
          Text(l10n.compareSameStudy, style: theme.textTheme.bodyMedium)
        else
          switch ((a, b)) {
            (AsyncData(value: final x?), AsyncData(value: final y?)) =>
              () {
                // One window for both sides' occupation, so neither is diluted
                // by months only the other worked.
                final window = comparisonWindow(x, before, y, after);
                return _Comparison(
                  before: ComparedSide.of(
                    x,
                    before,
                    window: window,
                    untypedLabel: l10n.occupationUntyped,
                  ),
                  after: ComparedSide.of(
                    y,
                    after,
                    window: window,
                    untypedLabel: l10n.occupationUntyped,
                  ),
                );
              }(),
            (AsyncError(:final error), _) ||
            (_, AsyncError(:final error)) => Text('$error'),
            _ => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
      ],
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.before, required this.after});

  final ComparedSide before;
  final ComparedSide after;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = FlowStatus.of(context);
    final comparison = RunComparison.between(before, after);
    final verdict = comparison.verdict;
    // **The columns are the studies**, by name (drive, 2026-09-13): *Before*
    // and *After* implied an order in time the two versions of a line do not
    // have.
    final nameBefore = before.study.name;
    final nameAfter = after.study.name;

    Color? tone(bool? better) => switch (better) {
      true => status.good.ink,
      false => status.critical.ink,
      null => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // **The verdict first**, and it is on-time delivery — the figure the
        // run's own headline and the report lead with, so the three agree.
        if (verdict != null)
          Card(
            color: switch (verdict.isBetter) {
              true => status.good.fill,
              false => status.critical.fill,
              null => null,
            },
            child: ListTile(
              title: Text(
                '${l10n.simOnTimeDelivery}: '
                '${_value(l10n, verdict.metric, verdict.before)} → '
                '${_value(l10n, verdict.metric, verdict.after)}',
                style: theme.textTheme.titleMedium,
              ),
              subtitle: verdict.delta == null
                  ? null
                  : Text(
                      _change(l10n, verdict.metric, verdict.delta!),
                      style: TextStyle(color: tone(verdict.isBetter)),
                    ),
            ),
          ),
        for (final warning in comparison.warnings)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    switch (warning) {
                      ComparisonWarning.differentBuilds =>
                        l10n.compareDifferentBuilds(
                          before.appVersion ?? l10n.compareUnstamped,
                          after.appVersion ?? l10n.compareUnstamped,
                        ),
                    },
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        // **What was different, before the figures** — the half the feature
        // exists for: *better, and here is what the two were given*.
        Text(l10n.compareStudiesDifference, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (comparison.differences.isEmpty)
          Text(l10n.compareNoInputs, style: theme.textTheme.bodyMedium)
        else
          resultTable(
            maxHeight: null,
            columns: [
              ResultColumn(label: l10n.compareInput, width: 160),
              ResultColumn(label: l10n.workcenter, width: 160),
              ResultColumn(label: nameBefore, width: 180),
              ResultColumn(label: nameAfter, width: 180),
            ],
            rowCount: comparison.differences.length,
            cellAt: (row, column) {
              final d = comparison.differences[row];
              return Text(switch (column) {
                0 => _fieldLabel(l10n, d.field),
                1 => d.workcenter ?? '—',
                2 => _input(l10n, d.field, d.before),
                _ => _input(l10n, d.field, d.after),
              });
            },
          ),
        const SizedBox(height: 24),
        Text(l10n.compareResults, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        resultTable(
          maxHeight: null,
          columns: [
            ResultColumn(label: l10n.compareInput, width: 200),
            ResultColumn(label: nameBefore, width: 180),
            ResultColumn(label: nameAfter, width: 180),
            ResultColumn(label: l10n.compareChange, width: 140),
          ],
          rowCount: comparison.deltas.length,
          cellAt: (row, column) {
            final d = comparison.deltas[row];
            return switch (column) {
              0 => Text(_metricLabel(l10n, d.metric)),
              1 => Text(_value(l10n, d.metric, d.before)),
              2 => Text(_value(l10n, d.metric, d.after)),
              // Coloured by *better*, never by *larger*: lead time falling is
              // an improvement and OTD falling is not.
              _ => Text(
                d.delta == null ? '—' : _change(l10n, d.metric, d.delta!),
                style: TextStyle(
                  color: tone(d.isBetter),
                  fontWeight: d.isBetter == null ? null : FontWeight.w600,
                ),
              ),
            };
          },
        ),
        const SizedBox(height: 24),
        Text(l10n.compareOccupation, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        resultTable(
          maxHeight: null,
          columns: [
            ResultColumn(label: l10n.occupationWorkcenterType, width: 200),
            ResultColumn(label: nameBefore, width: 180),
            ResultColumn(label: nameAfter, width: 180),
            ResultColumn(label: l10n.compareChange, width: 140),
          ],
          rowCount: comparison.occupation.length,
          cellAt: (row, column) {
            final o = comparison.occupation[row];
            final total = o.type == null;
            final weight = total ? FontWeight.w700 : null;
            // Over 100 % is the one reading that is a finding on its own, so it
            // is coloured wherever it appears; the change stays neutral, since
            // a busier plant is not better or worse without knowing why.
            Text ratio(double? value) => Text(
              value == null ? '—' : '${(value * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: weight,
                color: (value ?? 0) > 1 ? status.critical.ink : null,
              ),
            );
            return switch (column) {
              0 => Text(
                o.type ?? l10n.occupationTotal,
                style: TextStyle(fontWeight: weight),
              ),
              1 => ratio(o.before),
              2 => ratio(o.after),
              _ => Text(
                o.delta == null
                    ? '—'
                    : l10n.comparePoints(
                        '${o.delta! > 0 ? '+' : ''}'
                        '${(o.delta! * 100).toStringAsFixed(0)}',
                      ),
                style: TextStyle(fontWeight: weight),
              ),
            };
          },
        ),
      ],
    );
  }
}

String _metricLabel(AppLocalizations l10n, ComparedMetric metric) =>
    switch (metric) {
      ComparedMetric.onTimeDelivery => l10n.simOnTimeDelivery,
      ComparedMetric.leadTime => l10n.simAverageLeadTime,
      ComparedMetric.float => l10n.simAverageFloat,
      ComparedMetric.lateOrders => l10n.simReportLateOrders,
      ComparedMetric.emptySlots => l10n.simEmptySlots,
    };

/// A figure as the run's own screen writes it. Lead time and float arrive in
/// days from the comparison; they go back through the app's duration format.
String _value(AppLocalizations l10n, ComparedMetric metric, double? value) {
  if (value == null) return '—';
  return switch (metric) {
    ComparedMetric.onTimeDelivery => '${value.toStringAsFixed(0)}%',
    ComparedMetric.leadTime || ComparedMetric.float => formatAdaptiveDuration(
      l10n,
      Duration(minutes: (value * 24 * 60).round()),
    ),
    _ => value.toStringAsFixed(0),
  };
}

String _change(AppLocalizations l10n, ComparedMetric metric, double delta) {
  final sign = delta > 0 ? '+' : '';
  return switch (metric) {
    ComparedMetric.onTimeDelivery => l10n.comparePoints(
      '$sign${delta.toStringAsFixed(0)}',
    ),
    ComparedMetric.leadTime ||
    ComparedMetric.float => '$sign${_value(l10n, metric, delta)}',
    _ => '$sign${delta.toStringAsFixed(0)}',
  };
}

String _fieldLabel(AppLocalizations l10n, InputField field) => switch (field) {
  InputField.takt => l10n.takt,
  InputField.wipCap => l10n.studyWipCap,
  InputField.startBuffer => l10n.studyStartBuffer,
  InputField.dispatch => l10n.compareDispatch,
};

/// An input value as it reads on screen. The comparison carries them as the
/// strings it recorded; the words for them are this screen's.
String _input(AppLocalizations l10n, InputField field, String? raw) {
  if (raw == null) {
    return field == InputField.wipCap ? l10n.studyWipCapUnlimited : '—';
  }
  return switch (field) {
    InputField.takt => () {
      final parts = raw.split(' ');
      final value = double.tryParse(parts.first);
      final unit = parts.length > 1
          ? TaktUnit.values.where((u) => u.name == parts[1]).firstOrNull
          : null;
      return value == null || unit == null ? raw : taktLabel(l10n, value, unit);
    }(),
    InputField.dispatch => () {
      final rule = DispatchRule.values.where((r) => r.name == raw).firstOrNull;
      return rule == null ? raw : dispatchRuleLabel(l10n, rule);
    }(),
    _ => raw,
  };
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      child,
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.compare_arrows,
                size: 40,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
