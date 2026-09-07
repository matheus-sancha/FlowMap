import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../common/help_icon.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../projects/presentation/workspace_tabs.dart';
import '../application/run_filter.dart';
import '../application/simulation_providers.dart';
import '../data/simulation_runs_repository.dart' show StoredRun;
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
    required this.tab,
    this.initialStudyId,
  });

  final Project project;

  /// Which of the five results tabs the location names (#7).
  ///
  /// **Passed in rather than held.** The tab is a fact about the URL, so a
  /// chart is linkable and the window reopens on the one that was being read —
  /// which is the gap §12.1 claimed was closed and was not.
  final SimulationTab tab;

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

  /// §7.5's three. Unlike the studies, cells and lines above, these are values
  /// out of the **run** rather than out of the plant — so they have nothing to
  /// offer until a run exists, and a run replaced by a newer one may not contain
  /// what is selected.
  final _projects = <String>{};
  final _parts = <String>{};
  final _orders = <int>{};

  /// **#9's two, promoted out of the Occupation view.** They were
  /// `OccupationStations`, owned by that view and reaching nothing else — so a
  /// reader narrowing to one workcenter narrowed a chart and left the Gantt and
  /// the queue tables drawing the whole plant. They are structural filters like
  /// the cells and lines beside them, and every surface whose rows are stations
  /// obeys them now.
  final _types = <String>{};
  final _workcenters = <String>{};

  DateTimeRange? _period;

  /// **Copied, every one of them.** The pickers above mutate these sets in
  /// place, so handing the instances over would give a value object a live view
  /// of state that changes under it — which is what made a slice taken before an
  /// edit report the identity of the slice after it. `FilteredRun` now fixes its
  /// signature when it is built, so this is no longer what stands between the
  /// Gantt and a stale chart; it is here because a filter that shares its
  /// caller's mutable state is a trap for the next thing that compares two.
  RunFilter get _filter => RunFilter(
    studyIds: {..._studies},
    cellIds: {..._cells},
    lineIds: {..._lines},
    customerProjects: {..._projects},
    partNumbers: {..._parts},
    orderNumbers: {..._orders},
    typeIds: {..._types},
    workcenterIds: {..._workcenters},
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
          // The run itself, for the three filters whose options are values in
          // it rather than parts of the plant.
          run: runner.value,
          filter: _filter,
          studies: _studies,
          cells: _cells,
          lines: _lines,
          projects: _projects,
          parts: _parts,
          orders: _orders,
          types: _types,
          workcenters: _workcenters,
          period: _period,
          onChanged: () => setState(() {}),
          onClear: () => setState(() {
            _studies.clear();
            _cells.clear();
            _lines.clear();
            _projects.clear();
            _parts.clear();
            _orders.clear();
            _types.clear();
            _workcenters.clear();
            _period = null;
          }),
          onOrders: (values) => setState(() {
            _orders
              ..clear()
              ..addAll(values);
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
            // **Not keyed on the slice.** It was, on the argument that the
            // results widget holds the reader's zoom and view choice against the
            // slice it was given — so a new slice should discard them. That
            // threw away the *view choice* as well, and a reader who filters
            // while reading the Gantt was dropped back onto the tables at every
            // keystroke, which is what the field reported.
            //
            // The argument was also unnecessary. `GanttView.didUpdateWidget`
            // already compares `slice.signature` and rebuilds its chart, refits
            // its zoom and drops its hover and selection when it changes — so
            // the state that genuinely must not survive a new slice is discarded
            // by the widget that owns it, and the state that should survive now
            // does.
            AsyncValue(value: final run!) => RunResults(
              slice: filterRun(run, _filter),
              projectName: widget.project.name,
              project: widget.project,
              tab: widget.tab,
            ),
          },
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.project,
    required this.run,
    required this.filter,
    required this.studies,
    required this.cells,
    required this.lines,
    required this.projects,
    required this.parts,
    required this.orders,
    required this.types,
    required this.workcenters,
    required this.period,
    required this.onChanged,
    required this.onClear,
    required this.onOrders,
    required this.onPeriod,
  });

  final Project project;

  /// Null until a run exists, which is what leaves §7.5's three with nothing to
  /// offer. **The right dependency rather than an awkward one**: offering a part
  /// number the run never made would be a filter that returns nothing and looks
  /// broken, which is the argument §7.10 makes for a run joining to nothing,
  /// read from the other end.
  final StoredRun? run;

  /// What is already narrowed, so each picker can offer what would still
  /// narrow further (§7.6).
  final RunFilter filter;

  final Set<String> studies;
  final Set<String> cells;
  final Set<String> lines;
  final Set<String> projects;
  final Set<String> parts;
  final Set<int> orders;
  final Set<String> types;
  final Set<String> workcenters;
  final DateTimeRange? period;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final ValueChanged<Set<int>> onOrders;
  final ValueChanged<DateTimeRange?> onPeriod;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // **Every picker offers what could still narrow what is on screen** (§7.6),
    // computed from the run rather than from the plant. Two complaints from the
    // field are one rule: the Cells and Lines menus used to list every cell and
    // line in the *plant*, most of which no study had ever used, and choosing a
    // study left the Part numbers menu offering parts that study never makes.
    //
    // `studiesProvider` and `plantLinesProvider` are no longer read here at all.
    // §7.10 puts each study's cell and line on the run precisely so a filter
    // survives the plant being re-organised, and the run's studies are by
    // definition the ones that have a simulation.
    final options = runFilterOptions(run, filter);

    // The sentinel keeps its key and takes its label here, so it reads in the
    // reader's language and sorts to the top rather than under whatever `(no
    // project)` is called in Portuguese.
    final projectOptions = <String, String>{
      if (options.projects.containsKey(RunFilter.noProject))
        RunFilter.noProject: l10n.simFilterNoProject,
      for (final entry in options.projects.entries)
        if (entry.key != RunFilter.noProject) entry.key: entry.value,
    };

    final anyFilter =
        studies.isNotEmpty ||
        cells.isNotEmpty ||
        lines.isNotEmpty ||
        projects.isNotEmpty ||
        parts.isNotEmpty ||
        orders.isNotEmpty ||
        types.isNotEmpty ||
        workcenters.isNotEmpty ||
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
                    options: options.studies,
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
                    options: options.cells,
                    selected: cells,
                    onChanged: onChanged,
                  ),
                  const SizedBox(width: 8),
                  _MultiPicker(
                    label: l10n.simFilterLines,
                    options: options.lines,
                    selected: lines,
                    onChanged: onChanged,
                  ),
                  const SizedBox(width: 8),
                  // **#9's two, beside the other structural filters** — these
                  // choose the station set, so demand and capacity move
                  // together and a cell still reads everyone's demand over that
                  // station's full capacity. Next to Cells and Lines rather
                  // than next to §7.5's three, because what a filter *does* is
                  // the thing worth grouping by: these four narrow the plant,
                  // the three after them narrow the orders.
                  _MultiPicker(
                    label: l10n.occupationType,
                    options: options.types,
                    selected: types,
                    onChanged: onChanged,
                  ),
                  const SizedBox(width: 8),
                  _MultiPicker(
                    label: l10n.occupationStation,
                    options: options.workcenters,
                    selected: workcenters,
                    onChanged: onChanged,
                  ),
                  const SizedBox(width: 8),
                  // §7.5's three, after the plant's and before the period, so
                  // the bar reads outward from what the plant *is* to what this
                  // run put through it.
                  _MultiPicker(
                    label: l10n.simFilterProjects,
                    options: projectOptions,
                    selected: projects,
                    onChanged: onChanged,
                  ),
                  const SizedBox(width: 8),
                  _MultiPicker(
                    label: l10n.simFilterParts,
                    options: options.parts,
                    selected: parts,
                    onChanged: onChanged,
                  ),
                  const SizedBox(width: 8),
                  // **Typed rather than picked.** A 190-order run would make a
                  // menu of 190 entries, which is a list to scroll rather than a
                  // filter to use — and a planner reaching for an order number
                  // already knows the number.
                  _OrderNumberField(
                    values: orders,
                    enabled: run != null,
                    // How many studies the *other* filters leave in view, so
                    // the warning counts what a number would actually match.
                    studiesInView: options.studiesInView,
                    onChanged: onOrders,
                  ),
                  const SizedBox(width: 8),
                  _PeriodSlicer(
                    months: run == null ? const [] : runMonths(run!),
                    period: period,
                    onChanged: onPeriod,
                  ),
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

/// The order-number field, which is the one filter control a test cannot reach
/// by its label — the others are buttons carrying their own text.
@visibleForTesting
const orderFilterFieldKey = ValueKey('filter-order-numbers');

/// The order-number filter (§7.5), typed rather than picked.
///
/// A 190-order run would make a menu of 190 entries, which is a list to scroll
/// rather than a filter to use — and a planner reaching for an order number
/// already knows the number. Commas or spaces separate several.
///
/// **It says that a number is not unique.** An order number is a position in
/// *one* study's release sequence, so with two studies in view `5` selects order
/// five of each — every 190-order run in the live database has each number
/// twice. Narrowing to one is what the Studies filter beside it is for, and the
/// field says so rather than letting the reader assume it found one thing.
class _OrderNumberField extends StatefulWidget {
  const _OrderNumberField({
    required this.values,
    required this.enabled,
    required this.studiesInView,
    required this.onChanged,
  });

  final Set<int> values;
  final bool enabled;

  /// How many studies the rest of the filter leaves in view, which is how many
  /// orders one number names.
  final int studiesInView;

  final ValueChanged<Set<int>> onChanged;

  @override
  State<_OrderNumberField> createState() => _OrderNumberFieldState();
}

class _OrderNumberFieldState extends State<_OrderNumberField> {
  late final _controller = TextEditingController(text: _format(widget.values));

  static String _format(Set<int> values) =>
      (values.toList()..sort()).join(', ');

  /// **Anything that is not a positive number is dropped, not refused.** The
  /// field narrows a view rather than writing a row, so §9.2's "forgiving is not
  /// guessing" applies at its most forgiving end: a half-typed `5,` means five
  /// while the comma is being typed, and stopping to complain about it would
  /// fight the reader mid-keystroke.
  static Set<int> _parse(String text) => {
    for (final piece in text.split(RegExp(r'[,;\s]+')))
      if (int.tryParse(piece.trim()) case final n? when n > 0) n,
  };

  @override
  void didUpdateWidget(_OrderNumberField old) {
    super.didUpdateWidget(old);
    // Cleared from outside — the Clear button — rather than by typing.
    if (widget.values.isEmpty && _parse(_controller.text).isNotEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ambiguous = widget.values.isNotEmpty && widget.studiesInView > 1;

    return SizedBox(
      width: 168,
      child: TextField(
        key: orderFilterFieldKey,
        controller: _controller,
        enabled: widget.enabled,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: l10n.simFilterOrders,
          hintText: l10n.simFilterOrdersHint,
          // Said only while it is true, which is the rule the Gantt's floored-bar
          // note already follows: a permanent caveat is one a reader stops
          // seeing.
          helperText: ambiguous
              ? l10n.simFilterOrdersEachStudy(widget.studiesInView)
              : null,
          helperMaxLines: 3,
          suffixIcon: widget.values.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged(const {});
                  },
                ),
        ),
        keyboardType: TextInputType.number,
        onChanged: (text) => widget.onChanged(_parse(text)),
      ),
    );
  }
}

/// The period slicer: a range over the run's own months (#17).
///
/// **It replaced `showDateRangePicker`, and the reason is a defect.** The modal
/// picked *days* while the button beside it printed only year and month, so
/// choosing 15 January to 20 February read back as `2026-01 → 2026-02` — a
/// control accepting precision it never showed. Snapping to whole months makes
/// the control say exactly what it takes, and it is the resolution every
/// surface downstream buckets by in any case.
///
/// **The stops are the run's own months**, from [runMonths], so a range outside
/// the run cannot be expressed and the empty slice this filter used to be able
/// to produce is now unreachable. Other filters can still empty a run; this one
/// cannot, which is why `occupationUngraphable` keeps meaning what it says —
/// *this run predates v25* — rather than acquiring a second meaning.
///
/// _Rejected: day resolution over the span._ ~450 stops in a filter bar is a
/// pixel a day, so no one lands on a date by dragging and the label would have
/// to become the real control.
/// _Rejected: a sparkline of orders per month behind the track._ It reads well
/// and it is a chart in a filter bar — a new painter, nothing in the suite
/// renders a pixel, and it would land unverified.
class _PeriodSlicer extends StatelessWidget {
  const _PeriodSlicer({
    required this.months,
    required this.period,
    required this.onChanged,
  });

  /// Ascending, one entry per month the run holds anything for.
  final List<DateTime> months;
  final DateTimeRange? period;
  final ValueChanged<DateTimeRange?> onChanged;

  /// The last instant of [month], so `to` includes the whole of it.
  static DateTime _endOf(DateTime month) =>
      DateTime(month.year, month.month + 1, 0, 23, 59, 59);

  int _indexFor(DateTime date, {required int fallback}) {
    final key = DateTime(date.year, date.month);
    final at = months.indexWhere((m) => !m.isBefore(key));
    if (at < 0) return fallback;
    return at;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // **A run with one month has no range to drag**, and `RangeSlider` asserts
    // on min == max. Nothing is lost by omitting it: the only range a one-month
    // run can express is the one it already has.
    if (months.length < 2) return const SizedBox.shrink();

    final last = months.length - 1;
    final start = period == null
        ? 0
        : _indexFor(period!.start, fallback: 0);
    final end = period == null ? last : _indexFor(period!.end, fallback: last);
    final values = RangeValues(
      start.clamp(0, last).toDouble(),
      end.clamp(0, last).toDouble(),
    );
    final whole = values.start == 0 && values.end == last;
    final format = DateFormat.yMMM(Localizations.localeOf(context).toString());

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              whole
                  ? '${l10n.simFilterPeriod} · ${l10n.simFilterAll}'
                  : '${format.format(months[values.start.round()])}'
                        ' → ${format.format(months[values.end.round()])}',
              style: theme.textTheme.bodySmall,
            ),
            SizedBox(
              width: 220,
              child: RangeSlider(
                values: values,
                min: 0,
                max: last.toDouble(),
                divisions: last,
                labels: RangeLabels(
                  format.format(months[values.start.round()]),
                  format.format(months[values.end.round()]),
                ),
                onChanged: (next) {
                  final lo = next.start.round();
                  final hi = next.end.round();
                  // The whole span is *no filter*, not a filter that happens to
                  // match everything — so `isWholeRun` stays true and every
                  // surface that asks whether anything narrowed keeps its
                  // answer (§12.1).
                  if (lo == 0 && hi == last) return onChanged(null);
                  onChanged(
                    DateTimeRange(start: months[lo], end: _endOf(months[hi])),
                  );
                },
              ),
            ),
          ],
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
