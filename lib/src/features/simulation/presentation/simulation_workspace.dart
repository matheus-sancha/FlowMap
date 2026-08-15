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
  const SimulationWorkspace({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<SimulationWorkspace> createState() =>
      _SimulationWorkspaceState();
}

class _SimulationWorkspaceState extends ConsumerState<SimulationWorkspace> {
  final _studies = <String>{};
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
          busy: runner.isLoading,
          canRun: input?.canRun ?? false,
          onChanged: () => setState(() {}),
          onRun: () => ref
              .read(simulationRunnerProvider(widget.project.id).notifier)
              .run(),
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
            AsyncError(:final error) => Center(child: Text('$error')),
            AsyncLoading() => const Center(child: CircularProgressIndicator()),
            AsyncValue(value: null) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.simulationNeverRun,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
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
    required this.busy,
    required this.canRun,
    required this.onChanged,
    required this.onRun,
    required this.onClear,
    required this.onPeriod,
  });

  final Project project;
  final Set<String> studies;
  final Set<String> cells;
  final Set<String> lines;
  final DateTimeRange? period;
  final bool busy;
  final bool canRun;
  final VoidCallback onChanged;
  final VoidCallback onRun;
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
          FilledButton.icon(
            onPressed: busy || !canRun ? null : onRun,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(busy ? l10n.simulationRunning : l10n.simulationRun),
          ),
        ],
      ),
    );
  }
}

/// A dropdown of checkboxes, showing how many are chosen.
///
/// A `DropdownButton` cannot hold a multiple selection, and a row of chips per
/// study would be wider than the bar on a plant with a dozen of them.
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
          StatefulBuilder(
            builder: (context, setLocal) => CheckboxMenuButton(
              value: selected.contains(entry.key),
              onChanged: (checked) {
                setLocal(() {
                  if (checked ?? false) {
                    selected.add(entry.key);
                  } else {
                    selected.remove(entry.key);
                  }
                });
                onChanged();
              },
              child: Text(entry.value),
            ),
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
