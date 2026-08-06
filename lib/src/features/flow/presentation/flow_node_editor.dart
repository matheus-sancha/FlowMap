import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/dialogs.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../simulation/application/simulation_providers.dart';
import '../../studies/application/studies_providers.dart';
import '../application/flow_providers.dart';
import '../application/flow_view.dart';

/// Offers the two things that can go between nodes.
Future<void> showInsertNodeMenu(
  BuildContext context,
  WidgetRef ref, {
  required Study study,
  required int position,
  required Map<String, DispatchRule> dispatchByTarget,
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
        dispatchByTarget: dispatchByTarget,
      ),
    );
    if (draft == null) return;
    await repository.insertStep(
      studyId: study.id,
      atPosition: position,
      workcenterId: draft.workcenterId,
      poolId: draft.poolId,
      changeover: draft.changeover,
      equivalentValue: draft.equivalentValue,
      equivalentUnit: draft.equivalentUnit,
      label: draft.label,
    );
    await _writeDispatch(ref, study, draft, dispatchByTarget);
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
      label: draft.label,
    );
  }
}

/// Stores the step's target's queue discipline, if the user changed it (§7.4).
///
/// **Only on a change.** The rule belongs to the station and not to this step,
/// so saving a step for an unrelated reason must not rewrite it — and must not
/// delete a rule another step set, which is what an unconditional write of a
/// null would do.
Future<void> _writeDispatch(
  WidgetRef ref,
  Study study,
  _StepDraft draft,
  Map<String, DispatchRule> before,
) async {
  final targetId = draft.targetId;
  if (targetId == null) return;
  if (before[targetId] == draft.dispatch) return;

  await ref
      .read(simulationRepositoryProvider)
      .setDispatchRule(
        projectId: study.projectId,
        targetId: targetId,
        rule: draft.dispatch,
      );
}

/// Edits, moves or removes a process step.
Future<void> showStepEditor(
  BuildContext context,
  WidgetRef ref, {
  required Study study,
  required FlowStepView step,
  required Map<String, DispatchRule> dispatchByTarget,
}) async {
  final targets = await ref.read(flowTargetsProvider(study.id).future);
  if (!context.mounted) return;

  final result = await showDialog<_StepResult>(
    context: context,
    builder: (context) => _StepDialog(
      workcenters: targets.workcenters,
      pools: targets.pools,
      dispatchByTarget: dispatchByTarget,
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
        changeover: draft.changeover,
        equivalentValue: draft.equivalentValue,
        equivalentUnit: draft.equivalentUnit,
        label: draft.label,
        notes: step.node.notes,
      );
      await _writeDispatch(ref, study, draft, dispatchByTarget);
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
        label: draft.label,
        notes: buffer.node.notes,
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
    required this.changeover,
    this.equivalentValue,
    this.equivalentUnit,
    this.label,
    this.dispatch,
  });

  final String? workcenterId;
  final String? poolId;
  final Duration changeover;

  /// Null follows the line's takt — the usual case.
  final double? equivalentValue;
  final TaktUnit? equivalentUnit;

  final String? label;

  /// This step's target's queue discipline, or null to follow the run's
  /// (§7.4). Not a property of the step: it is written against [targetId],
  /// which is the station, and every step pointing at that station gets it.
  final DispatchRule? dispatch;

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
    this.label,
  });

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
    required this.dispatchByTarget,
    this.existing,
  });

  final List<Workcenter> workcenters;
  final List<WorkcenterPool> pools;

  /// The project's stored queue disciplines, by target (§7.4). Only the
  /// overrides are in here — an absent key means the station follows the run's
  /// rule, which is why the control's null option is a real choice.
  final Map<String, DispatchRule> dispatchByTarget;

  final FlowStepView? existing;

  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  /// `wc:<id>` or `pool:<id>` — one control rather than two, because a step
  /// targets exactly one of them and two dropdowns would let a user pick both.
  late String? _target = _initialTarget();

  /// The selected target's queue discipline, null meaning "follow the run's".
  ///
  /// Re-read whenever the target changes, so pointing the step at another
  /// station shows *that* station's rule rather than carrying the previous
  /// one across — the setting belongs to the station, not to the step.
  late DispatchRule? _dispatch = widget.dispatchByTarget[_targetId];
  late final TextEditingController _changeover = TextEditingController(
    text: '${(widget.existing?.changeover ?? Duration.zero).inMinutes}',
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

  String? _initialTarget() {
    final node = widget.existing?.node;
    if (node == null) return null;
    if (node.workcenterId != null) return 'wc:${node.workcenterId}';
    if (node.poolId != null) return 'pool:${node.poolId}';
    return null;
  }

  /// The bare id behind `_target`'s `wc:` / `pool:` prefix.
  String? get _targetId {
    final target = _target;
    if (target == null) return null;
    if (target.startsWith('wc:')) return target.substring(3);
    if (target.startsWith('pool:')) return target.substring(5);
    return null;
  }

  @override
  void dispose() {
    _changeover.dispose();
    _equivalent.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minutes = int.tryParse(_changeover.text.trim());

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
                onChanged: (value) => setState(() {
                  _target = value;
                  _dispatch = widget.dispatchByTarget[_targetId];
                }),
              ),
              // Only with a target to hang it on: an unbound step has no queue,
              // and a control that cannot be written anywhere is worse than an
              // absent one.
              if (_targetId != null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<DispatchRule?>(
                  initialValue: _dispatch,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.stepDispatch,
                    // Says out loud that this is the station's setting and not
                    // the step's — the one thing about it that can surprise.
                    helperText: l10n.stepDispatchHelp,
                    helperMaxLines: 3,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.stepDispatchFollowsRun),
                    ),
                    for (final rule in DispatchRule.values)
                      DropdownMenuItem(
                        value: rule,
                        child: Text(dispatchRuleLabel(l10n, rule)),
                      ),
                  ],
                  onChanged: (rule) => setState(() => _dispatch = rule),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _changeover,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.stepChangeover,
                  suffixText: l10n.unitMinutesShort,
                  helperText: l10n.stepChangeoverHelp,
                  helperMaxLines: 3,
                  errorText: minutes == null || minutes < 0
                      ? l10n.validationRequired
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _equivalent,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.stepEquivalentTime,
                        hintText: l10n.stepEquivalentFollowsTakt,
                        errorText: _equivalentInvalid
                            ? l10n.validationRequired
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<TaktUnit>(
                      initialValue: _equivalentUnit,
                      decoration: InputDecoration(labelText: l10n.taktUnit),
                      items: [
                        for (final unit in TaktUnit.values)
                          DropdownMenuItem(
                            value: unit,
                            child: Text(taktUnitLabel(l10n, unit)),
                          ),
                      ],
                      onChanged: (unit) {
                        if (unit != null) {
                          setState(() => _equivalentUnit = unit);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  // Days here are this station's productive days, exactly as
                  // for takt — so `1 day` equals one takt-day.
                  l10n.stepEquivalentHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                decoration: InputDecoration(
                  labelText: l10n.flowNodeLabel,
                  helperText: l10n.flowNodeLabelHelp,
                  helperMaxLines: 2,
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
          onPressed: minutes == null || minutes < 0 || _equivalentInvalid
              ? null
              : () {
                  final label = _label.text.trim();
                  final equivalent = _equivalentValue;
                  Navigator.of(context).pop(
                    _StepDraft(
                      workcenterId: _target?.startsWith('wc:') ?? false
                          ? _target!.substring(3)
                          : null,
                      poolId: _target?.startsWith('pool:') ?? false
                          ? _target!.substring(5)
                          : null,
                      changeover: Duration(minutes: minutes),
                      equivalentValue: equivalent,
                      // The unit is meaningless without a value, so it is only
                      // stored alongside one.
                      equivalentUnit: equivalent == null
                          ? null
                          : _equivalentUnit,
                      label: label.isEmpty ? null : label,
                      dispatch: _dispatch,
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
  late final TextEditingController _label = TextEditingController(
    text: widget.existing?.node.label ?? '',
  );

  @override
  void dispose() {
    _quantity.dispose();
    _wait.dispose();
    _label.dispose();
    super.dispose();
  }

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
    final valid = _mode == InventoryMode.quantity
        ? quantity != null && quantity >= 0
        : _waitValue != null;

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
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                decoration: InputDecoration(labelText: l10n.flowNodeLabel),
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
                      label: label.isEmpty ? null : label,
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
