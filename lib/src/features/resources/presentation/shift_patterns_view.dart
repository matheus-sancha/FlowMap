import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/dialogs.dart';
import '../../../common/formatters.dart';
import '../../../common/resource_row_menu.dart';
import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../calendar/application/shift_pattern_spec.dart';
import '../../calendar/application/working_calendar.dart';
import '../application/resources_providers.dart';
import 'shift_pattern_editor.dart';

/// Shift patterns (DESIGN.md §4.1) — plant-independent, because a project picks
/// one for its plant and two plants may well run the same one.
class ShiftPatternsView extends ConsumerWidget {
  const ShiftPatternsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final patterns = ref.watch(shiftPatternsProvider);

    return patterns.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (patterns) => ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          for (final pattern in patterns) _PatternTile(pattern: pattern),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final draft = await showShiftPatternEditor(
                    context,
                    takenNames: patterns
                        .map((p) => p.name.toLowerCase())
                        .toSet(),
                  );
                  if (draft == null) return;
                  final repository = ref.read(resourcesRepositoryProvider);
                  final id = await repository.createShiftPattern(
                    name: draft.name,
                    cycleType: draft.cycleType,
                    workingWeekdays: draft.workingWeekdays,
                    notes: draft.notes,
                  );
                  await repository.setPatternShifts(id, draft.shifts);
                },
                icon: const Icon(Icons.add),
                label: Text(l10n.shiftPatternNew),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternTile extends ConsumerWidget {
  const _PatternTile({required this.pattern});

  final ShiftPattern pattern;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final repository = ref.read(resourcesRepositoryProvider);
    final shifts = ref.watch(patternShiftsProvider(pattern.id)).value;

    final windows = [
      for (final shift in shifts ?? const <PatternShift>[])
        ShiftWindow(
          label: shift.label,
          position: shift.position,
          startMinute: shift.startMinute,
          endMinute: shift.endMinute,
          breakSeconds: shift.breakSeconds,
        ),
    ];

    // Every shift staffed: the ceiling this pattern can offer, and the figure
    // a workcenter's own staffing is read against.
    final openPerDay = windows.isEmpty
        ? Duration.zero
        : WorkingCalendar(
            pattern: ShiftPatternSpec(
              name: pattern.name,
              cycleType: pattern.cycleType,
              workingWeekdays: pattern.workingWeekdays,
              shifts: windows,
            ),
            operatorsPerShift: List.filled(windows.length, 1),
            // Any date: staffing here is constant.
          ).openTimePerWorkingDay(DateTime.now());

    return ExpansionTile(
      leading: const Icon(Icons.schedule_outlined),
      title: ResourceTitle(
        text: pattern.name,
        isArchived: pattern.archivedAt != null,
      ),
      subtitle: Text(
        '${_cycleLabel(l10n, pattern.cycleType)} · '
        '${_weekdaysLabel(l10n, pattern)} · '
        '${l10n.shiftPatternOpenPerDay(formatDurationHms(openPerDay))}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          switch (action) {
            case 'edit':
              final patterns =
                  ref.read(shiftPatternsProvider).value ?? const [];
              final draft = await showShiftPatternEditor(
                context,
                takenNames: patterns
                    .where((p) => p.id != pattern.id)
                    .map((p) => p.name.toLowerCase())
                    .toSet(),
                existing: ShiftPatternDraft(
                  name: pattern.name,
                  cycleType: pattern.cycleType,
                  workingWeekdays: pattern.workingWeekdays,
                  shifts: windows,
                  notes: pattern.notes,
                ),
              );
              if (draft == null) return;
              await repository.updateShiftPattern(
                pattern.id,
                name: draft.name,
                cycleType: draft.cycleType,
                workingWeekdays: draft.workingWeekdays,
                notes: draft.notes,
              );
              await repository.setPatternShifts(pattern.id, draft.shifts);
            case 'archive':
              await repository.setShiftPatternArchived(
                pattern.id,
                pattern.archivedAt == null,
              );
            case 'delete':
              if (!context.mounted) return;
              final confirmed = await confirmAction(
                context,
                title: l10n.confirmDeleteTitle(pattern.name),
                message: l10n.confirmDeleteBody,
                confirmLabel: l10n.actionDelete,
                destructive: true,
              );
              if (confirmed) await repository.deleteShiftPattern(pattern.id);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'edit', child: Text(l10n.actionEdit)),
          PopupMenuItem(
            value: 'archive',
            child: Text(
              pattern.archivedAt == null
                  ? l10n.actionArchive
                  : l10n.actionRestore,
            ),
          ),
          PopupMenuItem(value: 'delete', child: Text(l10n.actionDelete)),
        ],
      ),
      children: [
        if (windows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.shiftPatternNoShifts,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        for (final window in windows)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Row(
              children: [
                SizedBox(width: 96, child: Text(window.label)),
                SizedBox(
                  width: 160,
                  child: Text(
                    '${formatMinuteOfDay(window.startMinute)} – '
                    '${formatMinuteOfDay(window.endMinute)}'
                    '${window.crossesMidnight ? ' (+1)' : ''}',
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Text(
                    l10n.shiftBreakOf(
                      formatDurationHms(Duration(seconds: window.breakSeconds)),
                    ),
                  ),
                ),
                Text(formatDurationHms(window.netDuration)),
              ],
            ),
          ),
        if (pattern.notes != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 4, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(pattern.notes!, style: theme.textTheme.bodySmall),
            ),
          ),
      ],
    );
  }

  static String _cycleLabel(AppLocalizations l10n, ShiftCycleType cycle) =>
      switch (cycle) {
        ShiftCycleType.fixedWeekly => l10n.shiftPatternCycleFixedWeekly,
        ShiftCycleType.rotating => l10n.shiftPatternCycleRotating,
      };

  static String _weekdaysLabel(AppLocalizations l10n, ShiftPattern pattern) {
    if (pattern.cycleType == ShiftCycleType.rotating) {
      return l10n.shiftPatternEveryDay;
    }
    final labels = <String>[];
    const names = [1, 2, 3, 4, 5, 6, 7];
    for (final weekday in names) {
      if (pattern.workingWeekdays & (1 << (weekday - 1)) != 0) {
        labels.add(switch (weekday) {
          DateTime.monday => l10n.weekdayMon,
          DateTime.tuesday => l10n.weekdayTue,
          DateTime.wednesday => l10n.weekdayWed,
          DateTime.thursday => l10n.weekdayThu,
          DateTime.friday => l10n.weekdayFri,
          DateTime.saturday => l10n.weekdaySat,
          _ => l10n.weekdaySun,
        });
      }
    }
    return labels.isEmpty ? l10n.shiftPatternNoWorkingDays : labels.join(' ');
  }
}
