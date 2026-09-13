import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tokens.dart';
import '../../../common/date_style_scope.dart';
import '../../../common/result_table.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/run_comparison.dart';
import '../application/simulation_providers.dart';
import '../data/simulation_runs_repository.dart';

/// One stored run, loaded whole — the two halves of a comparison.
final storedRunProvider = FutureProvider.autoDispose.family<StoredRun?, String>(
  (ref, runId) => ref.watch(simulationRunsRepositoryProvider).loadRun(runId),
);

/// How a run is named wherever one is picked: the date, what it dispatched by,
/// and the takt it ran at (§7.3, §7.7.2). The runs menu and Compare's two
/// pickers read the same words, so a run is recognisable from either.
String runListingLabel(
  AppLocalizations l10n,
  String Function(DateTime? date) formatDate,
  RunListing listing,
) {
  final date = formatDate(listing.run.createdAt);
  final queues = runQueueLabel(l10n, listing.queues);
  final head = queues == null ? date : l10n.simRunLabel(date, queues);
  final takt = taktLabelForValues(l10n, listing.takts);
  return takt == null ? head : '$head  ·  $takt';
}

/// The third mode: two runs, a verdict, what differed, and the figures (#26).
///
/// **Two runs, not two studies** — inverted 2026-09-13 by the run history,
/// which matched zero pairs under #26's same-cell-and-line rule while one
/// study's own runs differed in up to nine release cadences. Cell and line are
/// a warning here, not a gate.
///
/// **It amends #7**, which settled on two modes after four driven rounds. The
/// reopening is deliberate: comparison is neither editing a study nor reading
/// one run, and a tab inside either would claim it was.
///
/// **Newest against the one before, on arrival** — the pair someone who just
/// pressed Simulate twice is asking about. Either side can be changed.
class CompareView extends ConsumerStatefulWidget {
  const CompareView({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<CompareView> createState() => _CompareViewState();
}

class _CompareViewState extends ConsumerState<CompareView> {
  String? _before;
  String? _after;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dateStyle = DateStyleScope.of(context);
    final runs = ref.watch(projectRunsProvider(widget.project.id)).value;

    if (runs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (runs.length < 2) {
      return _Empty(
        title: l10n.compareNeedsTwo,
        detail: l10n.compareNeedsTwoHelp,
      );
    }

    // A pick that no longer exists — a run deleted from the menu — falls back
    // to the default rather than to an error.
    bool exists(String? id) => runs.any((r) => r.run.id == id);
    final after = exists(_after) ? _after! : runs[0].run.id;
    final before = exists(_before) ? _before! : runs[1].run.id;

    DropdownButton<String> picker(String value, ValueChanged<String> onPick) =>
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: [
            for (final listing in runs)
              DropdownMenuItem(
                value: listing.run.id,
                child: Text(
                  runListingLabel(l10n, dateStyle.format, listing),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null) onPick(id);
          },
        );

    final a = ref.watch(storedRunProvider(before));
    final b = ref.watch(storedRunProvider(after));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _Labelled(
                label: l10n.compareBefore,
                child: picker(before, (id) => setState(() => _before = id)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Icon(Icons.arrow_forward),
            ),
            Expanded(
              child: _Labelled(
                label: l10n.compareAfter,
                child: picker(after, (id) => setState(() => _after = id)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (before == after)
          Text(l10n.compareSameRun, style: theme.textTheme.bodyMedium)
        else
          switch ((a, b)) {
            (AsyncData(value: final x?), AsyncData(value: final y?)) =>
              _Comparison(before: x, after: y),
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

  final StoredRun before;
  final StoredRun after;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = FlowStatus.of(context);
    final comparison = RunComparison.of(before, after);
    final verdict = comparison.verdict;

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
                      ComparisonWarning.differentScope =>
                        l10n.compareDifferentScope,
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
        // exists for: *better, and here is the one thing that changed*.
        Text(l10n.compareInputs, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (comparison.differences.isEmpty)
          Text(l10n.compareNoInputs, style: theme.textTheme.bodyMedium)
        else
          resultTable(
            maxHeight: null,
            columns: [
              ResultColumn(label: l10n.compareSubject, width: 200),
              ResultColumn(label: l10n.compareInput, width: 160),
              ResultColumn(label: l10n.compareBefore, width: 160),
              ResultColumn(label: l10n.compareAfter, width: 160),
            ],
            rowCount: comparison.differences.length,
            cellAt: (row, column) {
              final d = comparison.differences[row];
              return Text(switch (column) {
                0 => d.study,
                1 => _fieldLabel(l10n, d.field),
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
            ResultColumn(label: l10n.compareBefore, width: 140),
            ResultColumn(label: l10n.compareAfter, width: 140),
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
  InputField.releaseSeconds => l10n.compareReleaseInterval,
  InputField.takt => l10n.takt,
  InputField.wipCap => l10n.studyWipCap,
  InputField.startBuffer => l10n.studyStartBuffer,
  InputField.presence => l10n.compareInRun,
  InputField.dispatch => l10n.compareDispatch,
};

/// An input value as it reads on screen. The comparison carries them as the
/// strings it recorded; the words for them are this screen's.
String _input(AppLocalizations l10n, InputField field, String? raw) {
  if (raw == null) {
    return field == InputField.wipCap ? l10n.studyWipCapUnlimited : '—';
  }
  return switch (field) {
    InputField.releaseSeconds => formatAdaptiveDuration(
      l10n,
      Duration(seconds: int.tryParse(raw) ?? 0),
    ),
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
    InputField.presence => l10n.compareIncluded,
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
