import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../resources/application/resources_providers.dart';
import 'exceptions_view.dart';

/// The project's calendar exceptions, on their own (DESIGN.md §4.3, §12.1).
///
/// **Out of the study, because they were never the study's.** An exception is
/// stored per project and applied to a plant, a line or a workcenter — so a
/// shutdown typed inside `Célula 11B` closed the plant for every study in the
/// project, and nothing said so. The field asked the question directly: if they
/// are for the project, why are they inside a study.
///
/// A destination in the studies sidebar, beside the run, which is the place
/// §12.1 already established for what spans studies. §4.3's argument that
/// exceptions belong beside the schedules they override is answered rather than
/// overruled: the two do answer one question — what is a station open for — and
/// that answer is read on Capacity, where the shift pattern and the staffing
/// are. What is set here is the project's own calendar.
class ExceptionsScreen extends ConsumerWidget {
  const ExceptionsScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final shifts = ref
        .watch(patternShiftsProvider(project.shiftPatternId))
        .value;
    if (shifts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.calendarExceptions, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          l10n.exceptionsScope,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 16),
        CalendarExceptionsView(
          project: project,
          shiftLabels: [for (final shift in shifts) shift.label],
        ),
      ],
    );
  }
}
