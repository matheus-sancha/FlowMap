import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/centred_table.dart';
import '../../../common/date_input.dart';
import '../../../common/dialogs.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/run_metrics.dart';
import '../application/sim_assembly.dart';
import '../application/sim_model.dart';
import '../application/sim_result.dart';
import '../application/simulation_providers.dart';
import '../data/simulation_runs_repository.dart';

/// The Simulation tab (DESIGN.md §12.1).
///
/// **Project-level, not per study**, because a run spans studies: every flagged
/// study releases into one model of the plant, so line A's orders genuinely
/// delay line B's (§7.7). Which studies are in is set on the studies
/// themselves, so what is here is the rule to dispatch by, the readiness that
/// gates the button, and what §8 makes of the result.
class SimulationTab extends ConsumerWidget {
  const SimulationTab({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(simRunInputProvider(project.id));
    final runner = ref.watch(simulationRunnerProvider(project.id));

    return Column(
      children: [
        _RunBar(project: project, input: input.value, busy: runner.isLoading),
        const Divider(height: 1),
        Expanded(
          child: switch (input) {
            AsyncError(:final error) => _Message(
              icon: Icons.error_outline,
              title: '$error',
            ),
            AsyncValue(value: null) => const Center(
              child: CircularProgressIndicator(),
            ),
            AsyncValue(value: final assembled!) => _Body(
              project: project,
              input: assembled,
              runner: runner,
            ),
          },
        ),
      ],
    );
  }
}

class _RunBar extends ConsumerWidget {
  const _RunBar({required this.project, required this.input, required this.busy});

  final Project project;
  final SimRunInput? input;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rule = ref.watch(dispatchRuleSelectionProvider(project.id));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // The settings scroll and the button does not: Simulate is the one
          // control that must be reachable at any window width.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    l10n.simulationStudiesIn(input?.readiness.length ?? 0),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Tooltip(
                    message: l10n.simulationDispatchHelp,
                    child: Row(
                      children: [
                        Text(l10n.simulationDispatch),
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<DispatchRule>(
                            value: rule,
                            onChanged: busy
                                ? null
                                : (value) {
                                    if (value != null) {
                                      ref
                                          .read(
                                            dispatchRuleSelectionProvider(
                                              project.id,
                                            ).notifier,
                                          )
                                          .select(value);
                                    }
                                  },
                            items: [
                              for (final option in DispatchRule.values)
                                DropdownMenuItem(
                                  value: option,
                                  child: Text(dispatchRuleLabel(l10n, option)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Simulate itself is in the project's app bar (§12.1), so it can be
          // pressed from any tab. What stays here is the setting the run is
          // made with and the runs already made.
          _RunsMenu(projectId: project.id),
        ],
      ),
    );
  }
}

/// The project's stored runs: open an earlier one, or delete one (§7.10).
///
/// A run is ~4k rows for 500 orders, and nothing else in the app will ever
/// remove one — so the list that makes them reachable is also the only place
/// that can let them go.
class _RunsMenu extends ConsumerWidget {
  const _RunsMenu({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final runs =
        ref.watch(projectRunsProvider(projectId)).value ??
        const <SimulationRun>[];
    if (runs.isEmpty) return const SizedBox.shrink();

    String label(SimulationRun run) => l10n.simRunLabel(
      formatDateInput(run.createdAt, locale),
      dispatchRuleLabel(l10n, _ruleOf(run.dispatch)),
    );

    return PopupMenuButton<({String runId, bool delete})>(
      tooltip: l10n.simEarlierRuns,
      icon: const Icon(Icons.history),
      onSelected: (action) async {
        final runner = ref.read(simulationRunnerProvider(projectId).notifier);
        if (!action.delete) return runner.show(action.runId);

        final run = runs.firstWhere((r) => r.id == action.runId);
        final confirmed = await confirmAction(
          context,
          title: l10n.confirmDeleteTitle(label(run)),
          message: l10n.simRunDeleteBody,
          confirmLabel: l10n.actionDelete,
          destructive: true,
        );
        if (confirmed) await runner.delete(action.runId);
      },
      itemBuilder: (context) => [
        for (final run in runs)
          PopupMenuItem(
            value: (runId: run.id, delete: false),
            child: Row(
              children: [
                Expanded(child: Text(label(run))),
                const SizedBox(width: 12),
                // In the row rather than a second menu: the run being deleted
                // is the one being read, and a delete two levels away from it
                // is a delete aimed at the wrong one.
                IconButton(
                  tooltip: l10n.actionDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop((runId: run.id, delete: true)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static DispatchRule _ruleOf(String name) =>
      DispatchRule.values.where((r) => r.name == name).firstOrNull ??
      DispatchRule.fifo;
}

class _Body extends StatelessWidget {
  const _Body({
    required this.project,
    required this.input,
    required this.runner,
  });

  final Project project;
  final SimRunInput input;
  final AsyncValue<StoredRun?> runner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (input.isEmpty) {
      return _Message(
        icon: Icons.playlist_add_check_outlined,
        title: l10n.simulationNoStudies,
        detail: l10n.simulationNoStudiesHelp,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!input.canRun) ...[
          _ReadinessPanel(input: input),
          const SizedBox(height: 16),
        ],
        switch (runner) {
          AsyncError(:final error) => _Message(
            icon: Icons.error_outline,
            title: '$error',
          ),
          AsyncLoading() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
          AsyncValue(value: null) => _Message(
            icon: Icons.timeline_outlined,
            title: l10n.simulationNeverRun,
            detail: l10n.simulationNeverRunHelp,
          ),
          AsyncValue(value: final run!) => _Results(run: run),
        },
      ],
    );
  }
}

/// §11's readiness, per study. Simulate is disabled while any of it stands.
class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({required this.input});

  final SimRunInput input;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  l10n.simulationNotReady,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final study in input.readiness)
              if (!study.isReady)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(study.name, style: theme.textTheme.labelLarge),
                      for (final problem in study.problems)
                        Text('• ${simProblemLabel(l10n, problem)}'),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Everything §8 asks a run to report.
class _Results extends StatelessWidget {
  const _Results({required this.run});

  final StoredRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final metrics = run.metrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${l10n.simRunLabel(formatDateInput(run.createdAt, locale), dispatchRuleLabel(l10n, run.dispatch))}'
          '  ·  '
          '${l10n.simRunSpan(formatDateInput(run.result.start, locale), formatDateInput(run.result.end, locale))}'
          // Named here rather than left to the reader to notice, because the
          // rule beside the timestamp would otherwise describe a dispatch that
          // did not happen at every station (§7.4).
          '${run.dispatchOverrides.isEmpty ? '' : '  ·  ${l10n.simDispatchOverrides(run.dispatchOverrides.length)}'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        // Which stations, and to what. A count alone says the run is not what
        // its header claims without saying what it actually was.
        if (run.dispatchOverrides.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                for (final override in run.dispatchOverrides)
                  l10n.simDispatchOverrideRow(
                    override.name,
                    dispatchRuleLabel(l10n, override.rule),
                  ),
              ].join('  ·  '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (run.result.abort != null) ...[
          _AbortBanner(result: run.result),
          const SizedBox(height: 12),
        ],
        _Headline(metrics: metrics),
        const SizedBox(height: 16),
        _MetricsCard(metrics: metrics),
        const SizedBox(height: 24),
        Text(l10n.simByQueue, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          l10n.simRankingsHelp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        _QueueTable(metrics: metrics),
        const SizedBox(height: 24),
        Text(l10n.simByShare, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _ShareTable(metrics: metrics),
        const SizedBox(height: 24),
        Text(l10n.simPerPart, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _PartsTable(metrics: metrics),
        const SizedBox(height: 24),
        Text(l10n.simProductionPlan, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          l10n.simProductionPlanHelp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        _ProductionPlan(run: run),
      ],
    );
  }
}

/// The production plan: what the run says each order actually does
/// (DESIGN.md §8.5).
///
/// **One section per study**, because a study is one production line and a
/// production plan is a line's plan — a planner takes the section for their
/// line. Rows are in sequence order, which for §7.2's strict release *is*
/// release order, so "orders over time" needs no sort that could disagree with
/// the Order column.
class _ProductionPlan extends StatelessWidget {
  const _ProductionPlan({required this.run});

  final StoredRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (run.plan.isEmpty) return const SizedBox.shrink();

    // Study id → the name it had when the run was made (§7.10), so a study
    // renamed since still reads as the one that ran.
    final names = {for (final study in run.studies) study.studyId: study.name};

    final byStudy = <String, List<ProductionPlanRow>>{};
    for (final row in run.plan) {
      byStudy.putIfAbsent(row.outcome.studyId, () => []).add(row);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in byStudy.entries) ...[
          // Only when there is more than one: a heading over the single
          // section of a single-study run says nothing the tab has not said.
          if (byStudy.length > 1) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                names[entry.key] ?? entry.key,
                style: theme.textTheme.labelLarge,
              ),
            ),
          ],
          _PlanTable(rows: entry.value),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PlanTable extends StatelessWidget {
  const _PlanTable({required this.rows});

  final List<ProductionPlanRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

    String date(DateTime? value) =>
        value == null ? '—' : formatDateInput(value, locale);

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            centredColumn(l10n.simPlanOrder),
            centredColumn(l10n.demandPartNumber),
            centredColumn(l10n.demandDescription),
            centredColumn(l10n.demandProject),
            centredColumn(l10n.demandBatchNumber),
            centredColumn(l10n.demandBatchSize),
            centredColumn(l10n.demandNeedDate),
            centredColumn(l10n.demandMaterialDate),
            centredColumn(l10n.simPlanOrderStart),
            centredColumn(l10n.simPlanOrderEnd),
            // Theoretical first: it is the baseline, and the actual beside it
            // is read against it. The gap between the two is the queueing.
            centredColumn(l10n.simPlanTheoreticalLeadTime),
            centredColumn(l10n.simPlanActualLeadTime),
            centredColumn(l10n.simAverageFloat),
          ],
          rows: [
            for (final row in rows)
              DataRow(
                cells: [
                  centredText('${row.orderNumber}'),
                  centredText(row.partNumber),
                  // Free text with no length limit, in a table that sizes each
                  // column to its widest cell — so one long description would
                  // push Float off the right edge for every row. Capped and
                  // ellipsised with the whole string on hover, which is what
                  // §5.4 does with a node's notes for the same reason.
                  centredCell(_Description(text: row.partDescription)),
                  // Blank throughout means a run made before schema v12, which
                  // did not record any of this (§16.13). A dash, never a
                  // guess.
                  centredText(
                    (row.customerProject?.isEmpty ?? true)
                        ? '—'
                        : row.customerProject!,
                  ),
                  centredText(
                    (row.batchNumber?.isEmpty ?? true)
                        ? '—'
                        : row.batchNumber!,
                  ),
                  centredText(row.batchSize == null ? '—' : '${row.batchSize}'),
                  centredText(date(row.outcome.needDate)),
                  centredText(date(row.materialDate)),
                  centredText(date(row.orderStart)),
                  centredText(date(row.delivery)),
                  centredText(_duration(l10n, row.theoreticalLeadTime)),
                  centredText(_duration(l10n, row.actualLeadTime)),
                  // The one figure here that is a verdict rather than a fact,
                  // so late is coloured. Positive is early (§8).
                  centredText(
                    _duration(l10n, row.float),
                    style: (row.float?.isNegative ?? false)
                        ? theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          )
                        : null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The plan's Description cell: capped, ellipsised, whole text on hover.
///
/// A `DataTable` sizes every column to its widest cell, and a part description
/// is free text with no length limit — so one long one would widen this column
/// for all 33 rows and push Float past the right edge. The cap is the same
/// answer §5.4 gave a node's notes: show that there is one, and put the words
/// where asking for them costs nothing.
///
/// A blank is a dash, and means two things that read the same: nobody typed a
/// description, or the run predates v13 and did not record one (§16.14).
class _Description extends StatelessWidget {
  const _Description({required this.text});

  final String? text;

  static const _maxWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    final value = text;
    if (value == null || value.isEmpty) return const Text('—');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      // Unconditional, including on a description short enough to be fully
      // visible. Showing it only when truncated would mean measuring the text
      // against the cap on every build to save the reader a tooltip that
      // repeats what they can already read, which is not worth a TextPainter.
      child: Tooltip(
        message: value,
        child: Text(value, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    );
  }
}

/// Why the run stopped early (§7.8) — stated rather than left for the reader to
/// infer from a low delivery figure.
class _AbortBanner extends StatelessWidget {
  const _AbortBanner({required this.result});

  final SimRunResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.report_outlined, color: theme.colorScheme.error),
        title: Text(switch (result.abort!) {
          SimAbortReason.horizonExceeded => l10n.simulationAbortHorizon(
            '${result.undelivered.length}',
          ),
          SimAbortReason.nothingToRun => l10n.simulationAbortNothingToRun,
        }),
      ),
    );
  }
}

/// The one figure a reader takes away.
class _Headline extends StatelessWidget {
  const _Headline({required this.metrics});

  final RunMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bottleneck = metrics.bottleneck;
    final perfect = metrics.onTime == metrics.orders && metrics.orders > 0;

    return Card(
      color: perfect ? null : theme.colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(
          perfect ? Icons.check_circle_outline : Icons.warning_amber,
          color: perfect ? null : theme.colorScheme.error,
        ),
        title: Text(
          '${l10n.simOnTimeDelivery}: ${_percent(metrics.onTimeDelivery)}',
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          '${l10n.simOnTimeOfOrders('${metrics.onTime}', '${metrics.orders}')}'
          '${bottleneck == null ? '' : '  ·  ${l10n.summaryBottleneck(bottleneck.name, _percent(bottleneck.utilization))}'}',
        ),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.metrics});

  final RunMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _MetricRow(
              label: l10n.simDelivered,
              value: l10n.simDeliveredOf(
                '${metrics.delivered}',
                '${metrics.orders}',
              ),
              help: l10n.simOnTimeHelp,
            ),
            _MetricRow(
              label: l10n.simAverageFloat,
              value: _duration(l10n, metrics.averageFloat),
              help: l10n.simAverageFloatHelp,
            ),
            _MetricRow(
              label: l10n.simAverageLeadTime,
              value: _duration(l10n, metrics.averageLeadTime),
              help: l10n.simAverageLeadTimeHelp,
            ),
            _MetricRow(
              label: l10n.simTheoreticalLeadTime,
              value: _duration(l10n, metrics.theoreticalLeadTime),
              help: l10n.simTheoreticalLeadTimeHelp,
            ),
            _MetricRow(
              label: l10n.simLeadTimeEfficiency,
              value: metrics.leadTimeEfficiency == null
                  ? '—'
                  : '${metrics.leadTimeEfficiency!.toStringAsFixed(2)}×',
              help: l10n.simLeadTimeEfficiencyHelp,
            ),
            _MetricRow(
              label: l10n.simEmptySlots,
              value: '${metrics.emptySlots}',
              help: l10n.simEmptySlotsHelp,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
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

/// §8.1's first post-run ranking: where orders wait.
class _QueueTable extends StatelessWidget {
  const _QueueTable({required this.metrics});

  final RunMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (metrics.workcenters.isEmpty) {
      return Text(l10n.simNothingRanked);
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            centredColumn(l10n.workcenter),
            centredColumn(l10n.utilization),
            centredColumn(l10n.simQueue),
            centredColumn(l10n.simQueueAverage),
            centredColumn(l10n.simVisits),
            centredColumn(l10n.simChangeovers),
          ],
          rows: [
            for (final station in metrics.workcenters)
              DataRow(
                cells: [
                  centredText(station.name),
                  centredCell(
                    Tooltip(
                      message: l10n.simUtilizationHelp,
                      child: Text(_percent(station.utilization)),
                    ),
                  ),
                  centredText(_duration(l10n, station.queueTime)),
                  centredText(_duration(l10n, station.averageQueue)),
                  centredText('${station.visits}'),
                  centredText('${station.changeovers}'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// §8.1's second ranking, kept apart from the first because their disagreement
/// is the diagnostic.
class _ShareTable extends StatelessWidget {
  const _ShareTable({required this.metrics});

  final RunMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (metrics.workcenters.isEmpty) return const SizedBox.shrink();

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            centredColumn(l10n.workcenter),
            centredColumn(l10n.simContributed),
            centredColumn(l10n.simShareOfFlow),
          ],
          rows: [
            for (final station in metrics.byContribution)
              DataRow(
                cells: [
                  centredText(station.name),
                  centredText(_duration(l10n, station.contributedTime)),
                  centredText(_percent(metrics.shareOfFlow(station))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PartsTable extends StatelessWidget {
  const _PartsTable({required this.metrics});

  final RunMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (metrics.parts.isEmpty) return const SizedBox.shrink();

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            centredColumn(l10n.demandPartNumber),
            centredColumn(l10n.simOrders),
            centredColumn(l10n.simDelivered),
            centredColumn(l10n.simOnTime),
            centredColumn(l10n.simAverageLeadTime),
            centredColumn(l10n.simAverageFloat),
          ],
          rows: [
            for (final part in metrics.parts)
              DataRow(
                cells: [
                  centredText(part.partNumber),
                  centredText('${part.orders}'),
                  centredText('${part.delivered}'),
                  centredText('${part.onTime}'),
                  centredText(_duration(l10n, part.averageLeadTime)),
                  centredText(_duration(l10n, part.averageFloat)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.detail});

  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.bodyLarge),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Why a study cannot run (DESIGN.md §11).
String simProblemLabel(AppLocalizations l10n, SimAssemblyProblem problem) =>
    switch (problem) {
      SimAssemblyProblem.noTakt => l10n.simProblemNoTakt,
      SimAssemblyProblem.noOrders => l10n.simProblemNoOrders,
      SimAssemblyProblem.unboundStep => l10n.simProblemUnboundStep,
      SimAssemblyProblem.noPaceSetter => l10n.simProblemNoPaceSetter,
    };

/// A dash rather than a zero where there is no figure: a zero is a number
/// someone will add up (§11).
String _duration(AppLocalizations l10n, Duration? value) =>
    value == null ? '—' : formatAdaptiveDuration(l10n, value);

String _percent(double? value) =>
    value == null ? '—' : '${(value * 100).toStringAsFixed(0)}%';
