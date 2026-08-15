import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/dialogs.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../studies/application/studies_providers.dart';
import '../application/flow_providers.dart';
import '../application/flow_view.dart';

/// Offers the two things that can go between nodes.
Future<void> showInsertNodeMenu(
  BuildContext context,
  WidgetRef ref, {
  required Study study,
  required int position,
}) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showDialog<FlowNodeKind>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.flowInsertHere),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(FlowNodeKind.step),
          child: ListTile(
            leading: const Icon(Icons.crop_square_outlined),
            title: Text(l10n.flowInsertStep),
            subtitle: Text(l10n.flowInsertStepHelp),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(FlowNodeKind.inventory),
          child: ListTile(
            leading: const Icon(Icons.change_history),
            title: Text(l10n.flowInsertInventory),
            subtitle: Text(l10n.flowInsertInventoryHelp),
          ),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;

  final repository = ref.read(studiesRepositoryProvider);
  if (choice == FlowNodeKind.step) {
    final targets = await ref.read(flowTargetsProvider(study.id).future);
    if (!context.mounted) return;
    final draft = await showDialog<_StepDraft>(
      context: context,
      builder: (context) => _StepDialog(
        workcenters: targets.workcenters,
        pools: targets.pools,
      ),
    );
    if (draft == null) return;
    await repository.insertStep(
      studyId: study.id,
      atPosition: position,
      workcenterId: draft.workcenterId,
      poolId: draft.poolId,
      setupValue: draft.setupValue,
      setupUnit: draft.setupUnit,
      teardownValue: draft.teardownValue,
      teardownUnit: draft.teardownUnit,
      samePartPercent: draft.samePartPercent,
      equivalentValue: draft.equivalentValue,
      equivalentUnit: draft.equivalentUnit,
      label: draft.label,
      notes: draft.notes,
    );
  } else {
    final draft = await showDialog<_InventoryDraft>(
      context: context,
      builder: (context) => const _InventoryDialog(),
    );
    if (draft == null) return;
    await repository.insertInventory(
      studyId: study.id,
      atPosition: position,
      mode: draft.mode,
      quantity: draft.quantity,
      wait: draft.wait,
      waitUnit: draft.waitUnit,
      usesWorkingTime: draft.usesWorkingTime,
      laneRule: draft.laneRule,
      laneCapacity: draft.laneCapacity,
      label: draft.label,
      notes: draft.notes,
    );
  }
}

/// Stores the step's target's queue discipline, if the user changed it (§7.4).
///
/// Edits, moves or removes a process step.
Future<void> showStepEditor(
  BuildContext context,
  WidgetRef ref, {
  required Study study,
  required FlowStepView step,
}) async {
  final targets = await ref.read(flowTargetsProvider(study.id).future);
  if (!context.mounted) return;

  final result = await showDialog<_StepResult>(
    context: context,
    builder: (context) => _StepDialog(
      workcenters: targets.workcenters,
      pools: targets.pools,
      existing: step,
    ),
  );
  if (result == null) return;

  final repository = ref.read(studiesRepositoryProvider);
  switch (result) {
    case _StepDraft draft:
      await repository.updateStep(
        step.node.id,
        workcenterId: draft.workcenterId,
        poolId: draft.poolId,
        setupValue: draft.setupValue,
        setupUnit: draft.setupUnit,
        teardownValue: draft.teardownValue,
        teardownUnit: draft.teardownUnit,
        samePartPercent: draft.samePartPercent,
        equivalentValue: draft.equivalentValue,
        equivalentUnit: draft.equivalentUnit,
        label: draft.label,
        notes: draft.notes,
      );
      case _MoveNode move:
      await repository.moveNode(
        study.id,
        step.position,
        step.position + move.by,
      );
    case _DeleteNode():
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      final confirmed = await confirmAction(
        context,
        title: l10n.flowDeleteNodeTitle,
        message: l10n.confirmDeleteBody,
        confirmLabel: l10n.actionDelete,
        destructive: true,
      );
      if (confirmed) await repository.deleteNode(study.id, step.node.id);
  }
}

Future<void> showInventoryEditor(
  BuildContext context,
  WidgetRef ref, {
  required Study study,
  required FlowInventoryView buffer,
}) async {
  final result = await showDialog<_InventoryResult>(
    context: context,
    builder: (context) => _InventoryDialog(existing: buffer),
  );
  if (result == null) return;

  final repository = ref.read(studiesRepositoryProvider);
  switch (result) {
    case _InventoryDraft draft:
      await repository.updateInventory(
        buffer.node.id,
        mode: draft.mode,
        quantity: draft.quantity,
        wait: draft.wait,
        waitUnit: draft.waitUnit,
        usesWorkingTime: draft.usesWorkingTime,
        laneRule: draft.laneRule,
        laneCapacity: draft.laneCapacity,
        label: draft.label,
        notes: draft.notes,
      );
    case _MoveNode move:
      await repository.moveNode(
        study.id,
        buffer.position,
        buffer.position + move.by,
      );
    case _DeleteNode():
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      final confirmed = await confirmAction(
        context,
        title: l10n.flowDeleteNodeTitle,
        message: l10n.confirmDeleteBody,
        confirmLabel: l10n.actionDelete,
        destructive: true,
      );
      if (confirmed) await repository.deleteNode(study.id, buffer.node.id);
  }
}

// --- Dialog results -------------------------------------------------------

sealed class _StepResult {}

sealed class _InventoryResult {}

/// Reordering is expressed as a relative move rather than a target index: the
/// gesture on the canvas is "one to the left", and a relative move needs no
/// knowledge of the list's length.
class _MoveNode implements _StepResult, _InventoryResult {
  const _MoveNode(this.by);

  final int by;
}

class _DeleteNode implements _StepResult, _InventoryResult {
  const _DeleteNode();
}

class _StepDraft implements _StepResult {
  const _StepDraft({
    this.workcenterId,
    this.poolId,
    this.setupValue,
    this.setupUnit,
    this.teardownValue,
    this.teardownUnit,
    this.samePartPercent,
    this.equivalentValue,
    this.equivalentUnit,
    this.label,
    this.notes,
  });

  final String? workcenterId;
  final String? poolId;

  /// The two halves of a changeover, each a value and a [TaktUnit] (§7.6).
  /// Null is none, which is what every step had before v17.
  final double? setupValue;
  final TaktUnit? setupUnit;
  final double? teardownValue;
  final TaktUnit? teardownUnit;

  /// How much of the pair a repeat of the same part still pays. Null is 0 %.
  final double? samePartPercent;

  /// Null follows the line's takt — the usual case.
  final double? equivalentValue;
  final TaktUnit? equivalentUnit;

  final String? label;


  /// What a current-state walk found here — a problem, an opportunity, a
  /// question to come back to (§5.4). Free text, on the node, affecting no
  /// number.
  final String? notes;

  /// What the step targets — the pool when there is one, exactly as
  /// `demandTargetOf` resolves it, because a queue forms at a pool and not at
  /// whichever member stands for it (§3.1).
  String? get targetId => poolId ?? workcenterId;
}

class _InventoryDraft implements _InventoryResult {
  const _InventoryDraft({
    required this.mode,
    this.quantity,
    this.wait,
    this.waitUnit,
    required this.usesWorkingTime,
    this.laneRule,
    this.laneCapacity,
    this.label,
    this.notes,
  });

  /// What a walk found at this buffer — why the stock is here, what it costs.
  final String? notes;

  /// How the station ahead picks out of this lane, or null to follow the run's
  /// rule (§5.5, §7.4).
  final DispatchRule? laneRule;

  /// Orders that fit, or null for unlimited.
  final int? laneCapacity;

  final InventoryMode mode;
  final int? quantity;
  final Duration? wait;

  /// The unit [wait] was typed in, kept so it reads back the same way.
  final DurationUnit? waitUnit;

  final bool usesWorkingTime;
  final String? label;
}

// --- Dialogs --------------------------------------------------------------

class _StepDialog extends StatefulWidget {
  const _StepDialog({
    required this.workcenters,
    required this.pools,
    this.existing,
  });

  final List<Workcenter> workcenters;
  final List<WorkcenterPool> pools;

  final FlowStepView? existing;

  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  /// `wc:<id>` or `pool:<id>` — one control rather than two, because a step
  /// targets exactly one of them and two dropdowns would let a user pick both.
  late String? _target = _initialTarget();

  late final TextEditingController _setup = TextEditingController(
    text: widget.existing?.node.setupValue == null
        ? ''
        : _formatNumber(widget.existing!.node.setupValue!),
  );
  late TaktUnit _setupUnit =
      widget.existing?.node.setupUnit ?? TaktUnit.minutes;
  late final TextEditingController _teardown = TextEditingController(
    text: widget.existing?.node.teardownValue == null
        ? ''
        : _formatNumber(widget.existing!.node.teardownValue!),
  );
  late TaktUnit _teardownUnit =
      widget.existing?.node.teardownUnit ?? TaktUnit.minutes;
  late final TextEditingController _samePart = TextEditingController(
    text: widget.existing?.node.samePartPercent == null
        ? ''
        : _formatNumber(widget.existing!.node.samePartPercent!),
  );
  late final TextEditingController _equivalent = TextEditingController(
    text: widget.existing?.node.equivalentValue == null
        ? ''
        : _formatNumber(widget.existing!.node.equivalentValue!),
  );
  late TaktUnit _equivalentUnit =
      widget.existing?.node.equivalentUnit ?? TaktUnit.hours;
  late final TextEditingController _label = TextEditingController(
    text: widget.existing?.node.label ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.existing?.node.notes ?? '',
  );

  static String _formatNumber(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  /// Blank means "follow the line's takt", which is why an empty field is
  /// valid rather than an error.
  double? get _equivalentValue {
    final text = _equivalent.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value != null && value > 0 ? value : null;
  }

  bool get _equivalentInvalid =>
      _equivalent.text.trim().isNotEmpty && _equivalentValue == null;

  /// Blank means none, so an empty field is valid rather than an error — the
  /// same rule the Process Specific Takt above already follows.
  double? _positiveOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value != null && value > 0 ? value : null;
  }

  bool _invalid(TextEditingController controller) =>
      controller.text.trim().isNotEmpty && _positiveOrNull(controller) == null;

  double? get _setupValue => _positiveOrNull(_setup);
  double? get _teardownValue => _positiveOrNull(_teardown);

  /// A percentage, so zero is a meaningful answer and the > 0 rule above does
  /// not apply: `0 %` and blank both mean a repeat is free, and a user who
  /// types the zero deliberately should see it stay.
  double? get _samePartValue {
    final text = _samePart.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value != null && value >= 0 && value <= 100 ? value : null;
  }

  bool get _samePartInvalid =>
      _samePart.text.trim().isNotEmpty && _samePartValue == null;

  /// Whether a changeover exists at all, which is what reveals the percentage.
  /// A step with neither half shows five fields, exactly as it did before —
  /// which is what "optional for the user" has to mean on a dialog that already
  /// scrolls at the app's 700 px minimum height.
  bool get _hasChangeover => _setupValue != null || _teardownValue != null;

  String? _initialTarget() {
    final node = widget.existing?.node;
    if (node == null) return null;
    if (node.workcenterId != null) return 'wc:${node.workcenterId}';
    if (node.poolId != null) return 'pool:${node.poolId}';
    return null;
  }

  @override
  void dispose() {
    _setup.dispose();
    _teardown.dispose();
    _samePart.dispose();
    _equivalent.dispose();
    _label.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.existing == null ? l10n.flowInsertStep : l10n.flowStep,
      ),
      // Scrolls because the dialog can outgrow a short window: the app's
      // minimum height is 700, and helper text wraps to three lines.
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String?>(
                initialValue: _target,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.flowStepTarget,
                  helperText: l10n.flowStepTargetHelp,
                  helperMaxLines: 3,
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.valueNone)),
                  for (final workcenter in widget.workcenters)
                    DropdownMenuItem(
                      value: 'wc:${workcenter.id}',
                      child: Text(workcenter.name),
                    ),
                  for (final pool in widget.pools)
                    DropdownMenuItem(
                      value: 'pool:${pool.id}',
                      child: Text('${pool.name} (${l10n.workcenterPool})'),
                    ),
                ],
                onChanged: (value) => setState(() => _target = value),
              ),
              const SizedBox(height: 12),
              // Label second: what this step *is*, then what it is called, then
              // what it costs. The order the field asked for, and the order they
              // are read in.
              TextField(
                controller: _label,
                decoration: InputDecoration(labelText: l10n.flowNodeLabel),
              ),
              const SizedBox(height: 12),
              _ValueAndUnit(
                controller: _equivalent,
                unit: _equivalentUnit,
                label: l10n.stepEquivalentTime,
                hint: l10n.stepEquivalentFollowsTakt,
                // `days` here is this station's productive day, exactly as for
                // takt — so `1 day` equals one takt-day, and the same is true of
                // the two fields below (§6.1.1, §17.4). A definition a wrong
                // answer depends on, so it keeps an affordance rather than being
                // deleted with the rest of the helper text.
                help: l10n.stepEquivalentHelp,
                invalid: _equivalentInvalid,
                onChanged: () => setState(() {}),
                onUnitChanged: (unit) => setState(() => _equivalentUnit = unit),
              ),
              const SizedBox(height: 16),
              _FieldGroup(label: l10n.stepChangeover),
              const SizedBox(height: 8),
              _ValueAndUnit(
                controller: _setup,
                unit: _setupUnit,
                label: l10n.stepSetup,
                invalid: _invalid(_setup),
                onChanged: () => setState(() {}),
                onUnitChanged: (unit) => setState(() => _setupUnit = unit),
              ),
              const SizedBox(height: 12),
              _ValueAndUnit(
                controller: _teardown,
                unit: _teardownUnit,
                label: l10n.stepTeardown,
                help: l10n.stepTeardownHelp,
                invalid: _invalid(_teardown),
                onChanged: () => setState(() {}),
                onUnitChanged: (unit) => setState(() => _teardownUnit = unit),
              ),
              // Revealed rather than always shown: it modifies a changeover, and
              // a step with neither half has nothing for it to modify.
              if (_hasChangeover) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _samePart,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.stepSamePart,
                    suffixText: '%',
                    helperText: l10n.stepSamePartHelp,
                    helperMaxLines: 3,
                    errorText: _samePartInvalid ? l10n.validationRequired : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.flowNodeNotes,
                  helperText: l10n.flowNodeNotesHelp,
                  helperMaxLines: 3,
                  alignLabelWithHint: true,
                ),
              ),
              if (widget.existing != null) ...[
                const Divider(height: 24),
                const _NodeActionsRow(),
              ],
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
          onPressed:
              _equivalentInvalid ||
                  _invalid(_setup) ||
                  _invalid(_teardown) ||
                  _samePartInvalid
              ? null
              : () {
                  final label = _label.text.trim();
                  final notes = _notes.text.trim();
                  final equivalent = _equivalentValue;
                  Navigator.of(context).pop(
                    _StepDraft(
                      workcenterId: _target?.startsWith('wc:') ?? false
                          ? _target!.substring(3)
                          : null,
                      poolId: _target?.startsWith('pool:') ?? false
                          ? _target!.substring(5)
                          : null,
                      setupValue: _setupValue,
                      // The unit is meaningless without a value, and storing one
                      // beside a null would leave a figure nobody typed.
                      setupUnit: _setupValue == null ? null : _setupUnit,
                      teardownValue: _teardownValue,
                      teardownUnit: _teardownValue == null
                          ? null
                          : _teardownUnit,
                      // Discarded with the changeover it modified, so a step
                      // cleared of both halves does not keep a percentage that
                      // now applies to nothing.
                      samePartPercent: _hasChangeover ? _samePartValue : null,
                      equivalentValue: equivalent,
                      // The unit is meaningless without a value, so it is only
                      // stored alongside one.
                      equivalentUnit: equivalent == null
                          ? null
                          : _equivalentUnit,
                      label: label.isEmpty ? null : label,
                      // Emptying the box clears the note rather than storing a
                      // blank one, so "no findings here" and "a finding that
                      // happens to be empty" stay the same thing.
                      notes: notes.isEmpty ? null : notes,
                    ),
                  );
                },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

/// Move and delete, for a node that already exists.
///
/// Lives in the dialog's *content*, not its `actions`. `AlertDialog` lays
/// actions out in an `OverflowBar`, so a `Spacer` there — which is a `Flexible`
/// — throws `_OverflowBarParentData is not a subtype of FlexParentData` on
/// mount and leaves a blank grey dialog. Content is a Column; a Row inside it
/// can space things however it likes.
/// A heading over a run of related fields, with a rule to the right of it.
///
/// Setup and teardown are two halves of one operation and read wrong as two
/// unrelated numbers between a takt and a label.
class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(height: 1, color: theme.colorScheme.outlineVariant)),
      ],
    );
  }
}

/// A number and the [TaktUnit] it is written in, which is how all three of this
/// dialog's durations are stored (§6.1, §7.6).
///
/// **The help is an icon, not a line of text under the field.** Field feedback
/// was that the dialogs explain too much; the rule that came out of it is that
/// help restating a label is deleted and help carrying a *definition* keeps an
/// affordance. `days` is the definition that matters here — it means this
/// station's productive day in all three fields, and §17.4 is the scar that
/// makes saying so non-optional.
class _ValueAndUnit extends StatelessWidget {
  const _ValueAndUnit({
    required this.controller,
    required this.unit,
    required this.label,
    required this.invalid,
    required this.onChanged,
    required this.onUnitChanged,
    this.hint,
    this.help,
  });

  final TextEditingController controller;
  final TaktUnit unit;
  final String label;
  final bool invalid;
  final VoidCallback onChanged;
  final ValueChanged<TaktUnit> onUnitChanged;
  final String? hint;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              errorText: invalid ? l10n.validationRequired : null,
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<TaktUnit>(
            initialValue: unit,
            decoration: InputDecoration(labelText: l10n.taktUnit),
            items: [
              for (final value in TaktUnit.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(taktUnitLabel(l10n, value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) onUnitChanged(value);
            },
          ),
        ),
        if (help != null) ...[
          const SizedBox(width: 4),
          Padding(
            // Aligns with the field rather than with the row, which is taller
            // by the height of an error line that is usually absent.
            padding: const EdgeInsets.only(top: 12),
            child: Tooltip(
              message: help!,
              triggerMode: TooltipTriggerMode.tap,
              child: Icon(
                Icons.info_outline,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NodeActionsRow extends StatelessWidget {
  const _NodeActionsRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: l10n.flowMoveLeft,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(const _MoveNode(-1)),
        ),
        IconButton(
          tooltip: l10n.flowMoveRight,
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => Navigator.of(context).pop(const _MoveNode(1)),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(const _DeleteNode()),
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.actionDelete),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }
}

class _InventoryDialog extends StatefulWidget {
  const _InventoryDialog({this.existing});

  final FlowInventoryView? existing;

  @override
  State<_InventoryDialog> createState() => _InventoryDialogState();
}

class _InventoryDialogState extends State<_InventoryDialog> {
  late InventoryMode _mode =
      widget.existing?.node.inventoryMode ?? InventoryMode.quantity;
  late final TextEditingController _quantity = TextEditingController(
    text: '${widget.existing?.node.inventoryQuantity ?? 0}',
  );

  /// Rows written before the unit was stored read as hours, which is what the
  /// editor offered at the time.
  late DurationUnit _waitUnit =
      widget.existing?.node.inventoryUnit ?? DurationUnit.hours;

  late final TextEditingController _wait = TextEditingController(
    text: _formatNumber(
      durationIn(
        Duration(seconds: widget.existing?.node.inventorySeconds ?? 0),
        _waitUnit,
      ),
    ),
  );
  late bool _workingTime =
      widget.existing?.node.inventoryUsesWorkingTime ?? false;

  /// Null means "follow the run's rule", which is a real choice rather than a
  /// blank: storing the default would pin every queue the first time one was
  /// edited, and would freeze the run's own setting out (§7.4).
  late DispatchRule? _laneRule = widget.existing?.node.laneRule;

  /// Empty means unlimited, which is what every lane was before capacity
  /// existed — so a blank is the state to preserve rather than a zero.
  late final TextEditingController _capacity = TextEditingController(
    text: widget.existing?.node.laneCapacity?.toString() ?? '',
  );
  late final TextEditingController _label = TextEditingController(
    text: widget.existing?.node.label ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.existing?.node.notes ?? '',
  );

  @override
  void dispose() {
    _quantity.dispose();
    _wait.dispose();
    _capacity.dispose();
    _label.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Blank is unlimited; anything else has to be a positive whole number of
  /// orders. Zero is refused rather than treated as unlimited — a lane that
  /// holds nothing would stop the line for good, and is far more likely to be
  /// a typo than an intention.
  int? get _capacityValue {
    final text = _capacity.text.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    return value != null && value > 0 ? value : null;
  }

  bool get _capacityIsValid =>
      _capacity.text.trim().isEmpty || _capacityValue != null;

  double? get _waitValue {
    final value = double.tryParse(_wait.text.trim().replaceAll(',', '.'));
    return value != null && value >= 0 ? value : null;
  }

  /// Rewrites the field so the number keeps its meaning when the unit changes:
  /// `48 hours` becomes `2 days`, not `48 days`.
  void _changeUnit(DurationUnit unit) {
    final current = _waitValue;
    setState(() {
      if (current != null) {
        _wait.text = _formatNumber(
          durationIn(durationFrom(current, _waitUnit), unit),
        );
      }
      _waitUnit = unit;
    });
  }

  static String _formatNumber(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quantity = int.tryParse(_quantity.text.trim());
    final valid =
        (_mode == InventoryMode.quantity
            ? quantity != null && quantity >= 0
            : _waitValue != null) &&
        _capacityIsValid;

    return AlertDialog(
      title: Text(
        widget.existing == null ? l10n.flowInsertInventory : l10n.flowInventory,
      ),
      // Scrolls for the same reason as the step dialog: it can outgrow a short
      // window once the working-time switch and the actions row are in.
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<InventoryMode>(
                segments: [
                  ButtonSegment(
                    value: InventoryMode.quantity,
                    label: Text(l10n.inventoryModeQuantity),
                  ),
                  ButtonSegment(
                    value: InventoryMode.duration,
                    label: Text(l10n.inventoryModeDuration),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 16),
              if (_mode == InventoryMode.quantity)
                TextField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.inventoryPieces,
                    // pieces × takt is the classic "days of stock" reading.
                    helperText: l10n.inventoryPiecesHelp,
                    helperMaxLines: 3,
                  ),
                  onChanged: (_) => setState(() {}),
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _wait,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.inventoryWait,
                          errorText: _waitValue == null
                              ? l10n.validationRequired
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<DurationUnit>(
                        initialValue: _waitUnit,
                        decoration: InputDecoration(labelText: l10n.taktUnit),
                        items: [
                          for (final unit in DurationUnit.values)
                            DropdownMenuItem(
                              value: unit,
                              child: Text(durationUnitLabel(l10n, unit)),
                            ),
                        ],
                        onChanged: (unit) {
                          if (unit != null) _changeUnit(unit);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    // A day here is 24 h; whether those hours are wall clock or
                    // only-while-the-plant-runs is the switch below.
                    l10n.inventoryWaitHelp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _workingTime,
                  title: Text(l10n.inventoryWorkingTime),
                  // A cooling rack does not stop for the weekend; a manual queue
                  // does.
                  subtitle: Text(l10n.inventoryWorkingTimeHelp),
                  onChanged: (value) => setState(() => _workingTime = value),
                ),
              ],

              // --- what the lane governs (§5.5) ---
              //
              // Below the figure and above the label, because the figure is an
              // observation of today and these two are rules about the future.
              // Keeping them apart on screen is the same distinction the schema
              // makes by giving capacity its own column.
              const Divider(height: 24),
              DropdownButtonFormField<DispatchRule?>(
                initialValue: _laneRule,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.laneRule,
                  helperText: l10n.laneRuleHelp,
                  helperMaxLines: 4,
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.laneRuleFollowsRun),
                  ),
                  for (final rule in DispatchRule.values)
                    DropdownMenuItem(
                      value: rule,
                      child: Text(dispatchRuleLabel(l10n, rule)),
                    ),
                ],
                onChanged: (rule) => setState(() => _laneRule = rule),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.laneCapacity,
                  helperText: l10n.laneCapacityHelp,
                  helperMaxLines: 4,
                  errorText: _capacityIsValid ? null : l10n.validationRequired,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                decoration: InputDecoration(labelText: l10n.flowNodeLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.flowNodeNotes,
                  helperText: l10n.flowNodeNotesHelp,
                  helperMaxLines: 3,
                  alignLabelWithHint: true,
                ),
              ),
              if (widget.existing != null) ...[
                const Divider(height: 24),
                const _NodeActionsRow(),
              ],
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
              ? () {
                  final label = _label.text.trim();
                  final notes = _notes.text.trim();
                  final isDuration = _mode == InventoryMode.duration;
                  Navigator.of(context).pop(
                    _InventoryDraft(
                      mode: _mode,
                      quantity: _mode == InventoryMode.quantity
                          ? quantity
                          : null,
                      wait: isDuration
                          ? durationFrom(_waitValue!, _waitUnit)
                          : null,
                      waitUnit: isDuration ? _waitUnit : null,
                      usesWorkingTime: _workingTime,
                      laneRule: _laneRule,
                      laneCapacity: _capacityValue,
                      label: label.isEmpty ? null : label,
                      notes: notes.isEmpty ? null : notes,
                    ),
                  );
                }
              : null,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
