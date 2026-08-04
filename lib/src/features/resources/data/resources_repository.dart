import 'package:drift/drift.dart';

import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../calendar/application/shift_pattern_spec.dart';

/// The only place resource queries are written (DESIGN.md §1.1).
///
/// One repository for the whole resource tree rather than six: plants, cells,
/// lines, workcenters, pools, types and shift patterns are edited together on
/// one screen and constrain one another, so splitting them would spread a
/// single transaction's worth of reasoning across six files.
///
/// Reads are streams off the tables, so a write anywhere refreshes every screen
/// showing that data with no manual invalidation.
///
/// **Archived rows are excluded by default.** Soft deletion only means
/// something if the default read path honours it; a caller that wants the
/// archived ones has to ask (DESIGN.md §3).
/// A production line together with the cell it sits in — what the structure
/// tree and the workcenter editor both need to show a line unambiguously, since
/// two cells may each have a line called "Line 1".
class PlantLine {
  const PlantLine({required this.cell, required this.line});

  final ProductionCell cell;
  final ProductionLine line;

  String get qualifiedName => '${cell.name} · ${line.name}';
}

class ResourcesRepository {
  ResourcesRepository(this._db);

  final AppDatabase _db;

  // --- Plants -------------------------------------------------------------

  Stream<List<Plant>> watchPlants({bool includeArchived = false}) {
    final query = _db.select(_db.plants)
      ..orderBy([(p) => OrderingTerm(expression: p.name)]);
    if (!includeArchived) query.where((p) => p.archivedAt.isNull());
    return query.watch();
  }

  Future<String> createPlant({required String name, String? code}) async {
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.plants)
        .insert(
          PlantsCompanion.insert(
            id: id,
            name: name,
            code: Value(code),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updatePlant(String id, {required String name, String? code}) =>
      (_db.update(_db.plants)..where((p) => p.id.equals(id))).write(
        PlantsCompanion(
          name: Value(name),
          code: Value(code),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setPlantArchived(String id, bool archived) =>
      (_db.update(_db.plants)..where((p) => p.id.equals(id))).write(
        PlantsCompanion(
          archivedAt: Value(archived ? DateTime.now() : null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deletePlant(String id) =>
      (_db.delete(_db.plants)..where((p) => p.id.equals(id))).go();

  // --- Production cells ---------------------------------------------------

  Stream<List<ProductionCell>> watchCells(
    String plantId, {
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.productionCells)
      ..where((c) => c.plantId.equals(plantId))
      ..orderBy([(c) => OrderingTerm(expression: c.name)]);
    if (!includeArchived) query.where((c) => c.archivedAt.isNull());
    return query.watch();
  }

  Future<String> createCell({
    required String plantId,
    required String name,
  }) async {
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.productionCells)
        .insert(
          ProductionCellsCompanion.insert(
            id: id,
            plantId: plantId,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> renameCell(String id, String name) =>
      (_db.update(_db.productionCells)..where((c) => c.id.equals(id))).write(
        ProductionCellsCompanion(
          name: Value(name),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setCellArchived(String id, bool archived) =>
      (_db.update(_db.productionCells)..where((c) => c.id.equals(id))).write(
        ProductionCellsCompanion(
          archivedAt: Value(archived ? DateTime.now() : null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deleteCell(String id) =>
      (_db.delete(_db.productionCells)..where((c) => c.id.equals(id))).go();

  // --- Production lines ---------------------------------------------------

  Stream<List<ProductionLine>> watchLines(
    String cellId, {
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.productionLines)
      ..where((l) => l.cellId.equals(cellId))
      ..orderBy([(l) => OrderingTerm(expression: l.name)]);
    if (!includeArchived) query.where((l) => l.archivedAt.isNull());
    return query.watch();
  }

  /// Every line in the plant with the cell it belongs to.
  ///
  /// One join rather than a stream per cell: the structure tree and the
  /// workcenter editor both need the whole set, and a subscription per cell
  /// would multiply with the tree.
  Stream<List<PlantLine>> watchPlantLines(
    String plantId, {
    bool includeArchived = false,
  }) {
    final query =
        _db.select(_db.productionLines).join([
            innerJoin(
              _db.productionCells,
              _db.productionCells.id.equalsExp(_db.productionLines.cellId),
            ),
          ])
          ..where(_db.productionCells.plantId.equals(plantId))
          ..orderBy([
            OrderingTerm(expression: _db.productionCells.name),
            OrderingTerm(expression: _db.productionLines.name),
          ]);
    if (!includeArchived) {
      query.where(
        _db.productionLines.archivedAt.isNull() &
            _db.productionCells.archivedAt.isNull(),
      );
    }
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          PlantLine(
            cell: row.readTable(_db.productionCells),
            line: row.readTable(_db.productionLines),
          ),
      ],
    );
  }

  Future<String> createLine({
    required String cellId,
    required String name,
  }) async {
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.productionLines)
        .insert(
          ProductionLinesCompanion.insert(
            id: id,
            cellId: cellId,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> renameLine(String id, String name) =>
      (_db.update(_db.productionLines)..where((l) => l.id.equals(id))).write(
        ProductionLinesCompanion(
          name: Value(name),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setLineArchived(String id, bool archived) =>
      (_db.update(_db.productionLines)..where((l) => l.id.equals(id))).write(
        ProductionLinesCompanion(
          archivedAt: Value(archived ? DateTime.now() : null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deleteLine(String id) =>
      (_db.delete(_db.productionLines)..where((l) => l.id.equals(id))).go();

  // --- Workcenters --------------------------------------------------------

  /// Every workcenter in the plant, whatever line it is drawn under.
  Stream<List<Workcenter>> watchWorkcenters(
    String plantId, {
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.workcenters)
      ..where((w) => w.plantId.equals(plantId))
      ..orderBy([(w) => OrderingTerm(expression: w.name)]);
    if (!includeArchived) query.where((w) => w.archivedAt.isNull());
    return query.watch();
  }

  Future<String> createWorkcenter({
    required String plantId,
    required String name,
    String? typeId,
    Set<String> lineIds = const {},
  }) async {
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.workcenters)
        .insert(
          WorkcentersCompanion.insert(
            id: id,
            plantId: plantId,
            name: name,
            typeId: Value(typeId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await setWorkcenterLines(id, lineIds);
    return id;
  }

  Future<void> updateWorkcenter(
    String id, {
    required String name,
    String? typeId,
    Set<String>? lineIds,
  }) async {
    await (_db.update(_db.workcenters)..where((w) => w.id.equals(id))).write(
      WorkcentersCompanion(
        name: Value(name),
        typeId: Value(typeId),
        updatedAt: Value(DateTime.now()),
      ),
    );
    // Null means "the caller was not editing membership" — distinct from an
    // empty set, which means "under no line at all".
    if (lineIds != null) await setWorkcenterLines(id, lineIds);
  }

  /// Every workcenter's lines in one plant, as `workcenterId → lineIds`.
  Stream<Map<String, Set<String>>> watchWorkcenterLines(String plantId) {
    final query = _db.select(_db.workcenterLines).join([
      innerJoin(
        _db.workcenters,
        _db.workcenters.id.equalsExp(_db.workcenterLines.workcenterId),
      ),
    ])..where(_db.workcenters.plantId.equals(plantId));

    return query.watch().map((rows) {
      final byWorkcenter = <String, Set<String>>{};
      for (final row in rows) {
        final link = row.readTable(_db.workcenterLines);
        (byWorkcenter[link.workcenterId] ??= {}).add(link.lineId);
      }
      return byWorkcenter;
    });
  }

  Future<Set<String>> loadWorkcenterLines(String workcenterId) async {
    final rows = await (_db.select(
      _db.workcenterLines,
    )..where((l) => l.workcenterId.equals(workcenterId))).get();
    return {for (final row in rows) row.lineId};
  }

  /// Draws a workcenter under exactly [lineIds] in the resource tree.
  ///
  /// Membership is **organisational only** and a *set*: `CLAD04` genuinely
  /// serves two lines in a real plant. Any study of any line can target any
  /// workcenter of the plant either way, which is what makes cross-line
  /// contention possible (DESIGN.md §7.7).
  Future<void> setWorkcenterLines(
    String workcenterId,
    Set<String> lineIds,
  ) => _db.transaction(() async {
    await (_db.delete(
      _db.workcenterLines,
    )..where((l) => l.workcenterId.equals(workcenterId))).go();

    if (lineIds.isEmpty) return;
    final now = DateTime.now();
    await _db.batch((b) {
      for (final lineId in lineIds) {
        b.insert(
          _db.workcenterLines,
          WorkcenterLinesCompanion.insert(
            workcenterId: workcenterId,
            lineId: lineId,
            createdAt: now,
          ),
        );
      }
    });
  });

  /// Adds one line without disturbing the others — "add existing" in the tree.
  ///
  /// This is the operation the single `home_line_id` could not express: filing
  /// a workcenter under a second line used to take it out of the first.
  Future<void> addWorkcenterToLine(String workcenterId, String lineId) =>
      _db
          .into(_db.workcenterLines)
          .insert(
            WorkcenterLinesCompanion.insert(
              workcenterId: workcenterId,
              lineId: lineId,
              createdAt: DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );

  /// Takes a workcenter out of one line's group. The workcenter itself is
  /// untouched — it still belongs to the plant, and every study still reaches
  /// it.
  Future<void> removeWorkcenterFromLine(String workcenterId, String lineId) =>
      (_db.delete(_db.workcenterLines)..where(
            (l) =>
                l.workcenterId.equals(workcenterId) & l.lineId.equals(lineId),
          ))
          .go();

  Future<void> setWorkcenterArchived(String id, bool archived) =>
      (_db.update(_db.workcenters)..where((w) => w.id.equals(id))).write(
        WorkcentersCompanion(
          archivedAt: Value(archived ? DateTime.now() : null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deleteWorkcenter(String id) =>
      (_db.delete(_db.workcenters)..where((w) => w.id.equals(id))).go();

  // --- Workcenter types ---------------------------------------------------

  Stream<List<WorkcenterType>> watchWorkcenterTypes({
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.workcenterTypes)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (!includeArchived) query.where((t) => t.archivedAt.isNull());
    return query.watch();
  }

  Future<String> createWorkcenterType(String name) async {
    final id = newId();
    await _db
        .into(_db.workcenterTypes)
        .insert(
          WorkcenterTypesCompanion.insert(
            id: id,
            name: name,
            createdAt: DateTime.now(),
          ),
        );
    return id;
  }

  Future<void> renameWorkcenterType(String id, String name) =>
      (_db.update(_db.workcenterTypes)..where((t) => t.id.equals(id))).write(
        WorkcenterTypesCompanion(name: Value(name)),
      );

  Future<void> setWorkcenterTypeArchived(String id, bool archived) =>
      (_db.update(_db.workcenterTypes)..where((t) => t.id.equals(id))).write(
        WorkcenterTypesCompanion(
          archivedAt: Value(archived ? DateTime.now() : null),
        ),
      );

  Future<void> deleteWorkcenterType(String id) =>
      (_db.delete(_db.workcenterTypes)..where((t) => t.id.equals(id))).go();

  // --- Pools --------------------------------------------------------------

  Stream<List<WorkcenterPool>> watchPools(
    String plantId, {
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.workcenterPools)
      ..where((p) => p.plantId.equals(plantId))
      ..orderBy([(p) => OrderingTerm(expression: p.name)]);
    if (!includeArchived) query.where((p) => p.archivedAt.isNull());
    return query.watch();
  }

  /// The workcenters in a pool, ordered by name — which is also the last tie
  /// break when the simulation picks a member (DESIGN.md §3.1).
  Stream<List<Workcenter>> watchPoolMembers(String poolId) {
    final query =
        _db.select(_db.workcenters).join([
            innerJoin(
              _db.workcenterPoolMembers,
              _db.workcenterPoolMembers.workcenterId.equalsExp(
                _db.workcenters.id,
              ),
            ),
          ])
          ..where(_db.workcenterPoolMembers.poolId.equals(poolId))
          ..orderBy([OrderingTerm(expression: _db.workcenters.name)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(_db.workcenters)).toList(),
    );
  }

  /// Every pool's membership in the plant, keyed by pool id.
  ///
  /// One query for the whole plant: the flow view needs the members of any pool
  /// a step targets, and a stream per pool would multiply with the map.
  Stream<Map<String, List<String>>> watchPoolMembership(String plantId) {
    final query =
        _db.select(_db.workcenterPoolMembers).join([
            innerJoin(
              _db.workcenterPools,
              _db.workcenterPools.id.equalsExp(
                _db.workcenterPoolMembers.poolId,
              ),
            ),
            innerJoin(
              _db.workcenters,
              _db.workcenters.id.equalsExp(
                _db.workcenterPoolMembers.workcenterId,
              ),
            ),
          ])
          ..where(_db.workcenterPools.plantId.equals(plantId))
          ..orderBy([OrderingTerm(expression: _db.workcenters.name)]);
    return query.watch().map((rows) {
      final membership = <String, List<String>>{};
      for (final row in rows) {
        final member = row.readTable(_db.workcenterPoolMembers);
        membership
            .putIfAbsent(member.poolId, () => [])
            .add(member.workcenterId);
      }
      return membership;
    });
  }

  Future<String> createPool({
    required String plantId,
    required String name,
  }) async {
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.workcenterPools)
        .insert(
          WorkcenterPoolsCompanion.insert(
            id: id,
            plantId: plantId,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> renamePool(String id, String name) =>
      (_db.update(_db.workcenterPools)..where((p) => p.id.equals(id))).write(
        WorkcenterPoolsCompanion(
          name: Value(name),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setPoolArchived(String id, bool archived) =>
      (_db.update(_db.workcenterPools)..where((p) => p.id.equals(id))).write(
        WorkcenterPoolsCompanion(
          archivedAt: Value(archived ? DateTime.now() : null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deletePool(String id) =>
      (_db.delete(_db.workcenterPools)..where((p) => p.id.equals(id))).go();

  /// Replaces a pool's membership in one transaction, so no reader ever sees a
  /// pool that has been emptied but not refilled.
  Future<void> setPoolMembers(String poolId, Set<String> workcenterIds) =>
      _db.transaction(() async {
        await (_db.delete(
          _db.workcenterPoolMembers,
        )..where((m) => m.poolId.equals(poolId))).go();
        final now = DateTime.now();
        await _db.batch((b) {
          for (final workcenterId in workcenterIds) {
            b.insert(
              _db.workcenterPoolMembers,
              WorkcenterPoolMembersCompanion.insert(
                poolId: poolId,
                workcenterId: workcenterId,
                createdAt: now,
              ),
            );
          }
        });
      });

  // --- Shift patterns -----------------------------------------------------

  Stream<List<ShiftPattern>> watchShiftPatterns({
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.shiftPatterns)
      ..orderBy([(p) => OrderingTerm(expression: p.name)]);
    if (!includeArchived) query.where((p) => p.archivedAt.isNull());
    return query.watch();
  }

  Stream<List<PatternShift>> watchPatternShifts(String patternId) =>
      (_db.select(_db.patternShifts)
            ..where((s) => s.patternId.equals(patternId))
            ..orderBy([(s) => OrderingTerm(expression: s.position)]))
          .watch();

  /// Assembles the pure value object the calendar engine runs on
  /// (DESIGN.md §4). The one place database rows become calendar input.
  Future<ShiftPatternSpec?> loadPatternSpec(String patternId) async {
    final pattern = await (_db.select(
      _db.shiftPatterns,
    )..where((p) => p.id.equals(patternId))).getSingleOrNull();
    if (pattern == null) return null;
    final shifts =
        await (_db.select(_db.patternShifts)
              ..where((s) => s.patternId.equals(patternId))
              ..orderBy([(s) => OrderingTerm(expression: s.position)]))
            .get();
    return ShiftPatternSpec(
      name: pattern.name,
      cycleType: pattern.cycleType,
      workingWeekdays: pattern.workingWeekdays,
      shifts: [
        for (final shift in shifts)
          ShiftWindow(
            label: shift.label,
            position: shift.position,
            startMinute: shift.startMinute,
            endMinute: shift.endMinute,
            breakSeconds: shift.breakSeconds,
          ),
      ],
    );
  }

  Future<String> createShiftPattern({
    required String name,
    required ShiftCycleType cycleType,
    required int workingWeekdays,
    String? notes,
  }) async {
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.shiftPatterns)
        .insert(
          ShiftPatternsCompanion.insert(
            id: id,
            name: name,
            cycleType: cycleType,
            workingWeekdays: workingWeekdays,
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updateShiftPattern(
    String id, {
    required String name,
    required ShiftCycleType cycleType,
    required int workingWeekdays,
    String? notes,
  }) => (_db.update(_db.shiftPatterns)..where((p) => p.id.equals(id))).write(
    ShiftPatternsCompanion(
      name: Value(name),
      cycleType: Value(cycleType),
      workingWeekdays: Value(workingWeekdays),
      notes: Value(notes),
      updatedAt: Value(DateTime.now()),
    ),
  );

  Future<void> setShiftPatternArchived(String id, bool archived) =>
      (_db.update(_db.shiftPatterns)..where((p) => p.id.equals(id))).write(
        ShiftPatternsCompanion(
          archivedAt: Value(archived ? DateTime.now() : null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deleteShiftPattern(String id) =>
      (_db.delete(_db.shiftPatterns)..where((p) => p.id.equals(id))).go();

  /// Replaces a pattern's shifts wholesale, renumbering [ShiftWindow.position]
  /// from the list order.
  ///
  /// Replace rather than diff: the editor works on the whole list at once, and
  /// a partial update is how a pattern ends up with two shifts claiming
  /// position 1 — which the operators-per-shift list indexes into.
  Future<void> setPatternShifts(String patternId, List<ShiftWindow> shifts) =>
      _db.transaction(() async {
        await (_db.delete(
          _db.patternShifts,
        )..where((s) => s.patternId.equals(patternId))).go();
        await _db.batch((b) {
          for (var i = 0; i < shifts.length; i++) {
            final shift = shifts[i];
            b.insert(
              _db.patternShifts,
              PatternShiftsCompanion.insert(
                id: newId(),
                patternId: patternId,
                label: shift.label,
                position: i,
                startMinute: shift.startMinute,
                endMinute: shift.endMinute,
                breakSeconds: Value(shift.breakSeconds),
              ),
            );
          }
        });
        await (_db.update(_db.shiftPatterns)
              ..where((p) => p.id.equals(patternId)))
            .write(ShiftPatternsCompanion(updatedAt: Value(DateTime.now())));
      });
}
