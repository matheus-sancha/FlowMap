import '../../../data/database/database.dart';
import '../data/simulation_runs_repository.dart';
import 'run_metrics.dart';

/// How two runs compare, and what was different about them.
///
/// **The unit is two runs, not two studies** — inverted 2026-09-13 by the run
/// history. #26 settled on two studies of one cell and line; across all 165
/// runs ever made that matched **zero** pairs, while one study's own runs
/// differ in up to **9 release cadences**. The scenario case survives as a case
/// of this, since two studies on one line with a run each is simply two runs.
///
/// **Nothing here recomputes anything.** Both sides come from what the run
/// already stored — `RunMetrics` for the outcome and `SimulationRunStudies`'
/// input snapshot for the cause — which is the same one-function-two-callers
/// rule `occupationTooltip()` set. A comparison that re-derived its own figures
/// could disagree with the screen it sits beside.
class RunComparison {
  const RunComparison({
    required this.deltas,
    required this.differences,
    required this.warnings,
  });

  final List<MetricDelta> deltas;

  /// What was different about the inputs — the half the whole feature exists
  /// for. *"4 % better, and here is the one thing that differed."*
  final List<InputDifference> differences;

  /// Reasons to read the comparison carefully rather than refusals.
  final List<ComparisonWarning> warnings;

  /// The headline: on-time delivery, which is the customer-facing outcome and
  /// the metric §13's simulation report leads with, so the screen and the
  /// report agree rather than each picking a favourite.
  MetricDelta? get verdict =>
      deltas.where((d) => d.metric == ComparedMetric.onTimeDelivery).firstOrNull;

  static RunComparison of(StoredRun a, StoredRun b) => RunComparison(
    deltas: _deltas(a.metrics, b.metrics),
    differences: _differences(a, b),
    warnings: _warnings(a, b),
  );

  static List<MetricDelta> _deltas(RunMetrics a, RunMetrics b) {
    // **The headline's own figure**, on-time over *all* orders (§8): an order
    // that never came out is not on time. This was on-time over delivered,
    // which made the comparison disagree with the card above it. Null only when
    // the run had no orders, so a run of nothing is not an improvement.
    double? otd(RunMetrics m) => m.orders == 0 ? null : m.onTimeDelivery * 100;
    double? days(Duration? d) => d?.inMinutes == null
        ? null
        : d!.inMinutes / (60 * 24);

    return [
      MetricDelta(
        metric: ComparedMetric.onTimeDelivery,
        before: otd(a),
        after: otd(b),
        // Higher is better for OTD; lower for the rest.
        higherIsBetter: true,
      ),
      MetricDelta(
        metric: ComparedMetric.leadTime,
        before: days(a.averageLeadTime),
        after: days(b.averageLeadTime),
        higherIsBetter: false,
      ),
      MetricDelta(
        metric: ComparedMetric.float,
        before: days(a.averageFloat),
        after: days(b.averageFloat),
        // Float is slack against the need date: positive is early (§10.4).
        higherIsBetter: true,
      ),
      MetricDelta(
        metric: ComparedMetric.lateOrders,
        before: (a.delivered - a.onTime).toDouble(),
        after: (b.delivered - b.onTime).toDouble(),
        higherIsBetter: false,
      ),
      MetricDelta(
        metric: ComparedMetric.emptySlots,
        before: a.emptySlots.toDouble(),
        after: b.emptySlots.toDouble(),
        higherIsBetter: false,
      ),
    ];
  }

  /// What the two runs were *given*, where they differ.
  ///
  /// Read from the snapshot each run froze at the moment it was made (§7.10) —
  /// which is precisely why that snapshot exists, and why editing a takt
  /// schedule afterwards cannot rewrite what a past run claims to have done.
  static List<InputDifference> _differences(StoredRun a, StoredRun b) {
    final byStudy = <String, (SimulationRunStudy?, SimulationRunStudy?)>{};
    for (final study in a.studies) {
      byStudy[study.name] = (study, null);
    }
    for (final study in b.studies) {
      byStudy[study.name] = (byStudy[study.name]?.$1, study);
    }

    final out = <InputDifference>[];
    for (final entry in byStudy.entries) {
      final (before, after) = entry.value;
      if (before == null || after == null) {
        out.add(
          InputDifference(
            study: entry.key,
            field: InputField.presence,
            before: before == null ? null : 'included',
            after: after == null ? null : 'included',
          ),
        );
        continue;
      }
      void diff(InputField field, Object? x, Object? y) {
        if (x != y) {
          out.add(
            InputDifference(
              study: entry.key,
              field: field,
              before: x?.toString(),
              after: y?.toString(),
            ),
          );
        }
      }

      diff(InputField.releaseSeconds, before.releaseSeconds, after.releaseSeconds);
      // Value *and* unit: `4 days` and `4 hours` are the same number.
      diff(
        InputField.takt,
        before.taktValue == null ? null : '${before.taktValue} ${before.taktUnit}',
        after.taktValue == null ? null : '${after.taktValue} ${after.taktUnit}',
      );
      diff(InputField.wipCap, before.wipCap, after.wipCap);
      diff(InputField.startBuffer, before.startBufferDays, after.startBufferDays);
    }

    // **Dispatch, per workcenter** (§7.3). The rule belongs to the workcenter
    // rather than the study, and it is what the runs menu labels a run with —
    // so it is the input most likely to be the one thing someone changed.
    final rulesBefore = {for (final w in a.queues.workcenters) w.name: w.rule};
    final rulesAfter = {for (final w in b.queues.workcenters) w.name: w.rule};
    for (final name in {...rulesBefore.keys, ...rulesAfter.keys}) {
      final x = rulesBefore[name];
      final y = rulesAfter[name];
      if (x != y) {
        out.add(
          InputDifference(
            study: name,
            field: InputField.dispatch,
            before: x?.name,
            after: y?.name,
          ),
        );
      }
    }
    return out;
  }

  static List<ComparisonWarning> _warnings(StoredRun a, StoredRun b) {
    final out = <ComparisonWarning>[];

    // **Provenance.** Two runs whose origin is equally known compare freely;
    // a mismatched pair warns. #19 changed what a run *means* with no
    // migration, so schema cannot stand in for the build (#24).
    final left = a.appVersion;
    final right = b.appVersion;
    if (left != right) {
      out.add(ComparisonWarning.differentBuilds);
    }

    // **Cell and line**, which #26 made the gate and the run history demoted to
    // this: two studies on different lines cover different workcenters and
    // different demand, so a difference often means *these are different
    // things* rather than anything actionable.
    String scope(StoredRun r) => {
      for (final s in r.studies)
        '${s.productionCellName ?? '—'}·${s.productionLineName ?? '—'}',
    }.join(', ');
    if (scope(a) != scope(b)) out.add(ComparisonWarning.differentScope);

    return out;
  }
}

enum ComparedMetric { onTimeDelivery, leadTime, float, lateOrders, emptySlots }

/// What a difference is in. [dispatch] is keyed by workcenter rather than by
/// study, so its `study` is the workcenter's name.
enum InputField { releaseSeconds, takt, wipCap, startBuffer, presence, dispatch }

enum ComparisonWarning { differentBuilds, differentScope }

/// One row of the metric table.
class MetricDelta {
  const MetricDelta({
    required this.metric,
    required this.before,
    required this.after,
    required this.higherIsBetter,
  });

  final ComparedMetric metric;
  final double? before;
  final double? after;
  final bool higherIsBetter;

  double? get delta =>
      before == null || after == null ? null : after! - before!;

  /// Null when either side is missing, so a run that delivered nothing does not
  /// read as an improvement.
  bool? get isBetter {
    final d = delta;
    if (d == null || d == 0) return null;
    return higherIsBetter ? d > 0 : d < 0;
  }
}

/// One thing the two runs were given differently.
class InputDifference {
  const InputDifference({
    required this.study,
    required this.field,
    required this.before,
    required this.after,
  });

  final String study;
  final InputField field;
  final String? before;
  final String? after;
}
