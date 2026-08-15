import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/cell_parsers.dart';
import '../../../common/data_grid.dart';
import '../../../common/date_input.dart';
import '../../../common/date_style_scope.dart';
import '../../../common/dialogs.dart';
import '../../../data/database/database.dart';
import '../../../data/database/staffing_codec.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../resources/application/resources_providers.dart';
import '../../studies/application/studies_providers.dart';
import '../application/schedule_periods.dart';
import '../application/schedule_paste.dart';
import '../application/schedule_problems.dart';
import '../application/schedules_providers.dart';
import '../application/station_grid.dart';
import '../application/workcenter_schedule.dart';
import 'exceptions_view.dart';
import 'schedule_issues_banner.dart';
import 'takt_grid.dart';

/// What this line is open for, and at what pace (DESIGN.md §12.6).
///
/// **Two tabs merged.** `Flow Takt` and `Workcenters` answered one question
/// between them and neither said so; worse, both were editing things that are
/// not the study's — a takt belongs to the production line and is shared by
/// every study on it, and a workcenter schedule belongs to the project. The
/// merge does not fix that, but it puts the two shared tables together under
/// headings that can say whose they are.
///
/// **The small pair on top, the big grid below.** Takt is a handful of periods
/// and Exceptions a handful of dates; the stations are as long as the plant
/// decides. Stacking all three in one scroll would give the long one a capped
/// height inside a page scroll, which is the shape §8.6 moved the Gantt out of.
/// So the two small tables share a fixed band and the station grid takes the
/// rest of the height with its own scroll — one scroll region on the page.
class SchedulesTab extends ConsumerWidget {
  const SchedulesTab({super.key, required this.project, required this.study});

  final Project project;
  final Study study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shifts = ref
        .watch(patternShiftsProvider(project.shiftPatternId))
        .value;
    if (shifts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final shiftLabels = [for (final shift in shifts) shift.label];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Side by side, and both headed with whose they are: a reader editing
        // a takt here is editing every study on this line, and §12.6's rule is
        // that a surface says what it owns rather than letting the reader find
        // out afterwards.
        SizedBox(
          height: 260,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Section(
                  title: l10n.studyTabTakt,
                  scope: l10n.schedulesTaktScope,
                  child: TaktGrid(project: project, study: study),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _Section(
                  title: l10n.calendarExceptions,
                  scope: l10n.schedulesExceptionsScope,
                  child: CalendarExceptionsView(
                    project: project,
                    shiftLabels: shiftLabels,
                    dense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _Section(
            title: l10n.workcenters,
            scope: l10n.schedulesStationsScope,
            child: _StationGrid(
              project: project,
              study: study,
              shiftLabels: shiftLabels,
            ),
          ),
        ),
      ],
    );
  }
}

/// A heading, the scope it covers, and the table.
///
/// The scope line is the whole reason the sections are labelled at all: two of
/// the three tables here are not the study's, and a reader who edits one
/// without knowing that has changed another study's numbers (§12.6).
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Every station of this study's flow, in one grid (DESIGN.md §12.6).
///
/// **One grid rather than a card each.** Célula 11B's seven stations were seven
/// cards, each with its own issues banner and its own 320 px-capped scroller —
/// seven nested scroll regions to compare one column across. One grid compares
/// staffing by reading down it, and takes a year of periods for the whole line
/// as a single paste out of Excel.
///
/// Scoped to the flow rather than to the plant: a project may have fifty
/// workcenters and this study ten, and a schedule the study cannot reach is
/// noise here — it belongs to whichever study does reach it (§4.2).
class _StationGrid extends ConsumerWidget {
  const _StationGrid({
    required this.project,
    required this.study,
    required this.shiftLabels,
  });

  final Project project;
  final Study study;
  final List<String> shiftLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final nodes = ref.watch(flowNodesProvider(study.id)).value;
    final workcenters = ref.watch(workcentersProvider(project.plantId)).value;
    final membership = ref.watch(poolMembershipProvider(project.plantId)).value;

    if (nodes == null || workcenters == null || membership == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final used = <String>{};
    for (final node in nodes) {
      if (node.workcenterId != null) used.add(node.workcenterId!);
      if (node.poolId != null) used.addAll(membership[node.poolId] ?? const []);
    }
    final inFlow = workcenters.where((w) => used.contains(w.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (inFlow.isEmpty) {
      return Center(
        child: Text(
          l10n.workcentersTabEmpty,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    // Every station's periods, read together — the grid cannot lay out a row
    // until it knows how many rows each station has.
    final byStation = <String, List<WorkcenterSchedulePeriod>>{};
    for (final workcenter in inFlow) {
      final periods = ref
          .watch(
            workcenterScheduleProvider((
              projectId: project.id,
              workcenterId: workcenter.id,
            )),
          )
          .value;
      if (periods == null) {
        return const Center(child: CircularProgressIndicator());
      }
      byStation[workcenter.id] = periods;
    }

    final rows = stationGridRows([
      for (final workcenter in inFlow)
        (
          workcenterId: workcenter.id,
          name: workcenter.name,
          periods: byStation[workcenter.id]!.length,
        ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One banner for the whole grid rather than one per card: the cards are
        // gone, and a reader wants to know the line has a gap before they want
        // to know which station has it.
        ScheduleIssuesBanner(
          issues: [
            for (final workcenter in inFlow)
              ...findSchedulePeriodIssues(
                PeriodSchedule<DatedPeriod>([
                  for (final period in byStation[workcenter.id]!)
                    WorkcenterSchedulePeriodSpec(
                      startDate: period.startDate,
                      endDate: period.endDate,
                      operatorsPerShift: parseOperatorsPerShift(
                        period.operatorsPerShift,
                      ),
                      availability: period.availability,
                      rework: period.rework,
                    ),
                ]),
              ),
          ],
        ),
        Expanded(
          child: _Grid(
            project: project,
            rows: rows,
            byStation: byStation,
            shiftLabels: shiftLabels,
          ),
        ),
      ],
    );
  }
}

const _stationColumn = 0;
const _startColumn = 1;
const _endColumn = 2;
const _operatorsColumn = 4;
const _availabilityColumn = 5;
const _reworkColumn = 6;

/// The columns the per-station grids had, with the station in front of them.
class _Grid extends ConsumerWidget {
  const _Grid({
    required this.project,
    required this.rows,
    required this.byStation,
    required this.shiftLabels,
  });

  final Project project;
  final List<StationGridRow> rows;
  final Map<String, List<WorkcenterSchedulePeriod>> byStation;
  final List<String> shiftLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dates = DateStyleScope.of(context);
    final theme = Theme.of(context);

    return DataGrid(
      rowCount: rows.length,
      rowHeaderWidth: 44,
      rowActionsWidth: 48,
      rowHeader: (row) => Center(
        child: Text(
          // The append row of each station reads `+`, exactly as the single
          // station's grid did — there are simply several of them now.
          rows[row].isAppend ? '+' : '${rows[row].localRow + 1}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ),
      rowActions: (row) => rows[row].isAppend
          ? const SizedBox.shrink()
          : IconButton(
              tooltip: l10n.actionDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () async {
                final at = rows[row];
                final period = byStation[at.workcenterId]![at.localRow];
                final confirmed = await confirmAction(
                  context,
                  title: l10n.schedulePeriodDeleteTitle,
                  message: l10n.confirmDeleteBody,
                  confirmLabel: l10n.actionDelete,
                  destructive: true,
                );
                if (confirmed) {
                  await ref
                      .read(schedulesRepositoryProvider)
                      .deleteWorkcenterSchedulePeriod(period.id);
                }
              },
            ),
      columns: [
        // Read-only: which station a period belongs to is decided by the row it
        // is on, not by typing a name into it. A writable station column would
        // be a way to move a period between stations by mistyping.
        DataGridColumn(
          title: l10n.workcenter,
          width: 150,
          readOnly: true,
        ),
        DataGridColumn(title: l10n.fieldStart, width: 130, numeric: true),
        DataGridColumn(title: l10n.fieldEnd, width: 130, numeric: true),
        // Derived by counting, never stored (§4.2) — shown, not typed.
        DataGridColumn(
          title: l10n.scheduleShifts,
          width: 80,
          numeric: true,
          readOnly: true,
        ),
        DataGridColumn(
          title: l10n.scheduleOperatorsPerShift,
          width: 150,
          helper: shiftLabels.join(' / '),
        ),
        DataGridColumn(title: l10n.availability, width: 120, numeric: true),
        DataGridColumn(title: l10n.rework, width: 110, numeric: true),
      ],
      valueAt: (row, column) => _valueAt(dates, row, column),
      errorAt: (row, column, raw) => _errorAt(l10n, dates, row, column, raw),
      onCommit: (row, column, block) => _commit(ref, dates, row, column, block),
    );
  }

  String _valueAt(DateStyle dates, int row, int column) {
    final at = rows[row];
    // The station's name is on its append row too: a blank row that does not
    // say what it will create is a row you have to count to identify.
    if (column == _stationColumn) return at.name;
    if (at.isAppend) return '';

    final period = byStation[at.workcenterId]![at.localRow];
    final operators = parseOperatorsPerShift(period.operatorsPerShift);
    return switch (column) {
      _startColumn => dates.format(period.startDate),
      _endColumn => dates.format(period.endDate),
      _operatorsColumn => formatOperatorsPerShift(operators),
      _availabilityColumn => formatFraction(period.availability),
      _reworkColumn => formatFraction(period.rework),
      _ => '${staffedShiftCount(operators)}',
    };
  }

  String? _errorAt(
    AppLocalizations l10n,
    DateStyle dates,
    int row,
    int column,
    String raw,
  ) {
    final text = raw.trim();
    // An append row is blank until something is typed into it, so an empty cell
    // there is not yet an error.
    if (text.isEmpty) {
      return rows[row].isAppend ? null : l10n.validationRequired;
    }
    return switch (column) {
      _startColumn || _endColumn => dates.parse(text) == null
          ? l10n.validationNotADate
          : null,
      _availabilityColumn || _reworkColumn => parseFraction(text) == null
          ? l10n.validationNotAPercentage
          : null,
      _operatorsColumn => parseOperatorsPerShift(text).isEmpty
          ? l10n.validationRequired
          : null,
      _ => null,
    };
  }

  /// Applies a typed cell or a pasted block, station by station.
  ///
  /// [splitStationPaste] decides which rows belong to whom and
  /// [planSchedulePeriodWrite] decides what each piece means — both pure, both
  /// unit-tested, and neither of them knowing about the other. This only writes
  /// what they read (§9.1's split).
  Future<void> _commit(
    WidgetRef ref,
    DateStyle dates,
    int row,
    int column,
    List<List<String>> block,
  ) async {
    final repository = ref.read(schedulesRepositoryProvider);

    for (final slice in splitStationPaste(
      rows: rows,
      row: row,
      block: block,
    )) {
      final writes = planSchedulePeriodWrite(
        periods: byStation[slice.workcenterId]!,
        row: slice.localRow,
        // The planner is the per-station one and still counts from Start, so
        // the station column in front of it is taken back off here rather than
        // taught to it.
        column: column - 1,
        block: slice.block,
        dates: dates,
        shiftCount: shiftLabels.length,
      );
      for (final write in writes) {
        if (write.id == null) {
          await repository.createWorkcenterSchedulePeriod(
            projectId: project.id,
            workcenterId: slice.workcenterId,
            startDate: write.startDate,
            endDate: write.endDate,
            operatorsPerShift: write.operatorsPerShift,
            availability: write.availability,
            rework: write.rework,
          );
        } else {
          await repository.updateWorkcenterSchedulePeriod(
            write.id!,
            startDate: write.startDate,
            endDate: write.endDate,
            operatorsPerShift: write.operatorsPerShift,
            availability: write.availability,
            rework: write.rework,
          );
        }
      }
    }
  }
}
