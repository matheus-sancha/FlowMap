import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../common/help_icon.dart';
import '../../../common/dialogs.dart';
import '../../../common/result_table.dart';
import '../../../data/database/database.dart';
import '../../../data/database/staffing_codec.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../resources/application/resources_providers.dart';
import '../../studies/application/studies_providers.dart';
import '../application/schedule_periods.dart';
import '../application/schedule_problems.dart';
import '../application/schedules_providers.dart';
import '../application/workcenter_schedule.dart';
import 'date_range_field.dart';
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
    final l10n = AppLocalizations.of(context);
    final dates = DateFormat.yMd(Localizations.localeOf(context).toString());
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
    final issues = findSchedulePeriodIssues(schedule);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.precision_manufacturing_outlined),
            title: Text(workcenter.name),
            trailing: TextButton.icon(
              onPressed: () => _editPeriod(context, ref, periods: periods),
              icon: const Icon(Icons.add),
              label: Text(l10n.schedulePeriodNew),
            ),
          ),
          ScheduleIssuesBanner(issues: issues),
          if (periods.isNotEmpty)
            resultTable(
              columns: [
                ResultColumn(label: l10n.fieldStart, width: 120),
                ResultColumn(label: l10n.fieldEnd, width: 120),
                ResultColumn(label: l10n.scheduleShifts, width: 100),
                ResultColumn(label: l10n.scheduleOperatorsPerShift, width: 150),
                ResultColumn(label: l10n.availability, width: 130),
                ResultColumn(label: l10n.rework, width: 110),
                // Actions stay start-aligned beside the row they act on.
                const ResultColumn(label: '', width: 112, centred: false),
              ],
              rowCount: periods.length,
              cellAt: (index, column) =>
                  _cell(context, ref, periods[index], dates, periods, column),
            ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    WidgetRef ref,
    WorkcenterSchedulePeriod period,
    DateFormat dates,
    List<WorkcenterSchedulePeriod> periods,
    int column,
  ) {
    final l10n = AppLocalizations.of(context);
    final operators = parseOperatorsPerShift(period.operatorsPerShift);
    return switch (column) {
      0 => Text(dates.format(period.startDate)),
      1 => Text(dates.format(period.endDate)),
      // Derived by counting, never stored (DESIGN.md §4.2).
      2 => Text('${staffedShiftCount(operators)}'),
      3 => Text(formatOperatorsPerShift(operators)),
      4 => Text(_percent(period.availability)),
      5 => Text(_percent(period.rework)),
      _ => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.actionEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                _editPeriod(context, ref, periods: periods, existing: period),
          ),
          IconButton(
            tooltip: l10n.actionDelete,
            icon: const Icon(Icons.delete_outline),
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
                    .deleteWorkcenterSchedulePeriod(period.id);
              }
            },
          ),
        ],
      ),
    };
  }

  Future<void> _editPeriod(
    BuildContext context,
    WidgetRef ref, {
    required List<WorkcenterSchedulePeriod> periods,
    WorkcenterSchedulePeriod? existing,
  }) async {
    final draft = await showDialog<_ScheduleDraft>(
      context: context,
      builder: (context) => _SchedulePeriodDialog(
        shiftLabels: shiftLabels,
        existing: existing,
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
      await repository.createWorkcenterSchedulePeriod(
        projectId: project.id,
        workcenterId: workcenter.id,
        startDate: draft.start,
        endDate: draft.end,
        operatorsPerShift: draft.operators,
        availability: draft.availability,
        rework: draft.rework,
      );
    } else {
      await repository.updateWorkcenterSchedulePeriod(
        existing.id,
        startDate: draft.start,
        endDate: draft.end,
        operatorsPerShift: draft.operators,
        availability: draft.availability,
        rework: draft.rework,
      );
    }
  }
}

String _percent(double fraction) =>
    '${(fraction * 100).toStringAsFixed(fraction * 100 % 1 == 0 ? 0 : 1)}%';

class _ScheduleDraft {
  const _ScheduleDraft({
    required this.start,
    required this.end,
    required this.operators,
    required this.availability,
    required this.rework,
  });

  final DateTime start;
  final DateTime end;
  final List<int> operators;
  final double availability;
  final double rework;
}

class _SchedulePeriodDialog extends StatefulWidget {
  const _SchedulePeriodDialog({
    required this.shiftLabels,
    required this.suggestedStart,
    this.existing,
  });

  final List<String> shiftLabels;
  final DateTime suggestedStart;
  final WorkcenterSchedulePeriod? existing;

  @override
  State<_SchedulePeriodDialog> createState() => _SchedulePeriodDialogState();
}

class _SchedulePeriodDialogState extends State<_SchedulePeriodDialog> {
  late DateTime _start = widget.existing?.startDate ?? widget.suggestedStart;
  late DateTime _end =
      widget.existing?.endDate ?? DateTime(widget.suggestedStart.year, 12, 31);
  late final List<int> _operators = _initialOperators();
  late final TextEditingController _availability = TextEditingController(
    text: ((widget.existing?.availability ?? 1) * 100).toStringAsFixed(1),
  );
  late final TextEditingController _rework = TextEditingController(
    text: ((widget.existing?.rework ?? 0) * 100).toStringAsFixed(1),
  );

  List<int> _initialOperators() {
    final stored = parseOperatorsPerShift(widget.existing?.operatorsPerShift);
    return [
      for (var i = 0; i < widget.shiftLabels.length; i++)
        i < stored.length ? stored[i] : (widget.existing == null ? 1 : 0),
    ];
  }

  @override
  void dispose() {
    _availability.dispose();
    _rework.dispose();
    super.dispose();
  }

  double? _fraction(TextEditingController controller, {required double max}) {
    final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    if (value == null || value < 0 || value > max) return null;
    return value / 100;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Availability of zero means the workcenter can never run: effective
    // process time would divide by it (DESIGN.md §4.4), so it is refused here
    // rather than producing an infinity downstream.
    final availability = _fraction(_availability, max: 100);
    final rework = _fraction(_rework, max: 1000);
    final valid =
        availability != null &&
        availability > 0 &&
        rework != null &&
        !_end.isBefore(_start);

    return AlertDialog(
      title: Text(l10n.schedulePeriodNew),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(
                l10n.scheduleOperatorsPerShift,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < widget.shiftLabels.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 96,
                        child: _OperatorStepper(
                          label: widget.shiftLabels[i],
                          value: _operators[i],
                          onChanged: (value) =>
                              setState(() => _operators[i] = value),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.scheduleShiftsDerived(
                  '${staffedShiftCount(_operators)}',
                  formatOperatorsPerShift(_operators),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _availability,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.availability,
                        suffixText: '%',
                        suffixIcon: helpIcon(context, l10n.availabilityHelp),
                        errorText: availability == null || availability <= 0
                            ? l10n.availabilityInvalid
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _rework,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.rework,
                        suffixText: '%',
                        suffixIcon: helpIcon(context, l10n.reworkHelp),
                        errorText: rework == null ? l10n.reworkInvalid : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                  _ScheduleDraft(
                    start: _start,
                    end: _end,
                    operators: _operators,
                    availability: availability,
                    rework: rework,
                  ),
                )
              : null,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

/// Operators on one shift. Zero closes the shift, which is how a workcenter
/// runs two shifts under a three-shift pattern (DESIGN.md §4.2).
class _OperatorStepper extends StatelessWidget {
  const _OperatorStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: value == 0 ? null : () => onChanged(value - 1),
            child: const Icon(Icons.remove, size: 16),
          ),
          Text('$value'),
          InkWell(
            onTap: () => onChanged(value + 1),
            child: const Icon(Icons.add, size: 16),
          ),
        ],
      ),
    );
  }
}
