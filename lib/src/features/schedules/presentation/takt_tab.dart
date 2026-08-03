import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../common/dialogs.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/schedule_periods.dart';
import '../application/schedule_problems.dart';
import '../application/schedules_providers.dart';
import '../application/takt_schedule.dart';
import 'date_range_field.dart';
import 'schedule_issues_banner.dart';

/// The takt schedule of the study's production line (DESIGN.md §6.1).
///
/// Scoped to the line rather than the study: two studies of the same line are
/// scenarios of one reality, and a takt that differed between them would make
/// them incomparable.
class TaktTab extends ConsumerWidget {
  const TaktTab({super.key, required this.project, required this.study});

  final Project project;
  final Study study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
        final issues = findSchedulePeriodIssues(schedule);

        return Column(
          children: [
            ScheduleIssuesBanner(issues: issues),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TaktTable(periods: periods, project: project, study: study),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _editPeriod(context, ref, periods: periods),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.taktPeriodNew),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editPeriod(
    BuildContext context,
    WidgetRef ref, {
    required List<TaktPeriod> periods,
    TaktPeriod? existing,
  }) async {
    final draft = await showDialog<_TaktDraft>(
      context: context,
      builder: (context) => _TaktDialog(
        existing: existing,
        // A new period starts the day after the last one ends, which is what
        // the user means nine times in ten.
        suggestedStart: periods.isEmpty
            ? DateTime(DateTime.now().year, 1, 1)
            : DateTime(
                periods.last.endDate.year,
                periods.last.endDate.month,
                periods.last.endDate.day + 1,
              ),
      ),
    );
    if (draft == null) return;

    final repository = ref.read(schedulesRepositoryProvider);
    if (existing == null) {
      await repository.createTaktPeriod(
        projectId: project.id,
        productionLineId: study.productionLineId,
        startDate: draft.start,
        endDate: draft.end,
        takt: draft.value,
        unit: draft.unit,
      );
    } else {
      await repository.updateTaktPeriod(
        existing.id,
        startDate: draft.start,
        endDate: draft.end,
        takt: draft.value,
        unit: draft.unit,
      );
    }
  }
}

class _TaktTable extends ConsumerWidget {
  const _TaktTable({
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
    final dates = DateFormat.yMd(Localizations.localeOf(context).toString());

    if (periods.isEmpty) {
      return Text(l10n.taktEmpty, style: Theme.of(context).textTheme.bodyLarge);
    }

    return Card(
      child: DataTable(
        columns: [
          DataColumn(label: Text(l10n.fieldStart)),
          DataColumn(label: Text(l10n.fieldEnd)),
          DataColumn(label: Text(l10n.takt)),
          const DataColumn(label: SizedBox.shrink()),
        ],
        rows: [
          for (final period in periods)
            DataRow(
              cells: [
                DataCell(Text(dates.format(period.startDate))),
                DataCell(Text(dates.format(period.endDate))),
                DataCell(
                  Text(
                    '${_formatValue(period.taktValue)} '
                    '${taktUnitLabel(l10n, period.taktUnit)}',
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        tooltip: l10n.actionEdit,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            TaktTab(project: project, study: study)._editPeriod(
                              context,
                              ref,
                              periods: periods,
                              existing: period,
                            ),
                      ),
                      IconButton(
                        tooltip: l10n.actionDelete,
                        icon: const Icon(Icons.delete_outline),
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
                                .deleteTaktPeriod(period.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String _formatValue(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : '$value';

class _TaktDraft {
  const _TaktDraft({
    required this.start,
    required this.end,
    required this.value,
    required this.unit,
  });

  final DateTime start;
  final DateTime end;
  final double value;
  final TaktUnit unit;
}

class _TaktDialog extends StatefulWidget {
  const _TaktDialog({this.existing, required this.suggestedStart});

  final TaktPeriod? existing;
  final DateTime suggestedStart;

  @override
  State<_TaktDialog> createState() => _TaktDialogState();
}

class _TaktDialogState extends State<_TaktDialog> {
  late DateTime _start = widget.existing?.startDate ?? widget.suggestedStart;
  late DateTime _end =
      widget.existing?.endDate ?? DateTime(widget.suggestedStart.year, 12, 31);
  late final TextEditingController _value = TextEditingController(
    text: widget.existing == null
        ? ''
        : _formatValue(widget.existing!.taktValue),
  );
  late TaktUnit _unit = widget.existing?.taktUnit ?? TaktUnit.days;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  double? get _parsed {
    final value = double.tryParse(_value.text.trim().replaceAll(',', '.'));
    return value != null && value > 0 ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final valid = _parsed != null && !_end.isBefore(_start);

    return AlertDialog(
      title: Text(l10n.taktPeriodNew),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DateRangeField(
              start: _start,
              end: _end,
              onChanged: (start, end) => setState(() {
                _start = start;
                _end = end;
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _value,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: l10n.takt),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<TaktUnit>(
                    initialValue: _unit,
                    decoration: InputDecoration(labelText: l10n.taktUnit),
                    items: [
                      for (final unit in TaktUnit.values)
                        DropdownMenuItem(
                          value: unit,
                          child: Text(taktUnitLabel(l10n, unit)),
                        ),
                    ],
                    onChanged: (unit) => setState(() => _unit = unit!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                // Days are workcenter-relative; the others are not. Saying so
                // here saves the question the first time a 3-day takt reads as
                // 68 hours at one station and 26:24 at another.
                _unit == TaktUnit.days
                    ? l10n.taktDaysHelp
                    : l10n.taktLiteralHelp,
                style: Theme.of(context).textTheme.bodySmall,
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
          onPressed: valid
              ? () => Navigator.of(context).pop(
                  _TaktDraft(
                    start: _start,
                    end: _end,
                    value: _parsed!,
                    unit: _unit,
                  ),
                )
              : null,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
