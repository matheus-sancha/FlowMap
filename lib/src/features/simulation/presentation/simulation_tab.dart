import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/date_style_scope.dart';
import '../../../common/dialogs.dart';
import '../../../common/part_palette.dart';
import '../../../common/result_table.dart';
import '../../../common/unit_labels.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/run_filter.dart';
import '../application/run_metrics.dart';
import '../application/sim_assembly.dart';
import '../application/sim_result.dart';
import '../application/simulation_providers.dart';
import '../data/simulation_runs_repository.dart';
import 'gantt_view.dart';
import 'plan_excel.dart';

/// The project's stored runs: open an earlier one, or delete one (§7.10).
///
/// A run is ~4k rows for 500 orders, and nothing else in the app will ever
/// remove one — so the list that makes them reachable is also the only place
/// that can let them go.
class RunsMenu extends ConsumerWidget {
  const RunsMenu({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dateStyle = DateStyleScope.of(context);
    final runs =
        ref.watch(projectRunsProvider(projectId)).value ?? const <RunListing>[];
    if (runs.isEmpty) return const SizedBox.shrink();

    // The date, what the run dispatched by when every station agreed — `mixed`
    // when they did not (§7.3) — and the takt it ran at (§7.7.2). The takt is
    // what tells two runs of one study apart in the menu, which is what makes
    // "run it twice and compare" (§7.7) legible without opening each. A full
    // breakdown does not fit a menu row; the per-station list is on the run
    // header the row opens.
    String label(RunListing listing) {
      final date = dateStyle.format(listing.run.createdAt);
      final queues = runQueueLabel(l10n, listing.queues);
      final head = queues == null ? date : l10n.simRunLabel(date, queues);
      final takt = taktLabelForValues(l10n, listing.takts);
      return takt == null ? head : '$head  ·  $takt';
    }

    return PopupMenuButton<({String runId, bool delete})>(
      tooltip: l10n.simEarlierRuns,
      icon: const Icon(Icons.history),
      onSelected: (action) async {
        final runner = ref.read(simulationRunnerProvider(projectId).notifier);
        if (!action.delete) return runner.show(action.runId);

        final run = runs.firstWhere((r) => r.run.id == action.runId);
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
        for (final listing in runs)
          PopupMenuItem(
            value: (runId: listing.run.id, delete: false),
            child: Row(
              children: [
                Expanded(child: Text(label(listing))),
                const SizedBox(width: 12),
                // In the row rather than a second menu: the run being deleted
                // is the one being read, and a delete two levels away from it
                // is a delete aimed at the wrong one.
                IconButton(
                  tooltip: l10n.actionDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop((runId: listing.run.id, delete: true)),
                ),
              ],
            ),
          ),
      ],
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
/// card, three tables and a fourteen-column plan, and it would have needed a
/// height cap, a second vertical scrollbar and a nested scroll to fit there.
///
/// Held in an `IndexedStack`, so switching to the results and back returns the
/// zoom the reader left rather than refitting the chart under them.
///
/// **One screen shows it now.** It was public because two did — a study's
/// Simulation tab and the project's workspace — and the whole argument for
/// `run_filter.dart` was that two screens reading one `StoredRun` through one
/// filter could not report different numbers for the same study. The tab is
/// gone and the filter is what replaced it: a study reaches its slice through
/// `?study=` on the workspace's route, so the guarantee is now structural
/// rather than maintained (§12.1).
class RunResults extends StatefulWidget {
  const RunResults({super.key, required this.slice, required this.projectName});

  /// The run as this view of it reads (§12.1).
  final FilteredRun slice;

  /// Stamped into the workbook the plan exports to (§13).
  final String projectName;

  @override
  State<RunResults> createState() => _ResultsState();
}

class _ResultsState extends State<RunResults> {
  var _view = _RunView.results;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final slice = widget.slice;
    // The header, the abort banner and the horizon warning describe *the run*
    // rather than a view of it, so they read the unfiltered one.
    final run = slice.run;

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
              // Beneath the abort banner and above the headline, because it
              // qualifies every figure below it rather than replacing them.
              if (run.result.ordersPastHorizon.isNotEmpty) ...[
                _ScheduleTailBanner(result: run.result),
                const SizedBox(height: 12),
              ],
              _Headline(metrics: slice.metrics),
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
                child: _ResultTables(
                  slice: slice,
                  projectName: widget.projectName,
                ),
              ),
              GanttView(slice: slice),
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
    final dateStyle = DateStyleScope.of(context);

    final date = dateStyle.format(run.createdAt);
    final queues = runQueueLabel(l10n, run.queues);

    // **What it ran at, read off the orders rather than the study rows**
    // (§7.9). A study row carries the takt of its *first* release, which was
    // the whole run's until an order took the takt in force when it opened —
    // so a run that crossed 1 April reads `4 → 5 days` here and the study row
    // would have said `4 days` and stopped.
    //
    // Falls back to the study rows where no order carries one, which is every
    // run stored before v22: those really did hold one takt throughout.
    final sequences = taktSequences([
      for (final order in run.result.orders)
        (
          studyId: order.studyId,
          at: order.released,
          value: order.taktValue,
          unit: order.taktUnit?.name,
        ),
    ]);
    final takt = sequences.isEmpty
        ? runTaktLabel(l10n, run.studies)
        : taktLabelForValues(l10n, sequences);

    // Studies whose cadence ran out before their sequence did (§7.9.2). Named
    // rather than counted: a missing schedule row and a jammed plant produce
    // the same unreleased orders and want opposite responses.
    final stalled = [
      for (final study in run.studies)
        if (study.cadenceEndedAt case final at?)
          (
            name: study.name,
            at: at,
            unopened: run.result.orders
                .where((o) => o.studyId == study.studyId && o.released == null)
                .length,
          ),
    ];
    // Only where the change actually falls inside what this run covered. The
    // column records the schedule's next change after the run's start (§7.7.3),
    // and a change three years after the last order is not this run's caveat.
    final taktChange = run.studies
        .map((s) => s.nextTaktChange)
        .nonNulls
        .where((at) => at.isBefore(run.result.end))
        .fold<DateTime?>(
          null,
          (earliest, at) =>
              earliest == null || at.isBefore(earliest) ? at : earliest,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${queues == null ? date : l10n.simRunLabel(date, queues)}'
          '  ·  '
          '${l10n.simRunSpan(dateStyle.format(run.result.start), dateStyle.format(run.result.end))}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        // **What this run ran at, and when that stops being true** (§7.7.2,
        // §7.7.3). A run keeps one cadence throughout (§18.3), so the takt is
        // the parameter the whole experiment turns on — and until v20 a stored
        // run could not say it, which is why a Gantt drawn at one takt could not
        // be told from a Gantt drawn at another.
        //
        // A line rather than an icon, deliberately: the same caveat lived behind
        // a hover on the map and cost an evening.
        if (takt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                l10n.simRunTakt(takt),
                if (taktChange != null)
                  l10n.simRunTaktChanges(dateStyle.format(taktChange)),
              ].join('  ·  '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: taktChange == null
                    ? theme.colorScheme.outline
                    : theme.colorScheme.tertiary,
              ),
            ),
          ),
        // **A study that stopped opening orders for want of a takt** (§7.9.2).
        // §11.1's horizon warning cannot stand in for this: it compares the
        // run's *end* against the horizon, and a run that stops releasing early
        // may well end before it with the warning silent. In the tertiary
        // colour, like the takt caveat, because it qualifies every figure
        // beneath it.
        for (final study in stalled)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.simRunCadenceEnded(
                study.name,
                dateStyle.format(study.at),
                study.unopened,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
        // Which station dispatched by what, and only when they disagree. A
        // header saying `mixed` without saying what the mixture was tells the
        // reader the run is not one thing without telling them what it is;
        // repeating one shared rule per station would be the same word ten
        // times (§7.3).
        if (run.queues.isMixed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                for (final station in run.queues.stations)
                  l10n.simRunQueueRow(
                    station.name,
                    dispatchRuleLabel(l10n, station.rule),
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
  const _ResultTables({required this.slice, required this.projectName});

  final FilteredRun slice;
  final String projectName;

  StoredRun get run => slice.run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final metrics = slice.metrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricsCard(metrics: metrics),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(l10n.simByQueue, style: theme.textTheme.titleSmall),
            // **Said, not left to be inferred.** Order-level figures above
            // follow the filter and these do not, because utilisation's
            // denominator is a run total and the run does not carry what a
            // windowed one would need (§12.1). A reader comparing a filtered
            // count against an unfiltered utilisation would otherwise be
            // comparing two different plants.
            if (slice.stationsAreWholeRun) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l10n.simStationsWholeRun,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
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
        _PartsTable(slice: slice),
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
            if (slice.plan.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.table_view_outlined, size: 18),
                label: Text(l10n.exportExcel),
                // The slice, not the run: the button is under this table and
                // exports this table (§12.1).
                onPressed: () => exportPlanExcel(
                  context,
                  run: run,
                  plan: slice.plan,
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
        _ProductionPlan(slice: slice),
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
  const _ProductionPlan({required this.slice});

  /// **The slice, not the run.** `FilteredRun` has computed the filtered plan
  /// since the combined view was built and nothing ever read it — this table
  /// took `run.plan` and listed every order in the project under whatever
  /// filter was set (§12.1).
  final FilteredRun slice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (slice.plan.isEmpty) return const SizedBox.shrink();

    // Study id → the name it had when the run was made (§7.10), so a study
    // renamed since still reads as the one that ran. A lookup over the whole
    // run; which of them get a section is decided by the rows below.
    final names = {
      for (final study in slice.run.studies) study.studyId: study.name,
    };

    final byStudy = <String, List<PlanEntry>>{};
    for (final row in slice.plan) {
      byStudy.putIfAbsent(row.studyId, () => []).add(row);
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

  final List<PlanEntry> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dateStyle = DateStyleScope.of(context);

    String date(DateTime? value) =>
        value == null ? '—' : dateStyle.format(value);

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
          // **What the order opened under** (§7.9), introducing the three
          // figures it explains rather than sitting among the dates: an order's
          // work at each station is the balance's split against this, so two
          // rows of one part with different Theoretical LTs differ here first.
          //
          // Blank on a run stored before v22, which held one takt throughout
          // and said so on its header instead.
          ResultColumn(label: l10n.simPlanTakt, width: 110),
          // Theoretical first: it is the baseline, and the actual beside it
          // is read against it. The gap between the two is the queueing.
          ResultColumn(label: l10n.simPlanTheoreticalLeadTime, width: 130),
          ResultColumn(label: l10n.simPlanActualLeadTime, width: 120),
          // The ratio of the two beside them (§8.7). The card's headline drops
          // the warm-up orders so it can be compared between runs; this column
          // keeps every row, which is where the ramp those orders form becomes
          // visible instead of being averaged away.
          ResultColumn(label: l10n.simPlanLeadTimeEfficiency, width: 120),
          ResultColumn(label: l10n.simAverageFloat, width: 130),
        ],
        rowCount: rows.length,
        cellAt: (index, column) {
          final row = rows[index];
          // A slot that produced nothing has no part, no numbers and no
          // outcome — only when it came round and which gate held it. It takes
          // the Order Start column, because that is the moment it happened.
          if (row is PlanEmptySlot) {
            return switch (column) {
              1 => Text(
                emptySlotReasonLabel(l10n, row.reason),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
              8 => Text(
                date(row.slotAt),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              _ => const Text(''),
            };
          }
          row as ProductionPlanRow;

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
            10 => Text(
              row.outcome.taktValue == null || row.outcome.taktUnit == null
                  ? '—'
                  : taktLabel(
                      l10n,
                      row.outcome.taktValue!,
                      row.outcome.taktUnit!,
                    ),
            ),
            11 => Text(_duration(l10n, row.theoreticalLeadTime)),
            12 => Text(_duration(l10n, row.actualLeadTime)),
            13 => Text(
              row.leadTimeEfficiency == null
                  ? '—'
                  : '${(row.leadTimeEfficiency! * 100).toStringAsFixed(0)}%',
            ),
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

/// The run went past the last schedule anyone defined (DESIGN.md §11.1).
///
/// **A warning rather than an error.** Schedule periods are finite while a run
/// goes until the last order completes, so refusing here would make an
/// overloaded plant unsimulatable exactly when the simulation is most
/// informative — and the reader cannot know how far to extend their periods
/// until they have run it. What the app owes them is to say which figures are
/// standing on capacity nobody defined.
class _ScheduleTailBanner extends StatelessWidget {
  const _ScheduleTailBanner({required this.result});

  final SimRunResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dateStyle = DateStyleScope.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(
          Icons.event_busy_outlined,
          color: theme.colorScheme.tertiary,
        ),
        title: Text(
          l10n.simScheduleTail(
            result.ordersPastHorizon.length,
            dateStyle.format(result.scheduleHorizon),
          ),
        ),
        subtitle: Text(l10n.simScheduleTailHelp),
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
              // A percentage, not a `×` multiple: the figure reads "how much of
              // the standard did the flow beat", and above 100 % is good
              // (§8.7). Printed as `0.73×` it read as a low number for a flow
              // that was running well, which is how a metric shipped upside
              // down and stayed that way.
              value: metrics.leadTimeEfficiency == null
                  ? '—'
                  : '${(metrics.leadTimeEfficiency! * 100).toStringAsFixed(0)}%',
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
/// A station, and the pool it ran in where the run recorded one (DESIGN.md
/// §3.1).
///
/// **Beside the name rather than as a grouping**, which is where this differs
/// from the Gantt. §8.1's two tables *are* rankings — the first row is the
/// station that queued most — and clustering a pool's members together would
/// mean the top row was no longer the answer to the question the table asks.
/// The Gantt has no such ordering to lose: it goes down the page in flow order,
/// where a pool's machines already sit together.
///
/// A station reached through more than one pool carries both names and belongs
/// to neither, which is exactly what the run stored (§7.10).
class _StationName extends StatelessWidget {
  const _StationName({required this.station});

  final WorkcenterRunMetrics station;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pool = station.poolName;
    if (pool == null) return Text(station.name);

    // One line, because a `DataTable` row is a fixed height and a second line
    // would be clipped rather than shown.
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: station.name),
          TextSpan(
            text: '  $pool',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

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
          // Wider than it was, for the pool a station ran in (§3.1).
          ResultColumn(label: l10n.workcenter, width: 210),
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
            0 => _StationName(station: station),
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
          ResultColumn(label: l10n.workcenter, width: 210),
          ResultColumn(label: l10n.simContributed, width: 160),
          ResultColumn(label: l10n.simShareOfFlow, width: 140),
        ],
        rowCount: metrics.byContribution.length,
        cellAt: (index, column) {
          final station = metrics.byContribution[index];
          return switch (column) {
            0 => _StationName(station: station),
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
  const _PartsTable({required this.slice});

  /// **The slice, not the run.** This table read `run.metrics` and so reported
  /// every part in the project while the headline above it reported the
  /// filtered ones — a page disagreeing with itself, which is worse than a
  /// filter that does nothing at all (§12.1).
  final FilteredRun slice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metrics = slice.metrics;
    if (metrics.parts.isEmpty) return const SizedBox.shrink();

    // The names the studies had when the run was made (§7.10), so a study
    // renamed since still reads as the one that ran — as `_ProductionPlan`
    // does with the same map. Read from the whole run because it is a lookup:
    // what narrows is which of them appear, which is the line below.
    final names = {
      for (final study in slice.run.studies) study.studyId: study.name,
    };
    // The slice's studies, so filtering to one line drops the column that would
    // then hold the same answer on every row (§8.1.2).
    final showStudy = slice.studyIds.length > 1;

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
