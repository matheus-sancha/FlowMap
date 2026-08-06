import 'package:drift/drift.dart';

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

    // Queue disciplines, keyed by target — a workcenter or a pool (§7.4).
    // Loaded whole rather than per station: it is one small table per project,
    // and resolving a pool's rule needs to see rules the loop below has not
    // reached yet.
    final dispatchByTarget = await loadDispatchRules(projectId);

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
        // Flattened onto the member here, once, so the engine never has to ask
        // which of a step's targets a freeing machine belongs to.
        dispatch: resolveDispatch(
          workcenterId: id,
          byTarget: dispatchByTarget,
          poolMembers: poolMembers,
        ),
      );
    }

    final pools = await (_db.select(
      _db.workcenterPools,
    )..where((p) => p.plantId.equals(project.plantId))).get();

    // A takt in days means productive days of a station (§6.1), so resolving
    // one into a duration needs each station's own open time. Read at the
    // run's start, once: §18.3 leaves mid-flight takt changes open, and a run
    // keeps one cadence throughout.
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
      );
    }

    // Assembled twice, deliberately. §7.2 resolves the takt at the run's
    // start, and the run's start is the first order's need date minus its
    // theoretical lead time (§7.8) — which cannot be walked until the study
    // has been assembled. So the first pass uses the need date itself, the
    // plan it produces gives the real start, and the second pass resolves the
    // takt there. There is no third: chasing a fixed point is exactly the
    // mid-flight takt change §18.3 has not settled, and a run keeps one
    // cadence throughout.
    final first = assembleAt(null);
    if (!first.canRun) return first;

    final start = planRun(
      studies: first.studies,
      workcenters: workcenters,
    ).start;
    return start == null ? first : assembleAt(start);
  }

  // --- Queue disciplines (§7.4) --------------------------------------------

  /// This project's per-station rules, by target id — a workcenter or a pool.
  ///
  /// **Only the overrides.** A station following the run's rule has no row, so
  /// an absent key is the answer rather than a value to compare against a
  /// default; that is what keeps "never touched" and "deliberately set back to
  /// FIFO" different states.
  Future<Map<String, DispatchRule>> loadDispatchRules(String projectId) async {
    final rows = await (_db.select(
      _db.workcenterDispatch,
    )..where((d) => d.projectId.equals(projectId))).get();
    return {for (final row in rows) row.targetId: row.rule};
  }

  Stream<Map<String, DispatchRule>> watchDispatchRules(String projectId) =>
      (_db.select(
        _db.workcenterDispatch,
      )..where((d) => d.projectId.equals(projectId))).watch().map(
        (rows) => {for (final row in rows) row.targetId: row.rule},
      );

  /// Sets or clears one station's rule.
  ///
  /// A null [rule] deletes the row rather than storing the run's current
  /// default, so "follow the run" keeps following it when the run's rule is
  /// changed afterwards. Storing the default instead would silently pin every
  /// station the first time one was edited.
  Future<void> setDispatchRule({
    required String projectId,
    required String targetId,
    required DispatchRule? rule,
  }) async {
    if (rule == null) {
      await (_db.delete(_db.workcenterDispatch)..where(
        (d) => d.projectId.equals(projectId) & d.targetId.equals(targetId),
      )).go();
      return;
    }
    await _db
        .into(_db.workcenterDispatch)
        .insertOnConflictUpdate(
          WorkcenterDispatchCompanion.insert(
            projectId: projectId,
            targetId: targetId,
            rule: rule,
            updatedAt: DateTime.now(),
          ),
        );
  }
}

/// One study's demand and cadence, read once per assembly.
typedef _StudyDemand = ({
  List<DemandPart> parts,
  List<DemandOrder> orders,
  Map<String, Map<String, Duration>> processTimes,
  TaktScheduleSpec takt,
});
