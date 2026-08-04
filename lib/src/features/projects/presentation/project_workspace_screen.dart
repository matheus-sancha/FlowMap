import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/dialogs.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../flow/presentation/flow_tab.dart';
import '../../resources/application/resources_providers.dart';
import '../../resources/data/resources_repository.dart';
import '../../schedules/presentation/takt_tab.dart';
import '../../schedules/presentation/workcenters_tab.dart';
import '../../studies/application/studies_providers.dart';
import '../application/projects_providers.dart';

/// The project workspace: a studies sidebar, and the five tabs of whichever
/// study is open (DESIGN.md §12.1).
///
/// Simulation is a project-level tab rather than a study one, because a run
/// spans studies (§7.7) — it arrives in M4.
class ProjectWorkspaceScreen extends ConsumerWidget {
  const ProjectWorkspaceScreen({
    super.key,
    required this.projectId,
    this.studyId,
  });

  final String projectId;
  final String? studyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            title: Text(project.name),
          ),
          body: Row(
            children: [
              SizedBox(
                width: 280,
                child: _StudiesSidebar(
                  project: project,
                  studies: studyList,
                  selectedId: selected?.id,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: selected == null
                    ? _NoStudyYet(project: project)
                    : _StudyTabs(project: project, study: selected),
              ),
            ],
          ),
        );
      },
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
          PopupMenuItem(value: 'duplicate', child: Text(l10n.actionDuplicate)),
          PopupMenuItem(value: 'delete', child: Text(l10n.actionDelete)),
        ],
      ),
    );
  }
}

class _StudyTabs extends StatelessWidget {
  const _StudyTabs({required this.project, required this.study});

  final Project project;
  final Study study;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      // Keyed by study so switching studies resets to the Flow tab rather than
      // landing on whichever tab the previous study was showing.
      key: ValueKey(study.id),
      length: 5,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.studyTabFlow),
              Tab(text: l10n.studyTabTakt),
              Tab(text: l10n.workcenters),
              Tab(text: l10n.studyTabDemand),
              Tab(text: l10n.studyTabSummary),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                FlowTab(study: study),
                TaktTab(project: project, study: study),
                WorkcentersTab(project: project, study: study),
                _ComingInMilestone(milestone: l10n.milestoneDemand),
                _ComingInMilestone(milestone: l10n.milestoneSummary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingInMilestone extends StatelessWidget {
  const _ComingInMilestone({required this.milestone});

  final String milestone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        milestone,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
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
          onPressed: value.isEmpty || taken
              ? null
              : () => Navigator.of(context).pop((name: value, line: _line)),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
