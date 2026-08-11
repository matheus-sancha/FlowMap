import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/date_input.dart';
import '../../../common/dialogs.dart';
import '../../../common/part_palette.dart';
import '../../../common/result_table.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/run_metrics.dart';
import '../application/sim_assembly.dart';
import '../application/sim_model.dart';
import '../application/sim_result.dart';
import '../application/simulation_providers.dart';
import '../data/simulation_runs_repository.dart';
import 'gantt_view.dart';
import 'plan_excel.dart';

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
  const _RunBar({
    required this.project,
    required this.input,
    required this.busy,
  });

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
                  onPressed: () =>
                      Navigator.of(context).pop((runId: run.id, delete: true)),
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

    // A Column rather than the single scrolling page this was, because the
    // Gantt takes the body's full height (§8.6) and a child of a `ListView`
    // cannot. The readiness panel stays above whatever the body turns out to
    // be: it is about the *next* run, not about the one being read.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!input.canRun)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _ReadinessPanel(input: input),
          ),
        Expanded(
          child: switch (runner) {
            AsyncError(:final error) => SingleChildScrollView(
              child: _Message(icon: Icons.error_outline, title: '$error'),
            ),
            AsyncLoading() => const Center(child: CircularProgressIndicator()),
            AsyncValue(value: null) => SingleChildScrollView(
              child: _Message(
                icon: Icons.timeline_outlined,
                title: l10n.simulationNeverRun,
                detail: l10n.simulationNeverRunHelp,
              ),
            ),
            AsyncValue(value: final run!) => _Results(
              run: run,
              projectName: project.name,
            ),
          },
        ),
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

/// Which of the two views of a run is showing.
enum _RunView { results, gantt }

/// Everything §8 asks a run to report, in two views of it.
///
/// **The run header, the abort banner and the headline stay put**, because they
/// describe *the run* rather than a view of it; the segmented control switches
/// only the body beneath them. That is what lets the Gantt take the full body
/// height — it was a section below the production plan in the first draft, which
/// was one more block on a page already carrying a header, a headline, a metrics
/// card, three tables and a thirteen-column plan, and it would have needed a
/// height cap, a second vertical scrollbar and a nested scroll to fit there.
///
/// Held in an `IndexedStack`, so switching to the results and back returns the
/// zoom the reader left rather than refitting the chart under them.
class _Results extends StatefulWidget {
  const _Results({required this.run, required this.projectName});

  final StoredRun run;

  /// Stamped into the workbook the plan exports to (§13).
  final String projectName;

  @override
  State<_Results> createState() => _ResultsState();
}

class _ResultsState extends State<_Results> {
  var _view = _RunView.results;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final run = widget.run;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RunHeader(run: run),
              const SizedBox(height: 12),
              if (run.result.abort != null) ...[
                _AbortBanner(result: run.result),
                const SizedBox(height: 12),
              ],
              _Headline(metrics: run.metrics),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<_RunView>(
                  segments: [
                    ButtonSegment(
                      value: _RunView.results,
                      label: Text(l10n.simResultsView),
                      icon: const Icon(Icons.table_rows_outlined),
                    ),
                    ButtonSegment(
                      value: _RunView.gantt,
                      label: Text(l10n.simGanttView),
                      icon: const Icon(Icons.view_timeline_outlined),
                    ),
                  ],
                  selected: {_view},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      setState(() => _view = selection.first),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _view.index,
            sizing: StackFit.expand,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _ResultTables(run: run, projectName: widget.projectName),
              ),
              GanttView(run: run),
            ],
          ),
        ),
      ],
    );
  }
}

/// When the run was made, what it ran under, and where it sat in time.
class _RunHeader extends StatelessWidget {
  const _RunHeader({required this.run});

  final StoredRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

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
      ],
    );
  }
}

/// The metrics card and the four tables — what the Results view is.
class _ResultTables extends StatelessWidget {
  const _ResultTables({required this.run, required this.projectName});

  final StoredRun run;
  final String projectName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final metrics = run.metrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        _PartsTable(run: run),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.simProductionPlan,
                style: theme.textTheme.titleSmall,
              ),
            ),
            // Beside the thing it exports rather than on the tab's chrome: the
            // plan is one of several tables here, and a project-level export
            // button would not say which one it takes (§13).
            if (run.plan.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.table_view_outlined, size: 18),
                label: Text(l10n.exportExcel),
                onPressed: () => exportPlanExcel(
                  context,
                  run: run,
                  projectName: projectName,
                ),
              ),
          ],
        ),
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
      child: resultTable(
        columns: [
          ResultColumn(label: l10n.simPlanOrder, width: 72),
          ResultColumn(label: l10n.demandPartNumber, width: 130),
          ResultColumn(label: l10n.demandDescription, width: 210),
          ResultColumn(label: l10n.demandProject, width: 140),
          ResultColumn(label: l10n.demandBatchNumber, width: 120),
          ResultColumn(label: l10n.demandBatchSize, width: 110),
          ResultColumn(label: l10n.demandNeedDate, width: 120),
          ResultColumn(label: l10n.demandMaterialDate, width: 130),
          ResultColumn(label: l10n.simPlanOrderStart, width: 120),
          ResultColumn(label: l10n.simPlanOrderEnd, width: 120),
          // Theoretical first: it is the baseline, and the actual beside it
          // is read against it. The gap between the two is the queueing.
          ResultColumn(label: l10n.simPlanTheoreticalLeadTime, width: 130),
          ResultColumn(label: l10n.simPlanActualLeadTime, width: 120),
          ResultColumn(label: l10n.simAverageFloat, width: 130),
        ],
        rowCount: rows.length,
        cellAt: (index, column) {
          final row = rows[index];
          return switch (column) {
            0 => Text('${row.orderNumber}'),
            1 => Text(row.partNumber),
            2 => _Description(text: row.partDescription),
            // Blank throughout means a run made before schema v12, which did
            // not record any of this (§16.13). A dash, never a guess.
            3 => Text(
              (row.customerProject?.isEmpty ?? true)
                  ? '—'
                  : row.customerProject!,
            ),
            4 => Text(
              (row.batchNumber?.isEmpty ?? true) ? '—' : row.batchNumber!,
            ),
            5 => Text(row.batchSize == null ? '—' : '${row.batchSize}'),
            6 => Text(date(row.outcome.needDate)),
            7 => Text(date(row.materialDate)),
            8 => Text(date(row.orderStart)),
            9 => Text(date(row.delivery)),
            10 => Text(_duration(l10n, row.theoreticalLeadTime)),
            11 => Text(_duration(l10n, row.actualLeadTime)),
            // The one figure here that is a verdict rather than a fact, so
            // late is coloured. Positive is early (§8).
            _ => Text(
              _duration(l10n, row.float),
              style: (row.float?.isNegative ?? false)
                  ? theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    )
                  : null,
            ),
          };
        },
      ),
    );
  }
}

/// The plan's Description cell: ellipsised, whole text on hover.
///
/// The cap used to live here, because a `DataTable` sized every column to its
/// widest cell and one long description would push Float off the right edge for
/// all 33 rows. §12.6 declares the column's width instead, so the cell no longer
/// has to defend itself — what is left is the part §5.4 decided for a node's
/// notes: show that there is more, and put the words where asking for them
/// costs nothing.
///
/// A blank is a dash, and means two things that read the same: nobody typed a
/// description, or the run predates v13 and did not record one (§16.14).
class _Description extends StatelessWidget {
  const _Description({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final value = text;
    if (value == null || value.isEmpty) return const Text('—');

    // Unconditional, including on a description short enough to be fully
    // visible. Showing it only when truncated would mean measuring the text
    // against the column on every build to save the reader a tooltip that
    // repeats what they can already read, which is not worth a TextPainter.
    return Tooltip(
      message: value,
      child: Text(value, overflow: TextOverflow.ellipsis, maxLines: 1),
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
      child: resultTable(
        columns: [
          ResultColumn(label: l10n.workcenter, width: 160),
          ResultColumn(label: l10n.utilization, width: 120),
          ResultColumn(label: l10n.simQueue, width: 130),
          ResultColumn(label: l10n.simQueueAverage, width: 130),
          // Beside utilization rather than folded into it: a station at 40 %
          // and blocked half the run is a different plant from one at 40 % and
          // idle, and only the first is fixed downstream (§8.3).
          ResultColumn(label: l10n.simBlocked, width: 130),
          ResultColumn(label: l10n.simVisits, width: 100),
          ResultColumn(label: l10n.simChangeovers, width: 130),
        ],
        rowCount: metrics.workcenters.length,
        cellAt: (index, column) {
          final station = metrics.workcenters[index];
          return switch (column) {
            0 => Text(station.name),
            1 => Tooltip(
              message: l10n.simUtilizationHelp,
              child: Text(_percent(station.utilization)),
            ),
            2 => Text(_duration(l10n, station.queueTime)),
            3 => Text(_duration(l10n, station.averageQueue)),
            4 => Tooltip(
              message: l10n.simBlockedHelp,
              child: Text(_duration(l10n, station.blocked)),
            ),
            5 => Text('${station.visits}'),
            _ => Text('${station.changeovers}'),
          };
        },
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
      child: resultTable(
        columns: [
          ResultColumn(label: l10n.workcenter, width: 160),
          ResultColumn(label: l10n.simContributed, width: 160),
          ResultColumn(label: l10n.simShareOfFlow, width: 140),
        ],
        rowCount: metrics.byContribution.length,
        cellAt: (index, column) {
          final station = metrics.byContribution[index];
          return switch (column) {
            0 => Text(station.name),
            1 => Text(_duration(l10n, station.contributedTime)),
            _ => Text(_percent(metrics.shareOfFlow(station))),
          };
        },
      ),
    );
  }
}

/// How each part fared (§8.1.2).
///
/// **The Study column appears only when the run carries more than one**, which
/// is §8.5's rule for the plan's headings: a single-study run has one answer in
/// every row, and a column of it says nothing the tab has not said. It is not
/// decoration when there are two — a part number identifies a part only inside
/// its study (§16.15), so two lines' `PN2` are two parts, and this is the only
/// thing on the row that tells them apart.
class _PartsTable extends StatelessWidget {
  const _PartsTable({required this.run});

  final StoredRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metrics = run.metrics;
    if (metrics.parts.isEmpty) return const SizedBox.shrink();

    // The names the studies had when the run was made (§7.10), so a study
    // renamed since still reads as the one that ran — as `_ProductionPlan`
    // does with the same map.
    final names = {for (final study in run.studies) study.studyId: study.name};
    final showStudy = run.studies.length > 1;

    return Card(
      child: resultTable(
        columns: [
          // Wider than the other tables' part number column by the width of
          // the swatch and its gap, so the number itself has the room it had
          // before the legend moved in.
          ResultColumn(label: l10n.demandPartNumber, width: 172),
          if (showStudy) ResultColumn(label: l10n.study, width: 150),
          ResultColumn(label: l10n.simOrders, width: 100),
          ResultColumn(label: l10n.simDelivered, width: 110),
          ResultColumn(label: l10n.simOnTime, width: 100),
          ResultColumn(label: l10n.simAverageLeadTime, width: 150),
          ResultColumn(label: l10n.simAverageFloat, width: 130),
        ],
        rowCount: metrics.parts.length,
        cellAt: (index, column) {
          final part = metrics.parts[index];
          // Everything after Part Number shifts right by one when the Study
          // column is there, so the switch is written against the position the
          // column would have without it.
          final slot = showStudy && column > 0 ? column - 1 : column;
          if (showStudy && column == 1) {
            return Text(names[part.studyId] ?? part.studyId);
          }
          return switch (slot) {
            // The swatch is the legend (§8.6). It is defined here, beside that
            // part's orders, on-time and lead-time figures, so the reader
            // learns the mapping while reading the numbers rather than from a
            // strip that says nothing else.
            0 => _PartSwatch(index: index, partNumber: part.partNumber),
            1 => Text('${part.orders}'),
            2 => Text('${part.delivered}'),
            3 => Text('${part.onTime}'),
            4 => Text(_duration(l10n, part.averageLeadTime)),
            _ => Text(_duration(l10n, part.averageFloat)),
          };
        },
      ),
    );
  }
}

/// A part number with the colour it is drawn in (§8.6).
///
/// [index] is the row's position in `metrics.parts`, which **is** the part's
/// position in the run's sorted part list — the thing `partColour` is keyed on.
/// Taking it from the row rather than searching for the part is what keeps the
/// swatch here and the bar on the chart the same colour by construction.
///
/// Outlined, because eight fills at one luminance sit close to the dark theme's
/// card and a bare square of colour reads as a smudge against it. The outline
/// is the surface's own, so it disappears into whatever it is drawn on.
class _PartSwatch extends StatelessWidget {
  const _PartSwatch({required this.index, required this.partNumber});

  final int index;
  final String partNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: partColour(index).fill,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(width: 8),
        Text(partNumber),
      ],
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
