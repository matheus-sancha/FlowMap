import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/help_icon.dart';

import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../flow/application/flow_providers.dart';
import '../application/studies_providers.dart';

/// The two things about a study that shape a run without being on the map
/// (DESIGN.md §7.2, §7.8).
///
/// A dialog rather than a panel on a tab: neither is read while working, both
/// are set once and then left, and the Flow tab already carries everything that
/// *is* read while working.
Future<void> showStudyRunSettings(
  BuildContext context,
  WidgetRef ref, {
  required Study study,
}) async {
  // Read before the dialog opens rather than watched inside it: `ref.read` of a
  // stream's future can be cancelled by auto-dispose before it emits, and a
  // dialog that never opens is the failure §1.3 already found once.
  final targets = await ref.read(flowTargetsProvider(study.id).future);
  if (!context.mounted) return;

  final draft = await showDialog<_Draft>(
    context: context,
    builder: (context) => _StudyRunSettingsDialog(
      study: study,
      workcenters: targets.workcenters,
      pools: targets.pools,
    ),
  );
  if (draft == null) return;

  await ref
      .read(studiesRepositoryProvider)
      .updateStudy(
        study.id,
        name: study.name,
        supplierName: study.supplierName,
        customerName: study.customerName,
        wipCap: study.wipCap,
        priority: study.priority,
        notes: study.notes,
        startBufferDays: draft.startBufferDays,
        paceSetterTargetId: draft.paceSetterTargetId,
        paceSetterGiven: true,
      );
}

class _Draft {
  const _Draft({required this.startBufferDays, required this.paceSetterTargetId});

  final int startBufferDays;

  /// Null means derive it from work content, which is the default (§7.2).
  final String? paceSetterTargetId;
}

class _StudyRunSettingsDialog extends StatefulWidget {
  const _StudyRunSettingsDialog({
    required this.study,
    required this.workcenters,
    required this.pools,
  });

  final Study study;
  final List<Workcenter> workcenters;
  final List<WorkcenterPool> pools;

  @override
  State<_StudyRunSettingsDialog> createState() =>
      _StudyRunSettingsDialogState();
}

class _StudyRunSettingsDialogState extends State<_StudyRunSettingsDialog> {
  late final TextEditingController _buffer = TextEditingController(
    text: '${widget.study.startBufferDays}',
  );
  late String? _paceSetter = widget.study.paceSetterTargetId;

  @override
  void dispose() {
    _buffer.dispose();
    super.dispose();
  }

  /// Zero is a real answer — no margin — so only a negative or unparseable
  /// value is refused.
  int? get _bufferValue {
    final value = int.tryParse(_buffer.text.trim());
    return value != null && value >= 0 ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.studyRunSettings),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _buffer,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.studyStartBuffer,
                  suffixIcon: helpIcon(context, l10n.studyStartBufferHelp),
                  errorText: _bufferValue == null
                      ? l10n.validationRequired
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _paceSetter,
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
                  // Both kinds of target, because a step may point at either
                  // and the pacemaker is a step (§3.1).
                  for (final workcenter in widget.workcenters)
                    DropdownMenuItem(
                      value: workcenter.id,
                      child: Text(workcenter.name),
                    ),
                  for (final pool in widget.pools)
                    DropdownMenuItem(
                      value: pool.id,
                      child: Text('${pool.name} (${l10n.workcenterPool})'),
                    ),
                ],
                onChanged: (value) => setState(() => _paceSetter = value),
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
          onPressed: _bufferValue == null
              ? null
              : () => Navigator.of(context).pop(
                  _Draft(
                    startBufferDays: _bufferValue!,
                    paceSetterTargetId: _paceSetter,
                  ),
                ),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
