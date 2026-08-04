import 'package:drift/drift.dart';

import '../../../data/database/database.dart';
import '../application/run_metrics.dart';
import '../application/sim_model.dart';
import '../application/sim_result.dart';

/// Where a run is kept, and what it comes back as (DESIGN.md §7.10).
///
/// A run is written **whole, in one transaction**, and read back as the same
/// [SimRunResult] the engine produced plus the [RunMetrics] it reported at the
/// time. That round trip is the point: everything a report asks later — order
/// Gantts, queue histories, bottleneck evidence, "why was PN2 late" — is a
/// query over these rows rather than another run.
///
/// The snapshot columns (study names, part numbers, station names, each order's
/// theoretical lead time) are what keep that true after the plant beneath the
/// run is edited. Nothing here joins back to a study, a part or a workcenter.
class SimulationRunsRepository {
  SimulationRunsRepository(this._db);

  final AppDatabase _db;

  /// The project's runs, newest first.
  ///
  /// Ties break by id. Dates are stored to the second, the convention the rest
  /// of the schema uses, so two runs made inside one second would otherwise
  /// come back in whatever order the database felt like — and a list that
  /// reorders itself between rebuilds is the kind of thing a user reports as a
  /// bug in the run itself.
  Stream<List<SimulationRun>> watchRuns(String projectId) =>
      (_db.select(_db.simulationRuns)
            ..where((r) => r.projectId.equals(projectId))
            ..orderBy([
              (r) => OrderingTerm(
                expression: r.createdAt,
                mode: OrderingMode.desc,
              ),
              (r) => OrderingTerm(expression: r.id),
            ]))
          .watch();

  Future<void> deleteRun(String runId) =>
      (_db.delete(_db.simulationRuns)..where((r) => r.id.equals(runId))).go();

  /// Stores a finished run, returning its id.
  ///
  /// [studies] and [workcenters] are the ones the run was given — read here
  /// only to copy the names and to walk each order's theoretical lead time
  /// (§7.9) before the plant they describe can change.
  Future<String> saveRun({
    required String projectId,
    required DispatchRule dispatch,
    required SimRunResult result,
    required List<SimStudy> studies,
    required Map<String, SimWorkcenter> workcenters,
  }) async {
    final runId = newId();
    final partNumbers = {
      for (final study in studies)
        for (final part in study.parts.values) part.id: part.partNumber,
    };
    final theoretical = theoreticalLeadTimes(
      result: result,
      studies: studies,
      workcenters: workcenters,
    );

    // One transaction: a run half-written is worse than one not written at
    // all, because the second is visibly missing and the first reads as real.
    await _db.transaction(() async {
      await _db
          .into(_db.simulationRuns)
          .insert(
            SimulationRunsCompanion.insert(
              id: runId,
              projectId: projectId,
              dispatch: dispatch.name,
              runStart: result.start,
              runEnd: result.end,
              guard: result.guard,
              abortReason: Value(result.abort?.name),
              createdAt: DateTime.now(),
            ),
          );

      await _db.batch((b) {
        b.insertAll(_db.simulationRunStudies, [
          for (final study in studies)
            SimulationRunStudiesCompanion.insert(
              runId: runId,
              studyId: study.id,
              name: study.name,
              releaseSeconds: study.releaseInterval.inSeconds,
              releaseCalendarId: Value(study.releaseCalendarId),
              priority: study.priority,
              wipCap: Value(study.wipCap),
            ),
        ]);

        b.insertAll(_db.simulationRunOrders, [
          for (final order in result.orders)
            SimulationRunOrdersCompanion.insert(
              runId: runId,
              studyId: order.studyId,
              orderId: order.orderId,
              sequence: order.sequence,
              partId: order.partId,
              partNumber: partNumbers[order.partId] ?? order.partId,
              needDate: order.needDate,
              released: Value(order.released),
              delivered: Value(order.delivered),
              theoreticalSeconds: Value(
                theoretical[order.orderId]?.inSeconds,
              ),
            ),
        ]);

        b.insertAll(_db.simulationRunSteps, [
          for (final step in result.steps)
            SimulationRunStepsCompanion.insert(
              runId: runId,
              studyId: step.studyId,
              orderId: step.orderId,
              nodeId: step.nodeId,
              workcenterId: step.workcenterId,
              queueStart: step.queueStart,
              processStart: step.processStart,
              processEnd: step.processEnd,
              changeoverIncurred: Value(step.changeoverIncurred),
            ),
        ]);

        b.insertAll(_db.simulationRunEmptySlots, [
          for (final slot in result.emptySlots)
            SimulationRunEmptySlotsCompanion.insert(
              runId: runId,
              studyId: slot.studyId,
              slotAt: slot.at,
              reason: slot.reason.name,
            ),
        ]);

        // Every station in the model, not only the ones an order reached: a
        // station that sat idle all run is evidence too, and its open time is
        // the denominator that says so.
        b.insertAll(_db.simulationRunWorkcenters, [
          for (final entry in result.openByWorkcenter.entries)
            SimulationRunWorkcentersCompanion.insert(
              runId: runId,
              workcenterId: entry.key,
              name: workcenters[entry.key]?.name ?? entry.key,
              busySeconds:
                  (result.busyByWorkcenter[entry.key] ?? Duration.zero)
                      .inSeconds,
              openSeconds: entry.value.inSeconds,
            ),
        ]);
      });
    });

    return runId;
  }

  /// Reads a run back as the engine's own result plus what it reported.
  ///
  /// Returns null when the run is gone — a deleted project takes its runs, and
  /// a screen holding an id across that is a state to report rather than throw
  /// on.
  Future<StoredRun?> loadRun(String runId) async {
    final header = await (_db.select(
      _db.simulationRuns,
    )..where((r) => r.id.equals(runId))).getSingleOrNull();
    if (header == null) return null;

    final studies = await (_db.select(
      _db.simulationRunStudies,
    )..where((s) => s.runId.equals(runId))).get();
    final orders = await (_db.select(
      _db.simulationRunOrders,
    )..where((o) => o.runId.equals(runId))).get();
    final steps = await (_db.select(
      _db.simulationRunSteps,
    )..where((s) => s.runId.equals(runId))).get();
    final slots = await (_db.select(
      _db.simulationRunEmptySlots,
    )..where((s) => s.runId.equals(runId))).get();
    final stations = await (_db.select(
      _db.simulationRunWorkcenters,
    )..where((w) => w.runId.equals(runId))).get();

    final result = SimRunResult(
      start: header.runStart,
      end: header.runEnd,
      guard: header.guard,
      steps: [
        for (final row in steps)
          SimOrderStep(
            studyId: row.studyId,
            orderId: row.orderId,
            nodeId: row.nodeId,
            workcenterId: row.workcenterId,
            queueStart: row.queueStart,
            processStart: row.processStart,
            processEnd: row.processEnd,
            changeoverIncurred: row.changeoverIncurred,
          ),
      ],
      orders: [
        for (final row in orders)
          SimOrderOutcome(
            studyId: row.studyId,
            orderId: row.orderId,
            sequence: row.sequence,
            partId: row.partId,
            needDate: row.needDate,
            released: row.released,
            delivered: row.delivered,
          ),
      ],
      emptySlots: [
        for (final row in slots)
          SimEmptySlot(
            studyId: row.studyId,
            at: row.slotAt,
            reason: _parse(
              EmptySlotReason.values,
              row.reason,
              EmptySlotReason.awaitingMaterial,
            ),
          ),
      ],
      busyByWorkcenter: {
        for (final row in stations) row.workcenterId: Duration(
          seconds: row.busySeconds,
        ),
      },
      openByWorkcenter: {
        for (final row in stations) row.workcenterId: Duration(
          seconds: row.openSeconds,
        ),
      },
      abort: header.abortReason == null
          ? null
          : _parse(
              SimAbortReason.values,
              header.abortReason!,
              SimAbortReason.nothingToRun,
            ),
    );

    return StoredRun(
      id: header.id,
      projectId: header.projectId,
      createdAt: header.createdAt,
      dispatch: _parse(DispatchRule.values, header.dispatch, DispatchRule.fifo),
      studies: studies,
      result: result,
      metrics: summariseRun(
        result: result,
        partNumbers: {for (final row in orders) row.partId: row.partNumber},
        workcenterNames: {for (final row in stations) row.workcenterId: row.name},
        theoreticalByOrder: {
          for (final row in orders)
            if (row.theoreticalSeconds != null)
              row.orderId: Duration(seconds: row.theoreticalSeconds!),
        },
      ),
    );
  }

  /// Resolves a stored enum name, falling back rather than throwing.
  ///
  /// A database written by a later build may hold a rule this one has never
  /// heard of, and a list of runs that cannot be opened at all is a worse
  /// answer than one run that reads as the default (see `SimulationRuns`).
  static T _parse<T extends Enum>(List<T> values, String name, T fallback) =>
      values.where((v) => v.name == name).firstOrNull ?? fallback;
}

/// A run as it comes back out of storage.
class StoredRun {
  const StoredRun({
    required this.id,
    required this.projectId,
    required this.createdAt,
    required this.dispatch,
    required this.studies,
    required this.result,
    required this.metrics,
  });

  final String id;
  final String projectId;
  final DateTime createdAt;
  final DispatchRule dispatch;

  /// The studies that took part, as they stood at the time.
  final List<SimulationRunStudy> studies;

  final SimRunResult result;

  /// What §8 said about it. Recomputed on read from the stored rows rather
  /// than stored as numbers, so there is one implementation of every figure.
  final RunMetrics metrics;
}
