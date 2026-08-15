import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/cell_parsers.dart';
import '../../../common/data_grid.dart';
import '../../../common/date_input.dart';
import '../../../common/date_style_scope.dart';
import '../../../common/dialogs.dart';
import '../../../data/database/database.dart';
import '../../../data/database/staffing_codec.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../resources/application/resources_providers.dart';
import '../../studies/application/studies_providers.dart';
import '../application/schedule_periods.dart';
import '../application/schedule_paste.dart';
import '../application/schedule_problems.dart';
import '../application/schedules_providers.dart';
import '../application/workcenter_schedule.dart';
import 'exceptions_view.dart';
import 'schedule_issues_banner.dart';

/// Staffing, availability and rework for every workcenter this study's flow
/// touches (DESIGN.md §4.2, §4.4).
///
/// Scoped to the flow rather than the whole plant: a project may have fifty
/// workcenters and this study ten, and a schedule the study cannot reach is
/// noise here — it belongs to whichever study does reach it.
class WorkcentersTab extends ConsumerWidget {
  const WorkcentersTab({super.key, required this.project, required this.study});

  final Project project;
  final Study study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final nodes = ref.watch(flowNodesProvider(study.id)).value;
    final workcenters = ref.watch(workcentersProvider(project.plantId)).value;
    final membership = ref.watch(poolMembershipProvider(project.plantId)).value;
    final shifts = ref
        .watch(patternShiftsProvider(project.shiftPatternId))
        .value;

    if (nodes == null ||
        workcenters == null ||
        membership == null ||
        shifts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final used = <String>{};
    for (final node in nodes) {
      if (node.workcenterId != null) used.add(node.workcenterId!);
      if (node.poolId != null) used.addAll(membership[node.poolId] ?? const []);
    }

    final inFlow = workcenters.where((w) => used.contains(w.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (inFlow.isEmpty) {
      return Center(
        child: Text(
          l10n.workcentersTabEmpty,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.workcentersTabPattern(shifts.map((s) => s.label).join(' / ')),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (final workcenter in inFlow)
          _WorkcenterCard(
            project: project,
            workcenter: workcenter,
            shiftLabels: shifts.map((s) => s.label).toList(),
          ),
        const SizedBox(height: 8),
        // Beside the schedules they override: the two answer one question —
        // what is this station open for — and separating them would put the
        // answer in two places (DESIGN.md §4.3).
        CalendarExceptionsView(
          project: project,
          shiftLabels: shifts.map((s) => s.label).toList(),
        ),
      ],
    );
  }
}

class _WorkcenterCard extends ConsumerWidget {
  const _WorkcenterCard({
    required this.project,
    required this.workcenter,
    required this.shiftLabels,
  });

  final Project project;
  final Workcenter workcenter;
  final List<String> shiftLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = (projectId: project.id, workcenterId: workcenter.id);
    final periods = ref.watch(workcenterScheduleProvider(scope)).value;

    if (periods == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final schedule = PeriodSchedule<DatedPeriod>([
      for (final period in periods)
        WorkcenterSchedulePeriodSpec(
          startDate: period.startDate,
          endDate: period.endDate,
          operatorsPerShift: parseOperatorsPerShift(period.operatorsPerShift),
          availability: period.availability,
          rework: period.rework,
        ),
    ]);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.precision_manufacturing_outlined),
            title: Text(workcenter.name),
          ),
          ScheduleIssuesBanner(issues: findSchedulePeriodIssues(schedule)),
          // Bounded, because this card sits in a page carrying one per
          // workcenter and a station's schedule is as long as the plant decides
          // (§12.6). The grid scrolls inside it.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: _ScheduleGrid(
              project: project,
              workcenter: workcenter,
              periods: periods,
              shiftLabels: shiftLabels,
            ),
          ),
        ],
      ),
    );
  }
}

const _startColumn = 0;
const _endColumn = 1;
const _operatorsColumn = 3;
const _availabilityColumn = 4;
const _reworkColumn = 5;

/// One workcenter's dated schedule, typed in place (DESIGN.md §12.6).
///
/// **The dialog this replaces is gone rather than kept beside it**: two write
/// paths into one table is how the two come to disagree. Overlaps and gaps keep
/// being reported by the banner above rather than refused here — that guard
/// already existed and the dialog was duplicating it, and §11's readiness is
/// what actually blocks a run on a real gap.
class _ScheduleGrid extends ConsumerWidget {
  const _ScheduleGrid({
    required this.project,
    required this.workcenter,
    required this.periods,
    required this.shiftLabels,
  });

  final Project project;
  final Workcenter workcenter;
  final List<WorkcenterSchedulePeriod> periods;
  final List<String> shiftLabels;

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
                  title: l10n.schedulePeriodDeleteTitle,
                  message: l10n.confirmDeleteBody,
                  confirmLabel: l10n.actionDelete,
                  destructive: true,
                );
                if (confirmed) {
                  await ref
                      .read(schedulesRepositoryProvider)
                      .deleteWorkcenterSchedulePeriod(periods[row].id);
                }
              },
            ),
      columns: [
        DataGridColumn(title: l10n.fieldStart, width: 130, numeric: true),
        DataGridColumn(title: l10n.fieldEnd, width: 130, numeric: true),
        // Derived by counting, never stored (§4.2) — shown, not typed, which is
        // exactly what `readOnly` is for.
        DataGridColumn(
          title: l10n.scheduleShifts,
          width: 80,
          numeric: true,
          readOnly: true,
        ),
        DataGridColumn(
          title: l10n.scheduleOperatorsPerShift,
          width: 150,
          helper: shiftLabels.join(' / '),
        ),
        DataGridColumn(title: l10n.availability, width: 120, numeric: true),
        DataGridColumn(title: l10n.rework, width: 110, numeric: true),
      ],
      valueAt: (row, column) => _valueAt(dates, row, column),
      errorAt: (row, column, raw) => _errorAt(l10n, dates, row, column, raw),
      onCommit: (row, column, block) => _commit(ref, dates, row, column, block),
    );
  }

  String _valueAt(DateStyle dates, int row, int column) {
    if (row >= periods.length) return '';
    final period = periods[row];
    final operators = parseOperatorsPerShift(period.operatorsPerShift);
    return switch (column) {
      _startColumn => dates.format(period.startDate),
      _endColumn => dates.format(period.endDate),
      _operatorsColumn => formatOperatorsPerShift(operators),
      _availabilityColumn => formatFraction(period.availability),
      _reworkColumn => formatFraction(period.rework),
      // The derived shift count.
      _ => '${staffedShiftCount(operators)}',
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
    // The blank row stays blank until something is typed into it, so an empty
    // cell there is not yet an error.
    if (text.isEmpty) {
      return row >= periods.length ? null : l10n.validationRequired;
    }
    return switch (column) {
      _startColumn || _endColumn => dates.parse(text) == null
          ? l10n.validationNotADate
          : null,
      _availabilityColumn || _reworkColumn => parseFraction(text) == null
          ? l10n.validationNotAPercentage
          : null,
      // `1/1/1`, as it has always been stored. An unreadable entry becomes an
      // unstaffed shift rather than capacity (`staffing_codec.dart`), so the
      // only thing refused here is a cell with nothing in it to read.
      _operatorsColumn => parseOperatorsPerShift(text).isEmpty
          ? l10n.validationRequired
          : null,
      _ => null,
    };
  }

  /// Applies a typed cell or a pasted block.
  ///
  /// What the block *means* is decided by [planSchedulePeriodWrite], which is
  /// pure and unit-tested; this only writes what it read.
  Future<void> _commit(
    WidgetRef ref,
    DateStyle dates,
    int row,
    int column,
    List<List<String>> block,
  ) async {
    final writes = planSchedulePeriodWrite(
      periods: periods,
      row: row,
      column: column,
      block: block,
      dates: dates,
      shiftCount: shiftLabels.length,
    );
    final repository = ref.read(schedulesRepositoryProvider);
    for (final write in writes) {
      if (write.id == null) {
        await repository.createWorkcenterSchedulePeriod(
          projectId: project.id,
          workcenterId: workcenter.id,
          startDate: write.startDate,
          endDate: write.endDate,
          operatorsPerShift: write.operatorsPerShift,
          availability: write.availability,
          rework: write.rework,
        );
      } else {
        await repository.updateWorkcenterSchedulePeriod(
          write.id!,
          startDate: write.startDate,
          endDate: write.endDate,
          operatorsPerShift: write.operatorsPerShift,
          availability: write.availability,
          rework: write.rework,
        );
      }
    }
  }
}
