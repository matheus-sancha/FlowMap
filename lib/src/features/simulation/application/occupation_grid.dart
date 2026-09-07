/// The Occupation grid: which station is over capacity, in which month, and by
/// how many hours (DESIGN.md §10.3, #9).
///
/// **A station × month grid, not a chart**, and the live database is why. Across
/// all three stored runs that can draw this view at all — 3 of 147; the other
/// 144 predate v25's monthly capacity — the aggregate bar the old chart drew
/// **never once broke its capacity line**, peaking at 87 %. Over the same months
/// single stations reached 149 % and seven of seventeen were over in one month.
/// The figure the view was built around could not report the finding the view
/// exists to find.
///
/// So the plant-level question — *is there enough plant* — is answered as one
/// row rather than as the figure.
///
/// **What is kept from the chart** (§10.3): work is bucketed by `queueStart`,
/// never `processStart`. Work the engine scheduled can never much exceed
/// capacity or it would not have been scheduled, so bucketing by when it *ran*
/// hides the overload that caused the queue. And changeover and rework stay
/// *inside* the number (§7.6) — a cell omitting them would disagree with the
/// Summary.
library;

import '../data/simulation_runs_repository.dart';
import 'run_filter.dart';
import '../../../common/period_granularity.dart';

/// What the rows of the grid are.
enum OccupationGrouping {
  /// One row per station: all demand at it over its own capacity that month.
  /// The default, and the grouping that answers the view's question.
  workcenter,

  /// One row per production line: **everyone's** demand at the stations that
  /// line depends on, over those stations' capacity.
  ///
  /// Arithmetically identical to filtering to that line, so the bands carry over
  /// unchanged and a line row is one PLANT row per line. This is the retired
  /// pivot's replacement, at one grain instead of two.
  ///
  /// **Known cost, accepted:** on the live plant the three lines read 79–82 %
  /// every month, because they share four of their stations. It separates them
  /// only where they do not overlap.
  ///
  /// *Rejected: the line's own demand ÷ all capacity in view.* Rows would sum to
  /// the PLANT row exactly and read as a clean decomposition, but they would be
  /// *shares* rather than occupations — so the 85/100 bands would be meaningless
  /// and the view would need a second colour vocabulary.
  line,

  /// One row per workcenter type: all demand at the stations of that type over
  /// those stations' capacity.
  ///
  /// **The one grouping whose rows genuinely partition.** A station carries
  /// exactly one type, so unlike [line] — where two lines sharing four stations
  /// count them both — no station is in two rows and none is in none. The rows
  /// therefore sum to the TOTAL row, which is the clean decomposition [line]
  /// was asked for and could not be.
  ///
  /// **Membership is the station's, not the run's.** [line] reads its stations
  /// from the steps, because a line depends on a station by using it; a type is
  /// a property of the machine, so a scheduled station the run never touched is
  /// in its type's row with capacity and no demand. That is the answer to *have
  /// I got enough cladding capacity* rather than *what did cladding do* — and
  /// on the live plant it moves Cladding from 67 % to 58 %, because one of its
  /// seven machines has never had work.
  ///
  /// **Recorded, and chosen with the cost stated:** nothing on the row says so.
  /// The qualifier slot could carry *7 stations, 1 idle*, and the offer was
  /// declined — the third time this view has been offered a way to show that an
  /// aggregate hides its members, after the plant row's 87 % over a 149 %
  /// station and the stations-over badge twice.
  type,
}

/// How a cell reads. The same cell, three ways.
enum OccupationUnit {
  /// `147%`.
  percent,

  /// `733/499` — asked of, over open.
  ///
  /// **Restores what a percentage drops.** Oct-25 carries 3,296 h of capacity
  /// and Jul-26 carries 9,384; a ratio makes a ramp-up month look like a full
  /// one. It is also §15's rule for what makes a number defensible — every
  /// derived figure expands to show its inputs.
  hours,

  /// `-234` h: open minus asked, negative when the station is over.
  gap,
}

/// One row of the grid, and its months.
class OccupationRow {
  const OccupationRow({
    required this.id,
    required this.name,
    required this.qualifier,
    required this.cells,
  });

  final String id;

  /// The station or line, as the run recorded it (§7.10).
  final String name;

  /// The pool a station ran in, or the cell a line sits in — the second line of
  /// the row header, and null when there is nothing to qualify.
  final String? qualifier;

  /// By month. A month the row has no capacity in is absent rather than zero:
  /// a station that did not exist yet and a station asked for nothing are
  /// different facts, and only one of them is a finding.
  final Map<DateTime, OccupationCell> cells;

  /// This row across every month shown — the frozen TOTAL column (#14).
  ///
  /// **A ratio of sums, never a mean of ratios.** Averaging the monthly
  /// percentages would weight a 400 h month exactly like a 9,000 h one, and on
  /// the live database those months sit side by side: 3,296 h of capacity in
  /// October against 9,384 h in July. `OccupationPivot.total` already computes
  /// its figure this way and is the precedent.
  ///
  /// Under the Hours and Gap units the same sums are simply read differently,
  /// so one total serves all three.
  OccupationCell get total {
    var asked = Duration.zero;
    var open = Duration.zero;
    var filtered = Duration.zero;
    var process = Duration.zero;
    var rework = Duration.zero;
    var changeover = Duration.zero;
    for (final cell in cells.values) {
      asked += cell.asked;
      open += cell.open;
      filtered += cell.filtered;
      process += cell.process;
      rework += cell.rework;
      changeover += cell.changeover;
    }
    return OccupationCell(
      asked: asked,
      open: open,
      filtered: filtered,
      process: process,
      rework: rework,
      changeover: changeover,
    );
  }

  /// The worst month this row had, for the sort the grid arrives on.
  double? get peak {
    double? worst;
    for (final cell in cells.values) {
      final value = cell.ratio;
      if (value == null) continue;
      if (worst == null || value > worst) worst = value;
    }
    return worst;
  }
}

/// One cell: what was asked of a station in a month, and what it had.
class OccupationCell {
  const OccupationCell({
    required this.asked,
    required this.open,
    required this.filtered,
    this.process = Duration.zero,
    this.rework = Duration.zero,
    this.changeover = Duration.zero,
  });

  /// **Everyone's demand**, never the filtered line's own share.
  ///
  /// A structural filter chooses which stations are in view; it does not shrink
  /// what a machine was asked for. Filtered to one line, CLAD04 still reads
  /// 99 % because another line is also on it — which is the difference between
  /// *"this station is full"* and *"my orders fill this station"*, and only the
  /// first is a capacity finding.
  final Duration asked;

  final Duration open;

  /// What the kept orders' demand is made of — the same three segments the
  /// chart stacks (#14).
  ///
  /// **They sum to [filtered], not to [asked].** The split is only knowable for
  /// orders the filter kept; what an order-level filter excluded is a lump, the
  /// grey segment on the chart, and is [asked] minus [filtered].
  final Duration process;
  final Duration rework;
  final Duration changeover;

  /// Demand here from orders an order-level filter excluded.
  Duration get outside => asked - filtered;

  /// How much of [asked] belongs to the orders an **order-level** filter kept.
  ///
  /// Equal to [asked] when nothing order-level is set. This is what lets the
  /// cell tell *"CEU27 is at 100 % and 80 of it is yours"* — reschedule — from
  /// *"CEU32 is at 147 % and none of it is yours"* — escalate. Same colour,
  /// opposite action, and the chart this replaces had nothing that said which.
  final Duration filtered;

  /// Asked over open, or null where the station had no open time at all.
  double? get ratio =>
      open == Duration.zero ? null : asked.inSeconds / open.inSeconds;

  /// The filtered orders' share of this cell, for the fill along its base.
  double get share =>
      asked == Duration.zero ? 0 : filtered.inSeconds / asked.inSeconds;

  /// Open minus asked. Negative is over.
  Duration get gap => open - asked;
}

/// The grid: its rows, its months, and the plant's own row.
class OccupationGrid {
  const OccupationGrid({
    required this.months,
    required this.rows,
    required this.total,
  });

  /// Every month the run spans at the stations in view, whether or not anything
  /// arrived in one: a quiet month is a fact about the plan and a gap in the
  /// axis would hide it.
  final List<DateTime> months;

  final List<OccupationRow> rows;

  /// Every station in view as one row, drawn along the bottom (#14).
  ///
  /// **Always present, which it was not.** This was `plant`, and it went null
  /// the moment any filter narrowed the station set, because #9 judged *"a
  /// partial total wearing the plant's name"* worse than no row at all.
  /// Renaming it **TOTAL** dissolved that objection rather than answering it: a
  /// total claims only the rows above it, which is true under every filter —
  /// and a narrowed view is exactly when a reader wants one.
  final OccupationRow total;
}

/// Builds the grid from a stored run.
///
/// **Returns null on a run that cannot answer**, rather than an empty grid: a
/// run made before v25 carries no monthly capacity, and §10.2 is explicit that
/// inventing it from today's schedules would draw a 2025 capacity out of a plant
/// retuned in 2026. 144 of 147 stored runs are in this state, so the message is
/// the common case rather than the edge.
OccupationGrid? occupationGrid({
  required StoredRun run,
  RunFilter filter = const RunFilter(),
  OccupationGrouping grouping = OccupationGrouping.workcenter,
  PeriodGranularity granularity = PeriodGranularity.month,
  /// What to call the bucket for stations carrying no type, under
  /// [OccupationGrouping.type]. Passed in rather than composed here because
  /// this file is pure and the label is one of three locales' — the same reason
  /// the line rows take their names from the run rather than from the plant.
  String untypedLabel = 'Untyped',
}) {
  final monthly = run.result.openByWorkcenterMonth;
  if (monthly.isEmpty) return null;

  final stations = {
    for (final row in run.metrics.workcenters) row.workcenterId: row,
  };

  // **One station resolution, shared with the chart** — see
  // `stationsInView`. It lives in `run_filter.dart` because it is filter
  // semantics, and because computing it in two places is how the study filter
  // came to be applied in neither.
  final inView = stationsInView(run, filter);
  if (inView.isEmpty) return null;

  // The orders an **order-level** filter keeps, taken through `filterRun` so
  // the grid and every table beside it cannot disagree about which orders are in
  // the slice. Structural filters are stripped out of this: they choose the
  // station set, and letting them shrink the demand as well is exactly the
  // mistake #9 rejected — no single line is ever over 100 %, so the view would
  // stop finding overloads the moment anyone filtered.
  final kept = {
    for (final outcome in filterRun(
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

  // **The period filter stays monthly, and the fold happens after it** (#17).
  // Folding first would drop a quarter whose first day falls before the range —
  // ask for February onward while reading quarters and Q1 would vanish, taking
  // February and March with it. A period is in view when *any* of its months
  // is, which is what filtering the months and then bucketing them means.
  final keptMonths = <DateTime>{
    for (final id in inView) ...?monthly[id]?.keys,
  }.where(filter.includesDate).toSet();
  if (keptMonths.isEmpty) return null;

  final months = keptMonths.map(granularity.startOf).toSet().toList()..sort();

  // **Capacity is the sum of the months in each period, never a mean of their
  // ratios** — #14's arithmetic for the TOTAL column, for its reason: averaging
  // three monthly percentages would weight a 733 h month like a 499 h one.
  final capacityByStation = <String, Map<DateTime, Duration>>{
    for (final entry in monthly.entries)
      entry.key: {
        for (final month in entry.value.entries)
          if (keptMonths.contains(month.key))
            granularity.startOf(month.key): Duration.zero,
      },
  };
  for (final entry in monthly.entries) {
    final folded = capacityByStation[entry.key]!;
    for (final month in entry.value.entries) {
      if (!keptMonths.contains(month.key)) continue;
      folded.update(granularity.startOf(month.key), (had) => had + month.value);
    }
  }

  // Demand per station per month, and the filtered share of it.
  final asked = <String, Map<DateTime, Duration>>{};
  final mine = <String, Map<DateTime, Duration>>{};
  // The kept orders' demand broken into the chart's three segments, so the
  // grid's hover can say the same things the chart's does (#14).
  final mineProcess = <String, Map<DateTime, Duration>>{};
  final mineRework = <String, Map<DateTime, Duration>>{};
  final mineChangeover = <String, Map<DateTime, Duration>>{};

  for (final step in run.result.steps) {
    if (!inView.contains(step.workcenterId)) continue;
    if (!keptMonths.contains(
      DateTime(step.queueStart.year, step.queueStart.month),
    )) {
      continue;
    }
    final month = granularity.startOf(step.queueStart);

    final total = step.processSeconds;
    if (total == null) continue;
    final work =
        Duration(seconds: total) +
        Duration(seconds: step.changeoverSeconds ?? 0);

    (asked[step.workcenterId] ??= {}).update(
      month,
      (had) => had + work,
      ifAbsent: () => work,
    );
    if (kept.contains(step.orderId)) {
      (mine[step.workcenterId] ??= {}).update(
        month,
        (had) => had + work,
        ifAbsent: () => work,
      );

      // **A run with no rework column keeps its whole time as process**, rather
      // than being skipped the way the chart skips it: the grid already counts
      // this step in `asked`, so dropping it here would make the segments
      // disagree with the number they are supposed to explain.
      final before = step.processSecondsBeforeRework ?? total;
      void add(Map<String, Map<DateTime, Duration>> into, int seconds) {
        if (seconds <= 0) return;
        (into[step.workcenterId] ??= {}).update(
          month,
          (had) => had + Duration(seconds: seconds),
          ifAbsent: () => Duration(seconds: seconds),
        );
      }

      add(mineProcess, before);
      add(mineRework, total - before);
      add(mineChangeover, step.changeoverSeconds ?? 0);
    }
  }

  OccupationCell cellFor(Iterable<String> ids, DateTime month) {
    var open = Duration.zero;
    var demand = Duration.zero;
    var filtered = Duration.zero;
    var process = Duration.zero;
    var rework = Duration.zero;
    var changeover = Duration.zero;
    for (final id in ids) {
      open += capacityByStation[id]?[month] ?? Duration.zero;
      demand += asked[id]?[month] ?? Duration.zero;
      filtered += mine[id]?[month] ?? Duration.zero;
      process += mineProcess[id]?[month] ?? Duration.zero;
      rework += mineRework[id]?[month] ?? Duration.zero;
      changeover += mineChangeover[id]?[month] ?? Duration.zero;
    }
    return OccupationCell(
      asked: demand,
      open: open,
      filtered: filtered,
      process: process,
      rework: rework,
      changeover: changeover,
    );
  }

  Map<DateTime, OccupationCell> cellsFor(Iterable<String> ids) => {
    for (final month in months)
      if (cellFor(ids, month) case final cell when cell.open > Duration.zero)
        month: cell,
  };

  final rows = <OccupationRow>[];
  switch (grouping) {
    case OccupationGrouping.workcenter:
      for (final id in inView) {
        final station = stations[id];
        rows.add(
          OccupationRow(
            id: id,
            name: station?.name ?? id,
            qualifier: station?.poolName,
            cells: cellsFor([id]),
          ),
        );
      }
      // Worst first: the row a reader came for is the one at the top, and #10's
      // rule leaves the grid sortable from there.
      rows.sort((a, b) {
        final byPeak = (b.peak ?? -1).compareTo(a.peak ?? -1);
        return byPeak != 0 ? byPeak : a.name.compareTo(b.name);
      });

    case OccupationGrouping.line:
      // Which stations each line's studies actually touched. A line depends on
      // a station if any of its orders visited it — read from the run rather
      // than from the plant, which may have been rearranged since (§7.10).
      final lineOf = {
        for (final study in run.studies)
          study.studyId: (
            id: study.productionLineId ?? study.studyId,
            name: study.productionLineName ?? study.name,
            cell: study.productionCellName,
          ),
      };
      final touched = <String, Set<String>>{};
      for (final step in run.result.steps) {
        if (!inView.contains(step.workcenterId)) continue;
        final line = lineOf[step.studyId];
        if (line == null) continue;
        (touched[line.id] ??= {}).add(step.workcenterId);
      }
      final seen = <String>{};
      for (final study in run.studies) {
        final line = lineOf[study.studyId]!;
        if (!seen.add(line.id)) continue;
        final ids = touched[line.id];
        if (ids == null || ids.isEmpty) continue;
        rows.add(
          OccupationRow(
            id: line.id,
            name: line.name,
            qualifier: line.cell,
            cells: cellsFor(ids),
          ),
        );
      }
      rows.sort((a, b) {
        final byPeak = (b.peak ?? -1).compareTo(a.peak ?? -1);
        return byPeak != 0 ? byPeak : a.name.compareTo(b.name);
      });

    case OccupationGrouping.type:
      // **The station's own type, not the run's steps.** A machine belongs to a
      // type whether or not anything ran on it, so a scheduled station the run
      // never touched is in its type's row carrying capacity and no demand —
      // which is the question this grouping answers.
      //
      // The type is read from the stored run (§7.10), so a station retyped
      // since still groups as it did when it ran.
      final byType = <String, ({String name, Set<String> ids})>{};
      for (final id in inView) {
        final station = stations[id];
        // A run stored before a station was typed carries a null here. It gets
        // its own bucket rather than being dropped: the rows partition the
        // stations in view, and a row silently missing from that partition is
        // a TOTAL that does not add up — the fault #14 spent its argument on.
        final key = station?.typeId ?? '';
        final name = station?.typeName ?? untypedLabel;
        (byType[key] ??= (name: name, ids: <String>{})).ids.add(id);
      }
      for (final entry in byType.entries) {
        rows.add(
          OccupationRow(
            id: entry.key,
            name: entry.value.name,
            // **No qualifier, so the rows stay 40 pt.** The count and the idle
            // ones would go here; see the enum.
            qualifier: null,
            cells: cellsFor(entry.value.ids),
          ),
        );
      }
      rows.sort((a, b) {
        final byPeak = (b.peak ?? -1).compareTo(a.peak ?? -1);
        return byPeak != 0 ? byPeak : a.name.compareTo(b.name);
      });
  }

  return OccupationGrid(
    months: months,
    rows: rows,
    // Every station in view, under every filter (#14).
    total: OccupationRow(
      id: '',
      name: '',
      qualifier: null,
      cells: cellsFor(inView),
    ),
  );
}
