import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// Asks before something irreversible. Resources edits are not undoable — they
/// are infrequent and deliberate, so they get a confirm instead of a command
/// stack (DESIGN.md §12.3).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A single-field name prompt — the shape of most resource edits.
///
/// [validate] returns an error message or null, and runs on every change, so
/// "that name is already used here" appears as the user types rather than on
/// save.
Future<String?> promptForName(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
  String? Function(String value)? validate,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NamePromptDialog(
      title: title,
      label: label,
      initialValue: initialValue,
      validate: validate,
    ),
  );
}

class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    this.validate,
  });

  final String title;
  final String label;
  final String initialValue;
  final String? Function(String value)? validate;

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    if (value.isEmpty || widget.validate?.call(value) != null) return;
    Navigator.of(context).pop(value);
  }

  /// Built inside a [ValueListenableBuilder] on the controller, so everything
  /// derived from the typed name — the error, and whether Save is enabled —
  /// rebuilds because the text changed, not because someone remembered to call
  /// `setState`.
  ///
  /// That is the bug this shape exists to prevent, and it was a real one: the
  /// error was cached in a field and `setState` was called only when the error
  /// itself changed. Typing a perfectly good name into an empty field changed
  /// no error, so nothing rebuilt, and Save stayed greyed out — leaving Enter
  /// as the only way to create a plant, a cell, a line, a pool or a workcenter
  /// type.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (context, editing, _) {
        final value = editing.text.trim();
        // An empty field disables Save; there is no need to shout at someone
        // who has not typed anything yet.
        final error = value.isEmpty ? null : widget.validate?.call(value);

        return AlertDialog(
          title: Text(widget.title),
          content: TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.label,
              errorText: error,
            ),
            onSubmitted: (_) => _submit(value),
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
