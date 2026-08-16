import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/help_icon.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../resources/application/resources_providers.dart';
import '../../studies/application/studies_providers.dart';
import '../application/run_filter.dart';
import '../application/simulation_providers.dart';
import 'simulation_tab.dart';

/// The whole project's run, filtered (DESIGN.md §12.1).
///
/// **A destination in the studies sidebar rather than a tab or an overlay.** A
/// run spans studies (§7.7), so it does not belong inside one of them; and it is
/// deep-linkable like every other route, because a filtered view and a run's
/// history are both things worth sending someone a link to.
///
/// It reads the same `StoredRun` a study's own Simulation tab reads, through the
/// same `filterRun` — so the two cannot report different numbers for the same
/// study. Simulate stays on the project app bar as well as being here: §12.1's
/// rule is that starting a run must not require navigating somewhere first,
/// which is the complaint that moved the button there in the first place.
class SimulationWorkspace extends ConsumerStatefulWidget {
  const SimulationWorkspace({
    super.key,
    required this.project,
    this.initialStudyId,
  });

  final Project project;

  /// The study to narrow to on arrival, from the route's `?study=`.
  ///
  /// **This is what replaced the study's Simulation tab.** That tab was this
  /// widget with one filter pre-applied, so the tab became a link rather than a
  /// screen — and because both read one `StoredRun` through one `RunFilter`,
  /// the slice a study shows is the same slice it always showed.
  final String? initialStudyId;

  @override
  ConsumerState<SimulationWorkspace> createState() =>
      _SimulationWorkspaceState();
}

class _SimulationWorkspaceState extends ConsumerState<SimulationWorkspace> {
  late final Set<String> _studies = {?widget.initialStudyId};
  final _cells = <String>{};
  final _lines = <String>{};
  DateTimeRange? _period;

  RunFilter get _filter => RunFilter(
    studyIds: _studies,
    cellIds: _cells,
    lineIds: _lines,
    from: _period?.start,
    to: _period?.end,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runner = ref.watch(simulationRunnerProvider(widget.project.id));
    final input = ref.watch(simRunInputProvider(widget.project.id)).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterBar(
          project: widget.project,
          studies: _studies,
          cells: _cells,
          lines: _lines,
          period: _period,
          onChanged: () => setState(() {}),
          onClear: () => setState(() {
            _studies.clear();
            _cells.clear();
            _lines.clear();
            _period = null;
          }),
          onPeriod: (range) => setState(() => _period = range),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (runner) {
            AsyncError(:final error) => _Message(
              icon: Icons.error_outline,
              title: '$error',
            ),
            AsyncLoading() => const Center(child: CircularProgressIndicator()),
            // **Nothing to run and nothing run yet are different problems**, and
            // this screen used to draw both as one blank pane — the deleted
            // Simulation tab was the only thing that told them apart, so the
            // distinction moved here with its body rather than dying with it.
            AsyncValue(value: null) when input?.isEmpty ?? false => _Message(
              icon: Icons.playlist_add_check_outlined,
              title: l10n.simulationNoStudies,
              detail: l10n.simulationNoStudiesHelp,
            ),
            AsyncValue(value: null) => _Message(
              icon: Icons.timeline_outlined,
              title: l10n.simulationNeverRun,
              detail: l10n.simulationNeverRunHelp,
            ),
            AsyncValue(value: final run!) => RunResults(
              // Rebuilt when the filter changes, because the results widget
              // holds the reader's zoom and view choice against the slice it was
              // given — and a slice is what changed.
              key: ValueKey(filterRun(run, _filter).signature),
              slice: filterRun(run, _filter),
              projectName: widget.project.name,
            ),
          },
        ),
      ],
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({
    required this.project,
    required this.studies,
    required this.cells,
    required this.lines,
    required this.period,
    required this.onChanged,
    required this.onClear,
    required this.onPeriod,
  });

  final Project project;
  final Set<String> studies;
  final Set<String> cells;
  final Set<String> lines;
  final DateTimeRange? period;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final ValueChanged<DateTimeRange?> onPeriod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final allStudies =
        ref.watch(studiesProvider(project.id)).value ?? const <Study>[];
    final plantLines =
        ref.watch(plantLinesProvider(project.plantId)).value ?? const [];

    // Cells and lines are offered from the plant rather than from the run, so
    // the filter reads the same before and after a run exists.
    final cellsById = <String, String>{
      for (final line in plantLines) line.cell.id: line.cell.name,
    };
    final linesById = <String, String>{
      for (final line in plantLines) line.line.id: line.line.name,
    };

    final anyFilter =
        studies.isNotEmpty ||
        cells.isNotEmpty ||
        lines.isNotEmpty ||
        period != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _MultiPicker(
                    label: l10n.simFilterStudies,
                    options: {for (final s in allStudies) s.id: s.name},
                    selected: studies,
                    onChanged: onChanged,
                  ),
                  const SizedBox(width: 8),
                  // **A cell or line filter is a study filter one level up**
                  // (§7.10): workcenters belong to a plant, not to a cell, so
                  // these narrow which studies are in view and the stations
                  // follow from them.
                  _MultiPicker(
                    label: l10n.simFilterCells,
                    options: cellsById,
                    selected: cells,
                    onChanged: onChanged,
                  ),
                  const SizedBox(width: 8),
                  _MultiPicker(
                    label: l10n.simFilterLines,
                    options: linesById,
                    selected: lines,
                    onChanged: onChanged,
                  ),
                  const SizedBox(width: 8),
                  _PeriodPicker(period: period, onChanged: onPeriod),
                  if (anyFilter) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onClear,
                      icon: const Icon(Icons.clear, size: 18),
                      label: Text(l10n.simFilterClear),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // **Which run is being read**, beside the filters that narrow it.
          //
          // Simulate itself is not here: the app bar's button is the one
          // trigger now, and two buttons for one action about 200 px apart is
          // what the field reported on opening this screen (§12.1).
          RunsMenu(projectId: project.id),
        ],
      ),
    );
  }
}

/// A dropdown of checkboxes, showing how many are chosen.
///
/// A `DropdownButton` cannot hold a multiple selection, and a row of chips per
/// study would be wider than the bar on a plant with a dozen of them.
///
/// **No `StatefulBuilder` around the items, and that was the bug.** Each item
/// was wrapped in one so the tick could repaint itself before the parent
/// rebuilt. But `CheckboxMenuButton` closes the menu when it is activated,
/// which disposes that builder — and `State.setState` asserts it is still
/// mounted *before* it runs the callback it was given. So the line that added
/// the study to the set never ran, and the `onChanged()` after it never ran
/// either. The filter did nothing at all, in every build since it shipped,
/// while the picker's own label counted the selection correctly enough to look
/// like it was working.
///
/// The selection is the parent's state, so the parent's rebuild is what should
/// repaint the tick. There was never a second piece of state to keep in step.
class _MultiPicker extends StatelessWidget {
  const _MultiPicker({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final Map<String, String> options;
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MenuAnchor(
      menuChildren: [
        for (final entry in options.entries)
          CheckboxMenuButton(
            // **The menu stays open**, so several studies can be ticked in one
            // visit rather than one reopening per choice. Not what fixed the
            // bug above — removing the builder is — but it is why the builder
            // looked necessary in the first place.
            closeOnActivate: false,
            value: selected.contains(entry.key),
            onChanged: (checked) {
              if (checked ?? false) {
                selected.add(entry.key);
              } else {
                selected.remove(entry.key);
              }
              onChanged();
            },
            child: Text(entry.value),
          ),
      ],
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.arrow_drop_down, size: 18),
        iconAlignment: IconAlignment.end,
        // Empty means every one of them, which is what the whole run is — so
        // the button says `all` rather than `0`.
        label: Text(
          selected.isEmpty ? '$label · ${l10n.simFilterAll}' : '$label · ${selected.length}',
        ),
      ),
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.period, required this.onChanged});

  final DateTimeRange? period;
  final ValueChanged<DateTimeRange?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDateRange: period,
            );
            if (picked != null) onChanged(picked);
          },
          icon: const Icon(Icons.date_range, size: 18),
          label: Text(
            period == null
                ? '${l10n.simFilterPeriod} · ${l10n.simFilterAll}'
                : '${period!.start.year}-${period!.start.month.toString().padLeft(2, '0')}'
                      ' → ${period!.end.year}-${period!.end.month.toString().padLeft(2, '0')}',
          ),
        ),
        // The one thing about this filter a reader has to know, and it cannot be
        // guessed from the control: it selects by **need date**, which is the
        // only one of an order's dates that is never null — so an order the run
        // never completed still appears in its period rather than vanishing.
        helpIcon(context, l10n.simFilterPeriodHelp) ?? const SizedBox.shrink(),
      ],
    );
  }
}

/// An empty state: an icon, a sentence and an optional explanation.
///
/// Moved here with the Simulation tab's body (§12.1). It is the deleted tab
/// that knew "nothing is flagged for a run" was worth saying rather than
/// leaving as an empty screen, and dropping it with the tab would have lost
/// that distinction — nothing to run and nothing run yet read identically as a
/// blank pane and are different problems.
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
