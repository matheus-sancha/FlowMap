import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/help_icon.dart';
import '../../../common/dialogs.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../studies/application/studies_providers.dart';
import '../application/flow_providers.dart';
import '../application/flow_view.dart';

/// Adds a process step to the spine, and the queue in front of it.
///
/// **There is one thing to insert now** (§7.3). This offered a choice of two —
/// a step or an inventory — and an inventory is no longer a node: every step has
/// a queue in front of it, and the type of that queue is chosen here, when the
/// workcenter is. A menu of one is a dialog with an extra click in it, so the
/// step dialog opens directly.
Future<void> showInsertNodeMenu(
  BuildContext context,
  WidgetRef ref, {
  required Study study,
  required int position,
  required Map<String, ProjectQueue> queues,
}) async {
  final targets = await ref.read(flowTargetsProvider(study.id).future);
  if (!context.mounted) return;

  final draft = await showDialog<_StepDraft>(
    context: context,
    builder: (context) => _StepDialog(
      workcenters: targets.workcenters,
      pools: targets.pools,
      queues: queues,
    ),
  );
  if (draft == null) return;

  await ref
      .read(studiesRepositoryProvider)
      .insertStep(
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
  await _saveQueue(ref, projectId: study.projectId, draft: draft);
}

/// Writes the step's queue, and only when the dialog says it changed.
///
/// **A step's dialog is opened to change a label far more often than to change a
/// queue**, and the row it would write is shared by every study whose flow
/// reaches that target (§7.3) — five of them on the real database. Writing on
/// every save would let one study revert another's capacity by renaming a step,
/// without either of them seeing it happen. So `_StepDraft.queue` is null unless
/// a queue field actually differs from what the dialog loaded, and a target
/// nobody has described keeps no row at all.
Future<void> _saveQueue(
  WidgetRef ref, {
  required String projectId,
  required _StepDraft draft,
}) async {
  final queue = draft.queue;
  final targetId = draft.targetId;
  if (queue == null || targetId == null) return;

  await ref
      .read(flowQueuesRepositoryProvider)
      .saveQueue(
        projectId: projectId,
        targetId: targetId,
        name: queue.name,
        rule: queue.rule,
        capacity: queue.capacity,
        stockMode: queue.stockMode,
        stockQuantity: queue.stockQuantity,
        stockSeconds: queue.stockSeconds,
        stockUnit: queue.stockUnit,
      );
}

/// Edits, moves or removes a process step — and the queue in front of it.
///
/// **[queues] is handed in rather than fetched here.** The canvas is already
/// watching them — it cannot draw a channel without them — so the map has the
/// answer before the click, and a dialog that went and asked again would be a
/// second read of something already on screen. It also keeps this function
/// testable without a database, which is what the queue section is worth
/// testing through.
///
/// **The queue is set here, not on the connector** (§7.3, revised). It was on
/// the channel, which is where a queue is *drawn* and where a planner is looking
/// when they think of one; the field's answer was that choosing the type is part
/// of putting a workcenter on the map, so it belongs in the same dialog as the
/// workcenter. Clicking the channel opens this. _Rejected: both._ Two write
/// paths into one shared row is how the two come to disagree (§12.6).
Future<void> showStepEditor(
  BuildContext context,
  WidgetRef ref, {
  required Study study,
  required FlowStepView step,
  required Map<String, ProjectQueue> queues,
}) async {
  final targets = await ref.read(flowTargetsProvider(study.id).future);
  if (!context.mounted) return;

  final result = await showDialog<_StepResult>(
    context: context,
    builder: (context) => _StepDialog(
      workcenters: targets.workcenters,
      pools: targets.pools,
      queues: queues,
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
      await _saveQueue(ref, projectId: study.projectId, draft: draft);
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

// --- Dialog results -------------------------------------------------------

sealed class _StepResult {}

/// Reordering is expressed as a relative move rather than a target index: the
/// gesture on the canvas is "one to the left", and a relative move needs no
/// knowledge of the list's length.
class _MoveNode implements _StepResult {
  const _MoveNode(this.by);

  final int by;
}

class _DeleteNode implements _StepResult {
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
    this.queue,
  });

  /// The queue in front of [targetId], or **null when nothing about it
  /// changed** — which is the usual case, because a step dialog is opened to
  /// change a label far more often than to retune a floor space.
  final _QueueDraft? queue;

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

/// A whole queue row, as the dialog gives it back.
///
/// **Every field, every time.** The dialog is over the whole queue, so a null
/// here means "unset" rather than "leave alone" — which is what keeps one write
/// path into a row two studies read (§12.6).
class _QueueDraft {
  const _QueueDraft({
    this.name,
    this.rule,
    this.capacity,
    this.stockMode,
    this.stockQuantity,
    this.stockSeconds,
    this.stockUnit,
  });

  /// `FIFO CEU27` — what the floor calls this space.
  final String? name;

  /// How the station ahead picks out of it, or null for a push: material piles
  /// up and nobody has decided in what order it comes off (§7.3).
  final DispatchRule? rule;

  /// Orders that fit, or null for unlimited.
  final int? capacity;

  /// What is standing here, as an observation of today (§5.5). Its own figure,
  /// never read as a rule about the future.
  final InventoryMode? stockMode;
  final int? stockQuantity;
  final int? stockSeconds;

  /// The unit a fixed wait was typed in, kept so it reads back the same way.
  final DurationUnit? stockUnit;

  /// **Compared by value**, because that comparison is the rule: the dialog
  /// keeps what it loaded and writes nothing when the two are equal, so a label
  /// edit cannot rewrite a row two studies share (§12.6).
  @override
  bool operator ==(Object other) =>
      other is _QueueDraft &&
      other.name == name &&
      other.rule == rule &&
      other.capacity == capacity &&
      other.stockMode == stockMode &&
      other.stockQuantity == stockQuantity &&
      other.stockSeconds == stockSeconds &&
      other.stockUnit == stockUnit;

  @override
  int get hashCode => Object.hash(
    name,
    rule,
    capacity,
    stockMode,
    stockQuantity,
    stockSeconds,
    stockUnit,
  );
}

// --- Dialogs --------------------------------------------------------------

class _StepDialog extends StatefulWidget {
  const _StepDialog({
    required this.workcenters,
    required this.pools,
    this.queues = const {},
    this.existing,
  });

  final List<Workcenter> workcenters;
  final List<WorkcenterPool> pools;

  /// Every queue the project has, by target (§7.3).
  ///
  /// The whole map's worth rather than this step's, because the target picker
  /// above can be changed while the dialog is open and the queue section has to
  /// follow it — including onto a station another study has already described.
  final Map<String, ProjectQueue> queues;

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

  // --- the queue in front of this step (§7.3) ------------------------------
  //
  // Loaded from whatever the target picker is on, and reloaded whenever it
  // moves, so the heading and the row that Save writes are always the same
  // station. The controllers are rebuilt in place rather than recreated: a
  // `TextEditingController` outlives the value it is showing.
  final TextEditingController _queueName = TextEditingController();
  final TextEditingController _queueCapacity = TextEditingController();
  final TextEditingController _stockQuantity = TextEditingController();
  final TextEditingController _stockWait = TextEditingController();
  _QueueType _queueType = _QueueType.push;
  InventoryMode _stockMode = InventoryMode.quantity;
  DurationUnit _stockUnit = DurationUnit.hours;

  /// What the queue section held when it was last loaded from a target.
  ///
  /// Compared on save so an untouched queue is not written at all — see
  /// `_saveQueue` for why a shared row must not be rewritten by a label edit.
  _QueueDraft? _loadedQueue;

  static String _formatNumber(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  /// Blank means "follow the line's takt", and **so does zero**: a step that
  /// consumes none of the flow's capacity is not a thing to state, so the two
  /// ways of typing nothing agree rather than one of them erroring.
  double? get _equivalentValue => _amountOrNull(_equivalent);

  bool get _equivalentInvalid => _invalid(_equivalent);

  /// **Blank and zero both mean none**, so neither is an error.
  ///
  /// Zero used to be refused, and the field then said `Required` on an optional
  /// field — reported from the field, and the two halves of a changeover are the
  /// place it bites, because clearing a number very often lands on `0` rather
  /// than on an empty box. A setup of zero *is* no setup; it is stored as
  /// nothing, which is what the field already did with a blank.
  double? _amountOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value != null && value > 0 ? value : null;
  }

  /// Only what cannot be read as a duration at all: letters, or a negative.
  bool _invalid(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return false;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value == null || value < 0;
  }

  double? get _setupValue => _amountOrNull(_setup);
  double? get _teardownValue => _amountOrNull(_teardown);

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

  /// The dispatch target the queue is keyed by — the pool where there is one,
  /// never whichever member stands for it on the map (§3.1).
  String? get _targetId => switch (_target) {
    final value? when value.startsWith('wc:') => value.substring(3),
    final value? when value.startsWith('pool:') => value.substring(5),
    _ => null,
  };

  /// `CLAD04` or `CAL Pool` — what the section is headed with, and what the
  /// shared-queue line names. The station's own name rather than the step's
  /// label: the other study's step may call its visit something else, and both
  /// wait in this one line.
  String get _targetName {
    final id = _targetId;
    if (id == null) return '';
    for (final pool in widget.pools) {
      if (pool.id == id) return pool.name;
    }
    for (final workcenter in widget.workcenters) {
      if (workcenter.id == id) return workcenter.name;
    }
    return id;
  }

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  /// Fills the queue section from the target the picker is on.
  ///
  /// **An absent row is a push with nothing in it**, which is what a floor space
  /// nobody has described is (§7.3) — not an error, and not a reason to hide the
  /// section on a step that is bound.
  void _loadQueue() {
    final row = widget.queues[_targetId];
    _queueType = _QueueType.of(row?.rule);
    _queueName.text = row?.name ?? '';
    _queueCapacity.text = row?.capacity?.toString() ?? '';
    _stockMode = row?.stockMode ?? InventoryMode.quantity;
    _stockQuantity.text = '${row?.stockQuantity ?? 0}';
    _stockUnit = row?.stockUnit ?? DurationUnit.hours;
    _stockWait.text = _formatNumber(
      durationIn(Duration(seconds: row?.stockSeconds ?? 0), _stockUnit),
    );
    _loadedQueue = _queueDraft();
  }

  /// The queue section as it stands, ready to be stored or compared.
  _QueueDraft _queueDraft() {
    final name = _queueName.text.trim();
    final isDuration = _stockMode == InventoryMode.duration;
    return _QueueDraft(
      name: name.isEmpty ? null : name,
      rule: _queueType.rule,
      capacity: _queueCapacityValue,
      stockMode: _stockMode,
      stockQuantity: isDuration
          ? null
          : (int.tryParse(_stockQuantity.text.trim()) ?? 0),
      stockSeconds: isDuration
          ? durationFrom(_stockWaitValue ?? 0, _stockUnit).inSeconds
          : null,
      stockUnit: isDuration ? _stockUnit : null,
    );
  }

  /// Blank is unlimited; anything else has to be a positive whole number of
  /// orders. Zero is refused rather than treated as unlimited — a queue that
  /// holds nothing would stop the line for good, and is far more likely to be a
  /// typo than an intention.
  int? get _queueCapacityValue {
    final text = _queueCapacity.text.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    return value != null && value > 0 ? value : null;
  }

  bool get _queueCapacityInvalid =>
      _queueCapacity.text.trim().isNotEmpty && _queueCapacityValue == null;

  double? get _stockWaitValue {
    final value = double.tryParse(_stockWait.text.trim().replaceAll(',', '.'));
    return value != null && value >= 0 ? value : null;
  }

  /// An emptied stock field is **nothing standing there**, not an error.
  ///
  /// It used to disable Save with no message against it at all, which is worse
  /// than a wrong message: the button greys out and the dialog does not say why.
  bool get _stockInvalid {
    if (_targetId == null) return false;
    final text = (_stockMode == InventoryMode.quantity ? _stockQuantity
            : _stockWait)
        .text
        .trim();
    if (text.isEmpty) return false;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value == null || value < 0;
  }

  /// Rewrites the field so the number keeps its meaning when the unit changes:
  /// `48 hours` becomes `2 days`, not `48 days`.
  void _changeStockUnit(DurationUnit unit) {
    final current = _stockWaitValue;
    setState(() {
      if (current != null) {
        _stockWait.text = _formatNumber(
          durationIn(durationFrom(current, _stockUnit), unit),
        );
      }
      _stockUnit = unit;
    });
  }

  @override
  void dispose() {
    _setup.dispose();
    _teardown.dispose();
    _samePart.dispose();
    _equivalent.dispose();
    _label.dispose();
    _notes.dispose();
    _queueName.dispose();
    _queueCapacity.dispose();
    _stockQuantity.dispose();
    _stockWait.dispose();
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
                  suffixIcon: helpIcon(context, l10n.flowStepTargetHelp),
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
                // **The queue section follows this picker.** Repointing a step
                // from CLAD17 to CLAD09 means the fields on screen describe a
                // station the step no longer feeds, so they are reloaded from
                // the new target — including from a row another study has
                // already configured, which is then shown rather than
                // overwritten. What the heading names is what Save writes.
                onChanged: (value) => setState(() {
                  _target = value;
                  _loadQueue();
                }),
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
                    suffixIcon: helpIcon(context, l10n.stepSamePartHelp),
                    errorText: _samePartInvalid ? l10n.validationNumber : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              // --- the queue in front of this step (§7.3) ---
              //
              // Only on a bound step: there is no floor space in front of a step
              // that names no station, and nothing to key a row by.
              if (_targetId != null) ...[
                const SizedBox(height: 16),
                _FieldGroup(label: l10n.flowQueueTitle(_targetName)),
                const SizedBox(height: 4),
                // **Said, not left to be discovered.** One queue per station is
                // the whole correction §7.3 made, and a planner editing this
                // from inside one study has to know the other study's orders
                // stand in the same line.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.flowQueueShared(_targetName),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _QueueTypeField(
                  value: _queueType,
                  onChanged: (type) => setState(() => _queueType = type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _queueName,
                  decoration: InputDecoration(labelText: l10n.flowQueueName),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _queueCapacity,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.laneCapacity,
                    suffixIcon: helpIcon(context, l10n.laneCapacityHelp),
                    // **Zero really is refused here**, and this is the one
                    // field where it is: a queue that holds nothing would stop
                    // the line for good, and is far more likely to be a typo
                    // than an intention (§5.5). Blank is unlimited. So the
                    // message says what is wrong rather than claiming a field
                    // nobody has to fill in is required.
                    errorText: _queueCapacityInvalid
                        ? l10n.validationAboveZero
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                _FieldGroup(label: l10n.flowQueueStock),
                const SizedBox(height: 8),
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
                  selected: {_stockMode},
                  onSelectionChanged: (s) =>
                      setState(() => _stockMode = s.first),
                ),
                const SizedBox(height: 12),
                if (_stockMode == InventoryMode.quantity)
                  TextField(
                    controller: _stockQuantity,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.inventoryPieces,
                      // pieces × takt is the classic "days of stock" reading.
                      suffixIcon: helpIcon(context, l10n.inventoryPiecesHelp),
                    ),
                    onChanged: (_) => setState(() {}),
                  )
                else ...[
                  _ValueAndUnitDuration(
                    controller: _stockWait,
                    unit: _stockUnit,
                    label: l10n.inventoryWait,
                    invalid: _stockInvalid,
                    onChanged: () => setState(() {}),
                    onUnitChanged: _changeStockUnit,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      // A day here is 24 h. The working-time switch the
                      // inventory node carried has not come across:
                      // `project_queues` stores no such flag, and §5.5 leaves a
                      // genuine process delay open rather than inventing the
                      // column inside a re-model.
                      l10n.inventoryWaitHelp,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.flowNodeNotes,
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
                  _samePartInvalid ||
                  _queueCapacityInvalid ||
                  _stockInvalid
              ? null
              : () {
                  final label = _label.text.trim();
                  final notes = _notes.text.trim();
                  final equivalent = _equivalentValue;
                  final queue = _targetId == null ? null : _queueDraft();
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
                      // Null unless a queue field moved. `_saveQueue` writes
                      // nothing then, so a target nobody has described keeps no
                      // row and one study cannot revert another's by saving a
                      // label (§7.3, §12.6).
                      queue: queue == _loadedQueue ? null : queue,
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
              errorText: invalid ? l10n.validationNumber : null,
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
            child: helpIcon(context, help),
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

/// What the queue-type picker offers (§7.3).
///
/// **Its own type rather than a nullable `DispatchRule`**, because two of the
/// six entries are not rules: a push is the absence of one, and a supermarket is
/// a rule the engine cannot honour yet. A dropdown asserts exactly one item
/// matches its value, so two entries sharing `null` throws at mount — which is
/// what the test that opens this dialog found.
enum _QueueType {
  push(null),
  fifo(DispatchRule.fifo),
  lifo(DispatchRule.lifo),
  earliestDueDate(DispatchRule.earliestDueDate),
  shortestProcessing(DispatchRule.shortestProcessing),
  supermarket(null);

  const _QueueType(this.rule);

  /// What is stored, or null for the two that store nothing.
  final DispatchRule? rule;

  /// Null is a push rather than a supermarket: an unset row is a pile nobody
  /// has described, and the one entry that cannot be chosen can never be what
  /// was stored.
  static _QueueType of(DispatchRule? rule) => switch (rule) {
    null => _QueueType.push,
    DispatchRule.fifo => _QueueType.fifo,
    DispatchRule.lifo => _QueueType.lifo,
    DispatchRule.earliestDueDate => _QueueType.earliestDueDate,
    DispatchRule.shortestProcessing => _QueueType.shortestProcessing,
  };
}

/// The queue in front of one dispatch target (§7.3, §5.5).
///
/// Four things, in two groups the schema keeps apart for a reason: the
/// **discipline and the capacity** are rules about the future, and the **stock**
/// is an observation of today. They share a unit and mean opposite things
/// (§16.16), and §5.5's correction was precisely that an observation must not be
/// read as a rule — so a divider separates them here as a column separates them
/// there.
/// The queue-type picker, on the step dialog (§7.3).
///
/// Its own widget because the list has a shape: five things that can be chosen
/// and one that is named and cannot.
class _QueueTypeField extends StatelessWidget {
  const _QueueTypeField({required this.value, required this.onChanged});

  final _QueueType value;
  final ValueChanged<_QueueType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DropdownButtonFormField<_QueueType>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.flowQueueType,
        suffixIcon: helpIcon(context, l10n.flowQueueTypeHelp),
      ),
      items: [
        for (final type in _QueueType.values)
          DropdownMenuItem(
            value: type,
            // **Supermarket is named and not selectable** (§7.3). It is the
            // type the field asked for and the one the engine cannot honour: it
            // decouples — downstream withdraws from stock rather than waiting
            // for a specific order — and it needs stock levels, a replenishment
            // trigger and stockout metrics (§9). A supermarket symbol over FIFO
            // behaviour would be a map that lies about the plant. Listed rather
            // than omitted so a reader looking for it finds out why it is not
            // there.
            enabled: type != _QueueType.supermarket,
            child: Text(
              switch (type) {
                _QueueType.push => l10n.queueTypePush,
                _QueueType.supermarket => l10n.queueTypeSupermarket,
                _ => dispatchRuleLabel(l10n, type.rule!),
              },
              style: type == _QueueType.supermarket
                  ? TextStyle(color: theme.disabledColor)
                  : null,
            ),
          ),
      ],
      onChanged: (type) {
        if (type != null) onChanged(type);
      },
    );
  }
}

/// [_ValueAndUnit] for a plain duration rather than a takt.
///
/// A separate widget rather than a generic one: `days` means this station's
/// productive day in a [TaktUnit] and a flat 24 hours in a [DurationUnit]
/// (§17.3), and a control that took either would be one edit away from
/// offering the wrong meaning of the word.
class _ValueAndUnitDuration extends StatelessWidget {
  const _ValueAndUnitDuration({
    required this.controller,
    required this.unit,
    required this.label,
    required this.invalid,
    required this.onChanged,
    required this.onUnitChanged,
  });

  final TextEditingController controller;
  final DurationUnit unit;
  final String label;
  final bool invalid;
  final VoidCallback onChanged;
  final ValueChanged<DurationUnit> onUnitChanged;

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
              errorText: invalid ? l10n.validationNumber : null,
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<DurationUnit>(
            initialValue: unit,
            decoration: InputDecoration(labelText: l10n.taktUnit),
            items: [
              for (final value in DurationUnit.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(durationUnitLabel(l10n, value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) onUnitChanged(value);
            },
          ),
        ),
      ],
    );
  }
}
