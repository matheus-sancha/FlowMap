/// Reading a slice of a stored run (DESIGN.md §12.1).
///
/// **One run, filtered — never a second run.** §7.7 builds one resource model of
/// the plant and lets line A's orders delay line B's, so a study run on its own
/// is a different and always-optimistic answer to a differently-worded question.
/// A study's Simulation tab and the combined workspace therefore read the same
/// `StoredRun` through this, and cannot disagree about a number.
///
/// **Order-level figures follow the filter; station-level figures do not**, and
/// the card says which. Utilisation's denominator is `openSeconds`, stored as a
/// run total, and rebuilding open time for a subset needs each station's
/// calendar — which §7.10 deliberately does not store and which is the exact
/// cost that got §3.5 dropped. Every order carries its own dates, so counts,
/// on-time, lead times and float recompute cleanly; a station's busy, open and
/// blocked time keep describing the whole run.
///
/// Pure and free of Drift, so what a filter *means* is a unit test.
library;

import '../data/simulation_runs_repository.dart';
import 'run_metrics.dart';
import 'sim_result.dart';

/// Which slice is being read. Every field null or empty is the whole run.
class RunFilter {
  const RunFilter({
    this.studyIds = const {},
    this.cellIds = const {},
    this.lineIds = const {},
    this.from,
    this.to,
  });

  /// One study, for its own Simulation tab.
  RunFilter.study(String studyId) : this(studyIds: {studyId});

  final Set<String> studyIds;

  /// **A cell or line filter is a study filter one level up.** Workcenters
  /// belong to a plant rather than to a cell (§7.10), so stations are never
  /// narrowed this way — the studies are, and their stations follow.
  final Set<String> cellIds;
  final Set<String> lineIds;

  /// The period, **by need date**.
  ///
  /// The only one of an order's three dates that is never null, so an order the
  /// run failed to complete still appears in its period instead of vanishing —
  /// and §7.8's abort case is exactly what a planner filters to find. It is also
  /// the date on-time and float are defined against, so the filter and the
  /// figures agree by construction.
  final DateTime? from;
  final DateTime? to;

  bool get isWholeRun =>
      studyIds.isEmpty &&
      cellIds.isEmpty &&
      lineIds.isEmpty &&
      from == null &&
      to == null;

  bool get narrowsOrders => from != null || to != null;

  bool includesDate(DateTime date) {
    if (from != null && date.isBefore(from!)) return false;
    if (to != null && date.isAfter(to!)) return false;
    return true;
  }
}

/// A stored run as one slice of it reads.
class FilteredRun {
  const FilteredRun({
    required this.run,
    required this.filter,
    required this.studyIds,
    required this.result,
    required this.metrics,
    required this.plan,
    required this.stationsAreWholeRun,
  });

  final StoredRun run;
  final RunFilter filter;

  /// The studies the filter resolved to, after cells and lines were applied.
  final Set<String> studyIds;

  /// Orders, steps and lane visits of those studies, inside the period.
  final SimRunResult result;

  /// Order-level figures for the slice; **station-level figures for the whole
  /// run**, because the run does not carry what a windowed denominator needs.
  final RunMetrics metrics;

  final List<ProductionPlanRow> plan;

  /// Whether the station figures describe more than the slice, so the view can
  /// say so rather than letting them read as filtered.
  final bool stationsAreWholeRun;

  bool get isWholeRun => filter.isWholeRun;

  /// What identifies this slice, for a view that caches something derived from
  /// it.
  ///
  /// The run's id alone is not enough: the combined workspace changes the filter
  /// without changing the run, and a chart that only watched the id would keep
  /// drawing the slice before last.
  String get signature =>
      '${run.id}|${(studyIds.toList()..sort()).join(',')}'
      '|${filter.from?.millisecondsSinceEpoch}|${filter.to?.millisecondsSinceEpoch}';
}

/// Reads [run] through [filter].
FilteredRun filterRun(StoredRun run, RunFilter filter) {
  // **Naming no study means every study, not no study.** Resolving the set from
  // `run.studies` and then requiring membership made an unfiltered view of a run
  // that lists no studies drop every order it had — which is exactly what the
  // Gantt's own tests caught, and would have been an empty chart in front of a
  // user otherwise. So a null set means "do not narrow" and is kept distinct
  // from an empty one, which means "narrowed to nothing".
  final narrowsStudies =
      filter.studyIds.isNotEmpty ||
      filter.cellIds.isNotEmpty ||
      filter.lineIds.isNotEmpty;

  final Set<String>? allowed = !narrowsStudies
      ? null
      : {
          for (final study in run.studies)
            if ((filter.studyIds.isEmpty ||
                    filter.studyIds.contains(study.studyId)) &&
                (filter.cellIds.isEmpty ||
                    filter.cellIds.contains(study.productionCellId)) &&
                (filter.lineIds.isEmpty ||
                    filter.lineIds.contains(study.productionLineId)))
              study.studyId,
        };

  // What the view reports as its studies: the resolved set, or everything the
  // run listed when nothing narrowed it.
  final studyIds =
      allowed ?? {for (final study in run.studies) study.studyId};

  bool keepsStudy(String studyId) => allowed == null || allowed.contains(studyId);

  bool keepsOrder(SimOrderOutcome outcome) =>
      keepsStudy(outcome.studyId) && filter.includesDate(outcome.needDate);

  final orders = run.result.orders.where(keepsOrder).toList();
  final keptOrderIds = {for (final outcome in orders) outcome.orderId};

  final result = SimRunResult(
    start: run.result.start,
    end: run.result.end,
    guard: run.result.guard,
    abort: run.result.abort,
    steps: [
      for (final step in run.result.steps)
        if (keptOrderIds.contains(step.orderId)) step,
    ],
    orders: orders,
    emptySlots: [
      for (final slot in run.result.emptySlots)
        if (keepsStudy(slot.studyId) && filter.includesDate(slot.at))
          slot,
    ],
    busyByWorkcenter: run.result.busyByWorkcenter,
    openByWorkcenter: run.result.openByWorkcenter,
    blockedByWorkcenter: run.result.blockedByWorkcenter,
    lanes: [
      for (final lane in run.result.lanes)
        if (keepsStudy(lane.studyId)) lane,
    ],
    openLaneVisits: run.result.openLaneVisits,
  );

  final sliced = summariseRun(
    result: result,
    // **From the metrics rather than from the plan.** Both carry the mapping,
    // but the plan is empty on a run nothing has printed and the metrics never
    // are — reading the plan made a filtered view fall back to part *ids*
    // wherever the plan happened to be absent, which is what the Gantt's own
    // tests caught.
    partNumbers: {
      for (final part in run.metrics.parts) part.partId: part.partNumber,
    },
    workcenterNames: {
      for (final station in run.metrics.workcenters)
        station.workcenterId: station.name,
    },
    // The theoretical walk is stored per order on the plan row rather than on
    // the outcome, so it is read from there (§8.5).
    theoreticalByOrder: {
      for (final row in run.plan)
        if (keptOrderIds.contains(row.outcome.orderId) &&
            row.theoreticalLeadTime != null)
          row.outcome.orderId: row.theoreticalLeadTime!,
    },
  );

  return FilteredRun(
    run: run,
    filter: filter,
    studyIds: studyIds,
    result: result,
    // **The station rankings come from the unfiltered run**, spliced back over
    // the slice's own figures. Recomputing them from filtered steps would give
    // a busy total for the slice over an open total for the run, which is a
    // utilisation that means nothing.
    metrics: sliced.withWorkcenters(run.metrics.workcenters),
    plan: [
      for (final row in run.plan)
        if (keptOrderIds.contains(row.outcome.orderId)) row,
    ],
    stationsAreWholeRun: !filter.isWholeRun,
  );
}
