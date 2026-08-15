import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/flow_providers.dart';
import '../application/flow_view.dart';
import 'period_label.dart';

/// The period every figure in a study is about (DESIGN.md §12.1).
///
/// **One control, on the tab strip, rather than one per tab.** The Flow tab and
/// the Summary each carried their own copy of this — the same four widgets over
/// the same `viewedPeriodProvider`, so the state could not disagree, but the
/// reader met a stepper that moved position when they switched tabs and had to
/// find it twice. The period is a property of the study workspace rather than
/// of either tab, and it now sits where that is true.
///
/// **The granularity is on the label, not beside it.** It is set once and read
/// often, so a permanently visible dropdown was a control the size of a choice
/// nobody makes twice. Tapping the period opens it.
class PeriodControl extends ConsumerWidget {
  const PeriodControl({super.key, required this.studyId, this.enabled = true});

  final String studyId;

  /// Whether the period governs what is on screen.
  ///
  /// **Greyed rather than hidden** where it does not — Study Settings and
  /// Schedules are about the study whatever month it is. A control that
  /// vanishes makes the strip jump as the reader moves along it, and leaves
  /// them wondering where it went; one that dims says "not this tab" and stays
  /// where it was.
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final period = ref.watch(viewedPeriodProvider(studyId));
    final notifier = ref.read(viewedPeriodProvider(studyId).notifier);

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.periodPrevious,
            icon: const Icon(Icons.chevron_left),
            onPressed: enabled ? notifier.previous : null,
          ),
          MenuAnchor(
            menuChildren: [
              for (final granularity in PeriodGranularity.values)
                MenuItemButton(
                  onPressed: () => notifier.setGranularity(granularity),
                  leadingIcon: Icon(
                    granularity == period.granularity
                        ? Icons.check
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: granularity == period.granularity
                        ? null
                        : Colors.transparent,
                  ),
                  child: Text(granularityLabel(l10n, granularity)),
                ),
            ],
            builder: (context, controller, _) => TextButton(
              onPressed: enabled
                  ? () => controller.isOpen
                        ? controller.close()
                        : controller.open()
                  : null,
              child: SizedBox(
                // Fixed, so stepping through the months does not shuffle
                // everything beside it as the label's width changes.
                width: 104,
                child: Text(
                  periodLabel(context, period.anchor, period.granularity),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.periodNext,
            icon: const Icon(Icons.chevron_right),
            onPressed: enabled ? notifier.next : null,
          ),
        ],
      ),
    );
  }
}
