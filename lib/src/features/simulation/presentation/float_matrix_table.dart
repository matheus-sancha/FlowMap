import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/tokens.dart';
import '../../../common/horizontal_scroll.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/float_matrix.dart';
import '../application/run_filter.dart';

/// Float, month by month (`TODO.md` §10.4).
///
/// **A table rather than a chart**, because the figure a planner acts on is the
/// number of days rather than its shape: the colour is what makes the shape
/// readable at a glance and the digits are what they write down.
class FloatMatrixTable extends StatelessWidget {
  const FloatMatrixTable({
    super.key,
    required this.slice,
    required this.project,
  });

  final FilteredRun slice;

  /// Whose thresholds colour the cells — the project's own (§10.1).
  final Project project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final matrix = buildFloatMatrix(
      slice: slice,
      redDays: project.floatRedDays,
      greenDays: project.floatGreenDays,
      partNumbers: {
        for (final part in slice.metrics.parts) part.partId: part.partNumber,
      },
    );

    if (matrix.isEmpty) {
      return Text(
        l10n.floatMatrixEmpty,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    }

    final tally = matrix.tally;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // **A legend, not a tally** (v2.0). The line here read
        // `3 red · 5 amber · 12 green` in the body colour — it named the
        // colours in words while showing none of them, and it never said what
        // the bands actually are. The thresholds are the project's own
        // (§10.4), so a reader cannot know that `amber` means 1-29 days
        // without being told. Each entry now carries its own swatch, the
        // threshold that defines it and its count.
        _Legend(project: project, tally: tally),
        const SizedBox(height: 8),
        HorizontalScroll(
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 32,
            columns: [
              const DataColumn(label: Text('#')),
              for (final month in matrix.months)
                DataColumn(
                  label: Text(DateFormat('MMM/yy').format(month)),
                  numeric: true,
                ),
            ],
            rows: [
              for (final (rank, row) in matrix.rows.indexed)
                DataRow(
                  cells: [
                    DataCell(Text('${rank + 1}')),
                    for (final cell in row)
                      DataCell(_Cell(cell: cell, theme: theme, l10n: l10n)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One order's slack, coloured by its band.
///
/// **The colour is a background rather than the text**, so a red cell is legible
/// at a glance across a matrix of sixty and does not depend on the reader
/// telling three similar text colours apart.
class _Cell extends StatelessWidget {
  const _Cell({required this.cell, required this.theme, required this.l10n});

  final FloatCell? cell;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final value = cell;
    // A month with fewer orders says nothing in this row (§10.4). Blank rather
    // than zero, which would read as an order delivered exactly on its date.
    if (value == null) return const SizedBox.shrink();

    // **The chosen status set, not the generated scheme** (v2.0). These four
    // read `errorContainer`, `tertiaryContainer` and `primaryContainer` until
    // now — which is exactly the coupling `tokens.dart` says was removed: with
    // the seed moved off green to a blueprint blue, `primaryContainer` is
    // *blue*, so the band named `green` was drawing the brand's accent and the
    // matrix no longer said what it meant. `FlowStatus` is picked rather than
    // derived, so re-seeding the chrome cannot move a delivery cell again.
    final status = FlowStatus.of(context);
    final (Color background, Color foreground) = switch (value.band) {
      FloatBand.red => (status.critical.fill, status.critical.ink),
      FloatBand.amber => (status.warning.fill, status.warning.ink),
      FloatBand.green => (status.good.fill, status.good.ink),
      // **Not red.** Late by a month and never finished are different findings,
      // and colouring them alike hides the second inside the first.
      FloatBand.undelivered => (
        status.undelivered.fill,
        status.undelivered.ink,
      ),
    };

    return Tooltip(
      message: value.band == FloatBand.undelivered
          ? '${value.partNumber} · ${l10n.floatMatrixUndelivered}'
          : '${value.partNumber} · ${DateFormat.yMMMd().format(value.needDate)}',
      child: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          value.days == null ? '—' : '${value.days}',
          style: theme.textTheme.bodySmall?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

/// What the four bands mean, in the project's own thresholds (DESIGN.md §10.4).
class _Legend extends StatelessWidget {
  const _Legend({required this.project, required this.tally});

  final Project project;
  final Map<FloatBand, int> tally;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = FlowStatus.of(context);

    final entries = <(StatusColour, String, int)>[
      (
        status.critical,
        l10n.floatLegendRed('${project.floatRedDays}'),
        tally[FloatBand.red] ?? 0,
      ),
      (
        status.warning,
        l10n.floatLegendAmber(
          '${project.floatRedDays}',
          '${project.floatGreenDays}',
        ),
        tally[FloatBand.amber] ?? 0,
      ),
      (
        status.good,
        l10n.floatLegendGreen('${project.floatGreenDays}'),
        tally[FloatBand.green] ?? 0,
      ),
      (
        status.undelivered,
        l10n.floatMatrixUndelivered,
        tally[FloatBand.undelivered] ?? 0,
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (colour, label, count) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The swatch is the fill a cell actually uses, so the legend
              // cannot drift from the matrix beside it.
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colour.fill,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
