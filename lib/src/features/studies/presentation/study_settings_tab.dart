import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/help_icon.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../flow/application/flow_providers.dart';
import '../../resources/application/resources_providers.dart';
import '../application/studies_providers.dart';

/// Everything about a study that is not on its map (DESIGN.md §12.1).
///
/// **A tab, where these were a dialog and a sidebar menu.** The `Run settings`
/// dialog held the buffer and the pacemaker; the name, the line and the
/// include-in-a-run flag were on the study's menu; and `wipCap` and `priority`
/// were stored, read by the engine, and reachable from nothing at all — §17.5
/// has listed them since M3, and §3.3b said outright that they belonged in the
/// same place and were waiting for the round that needed them.
///
/// **`priority` was given a field here and then deleted in v28** (#6). Making
/// it reachable is what showed it was not worth reaching: it sat below arrival
/// in the fall-through, so it could not expedite anything, and all 3 studies
/// and all 324 stored run rows sat at the default. The cap stays and is
/// unaffected.
///
/// Gathering them costs one tab and closes two §17.5 entries. It is also where
/// a map-only flag will go when §3.8 is picked up, which is half the reason the
/// tab is worth its place now rather than later.
///
/// **Every field writes on commit, not on a Save button.** There is no draft to
/// lose and no dialog to cancel out of, which is the same bargain the schedule
/// grids made (§12.6): a tab that saves as you leave a field cannot hold a
/// half-typed state that disagrees with what is stored.
class StudySettingsTab extends ConsumerWidget {
  const StudySettingsTab({super.key, required this.project, required this.study});

  final Project project;
  final Study study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final targets = ref.watch(flowTargetsProvider(study.id)).value;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.studySettingsIdentity, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NameField(study: study),
                const SizedBox(height: 16),
                // Where it sits in the plant. Read-only here: a study's line
                // decides which takt schedule it reads (§6.1) and moving one
                // would silently repoint every figure on the map, so it stays a
                // decision made when the study is created.
                _ReadOnly(
                  label: l10n.studyLine,
                  value: _lineName(ref),
                  help: l10n.studyLineHelp,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(l10n.studySettingsInRuns, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: study.includeInSimulation,
                  title: Text(l10n.studyIncludeInRuns),
                  subtitle: Text(l10n.studyIncludeInRunsHelp),
                  onChanged: (value) => _write(ref, includeInSimulation: value),
                ),
                const Divider(height: 24),
                if (targets == null)
                  const Center(child: CircularProgressIndicator())
                else
                  _PaceSetterField(
                    study: study,
                    workcenters: targets.workcenters,
                    pools: targets.pools,
                  ),
                const SizedBox(height: 16),
                _StartBufferField(study: study),
                const SizedBox(height: 16),
                // Reachable for the first time since M3 (§17.5). Both are read
                // by the engine and neither has ever been set by a user, so
                // §7.3's CONWIP behaviour meets the field here.
                _WipCapField(study: study),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _lineName(WidgetRef ref) {
    final lines = ref.watch(plantLinesProvider(project.plantId)).value;
    final line = lines
        ?.where((l) => l.line.id == study.productionLineId)
        .firstOrNull;
    return line == null ? '—' : '${line.cell.name} / ${line.line.name}';
  }

  void _write(
    WidgetRef ref, {
    String? name,
    bool? includeInSimulation,
    int? wipCap,
    bool wipCapGiven = false,
    int? startBufferDays,
    String? paceSetterTargetId,
    bool paceSetterGiven = false,
  }) {
    final repository = ref.read(studiesRepositoryProvider);
    if (includeInSimulation != null) {
      repository.setIncludedInSimulation(study.id, includeInSimulation);
      return;
    }
    repository.updateStudy(
      study.id,
      name: name ?? study.name,
      supplierName: study.supplierName,
      customerName: study.customerName,
      // Null is a real answer for the cap — unlimited — so absence has to be
      // said separately or every other field would clear it.
      wipCap: wipCapGiven ? wipCap : study.wipCap,
      notes: study.notes,
      startBufferDays: startBufferDays ?? study.startBufferDays,
      paceSetterTargetId: paceSetterGiven
          ? paceSetterTargetId
          : study.paceSetterTargetId,
      paceSetterGiven: true,
    );
  }
}

/// A label and a value that cannot be edited here, drawn like the fields around
/// it so the panel reads as one thing.
class _ReadOnly extends StatelessWidget {
  const _ReadOnly({required this.label, required this.value, this.help});

  final String label;
  final String value;
  final String? help;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: helpIcon(context, help),
      enabled: false,
    ),
    child: Text(value),
  );
}

class _NameField extends ConsumerStatefulWidget {
  const _NameField({required this.study});

  final Study study;

  @override
  ConsumerState<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends ConsumerState<_NameField> {
  late final _controller = TextEditingController(text: widget.study.name);
  late final FocusNode _focus = FocusNode()
    ..addListener(() {
      if (!_focus.hasFocus) _commit();
    });

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// An emptied name is refused rather than stored: a study with no name cannot
  /// be told from another in the sidebar, and the field puts back what was
  /// there rather than leaving the two disagreeing.
  void _commit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      _controller.text = widget.study.name;
      return;
    }
    if (name == widget.study.name) return;
    ref.read(studiesRepositoryProvider).updateStudy(
      widget.study.id,
      name: name,
      supplierName: widget.study.supplierName,
      customerName: widget.study.customerName,
      wipCap: widget.study.wipCap,
      notes: widget.study.notes,
      startBufferDays: widget.study.startBufferDays,
      paceSetterTargetId: widget.study.paceSetterTargetId,
      paceSetterGiven: true,
    );
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    decoration: InputDecoration(
      labelText: AppLocalizations.of(context).studyName,
    ),
    onSubmitted: (_) => _commit(),
  );
}

class _PaceSetterField extends ConsumerWidget {
  const _PaceSetterField({
    required this.study,
    required this.workcenters,
    required this.pools,
  });

  final Study study;
  final List<Workcenter> workcenters;
  final List<WorkcenterPool> pools;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<String?>(
      initialValue: study.paceSetterTargetId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.studyPaceSetter,
        suffixIcon: helpIcon(context, l10n.studyPaceSetterHelp),
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(l10n.studyPaceSetterAutomatic),
        ),
        // Both kinds of target, because a step may point at either and the
        // pacemaker is a step (§3.1).
        for (final workcenter in workcenters)
          DropdownMenuItem(value: workcenter.id, child: Text(workcenter.name)),
        for (final pool in pools)
          DropdownMenuItem(
            value: pool.id,
            child: Text('${pool.name} (${l10n.workcenterPool})'),
          ),
      ],
      onChanged: (value) => ref.read(studiesRepositoryProvider).updateStudy(
        study.id,
        name: study.name,
        supplierName: study.supplierName,
        customerName: study.customerName,
        wipCap: study.wipCap,
        notes: study.notes,
        startBufferDays: study.startBufferDays,
        paceSetterTargetId: value,
        paceSetterGiven: true,
      ),
    );
  }
}

/// A whole number written straight to the study when the field is left.
///
/// One widget for the buffer and the cap: they differ only in their label,
/// whether blank is allowed, and where the value lands. It served the priority
/// too until v28 dropped it (#6).
class _NumberField extends ConsumerStatefulWidget {
  const _NumberField({
    required this.study,
    required this.label,
    required this.initial,
    required this.onCommit,
    this.help,
    this.suffix,
    this.blankMeans,
  });

  final Study study;
  final String label;
  final String initial;
  final void Function(WidgetRef ref, int? value) onCommit;
  final String? help;
  final String? suffix;

  /// What an empty field means, shown as the hint. Null makes blank invalid.
  final String? blankMeans;

  @override
  ConsumerState<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends ConsumerState<_NumberField> {
  late final _controller = TextEditingController(text: widget.initial);
  late final FocusNode _focus = FocusNode()
    ..addListener(() {
      if (!_focus.hasFocus) _commit();
    });

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (widget.blankMeans == null) {
        _controller.text = widget.initial;
        return;
      }
      widget.onCommit(ref, null);
      return;
    }
    final value = int.tryParse(text);
    if (value == null || value < 0) {
      _controller.text = widget.initial;
      return;
    }
    widget.onCommit(ref, value);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.blankMeans,
      suffixText: widget.suffix,
      suffixIcon: helpIcon(context, widget.help),
    ),
    onSubmitted: (_) => _commit(),
  );
}

class _StartBufferField extends StatelessWidget {
  const _StartBufferField({required this.study});

  final Study study;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _NumberField(
      study: study,
      label: l10n.studyStartBuffer,
      initial: '${study.startBufferDays}',
      help: l10n.studyStartBufferHelp,
      suffix: l10n.unitDays,
      onCommit: (ref, value) => ref.read(studiesRepositoryProvider).updateStudy(
        study.id,
        name: study.name,
        supplierName: study.supplierName,
        customerName: study.customerName,
        wipCap: study.wipCap,
        notes: study.notes,
        startBufferDays: value ?? 0,
        paceSetterTargetId: study.paceSetterTargetId,
        paceSetterGiven: true,
      ),
    );
  }
}

class _WipCapField extends StatelessWidget {
  const _WipCapField({required this.study});

  final Study study;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _NumberField(
      study: study,
      label: l10n.studyWipCap,
      initial: study.wipCap == null ? '' : '${study.wipCap}',
      help: l10n.studyWipCapHelp,
      // Blank is unlimited, which is what every study has had until now — so an
      // empty field is the answer rather than a missing one (§7.3).
      blankMeans: l10n.studyWipCapUnlimited,
      onCommit: (ref, value) => ref.read(studiesRepositoryProvider).updateStudy(
        study.id,
        name: study.name,
        supplierName: study.supplierName,
        customerName: study.customerName,
        wipCap: value,
        notes: study.notes,
        startBufferDays: study.startBufferDays,
        paceSetterTargetId: study.paceSetterTargetId,
        paceSetterGiven: true,
      ),
    );
  }
}
