import 'package:flutter/material.dart';
import '../../../common/help_icon.dart';

import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/resources_repository.dart';

/// What the workcenter editor produced.
class WorkcenterDraft {
  const WorkcenterDraft({
    required this.name,
    this.typeId,
    this.parallelCapacity = 1,
    this.lineIds = const {},
  });

  final String name;
  final String? typeId;

  /// How many orders it runs at once (DESIGN.md §3.1). One is a single
  /// machine, which is what every workcenter was before the field existed.
  final int parallelCapacity;

  /// Which lines it is drawn under. A **set**, and possibly empty: a
  /// workcenter belongs to its plant, and filing it in the tree is
  /// organisational (DESIGN.md §3, [WorkcenterLines]).
  final Set<String> lineIds;
}

/// Creates or edits a workcenter.
///
/// Lines are optional checkboxes rather than a required parent: a workcenter
/// belongs to its plant, studies on any line may use it, and one station often
/// serves several lines at once.
Future<WorkcenterDraft?> showWorkcenterEditor(
  BuildContext context, {
  required List<PlantLine> lines,
  required List<WorkcenterType> types,
  required Set<String> takenNames,
  Workcenter? existing,
  Set<String> initialLineIds = const {},
}) {
  return showDialog<WorkcenterDraft>(
    context: context,
    builder: (context) => _WorkcenterEditorDialog(
      lines: lines,
      types: types,
      takenNames: takenNames,
      existing: existing,
      initialLineIds: initialLineIds,
    ),
  );
}

class _WorkcenterEditorDialog extends StatefulWidget {
  const _WorkcenterEditorDialog({
    required this.lines,
    required this.types,
    required this.takenNames,
    this.existing,
    this.initialLineIds = const {},
  });

  final List<PlantLine> lines;
  final List<WorkcenterType> types;
  final Set<String> takenNames;
  final Workcenter? existing;
  final Set<String> initialLineIds;

  @override
  State<_WorkcenterEditorDialog> createState() =>
      _WorkcenterEditorDialogState();
}

class _WorkcenterEditorDialogState extends State<_WorkcenterEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late String? _typeId = widget.existing?.typeId;
  late final Set<String> _lineIds = {...widget.initialLineIds};
  late final TextEditingController _units = TextEditingController(
    text: '${widget.existing?.parallelCapacity ?? 1}',
  );

  @override
  void dispose() {
    _name.dispose();
    _units.dispose();
    super.dispose();
  }

  /// At least one, always: a station that runs no orders is a station that is
  /// closed, and an unstaffed shift already says that (§4.2).
  int? get _unitsValue {
    final value = int.tryParse(_units.text.trim());
    return value != null && value >= 1 ? value : null;
  }

  String? get _nameError {
    final value = _name.text.trim();
    if (value.isEmpty) return null; // Empty disables save; no need to shout.
    return widget.takenNames.contains(value.toLowerCase())
        ? AppLocalizations.of(context).validationNameTaken
        : null;
  }

  void _submit() {
    if (_name.text.trim().isEmpty ||
        _nameError != null ||
        _unitsValue == null) {
      return;
    }
    Navigator.of(context).pop(
      WorkcenterDraft(
        name: _name.text.trim(),
        typeId: _typeId,
        parallelCapacity: _unitsValue!,
        lineIds: _lineIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSave =
        _name.text.trim().isNotEmpty &&
        _nameError == null &&
        _unitsValue != null;

    return AlertDialog(
      title: Text(
        widget.existing == null ? l10n.workcenterNew : l10n.workcenter,
      ),
      content: SizedBox(
        width: 420,
        // Scrolls for the same reason the step and inventory dialogs do: with
        // the units field and its explanation in, this outgrows a short window.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.fieldName,
                  // The name is what the process box is labelled with, so it is
                  // the shop-floor code, not a description.
                  // `helperMaxLines` defaults to 1 however long the string is,
                  // so without this the sentence is clipped mid-word — which is
                  // exactly what was reported from the field.
                  helperMaxLines: 3,
                  errorText: _nameError,
                ),
                onChanged: (_) => setState(() {}),
                // The name is the only thing that has to be typed here, so Enter
                // finishes the job rather than doing nothing.
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _typeId,
                decoration: InputDecoration(labelText: l10n.workcenterType),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.valueNone)),
                  for (final type in widget.types)
                    DropdownMenuItem(value: type.id, child: Text(type.name)),
                ],
                onChanged: (value) => setState(() => _typeId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _units,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.workcenterParallelCapacity,
                  suffixIcon: helpIcon(context, l10n.workcenterParallelCapacityHelp),
                  errorText: _unitsValue == null
                      ? l10n.validationRequired
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                // Beside the name of the thing it explains (§12.7b). It is the
                // same sentence the add-existing dialog shows, from the same
                // key — ticking a line does not restrict who may use a station,
                // which is a wrong conclusion the boxes invite.
                child: namedHelp(
                  context,
                  l10n.workcenterLines,
                  l10n.workcenterLinesHelp,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (widget.lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.workcenterNoLines,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                )
              else
                // Checkboxes, not a dropdown: a station that serves two lines is
                // filed under both, and a single-choice control is what made
                // adding it to a second line silently remove it from the first.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final line in widget.lines)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _lineIds.contains(line.line.id),
                          title: Text(line.qualifiedName),
                          onChanged: (checked) => setState(() {
                            if (checked ?? false) {
                              _lineIds.add(line.line.id);
                            } else {
                              _lineIds.remove(line.line.id);
                            }
                          }),
                        ),
                    ],
                  ),
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
          onPressed: canSave ? _submit : null,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
