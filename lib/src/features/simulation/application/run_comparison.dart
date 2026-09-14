import '../../../data/database/database.dart';
import '../data/simulation_runs_repository.dart';
import 'occupation_grid.dart';
import 'run_filter.dart';
import 'run_metrics.dart';

/// Two studies of one cell and line, each as its latest run left it (#26).
///
/// **The unit is two studies again**, restored 2026-09-13 at the developer's
/// call after a morning as *two runs*. The run history had argued for runs —
/// #26's rule matched zero pairs across all 165 stored runs — but the question
/// a planner brings is *which version of this line is better*, and two runs of
/// one study answer a narrower one. The cost is stated rather than argued away:
/// **Compare stays empty until someone duplicates a study on its line, flags
/// the copy and simulates it**, and the screen says exactly that.
///
/// **Each side is its study's slice of the run**, not the run. At most one study
/// per line is flagged in a run, so the two studies are always in different
/// runs, and each of those runs also carries every other line's orders; the
/// whole-run figures would compare the plant, not the line.
///
/// **Nothing here recomputes anything.** The outcome comes from `filterRun`'s
/// metrics — the same slice the results screen shows for that study — and the
/// cause from the input snapshot each run froze (§7.10).
class RunComparison {
  const RunComparison({
    required this.deltas,
    required this.differences,
    required this.warnings,
    this.occupation = const [],
  });

  final List<MetricDelta> deltas;

  /// What was different about the inputs — the half the feature exists for.
  final List<InputDifference> differences;

  /// Reasons to read the comparison carefully rather than refusals.
  final List<ComparisonWarning> warnings;

  /// Occupation per workcenter type, the total first — one row per type
  /// either side used, so a type only one study touches still shows.
  final List<OccupationDelta> occupation;

  /// On-time delivery, which the run's headline and §13's report lead with.
  MetricDelta? get verdict => deltas
      .where((d) => d.metric == ComparedMetric.onTimeDelivery)
      .firstOrNull;

  static RunComparison between(ComparedSide before, ComparedSide after) =>
      RunComparison(
        deltas: _deltas(before.metrics, after.metrics),
        differences: _differences(before, after),
        occupation: _occupation(before, after),
        warnings: [
          // **Provenance.** #19 changed what a run means with no migration, so
          // the build is the only thing that separates two runs at one schema
          // version (#24). Both unstamped compares freely.
          if (before.appVersion != after.appVersion)
            ComparisonWarning.differentBuilds,
        ],
      );

  static List<MetricDelta> _deltas(RunMetrics a, RunMetrics b) {
    // **The headline's own figure**, on-time over *all* orders (§8): an order
    // that never came out is not on time. Null only when there were no orders,
    // so a side of nothing is not an improvement.
    double? otd(RunMetrics m) => m.orders == 0 ? null : m.onTimeDelivery * 100;
    double? days(Duration? d) => d == null ? null : d.inMinutes / (60 * 24);

    return [
      MetricDelta(
        metric: ComparedMetric.onTimeDelivery,
        before: otd(a),
        after: otd(b),
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
        before: a.late.toDouble(),
        after: b.late.toDouble(),
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

  /// What the two studies were *given*, where it differs.
  ///
  /// The two snapshot rows against each other directly: they are different
  /// studies with different names, so matching them by name — as the run
  /// comparison did — would report each as missing from the other.
  static List<InputDifference> _differences(ComparedSide a, ComparedSide b) {
    final out = <InputDifference>[];
    void diff(InputField field, Object? x, Object? y) {
      if (x != y) {
        out.add(
          InputDifference(
            field: field,
            before: x?.toString(),
            after: y?.toString(),
          ),
        );
      }
    }

    final x = a.study;
    final y = b.study;
    // **No release interval** (drive, 2026-09-13). It is derived from the takt
    // and the pace setter's calendar rather than chosen, so it showed as a
    // second, less readable row for a difference already on the takt row.
    // Value *and* unit: `4 days` and `4 hours` are the same number.
    diff(
      InputField.takt,
      x.taktValue == null ? null : '${x.taktValue} ${x.taktUnit}',
      y.taktValue == null ? null : '${y.taktValue} ${y.taktUnit}',
    );
    diff(InputField.wipCap, x.wipCap, y.wipCap);
    diff(InputField.startBuffer, x.startBufferDays, y.startBufferDays);

    // **Dispatch, per workcenter** (§7.3). The rule belongs to the workcenter,
    // so a study's side carries its whole run's rules; two studies of one line
    // share their workcenters, so a difference here is one someone set.
    final rulesBefore = {for (final w in a.queues.workcenters) w.name: w.rule};
    final rulesAfter = {for (final w in b.queues.workcenters) w.name: w.rule};
    for (final name in {...rulesBefore.keys, ...rulesAfter.keys}) {
      final r1 = rulesBefore[name];
      final r2 = rulesAfter[name];
      if (r1 != r2) {
        out.add(
          InputDifference(
            field: InputField.dispatch,
            workcenter: name,
            before: r1?.name,
            after: r2?.name,
          ),
        );
      }
    }
    return out;
  }

  static List<OccupationDelta> _occupation(ComparedSide a, ComparedSide b) {
    final names = <String>{
      ...a.occupationByType.keys,
      ...b.occupationByType.keys,
    }.toList()..sort();
    return [
      OccupationDelta(
        type: null,
        before: a.occupationTotal,
        after: b.occupationTotal,
      ),
      for (final name in names)
        OccupationDelta(
          type: name,
          before: a.occupationByType[name],
          after: b.occupationByType[name],
        ),
    ];
  }
}

/// One row of the occupation table: a workcenter type, or the total when
/// [type] is null. Ratios, 1.0 is full.
class OccupationDelta {
  const OccupationDelta({
    required this.type,
    required this.before,
    required this.after,
  });

  final String? type;
  final double? before;
  final double? after;

  double? get delta =>
      before == null || after == null ? null : after! - before!;
}

/// The months both sides of a comparison are measured over: from the earlier
/// first release to the later last delivery of the two studies.
///
/// **One window for both**, so neither ratio is diluted by months the other
/// did not work: the live schedules run three years around fifteen months of
/// work (#31), and an occupation averaged over the idle ones is not the one a
/// planner reads. Null when neither study delivered anything, which measures
/// the whole span.
({DateTime from, DateTime to})? comparisonWindow(
  StoredRun a,
  String studyA,
  StoredRun b,
  String studyB,
) {
  DateTime? first;
  DateTime? last;
  for (final (run, studyId) in [(a, studyA), (b, studyB)]) {
    for (final order in run.result.orders) {
      if (order.studyId != studyId) continue;
      final released = order.released;
      final delivered = order.delivered;
      if (released == null || delivered == null) continue;
      if (first == null || released.isBefore(first)) first = released;
      if (last == null || delivered.isAfter(last)) last = delivered;
    }
  }
  if (first == null || last == null) return null;
  return (
    from: DateTime(first.year, first.month),
    to: DateTime(last.year, last.month + 1, 0, 23, 59, 59),
  );
}

/// One study, as one run left it: its slice's figures and its input snapshot.
class ComparedSide {
  const ComparedSide({
    required this.study,
    required this.metrics,
    required this.queues,
    required this.appVersion,
    required this.runAt,
    this.occupationTotal,
    this.occupationByType = const {},
  });

  /// The study's side of [run], through the same filter the results screen
  /// uses, so the figures here and the study's own results cannot disagree.
  ///
  /// **Occupation is the Occupation grid's, grouped by type**, over [window]:
  /// the workcenters this study used, carrying *everyone's* demand in that run
  /// over their capacity — a filter chooses what you look at and never shrinks
  /// what a machine was asked for (§10.3). So it answers *how loaded was the
  /// plant this study ran in*, which is the question a second version of a line
  /// changes.
  factory ComparedSide.of(
    StoredRun run,
    String studyId, {
    ({DateTime from, DateTime to})? window,
    String untypedLabel = 'Untyped',
  }) {
    final grid = occupationGrid(
      run: run,
      filter: RunFilter(
        studyIds: {studyId},
        from: window?.from,
        to: window?.to,
      ),
      grouping: OccupationGrouping.type,
      untypedLabel: untypedLabel,
    );
    return ComparedSide(
      study: run.studies.firstWhere((s) => s.studyId == studyId),
      metrics: filterRun(run, RunFilter.study(studyId)).metrics,
      queues: run.queues,
      appVersion: run.appVersion,
      runAt: run.createdAt,
      occupationTotal: grid?.total.total.ratio,
      occupationByType: {
        for (final row in grid?.rows ?? const <OccupationRow>[])
          row.name: row.total.ratio,
      },
    );
  }

  final SimulationRunStudy study;
  final RunMetrics metrics;
  final RunQueues queues;
  final String? appVersion;
  final DateTime runAt;

  /// Demand over capacity across the window, or null on a run with no monthly
  /// capacity (before v25).
  final double? occupationTotal;
  final Map<String, double?> occupationByType;
}

enum ComparedMetric { onTimeDelivery, leadTime, float, lateOrders, emptySlots }

/// What a difference is in. [dispatch] names its workcenter.
enum InputField { takt, wipCap, startBuffer, dispatch }

enum ComparisonWarning { differentBuilds }

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

  /// Null when either side is missing, so a side that delivered nothing does not
  /// read as an improvement.
  bool? get isBetter {
    final d = delta;
    if (d == null || d == 0) return null;
    return higherIsBetter ? d > 0 : d < 0;
  }
}

/// One thing the two sides were given differently.
class InputDifference {
  const InputDifference({
    required this.field,
    required this.before,
    required this.after,
    this.workcenter,
  });

  final InputField field;

  /// Set for [InputField.dispatch] only.
  final String? workcenter;
  final String? before;
  final String? after;
}

/// A cell and line with at least two studies that have been simulated — the
/// only place Compare has anything to offer.
class ComparableLine {
  const ComparableLine({
    required this.cellId,
    required this.lineId,
    required this.label,
    required this.studies,
  });

  final String cellId;
  final String lineId;

  /// `Célula 11 · Fluxo 11B`, from the latest run's snapshot.
  final String label;

  /// Newest run first, so the default pair is the two most recently simulated.
  final List<LatestStudyRun> studies;
}

typedef LatestStudyRun = ({
  String studyId,
  String name,
  String runId,
  DateTime runAt,
});

/// The lines Compare can offer, from the project's studies and its run history.
///
/// **Grouped by where each study is now**, not by its snapshot: 37 of the live
/// database's 378 snapshot rows predate the cell and line columns, and a study
/// moved to another line belongs with its new neighbours. A study with no run
/// is left out — there is nothing of it to compare.
///
/// [runs] is newest first, as `watchRuns` returns it, so a study's first
/// appearance is its latest run.
List<ComparableLine> comparableLines(
  List<Study> studies,
  List<RunListing> runs,
) {
  final latest = <String, ({RunListing listing, RunListingStudy snapshot})>{};
  for (final listing in runs) {
    for (final snapshot in listing.studies) {
      latest.putIfAbsent(
        snapshot.id,
        () => (listing: listing, snapshot: snapshot),
      );
    }
  }

  final groups = <(String, String), List<Study>>{};
  for (final study in studies) {
    if (!latest.containsKey(study.id)) continue;
    (groups[(study.productionCellId, study.productionLineId)] ??= []).add(
      study,
    );
  }

  return [
    for (final MapEntry(key: (cellId, lineId), value: members)
        in groups.entries)
      if (members.length >= 2)
        () {
          final ranked = [
            for (final study in members)
              (
                studyId: study.id,
                name: study.name,
                runId: latest[study.id]!.listing.run.id,
                runAt: latest[study.id]!.listing.run.createdAt,
              ),
          ]..sort((a, b) => b.runAt.compareTo(a.runAt));
          final snapshot = latest[ranked.first.studyId]!.snapshot;
          return ComparableLine(
            cellId: cellId,
            lineId: lineId,
            label: [
              snapshot.cellName ?? '—',
              snapshot.lineName ?? '—',
            ].join(' · '),
            studies: ranked,
          );
        }(),
  ];
}
