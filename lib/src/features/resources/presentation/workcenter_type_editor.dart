import 'package:flutter/material.dart';

import '../../../common/help_icon.dart';
import '../../../common/workcenter_icons.dart';
import '../../../data/database/enums.dart';
import '../../../data/database/seed_data.dart';
import '../../../l10n/generated/app_localizations.dart';

/// What the workcenter type editor produced.
class WorkcenterTypeDraft {
  const WorkcenterTypeDraft({
    required this.name,
    this.icon,
    this.labourPaced = false,
  });

  final String name;

  /// Whether the crew is this type's throughput (§7.5, v30).
  final bool labourPaced;

  /// Null draws the default machine glyph — a type without an icon is a
  /// perfectly ordinary type, not an unfinished one.
  final WorkcenterIcon? icon;
}

/// Names a workcenter type and picks its icon (DESIGN.md §12.1).
///
/// The icon is chosen from a fixed library rather than typed: the glyphs have
/// to survive tree-shaking, so they are enum members the compiler can see, and
/// a free-text field would only invite names that resolve to nothing.
Future<WorkcenterTypeDraft?> showWorkcenterTypeEditor(
  BuildContext context, {
  required Set<String> takenNames,
  String initialName = '',
  WorkcenterIcon? initialIcon,
  bool initialLabourPaced = false,
}) {
  return showDialog<WorkcenterTypeDraft>(
    context: context,
    builder: (context) => _WorkcenterTypeDialog(
      takenNames: takenNames,
      initialName: initialName,
      initialIcon: initialIcon,
      initialLabourPaced: initialLabourPaced,
    ),
  );
}

class _WorkcenterTypeDialog extends StatefulWidget {
  const _WorkcenterTypeDialog({
    required this.takenNames,
    required this.initialName,
    this.initialIcon,
    this.initialLabourPaced = false,
  });

  final Set<String> takenNames;
  final String initialName;
  final WorkcenterIcon? initialIcon;
  final bool initialLabourPaced;

  @override
  State<_WorkcenterTypeDialog> createState() => _WorkcenterTypeDialogState();
}

class _WorkcenterTypeDialogState extends State<_WorkcenterTypeDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late WorkcenterIcon? _icon = widget.initialIcon;
  late bool _labourPaced = widget.initialLabourPaced;

  /// Whether the user has chosen a glyph by hand. Until they do, typing a name
  /// keeps re-guessing — so "Welding" lands on the welding icon without a
  /// second gesture, and a deliberate choice is never overwritten.
  bool _iconChosen = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? _error(String value) => widget.takenNames.contains(value.toLowerCase())
      ? AppLocalizations.of(context).validationNameTaken
      : null;

  void _submit(String value) {
    if (value.isEmpty || _error(value) != null) return;
    Navigator.of(context).pop(
      WorkcenterTypeDraft(
        name: value,
        icon: _icon,
        labourPaced: _labourPaced,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ValueListenableBuilder(
      valueListenable: _name,
      builder: (context, editing, _) {
        final value = editing.text.trim();
        final error = value.isEmpty ? null : _error(value);

        return AlertDialog(
          title: Text(l10n.workcenterTypeEdit),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.fieldName,
                    errorText: error,
                  ),
                  onChanged: (typed) {
                    if (_iconChosen) return;
                    final guess = guessWorkcenterIcon(typed.trim());
                    if (guess != _icon) setState(() => _icon = guess);
                  },
                  onSubmitted: (_) => _submit(value),
                ),
                const SizedBox(height: 8),
                // **The one thing here that changes a number.** §12.7b: a
                // definition a wrong conclusion depends on, and the field drew
                // exactly that conclusion — crewing a station up and expecting
                // it to go faster, on a model that said every station was
                // machine-paced.
                // **A named choice between two, not a switch.** A switch says
                // *on or off* and leaves the reader to guess what off is; the
                // two pacings are peers, and the one nobody picks is a real
                // answer about the machine rather than the absence of one.
                DropdownButtonFormField<bool>(
                  initialValue: _labourPaced,
                  decoration: InputDecoration(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(l10n.workcenterCapacityType)),
                        ?helpIcon(context, l10n.workcenterTypeLabourPacedHelp),
                      ],
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: false,
                      child: Text(l10n.workcenterCapacityMachine),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text(l10n.workcenterCapacityOperator),
                    ),
                  ],
                  onChanged: (picked) =>
                      setState(() => _labourPaced = picked ?? false),
                ),
                const SizedBox(height: 16),
                // *Deleted, not moved* (§12.7b): "workcenters of this type are
                // drawn with it" restates what picking an icon visibly does.
                Text(l10n.workcenterTypeIcon, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _IconChoice(
                          label: l10n.workcenterTypeNone,
                          glyph: fallbackWorkcenterIcon,
                          selected: _icon == null,
                          onTap: () => setState(() {
                            _icon = null;
                            _iconChosen = true;
                          }),
                        ),
                        for (final option in WorkcenterIcon.values)
                          _IconChoice(
                            label: workcenterIconLabel(l10n, option),
                            glyph: workcenterIconGlyph(option),
                            selected: _icon == option,
                            onTap: () => setState(() {
                              _icon = option;
                              _iconChosen = true;
                            }),
                          ),
                      ],
                    ),
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
              onPressed: value.isEmpty || error != null
                  ? null
                  : () => _submit(value),
              child: Text(l10n.actionSave),
            ),
          ],
        );
      },
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.label,
    required this.glyph,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData glyph;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            color: selected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
          ),
          child: Icon(
            glyph,
            size: 22,
            color: selected ? theme.colorScheme.onPrimaryContainer : null,
          ),
        ),
      ),
    );
  }
}
