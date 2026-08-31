import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/tokens.dart';
import '../../../common/period_matrix.dart';
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
        // **The shared chrome** (#10): rows × months, banded cells, a frozen
        // first column. The Occupation grid is its other caller. They share
        // this and not the row semantics — here row *r* means "the order ranked
        // *r* that month", each column independently sorted and ragged, and
        // there the rows are stations that persist across the row. So the
        // widget takes a cell and the row's meaning stays here.
        PeriodMatrix(
          months: matrix.months,
          headerLabel: '#',
          headerWidth: 40,
          rows: [
            for (final (rank, _) in matrix.rows.indexed)
              PeriodMatrixRow(label: '${rank + 1}'),
          ],
          cellAt: (row, month) =>
              _cellOf(matrix.rows[row], month, context, l10n),
        ),
      ],
    );
  }
}

/// One order's slack, as a banded cell of the shared matrix.
///
/// **Was a widget, `_Cell`.** The painting moved into `PeriodMatrix` when the
/// Occupation grid needed the same chrome; what stayed here is the only part
/// that was ever about float — which band a number falls in, and what the
/// tooltip says.
PeriodMatrixCell? _cellOf(
  List<FloatCell?> row,
  int month,
  BuildContext context,
  AppLocalizations l10n,
) {
  if (month >= row.length) return null;
  final value = row[month];
  // A month with fewer orders says nothing in this row (§10.4). Blank rather
  // than zero, which would read as an order delivered exactly on its date.
  if (value == null) return null;

  // **The chosen status set, not the generated scheme** (v2.0). These four read
  // `errorContainer`, `tertiaryContainer` and `primaryContainer` until then —
  // which is exactly the coupling `tokens.dart` says was removed: with the seed
  // moved off green to a blueprint blue, `primaryContainer` is *blue*, so the
  // band named `green` was drawing the brand's accent and the matrix no longer
  // said what it meant. `FlowStatus` is picked rather than derived, so
  // re-seeding the chrome cannot move a delivery cell again.
  final status = FlowStatus.of(context);
  final (Color background, Color foreground) = switch (value.band) {
    FloatBand.red => (status.critical.fill, status.critical.ink),
    FloatBand.amber => (status.warning.fill, status.warning.ink),
    FloatBand.green => (status.good.fill, status.good.ink),
    // **Not red.** Late by a month and never finished are different findings,
    // and colouring them alike hides the second inside the first.
    FloatBand.undelivered => (status.undelivered.fill, status.undelivered.ink),
  };

  return PeriodMatrixCell(
    text: value.days == null ? '—' : '${value.days}',
    background: background,
    foreground: foreground,
    tooltip: value.band == FloatBand.undelivered
        ? '${value.partNumber} · ${l10n.floatMatrixUndelivered}'
        : '${value.partNumber} · ${DateFormat.yMMMd().format(value.needDate)}',
  );
}

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
