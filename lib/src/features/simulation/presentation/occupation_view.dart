/// The Occupation grid: station × month, banded (DESIGN.md §10.3, #9).
///
/// **This file replaced a chart.** It held a stacked bar per month, a capacity
/// line, a four-segment legend and a `CustomPainter`; all of it is gone. The
/// live database is the argument: across the three stored runs that can draw
/// this view, the aggregate bar **never once broke its capacity line** — peak
/// 87 % — while single stations reached 149 % and seven of seventeen were over
/// in one month. A small red `7` floating above an 87 % bar was carrying the
/// whole signal. Two of the four stack segments were hairlines besides, at 3 %
/// and 2 %.
///
/// **The centring fix dissolved rather than being made.** The capacity line was
/// drawn per column across each column's full width — deliberately, because
/// capacity is a step function — and that is what read as disconnected
/// segments. With the chart gone there is no line to centre.
///
/// **Two named losses**, recorded rather than quietly dropped. The process /
/// rework / changeover split existed only as stack segments and has nowhere left
/// to live; at 3 % and 2 % of a bar it was two hairlines, but it is gone rather
/// than moved. And a line's own share of a station is not on the grid: cell and
/// line are structural filters and do not dim, so only project and part show a
/// share. The retired pivot was the one place that number lived.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/tokens.dart';
import '../../../common/period_matrix.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
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
        OccupationUnit.percent => ratio == null
            ? '—'
            : '${(ratio * 100).round()}%',
        // Asked of, over open — §15's rule that a derived figure expands to
        // show its inputs, and what a percentage drops: 3,296 h of capacity in
        // one month and 9,384 in another read alike as a ratio.
        OccupationUnit.hours =>
          '${cell.asked.inHours}/${cell.open.inHours}',
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
              _Bands(project: widget.project),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: PeriodMatrix(
                months: grid.months,
                headerLabel: _grouping == OccupationGrouping.workcenter
                    ? l10n.occupationWorkcenter
                    : l10n.occupationLine,
                rows: [
                  for (final row in rows)
                    PeriodMatrixRow(label: row.name, qualifier: row.qualifier),
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
