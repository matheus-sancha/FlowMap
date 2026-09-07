/// Demand against capacity, month by month (DESIGN.md §8.2, `TODO.md` §10.3).
///
/// **What a run says about load over time**, which every figure before it
/// flattened: the Summary states one occupation for a whole run, so a plant
/// that is comfortable in January and drowning in April reads as an average
/// neither month has. §10.2 gave a run the two things this needs — what rework
/// cost, and what a *month* of a station was worth — and this is what reads
/// them.
///
/// Pure and free of Drift, so what a bar means is a unit test.
library;

import '../data/simulation_runs_repository.dart';
import 'run_filter.dart';
import '../../../common/period_granularity.dart';

/// Which stations are in view, on top of the study and order filters
/// [RunFilter] already carries.
///
/// **A second filter rather than more fields on the first**, because the two
/// narrow different things and combining them would hide that. [RunFilter]
/// chooses whose *demand* is coloured — its cells and lines are a study filter
/// one level up (§7.10) and never touch a station. This chooses which
/// **stations** are drawn at all, and a station it excludes contributes neither
/// bar nor capacity line.

/// One column of the chart: a month, its three segments, what else was asked of
/// those stations, and what they had.
class OccupationMonth {
  const OccupationMonth({
    required this.month,
    required this.process,
    required this.rework,
    required this.changeover,
    required this.other,
    required this.capacity,
    required this.stations,
    required this.stationsOver,
  });

  /// First instant of the month, local — the same key the capacity rows are
  /// stored under, so a bar and its line cannot land in different columns.
  final DateTime month;

  /// Work before rework, in seconds of the stations' open clock (§10.2).
  final Duration process;

  /// What rework added on top — `processSeconds - processSecondsBeforeRework`,
  /// subtracted rather than multiplied out so a station with none reads a true
  /// zero.
  final Duration rework;

  /// Setup and teardown actually charged (§7.6).
  ///
  /// **In the bar rather than left out.** A bar omitting it would draw a station
  /// under its line while the Summary read 96 %, and §7.6 is the record of what
  /// a surface agreeing with itself and disagreeing with its own metric costs.
  final Duration changeover;

  /// Demand at these stations from orders an **order-level** filter excluded —
  /// a customer project, a part number, an order number.
  ///
  /// **An order-level filter colours the bar; it never shrinks it.** Filtered to
  /// one project, its own demand may sit comfortably under the line while
  /// everything the station is actually asked for breaks it, and a bar that
  /// dropped the rest would let a planner filter an overload away. So it stays
  /// in the stack as a fourth, neutral segment and [total] is always the
  /// station's true load.
  ///
  /// **Zero under a structural filter, always.** Study, cell, line, type and
  /// workcenter choose the *station set*, so demand and capacity move together
  /// and there is no remainder to hold — the bar is fully coloured. It did not
  /// used to be, and the field reported it: those filters were being passed
  /// through to `kept`, so narrowing to one study painted every other study's
  /// work at a shared station grey.
  final Duration other;

  /// Open time those stations had in this month, units already multiplied in.
  ///
  /// **Never pro-rated and never moved by a filter**: a denominator computed
  /// from one line's share of another line's demand is not a number the plant
  /// has.
  final Duration capacity;

  /// How many stations are in view, and how many of them individually asked for
  /// more than they had this month.
  ///
  /// **The badge that stops an aggregate reading as an occupation.** Summed over
  /// twelve stations the ratio answers a real question about plant hours and
  /// headcount, and answers nothing at all about whether any one machine is
  /// overloaded — §8.1's ranking is where a bottleneck is found.
  final int stations;
  final int stationsOver;

  /// The three coloured segments — what the filter's own orders asked for, and
  /// what the Summary calls `required`.
  Duration get required => process + rework + changeover;

  /// Everything those stations were asked for, filtered or not.
  Duration get total => required + other;

  /// [total] over [capacity], or null where there is no capacity to divide by —
  /// a month every station in view was closed for, which is a real state and is
  /// drawn as a floor rather than as a bar of infinite height.
  double? get occupation =>
      capacity == Duration.zero ? null : total.inSeconds / capacity.inSeconds;

  bool get isOverloaded => (occupation ?? 0) > 1;
}

/// One row of the pivot beneath the chart: a production line, and what its own
/// demand asked of each workcenter type over the whole visible span.
class OccupationPivotRow {
  const OccupationPivotRow({
    required this.cellId,
    required this.cellName,
    required this.lineId,
    required this.lineName,
    required this.byType,
    required this.total,
  });

  final String? cellId;
  final String cellName;
  final String? lineId;
  final String lineName;

  /// Type id → this line's own demand over that type's **full** capacity.
  ///
  /// Absent where the line never touches the type — a dash rather than a zero,
  /// which are different statements (§5.1).
  final Map<String, double> byType;

  /// The same across every type in view.
  final double? total;
}

/// The pivot: lines down, workcenter types across.
///
/// **Columns are types rather than stations**, which is defensible in a way
/// summing unlike machines is not — `takt_balance.dart` already treats
/// *"workcenters of the same type in the sequence"* as one group that can share
/// work.
class OccupationPivot {
  const OccupationPivot({
    required this.typeIds,
    required this.typeNames,
    required this.rows,
    required this.totals,
    required this.total,
  });

  /// Column order, by name.
  final List<String> typeIds;
  final Map<String, String> typeNames;
  final List<OccupationPivotRow> rows;

  /// The TOTAL row: **every line touching those stations, filtered out or not**,
  /// which is the same rule as the chart's neutral segment.
  ///
  /// Under a filter this will therefore *not* equal the sum of the cells above
  /// it. **That is the point rather than a defect** — it is the only place the
  /// contention still appears once a cell reads its own comfortable 75 %.
  final Map<String, double> totals;
  final double? total;
}

/// The whole chart, ready to draw.
class OccupationGraph {
  const OccupationGraph({
    required this.months,
    required this.pivot,
    required this.stationsInView,
  });

  final List<OccupationMonth> months;
  final OccupationPivot pivot;

  /// Workcenter ids the chart aggregated, for the caption that says how many.
  final Set<String> stationsInView;

  bool get isEmpty => months.isEmpty;

  /// Whether any month asks for more than it has, which is what a reader is
  /// scanning for.
  bool get hasOverload => months.any((m) => m.isOverloaded);
}

/// Builds the chart from a stored run.
///
/// **Returns null on a run that cannot answer**, rather than an empty chart:
/// a run made before v25 carries no monthly capacity and no rework split, and
/// §10.2 is explicit that inventing them from today's schedules would draw a
/// 2025 capacity line out of a plant retuned in 2026. No graph is the honest
/// answer, the way pre-v18 runs group nothing.
OccupationGraph? occupationGraph({
  required StoredRun run,
  RunFilter filter = const RunFilter(),
  PeriodGranularity granularity = PeriodGranularity.month,
}) {
  final monthly = run.result.openByWorkcenterMonth;
  if (monthly.isEmpty) return null;

  final typeOf = {
    for (final row in run.metrics.workcenters) row.workcenterId: row.typeId,
  };
  final typeNames = <String, String>{
    for (final row in run.metrics.workcenters)
      if (row.typeId != null && row.typeName != null) row.typeId!: row.typeName!,
  };

  // **The shared station resolution** (#9). The chart used to carry its own
  // `OccupationStations`, owned by the Occupation view and reaching nothing
  // else — so narrowing to one workcenter narrowed this chart while the Gantt
  // and the queue tables went on drawing the whole plant. Both station filters
  // are on `RunFilter` now, and studies, cells and lines narrow the station set
  // too, through the stations their studies visited.
  final inView = stationsInView(run, filter);
  if (inView.isEmpty) return null;

  // The orders an **order-level** filter keeps, taken through `filterRun` so
  // the chart and every table beside it cannot disagree about which orders are
  // in the slice.
  //
  // **Structural filters are stripped out of this, and were not** — the field
  // reported the neutral segment appearing under a study, cell, line, type or
  // workcenter filter, and it was right. This passed the whole `filter`, so a
  // structural filter narrowed the station set *and* dropped every other
  // study's orders out of `kept`, painting their work at those shared stations
  // grey. `occupation_grid.dart` has always stripped them; the chart never did,
  // which quietly broke this library's own claim that the two surfaces cannot
  // disagree about what is being looked at.
  //
  // A structural filter therefore leaves the bar entirely coloured: the station
  // set moved, so demand and capacity moved with it, and there is no remainder
  // for the neutral segment to hold. The bar is still the stations' **full**
  // load, which is what stops a filter from making an overload disappear.
  final kept = {
    for (final outcome
        in filterRun(
          run,
          RunFilter(
            customerProjects: filter.customerProjects,
            partNumbers: filter.partNumbers,
            orderNumbers: filter.orderNumbers,
            from: filter.from,
            to: filter.to,
          ),
        ).result.orders)
      outcome.orderId,
  };

  // --- the columns ---------------------------------------------------------

  final process = <DateTime, Duration>{};
  final rework = <DateTime, Duration>{};
  final changeover = <DateTime, Duration>{};
  final other = <DateTime, Duration>{};
  // Per station per month, so a month can say how many individual machines are
  // over rather than only whether the sum is.
  final loadByStation = <DateTime, Map<String, Duration>>{};

  for (final step in run.result.steps) {
    if (!inView.contains(step.workcenterId)) continue;
    // **Bucketed by when the work *arrived*, not when it ran** (§10.3). Work the
    // engine scheduled can never much exceed capacity — it would not have been
    // scheduled otherwise — so bucketing by `processStart` hides the overload
    // that caused the queue. Five orders arriving with 500 h against a 400 h
    // month is 125 %, and the bar is meant to break the line.
    if (!filter.includesDate(step.queueStart)) continue;
    final month = granularity.startOf(step.queueStart);

    final before = step.processSecondsBeforeRework;
    final total = step.processSeconds;
    if (before == null || total == null) continue;
    final setup = Duration(seconds: step.changeoverSeconds ?? 0);
    final work = Duration(seconds: before);
    final extra = Duration(seconds: total - before);

    (loadByStation[month] ??= {}).update(
      step.workcenterId,
      (had) => had + work + extra + setup,
      ifAbsent: () => work + extra + setup,
    );

    if (kept.contains(step.orderId)) {
      process[month] = (process[month] ?? Duration.zero) + work;
      rework[month] = (rework[month] ?? Duration.zero) + extra;
      changeover[month] = (changeover[month] ?? Duration.zero) + setup;
    } else {
      other[month] = (other[month] ?? Duration.zero) + work + extra + setup;
    }
  }

  // Every month the run spans at the stations in view, whether or not anything
  // arrived in it: a quiet month is a fact about the plan and a gap in the axis
  // would hide it.
  // **Filtered monthly, then folded — the grid's order exactly** (#17). The
  // chart is the grid's banner since #16, one bar directly above its own row of
  // cells, so a column the two computed differently would be a bar over the
  // wrong figures.
  final keptMonths = <DateTime>{
    for (final id in inView) ...?monthly[id]?.keys,
  }.where(filter.includesDate).toSet();

  final capacityByStation = <String, Map<DateTime, Duration>>{
    for (final entry in monthly.entries) entry.key: <DateTime, Duration>{},
  };
  for (final entry in monthly.entries) {
    final folded = capacityByStation[entry.key]!;
    for (final month in entry.value.entries) {
      if (!keptMonths.contains(month.key)) continue;
      folded.update(
        granularity.startOf(month.key),
        (had) => had + month.value,
        ifAbsent: () => month.value,
      );
    }
  }

  final months = keptMonths.map(granularity.startOf).toSet().toList()..sort();

  final columns = [
    for (final month in months)
      () {
        var capacity = Duration.zero;
        var over = 0;
        for (final id in inView) {
          final had = capacityByStation[id]?[month] ?? Duration.zero;
          capacity += had;
          final asked = loadByStation[month]?[id] ?? Duration.zero;
          if (had > Duration.zero && asked > had) over++;
        }
        return OccupationMonth(
          month: month,
          process: process[month] ?? Duration.zero,
          rework: rework[month] ?? Duration.zero,
          changeover: changeover[month] ?? Duration.zero,
          other: other[month] ?? Duration.zero,
          capacity: capacity,
          stations: inView.length,
          stationsOver: over,
        );
      }(),
  ];

  // --- the pivot -----------------------------------------------------------

  // Capacity per type over the whole visible span, which is every cell's
  // denominator: a line's share is measured against the type's *full* capacity,
  // so with every line in view a column's cells sum to its total.
  final capacityByType = <String, Duration>{};
  for (final id in inView) {
    final type = typeOf[id];
    if (type == null) continue;
    for (final month in months) {
      capacityByType[type] =
          (capacityByType[type] ?? Duration.zero) +
          (capacityByStation[id]?[month] ?? Duration.zero);
    }
  }

  final studyOf = {for (final study in run.studies) study.studyId: study};
  final demandByLineType = <String, Map<String, Duration>>{};
  final demandByType = <String, Duration>{};

  for (final step in run.result.steps) {
    if (!inView.contains(step.workcenterId)) continue;
    if (!filter.includesDate(step.queueStart)) continue;
    final month = granularity.startOf(step.queueStart);
    if (!months.contains(month)) continue;
    final type = typeOf[step.workcenterId];
    if (type == null) continue;
    final before = step.processSecondsBeforeRework;
    final total = step.processSeconds;
    if (before == null || total == null) continue;
    final asked =
        Duration(seconds: total) + Duration(seconds: step.changeoverSeconds ?? 0);

    // The TOTAL row counts every line, filtered out or not — the same rule as
    // the neutral segment above.
    demandByType[type] = (demandByType[type] ?? Duration.zero) + asked;

    final study = studyOf[step.studyId];
    final lineKey = study?.productionLineId ?? study?.studyId ?? step.studyId;
    (demandByLineType[lineKey] ??= {}).update(
      type,
      (had) => had + asked,
      ifAbsent: () => asked,
    );
  }

  double? ratio(Duration asked, Duration had) =>
      had == Duration.zero ? null : asked.inSeconds / had.inSeconds;

  final typeIds = capacityByType.keys.toList()
    ..sort((a, b) => (typeNames[a] ?? a).compareTo(typeNames[b] ?? b));

  // One row per line the run touched, in cell then line order — the reading
  // order of the plant rather than of the database.
  final lines = {
    for (final study in run.studies.reversed)
      study.productionLineId ?? study.studyId: study,
  };
  final rows =
      [
        for (final entry in lines.entries)
          if (demandByLineType[entry.key] case final asked?)
            OccupationPivotRow(
              cellId: entry.value.productionCellId,
              cellName: entry.value.productionCellName ?? '—',
              lineId: entry.value.productionLineId,
              lineName: entry.value.productionLineName ?? entry.value.name,
              byType: {
                for (final type in typeIds)
                  if (asked[type] case final worked?)
                    type: ?ratio(worked, capacityByType[type] ?? Duration.zero),
              },
              total: ratio(
                asked.values.fold(Duration.zero, (sum, d) => sum + d),
                capacityByType.values.fold(Duration.zero, (sum, d) => sum + d),
              ),
            ),
      ]..sort((a, b) {
        final byCell = a.cellName.compareTo(b.cellName);
        return byCell != 0 ? byCell : a.lineName.compareTo(b.lineName);
      });

  return OccupationGraph(
    months: columns,
    stationsInView: inView,
    pivot: OccupationPivot(
      typeIds: typeIds,
      typeNames: typeNames,
      rows: rows,
      totals: {
        for (final type in typeIds)
          type: ?ratio(
            demandByType[type] ?? Duration.zero,
            capacityByType[type] ?? Duration.zero,
          ),
      },
      total: ratio(
        demandByType.values.fold(Duration.zero, (sum, d) => sum + d),
        capacityByType.values.fold(Duration.zero, (sum, d) => sum + d),
      ),
    ),
  );
}
