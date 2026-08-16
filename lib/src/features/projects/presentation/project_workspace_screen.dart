import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/help_icon.dart';
import '../../../common/dialogs.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../demand/presentation/demand_tab.dart';
import '../../flow/presentation/flow_tab.dart';
import '../../flow/presentation/period_control.dart';
import '../../resources/application/resources_providers.dart';
import '../../resources/data/resources_repository.dart';
import '../../schedules/presentation/capacity_tab.dart';
import '../../schedules/presentation/exceptions_screen.dart';
import '../../simulation/application/sim_assembly.dart';
import '../../simulation/application/simulation_providers.dart';
import '../../simulation/presentation/simulation_tab.dart';
import '../../studies/application/studies_providers.dart';
import '../../simulation/presentation/simulation_workspace.dart';
import '../../studies/presentation/study_settings_tab.dart';
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
    this.showSimulation = false,
    this.showExceptions = false,
    this.simulationStudyId,
  });

  final String projectId;
  final String? studyId;

  /// Whether the body is the project's run rather than a study's tabs (§12.1).
  /// A destination in the sidebar, so it is part of the location.
  final bool showSimulation;

  /// Whether the body is the project's calendar exceptions (§4.3, §12.1).
  ///
  /// A destination rather than a tab, for the same reason the run is one: an
  /// exception is stored per project and applies to every study in it, so it
  /// was never one study's to edit.
  final bool showExceptions;

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

class _ProjectWorkspaceScreenState extends ConsumerState<ProjectWorkspaceScreen>
    with SingleTickerProviderStateMixin {
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

  /// Owned here rather than by [_StudyTabs], because the app bar's Simulate
  /// button has to be able to reset it and because §12.1's period control will
  /// sit on the strip beside it.
  ///
  /// Five, from seven. The study's Simulation tab is gone — a run spans studies
  /// and is read in one place now, and `View results` navigates there rather
  /// than moving an index, which is the whole reason the banner needed a
  /// controller at all. `Flow Takt` and `Workcenters` merged into `Capacity`
  /// (§12.6), which is one question and was two tabs.
  late final TabController _tabs = TabController(length: 5, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

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
              // A run spans studies and belongs to the project (§7.7), so its
              // trigger belongs on the project's chrome rather than inside one
              // of six tabs.
              _SimulateButton(
                project: project,
                onFinished: (outcome) => setState(() => _outcome = outcome),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
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
                child: widget.showExceptions
                    ? ExceptionsScreen(project: project)
                    : widget.showSimulation
                    ? SimulationWorkspace(
                        project: project,
                        // From `?study=`, so a study's own slice is one click
                        // and one link away (§12.1).
                        initialStudyId: widget.simulationStudyId,
                      )
                    : selected == null
                    ? _NoStudyYet(project: project)
                    : _StudyTabs(
                        project: project,
                        study: selected,
                        tabs: _tabs,
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

    return Row(
      children: [
        Tooltip(
          // The first thing in the way still travels with the button (§11): a
          // tooltip is a sentence and the panel beside it is the list.
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
        ),
        // **Everything about the *next* run, under the button that starts it**
        // (§12.1). The dispatch rule and §11's readiness were on the deleted
        // Simulation tab; they are about what the run will be rather than about
        // what it said, so they follow the trigger rather than the results.
        // Stacking them into the workspace's filter bar instead would have made
        // a strip that already scrolls sideways at 1100 px carry three more
        // controls.
        _RunSettingsButton(project: project, input: input, busy: busy),
      ],
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

/// The rule the next run is made with, and why it cannot be started
/// (DESIGN.md §12.1).
///
/// **Under the Simulate button rather than beside the results.** Both of these
/// describe the run that has not happened yet: the dispatch rule decides what it
/// will do, and §11's readiness decides whether it may begin. They lived on the
/// Simulation tab because that is where the button used to be; the button moved
/// to the app bar in an earlier round and they did not follow it, which is how
/// the reason a button is disabled came to be on a tab the reader was not
/// looking at.
///
/// The badge is the count of studies that are not ready, so the panel says there
/// is something to open before it is opened.
class _RunSettingsButton extends ConsumerWidget {
  const _RunSettingsButton({
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
    final blocked =
        input?.readiness.where((study) => !study.isReady).length ?? 0;

    return MenuAnchor(
      menuChildren: [
        // A panel rather than a list of menu items: it holds a dropdown and a
        // block of prose, neither of which is a thing to be selected.
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.simulationStudiesIn(input?.readiness.length ?? 0),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text(l10n.simulationDispatch)),
                    _DispatchPicker(projectId: project.id, busy: busy),
                  ],
                ),
                Text(
                  l10n.simulationDispatchHelp,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                if (input case final input? when !input.canRun) ...[
                  const Divider(height: 24),
                  Readiness(input: input),
                ],
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: l10n.simulationRunSettings,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: Badge(
          // Absent rather than zero when everything is ready: a badge reading
          // `0` is a warning that nothing is wrong.
          isLabelVisible: blocked > 0,
          label: Text('$blocked'),
          child: const Icon(Icons.tune),
        ),
      ),
    );
  }
}

class _DispatchPicker extends ConsumerWidget {
  const _DispatchPicker({required this.projectId, required this.busy});

  final String projectId;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rule = ref.watch(dispatchRuleSelectionProvider(projectId));

    return DropdownButtonHideUnderline(
      child: DropdownButton<DispatchRule>(
        value: rule,
        onChanged: busy
            ? null
            : (value) {
                if (value != null) {
                  ref
                      .read(dispatchRuleSelectionProvider(projectId).notifier)
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
    );
  }
}

/// §11's readiness, per study — the list the button's tooltip is one sentence
/// of.
///
/// Visible for testing for [RunBanner]'s reason: mounting the workspace needs a
/// project, a study list and a database, and none of that is what the rule here
/// is about. The rule is that a study which cannot run says so **by name** —
/// "something is wrong" is not a thing anyone can act on.
@visibleForTesting
class Readiness extends StatelessWidget {
  const Readiness({super.key, required this.input});

  final SimRunInput input;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber, color: theme.colorScheme.error, size: 18),
            const SizedBox(width: 8),
            Text(
              // Nothing flagged is not a fault, so it does not read as one.
              input.isEmpty ? l10n.simulationNoStudies : l10n.simulationNotReady,
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        for (final study in input.readiness)
          if (!study.isReady)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(study.name, style: theme.textTheme.labelLarge),
                  for (final problem in study.problems)
                    Text(
                      '• ${simProblemLabel(l10n, problem)}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
      ],
    );
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
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
        // Under New study, and a destination rather than a button: a run spans
        // studies (§7.7), so it sits beside them rather than inside one, and
        // selecting it replaces the tabs entirely (§12.1).
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () =>
                  context.go('/projects/${project.id}/simulation'),
              icon: const Icon(Icons.insights_outlined),
              label: Text(l10n.simWorkspace),
            ),
          ),
        ),
        // Beside the run, and for the same reason it is here rather than on a
        // tab: an exception is stored per project and closes the plant for
        // every study in it (§4.3, §12.1).
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () =>
                  context.go('/projects/${project.id}/exceptions'),
              icon: const Icon(Icons.event_busy_outlined),
              label: Text(l10n.navExceptions),
            ),
          ),
        ),
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
class _StudyTabs extends StatefulWidget {
  const _StudyTabs({
    required this.project,
    required this.study,
    required this.tabs,
  });

  final Project project;
  final Study study;

  /// Owned by the workspace, not here — the app bar's Simulate button raises a
  /// snackbar that has to be able to bring the reader to the results.
  final TabController tabs;

  @override
  State<_StudyTabs> createState() => _StudyTabsState();
}

class _StudyTabsState extends State<_StudyTabs> {
  /// Which tabs the viewed period is about: Flow and Summary, the two that
  /// carried a stepper of their own. Study Settings, Schedules and Demand are
  /// about the study whatever month it is.
  static bool _periodGoverns(int index) => index == 0 || index == 4;

  @override
  void initState() {
    super.initState();
    // The strip's own control greys by tab, so it has to be rebuilt when the
    // tab changes — the `TabBarView` swapping its child does not rebuild the
    // row above it.
    widget.tabs.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    widget.tabs.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_StudyTabs old) {
    super.didUpdateWidget(old);
    if (old.study.id == widget.study.id) return;
    // Switching studies resets to Flow rather than landing on whichever tab the
    // previous study was showing. The exception this used to carry — do not do
    // it when the reader is on Simulation, which was not about the study they
    // switched away from — went with that tab: every tab here is now about the
    // study, so every one of them should follow it.
    widget.tabs.index = 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final study = widget.study;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _tabBar(l10n)),
            // **One period control for the workspace**, not one per tab
            // (§12.1). It governs Flow and Summary and is greyed on the three
            // it does not — dimmed rather than hidden, so the strip does not
            // jump as the reader moves along it.
            PeriodControl(
              studyId: study.id,
              enabled: _periodGoverns(widget.tabs.index),
            ),
            // **The one-click path from a study to its own numbers**, which is
            // what the deleted Simulation tab was (§12.1). A link rather than a
            // screen: it carries `?study=` to the one place a run is read, so
            // the slice is the same `RunFilter` the tab applied and the two
            // cannot disagree.
            //
            // On the strip rather than in the study's menu, because it is not a
            // property of the study — and §12.1's period control lands beside
            // it, which is what this row exists to make room for.
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 12),
              child: TextButton.icon(
                onPressed: () => context.go(
                  '/projects/${widget.project.id}/simulation'
                  '?study=${study.id}',
                ),
                icon: const Icon(Icons.insights_outlined, size: 18),
                label: Text(l10n.simViewResults),
              ),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: widget.tabs,
            children: [
              FlowTab(study: study),
              StudySettingsTab(project: widget.project, study: study),
              CapacityTab(project: widget.project, study: study),
              DemandTab(study: study),
              SummaryTab(study: study),
            ],
          ),
        ),
      ],
    );
  }

  /// Scrollable, so the strip can lose width to what sits beside it without
  /// the last tab falling off the end — the run's link now, §12.1's period
  /// control next.
  Widget _tabBar(AppLocalizations l10n) => TabBar(
    controller: widget.tabs,
    isScrollable: true,
    tabAlignment: TabAlignment.start,
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
