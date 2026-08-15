import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/cell_parsers.dart';
import '../../../common/data_grid.dart';
import '../../../common/date_input.dart';
import '../../../common/date_style_scope.dart';
import '../../../common/dialogs.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/schedule_periods.dart';
import '../application/schedule_paste.dart';
import '../application/schedule_problems.dart';
import '../application/schedules_providers.dart';
import '../application/takt_schedule.dart';
import 'schedule_issues_banner.dart';

const _startColumn = 0;
const _endColumn = 1;
const _taktColumn = 2;

/// The takt schedule of the study's production line (DESIGN.md §6.1).
///
/// Scoped to the line rather than the study: two studies of the same line are
/// scenarios of one reality, and a takt that differed between them would make
/// them incomparable.
///
/// **Typed in the table, not behind a dialog** (§12.6). Field feedback was that
/// re-tuning a takt cost a round trip through an editor; `DataGrid` already had
/// what that needs — keyboard navigation, per-keystroke validation and a
/// multi-cell paste out of Excel, which is how a year of periods actually
/// arrives. The dialog is gone rather than kept beside it: two write paths into
/// one table is how the two come to disagree.
class TaktTab extends ConsumerWidget {
  const TaktTab({super.key, required this.project, required this.study});

  final Project project;
  final Study study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = (
      projectId: project.id,
      productionLineId: study.productionLineId,
    );
    final periods = ref.watch(taktPeriodsProvider(scope));

    return periods.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (periods) {
        final schedule = PeriodSchedule<DatedPeriod>([
          for (final period in periods)
            TaktPeriodSpec(
              startDate: period.startDate,
              endDate: period.endDate,
              value: period.taktValue,
              unit: period.taktUnit,
            ),
        ]);

        return Column(
          children: [
            // Overlaps and gaps are reported, never refused. The banner was
            // already here and the dialog was duplicating the guard; §11's
            // readiness is what actually blocks a run on a real gap.
            ScheduleIssuesBanner(issues: findSchedulePeriodIssues(schedule)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _TaktGrid(
                  periods: periods,
                  project: project,
                  study: study,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TaktGrid extends ConsumerWidget {
  const _TaktGrid({
    required this.periods,
    required this.project,
    required this.study,
  });

  final List<TaktPeriod> periods;
  final Project project;
  final Study study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dates = DateStyleScope.of(context);

    return DataGrid(
      // One row past the end, always blank: a period is added by typing into
      // it, the way the sequence grid appends an order (§9.1).
      rowCount: periods.length + 1,
      rowHeaderWidth: 44,
      rowActionsWidth: 48,
      rowHeader: (row) => Center(
        child: Text(
          row < periods.length ? '${row + 1}' : '+',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
      rowActions: (row) => row >= periods.length
          ? const SizedBox.shrink()
          : IconButton(
              tooltip: l10n.actionDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () async {
                final confirmed = await confirmAction(
                  context,
                  title: l10n.taktPeriodDeleteTitle,
                  message: l10n.confirmDeleteBody,
                  confirmLabel: l10n.actionDelete,
                  destructive: true,
                );
                if (confirmed) {
                  await ref
                      .read(schedulesRepositoryProvider)
                      .deleteTaktPeriod(periods[row].id);
                }
              },
            ),
      columns: [
        DataGridColumn(title: l10n.fieldStart, width: 140, numeric: true),
        DataGridColumn(title: l10n.fieldEnd, width: 140, numeric: true),
        DataGridColumn(title: l10n.takt, width: 100, numeric: true),
        DataGridColumn(title: l10n.taktUnit, width: 120),
      ],
      valueAt: (row, column) => _valueAt(l10n, dates, row, column),
      errorAt: (row, column, raw) => _errorAt(l10n, dates, row, column, raw),
      onCommit: (row, column, block) =>
          _commit(ref, dates, row, column, block),
    );
  }

  String _valueAt(
    AppLocalizations l10n,
    DateStyle dates,
    int row,
    int column,
  ) {
    if (row >= periods.length) return '';
    final period = periods[row];
    return switch (column) {
      _startColumn => dates.format(period.startDate),
      _endColumn => dates.format(period.endDate),
      _taktColumn => formatNumber(period.taktValue),
      // Canonical out: whatever spelling was typed, the column reads back in
      // the user's own language (§9.2).
      _ => taktUnitLabel(l10n, period.taktUnit),
    };
  }

  String? _errorAt(
    AppLocalizations l10n,
    DateStyle dates,
    int row,
    int column,
    String raw,
  ) {
    final text = raw.trim();
    // The blank row is blank until something is typed into it, so an empty cell
    // there is not yet an error.
    if (text.isEmpty) return row >= periods.length ? null : l10n.validationRequired;

    return switch (column) {
      _startColumn || _endColumn =>
        dates.parse(text) == null ? l10n.validationNotADate : null,
      _taktColumn => parsePositive(text) == null ? l10n.validationPositiveNumber : null,
      _ => parseTaktUnit(text) == null ? l10n.validationUnknownUnit : null,
    };
  }

  /// Applies a typed cell or a pasted block.
  ///
  /// What the block *means* is decided by [planTaktWrite], which is pure and
  /// unit-tested; this only writes what it read (§9.1's split).
  Future<void> _commit(
    WidgetRef ref,
    DateStyle dates,
    int row,
    int column,
    List<List<String>> block,
  ) async {
    final writes = planTaktWrite(
      periods: periods,
      row: row,
      column: column,
      block: block,
      dates: dates,
    );
    final repository = ref.read(schedulesRepositoryProvider);
    for (final write in writes) {
      if (write.id == null) {
        await repository.createTaktPeriod(
          projectId: project.id,
          productionLineId: study.productionLineId,
          startDate: write.startDate,
          endDate: write.endDate,
          takt: write.takt,
          unit: write.unit,
        );
      } else {
        await repository.updateTaktPeriod(
          write.id!,
          startDate: write.startDate,
          endDate: write.endDate,
          takt: write.takt,
          unit: write.unit,
        );
      }
    }
  }
}
