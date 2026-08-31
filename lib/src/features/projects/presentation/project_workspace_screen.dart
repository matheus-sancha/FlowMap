import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/help_icon.dart';
import '../../../common/dialogs.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../demand/presentation/demand_tab.dart';
import '../../flow/presentation/flow_tab.dart';
import '../../flow/presentation/period_control.dart';
import '../../resources/application/resources_providers.dart';
import '../../resources/data/resources_repository.dart';
import '../../schedules/presentation/capacity_tab.dart';
import 'project_settings_screen.dart';
import '../../simulation/application/sim_assembly.dart';
import '../../simulation/application/simulation_providers.dart';
import '../../simulation/presentation/simulation_tab.dart';
import '../../studies/application/studies_providers.dart';
import '../../simulation/presentation/simulation_workspace.dart';
import '../../studies/presentation/study_settings_tab.dart';
import 'workspace_tabs.dart';
import '../../summary/presentation/summary_tab.dart';
import '../application/projects_providers.dart';

/// The project workspace: a studies sidebar and the tabs of whichever study is
/// open — or, at `/simulation`, the one place the project's run is read
/// (DESIGN.md §12.1).
///
/// **Simulation is not a tab.** A run spans studies (§7.7), so it was never one
/// study's; it was a project-level tab wedged into a study's strip, and a
/// workspace destination beside it, and a Run button on each. Opening the
/// destination showed two Simulate buttons a few hundred pixels apart. There is
/// one trigger now, on this app bar, and one place the result is read.
class ProjectWorkspaceScreen extends ConsumerStatefulWidget {
  const ProjectWorkspaceScreen({
    super.key,
    required this.projectId,
    this.studyId,
    this.studyTab = StudyTab.flow,
    this.showSimulation = false,
    this.simulationTab = SimulationTab.overview,
    this.showSettings = false,
    this.simulationStudyId,
  });

  final String projectId;
  final String? studyId;

  /// Which study tab the location names (#7). Every one of the five is a URL.
  final StudyTab studyTab;

  /// Which of the results' five tabs the location names (#7).
  final SimulationTab simulationTab;

  /// Whether the body is the project's run rather than a study's tabs (§12.1).
  /// A destination in the sidebar, so it is part of the location.
  final bool showSimulation;

  /// Whether the body is the project's calendar exceptions (§4.3, §12.1).
  ///
  /// A destination rather than a tab, for the same reason the run is one: an
  /// exception is stored per project and applies to every study in it, so it
  /// was never one study's to edit.
  final bool showSettings;

  /// The study to pre-select in the run's filter, from `?study=`.
  ///
  /// This is how a study reaches its own numbers now that its Simulation tab is
  /// gone (§12.1). Null means the whole run, which is what the sidebar's own
  /// entry links to.
  final String? simulationStudyId;

  @override
  ConsumerState<ProjectWorkspaceScreen> createState() =>
      _ProjectWorkspaceScreenState();
}

/// **No `TabController` here any more** (#7). Both strips read the location, so
/// the tab a reader is on is a fact about the URL rather than about this
/// object — which is what makes it linkable, restorable on reopen, and
/// reachable by back and forward.
class _ProjectWorkspaceScreenState
    extends ConsumerState<ProjectWorkspaceScreen> {
  /// Collapsed to a rail, so the canvas gets the width on a laptop screen.
  ///
  /// Held here rather than in a provider: it is a property of this window, not
  /// of the project, and it should not follow the user to another machine.
  bool _sidebarCollapsed = false;

  /// What the last run said, until the reader dismisses it (§12.1).
  ///
  /// **A banner rather than a snackbar.** A snackbar anchors to the bottom of
  /// the window, and since the Gantt took the full body height (§8.6) one that
  /// never goes away parks permanently over the last station's row and the
  /// scrollbar gutter §2.11 added to reach it. A banner pushes content down
  /// instead of covering it — and a run's outcome is a statement about the
  /// project that should stay until it is read, which is not what a snackbar
  /// is for.
  ({String message, bool failed})? _outcome;

  @override
  Widget build(BuildContext context) {
    final projectId = widget.projectId;
    final studyId = widget.studyId;
    final l10n = AppLocalizations.of(context);
    final project = ref.watch(projectProvider(projectId));
    final studies = ref.watch(studiesProvider(projectId));

    return project.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$error')),
      ),
      data: (project) {
        if (project == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l10n.projectMissing)),
          );
        }

        final studyList = studies.value ?? const <Study>[];
        final selected =
            studyList.where((s) => s.id == studyId).firstOrNull ??
            studyList.firstOrNull;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/projects'),
            ),
            // Still on the left half of the bar, so the argument stands: a
            // control across the window from what it moves reads as belonging
            // to whatever is under it. It follows the project name rather than
            // leading it, which puts the workspace's own name first.
            titleSpacing: 0,
            title: Row(
              children: [
                Flexible(
                  child: Text(project.name, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: _sidebarCollapsed
                      ? l10n.studiesExpand
                      : l10n.studiesCollapse,
                  icon: Icon(
                    _sidebarCollapsed
                        ? Icons.menu_open
                        : Icons.chevron_left,
                  ),
                  onPressed: () => setState(
                    () => _sidebarCollapsed = !_sidebarCollapsed,
                  ),
                ),
              ],
            ),
            actions: [
              // The project's own settings, on the project's own chrome. A
              // gear rather than a labelled button: it is the one action here
              // that is not about running anything, and §12.1 puts what spans
              // studies on this bar rather than inside one of six tabs.
              //
              // **Simulate first, then the gear** (#7). The order was the other
              // way round, which put the one control nobody presses in a
              // session between the reader and the one they press every time.
              // Reading order is priority order on a bar this short.
              //
              // A run spans studies and belongs to the project (§7.7), so its
              // trigger belongs on the project's chrome rather than inside one
              // of six tabs.
              _SimulateButton(
                project: project,
                onFinished: (outcome) => setState(() => _outcome = outcome),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: l10n.projectSettings,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () =>
                    context.go('/projects/${project.id}/settings'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // **The readiness strip** (#7): a red band under the app bar
              // whenever any study cannot run, listing each one and its first
              // problem. Full width and above everything, because it is about
              // the project rather than about whatever is being read.
              //
              // *Rejected: putting it in Simulation mode, above the run.* It
              // reads well — readiness describes a run that has not happened —
              // but it puts the reason a button is disabled one click from the
              // button, which is the exact fault §12.1 recorded when the panel
              // sat on a tab the reader was not looking at.
              ReadinessStrip(
                input: ref.watch(simRunInputProvider(project.id)).value,
              ),
              // Above the tabs and across the full width, so it pushes the
              // workspace down rather than covering any part of it.
              if (_outcome case final outcome?)
                RunBanner(
                  outcome: outcome,
                  // A route rather than a tab index (§12.1). There is one place
                  // a run is read now, and it is not one of these tabs — so
                  // the action goes there, filtered to the study being read if
                  // there is one, which is the same slice the deleted tab used
                  // to show.
                  onViewResults: () {
                    setState(() => _outcome = null);
                    context.go(
                      '/projects/${project.id}/simulation'
                      '${selected == null ? '' : '?study=${selected.id}'}',
                    );
                  },
                  onDismiss: () => setState(() => _outcome = null),
                ),
              Expanded(
                child: Row(
                  children: [
              // Animated rather than snapped: a pane that vanishes leaves the
              // reader hunting for what moved.
              AnimatedSize(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: SizedBox(
                  width: _sidebarCollapsed ? 0 : 280,
                  child: _sidebarCollapsed
                      ? const SizedBox.shrink()
                      : _StudiesSidebar(
                          project: project,
                          studies: studyList,
                          selectedId: selected?.id,
                        ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: widget.showSettings
                    ? ProjectSettingsScreen(project: project)
                    // **Two modes of one project, not two places** (#7). The
                    // switch sits above whichever strip is showing, so the
                    // study strip and the results strip can never both claim
                    // to be "the tabs".
                    : Column(
                        children: [
                          _ModeSwitch(
                            project: project,
                            study: selected,
                            simulation: widget.showSimulation,
                          ),
                          Expanded(
                            child: widget.showSimulation
                                ? SimulationWorkspace(
                                    project: project,
                                    tab: widget.simulationTab,
                                    // From `?study=`, so a study's own slice is
                                    // one click and one link away (§12.1).
                                    initialStudyId: widget.simulationStudyId,
                                  )
                                : selected == null
                                ? _NoStudyYet(project: project)
                                : _StudyTabs(
                                    project: project,
                                    study: selected,
                                    tab: widget.studyTab,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What the last run said, until it is dismissed (DESIGN.md §12.1).
///
/// Carries the headline figure, one way to the rest of it, and a close button.
/// The action dismisses as well as navigating: having arrived at the results,
/// a bar still offering to take you there is asking a question already
/// answered.
///
/// Visible for testing: the workspace itself needs a project, a study list and
/// a database to mount, and none of that is what the two rules here are about.
@visibleForTesting
class RunBanner extends StatelessWidget {
  const RunBanner({
    super.key,
    required this.outcome,
    required this.onViewResults,
    required this.onDismiss,
  });

  final ({String message, bool failed}) outcome;
  final VoidCallback onViewResults;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return MaterialBanner(
      backgroundColor: outcome.failed
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.surfaceContainerHighest,
      leading: Icon(
        outcome.failed ? Icons.error_outline : Icons.check_circle_outline,
        color: outcome.failed
            ? theme.colorScheme.onErrorContainer
            : theme.colorScheme.primary,
      ),
      content: Text(
        outcome.message,
        style: TextStyle(
          color: outcome.failed
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onSurface,
        ),
      ),
      actions: [
        // Nowhere to go when there is no run to look at.
        if (!outcome.failed)
          TextButton(
            onPressed: onViewResults,
            child: Text(l10n.simViewResults),
          ),
        TextButton(onPressed: onDismiss, child: Text(l10n.actionClose)),
      ],
    );
  }
}

/// Simulate, on the project's own chrome (DESIGN.md §12.1).
///
/// **Pressing it never moves the reader.** A run takes a second or two on a
/// background isolate (§7.1), and being thrown out of a half-typed sequence
/// cell to watch it is worse than not seeing the result immediately. The
/// spinner stays on the button and a banner reports the headline with one way
/// to the rest.
class _SimulateButton extends ConsumerWidget {
  const _SimulateButton({required this.project, required this.onFinished});

  final Project project;

  /// What to say once the run is over. Raised here and rendered by the
  /// workspace, because the banner belongs above the tabs rather than beside
  /// the button that started it.
  final ValueChanged<({String message, bool failed})> onFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final input = ref.watch(simRunInputProvider(project.id)).value;
    final busy = ref.watch(simulationRunnerProvider(project.id)).isLoading;
    final ready = input?.canRun ?? false;

    // **The tooltip is the only thing left beside the button** (#7). The tune
    // icon that sat here — `_RunSettingsButton`, a badge over a panel holding
    // §11's readiness list — is gone: the readiness strip under the app bar is
    // that list, always open while it has something to say, rather than two
    // clicks from the disabled button it explains. The tooltip still names the
    // first thing in the way, because a tooltip is a sentence and the strip is
    // the list.
    return Tooltip(
      message: busy || ready ? '' : _blockedBecause(l10n, input),
      child: FilledButton.icon(
        onPressed: busy || !ready ? null : () => _run(context, ref, l10n),
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.play_arrow),
        label: Text(busy ? l10n.simulationRunning : l10n.simulationRun),
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    await ref.read(simulationRunnerProvider(project.id).notifier).run();

    final run = ref.read(simulationRunnerProvider(project.id));
    final metrics = run.value?.metrics;
    final failed = run.hasError || metrics == null;
    onFinished((
      message: failed
          ? l10n.simulationRunFailed
          : '${l10n.simOnTimeDelivery}: '
                '${(metrics.onTimeDelivery * 100).round()}%',
      failed: failed,
    ));
  }

  /// The first thing standing in the way, named with the study it belongs to.
  ///
  /// One rather than all of them: a tooltip is a sentence, the panel is the
  /// list, and "nothing is selected" is not a fault to report as one.
  static String _blockedBecause(AppLocalizations l10n, SimRunInput? input) {
    if (input == null) return '';
    if (input.isEmpty) return l10n.simulationNoStudies;
    for (final study in input.readiness) {
      if (study.problems.isEmpty) continue;
      return '${study.name}: ${simProblemLabel(l10n, study.problems.first)}';
    }
    return '';
  }
}

class _StudiesSidebar extends ConsumerWidget {
  const _StudiesSidebar({
    required this.project,
    required this.studies,
    required this.selectedId,
  });

  final Project project;
  final List<Study> studies;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lines =
        ref.watch(plantLinesProvider(project.plantId)).value ??
        const <PlantLine>[];
    final linesById = {for (final line in lines) line.line.id: line};

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              for (final study in studies)
                _StudyTile(
                  study: study,
                  line: linesById[study.productionLineId],
                  selected: study.id == selectedId,
                  // Its siblings' names, so a rename or a duplicate can refuse
                  // one the project already holds. Its own is not taken.
                  takenNames: {
                    for (final other in studies)
                      if (other.id != study.id) other.name.toLowerCase(),
                  },
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: lines.isEmpty
                  ? null
                  : () => _createStudy(context, ref, project, lines, studies),
              icon: const Icon(Icons.add),
              label: Text(l10n.studyNew),
            ),
          ),
        ),
        // **The Simulation destination is gone from here** (v2.0). It sat under
        // New study as the unfiltered way into the run, and put a second way to
        // the results a few hundred pixels from the strip's own one. The run is
        // reached from where it is read: Simulation results on the tab strip,
        // and the banner a finished run raises.
        // **The exceptions button is gone from here** (§10.1). It sat at the
        // bottom of this sidebar because there was nowhere better — there is
        // now, and the calendar is a section of Project Settings rather than a
        // destination competing with the run for the same strip of chrome.
      ],
    );
  }
}

class _StudyTile extends ConsumerWidget {
  const _StudyTile({
    required this.study,
    required this.line,
    required this.selected,
    required this.takenNames,
  });

  final Study study;
  final PlantLine? line;
  final bool selected;

  /// Lower-cased names of the other studies in this project.
  final Set<String> takenNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(studiesRepositoryProvider);
    final taken = takenNames;

    return ListTile(
      selected: selected,
      leading: Icon(
        study.includeInSimulation
            ? Icons.play_circle
            : Icons.play_circle_outline,
        // The flag is the study's most consequential property — only one per
        // line may carry it — so it earns the leading slot rather than a
        // checkbox buried in a menu.
        //
        // **Shown here, set on Study Settings.** That was always the argument
        // for the leading slot: it is about seeing at a glance which studies a
        // run will cover, across the whole list, which is a different question
        // from setting one of them (§12.1).
        color: study.includeInSimulation
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Text(study.name),
      subtitle: Text(line?.qualifiedName ?? '—'),
      // **The bare study location**, which the router redirects to Flow (#7).
      // So picking a study in the sidebar lands on its map rather than on
      // whichever tab the previous study was showing — the behaviour
      // `_StudyTabs.didUpdateWidget` used to have to arrange by hand, now a
      // property of where the link points.
      onTap: () =>
          context.go('/projects/${study.projectId}/studies/${study.id}'),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          switch (action) {
            case 'duplicate':
              final name = await promptForName(
                context,
                title: l10n.actionDuplicate,
                label: l10n.fieldName,
                initialValue: '${study.name} (copy)',
                // The copy needs a free name too, and here the original's own
                // name is taken as well.
                validate: (value) =>
                    taken.contains(value.toLowerCase()) ||
                        value.toLowerCase() == study.name.toLowerCase()
                    ? l10n.validationNameTaken
                    : null,
              );
              if (name == null) return;
              final copyId = await repository.duplicateStudy(
                study.id,
                newName: name,
              );
              if (context.mounted) {
                context.go('/projects/${study.projectId}/studies/$copyId');
              }
            case 'delete':
              if (!context.mounted) return;
              final confirmed = await confirmAction(
                context,
                title: l10n.confirmDeleteTitle(study.name),
                message: l10n.studyDeleteBody,
                confirmLabel: l10n.actionDelete,
                destructive: true,
              );
              if (confirmed) await repository.deleteStudy(study.id);
          }
        },
        // **Only what acts on the study as an object.** Include and Rename
        // are fields, and Study Settings owns the study's fields (§12.1) —
        // round four removed the `Run settings` dialog on the rule that two
        // ways to set one thing is how the two come to disagree, and then left
        // two of them here. Duplicate and Delete stay: neither sets a value,
        // and neither belongs on a page that would vanish underneath the
        // reader as it ran.
        itemBuilder: (context) => [
          PopupMenuItem(value: 'duplicate', child: Text(l10n.actionDuplicate)),
          PopupMenuItem(value: 'delete', child: Text(l10n.actionDelete)),
        ],
      ),
    );
  }
}

/// The study's tabs (DESIGN.md §12.1).
///
/// **Simulation is not among them.** A run spans studies (§7.7) and is read in
/// one place; a study reaches its own slice through `?study=` on that place's
/// route, which is the same `RunFilter` the deleted tab applied and therefore
/// cannot report a different number for the same study.
/// **Two modes of one project** (#7): the study you are editing, and the run
/// you are reading.
///
/// The run is a *mode* of the workspace rather than a place inside it. That is
/// what makes it impossible for the study strip and the results strip to both
/// claim to be "the tabs" — the fault a flat nine-tab strip had when it was
/// driven and rejected as shape C, which rebuilt the Simulation tab §12.1
/// deleted and lost the boundary between what a reader is typing and what the
/// engine said.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.project,
    required this.study,
    required this.simulation,
  });

  final Project project;

  /// The selected study, so Study mode returns to *that* study rather than the
  /// first one. Null when the project has none yet.
  final Study? study;

  final bool simulation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(l10n.workspaceModeStudy),
              icon: const Icon(Icons.account_tree_outlined),
            ),
            ButtonSegment(
              value: true,
              // `simWorkspace` — stored in all three ARB files and unused in
              // `lib/` since the pre-map renames. #7 spoke for it, and this is
              // the segment it names.
              label: Text(l10n.simWorkspace),
              icon: const Icon(Icons.insights_outlined),
            ),
          ],
          selected: {simulation},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            // **Each mode goes to its own first tab.** Neither remembers which
            // tab it was on: the location is the memory, and coming back to a
            // mode by way of the switch is a fresh arrival at it.
            final target = study;
            if (selection.first) {
              context.go(
                '/projects/${project.id}/simulation'
                '/${SimulationTab.overview.slug}'
                '${target == null ? '' : '?study=${target.id}'}',
              );
            } else if (target != null) {
              context.go(
                '/projects/${project.id}/studies/${target.id}'
                '/${StudyTab.flow.slug}',
              );
            } else {
              context.go('/projects/${project.id}');
            }
          },
        ),
      ),
    );
  }
}

/// §11's readiness as a strip under the app bar, whenever any study cannot run
/// (#7).
///
/// **It replaces `_RunSettingsButton`**, the tune icon with a badge whose panel
/// held this same list plus a count of the studies in the run. That control was
/// two clicks from a disabled button and named nothing until it was opened; the
/// strip is always the list, and always visible while it has something to say.
/// The button's tooltip still names the first thing in the way — a tooltip is a
/// sentence, this is the list.
///
/// **Visible for testing**, for [RunBanner]'s reason: mounting the workspace
/// needs a project, a study list and a database, and none of that is what the
/// rule here is about. The rule is that a study which cannot run says so *by
/// name*.
@visibleForTesting
class ReadinessStrip extends StatelessWidget {
  const ReadinessStrip({super.key, required this.input});

  /// The run as it would be assembled now, or null while it is still loading.
  final SimRunInput? input;

  @override
  Widget build(BuildContext context) {
    final input = this.input;
    // **Silent while everything is ready, and silent while nothing is
    // flagged.** A project with no study in the run is not a project with a
    // fault in it, and a strip that appears for both cannot be read as meaning
    // either.
    if (input == null || input.isEmpty || input.canRun) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final blocked = input.readiness.where((s) => !s.isReady).toList();

    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber,
              size: 18,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.simulationStudiesNotReady(blocked.length),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  // **The first problem per study, not all of them.** A strip
                  // is a summary; the study's own tab is where a reader fixes
                  // the thing, and a band that grows to twelve lines stops
                  // being chrome and starts being the screen.
                  for (final study in blocked)
                    Text(
                      '${study.name}: '
                      '${simProblemLabel(l10n, study.problems.first)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The study's five tabs, each of them a location (#7).
///
/// **Route-driven.** It held a `TabController` and a listener that rebuilt the
/// strip when the index moved; the index is now
/// [ProjectWorkspaceScreen.studyTab], read from the URL, so tapping a tab
/// navigates and the rebuild *is* the navigation.
class _StudyTabs extends StatefulWidget {
  const _StudyTabs({
    required this.project,
    required this.study,
    required this.tab,
  });

  final Project project;
  final Study study;
  final StudyTab tab;

  @override
  State<_StudyTabs> createState() => _StudyTabsState();
}

class _StudyTabsState extends State<_StudyTabs>
    with SingleTickerProviderStateMixin {
  /// **Kept only to paint the indicator.** `TabBar` needs a controller; what it
  /// must not do is decide which tab is showing, which is the location's job.
  /// So this is driven *from* the route on every build and never the other way
  /// — `onTap` navigates, and the navigation is what moves it.
  late final TabController _tabs = TabController(
    length: StudyTab.values.length,
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
    final study = widget.study;
    if (_tabs.index != widget.tab.index) _tabs.index = widget.tab.index;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _tabBar(l10n)),
            // **One period control for the workspace**, not one per tab
            // (§12.1) — and **hidden rather than greyed** on the three tabs it
            // does not govern (#7). §12.1 dimmed it so the strip would not
            // jump; the strip no longer carries the results link, so there is
            // nothing left to jump, and a permanently dead control is worse
            // than an absent one.
            if (widget.tab.hasPeriod)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: PeriodControl(studyId: study.id, enabled: true),
              ),
          ],
        ),
        Expanded(
          child: switch (widget.tab) {
            StudyTab.flow => FlowTab(study: study),
            StudyTab.settings => StudySettingsTab(
              project: widget.project,
              study: study,
            ),
            StudyTab.capacity => CapacityTab(
              project: widget.project,
              study: study,
            ),
            StudyTab.demand => DemandTab(study: study),
            StudyTab.summary => SummaryTab(study: study),
          },
        ),
      ],
    );
  }

  /// Scrollable, so the strip can lose width to the period control without the
  /// last tab falling off the end.
  ///
  /// **The `View results` link has gone from here.** It was the one-click path
  /// from a study to its own slice; the mode switch above is that path now, and
  /// it carries the same `?study=`.
  Widget _tabBar(AppLocalizations l10n) => TabBar(
    controller: _tabs,
    isScrollable: true,
    tabAlignment: TabAlignment.start,
    onTap: (index) => context.go(
      '/projects/${widget.project.id}/studies/${widget.study.id}'
      '/${StudyTab.values[index].slug}',
    ),
    tabs: [
      Tab(text: l10n.studyTabFlow),
      Tab(text: l10n.studyTabSettings),
      Tab(text: l10n.studyTabCapacity),
      Tab(text: l10n.studyTabDemand),
      Tab(text: l10n.studyTabSummary),
    ],
  );
}

class _NoStudyYet extends ConsumerWidget {
  const _NoStudyYet({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lines =
        ref.watch(plantLinesProvider(project.plantId)).value ??
        const <PlantLine>[];

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            lines.isEmpty ? l10n.studyNeedsLine : l10n.studiesEmpty,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (lines.isEmpty)
            FilledButton.icon(
              onPressed: () => context.go('/resources'),
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.navResources),
            )
          else
            FilledButton.icon(
              onPressed: () =>
                  _createStudy(context, ref, project, lines, const []),
              icon: const Icon(Icons.add),
              label: Text(l10n.studyNew),
            ),
        ],
      ),
    );
  }
}

Future<void> _createStudy(
  BuildContext context,
  WidgetRef ref,
  Project project,
  List<PlantLine> lines,
  List<Study> existing,
) async {
  final draft = await showDialog<({String name, PlantLine line})>(
    context: context,
    builder: (context) => _StudyDialog(
      lines: lines,
      takenNames: existing.map((s) => s.name.toLowerCase()).toSet(),
    ),
  );
  if (draft == null) return;

  final id = await ref
      .read(studiesRepositoryProvider)
      .createStudy(
        projectId: project.id,
        productionCellId: draft.line.cell.id,
        productionLineId: draft.line.line.id,
        name: draft.name,
      );
  if (context.mounted) context.go('/projects/${project.id}/studies/$id');
}

class _StudyDialog extends StatefulWidget {
  const _StudyDialog({required this.lines, required this.takenNames});

  final List<PlantLine> lines;
  final Set<String> takenNames;

  @override
  State<_StudyDialog> createState() => _StudyDialogState();
}

class _StudyDialogState extends State<_StudyDialog> {
  final _name = TextEditingController();
  late PlantLine _line = widget.lines.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _name.text.trim();
    if (value.isEmpty || widget.takenNames.contains(value.toLowerCase())) {
      return;
    }
    Navigator.of(context).pop((name: value, line: _line));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = _name.text.trim();
    final taken = widget.takenNames.contains(value.toLowerCase());

    return AlertDialog(
      title: Text(l10n.studyNew),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                hintText: l10n.studyNameHint,
                errorText: taken ? l10n.validationNameTaken : null,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _line.line.id,
              decoration: InputDecoration(
                labelText: l10n.productionLine,
                suffixIcon: helpIcon(context, l10n.studyLineHelp),
              ),
              items: [
                for (final line in widget.lines)
                  DropdownMenuItem(
                    value: line.line.id,
                    child: Text(line.qualifiedName),
                  ),
              ],
              onChanged: (id) => setState(
                () => _line = widget.lines.firstWhere((l) => l.line.id == id),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: value.isEmpty || taken ? null : _submit,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
