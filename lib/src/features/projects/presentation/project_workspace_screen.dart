import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/dialogs.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../demand/presentation/demand_tab.dart';
import '../../flow/presentation/flow_tab.dart';
import '../../resources/application/resources_providers.dart';
import '../../resources/data/resources_repository.dart';
import '../../schedules/presentation/takt_tab.dart';
import '../../schedules/presentation/workcenters_tab.dart';
import '../../simulation/application/sim_assembly.dart';
import '../../simulation/application/simulation_providers.dart';
import '../../simulation/presentation/simulation_tab.dart';
import '../../studies/application/studies_providers.dart';
import '../../studies/presentation/study_run_settings.dart';
import '../../summary/presentation/summary_tab.dart';
import '../application/projects_providers.dart';

/// The project workspace: a studies sidebar, the five tabs of whichever study
/// is open, and the project's Simulation tab (DESIGN.md §12.1).
///
/// Simulation sits in the same strip but is a project-level tab rather than a
/// study one, because a run spans studies (§7.7).
class ProjectWorkspaceScreen extends ConsumerStatefulWidget {
  const ProjectWorkspaceScreen({
    super.key,
    required this.projectId,
    this.studyId,
  });

  final String projectId;
  final String? studyId;

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

  /// The Simulation tab, after the five study ones.
  static const _simulation = 5;

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

  /// Owned here rather than by [_StudyTabs], because Simulate now lives in the
  /// app bar (§12.1) and the banner it raises has to be able to bring the
  /// reader to the results. A controller one level below the button that needs
  /// it cannot be reached without passing a callback down and an index back up.
  late final TabController _tabs = TabController(length: 6, vsync: this);

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
                onViewResults: () => _tabs.index = _simulation,
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
                  onViewResults: () {
                    _tabs.index = _simulation;
                    setState(() => _outcome = null);
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
                child: selected == null
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
  const _SimulateButton({
    required this.project,
    required this.onViewResults,
    required this.onFinished,
  });

  final Project project;
  final VoidCallback onViewResults;

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

    return Tooltip(
      // The readiness panel lives on a tab the reader may not be looking at,
      // so the reason travels with the button (§11).
      message: busy || ready ? '' : _blockedBecause(l10n, input),
      child: FilledButton.icon(
        onPressed: busy || !ready
            ? null
            : () => _run(context, ref, l10n),
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
          padding: const EdgeInsets.all(12),
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
            case 'include':
              await repository.setIncludedInSimulation(
                study.id,
                !study.includeInSimulation,
              );
            case 'runSettings':
              await showStudyRunSettings(context, ref, study: study);
            case 'rename':
              final name = await promptForName(
                context,
                title: l10n.actionRename,
                label: l10n.fieldName,
                initialValue: study.name,
                // Study names are unique per project. Without this the write
                // hits the constraint and throws inside an async callback,
                // where the user sees the dialog close and nothing happen.
                validate: (value) => taken.contains(value.toLowerCase())
                    ? l10n.validationNameTaken
                    : null,
              );
              if (name != null) {
                await repository.updateStudy(
                  study.id,
                  name: name,
                  supplierName: study.supplierName,
                  customerName: study.customerName,
                  wipCap: study.wipCap,
                  priority: study.priority,
                  notes: study.notes,
                );
              }
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
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'include',
            child: Text(
              study.includeInSimulation
                  ? l10n.studyExcludeFromSimulation
                  : l10n.studyIncludeInSimulation,
            ),
          ),
          PopupMenuItem(value: 'rename', child: Text(l10n.actionRename)),
          PopupMenuItem(
            value: 'runSettings',
            child: Text(l10n.studyRunSettings),
          ),
          PopupMenuItem(value: 'duplicate', child: Text(l10n.actionDuplicate)),
          PopupMenuItem(value: 'delete', child: Text(l10n.actionDelete)),
        ],
      ),
    );
  }
}

/// The five study tabs, plus the project-level Simulation tab (DESIGN.md
/// §12.1) — a run spans studies, so it cannot belong to one of them (§7.7).
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
  /// The Simulation tab, which the five before it are study tabs.
  static const _simulation = 5;

  @override
  void didUpdateWidget(_StudyTabs old) {
    super.didUpdateWidget(old);
    if (old.study.id == widget.study.id) return;
    // Switching studies resets to Flow rather than landing on whichever tab
    // the previous study was showing — unless the reader is on Simulation,
    // which is not about the study they just switched away from and would be
    // an odd thing to be thrown out of.
    if (widget.tabs.index != _simulation) widget.tabs.index = 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final study = widget.study;

    return Column(
      children: [
        TabBar(
          controller: widget.tabs,
          tabs: [
            Tab(text: l10n.studyTabFlow),
            Tab(text: l10n.studyTabTakt),
            Tab(text: l10n.workcenters),
            Tab(text: l10n.studyTabDemand),
            Tab(text: l10n.studyTabSummary),
            Tab(text: l10n.projectTabSimulation),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: widget.tabs,
            children: [
              FlowTab(study: study),
              TaktTab(project: widget.project, study: study),
              WorkcentersTab(project: widget.project, study: study),
              DemandTab(study: study),
              SummaryTab(study: study),
              SimulationTab(project: widget.project),
            ],
          ),
        ),
      ],
    );
  }
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
                helperText: l10n.studyLineHelp,
                helperMaxLines: 3,
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
