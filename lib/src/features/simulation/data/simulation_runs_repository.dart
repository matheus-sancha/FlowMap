import 'package:drift/drift.dart';

import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../application/run_metrics.dart';
import '../application/sim_assembly.dart' show stationPools;
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

  /// The project's runs, newest first, each with what its stations dispatched
  /// by (§7.3).
  ///
  /// Ties break by id. Dates are stored to the second, the convention the rest
  /// of the schema uses, so two runs made inside one second would otherwise
  /// come back in whatever order the database felt like — and a list that
  /// reorders itself between rebuilds is the kind of thing a user reports as a
  /// bug in the run itself.
  ///
  /// **The stations come with the list rather than on demand.** The history
  /// menu labels every row with its queue type, so a per-run query would be one
  /// query per menu item; this is one row per station per run, which on the real
  /// database is 35 runs of about ten. Reading them here is also what lets the
  /// menu row and the run header be folded by the same code — a menu saying
  /// `FIFO` over a header saying `mixed` is exactly the disagreement §12.6 is
  /// about.
  Stream<List<RunListing>> watchRuns(String projectId) {
    final stations = _db.simulationRunWorkcenters;
    final studies = _db.simulationRunStudies;
    final query =
        _db.select(_db.simulationRuns).join([
            leftOuterJoin(
              stations,
              stations.runId.equalsExp(_db.simulationRuns.id),
            ),
            // The takt is on the study rows (§7.7.2), joined here so the menu can
            // tell two runs of one study apart by what they ran at — which is
            // what makes §7.7's "run it twice and compare" legible in the list.
            leftOuterJoin(
              studies,
              studies.runId.equalsExp(_db.simulationRuns.id),
            ),
          ])
          ..where(_db.simulationRuns.projectId.equals(projectId))
          ..orderBy([
            OrderingTerm(
              expression: _db.simulationRuns.createdAt,
              mode: OrderingMode.desc,
            ),
            OrderingTerm(expression: _db.simulationRuns.id),
            OrderingTerm(expression: stations.name),
          ]);

    return query.watch().map((rows) {
      // Grouped in the order the join produced, so the newest-first ordering
      // above is the ordering that comes out.
      final headers = <String, SimulationRun>{};
      final byRun = <String, List<({String name, DispatchRule rule})>>{};
      final takts = <String, List<List<(double, String?)>>>{};
      // The two joins multiply: one row per (station × study), so a station or a
      // study is seen once per row of the other and has to be counted once.
      final seenStations = <String, Set<String>>{};
      final seenStudies = <String, Set<String>>{};
      for (final row in rows) {
        final header = row.readTable(_db.simulationRuns);
        headers[header.id] = header;
        final queues = byRun.putIfAbsent(header.id, () => []);
        final station = row.readTableOrNull(stations);
        if (station != null &&
            (seenStations[header.id] ??= {}).add(station.workcenterId)) {
          final rule = _stationRule(station.queueType, header.dispatch);
          if (rule != null) queues.add((name: station.name, rule: rule));
        }
        final study = row.readTableOrNull(studies);
        if (study != null &&
            (seenStudies[header.id] ??= {}).add(study.studyId)) {
          if (study.taktValue case final value?) {
            // One takt, the whole way — which is what a study row can say, and
            // what was true of every run before §7.9. `_withOrderTakts` below
            // replaces it wherever the orders know better.
            (takts[header.id] ??= []).add([(value, study.taktUnit)]);
          }
        }
      }
      return [
        for (final entry in headers.entries)
          (
            run: entry.value,
            queues: RunQueues(byRun[entry.key] ?? const []),
            takts: takts[entry.key] ?? const [],
          ),
      ];
    }).asyncMap(_withOrderTakts);
  }

  /// Replaces each listing's per-study takt with the sequence its **orders**
  /// actually opened under (§7.9).
  ///
  /// **A second query rather than a third join.** The takt lives on the orders
  /// now, and a run has hundreds of those against a handful of stations — a
  /// third join would multiply the cartesian by the demand and make the menu's
  /// query grow with the plant. Run in step with the listing instead: a run's
  /// header row and its orders are written and deleted together, so the main
  /// query fires whenever these change.
  ///
  /// **The menu and the run header then read the same rows**, which is the
  /// whole reason `taktLabelForValues` exists — a label with its own copy of
  /// the fact can only agree by being written correctly, where a query agrees
  /// by construction (§7.9.3).
  ///
  /// A run stored before v22 has no takt on any order and keeps the single
  /// figure its study rows carry, which is what it did in fact run at
  /// throughout.
  Future<List<RunListing>> _withOrderTakts(List<RunListing> listings) async {
    if (listings.isEmpty) return listings;

    final rows = await _db
        .customSelect(
          'SELECT run_id, study_id, takt_value, takt_unit, '
          'MIN(released) AS first_release '
          'FROM simulation_run_orders '
          'WHERE takt_value IS NOT NULL AND run_id IN '
          '(SELECT id FROM simulation_runs WHERE project_id = ?) '
          'GROUP BY run_id, study_id, takt_value, takt_unit',
          variables: [Variable<String>(listings.first.run.projectId)],
          readsFrom: {_db.simulationRunOrders, _db.simulationRuns},
        )
        .get();

    // Grouped per run and handed to the shared rule, so the ordering and the
    // consecutive-distinct fold are written once (§7.9.3).
    final byRun =
        <
          String,
          List<({String studyId, DateTime? at, double? value, String? unit})>
        >{};
    for (final row in rows) {
      (byRun[row.read<String>('run_id')] ??= []).add((
        studyId: row.read<String>('study_id'),
        at: row.read<DateTime?>('first_release'),
        value: row.read<double>('takt_value'),
        unit: row.read<String?>('takt_unit'),
      ));
    }

    return [
      for (final listing in listings)
        if (byRun[listing.run.id] case final entries?)
          (
            run: listing.run,
            queues: listing.queues,
            takts: taktSequences(entries),
          )
        else
          listing,
    ];
  }

  Future<void> deleteRun(String runId) =>
      (_db.delete(_db.simulationRuns)..where((r) => r.id.equals(runId))).go();

  /// Stores a finished run, returning its id.
  ///
  /// [studies] and [workcenters] are the ones the run was given — read here
  /// only to copy the names and to walk each order's theoretical lead time
  /// (§7.9) before the plant they describe can change.
  Future<String> saveRun({
    required String projectId,
    required SimRunResult result,
    required List<SimStudy> studies,
    required Map<String, SimWorkcenter> workcenters,
  }) async {
    final runId = newId();
    final partNumbers = {
      for (final study in studies)
        for (final part in study.parts.values) part.id: part.partNumber,
    };
    final descriptions = {
      for (final study in studies)
        for (final part in study.parts.values)
          if (part.description != null) part.id: part.description!,
    };
    // What §8.5's plan needs and the result does not carry: the engine reports
    // outcomes per order id, and the order's own batch and dates live on the
    // input it was built from.
    final ordersById = {
      for (final study in studies)
        for (final order in study.orders) order.id: order,
    };
    final theoretical = theoreticalLeadTimes(
      result: result,
      studies: studies,
      workcenters: workcenters,
    );
    // Which pool each station was dispatched through, resolved now rather than
    // joined later: the plant can be re-grouped tomorrow and this run has to
    // keep saying what it observed (§7.10).
    final pools = stationPools(studies);
    // The queue each station dispatched by, copied in for the same reason
    // (§7.10): the queue lives on the project and can be retuned tomorrow, and
    // a run that read it back would silently change what it claims to have
    // done. Keyed by station rather than by target, because that is what the
    // row is — a pool's members all carry the pool's queue.
    final queues = <String, SimQueue>{
      for (final study in studies)
        for (final step in study.nodes)
          for (final candidate in step.candidates) candidate: step.queue,
    };

    // One transaction: a run half-written is worse than one not written at
    // all, because the second is visibly missing and the first reads as real.
    await _db.transaction(() async {
      await _db
          .into(_db.simulationRuns)
          .insert(
            SimulationRunsCompanion.insert(
              id: runId,
              projectId: projectId,
              // **Written empty, because a run no longer has one rule** (§7.3).
              // The column is `NOT NULL` and stays on the schema so the runs
              // made before v19 keep the rule they really were made with; empty
              // parses to no rule, so it contributes nothing to the fold in
              // [_stationRule] and every station of a v19 run speaks for itself.
              // Widening it to nullable would rebuild the table, which §16.11
              // is the record of the cost of.
              dispatch: '',
              runStart: result.start,
              runEnd: result.end,
              guard: result.guard,
              abortReason: Value(result.abort?.name),
              scheduleHorizon: Value(result.scheduleHorizon),
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
              // The interval at this study's **first release** (§7.9). It was
              // the whole run's cadence until an order took the takt in force
              // when it opened; what a run spanning a change actually ran at is
              // read off its orders now.
              releaseSeconds: study.releaseInterval.inSeconds,
              releaseCalendarId: Value(study.releaseCalendarId),
              // The takt as typed, beside the interval it resolved to (§7.7.2)
              // — the one it first released at, and the schedule it came from
              // may be edited tomorrow, which is why it is copied not joined.
              taktValue: Value(study.taktValue),
              taktUnit: Value(study.taktUnit?.name),
              // When it stops being that figure — the boundary this run
              // crossed, since §7.9 made the engine act on it (§7.7.3).
              nextTaktChange: Value(study.nextTaktChange),
              // And where its cadence ran out, if it did (§7.9.2). Absent for
              // every study that released its whole sequence.
              cadenceEndedAt: Value(result.cadenceEndedByStudy[study.id]),
              // Copied in so a run can still say why it began where it did
              // after the study's buffer is changed (§7.10).
              startBufferDays: Value(study.startBuffer.inDays),
              priority: study.priority,
              wipCap: Value(study.wipCap),
              // Where it sat in the plant, so §12.1's cell and line filters can
              // read a stored run rather than joining to a study that may have
              // moved since (§7.10). Id and name both: the id survives a rename
              // and the name survives a deletion.
              productionCellId: Value(study.productionCellId),
              productionCellName: Value(study.productionCellName),
              productionLineId: Value(study.productionLineId),
              productionLineName: Value(study.productionLineName),
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
              customerProject: Value(
                ordersById[order.orderId]?.customerProject,
              ),
              partDescription: Value(descriptions[order.partId]),
              batchNumber: Value(ordersById[order.orderId]?.batchNumber),
              batchSize: Value(ordersById[order.orderId]?.batchSize),
              materialDate: Value(ordersById[order.orderId]?.materialDate),
              needDate: order.needDate,
              released: Value(order.released),
              delivered: Value(order.delivered),
              // **The takt it opened under** (§7.9, v22) — the cause of which
              // v21's `process_seconds` is the effect. Null where it never
              // opened, which is the same blank as every other figure an
              // unreleased order has nothing to say about.
              taktValue: Value(order.taktValue),
              taktUnit: Value(order.taktUnit?.name),
              theoreticalSeconds: Value(theoretical[order.orderId]?.inSeconds),
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
              changeoverSeconds: Value(step.changeoverSeconds),
              processSeconds: Value(step.processSeconds),
              // The same work before rework, so §10.3 can draw the two as
              // separate segments of one bar (§10.2).
              processSecondsBeforeRework: Value(
                step.processSecondsBeforeRework,
              ),
              // The lane it was pulled out of, and how long the station then
              // stood holding it (§5.5). Both are read back below, and a column
              // written by nobody is the failure §1.5 found once already.
              laneNodeId: Value(step.laneNodeId),
              blockedSeconds: Value(step.blocked.inSeconds),
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
              busySeconds: (result.busyByWorkcenter[entry.key] ?? Duration.zero)
                  .inSeconds,
              openSeconds: entry.value.inSeconds,
              // Kept out of `busySeconds` on purpose (§8.3): a station holding
              // a finished order it cannot put down is occupied and producing
              // nothing, and folding the two would report the jam as output.
              blockedSeconds: Value(
                (result.blockedByWorkcenter[entry.key] ?? Duration.zero)
                    .inSeconds,
              ),
              // Copied in like the name, and for the same reason: a station
              // re-rated from one unit to two afterwards would otherwise
              // silently change what this run's utilization meant (§3.1).
              units: Value(workcenters[entry.key]?.units ?? 1),
              // Null id where the station was named directly, or reached
              // through more than one pool — ungrouped either way, and the
              // name still says which pools it served (§3.1).
              poolId: Value(pools[entry.key]?.id),
              poolName: Value(pools[entry.key]?.name),
              queueType: Value(queues[entry.key]?.rule.name),
              queueCapacity: Value(queues[entry.key]?.capacity),
              // Copied in for the same reason the pool name is: a station
              // retyped afterwards would otherwise re-column every stored run
              // in the picker (§7.10, §10.2).
              typeId: Value(workcenters[entry.key]?.typeId),
              typeName: Value(workcenters[entry.key]?.typeName),
            ),
        ]);

        // A row per station per month of the run (§10.2). Written from the
        // same walk that produced the whole-run figure above, so the months sum
        // to it rather than being a second opinion about the same calendar.
        b.insertAll(_db.simulationRunWorkcenterMonths, [
          for (final entry in result.openByWorkcenterMonth.entries)
            for (final month in entry.value.entries)
              SimulationRunWorkcenterMonthsCompanion.insert(
                runId: runId,
                workcenterId: entry.key,
                month: month.key,
                openSeconds: month.value.inSeconds,
              ),
        ]);

        // Every lane in the flow, whether or not anything queued in it (§5.5).
        //
        // All of it copied in: the name a reader recognises, the discipline
        // that decided the order, the capacity that decided the blocking, and
        // the position §8.6 needs to draw a lane row between the two station
        // rows it connects. §7.10 joins to nothing, and the flow beneath a run
        // may be edited the moment after it is stored.
        //
        // **One row per target now, not per study.** A queue belongs to the
        // station it stands in front of (§5.5), so two studies feeding CLAD07
        // store the one queue they share — and `node_id` holds the *target* id,
        // which is what a lane is identified by since v19. The first study to
        // name a target writes it; the second finds it already there.
        b.insertAll(_db.simulationRunLanes, [
          for (final entry in {
            for (final study in studies)
              for (final node in study.nodes)
                node.queue.targetId: (study: study, node: node),
          }.entries)
            SimulationRunLanesCompanion.insert(
              runId: runId,
              studyId: entry.value.study.id,
              nodeId: entry.key,
              name: Value(entry.value.node.queue.name),
              position: entry.value.node.position,
              rule: Value(entry.value.node.queue.rule.name),
              capacity: Value(entry.value.node.queue.capacity),
            ),
        ]);

        // One stay per order per lane, read off the steps: an order enters a
        // lane when it starts queueing and leaves it when the station pulls it,
        // which `queueStart` and `processStart` already record. Deriving rather
        // than having the engine keep a second list of the same fact — two
        // records of one event are two things to keep in step.
        b.insertAll(_db.simulationRunLaneVisits, [
          for (final step in result.steps)
            if (step.laneNodeId case final laneId?)
              SimulationRunLaneVisitsCompanion.insert(
                runId: runId,
                studyId: step.studyId,
                orderId: step.orderId,
                targetId: laneId,
                // The step already knows both, so the visit derived from it
                // needs nothing the engine did not already say (§8.6).
                stepNodeId: step.nodeId,
                enteredAt: step.queueStart,
                leftAt: Value(step.processStart),
              ),
          // And whatever was still standing in a lane when the run stopped,
          // which produced no step at all.
          for (final open in result.openLaneVisits)
            SimulationRunLaneVisitsCompanion.insert(
              runId: runId,
              studyId: open.studyId,
              orderId: open.orderId,
              targetId: open.laneNodeId,
              stepNodeId: open.stepNodeId,
              enteredAt: open.enteredAt,
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
    final byOrderId = {for (final row in orders) row.orderId: row};
    // Empty on every run made before v25, which is what makes §10.3 offer no
    // graph rather than an empty one.
    final stationMonths = await (_db.select(
      _db.simulationRunWorkcenterMonths,
    )..where((m) => m.runId.equals(runId))).get();
    final lanes = await (_db.select(
      _db.simulationRunLanes,
    )..where((l) => l.runId.equals(runId))).get();
    final laneVisits = await (_db.select(
      _db.simulationRunLaneVisits,
    )..where((v) => v.runId.equals(runId))).get();

    // What each station dispatched by (§7.3), by name so the breakdown reads
    // as a list of stations rather than of uuids.
    final queues = RunQueues(
      [
        for (final row in stations)
          if (_stationRule(row.queueType, header.dispatch) case final rule?)
            (name: row.name, rule: rule),
      ]..sort((a, b) => a.name.compareTo(b.name)),
    );

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
            changeoverSeconds: row.changeoverSeconds,
            processSeconds: row.processSeconds,
            processSecondsBeforeRework: row.processSecondsBeforeRework,
            laneNodeId: row.laneNodeId,
            blocked: Duration(seconds: row.blockedSeconds),
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
            // The takt it opened under (§7.9, v22). Null on a run stored
            // before it, which is *made before a run said this* — the plan's
            // column and the hover card show nothing rather than guessing.
            taktValue: row.taktValue,
            taktUnit: row.taktUnit == null
                ? null
                : _parseOrNull(TaktUnit.values, row.taktUnit!),
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
        for (final row in stations)
          row.workcenterId: Duration(seconds: row.busySeconds),
      },
      openByWorkcenter: {
        for (final row in stations)
          row.workcenterId: Duration(seconds: row.openSeconds),
      },
      openByWorkcenterMonth: {
        for (final row in stationMonths)
          row.workcenterId: {
            for (final month in stationMonths.where(
              (m) => m.workcenterId == row.workcenterId,
            ))
              month.month: Duration(seconds: month.openSeconds),
          },
      },
      blockedByWorkcenter: {
        for (final row in stations)
          row.workcenterId: Duration(seconds: row.blockedSeconds),
      },
      lanes: [
        for (final row in lanes)
          SimLane(
            studyId: row.studyId,
            nodeId: row.nodeId,
            position: row.position,
            name: row.name,
            capacity: row.capacity,
          ),
      ],
      // Only the stays that never ended. Every other one is readable off the
      // steps — `queueStart` and `processStart` are its two ends — so reading
      // them back as well would give the chart two records of one event.
      openLaneVisits: [
        for (final row in laneVisits)
          if (row.leftAt == null)
            SimOpenLaneVisit(
              studyId: row.studyId,
              orderId: row.orderId,
              laneNodeId: row.targetId,
              stepNodeId: row.stepNodeId,
              enteredAt: row.enteredAt,
            ),
      ],
      scheduleHorizon: header.scheduleHorizon,
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
      queues: queues,
      studies: studies,
      result: result,
      // Built from the same `orders` rows the result above was, so the plan's
      // dates and the metrics' cannot come from two different readings.
      plan:
          <PlanEntry>[
            for (final outcome in result.orders)
              if (byOrderId[outcome.orderId] case final row?)
                ProductionPlanRow(
                  outcome: outcome,
                  partNumber: row.partNumber,
                  partDescription: row.partDescription,
                  customerProject: row.customerProject,
                  batchNumber: row.batchNumber,
                  batchSize: row.batchSize,
                  materialDate: row.materialDate,
                  theoreticalLeadTime: row.theoreticalSeconds == null
                      ? null
                      : Duration(seconds: row.theoreticalSeconds!),
                ),
            for (final slot in result.emptySlots)
              PlanEmptySlot(
                studyId: slot.studyId,
                slotAt: slot.at,
                reason: slot.reason,
              ),
          ]..sort((a, b) {
            // By date, so the table reads as the cadence ran. An order that
            // never released has no date and goes to the end rather than to the
            // beginning, where a null would sort it.
            final left = a.at;
            final right = b.at;
            if (left == null) return right == null ? 0 : 1;
            if (right == null) return -1;
            final byDate = left.compareTo(right);
            if (byDate != 0) return byDate;
            // A slot and the order it released at the same instant: the order
            // first, because the slot that produced it is not an empty one.
            return a is ProductionPlanRow ? -1 : 1;
          }),
      metrics: summariseRun(
        result: result,
        partNumbers: {for (final row in orders) row.partId: row.partNumber},
        workcenterNames: {
          for (final row in stations) row.workcenterId: row.name,
        },
        // Read back rather than re-derived: the pools the plant has today are
        // not necessarily the ones this run dispatched through (§7.10). A row
        // written before v18 has neither column and is simply absent, which is
        // a station that groups under nothing.
        pools: {
          for (final row in stations)
            if (row.poolName != null)
              row.workcenterId: StationPool(
                id: row.poolId,
                name: row.poolName!,
              ),
        },
        // The type the run copied in (§10.2), for the same reason as the pool
        // above: a station retyped since must not re-column a stored run.
        // Absent on every row written before v25 and on a station that has no
        // type, which the plant allows.
        types: {
          for (final row in stations)
            if (row.typeId != null && row.typeName != null)
              row.workcenterId: (id: row.typeId!, name: row.typeName!),
        },
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
      _parseOrNull(values, name) ?? fallback;

  static T? _parseOrNull<T extends Enum>(List<T> values, String name) =>
      values.where((v) => v.name == name).firstOrNull;

  /// What one station of a run dispatched by (§7.3).
  ///
  /// **The run-level rule fills in, and is the only thing it is still read
  /// for.** A run made before v19 recorded no queue type per station and really
  /// did dispatch the whole plant by one rule, so reading it here is what keeps
  /// the 35 stored runs saying what they did. A v19 run writes the column empty
  /// (see `saveRun`), which parses to null — so a station that also has no queue
  /// type recorded has nothing to say and is left out rather than reported as
  /// FIFO.
  static DispatchRule? _stationRule(String? queueType, String runRule) =>
      _parseOrNull(DispatchRule.values, queueType ?? runRule);
}

/// One ordered takt sequence per study, from whatever carries a takt and a
/// moment (§7.9).
///
/// **The sequence, not the set.** A run that opened at 4 days and then at 5 is
/// not the run that did the reverse, and a label saying `4 → 5 days` has to know
/// which way round it went. Ordered by when each takt was first opened under;
/// entries with no moment sort first, which is where an order that never
/// released would sit if it carried a takt at all — it does not.
///
/// Shared by the runs-history menu and the run header, which read the same facts
/// out of different shapes: aggregated rows in the repository, order outcomes in
/// the view. The fold below then cannot name a run two ways because one of them
/// grouped it differently.
List<List<(double, String?)>> taktSequences(
  Iterable<({String studyId, DateTime? at, double? value, String? unit})>
  entries,
) {
  final byStudy = <String, List<(DateTime?, (double, String?))>>{};
  for (final entry in entries) {
    if (entry.value case final value?) {
      (byStudy[entry.studyId] ??= []).add((entry.at, (value, entry.unit)));
    }
  }

  return [
    for (final found in byStudy.values)
      [
        for (final pair in (found
              ..sort((a, b) {
                if (a.$1 == null) return b.$1 == null ? 0 : -1;
                if (b.$1 == null) return 1;
                return a.$1!.compareTo(b.$1!);
              })))
          pair.$2,
      ].fold<List<(double, String?)>>([], (seen, pair) {
        // Distinct **consecutively**: a study that ran 4, then 5, then 4 again
        // is three regimes and not two, and collapsing by value alone would
        // report it as a single change it never made.
        if (seen.isEmpty || seen.last != pair) seen.add(pair);
        return seen;
      }),
  ];
}

/// One line of the runs history: a run's header row, what it dispatched by, and
/// the takts each of its studies ran through (§7.7.2, §7.9).
///
/// **[takts] is one ordered sequence per study**, of raw `(value, unit-name)`
/// pairs rather than full study rows: the menu labels every run, so it reads the
/// lightest thing that can name a takt. Ordered by when each was first released
/// under, because a run that went `4 → 5 days` is not the run that went
/// `5 → 4`.
///
/// The sequences collapse to one label — a figure, a change, or `mixed` —
/// through `taktLabelForValues`, the same fold the run header uses, so the menu
/// and the header it opens cannot name a run two different ways.
typedef RunListing = ({
  SimulationRun run,
  RunQueues queues,
  List<List<(double, String?)>> takts,
});

/// What each station of a run dispatched by, as the run recorded it (§7.3).
///
/// **This replaced `simulation_runs.dispatch` as the thing a run is labelled
/// with.** The queue type belongs to a station since v19, so a header claiming
/// the run had one rule was describing a decision the engine had stopped making
/// — and the count of stations that "overrode" it described an override of
/// nothing.
///
/// [uniform] and [isMixed] are both derived from [stations], so the one-line
/// label and the breakdown beneath it cannot disagree about the same run.
class RunQueues {
  const RunQueues(this.stations);

  /// Every station that recorded a queue type, by name.
  final List<({String name, DispatchRule rule})> stations;

  /// The one type every station shared, or null when they differed.
  ///
  /// Also null when the run recorded no station at all, which [isMixed]
  /// separates: one is `mixed`, the other is a run with nothing to say.
  DispatchRule? get uniform {
    final types = _types;
    return types.length == 1 ? types.single : null;
  }

  bool get isMixed => _types.length > 1;

  Set<DispatchRule> get _types => {
    for (final station in stations) station.rule,
  };

  /// How this reads in one line: the shared type's name, or `mixed`.
  ///
  /// Null when there is nothing to name, and the caller drops the clause rather
  /// than inventing FIFO for a run that never said so.
  ///
  /// Takes its words rather than an `AppLocalizations`, so the fold stays in the
  /// data layer where the run is read and no layer below the widgets has to know
  /// what a locale is.
  String? label({
    required String Function(DispatchRule) name,
    required String mixed,
  }) {
    if (isMixed) return mixed;
    final rule = uniform;
    return rule == null ? null : name(rule);
  }
}

/// A run as it comes back out of storage.
class StoredRun {
  const StoredRun({
    required this.id,
    required this.projectId,
    required this.createdAt,
    required this.queues,
    required this.studies,
    required this.result,
    required this.metrics,
    required this.plan,
  });

  final String id;
  final String projectId;
  final DateTime createdAt;

  /// What each station dispatched by, as the run recorded it (§7.3).
  final RunQueues queues;

  /// The production plan (§8.5), in date order, all studies together.
  ///
  /// The UI sections it by study. **Ordered by date rather than by sequence**
  /// since the empty slots joined it: §7.2 releases strictly from the head and
  /// never reorders, so for the orders alone the two orderings are the same list
  /// — but a slot that produced nothing has a date and no sequence number, and
  /// only a timeline can say where it belongs. An order that never released has
  /// neither and sorts last.
  final List<PlanEntry> plan;

  /// The studies that took part, as they stood at the time.
  final List<SimulationRunStudy> studies;

  final SimRunResult result;

  /// What §8 said about it. Recomputed on read from the stored rows rather
  /// than stored as numbers, so there is one implementation of every figure.
  final RunMetrics metrics;
}

/// One line of the production plan (DESIGN.md §8.5).
///
/// `Order | Part Number | Project | Batch Number | Batch Size | Need Date |
/// Material Date | Order Start Date | Delivery Date | Float`
///
/// **The outcome is held rather than unpacked**, so Float comes from
/// [SimOrderOutcome.float] — the one place it is defined — instead of being
/// worked out a second time here. A plan whose Float disagreed with the tab's
/// average float would be worse than no plan.
///
/// The demand half is nullable throughout because a run stored before schema
/// v12 did not record it (§16.13). A blank cell says "this run did not keep
/// that", which is true; it is not the same as an empty batch number.
/// One line of the production plan: an order, or a release slot that went out
/// empty (DESIGN.md §8.5, §7.2).
///
/// **Empty slots are rows.** The plan used to be the orders that survived the
/// release gate, so a study that spent eight of twenty-three slots waiting for
/// material read as a plan with gaps nobody could see — reported from the field
/// as wanting them shown. Interleaved by date, the table reads as the cadence
/// actually ran: three slots, one order.
sealed class PlanEntry {
  const PlanEntry();

  /// The study whose sequence this belongs to — what the plan sections by.
  String get studyId;

  /// When it happened, and what the plan sorts by. Null for an order that never
  /// released, which has no place in a timeline and sorts last.
  DateTime? get at;
}

/// A release slot that produced nothing, and why (§7.2).
class PlanEmptySlot extends PlanEntry {
  const PlanEmptySlot({
    required this.studyId,
    required this.slotAt,
    required this.reason,
  });

  @override
  final String studyId;

  final DateTime slotAt;

  /// Awaiting material, the WIP cap, or a full lane — the three gates §7.2
  /// checks. Kept per slot rather than counted, because *which* gate held the
  /// line is the thing a planner acts on.
  final EmptySlotReason reason;

  @override
  DateTime? get at => slotAt;
}

class ProductionPlanRow extends PlanEntry {
  const ProductionPlanRow({
    required this.outcome,
    required this.partNumber,
    required this.partDescription,
    required this.customerProject,
    required this.batchNumber,
    required this.batchSize,
    required this.materialDate,
    required this.theoreticalLeadTime,
  });

  final SimOrderOutcome outcome;
  final String partNumber;

  @override
  String get studyId => outcome.studyId;

  @override
  DateTime? get at => outcome.released;

  /// Null on a run stored before v13, which did not record it (§16.14).
  final String? partDescription;

  final String? customerProject;
  final String? batchNumber;
  final int? batchSize;
  final DateTime? materialDate;

  /// The `Order` column: the row's place in the study's sequence, 1-based
  /// because the grid it came from numbers its rows that way.
  int get orderNumber => outcome.sequence + 1;

  /// When it entered the flow (§7.2). Null means it never did.
  DateTime? get orderStart => outcome.released;

  DateTime? get delivery => outcome.delivered;

  /// §7.9's queue-free walk for this order, as the run stored it.
  ///
  /// Null when the run could not cost the order — it never released, or a step
  /// had no process time — which is the same set of rows [actualLeadTime]
  /// is null for, bar the orders that released and never finished.
  final Duration? theoreticalLeadTime;

  /// Order end minus order start: the wall-clock time this order was in the
  /// flow. Read from [outcome] rather than stored, so the column and the tab's
  /// average lead time cannot come from two different subtractions.
  ///
  /// The gap between this and [theoreticalLeadTime] is what the order queued.
  Duration? get actualLeadTime => outcome.leadTime;

  /// Slack against the need date: positive is early (§8).
  Duration? get float => outcome.float;

  /// This order's own `theoretical ÷ actual` (§8.7), or null when either half
  /// is missing.
  ///
  /// **Carries no warm-up exclusion, unlike the metrics card's headline.** The
  /// early orders of a study meet a flow nothing has queued in yet and score
  /// far above 1.0; that ramp is real and a planner should be able to see it
  /// and judge it. A column that silently blanked its own first rows would be
  /// the same hiding in a different place.
  double? get leadTimeEfficiency {
    final actual = actualLeadTime;
    final theoretical = theoreticalLeadTime;
    if (actual == null || theoretical == null || actual.inSeconds == 0) {
      return null;
    }
    return theoretical.inSeconds / actual.inSeconds;
  }
}
