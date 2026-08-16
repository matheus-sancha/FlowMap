import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../common/help_icon.dart';
import '../../../common/dialogs.dart';
import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../../data/database/staffing_codec.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../resources/application/resources_providers.dart';
import '../../resources/data/resources_repository.dart';
import '../application/schedules_providers.dart';
import 'date_range_field.dart';

/// Holidays, shutdowns and extra hours (DESIGN.md §4.3).
///
/// "Saturday extra hours on CLAD04" is the commonest capacity lever there is,
/// and until now the only way to express it was to edit a shift pattern that
/// every other workcenter shares.
///
/// Project-scoped, and shown on the Workcenters tab beside the schedules it
/// overrides: the two answer one question — what is this station open for —
/// and separating them would make the answer live in two places.
class CalendarExceptionsView extends ConsumerWidget {
  const CalendarExceptionsView({
    super.key,
    required this.project,
    required this.shiftLabels,
  });

  final Project project;
  final List<String> shiftLabels;


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final exceptions =
        ref.watch(calendarExceptionsProvider(project.id)).value ??
        const <CalendarException>[];

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.exceptions, style: theme.textTheme.titleSmall),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.exceptionNew),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.exceptionsHelp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 12),
        if (exceptions.isEmpty)
          Text(l10n.exceptionsEmpty, style: theme.textTheme.bodyMedium)
        else
          _Groups(
            project: project,
            exceptions: exceptions,
            shiftLabels: shiftLabels,
          ),
      ],
    );

    return Card(child: Padding(padding: const EdgeInsets.all(16), child: body));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<_ExceptionDraft>(
      context: context,
      builder: (context) => _ExceptionDialog(
        project: project,
        shiftLabels: shiftLabels,
      ),
    );
    if (draft == null) return;

    final repository = ref.read(schedulesRepositoryProvider);
    // A pool is expanded to its members here rather than stored as a scope of
    // its own: the schema's scopes are plant, line and workcenter (§4.3), and
    // a pool is a name for a set of workcenters, not a fourth kind of place.
    // Expanding on entry keeps every lookup downstream a map hit.
    for (final scopeId in draft.scopeIds) {
      await repository.addExceptionRange(
        projectId: project.id,
        from: draft.from,
        to: draft.to,
        kind: draft.kind,
        scope: draft.scope,
        scopeId: scopeId,
        operatorsPerShift: draft.kind == CalendarExceptionKind.extraWorking
            ? draft.operatorsPerShift
            : null,
        note: draft.note,
      );
    }
  }
}

/// Consecutive days of one exception, shown as the range the user entered.
///
/// Ranges are stored expanded, one row per day (§16.2), so a fortnight's
/// shutdown is fourteen rows. Listing them one by one would bury the one
/// Saturday that matters.
class _Groups extends ConsumerWidget {
  const _Groups({
    required this.project,
    required this.exceptions,
    required this.shiftLabels,
  });

  final Project project;
  final List<CalendarException> exceptions;
  final List<String> shiftLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = DateFormat.yMd(Localizations.localeOf(context).toString());
    final names = _scopeNames(ref);

    return Column(
      children: [
        for (final group in groupExceptions(exceptions))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              group.kind == CalendarExceptionKind.nonWorking
                  ? Icons.event_busy_outlined
                  : Icons.more_time,
              color: group.kind == CalendarExceptionKind.nonWorking
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            title: Text(
              group.days == 1
                  ? dates.format(group.from)
                  : '${dates.format(group.from)} – ${dates.format(group.to)}',
            ),
            subtitle: Text(
              [
                switch (group.scope) {
                  CalendarExceptionScope.plant => l10n.exceptionScopePlant,
                  CalendarExceptionScope.productionLine =>
                    names[group.scopeId] ?? l10n.productionLine,
                  CalendarExceptionScope.workcenter =>
                    names[group.scopeId] ?? l10n.workcenter,
                },
                if (group.operatorsPerShift != null)
                  formatOperatorsPerShift(group.operatorsPerShift!),
                if (group.note != null && group.note!.isNotEmpty) group.note!,
              ].join(' · '),
            ),
            trailing: IconButton(
              tooltip: l10n.actionDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirmed = await confirmAction(
                  context,
                  title: l10n.exceptionDeleteTitle,
                  message: l10n.confirmDeleteBody,
                  confirmLabel: l10n.actionDelete,
                  destructive: true,
                );
                if (!confirmed) return;
                final repository = ref.read(schedulesRepositoryProvider);
                for (final id in group.ids) {
                  await repository.deleteException(id);
                }
              },
            ),
          ),
      ],
    );
  }

  /// Line and workcenter names, so a scope reads as `CLAD04` rather than as a
  /// uuid.
  Map<String, String> _scopeNames(WidgetRef ref) {
    final names = <String, String>{};
    for (final line in ref.watch(plantLinesProvider(project.plantId)).value ??
        const <PlantLine>[]) {
      names[line.line.id] = line.qualifiedName;
    }
    for (final workcenter
        in ref.watch(workcentersProvider(project.plantId)).value ??
            const <Workcenter>[]) {
      names[workcenter.id] = workcenter.name;
    }
    return names;
  }
}

/// One entry as the user made it: a run of consecutive days sharing a scope,
/// kind, staffing and note.
class ExceptionGroup {
  const ExceptionGroup({
    required this.ids,
    required this.from,
    required this.to,
    required this.kind,
    required this.scope,
    required this.scopeId,
    required this.operatorsPerShift,
    required this.note,
  });

  final List<String> ids;
  final DateTime from;
  final DateTime to;
  final CalendarExceptionKind kind;
  final CalendarExceptionScope scope;
  final String scopeId;
  final List<int>? operatorsPerShift;
  final String? note;

  int get days => to.difference(from).inDays + 1;
}

/// Folds stored days back into the ranges they were entered as.
///
/// Pure, so "does a gap break a range" is a unit test rather than something
/// discovered on a shutdown that spans a weekend.
List<ExceptionGroup> groupExceptions(List<CalendarException> exceptions) {
  final sorted = [...exceptions]
    ..sort((a, b) {
      final scope = a.scope.index.compareTo(b.scope.index);
      if (scope != 0) return scope;
      final id = a.scopeId.compareTo(b.scopeId);
      if (id != 0) return id;
      return a.date.compareTo(b.date);
    });

  final groups = <ExceptionGroup>[];
  var index = 0;
  while (index < sorted.length) {
    final first = sorted[index];
    final ids = <String>[first.id];
    var last = first;

    var next = index + 1;
    while (next < sorted.length) {
      final candidate = sorted[next];
      final consecutive =
          candidate.date.difference(last.date).inDays == 1 &&
          candidate.scope == last.scope &&
          candidate.scopeId == last.scopeId &&
          candidate.kind == last.kind &&
          candidate.operatorsPerShift == last.operatorsPerShift &&
          candidate.note == last.note;
      if (!consecutive) break;
      ids.add(candidate.id);
      last = candidate;
      next++;
    }

    groups.add(
      ExceptionGroup(
        ids: ids,
        from: first.date,
        to: last.date,
        kind: first.kind,
        scope: first.scope,
        scopeId: first.scopeId,
        operatorsPerShift: first.operatorsPerShift == null
            ? null
            : parseOperatorsPerShift(first.operatorsPerShift!),
        note: first.note,
      ),
    );
    index = next;
  }

  groups.sort((a, b) => a.from.compareTo(b.from));
  return groups;
}

class _ExceptionDraft {
  const _ExceptionDraft({
    required this.from,
    required this.to,
    required this.kind,
    required this.scope,
    required this.scopeIds,
    required this.operatorsPerShift,
    required this.note,
  });

  final DateTime from;
  final DateTime to;
  final CalendarExceptionKind kind;
  final CalendarExceptionScope scope;

  /// One entry per place the exception reaches — several when a pool was
  /// chosen, and a single `''` for the plant.
  final List<String> scopeIds;

  final List<int> operatorsPerShift;
  final String? note;
}

class _ExceptionDialog extends ConsumerStatefulWidget {
  const _ExceptionDialog({required this.project, required this.shiftLabels});

  final Project project;
  final List<String> shiftLabels;

  @override
  ConsumerState<_ExceptionDialog> createState() => _ExceptionDialogState();
}

class _ExceptionDialogState extends ConsumerState<_ExceptionDialog> {
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  var _kind = CalendarExceptionKind.nonWorking;
  var _scope = CalendarExceptionScope.plant;
  String? _scopeId;
  late final List<int> _operators = List.filled(
    widget.shiftLabels.length,
    1,
  );
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lines =
        ref.watch(plantLinesProvider(widget.project.plantId)).value ??
        const <PlantLine>[];
    final workcenters =
        ref.watch(workcentersProvider(widget.project.plantId)).value ??
        const <Workcenter>[];
    final pools =
        ref.watch(poolsProvider(widget.project.plantId)).value ??
        const <WorkcenterPool>[];
    final membership =
        ref.watch(poolMembershipProvider(widget.project.plantId)).value ??
        const <String, List<String>>{};

    // Pools are offered in the same picker as workcenters and expanded on
    // save. A pool is a name for a set of stations, not a fourth kind of
    // place, so the schema needs no fourth scope.
    final targets = <({String id, String label})>[
      for (final pool in pools)
        (id: 'pool:${pool.id}', label: '${pool.name} (${l10n.workcenterPool})'),
      for (final workcenter in workcenters)
        (id: workcenter.id, label: workcenter.name),
    ];

    final needsTarget = _scope != CalendarExceptionScope.plant;
    final options = _scope == CalendarExceptionScope.productionLine
        ? [for (final line in lines) (id: line.line.id, label: line.qualifiedName)]
        : targets;
    final valid =
        !_to.isBefore(_from) &&
        (!needsTarget || options.any((o) => o.id == _scopeId)) &&
        (_kind == CalendarExceptionKind.nonWorking ||
            _operators.any((o) => o > 0));

    return AlertDialog(
      title: Text(l10n.exceptionNew),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DateRangeField(
                start: _from,
                end: _to,
                onChanged: (from, to) => setState(() {
                  _from = from;
                  _to = to;
                }),
              ),
              const SizedBox(height: 16),
              SegmentedButton<CalendarExceptionKind>(
                segments: [
                  ButtonSegment(
                    value: CalendarExceptionKind.nonWorking,
                    label: Text(l10n.exceptionKindNonWorking),
                    icon: const Icon(Icons.event_busy_outlined),
                  ),
                  ButtonSegment(
                    value: CalendarExceptionKind.extraWorking,
                    label: Text(l10n.exceptionKindExtraWorking),
                    icon: const Icon(Icons.more_time),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CalendarExceptionScope>(
                initialValue: _scope,
                decoration: InputDecoration(
                  labelText: l10n.exceptionScope,
                  suffixIcon: helpIcon(context, l10n.exceptionScopeHelp),
                ),
                items: [
                  DropdownMenuItem(
                    value: CalendarExceptionScope.plant,
                    child: Text(l10n.exceptionScopePlant),
                  ),
                  DropdownMenuItem(
                    value: CalendarExceptionScope.productionLine,
                    child: Text(l10n.productionLine),
                  ),
                  DropdownMenuItem(
                    value: CalendarExceptionScope.workcenter,
                    child: Text(l10n.workcenter),
                  ),
                ],
                onChanged: (scope) => setState(() {
                  _scope = scope!;
                  _scopeId = null;
                }),
              ),
              if (needsTarget) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _scopeId,
                  decoration: InputDecoration(
                    labelText: _scope == CalendarExceptionScope.productionLine
                        ? l10n.productionLine
                        : l10n.workcenter,
                    errorText: _scopeId == null ? l10n.validationRequired : null,
                  ),
                  items: [
                    for (final option in options)
                      DropdownMenuItem(
                        value: option.id,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (id) => setState(() => _scopeId = id),
                ),
              ],
              if (_kind == CalendarExceptionKind.extraWorking) ...[
                const SizedBox(height: 16),
                Text(l10n.stepOperators, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (var i = 0; i < widget.shiftLabels.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _ShiftOperators(
                          label: widget.shiftLabels[i],
                          value: _operators[i],
                          onChanged: (value) =>
                              setState(() => _operators[i] = value),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.exceptionOperatorsHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                decoration: InputDecoration(labelText: l10n.fieldNote),
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
                  _ExceptionDraft(
                    from: _from,
                    to: _to,
                    kind: _kind,
                    scope: _scope,
                    scopeIds: _resolveScopeIds(membership),
                    operatorsPerShift: _operators,
                    note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                  ),
                )
              : null,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }

  List<String> _resolveScopeIds(Map<String, List<String>> membership) {
    if (_scope == CalendarExceptionScope.plant) return const [''];
    final id = _scopeId!;
    if (!id.startsWith('pool:')) return [id];
    return membership[id.substring(5)] ?? const [];
  }
}

class _ShiftOperators extends StatelessWidget {
  const _ShiftOperators({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove, size: 16),
              onPressed: value == 0 ? null : () => onChanged(value - 1),
            ),
            Text('$value'),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add, size: 16),
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}
