import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/schedule_problems.dart';

/// Shows what is wrong with a schedule, above the table that is wrong.
///
/// Errors appear beside the data that causes them rather than in a distant
/// panel: the fix is always a row on this screen, and a problem reported
/// somewhere else is a problem the user has to go looking for.
class ScheduleIssuesBanner extends StatelessWidget {
  const ScheduleIssuesBanner({super.key, required this.issues});

  final List<SchedulePeriodIssue> issues;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = DateFormat.yMd(Localizations.localeOf(context).toString());

    String describe(SchedulePeriodIssue issue) {
      final from = issue.from == null ? '' : dates.format(issue.from!);
      final to = issue.to == null ? '' : dates.format(issue.to!);
      return switch (issue.problem) {
        SchedulePeriodProblem.empty => l10n.scheduleIssueEmpty,
        SchedulePeriodProblem.overlap => l10n.scheduleIssueOverlap(from, to),
        SchedulePeriodProblem.gap => l10n.scheduleIssueGap(from, to),
        SchedulePeriodProblem.inverted => l10n.scheduleIssueInverted(from, to),
      };
    }

    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      describe(issue),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
