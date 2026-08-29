import '../../../data/database/database.dart';
import '../../demand/data/demand_repository.dart';
import '../../resources/data/resources_repository.dart';
import '../../schedules/application/takt_schedule.dart';
import '../../schedules/data/schedules_repository.dart';
import '../../studies/data/studies_repository.dart';
import '../application/engine.dart';
import '../application/sim_assembly.dart';
import '../application/sim_model.dart';

/// Gathers a project's run from what is stored (DESIGN.md §7.7).
///
/// The loading half of `sim_assembly.dart`: this reads the rows and builds the
/// calendars, and every decision about what they mean — what a quantity buffer
/// becomes, which station paces the releases, whether a study can run at all —
/// stays in the pure assembler beside it, where it is a unit test rather than a
/// question you answer by pressing Simulate.
///
/// **One resource model of the plant** (§7.7): a workcenter reached by three
/// studies is loaded once and appears once, because that shared use is the
/// contention the run exists to show.
class SimulationRepository {
  SimulationRepository(
    this._db,
    this._resources,
    this._schedules,
    this._studies,
    this._demand,
  );

  final AppDatabase _db;
  final ResourcesRepository _resources;
  final SchedulesRepository _schedules;
  final StudiesRepository _studies;
  final DemandRepository _demand;

  /// Builds the whole run, or says why it cannot be built.
  ///
  /// Returns an input whose [SimRunInput.canRun] is false rather than throwing:
  /// an unbound step is a state the readiness panel reports and deep-links to
  /// (§11), not an exception to surface mid-render.
  Future<SimRunInput> assembleRun(String projectId) async {
    final project = await (_db.select(
      _db.projects,
    )..where((p) => p.id.equals(projectId))).getSingleOrNull();
    if (project == null) return const SimRunInput.empty();

    final flagged = await _studies.loadFlaggedStudies(projectId);
    if (flagged.isEmpty) return const SimRunInput.empty();

    final nodesByStudy = {
      for (final study in flagged) study.id: await _studies.loadNodes(study.id),
    };

    // Every workcenter any flagged study can reach, directly or through a
    // pool — loaded once, so the model contends properly.
    final poolMembers = await _resources.loadPoolMembership(project.plantId);
    final needed = <String>{};
    for (final nodes in nodesByStudy.values) {
      for (final node in nodes) {
        if (node.workcenterId != null) needed.add(node.workcenterId!);
        if (node.poolId != null) {
          needed.addAll(poolMembers[node.poolId] ?? const []);
        }
      }
    }

    final workcenterRows =
        await (_db.select(
          _db.workcenters,
        )..where((w) => w.plantId.equals(project.plantId))).get();
    final byId = {for (final row in workcenterRows) row.id: row};

    final workcenters = <String, SimWorkcenter>{};
    for (final id in needed) {
      final row = byId[id];
      if (row == null) continue;
      final calendar = await _schedules.loadWorkcenterCalendar(
        projectId: projectId,
        workcenterId: id,
      );
      if (calendar == null) continue;
      workcenters[id] = SimWorkcenter(
        id: id,
        name: row.name,
        calendar: calendar,
        schedule: await _schedules.loadWorkcenterSchedule(projectId, id),
        units: row.parallelCapacity,
      );
    }

    // Workcenter → the name of its type, which is the identity §7.4 balances
    // on. By name rather than by id because the balance compares two stations
    // and a name is what a reader would compare them by — and because the type
    // rows are a handful, so the join is one query for the whole plant.
    final typeNames = {
      for (final type in await _db.select(_db.workcenterTypes).get())
        type.id: type.name,
    };
    final workcenterTypeNames = {
      for (final row in workcenterRows) row.id: ?typeNames[row.typeId],
    };

    final pools = await (_db.select(
      _db.workcenterPools,
    )..where((p) => p.plantId.equals(project.plantId))).get();

    // The queue in front of each dispatch target (§5.5). Read whole-project and
    // handed to every study, which is the point: two studies stepping on CLAD07
    // are given the *same* queue, so the engine contends over one floor space
    // rather than one each.
    //
    // A target with no row is an uncapped FIFO — what a shop floor does, and
    // what every lane was before it could say otherwise. The assembler applies
    // that default, so a plant nobody has configured behaves exactly as it did.
    final queues = {
      for (final row in await (_db.select(
        _db.projectQueues,
      )..where((q) => q.projectId.equals(project.id))).get())
        row.targetId: SimQueue(
          targetId: row.targetId,
          name: row.name,
          rule: row.rule ?? DispatchRule.fifo,
          capacity: row.capacity,
          // Raw, for the assembler to resolve against each study's takt.
          stockMode: row.stockMode,
          stockQuantity: row.stockQuantity,
          stockSeconds: row.stockSeconds,
        ),
    };

    // Where each study sits, read once and copied into the run so §12.1's cell
    // and line filters never join back to a plant that may have been
    // rearranged since (§7.10). Whole-plant rather than per-study: there are a
    // handful of each, and two queries beat one per flagged study.
    final cellNames = {
      for (final cell
          in await (_db.select(
            _db.productionCells,
          )..where((c) => c.plantId.equals(project.plantId))).get())
        cell.id: cell.name,
    };
    final lineNames = {
      for (final line in await _db.select(_db.productionLines).get())
        line.id: line.name,
    };

    // A takt in days means productive days of a station (§6.1), so resolving
    // one into a duration needs each station's own open time.
    //
    // **Read at the run's start, once, and that is now the only thing here that
    // is.** §7.9 made the *takt* the order's — every period the line states is
    // resolved and the engine reads the one in force — but a station's own
    // staffing is a second axis and this round did not touch it. A workcenter
    // whose shift pattern changes in July still reports one productive day for
    // the whole run, exactly as it always has, and the takt periods are
    // resolved against that one figure.
    Map<String, Duration> productiveOn(DateTime asOf) => {
      for (final entry in workcenters.entries)
        entry.key:
            entry.value.calendar.openTimePerWorkingDay(asOf) *
            (entry.value.schedule.lookup(asOf).period?.availability ?? 1),
    };

    final demand = <String, _StudyDemand>{};
    for (final study in flagged) {
      demand[study.id] = (
        parts: await _demand.loadParts(study.id),
        orders: await _demand.loadOrders(study.id),
        processTimes: await _demand.loadProcessTimes(study.id),
        takt: await _schedules.loadTaktSchedule(
          projectId,
          study.productionLineId,
        ),
      );
    }

    SimRunInput assembleAt(DateTime? runStart) {
      final assembled = <SimStudy>[];
      final readiness = <StudyReadiness>[];

      for (final study in flagged) {
        final rows = demand[study.id]!;
        final problems = <SimAssemblyProblem>[];
        // The first order of the sequence sets the offset (§7.8), so its need
        // date is the best answer available before a start exists.
        final asOf =
            runStart ?? rows.orders.firstOrNull?.needDate ?? DateTime.now();

        final built = assembleSimStudy(
          study: study,
          nodes: nodesByStudy[study.id] ?? const [],
          parts: rows.parts,
          processTimes: rows.processTimes,
          orders: rows.orders,
          taktSchedule: rows.takt,
          resources: SimResourceContext(
            workcenterNames: {
              for (final entry in workcenters.entries) entry.key: entry.value.name,
            },
            poolNames: {for (final pool in pools) pool.id: pool.name},
            poolMembers: poolMembers,
            productivePerWorkingDay: productiveOn(asOf),
            // Read the same way and at the same instant as the productive day
            // above, so the cap and the charge cannot disagree (§9.8).
            rework: {
              for (final entry in workcenters.entries)
                entry.key:
                    entry.value.schedule.lookup(asOf).period?.rework ?? 0,
            },
            queues: queues,
            cellNames: cellNames,
            lineNames: lineNames,
            workcenterTypeNames: workcenterTypeNames,
          ),
          asOf: asOf,
          problems: problems,
        );

        if (built != null) assembled.add(built);
        readiness.add(
          StudyReadiness(
            studyId: study.id,
            name: study.name,
            problems: problems,
          ),
        );
      }

      return SimRunInput(
        studies: assembled,
        workcenters: workcenters,
        readiness: readiness,
        scheduleHorizon: _horizonOf(
          takts: [for (final study in flagged) demand[study.id]!.takt],
          stations: workcenters.values,
        ),
      );
    }

    // Assembled twice, deliberately, and it survives §7.9 with a smaller job.
    // The run's start is the first order's need date minus its theoretical lead
    // time (§7.8), which cannot be walked until the study has been assembled.
    // So the first pass uses the need date itself and the plan it produces
    // gives the real start.
    //
    // **What the second pass now settles is the staffing and the study's stated
    // takt, not which cadence the run keeps.** The engine reads the takt at
    // each slot from the schedule it was handed, so a run spanning a change no
    // longer depends on this pass to notice. What it still fixes is
    // `productiveOn` and the `taktValue` a study reports as its first
    // release's. There is no third pass: chasing a fixed point across a takt
    // boundary would let two takts argue over one order, which is the
    // mid-flight re-cadencing §18.3 rules out.
    final first = assembleAt(null);
    if (!first.canRun) return first;

    final start = planRun(
      studies: first.studies,
      workcenters: workcenters,
    ).start;
    return start == null ? first : assembleAt(start);
  }
}

/// One study's demand and cadence, read once per assembly.
typedef _StudyDemand = ({
  List<DemandPart> parts,
  List<DemandOrder> orders,
  Map<String, Map<String, Duration>> processTimes,
  TaktScheduleSpec takt,
});

/// The last date every schedule in the run is actually defined for (§11.1).
///
/// **The minimum of each schedule's own last end date**, because past the
/// earliest of them at least one schedule is being carried forward — and a
/// figure is only as defined as the least-defined thing that produced it.
/// Taking the maximum would say the run was covered right up to whichever
/// station happened to have the longest schedule.
///
/// Null when nothing has any periods, which is a state the readiness panel
/// already blocks on: there is no horizon to be past.
DateTime? _horizonOf({
  required Iterable<TaktScheduleSpec> takts,
  required Iterable<SimWorkcenter> stations,
}) {
  DateTime? earliest;
  void consider(Iterable<DateTime> ends) {
    if (ends.isEmpty) return;
    final last = ends.reduce((a, b) => a.isAfter(b) ? a : b);
    if (earliest == null || last.isBefore(earliest!)) earliest = last;
  }

  for (final takt in takts) {
    consider([for (final period in takt.periods) period.endDate]);
  }
  for (final station in stations) {
    consider([for (final period in station.schedule.periods) period.endDate]);
  }
  return earliest;
}
