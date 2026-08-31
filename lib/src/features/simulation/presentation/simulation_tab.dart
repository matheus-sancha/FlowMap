import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/date_style_scope.dart';
import '../../../common/dialogs.dart';
import '../../../common/part_palette.dart';
import '../../../common/result_table.dart';
import '../../../common/unit_labels.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../projects/presentation/workspace_tabs.dart';
import '../application/run_filter.dart';
import '../application/run_metrics.dart';
import '../application/sim_assembly.dart';
import '../application/sim_result.dart';
import '../application/simulation_providers.dart';
import '../data/simulation_runs_repository.dart';
import '../../../data/database/database.dart';
import 'float_matrix_table.dart';
import 'gantt_view.dart';
import 'occupation_view.dart';
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

/// Everything §8 asks a run to report, in **five tabs of one destination**
/// (#7).
///
/// **The run header, the abort banner and the headline stay put**, because they
/// describe *the run* rather than a view of it; the strip switches only the body
/// beneath them. That is what lets the Gantt take the full body height — it was
/// a section below the production plan in the first draft, which would have
/// needed a height cap, a second vertical scrollbar and a nested scroll to fit.
///
/// **Five tabs, from three views and a scrolling page.** The production plan and
/// the float matrix were sections inside the Results view, stacked under three
/// tables; each is now a tab of its own, which is what lets the plan be a table
/// rather than a block on a page — wrapped in that scrolling column it inherited
/// `resultTableMaxHeight`'s 360 px cap and used a third of a tall window.
///
/// **The tab is the location, not this object's state.** It was
/// `var _view = _RunView.results` behind a `SegmentedButton`, so three screens
/// had no URL. `IndexedStack` still holds all five, so switching away and back
/// returns the zoom the reader left rather than refitting the chart under them.
///
/// **One screen shows it.** It was public because two did — a study's Simulation
/// tab and the project's workspace — and the whole argument for
/// `run_filter.dart` was that two screens reading one `StoredRun` through one
/// filter could not report different numbers. The tab is gone and the filter is
/// what replaced it (§12.1).
class RunResults extends StatelessWidget {
  const RunResults({
    super.key,
    required this.slice,
    required this.projectName,
    required this.project,
    required this.tab,
  });

  /// The project whose float thresholds colour §10.4's matrix.
  final Project project;

  /// The run as this view of it reads (§12.1).
  final FilteredRun slice;

  /// Stamped into the workbook the plan exports to (§13).
  final String projectName;

  /// Which tab the location names (#7).
  final SimulationTab tab;

  @override
  Widget build(BuildContext context) {
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
            ],
          ),
        ),
        _ResultsTabBar(project: project, tab: tab),
        Expanded(
          child: IndexedStack(
            index: tab.index,
            sizing: StackFit.expand,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: _Overview(slice: slice),
              ),
              _PlanTab(
                slice: slice,
                projectName: projectName,
                run: run,
              ),
              GanttView(slice: slice),
              OccupationView(slice: slice, project: project),
              _FloatTab(slice: slice, project: project),
            ],
          ),
        ),
      ],
    );
  }
}

/// The five tabs, each of them a location (#7).
///
/// Scrollable for the same reason the study strip is: five labels of this length
/// do not fit a narrow window, and a tab falling off the end is a screen with no
/// way to it.
class _ResultsTabBar extends StatefulWidget {
  const _ResultsTabBar({required this.project, required this.tab});

  final Project project;
  final SimulationTab tab;

  @override
  State<_ResultsTabBar> createState() => _ResultsTabBarState();
}

class _ResultsTabBarState extends State<_ResultsTabBar>
    with SingleTickerProviderStateMixin {
  /// Paints the indicator and nothing else — the location decides which tab is
  /// showing, and `onTap` navigates. Driven *from* the route on every build.
  late final TabController _tabs = TabController(
    length: SimulationTab.values.length,
    initialIndex: widget.tab.index,
    vsync: this,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_tabs.index != widget.tab.index) _tabs.index = widget.tab.index;

    return TabBar(
      controller: _tabs,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      // **`?study=` is carried across**, or moving between tabs would silently
      // widen a reader's filter from one study to the whole run.
      onTap: (index) {
        final study = GoRouterState.of(context).uri.queryParameters['study'];
        context.go(
          '/projects/${widget.project.id}/simulation'
          '/${SimulationTab.values[index].slug}'
          '${study == null ? '' : '?study=$study'}',
        );
      },
      tabs: [
        // The destination is *Simulation results* and this tab is *Simulation
        // Overview*, deliberately not the same words — so the way in and the
        // first thing inside never read as one thing (#7).
        Tab(text: l10n.simTabOverview),
        Tab(text: l10n.simTabPlan),
        Tab(text: l10n.simGanttView),
        Tab(text: l10n.occupationView),
        Tab(text: l10n.floatMatrixTitle),
      ],
    );
  }
}

/// The metrics card, the studies the run covers, and the three station tables.
///
/// **The paired layout** (#7): Queue and Share side by side, because §8.1 makes
/// them one ranking read two ways, with Parts full width beneath. Collapses back
/// to stacked under 1100 px, where two half-width tables are two cramped ones.
/// *Rejected: stacked, and a card-per-table grid.*
class _Overview extends StatelessWidget {
  const _Overview({required this.slice});

  final FilteredRun slice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final metrics = slice.metrics;

    final queue = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(l10n.simByQueue, style: theme.textTheme.titleSmall),
            // **Said, not left to be inferred.** Order-level figures follow the
            // filter and these do not, because utilisation's denominator is a
            // run total and the run does not carry what a windowed one would
            // need (§12.1). A reader comparing a filtered count against an
            // unfiltered utilisation would be comparing two different plants.
            //
            // *Rejected: repeating it on the filter bar* — a note on a bar that
            // is usually irrelevant is a note people stop reading. It belongs
            // beside the numbers that would be misread.
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
      ],
    );

    final share = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.simByShare, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _ShareTable(metrics: metrics),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricsCard(metrics: metrics),
        const SizedBox(height: 24),
        _RunCoverage(slice: slice),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 1100
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [queue, const SizedBox(height: 24), share],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: queue),
                    const SizedBox(width: 24),
                    Expanded(child: share),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        Text(l10n.simPerPart, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _PartsTable(slice: slice),
      ],
    );
  }
}

/// Which studies this run covers, and which of them the filter is showing (#7).
///
/// **`StoredRun.studies` already held this and nothing showed it.** A reader
/// looking at a filtered page had no way to tell a study that was never in the
/// run from one their own filter had excluded — two very different statements
/// that drew identically.
class _RunCoverage extends StatelessWidget {
  const _RunCoverage({required this.slice});

  final FilteredRun slice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final studies = slice.run.studies;
    if (studies.isEmpty) return const SizedBox.shrink();

    // Which studies still have a figure after the filter — read off the
    // per-part rows, which is where a study's presence in the slice actually
    // shows.
    final shown = {for (final part in slice.metrics.parts) part.studyId};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.simRunCovers, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final study in studies)
              if (shown.contains(study.studyId))
                Chip(
                  avatar: const Icon(Icons.check, size: 16),
                  label: Text(study.name),
                )
              else
                // Greyed and explained, rather than absent: a study missing
                // from a list is indistinguishable from one that was never in
                // the run, which is the thing this row exists to say.
                Chip(
                  label: Text(
                    '${study.name} — ${l10n.simRunCoversFiltered}',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  backgroundColor: Colors.transparent,
                ),
          ],
        ),
      ],
    );
  }
}

/// §10.4's matrix, on a tab of its own (#7).
///
/// It was the last section of a scrolling page, beneath the plan — *"the plan's
/// own Float column read a second way"*, which is true and is why it is the tab
/// next to the plan rather than a place elsewhere.
class _FloatTab extends StatelessWidget {
  const _FloatTab({required this.slice, required this.project});

  final FilteredRun slice;
  final Project project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.floatMatrixHelp,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: FloatMatrixTable(slice: slice, project: project),
            ),
          ),
        ],
      ),
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

/// The production plan, on a tab of its own, read one of two ways (#7).
///
/// **The plan is a table, not a page.** It was the fourth section of the
/// scrolling Results view, where it inherited `resultTableMaxHeight`'s 360 px
/// cap and used a third of a tall window. Here the heading and the export pin,
/// and the rows take everything below.
class _PlanTab extends StatefulWidget {
  const _PlanTab({
    required this.slice,
    required this.projectName,
    required this.run,
  });

  final FilteredRun slice;
  final String projectName;
  final StoredRun run;

  @override
  State<_PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends State<_PlanTab> {
  /// **View state, deliberately not a route.** §12.1 argued the results filters
  /// should not ride in the URL and #7 left that argument standing; this is the
  /// same kind of thing — a way of reading one tab, not a place. `?study=` is
  /// still the one exception, because it is the filter you navigate *from*.
  bool _combined = false;

  /// Start Date ascending by default, which is the order the plan happens in.
  int _sortColumn = 3;
  bool _ascending = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final slice = widget.slice;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // **The help text is capped at two lines, and this was a defect.**
          // Unbounded beside the controls it wrapped to whatever width was
          // left — on a 768 pt pane that was tall enough to push the table out
          // of the column entirely, which `RenderFlex overflowed by 5.0 pixels`
          // is what a test saw. A tab's prose is a caption, not the tab.
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.simProductionPlanHelp,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.simPlanByStudy),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.simPlanCombined),
                  ),
                ],
                selected: {_combined},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    setState(() => _combined = s.first),
              ),
              // Beside the thing it exports rather than on the tab's chrome:
              // a project-level export button would not say which table it
              // takes (§13).
              if (slice.plan.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: Text(l10n.exportExcel),
                  // The slice, not the run: the button is over this table and
                  // exports this table (§12.1).
                  onPressed: () => exportPlanExcel(
                    context,
                    run: widget.run,
                    plan: slice.plan,
                    projectName: widget.projectName,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _combined
                ? _CombinedPlan(
                    slice: slice,
                    sortColumn: _sortColumn,
                    ascending: _ascending,
                    onSort: (column) => setState(() {
                      if (_sortColumn == column) {
                        _ascending = !_ascending;
                      } else {
                        _sortColumn = column;
                        _ascending = true;
                      }
                    }),
                  )
                : SingleChildScrollView(child: _ProductionPlan(slice: slice)),
          ),
        ],
      ),
    );
  }
}

/// Every study's orders in one table, sortable on any column (#7).
///
/// **It carries Study, Cell and Line**, the three things §8.5's sectioning used
/// to say and a flat table would otherwise lose. By study stays the default
/// shape of the tab — a study is one production line and a planner takes the
/// section for their line — and this is for the question sectioning cannot
/// answer: *what is happening across the plant this week?*
///
/// **Why this sorts when #10 says the production plan does not.** The rule is
/// *a surface sorts unless its row order is itself data*, and the two halves of
/// this tab fall on opposite sides of it. **By study**, a section's rows are one
/// study's release sequence — that order *is* the record, and sorting it would
/// produce a plan that looks fine and says something false, which is exactly
/// what #10 rejected. **Combined** has no such order to destroy: three studies
/// release on three independent sequences, so there is no single sequence
/// across them and whatever order the rows arrive in is already a presentation
/// choice. Start Date ascending is the honest default for it.
///
/// So the two are one surface only in the sense that they share a tab. The rule
/// holds unchanged; #7 and #10 do not actually disagree.
class _CombinedPlan extends StatelessWidget {
  const _CombinedPlan({
    required this.slice,
    required this.sortColumn,
    required this.ascending,
    required this.onSort,
  });

  final FilteredRun slice;
  final int sortColumn;
  final bool ascending;
  final ValueChanged<int> onSort;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dateStyle = DateStyleScope.of(context);

    String date(DateTime? value) =>
        value == null ? '—' : dateStyle.format(value);

    // What each study was called, and where it sat, when the run was made
    // (§7.10) — so a study renamed or moved since still reads as the one that
    // ran.
    final studies = {
      for (final study in slice.run.studies) study.studyId: study,
    };

    String cell(PlanEntry row) =>
        studies[row.studyId]?.productionCellName ?? '—';
    String line(PlanEntry row) =>
        studies[row.studyId]?.productionLineName ?? '—';
    String name(PlanEntry row) => studies[row.studyId]?.name ?? row.studyId;

    /// What each sortable column compares.
    Comparable<Object>? keyOf(PlanEntry row, int column) => switch (column) {
      0 => name(row),
      1 => cell(row),
      2 => line(row),
      3 => row.at ?? DateTime(9999),
      4 => row is ProductionPlanRow ? row.orderNumber : null,
      5 => row is ProductionPlanRow ? row.partNumber : null,
      6 => row is ProductionPlanRow ? (row.customerProject ?? '') : null,
      7 => row is ProductionPlanRow ? row.outcome.needDate : null,
      8 => row is ProductionPlanRow ? (row.delivery ?? DateTime(9999)) : null,
      _ => null,
    };

    final rows = [...slice.plan];
    rows.sort((a, b) {
      // **An empty release slot is not an order** (§7.2), so it cannot sort
      // like one. It sorts **last whichever way the arrow points** — it is the
      // absence of an order, not an extreme value of one, and letting it drift
      // to the top under a descending sort would put "nothing happened" above
      // everything that did.
      final aEmpty = a is PlanEmptySlot;
      final bEmpty = b is PlanEmptySlot;
      if (aEmpty != bEmpty) return aEmpty ? 1 : -1;

      final ka = keyOf(a, sortColumn);
      final kb = keyOf(b, sortColumn);
      if (ka == null || kb == null) return 0;
      final order = ka.compareTo(kb);
      return ascending ? order : -order;
    });

    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.outline,
    );

    return resultTable(
      // **No cap and filling the pane**: the plan is the whole tab now, so it
      // is as tall as the window rather than as tall as a section.
      maxHeight: null,
      fill: true,
      sortColumn: sortColumn,
      sortAscending: ascending,
      onSort: onSort,
      columns: [
        ResultColumn(label: l10n.simPlanStudy, width: 140),
        ResultColumn(label: l10n.simPlanCell, width: 130),
        ResultColumn(label: l10n.simPlanLine, width: 130),
        ResultColumn(label: l10n.simPlanOrderStart, width: 120),
        ResultColumn(label: l10n.simPlanOrder, width: 72),
        ResultColumn(label: l10n.demandPartNumber, width: 130),
        ResultColumn(label: l10n.demandProject, width: 140),
        ResultColumn(label: l10n.demandNeedDate, width: 120),
        ResultColumn(label: l10n.simPlanOrderEnd, width: 120),
        ResultColumn(label: l10n.simAverageFloat, width: 130),
      ],
      rowCount: rows.length,
      cellAt: (index, column) {
        final row = rows[index];

        // A slot that produced nothing keeps its study, cell, line and date and
        // shows em-dashes elsewhere, drawn in the outline colour so it reads as
        // an absence rather than a row with missing data.
        if (row is PlanEmptySlot) {
          return switch (column) {
            0 => Text(name(row), style: muted),
            1 => Text(cell(row), style: muted),
            2 => Text(line(row), style: muted),
            3 => Text(date(row.slotAt), style: muted),
            5 => Text(
              emptySlotReasonLabel(l10n, row.reason),
              style: muted?.copyWith(fontStyle: FontStyle.italic),
            ),
            _ => Text('—', style: muted),
          };
        }
        row as ProductionPlanRow;

        return switch (column) {
          0 => Text(name(row)),
          1 => Text(cell(row)),
          2 => Text(line(row)),
          3 => Text(date(row.orderStart)),
          4 => Text('${row.orderNumber}'),
          5 => Text(row.partNumber),
          6 => Text(
            (row.customerProject?.isEmpty ?? true) ? '—' : row.customerProject!,
          ),
          7 => Text(date(row.outcome.needDate)),
          8 => Text(date(row.delivery)),
          // The one figure here that is a verdict rather than a fact, so late
          // is coloured. Positive is early (§8).
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
      // **Sortable** (#10): re-ranking is exactly what a reader comes to §8.1's
      // two rankings to do. It arrives on queue time descending, which is the
      // order `metrics.workcenters` already computed — so the table looks on
      // arrival precisely as it did before it could sort at all.
      child: SortableResultTable<WorkcenterRunMetrics>(
        // The overview pairs Queue and Share side by side (#7), so these
        // take the width they are given rather than leaving half a pane
        // blank. `fill` never narrows a column below its declared width.
        fill: true,
        initialColumn: 2,
        initialAscending: false,
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
        rows: metrics.workcenters,
        sortKeyOf: (station, column) => switch (column) {
          0 => station.name,
          1 => station.utilization,
          2 => station.queueTime,
          3 => station.averageQueue,
          4 => station.blocked,
          5 => station.visits,
          _ => station.changeovers,
        },
        cellAt: (station, column) => switch (column) {
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
      // Sortable for the same reason as the queue ranking, and arriving on the
      // contribution `byContribution` already ordered it by (#10).
      child: SortableResultTable<WorkcenterRunMetrics>(
        // The overview pairs Queue and Share side by side (#7), so these
        // take the width they are given rather than leaving half a pane
        // blank. `fill` never narrows a column below its declared width.
        fill: true,
        initialColumn: 1,
        initialAscending: false,
        columns: [
          ResultColumn(label: l10n.workcenter, width: 210),
          ResultColumn(label: l10n.simContributed, width: 160),
          ResultColumn(label: l10n.simShareOfFlow, width: 140),
        ],
        rows: metrics.byContribution,
        // Share of flow is contributed time over the same total, so the two
        // columns are one ordering — sorting either gives the same rows in the
        // same places, which is honest rather than redundant.
        sortKeyOf: (station, column) => switch (column) {
          0 => station.name,
          _ => station.contributedTime,
        },
        cellAt: (station, column) => switch (column) {
          0 => _StationName(station: station),
          1 => Text(_duration(l10n, station.contributedTime)),
          _ => Text(_percent(metrics.shareOfFlow(station))),
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

    // **The palette index travels with the row** (#10). The swatch is keyed on
    // a part's position in `metrics.parts` — that is what `partColour` reads
    // and what the Gantt draws — so a sorted table handing `_PartSwatch` its
    // *displayed* row would recolour every part the moment a heading was
    // pressed, and the legend would then disagree with the chart it is the
    // legend for. Pairing each part with the index it had is what makes this
    // table safe to sort at all.
    final rows = metrics.parts.indexed.toList();

    return Card(
      child: SortableResultTable<(int, PartMetrics)>(
        // The overview pairs Queue and Share side by side (#7), so these
        // take the width they are given rather than leaving half a pane
        // blank. `fill` never narrows a column below its declared width.
        fill: true,
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
        rows: rows,
        sortKeyOf: (row, column) {
          final part = row.$2;
          if (showStudy && column == 1) return names[part.studyId] ?? '';
          return switch (showStudy && column > 0 ? column - 1 : column) {
            0 => part.partNumber,
            1 => part.orders,
            2 => part.delivered,
            3 => part.onTime,
            // A part the run could not cost sorts as though it took no time,
            // which puts it at one end rather than scattering it — the same
            // choice the empty release slot makes on the combined plan.
            4 => part.averageLeadTime ?? Duration.zero,
            _ => part.averageFloat ?? Duration.zero,
          };
        },
        cellAt: (row, column) {
          final (index, part) = row;
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
