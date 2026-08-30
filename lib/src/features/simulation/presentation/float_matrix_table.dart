import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

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
        Text(
          l10n.floatMatrixTally(
            '${tally[FloatBand.red]}',
            '${tally[FloatBand.amber]}',
            '${tally[FloatBand.green]}',
            '${tally[FloatBand.undelivered]}',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
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

    final scheme = theme.colorScheme;
    final (Color background, Color foreground) = switch (value.band) {
      FloatBand.red => (scheme.errorContainer, scheme.onErrorContainer),
      FloatBand.amber => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      FloatBand.green => (scheme.primaryContainer, scheme.onPrimaryContainer),
      // **Not red.** Late by a month and never finished are different findings,
      // and colouring them alike hides the second inside the first.
      FloatBand.undelivered => (scheme.surfaceContainerHighest, scheme.outline),
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
