/// What the simulation report ranks and lists (DESIGN.md §13, #27).
///
/// Pure, so what the printed page *says* is a unit test; the page only sets it.
library;

import '../data/simulation_runs_repository.dart';
import 'run_metrics.dart';

/// The orders that were not on time, worst first.
///
/// **An order that never delivered is the worst**, ahead of any late one: it
/// has no float to rank by, and §8 already counts it against on-time delivery —
/// a list that dropped it would be shorter than the headline's late count.
/// After those, the most negative float first, then by need date.
List<ProductionPlanRow> lateOrders(List<PlanEntry> plan) {
  final late = [
    for (final entry in plan)
      if (entry is ProductionPlanRow && !entry.outcome.isOnTime) entry,
  ];
  late.sort((a, b) {
    final fa = a.float;
    final fb = b.float;
    if (fa == null && fb != null) return -1;
    if (fb == null && fa != null) return 1;
    if (fa != null && fb != null && fa != fb) return fa.compareTo(fb);
    return a.outcome.needDate.compareTo(b.outcome.needDate);
  });
  return late;
}

/// §13's bottleneck ranking: the workcenters orders waited at longest.
///
/// `RunMetrics.workcenters` is already ranked by queue time, the ranking the
/// headline's bottleneck comes from; a workcenter nobody visited is left off,
/// for the reason `RunMetrics.bottleneck` leaves it off. Capped, because a
/// ranking is read from the top and forty rows of a quiet plant is a table
/// rather than a finding.
List<WorkcenterRunMetrics> bottleneckRanking(
  RunMetrics metrics, {
  int limit = 10,
}) => metrics.workcenters.where((w) => w.visits > 0).take(limit).toList();
