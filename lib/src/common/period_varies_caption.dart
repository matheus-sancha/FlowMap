import 'package:flutter/material.dart';

import '../features/schedules/application/takt_schedule.dart';
import '../l10n/generated/app_localizations.dart';
import 'date_style_scope.dart';
import 'unit_labels.dart';

/// The caption saying the map is showing one state of several (DESIGN.md §7.7.3).
///
/// **Visible text where there was a bare icon.** The old ⓘ over
/// `periodVariesHelp` was on screen the whole evening a takt change went unread —
/// with no affordance nobody hovers (§2.5), so the one caveat that decides which
/// takt every figure below belongs to was invisible. A takt change now reads in
/// words: which takt, when it moves, and what it becomes.
///
/// **The same widget on Flow and Summary**, because they share the viewed period
/// (§6.4) and so share the trap. Both read the change off the assembled map, so
/// the two surfaces cannot disagree about whether the span crosses one.
///
/// Falls back to the icon for a staffing-only change: [scheduleVaries] is the
/// broader "takt or staffing moved", and staffing is fifty stations with no one
/// sentence to name it.
class PeriodVariesCaption extends StatelessWidget {
  const PeriodVariesCaption({
    super.key,
    required this.taktChange,
    required this.scheduleVaries,
  });

  /// The takt change inside the viewed span, or null when the takt holds.
  final TaktChange? taktChange;

  /// Whether the takt *or* the staffing moves inside the span — the flag that
  /// earned the icon before the caption existed.
  final bool scheduleVaries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final change = taktChange;

    if (change != null) {
      // `from` is the takt on the span's first day, which is exactly the one the
      // map is drawn at (§7.7.3), so `shown` is the same figure — the string
      // keeps them apart so a translation can word "showing" naturally.
      final from = taktLabel(l10n, change.from.value, change.from.unit);
      final text = l10n.flowTaktChanges(
        from,
        taktLabel(l10n, change.to.value, change.to.unit),
        DateStyleScope.of(context).format(change.at),
        from,
      );
      // The full sentence is also in the tooltip, so a narrow toolbar that
      // ellipsises the visible copy still gives the reader the whole of it.
      return Tooltip(
        message: text,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (scheduleVaries) {
      return Tooltip(
        message: l10n.periodVariesHelp,
        child: Icon(
          Icons.info_outline,
          size: 18,
          color: theme.colorScheme.tertiary,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
