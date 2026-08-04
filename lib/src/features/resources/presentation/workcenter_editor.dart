import 'package:flutter/material.dart';

import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/resources_repository.dart';

/// What the workcenter editor produced.
class WorkcenterDraft {
  const WorkcenterDraft({required this.name, this.typeId, this.homeLineId});

  final String name;
  final String? typeId;
  final String? homeLineId;
}

/// Creates or edits a workcenter.
///
/// The home line is a plain optional field rather than a required parent: a
/// workcenter belongs to its plant, and studies on other lines may use it
/// (DESIGN.md §3, `Workcenters.homeLineId`).
Future<WorkcenterDraft?> showWorkcenterEditor(
  BuildContext context, {
  required List<PlantLine> lines,
  required List<WorkcenterType> types,
  required Set<String> takenNames,
  Workcenter? existing,
  String? initialLineId,
}) {
  return showDialog<WorkcenterDraft>(
    context: context,
    builder: (context) => _WorkcenterEditorDialog(
      lines: lines,
      types: types,
      takenNames: takenNames,
      existing: existing,
      initialLineId: initialLineId,
    ),
  );
}

class _WorkcenterEditorDialog extends StatefulWidget {
  const _WorkcenterEditorDialog({
    required this.lines,
    required this.types,
    required this.takenNames,
    this.existing,
    this.initialLineId,
  });

  final List<PlantLine> lines;
  final List<WorkcenterType> types;
  final Set<String> takenNames;
  final Workcenter? existing;
  final String? initialLineId;

  @override
  State<_WorkcenterEditorDialog> createState() =>
      _WorkcenterEditorDialogState();
}

class _WorkcenterEditorDialogState extends State<_WorkcenterEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late String? _typeId = widget.existing?.typeId;
  late String? _lineId = widget.existing?.homeLineId ?? widget.initialLineId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _nameError {
    final value = _name.text.trim();
    if (value.isEmpty) return null; // Empty disables save; no need to shout.
    return widget.takenNames.contains(value.toLowerCase())
        ? AppLocalizations.of(context).validationNameTaken
        : null;
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _nameError != null) return;
    Navigator.of(context).pop(
      WorkcenterDraft(
        name: _name.text.trim(),
        typeId: _typeId,
        homeLineId: _lineId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSave = _name.text.trim().isNotEmpty && _nameError == null;

    return AlertDialog(
      title: Text(
        widget.existing == null ? l10n.workcenterNew : l10n.workcenter,
      ),
      content: SizedBox(
        width: 420,
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
                helperText: l10n.workcenterNameHelp,
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
            DropdownButtonFormField<String?>(
              initialValue: _lineId,
              decoration: InputDecoration(
                labelText: l10n.workcenterHomeLine,
                helperText: l10n.workcenterHomeLineHelp,
                helperMaxLines: 3,
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.valueNone)),
                for (final line in widget.lines)
                  DropdownMenuItem(
                    value: line.line.id,
                    child: Text(line.qualifiedName),
                  ),
              ],
              onChanged: (value) => setState(() => _lineId = value),
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
          onPressed: canSave ? _submit : null,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
