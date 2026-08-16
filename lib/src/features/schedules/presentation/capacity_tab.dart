import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'station_cards.dart';
import 'takt_grid.dart';

/// What this line can give, and at what pace (DESIGN.md §12.6, §8.3).
///
/// **`Capacity`, not `Schedules`.** It is what the tab is for and what §8.3's
/// glossary already calls the thing; `Schedules` named the shape of the data
/// rather than the question being asked of it.
///
/// Two tables, and the merge that put three here is undone. §6.3 added the
/// project's calendar exceptions to this tab on §4.3's argument that a station's
/// schedule and the exceptions overriding it answer one question — they do, and
/// the answer is a *station's* open time, which is read here. But an exception
/// is stored per project and applied to a plant, a line or a workcenter, and
/// nothing about one is the study's. It has its own destination now (§12.1),
/// which is the only honest place for it.
///
/// **The takt is still shared and still says so.** It is scoped to the
/// production line, so two studies on one line read and write the same periods
/// — editing it here changes another study's numbers, and a reader is owed that
/// before they type rather than after.
class CapacityTab extends ConsumerWidget {
  const CapacityTab({super.key, required this.project, required this.study});

  final Project project;
  final Study study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A fixed band: a takt schedule is a handful of periods, and the
        // stations below are as long as the plant decides. Giving the long one
        // a capped height inside a page scroll is the shape §8.6 moved the
        // Gantt out of.
        SizedBox(
          height: 240,
          child: _Section(
            title: l10n.studyTabTakt,
            scope: l10n.schedulesTaktScope,
            child: TaktGrid(project: project, study: study),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _Section(
            title: l10n.workcenters,
            scope: l10n.schedulesStationsScope,
            child: StationCards(project: project, study: study),
          ),
        ),
      ],
    );
  }
}

/// A heading, the scope it covers, and the table.
///
/// The scope line is the reason the sections are labelled at all: the takt here
/// is not the study's, and a reader who retunes it without knowing that has
/// changed another study's numbers (§12.6).
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.scope,
    required this.child,
  });

  final String title;
  final String scope;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  scope,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: child,
          ),
        ),
      ],
    );
  }
}
