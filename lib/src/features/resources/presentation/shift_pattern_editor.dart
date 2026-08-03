import 'package:flutter/material.dart';

import '../../../common/formatters.dart';
import '../../../data/database/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../calendar/application/shift_pattern_spec.dart';
import '../../calendar/application/working_calendar.dart';

/// What the shift pattern editor produced.
class ShiftPatternDraft {
  const ShiftPatternDraft({
    required this.name,
    required this.cycleType,
    required this.workingWeekdays,
    required this.shifts,
    this.notes,
  });

  final String name;
  final ShiftCycleType cycleType;
  final int workingWeekdays;
  final List<ShiftWindow> shifts;
  final String? notes;
}

Future<ShiftPatternDraft?> showShiftPatternEditor(
  BuildContext context, {
  required Set<String> takenNames,
  ShiftPatternDraft? existing,
}) {
  return showDialog<ShiftPatternDraft>(
    context: context,
    builder: (context) =>
        _ShiftPatternEditorDialog(takenNames: takenNames, existing: existing),
  );
}

class _ShiftPatternEditorDialog extends StatefulWidget {
  const _ShiftPatternEditorDialog({required this.takenNames, this.existing});

  final Set<String> takenNames;
  final ShiftPatternDraft? existing;

  @override
  State<_ShiftPatternEditorDialog> createState() =>
      _ShiftPatternEditorDialogState();
}

class _ShiftPatternEditorDialogState extends State<_ShiftPatternEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late ShiftCycleType _cycle =
      widget.existing?.cycleType ?? ShiftCycleType.fixedWeekly;
  late int _weekdays =
      widget.existing?.workingWeekdays ??
      ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5]);
  late final List<_ShiftDraft> _shifts = [
    for (final shift in widget.existing?.shifts ?? const <ShiftWindow>[])
      _ShiftDraft.from(shift),
  ];

  @override
  void initState() {
    super.initState();
    if (_shifts.isEmpty) _shifts.add(_ShiftDraft.blank('A'));
  }

  @override
  void dispose() {
    _name.dispose();
    for (final shift in _shifts) {
      shift.dispose();
    }
    super.dispose();
  }

  String? get _nameError {
    final value = _name.text.trim();
    if (value.isEmpty) return null;
    return widget.takenNames.contains(value.toLowerCase())
        ? AppLocalizations.of(context).validationNameTaken
        : null;
  }

  /// The shifts that parse. Used for the live preview and for saving, so what
  /// the preview shows is exactly what gets stored.
  List<ShiftWindow> get _validShifts {
    final windows = <ShiftWindow>[];
    for (var i = 0; i < _shifts.length; i++) {
      final window = _shifts[i].toWindow(i);
      if (window != null) windows.add(window);
    }
    return windows;
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      _nameError == null &&
      _validShifts.length == _shifts.length &&
      _shifts.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final windows = _validShifts;

    // The preview runs the real calendar engine with every shift staffed, so
    // the number here is the same one the simulation will use — including the
    // union of overlapping shifts, which is the surprising part.
    final openPerDay = windows.isEmpty
        ? Duration.zero
        : WorkingCalendar(
            pattern: ShiftPatternSpec(
              name: 'preview',
              cycleType: _cycle,
              workingWeekdays: _weekdays,
              shifts: windows,
            ),
            operatorsPerShift: List.filled(windows.length, 1),
            // Any date: staffing here is constant, so the figure does not
            // depend on which day it is asked about.
          ).openTimePerWorkingDay(DateTime.now());

    return AlertDialog(
      title: Text(
        widget.existing == null ? l10n.shiftPatternNew : l10n.shiftPattern,
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.fieldName,
                  errorText: _nameError,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.shiftPatternCycle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              SegmentedButton<ShiftCycleType>(
                segments: [
                  ButtonSegment(
                    value: ShiftCycleType.fixedWeekly,
                    label: Text(l10n.shiftPatternCycleFixedWeekly),
                  ),
                  ButtonSegment(
                    value: ShiftCycleType.rotating,
                    label: Text(l10n.shiftPatternCycleRotating),
                  ),
                ],
                selected: {_cycle},
                onSelectionChanged: (selection) =>
                    setState(() => _cycle = selection.first),
              ),
              const SizedBox(height: 16),
              if (_cycle == ShiftCycleType.fixedWeekly) ...[
                Text(
                  l10n.shiftPatternWorkingDays,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var weekday = 1; weekday <= 7; weekday++)
                      FilterChip(
                        label: Text(_weekdayLabel(l10n, weekday)),
                        selected: _weekdays & (1 << (weekday - 1)) != 0,
                        onSelected: (selected) => setState(() {
                          final bit = 1 << (weekday - 1);
                          _weekdays = selected
                              ? _weekdays | bit
                              : _weekdays & ~bit;
                        }),
                      ),
                  ],
                ),
              ] else
                Text(
                  l10n.shiftPatternRotatingHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.shiftPatternShifts,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    l10n.shiftPatternOpenPerDay(formatDurationHms(openPerDay)),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _shifts.length; i++)
                _ShiftRow(
                  draft: _shifts[i],
                  position: i,
                  onChanged: () => setState(() {}),
                  onRemove: _shifts.length == 1
                      ? null
                      : () => setState(() => _shifts.removeAt(i).dispose()),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(
                  () => _shifts.add(_ShiftDraft.blank(_nextLabel())),
                ),
                icon: const Icon(Icons.add),
                label: Text(l10n.shiftPatternShiftNew),
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
          onPressed: _canSave
              ? () => Navigator.of(context).pop(
                  ShiftPatternDraft(
                    name: _name.text.trim(),
                    cycleType: _cycle,
                    // A rotating pattern runs every day by definition; storing
                    // the full mask keeps the row readable if the cycle type is
                    // later switched back.
                    workingWeekdays: _cycle == ShiftCycleType.rotating
                        ? ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5, 6, 7])
                        : _weekdays,
                    shifts: _validShifts,
                    notes: widget.existing?.notes,
                  ),
                )
              : null,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }

  String _nextLabel() {
    const alphabet = 'ABCDEFGH';
    final used = _shifts.map((s) => s.label.text.trim()).toSet();
    for (final letter in alphabet.split('')) {
      if (!used.contains(letter)) return letter;
    }
    return '${_shifts.length + 1}';
  }

  static String _weekdayLabel(AppLocalizations l10n, int weekday) =>
      switch (weekday) {
        DateTime.monday => l10n.weekdayMon,
        DateTime.tuesday => l10n.weekdayTue,
        DateTime.wednesday => l10n.weekdayWed,
        DateTime.thursday => l10n.weekdayThu,
        DateTime.friday => l10n.weekdayFri,
        DateTime.saturday => l10n.weekdaySat,
        _ => l10n.weekdaySun,
      };
}

/// One editable shift row, holding its own controllers.
class _ShiftDraft {
  _ShiftDraft({
    required this.label,
    required this.start,
    required this.end,
    required this.breakMinutes,
  });

  factory _ShiftDraft.blank(String label) => _ShiftDraft(
    label: TextEditingController(text: label),
    start: TextEditingController(),
    end: TextEditingController(),
    breakMinutes: TextEditingController(text: '0'),
  );

  factory _ShiftDraft.from(ShiftWindow window) => _ShiftDraft(
    label: TextEditingController(text: window.label),
    start: TextEditingController(text: formatMinuteOfDay(window.startMinute)),
    end: TextEditingController(text: formatMinuteOfDay(window.endMinute)),
    breakMinutes: TextEditingController(text: '${window.breakSeconds ~/ 60}'),
  );

  final TextEditingController label;
  final TextEditingController start;
  final TextEditingController end;
  final TextEditingController breakMinutes;

  /// The window this row describes, or null if any field does not parse.
  ShiftWindow? toWindow(int position) {
    final labelText = label.text.trim();
    final startMinute = parseMinuteOfDay(start.text);
    final endMinute = parseMinuteOfDay(end.text);
    final breaks = int.tryParse(breakMinutes.text.trim());
    if (labelText.isEmpty ||
        startMinute == null ||
        endMinute == null ||
        breaks == null ||
        breaks < 0) {
      return null;
    }
    return ShiftWindow(
      label: labelText,
      position: position,
      startMinute: startMinute,
      endMinute: endMinute,
      breakSeconds: breaks * 60,
    );
  }

  void dispose() {
    label.dispose();
    start.dispose();
    end.dispose();
    breakMinutes.dispose();
  }
}

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({
    required this.draft,
    required this.position,
    required this.onChanged,
    this.onRemove,
  });

  final _ShiftDraft draft;
  final int position;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final window = draft.toWindow(position);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: TextField(
              controller: draft.label,
              decoration: InputDecoration(labelText: l10n.shiftLabel),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: TextField(
              controller: draft.start,
              decoration: InputDecoration(
                labelText: l10n.shiftStart,
                hintText: '05:45',
                errorText:
                    draft.start.text.trim().isEmpty ||
                        parseMinuteOfDay(draft.start.text) != null
                    ? null
                    : '',
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: TextField(
              controller: draft.end,
              decoration: InputDecoration(
                labelText: l10n.shiftEnd,
                hintText: '15:13',
                errorText:
                    draft.end.text.trim().isEmpty ||
                        parseMinuteOfDay(draft.end.text) != null
                    ? null
                    : '',
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: TextField(
              controller: draft.breakMinutes,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.shiftBreakMinutes),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 108,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                window == null ? '—' : formatDurationHms(window.netDuration),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.actionDelete,
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }
}
