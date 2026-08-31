/// The Occupation view: a chart **and** a grid, switched (DESIGN.md §10.3, #9).
///
/// **The grid was added; the chart was not removed.** #9 concluded the stacked
/// bar should be deleted outright, and it was — the live database is a strong
/// argument for the grid: across the runs that can draw this view the aggregate
/// bar has **never once broken its capacity line**, peak 87 %, while single
/// stations reached 149 % and seven of seventeen were over in one month. A small
/// red `7` above an 87 % bar was carrying the whole signal.
///
/// **The field then said the chart was wanted adjusted, not deleted**, which
/// settles it: that is what a drive is for, and it outranks the ticket. So both
/// are here behind a `Chart | Grid` switch, and the argument above is why the
/// grid is the default rather than why the chart is gone.
///
/// What the grid adds that the chart could not: a per-station figure, so an
/// overloaded machine is visible under an aggregate that is not; two groupings;
/// three units; and the project's own bands. What the chart keeps that the grid
/// does not: the process / rework / changeover split, which exists nowhere else,
/// and the shape of a month read against the one before it.
///
/// **One filter, both surfaces.** They read the same `stationsInView`, so they
/// cannot disagree about which stations are being looked at.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/tokens.dart';
import '../../../common/period_matrix.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../common/horizontal_scroll.dart';
import '../application/occupation_graph.dart';
import '../application/occupation_grid.dart';
import '../application/run_filter.dart';

class OccupationView extends StatefulWidget {
  const OccupationView({super.key, required this.slice, required this.project});

  final FilteredRun slice;

  /// Whose thresholds band the cells — the project's own (§10.1, v29), the same
  /// shape and the same settings card as the float matrix's.
  final Project project;

  @override
  State<OccupationView> createState() => _OccupationViewState();
}

class _OccupationViewState extends State<OccupationView> {
  /// **View state, not a location.** §12.1 keeps the results filters out of the
  /// URL bar `?study=`, and how a reader is reading one tab is the same kind of
  /// thing as which of the plan's two shapes they chose.
  /// Which of the two the reader is looking at. **The grid by default**, for
  /// #9's reason: an aggregate cannot report the finding this view exists to
  /// find.
  bool _asGrid = true;

  OccupationGrouping _grouping = OccupationGrouping.workcenter;
  OccupationUnit _unit = OccupationUnit.percent;

  /// Which month the rows are ordered by, or **null for the arrival order** —
  /// worst month first, which is the question the view exists to answer and so
  /// the order it should already be in (#10).
  int? _sortedMonth;
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final graph = occupationGraph(
      run: widget.slice.run,
      filter: widget.slice.filter,
    );
    final grid = occupationGrid(
      run: widget.slice.run,
      filter: widget.slice.filter,
      grouping: _grouping,
    );

    // **A run before v25 offers no grid rather than an empty one** (§10.2). 144
    // of 147 stored runs are in this state, so this is the common case rather
    // than the edge — and inventing capacity from today's schedules would draw
    // a 2025 plant out of a 2026 one.
    if (grid == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.occupationUngraphable,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    final status = FlowStatus.of(context);
    final amber = widget.project.occupationAmberPct / 100;
    final red = widget.project.occupationRedPct / 100;

    PeriodMatrixCell? cellOf(OccupationRow row, int index) {
      final month = grid.months[index];
      final cell = row.cells[month];
      if (cell == null) return null;

      final ratio = cell.ratio;
      // **Three bands, from the project's own two thresholds** (v29) — the
      // float matrix's shape next door. `FlowStatus` is picked rather than
      // derived, so re-seeding the chrome cannot move a band (#8).
      final (Color background, Color foreground) = switch (ratio) {
        null => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.outline,
        ),
        final value when value > red => (
          status.critical.fill,
          status.critical.ink,
        ),
        final value when value > amber => (
          status.warning.fill,
          status.warning.ink,
        ),
        _ => (status.good.fill, status.good.ink),
      };

      final text = switch (_unit) {
        OccupationUnit.percent =>
          ratio == null ? '—' : '${(ratio * 100).round()}%',
        // Asked of, over open — §15's rule that a derived figure expands to
        // show its inputs, and what a percentage drops: 3,296 h of capacity in
        // one month and 9,384 in another read alike as a ratio.
        OccupationUnit.hours => '${cell.asked.inHours}/${cell.open.inHours}',
        OccupationUnit.gap => '${cell.gap.inHours}',
      };

      return PeriodMatrixCell(
        text: text,
        background: background,
        foreground: foreground,
        tooltip: l10n.occupationCellHelp(
          '${cell.asked.inHours}',
          row.name.isEmpty ? l10n.occupationPlant : row.name,
          DateFormat.yMMM().format(month),
          '${cell.open.inHours}',
          '${cell.filtered.inHours}',
        ),
        // The fill along the base is the filtered orders' share. It is what
        // tells "CEU27 is at 100 % and 80 of it is yours" from "CEU32 is at
        // 147 % and none of it is" — same colour, opposite action.
        share: cell.share,
      );
    }

    // **Sorted here rather than in the model** (#10): which month a reader is
    // ranking by is a way of reading the grid, not a fact about the run.
    // Descending first, because the row you came for is the overloaded one.
    final rows = [...grid.rows];
    if (_sortedMonth case final index?) {
      final month = grid.months[index];
      rows.sort((a, b) {
        // A row with nothing in that month sorts last either way — it is an
        // absence, not a value of zero, the same call the combined plan makes
        // about an empty release slot.
        final ka = a.cells[month]?.ratio;
        final kb = b.cells[month]?.ratio;
        if (ka == null || kb == null) {
          return ka == null ? (kb == null ? 0 : 1) : -1;
        }
        return _sortAscending ? ka.compareTo(kb) : kb.compareTo(ka);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.occupationViewChart),
                    icon: const Icon(Icons.bar_chart_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.occupationViewGrid),
                    icon: const Icon(Icons.grid_on_outlined, size: 18),
                  ),
                ],
                selected: {_asGrid},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _asGrid = s.first),
              ),
              // The grid's two switches, and only while the grid is showing —
              // a grouping control over a chart that has no rows would be a
              // control that does nothing.
              if (_asGrid)
                SegmentedButton<OccupationGrouping>(
                  segments: [
                    ButtonSegment(
                      value: OccupationGrouping.workcenter,
                      label: Text(l10n.occupationByWorkcenter),
                    ),
                    ButtonSegment(
                      value: OccupationGrouping.line,
                      label: Text(l10n.occupationByLine),
                    ),
                  ],
                  selected: {_grouping},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _grouping = s.first),
                ),
              if (_asGrid)
                SegmentedButton<OccupationUnit>(
                  segments: [
                    ButtonSegment(
                      value: OccupationUnit.percent,
                      label: Text(l10n.occupationUnitPercent),
                    ),
                    ButtonSegment(
                      value: OccupationUnit.hours,
                      label: Text(l10n.occupationUnitHours),
                    ),
                    ButtonSegment(
                      value: OccupationUnit.gap,
                      label: Text(l10n.occupationUnitGap),
                    ),
                  ],
                  selected: {_unit},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _unit = s.first),
                ),
              if (_asGrid) _Bands(project: widget.project),
            ],
          ),
          const SizedBox(height: 12),
          if (!_asGrid && graph != null) ...[
            _Legend(graph: graph),
            const SizedBox(height: 8),
            Expanded(child: _OccupationChart(graph: graph)),
          ] else
            Expanded(
              child: SingleChildScrollView(
                child: PeriodMatrix(
                  months: grid.months,
                  headerLabel: _grouping == OccupationGrouping.workcenter
                      ? l10n.occupationWorkcenter
                      : l10n.occupationLine,
                  rows: [
                    for (final row in rows)
                      PeriodMatrixRow(
                        label: row.name,
                        qualifier: row.qualifier,
                      ),
                  ],
                  cellAt: (row, month) => cellOf(rows[row], month),
                  sortedMonth: _sortedMonth,
                  sortAscending: _sortAscending,
                  onSortMonth: (index) => setState(() {
                    if (_sortedMonth == index) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortedMonth = index;
                      _sortAscending = false;
                    }
                  }),
                  // **Only when nothing has narrowed the station set** — once a
                  // line or a type is chosen, a total across what is left would
                  // be a partial wearing the plant's name.
                  pinned: grid.plant == null
                      ? null
                      : PeriodMatrixRow(
                          label: l10n.occupationPlant,
                          emphasis: true,
                        ),
                  pinnedCellAt: grid.plant == null
                      ? null
                      : (month) => cellOf(grid.plant!, month),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The two thresholds, named beside the grid they band.
///
/// The float matrix carries a legend for the same reason: the thresholds are the
/// project's own, so a reader cannot know what amber means without being told.
class _Bands extends StatelessWidget {
  const _Bands({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = FlowStatus.of(context);

    Widget swatch(Color fill, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );

    return Wrap(
      spacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        swatch(status.good.fill, '≤ ${project.occupationAmberPct}%'),
        swatch(status.warning.fill, '> ${project.occupationAmberPct}%'),
        swatch(status.critical.fill, '> ${project.occupationRedPct}%'),
      ],
    );
  }
}

/// What the four segments are, and how many stations the bars aggregate.
class _Legend extends StatelessWidget {
  const _Legend({required this.graph});

  final OccupationGraph graph;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colours = _SegmentColours.of(context);

    Widget swatch(Color colour, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: colour),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        swatch(colours.process, l10n.occupationProcess),
        swatch(colours.rework, l10n.occupationRework),
        swatch(colours.changeover, l10n.occupationChangeover),
        // Named for what it is rather than "other": it is the demand of lines
        // the filter excluded, and a reader has to know the bar still holds it.
        swatch(colours.other, l10n.occupationOutsideFilter),
        Text(
          l10n.occupationStations(graph.stationsInView.length),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _SegmentColours {
  const _SegmentColours({
    required this.process,
    required this.rework,
    required this.changeover,
    required this.other,
    required this.line,
    required this.over,
  });

  /// **From [OccupationRamp], not from the colour scheme** (#8). These read
  /// `primary`, `tertiary` and `secondary` in v1.0 — three *generated* hues
  /// carrying meaning nobody picked, and the exact coupling `tokens.dart` was
  /// written to remove. The stack is an ordered quantity, so it is one hue
  /// light-to-dark; `over` is [FlowStatus.critical]'s ink, because exceeding
  /// capacity is a state rather than more of the same quantity.
  factory _SegmentColours.of(BuildContext context) {
    final ramp = OccupationRamp.of(context);
    final theme = Theme.of(context);
    return _SegmentColours(
      process: ramp.process,
      rework: ramp.rework,
      changeover: ramp.changeover,
      other: ramp.other,
      line: theme.colorScheme.onSurface,
      over: FlowStatus.of(context).critical.ink,
    );
  }

  final Color process;
  final Color rework;
  final Color changeover;
  final Color other;
  final Color line;
  final Color over;
}

class _OccupationChart extends StatelessWidget {
  const _OccupationChart({required this.graph});

  final OccupationGraph graph;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A month is 64 px, so a two-year run scrolls rather than shrinking its
    // bars into stripes.
    final width = graph.months.length * 64.0;
    return HorizontalScroll(
      child: SizedBox(
        width: width < 320 ? 320 : width,
        child: CustomPaint(
          painter: _OccupationPainter(
            graph: graph,
            colours: _SegmentColours.of(context),
            grid: theme.colorScheme.outlineVariant,
            label:
                theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurface,
            direction: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

/// Stacked bars, a capacity line, and a month label under each column.
class _OccupationPainter extends CustomPainter {
  _OccupationPainter({
    required this.graph,
    required this.colours,
    required this.grid,
    required this.label,
    required this.direction,
  });

  final OccupationGraph graph;
  final _SegmentColours colours;
  final Color grid;
  final Color label;
  final TextDirection direction;

  static const _axis = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final months = graph.months;
    if (months.isEmpty) return;

    final plot = size.height - _axis;
    // **The tallest bar or the line, whichever is higher.** A scale fitted to
    // the bars alone would push the capacity line off the top on a quiet month
    // and make an under-loaded plant look overloaded.
    var peak = 0;
    for (final month in months) {
      final total = month.total.inSeconds;
      if (total > peak) peak = total;
      if (month.capacity.inSeconds > peak) peak = month.capacity.inSeconds;
    }
    if (peak <= 0) return;

    double y(int seconds) => plot * (1 - seconds / peak);
    final columnWidth = size.width / months.length;

    for (var i = 0; i < months.length; i++) {
      final month = months[i];
      final left = i * columnWidth + columnWidth * 0.18;
      final right = (i + 1) * columnWidth - columnWidth * 0.18;

      // Stacked from the floor up in the order they are charged: the work, then
      // rework on top of it, then the changeover, then whatever the filter is
      // not showing.
      var floor = 0;
      void segment(Duration part, Color colour) {
        if (part <= Duration.zero) return;
        final top = floor + part.inSeconds;
        canvas.drawRect(
          Rect.fromLTRB(left, y(top), right, y(floor)),
          Paint()..color = colour,
        );
        floor = top;
      }

      segment(month.process, colours.process);
      segment(month.rework, colours.rework);
      segment(month.changeover, colours.changeover);
      segment(month.other, colours.other);

      // The capacity line, drawn per column rather than as one polyline: it is
      // a step function — a month with a shutdown genuinely has less capacity
      // than the one before — and a sloping line between two months would claim
      // a capacity neither had.
      final capacity = y(month.capacity.inSeconds);
      canvas.drawLine(
        Offset(i * columnWidth, capacity),
        Offset((i + 1) * columnWidth, capacity),
        Paint()
          ..color = colours.line
          ..strokeWidth = 2,
      );

      _text(
        canvas,
        DateFormat('MMM/yy').format(month.month),
        Offset((i + 0.5) * columnWidth, plot + 6),
        label,
        centred: true,
      );

      // How many individual stations are over, where the sum alone would not
      // say (§10.3). Only when there are any — a badge on every column would be
      // noise on a plant that is coping.
      if (month.stationsOver > 0) {
        _text(
          canvas,
          '${month.stationsOver}',
          Offset((i + 0.5) * columnWidth, y(month.total.inSeconds) - 14),
          colours.over,
          centred: true,
        );
      }
    }

    canvas.drawLine(
      Offset(0, plot),
      Offset(size.width, plot),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    Color colour, {
    bool centred = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: colour, fontSize: 10),
      ),
      textDirection: direction,
    )..layout();
    painter.paint(canvas, centred ? at.translate(-painter.width / 2, 0) : at);
  }

  @override
  bool shouldRepaint(_OccupationPainter old) =>
      old.graph != graph || old.colours.process != colours.process;
}
