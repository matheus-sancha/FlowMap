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
import 'sim_model.dart' show StationPool;
import 'sim_result.dart';

/// Which slice is being read. Every field null or empty is the whole run.
class RunFilter {
  const RunFilter({
    this.studyIds = const {},
    this.cellIds = const {},
    this.lineIds = const {},
    this.customerProjects = const {},
    this.partNumbers = const {},
    this.orderNumbers = const {},
    this.typeIds = const {},
    this.workcenterIds = const {},
    this.from,
    this.to,
  });

  /// One study, for its own Simulation tab.
  RunFilter.study(String studyId) : this(studyIds: {studyId});

  /// What [customerProjects] holds for *no* project.
  ///
  /// 11 % of the live database's orders have none, so "orders not booked to a
  /// project" is a slice a planner can legitimately want — and offering the
  /// eighteen real names while silently dropping those orders from every one of
  /// them would be a filter that hides a ninth of the run without saying so.
  /// The empty string, because a project named `''` cannot exist: the column is
  /// either null or something a user typed.
  static const noProject = '';

  final Set<String> studyIds;

  /// **A cell or line filter is a study filter one level up.** Workcenters
  /// belong to a plant rather than to a cell (§7.10), so stations are never
  /// narrowed this way — the studies are, and their stations follow.
  final Set<String> cellIds;
  final Set<String> lineIds;

  /// The customer project the order is for — `MANIFOLD`, `Global 23` (§7.5).
  ///
  /// **The order's, not the part's** (§16.15), and therefore read off the run's
  /// plan rather than off its metrics: the plan is the only projection that
  /// carries it. [noProject] stands for the orders that have none.
  final Set<String> customerProjects;

  /// Part numbers, as the run recorded them.
  ///
  /// **Read from the metrics, not from the plan**, for the reason the part-name
  /// mapping below already is: the metrics always carry it and the plan is a
  /// projection this file should not depend on twice over.
  final Set<String> partNumbers;

  /// Positions in a study's release sequence, 1-based — the `Order` column.
  ///
  /// **One number can name several orders, and that is intended.** The sequence
  /// is dense *per study* (§16.15), so on a two-study run `5` is order five of
  /// each, and every 190-order run in the live database has each number twice.
  /// Narrowing to one is what combining this with [studyIds] is for; the surface
  /// offering it has to say so rather than implying it found one thing.
  final Set<int> orderNumbers;

  /// **The two station filters** — workcenter type, and individual stations
  /// (#9, absorbed from `OccupationStations`).
  ///
  /// **A different class of filter from everything above, and the Occupation
  /// grid is what made the difference matter.** The filters above are
  /// *order-level*: they choose whose demand is counted, and a station's
  /// capacity is untouched by them. These two are **structural** — they choose
  /// which stations are in view at all, so demand and capacity move together
  /// and a cell still reads *everyone's* demand at that station over that
  /// station's full capacity.
  ///
  /// So filtering to one line leaves CLAD04 at 99 % rather than dropping it to
  /// that line's own share: **a filter chooses what you look at; it never
  /// shrinks what a machine was asked for.** *Rejected: narrowing demand to the
  /// filtered line's orders* — no single line is ever over 100 %, so the view
  /// would stop finding overloads the moment anyone filtered, which is how the
  /// chart it replaces got into that state.
  ///
  /// `studyIds`, `cellIds` and `lineIds` are structural too, one level up: they
  /// choose studies, and a study's stations follow.
  ///
  /// **They reach every surface whose rows are stations** — the Gantt's Y axis
  /// *is* the workcenter, and the Overview's queue and share tables are keyed on
  /// workcenters. The production plan and the float matrix are per-order and
  /// per-part, so they ignore these, exactly as §12.1's whole-run caveat already
  /// handles figures a filter cannot reach.
  final Set<String> typeIds;
  final Set<String> workcenterIds;

  /// Whether this filter names particular stations, so a total across them
  /// cannot wear the plant's name (#9).
  bool get narrowsStations =>
      typeIds.isNotEmpty ||
      workcenterIds.isNotEmpty ||
      studyIds.isNotEmpty ||
      cellIds.isNotEmpty ||
      lineIds.isNotEmpty;

  /// Whether [workcenterId] of [typeId] survives the two station filters.
  ///
  /// Empty means every station, including one with no type at all — a type
  /// filter that silently dropped untyped stations would be a filter nobody
  /// asked for.
  bool includesStation({required String workcenterId, String? typeId}) {
    if (workcenterIds.isNotEmpty && !workcenterIds.contains(workcenterId)) {
      return false;
    }
    if (typeIds.isNotEmpty && (typeId == null || !typeIds.contains(typeId))) {
      return false;
    }
    return true;
  }

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
      customerProjects.isEmpty &&
      partNumbers.isEmpty &&
      orderNumbers.isEmpty &&
      typeIds.isEmpty &&
      workcenterIds.isEmpty &&
      from == null &&
      to == null;

  /// Whether orders are dropped for a reason that is not their study.
  ///
  /// The period was the only such reason until §7.5; the three below narrow
  /// **within** a study exactly as it does, so a slice can now hold some of a
  /// study's orders rather than all or none of them.
  bool get narrowsOrders =>
      from != null ||
      to != null ||
      customerProjects.isNotEmpty ||
      partNumbers.isNotEmpty ||
      orderNumbers.isNotEmpty;

  bool includesDate(DateTime date) {
    if (from != null && date.isBefore(from!)) return false;
    if (to != null && date.isAfter(to!)) return false;
    return true;
  }
}

/// Every month the run holds anything for, ascending — the slicer's stops.
///
/// **The union of two spans, and it has to be** (#17). Need dates and monthly
/// capacity do not cover the same months: on the live database the widest run's
/// orders run December 2025 to December 2026 while its capacity runs October
/// 2025 to December 2026, so taking need dates alone would put two months of
/// real capacity beyond the left end of the slider and make them unreachable on
/// the Occupation grid. Taking capacity alone fails the other way on a run made
/// before v25, which has none.
///
/// Empty only when the run has neither, which is a run with no orders.
List<DateTime> runMonths(StoredRun run) {
  final months = <DateTime>{
    for (final outcome in run.result.orders)
      DateTime(outcome.needDate.year, outcome.needDate.month),
    for (final byMonth in run.result.openByWorkcenterMonth.values)
      for (final month in byMonth.keys) DateTime(month.year, month.month),
  }.toList()..sort();
  return months;
}

/// A stored run as one slice of it reads.
class FilteredRun {
  FilteredRun({
    required this.run,
    required this.filter,
    required this.studyIds,
    required this.result,
    required this.metrics,
    required this.plan,
    required this.stationsAreWholeRun,
  }) : signature = _signatureOf(run, filter, studyIds);

  final StoredRun run;
  final RunFilter filter;

  /// The studies the filter resolved to, after cells and lines were applied.
  final Set<String> studyIds;

  /// Orders, steps and lane visits of those studies, inside the period.
  final SimRunResult result;

  /// Order-level figures for the slice; **station-level figures for the whole
  /// run**, because the run does not carry what a windowed denominator needs.
  final RunMetrics metrics;

  final List<PlanEntry> plan;

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
  ///
  /// **Computed when the slice is taken, not read back through the filter.** It
  /// was a getter, and the filter bar keeps one long-lived `Set` per control and
  /// mutates it in place — so a slice taken before an edit saw the edit through
  /// its own filter, and recomputed to the value of the slice that replaced it.
  /// A cache comparing old against new therefore found them equal and kept its
  /// old answer: the Gantt went on drawing the slice before last while every
  /// table beside it moved.
  ///
  /// Only the study segment escaped, because [studyIds] is built fresh by
  /// [filterRun] rather than read through — which is why the three §7.5 filters
  /// appeared to work *only* when a study filter was also touched.
  ///
  /// A snapshot's identity has to be fixed at the moment the snapshot is taken;
  /// anything else is not a snapshot. Stored rather than trusting every caller
  /// to hand over sets it will not touch again.
  final String signature;

  static String _signatureOf(
    StoredRun run,
    RunFilter filter,
    Set<String> studyIds,
  ) =>
      '${run.id}|${(studyIds.toList()..sort()).join(',')}'
      '|${filter.from?.millisecondsSinceEpoch}|${filter.to?.millisecondsSinceEpoch}'
      // §7.5's three, or a chart would keep drawing the slice before last on
      // every filter that narrows within a study rather than across studies.
      '|${(filter.customerProjects.toList()..sort()).join(',')}'
      '|${(filter.partNumbers.toList()..sort()).join(',')}'
      '|${(filter.orderNumbers.toList()..sort()).join(',')}'
      // **And #9's two**, for the same reason and with the same failure if they
      // are left out: `GanttView.didUpdateWidget` compares this string, so a
      // station filter missing from it would narrow every table on the page and
      // leave the chart drawing the plant it drew before. That is precisely the
      // defect §7.5's three were added to fix, one round later.
      '|${(filter.typeIds.toList()..sort()).join(',')}'
      '|${(filter.workcenterIds.toList()..sort()).join(',')}';
}

/// What each of the filter bar's pickers should offer, given what the others
/// have already narrowed to (§7.6).
///
/// Every map is `value → label`, sorted by label, ready to be a menu.
class RunFilterOptions {
  const RunFilterOptions({
    this.studies = const {},
    this.cells = const {},
    this.lines = const {},
    this.projects = const {},
    this.parts = const {},
    this.types = const {},
    this.workcenters = const {},
    this.studiesInView = 0,
  });

  final Map<String, String> studies;
  final Map<String, String> cells;
  final Map<String, String> lines;

  /// Keyed by the project name, or [RunFilter.noProject] for the orders that
  /// have none — offered only when the slice actually contains such an order.
  final Map<String, String> projects;

  final Map<String, String> parts;

  /// **The stations, offered from the run rather than from the plant** (#9) —
  /// the same rule as the cells and lines, and for the same reason: a menu
  /// listing every workcenter in the plant would be mostly entries that select
  /// nothing.
  ///
  /// Unlike every other facet, these are read off the run's **stations** rather
  /// than its orders: a station the run recorded is a station the run used,
  /// whether or not an order survives the other filters. Narrowing them by the
  /// order-level filters would empty the station menu whenever a part filter
  /// happened to exclude that machine — which is a picker that hides the
  /// stations you are trying to look at.
  final Map<String, String> types;
  final Map<String, String> workcenters;

  /// How many studies the other filters leave in view, which is how many orders
  /// one order number names.
  final int studiesInView;
}

/// The options every picker should show for [run] under [filter].
///
/// **A picker offers what could still narrow what you are looking at.** Two
/// complaints from the field are one rule: the Cells and Lines menus listed
/// every cell and line in the *plant*, including those no study has ever used,
/// so most entries selected nothing; and choosing a study left the Part numbers
/// menu offering parts that study never makes. Both are a menu describing
/// something other than the thing on screen.
///
/// **Read off the run, not off the plant.** §7.10 records each study's cell and
/// line on the run precisely so a filter keeps working after the plant is
/// re-organised, and the run's studies are by definition the ones that have a
/// simulation. Before a run exists every menu is empty, which is honest: the
/// pane below says nothing has been run, and there is nothing to filter.
///
/// **Each picker ignores its own selection and honours every other.** That is
/// what keeps a multi-select usable — ticking `MANIFOLD` must not make
/// `Global 23` vanish from the menu it was ticked in — while still letting a
/// study narrow the parts beside it. It is the standard faceted-search rule, and
/// the alternative was tried in the head and discarded: options narrowed by
/// *all* filters leave every menu holding exactly what is already ticked.
///
/// Computed in one pass over the orders rather than by calling [filterRun] once
/// per picker: this runs on every keystroke of the filter bar, and [filterRun]
/// re-summarises the whole run.
RunFilterOptions runFilterOptions(StoredRun? run, RunFilter filter) {
  if (run == null) return const RunFilterOptions();

  final studyOf = {for (final s in run.studies) s.studyId: s};
  final partNumberOf = {
    for (final part in run.metrics.parts) part.partId: part.partNumber,
  };
  final projectOf = {
    for (final entry in run.plan)
      if (entry case ProductionPlanRow(:final outcome, :final customerProject))
        outcome.orderId: customerProject,
  };

  final studies = <String, String>{};
  final cells = <String, String>{};
  final lines = <String, String>{};
  final projects = <String, String>{};
  final parts = <String, String>{};
  final inView = <String>{};

  for (final outcome in run.result.orders) {
    final study = studyOf[outcome.studyId];
    final project = projectOf[outcome.orderId] ?? RunFilter.noProject;
    final part = partNumberOf[outcome.partId];

    final byStudy =
        filter.studyIds.isEmpty || filter.studyIds.contains(outcome.studyId);
    final byCell =
        filter.cellIds.isEmpty ||
        filter.cellIds.contains(study?.productionCellId);
    final byLine =
        filter.lineIds.isEmpty ||
        filter.lineIds.contains(study?.productionLineId);
    final byDate = filter.includesDate(outcome.needDate);
    final byProject =
        filter.customerProjects.isEmpty ||
        filter.customerProjects.contains(project);
    final byPart =
        filter.partNumbers.isEmpty || filter.partNumbers.contains(part);
    final byOrder =
        filter.orderNumbers.isEmpty ||
        filter.orderNumbers.contains(outcome.sequence + 1);

    // Everything except the facet being offered.
    final others = byDate && byProject && byPart && byOrder;
    final place = byStudy && byCell && byLine;

    if (others && byCell && byLine && study != null) {
      studies[outcome.studyId] = study.name;
    }
    if (others && byStudy && byLine) {
      if (study?.productionCellId case final id?) {
        cells[id] = study?.productionCellName ?? id;
      }
    }
    if (others && byStudy && byCell) {
      if (study?.productionLineId case final id?) {
        lines[id] = study?.productionLineName ?? id;
      }
    }
    if (place && byDate && byPart && byOrder) projects[project] = project;
    if (place && byDate && byProject && byOrder && part != null) {
      parts[part] = part;
    }
    if (place && others) inView.add(outcome.studyId);
  }

  Map<String, String> sorted(Map<String, String> by) =>
      Map.fromEntries(
        by.entries.toList()..sort((a, b) => a.value.compareTo(b.value)),
      );

  // The run's own stations, each offered when the *other* station filter does
  // not exclude it — the same ignore-your-own-facet rule the pickers above use.
  final types = <String, String>{};
  final workcenters = <String, String>{};
  for (final station in run.metrics.workcenters) {
    final byType =
        filter.typeIds.isEmpty || filter.typeIds.contains(station.typeId);
    final byStation =
        filter.workcenterIds.isEmpty ||
        filter.workcenterIds.contains(station.workcenterId);
    if (byStation) {
      if (station.typeId case final id? when station.typeName != null) {
        types[id] = station.typeName!;
      }
    }
    if (byType) workcenters[station.workcenterId] = station.name;
  }

  return RunFilterOptions(
    studies: sorted(studies),
    cells: sorted(cells),
    lines: sorted(lines),
    types: sorted(types),
    workcenters: sorted(workcenters),
    // `(no project)` keeps its sentinel key and takes its label from the view,
    // so it sorts first rather than under whatever it is called in Portuguese.
    projects: sorted(projects),
    parts: sorted(parts),
    studiesInView: inView.length,
  );
}

/// The stations a run shows under [filter] — **the one station resolution**,
/// shared by the Occupation chart and the Occupation grid (#9).
///
/// **All five structural filters, and studies reach it through their steps.**
/// `typeIds` and `workcenterIds` name stations directly. `studyIds`, `cellIds`
/// and `lineIds` name *studies*, and a study narrows the station set to the
/// stations it actually visited in this run — read off the steps rather than the
/// flow, because a station a study routes through but never used has no demand
/// and no reason to be a row.
///
/// **This exists because it was got wrong once.** The grid applied only the two
/// direct filters and a comment claimed the other three were handled elsewhere;
/// they were handled nowhere, so choosing a study narrowed every other surface
/// on the page and left the grid drawing the whole plant. Two callers computing
/// it separately is how that happens twice.
Set<String> stationsInView(StoredRun run, RunFilter filter) {
  final typeOf = {
    for (final row in run.metrics.workcenters) row.workcenterId: row.typeId,
  };

  final narrowsStudies =
      filter.studyIds.isNotEmpty ||
      filter.cellIds.isNotEmpty ||
      filter.lineIds.isNotEmpty;

  final Set<String>? allowedStudies = !narrowsStudies
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

  final Set<String>? studyStations = allowedStudies == null
      ? null
      : {
          for (final step in run.result.steps)
            if (allowedStudies.contains(step.studyId)) step.workcenterId,
        };

  return {
    for (final id in run.result.openByWorkcenterMonth.keys)
      if (filter.includesStation(workcenterId: id, typeId: typeOf[id]) &&
          (studyStations == null || studyStations.contains(id)))
        id,
  };
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

  // **Two sources, and the split is deliberate.** A part number is on the
  // metrics, which every run has; the customer project is on the plan, which is
  // the only projection carrying it (§7.5). Both are built once here rather than
  // searched per order — a §14-scale run is 2000 orders and this is called on
  // every keystroke of the filter bar.
  final partNumberOf = {
    for (final part in run.metrics.parts) part.partId: part.partNumber,
  };
  final projectOf = {
    for (final entry in run.plan)
      if (entry case ProductionPlanRow(:final outcome, :final customerProject))
        outcome.orderId: customerProject,
  };

  bool keepsProject(SimOrderOutcome outcome) {
    if (filter.customerProjects.isEmpty) return true;
    // **An order the plan cannot answer for is treated as having none**, which
    // is the same answer a stored-before-v12 run gives for every order — so a
    // project filter on such a run selects nothing rather than everything, and
    // `(none)` selects all of it. Both readings are true; neither invents a
    // project the run never recorded.
    final project = projectOf[outcome.orderId] ?? RunFilter.noProject;
    return filter.customerProjects.contains(project);
  }

  bool keepsPart(SimOrderOutcome outcome) =>
      filter.partNumbers.isEmpty ||
      filter.partNumbers.contains(partNumberOf[outcome.partId]);

  // 1-based, as `ProductionPlanRow.orderNumber` and the demand grid's row
  // header are, so the number typed is the number read off the screen.
  bool keepsOrderNumber(SimOrderOutcome outcome) =>
      filter.orderNumbers.isEmpty ||
      filter.orderNumbers.contains(outcome.sequence + 1);

  bool keepsOrder(SimOrderOutcome outcome) =>
      keepsStudy(outcome.studyId) &&
      filter.includesDate(outcome.needDate) &&
      keepsProject(outcome) &&
      keepsPart(outcome) &&
      keepsOrderNumber(outcome);

  final orders = run.result.orders.where(keepsOrder).toList();
  final keptOrderIds = {for (final outcome in orders) outcome.orderId};

  // **And the station filters narrow the steps** (#9). Every surface whose rows
  // are stations reads them from here — the Gantt's Y axis *is* the workcenter,
  // and the Overview's queue and share tables are keyed on workcenters — so
  // narrowing the steps is what makes one picker govern all of them. The
  // production plan and the float matrix are per-order and per-part and so are
  // untouched, exactly as §12.1's whole-run caveat already handles figures a
  // filter cannot reach.
  //
  // **A station filter drops steps, never orders.** An order that visits CLAD06
  // and CEU27 keeps both its outcome and its float when the view narrows to
  // CLAD06; only its CEU27 bar leaves. Dropping the order instead would make a
  // station filter silently an order filter, which is the mistake #9 rejected
  // one level up.
  final stationTypeOf = {
    for (final station in run.metrics.workcenters)
      station.workcenterId: station.typeId,
  };
  final steps = [
    for (final step in run.result.steps)
      if (keptOrderIds.contains(step.orderId) &&
          filter.includesStation(
            workcenterId: step.workcenterId,
            typeId: stationTypeOf[step.workcenterId],
          ))
        step,
  ];

  // **Which queues the slice still stands in, read off the steps that survived.**
  //
  // This was `keepsStudy(lane.studyId)`, which stopped being right when v19 made
  // a queue belong to the station it stands in front of rather than to a study
  // (§7.3). One row is written per *target* now, and the study on it is whichever
  // study happened to be written last — so on the real run eight of ten lanes
  // carry one study's id and two carry the other's, and filtering to either
  // study dropped most of the queues. The `CLAD Pool` band vanishing on a
  // one-study view is what the field reported; it was never the pool's problem.
  //
  // A step is the honest source: it records the lane the order actually waited
  // in, which is the same thing `_laneRows` places the band by. So a lane is in
  // the slice exactly when an order in the slice queued there.
  final keptLaneIds = {for (final step in steps) ?step.laneNodeId};

  final result = SimRunResult(
    start: run.result.start,
    end: run.result.end,
    guard: run.result.guard,
    abort: run.result.abort,
    steps: steps,
    orders: orders,
    // **Still only by study and date, and §7.5's three deliberately do not
    // reach them.** An empty slot is a release opportunity nobody took, so it
    // carries a study and an instant and no order at all — there is no part to
    // match, no project it was for and no position in a sequence it never
    // entered. Narrowing them by a part filter would mean inventing which part
    // the slot *would* have carried, and the honest reading is that a study's
    // unused cadence is a fact about the study.
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
        if (keptLaneIds.contains(lane.nodeId)) lane,
    ],
    // By the order, for the reason above one level on: an order the guard caught
    // still standing in a lane leaves no step, so it is not covered by
    // `keptLaneIds` — and one belonging to an order the filter dropped must go
    // with it or a lane would be drawn fuller than the slice it describes.
    openLaneVisits: [
      for (final open in run.result.openLaneVisits)
        if (keptOrderIds.contains(open.orderId)) open,
    ],
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
    // Carried through the slice for the same reason as the names: a filtered
    // view must group its stations exactly as the unfiltered one does, or the
    // two would describe two different plants (§12.1).
    pools: {
      for (final station in run.metrics.workcenters)
        if (station.poolName != null)
          station.workcenterId: StationPool(
            id: station.poolId,
            name: station.poolName!,
          ),
    },
    // The theoretical walk is stored per order on the plan row rather than on
    // the outcome, so it is read from there (§8.5).
    theoreticalByOrder: {
      for (final entry in run.plan)
        if (entry case ProductionPlanRow(
          :final outcome,
          :final theoreticalLeadTime?,
        ) when keptOrderIds.contains(outcome.orderId))
          outcome.orderId: theoreticalLeadTime,
    },
  );

  return FilteredRun(
    run: run,
    filter: filter,
    studyIds: studyIds,
    result: result,
    // **Per column, not per table.** The stations used to be spliced back
    // wholesale from the unfiltered run, on the argument that a busy total for
    // the slice over an open total for the run is a utilisation that means
    // nothing. True of utilisation — and it was applied to five other columns
    // that have no such problem, so "ranked by queue" ranked the whole plant
    // whatever was filtered.
    //
    // The splice was also unnecessary. `result` above carries the run's own
    // `busyByWorkcenter`, `openByWorkcenter` and `blockedByWorkcenter` maps
    // unfiltered, so `summariseRun` already tallies queue, visits and
    // changeovers from the slice's steps while reading utilisation and blocked
    // from the whole run. That is exactly the split wanted; the splice threw it
    // away.
    metrics: sliced,
    plan: <PlanEntry>[
      for (final entry in run.plan)
        // **A slot is kept by its study, an order by its own id.** An empty slot
        // has no part and no order number, so a part or order filter cannot
        // speak about it — narrowing to a part would otherwise silently claim
        // the line never stalled. A study or cell filter is the one that can,
        // and does.
        if (switch (entry) {
          ProductionPlanRow(:final outcome) => keptOrderIds.contains(
            outcome.orderId,
          ),
          PlanEmptySlot(:final studyId) =>
            !filter.narrowsOrders && keepsStudy(studyId),
        })
          entry,
    ],
    stationsAreWholeRun: !filter.isWholeRun,
  );
}
