import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/result_table.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../flow/application/flow_providers.dart';
import '../../flow/application/flow_view.dart';
import '../../flow/presentation/period_label.dart';
import '../application/summary_providers.dart';
import '../application/summary_view.dart';

/// The Summary tab: what the plant is being asked to do this period, and what
/// it can (DESIGN.md §8).
///
/// Every figure here is available before a simulation is run — a constraint the
/// Summary can already see is one the user can fix before spending a run on it.
class SummaryTab extends ConsumerWidget {
  const SummaryTab({super.key, required this.study});

  final Study study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(summaryViewProvider(study.id));
    if (summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _PeriodBar(study: study, summary: summary),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Headline(summary: summary),
              const SizedBox(height: 16),
              Text(
                l10n.summaryOccupation,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _OccupationTable(summary: summary),
              const SizedBox(height: 24),
              Text(
                l10n.summaryDemandTakt,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _DemandTaktCard(takt: summary.demandTakt),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodBar extends ConsumerWidget {
  const _PeriodBar({required this.study, required this.summary});

  final Study study;
  final SummaryView summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final period = ref.watch(viewedPeriodProvider(study.id));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.periodPrevious,
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                ref.read(viewedPeriodProvider(study.id).notifier).previous(),
          ),
          SizedBox(
            width: 96,
            child: Text(
              periodLabel(context, period.anchor, period.granularity),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            tooltip: l10n.periodNext,
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                ref.read(viewedPeriodProvider(study.id).notifier).next(),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<PeriodGranularity>(
              value: period.granularity,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(viewedPeriodProvider(study.id).notifier)
                      .setGranularity(value);
                }
              },
              items: [
                for (final granularity in PeriodGranularity.values)
                  DropdownMenuItem(
                    value: granularity,
                    child: Text(granularityLabel(l10n, granularity)),
                  ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            l10n.summaryOrdersDue('${summary.ordersInPeriod}'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// The one sentence a reader takes away: which station constrains this period,
/// and by how much (DESIGN.md §8.1).
class _Headline extends StatelessWidget {
  const _Headline({required this.summary});

  final SummaryView summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bottleneck = summary.bottleneck;

    if (bottleneck == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(l10n.summaryNothingToRank),
        ),
      );
    }

    final overloaded = bottleneck.isOverloaded;
    return Card(
      color: overloaded ? theme.colorScheme.errorContainer : null,
      child: ListTile(
        leading: Icon(
          overloaded ? Icons.warning_amber : Icons.check_circle_outline,
          color: overloaded ? theme.colorScheme.error : null,
        ),
        title: Text(
          l10n.summaryBottleneck(
            bottleneck.title,
            _percent(bottleneck.occupation),
          ),
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          overloaded ? l10n.summaryOverloaded : l10n.summaryWithinCapacity,
        ),
      ),
    );
  }
}

class _OccupationTable extends StatelessWidget {
  const _OccupationTable({required this.summary});

  final SummaryView summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (summary.targets.isEmpty) {
      return Text(l10n.summaryNoSteps, style: theme.textTheme.bodyMedium);
    }

    return Card(
      child: resultTable(
        columns: [
          ResultColumn(label: l10n.workcenter, width: 190),
          ResultColumn(label: l10n.summaryRequired, width: 120),
          ResultColumn(label: l10n.summaryAvailable, width: 120),
          ResultColumn(label: l10n.occupation, width: 130),
          ResultColumn(label: l10n.summaryOperatorsAllocated, width: 140),
          ResultColumn(label: l10n.summaryOperatorsNeeded, width: 140),
        ],
        rowCount: summary.targets.length,
        cellAt: (index, column) {
          final target = summary.targets[index];
          return switch (column) {
            0 => Row(
              // Without this the Row fills the column and the centring around
              // it does nothing — a name with a `×3` badge and an error icon
              // still has to read as one centred group.
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  // The badge and the icon must survive a long workcenter
                  // name: the column's width is declared now, so something in
                  // here has to give, and it is the name that can ellipsise.
                  child: Text(
                    target.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (target.visits > 1) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: l10n.summaryVisitsHelp('${target.visits}'),
                    child: Text(
                      '×${target.visits}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
                if (target.partsWithoutTimes > 0) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: l10n.summaryMissingTimes(
                      '${target.partsWithoutTimes}',
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            1 => Tooltip(
              // §15: every derived figure expands to show its inputs.
              message: l10n.summaryRequiredHelp(
                _hours(target.work),
                '${target.changeovers}',
                _hours(target.changeoverTime),
              ),
              child: Text(_hours(target.required)),
            ),
            2 => Text(_hours(target.availableProductive)),
            3 => Tooltip(
              message: l10n.summaryOccupationHelp(
                _percent(target.occupation),
                _hours(target.required),
                _hours(target.availableProductive),
              ),
              child: Text(
                _percent(target.occupation),
                style: target.isOverloaded
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
              ),
            ),
            4 => Text('${target.operatorsAllocated}'),
            _ => Text(
              target.operatorsNeeded == null
                  ? '—'
                  : target.operatorsNeeded!.toStringAsFixed(1),
            ),
          };
        },
      ),
    );
  }
}

class _DemandTaktCard extends StatelessWidget {
  const _DemandTaktCard({required this.takt});

  final DemandTaktView? takt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (takt == null) {
      return Text(l10n.summaryNoDemandTakt, style: theme.textTheme.bodyMedium);
    }
    final view = takt!;
    final day = view.paceSetterWorkingDay;

    String format(Duration? value) => value == null
        ? '—'
        : formatAdaptiveDuration(l10n, value, workingDay: day);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.summaryPaceSetter(
                view.paceSetterTitle,
                format(view.available),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            _TaktRow(
              label: l10n.summaryTaktConfigured,
              value: format(view.configured),
              help: l10n.summaryTaktConfiguredHelp,
            ),
            _TaktRow(
              label: l10n.summaryTaktRaw,
              value: format(view.raw),
              help: l10n.summaryTaktRawHelp('${view.orders}'),
            ),
            _TaktRow(
              label: l10n.summaryTaktAdjusted,
              value: format(view.adjusted),
              help: l10n.summaryTaktAdjustedHelp(
                view.equivalents.toStringAsFixed(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaktRow extends StatelessWidget {
  const _TaktRow({
    required this.label,
    required this.value,
    required this.help,
  });

  final String label;
  final String value;
  final String help;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: help,
        child: Row(
          children: [
            SizedBox(width: 260, child: Text(label)),
            Text(value, style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

String _percent(double? value) =>
    value == null ? '—' : '${(value * 100).toStringAsFixed(0)}%';

String _hours(Duration value) => '${(value.inMinutes / 60).toStringAsFixed(1)} h';
