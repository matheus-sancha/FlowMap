import 'package:drift/drift.dart';

import '../../../data/database/database.dart';

/// The demand table of one study: its parts, their process times per step
/// target, and the order sequence (DESIGN.md §9, §7.2).
///
/// One repository rather than three, for the same reason the flow spine lives
/// inside [StudiesRepository]: none of the three has a life outside its study,
/// every read is scoped to one, and the structural edits — insert an order,
/// reorder, delete — have to renumber siblings in the transaction that changes
/// one row.
class DemandRepository {
  DemandRepository(this._db);

  final AppDatabase _db;

  // --- Parts ---------------------------------------------------------------

  Stream<List<DemandPart>> watchParts(String studyId) =>
      (_db.select(_db.demandParts)
            ..where((p) => p.studyId.equals(studyId))
            ..orderBy([(p) => OrderingTerm(expression: p.partNumber)]))
          .watch();

  Future<List<DemandPart>> loadParts(String studyId) =>
      (_db.select(_db.demandParts)
            ..where((p) => p.studyId.equals(studyId))
            ..orderBy([(p) => OrderingTerm(expression: p.partNumber)]))
          .get();

  Future<String> createPart({
    required String studyId,
    required String partNumber,
    String? customerProject,
    String? description,
  }) async {
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.demandParts)
        .insert(
          DemandPartsCompanion.insert(
            id: id,
            studyId: studyId,
            partNumber: partNumber,
            customerProject: Value(customerProject),
            description: Value(description),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updatePart(
    String id, {
    required String partNumber,
    String? customerProject,
    String? description,
  }) => (_db.update(_db.demandParts)..where((p) => p.id.equals(id))).write(
    DemandPartsCompanion(
      partNumber: Value(partNumber),
      customerProject: Value(customerProject),
      description: Value(description),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Removes a part, its process times and every order that referenced it.
  ///
  /// The orders go through [deleteOrder]'s renumbering rather than the foreign
  /// key's cascade: a cascade would leave holes in the sequence, and a sequence
  /// with holes is one the release slots (§7.2) cannot walk.
  Future<void> deletePart(String studyId, String id) =>
      _db.transaction(() async {
        await (_db.delete(
          _db.demandOrders,
        )..where((o) => o.partId.equals(id))).go();
        await (_db.delete(
          _db.demandParts,
        )..where((p) => p.id.equals(id))).go();
        await _renumberOrders(studyId);
      });

  // --- Process times -------------------------------------------------------

  /// Every process time in the study, as `partId → targetId → duration`.
  ///
  /// One query with a join rather than one per part: a study of ten steps and
  /// five hundred parts is five thousand cells, and the grid reads them all
  /// (§14).
  Stream<Map<String, Map<String, Duration>>> watchProcessTimes(String studyId) {
    final query = _db.select(_db.partProcessTimes).join([
      innerJoin(
        _db.demandParts,
        _db.demandParts.id.equalsExp(_db.partProcessTimes.partId),
      ),
    ])..where(_db.demandParts.studyId.equals(studyId));

    return query.watch().map((rows) {
      final times = <String, Map<String, Duration>>{};
      for (final row in rows) {
        final cell = row.readTable(_db.partProcessTimes);
        (times[cell.partId] ??= {})[cell.targetId] = Duration(
          seconds: cell.seconds,
        );
      }
      return times;
    });
  }

  /// Writes one cell, or clears it when [time] is null.
  ///
  /// **Null deletes the row rather than storing a zero.** A part that skips a
  /// step has no row at all (§5.1), which is what keeps "not routed here" and
  /// "takes no time" apart — and a zero silently standing in for a missing
  /// number is the failure §11 exists to prevent.
  Future<void> setProcessTime({
    required String partId,
    required String targetId,
    required Duration? time,
  }) async {
    if (time == null) {
      await (_db.delete(_db.partProcessTimes)..where(
            (t) => t.partId.equals(partId) & t.targetId.equals(targetId),
          ))
          .go();
      return;
    }
    await _db
        .into(_db.partProcessTimes)
        .insertOnConflictUpdate(
          PartProcessTimesCompanion.insert(
            partId: partId,
            targetId: targetId,
            seconds: time.inSeconds,
          ),
        );
  }

  /// Writes a block of cells in one transaction — what a paste from Excel is
  /// (§9), and what an import commits.
  Future<void> setProcessTimes(Iterable<ProcessTimeEdit> edits) =>
      _db.transaction(() async {
        for (final edit in edits) {
          await setProcessTime(
            partId: edit.partId,
            targetId: edit.targetId,
            time: edit.time,
          );
        }
      });

  // --- Orders --------------------------------------------------------------

  Stream<List<DemandOrder>> watchOrders(String studyId) =>
      (_db.select(_db.demandOrders)
            ..where((o) => o.studyId.equals(studyId))
            ..orderBy([(o) => OrderingTerm(expression: o.sequence)]))
          .watch();

  Future<List<DemandOrder>> loadOrders(String studyId) =>
      (_db.select(_db.demandOrders)
            ..where((o) => o.studyId.equals(studyId))
            ..orderBy([(o) => OrderingTerm(expression: o.sequence)]))
          .get();

  /// Appends an order to the end of the sequence.
  Future<String> createOrder({
    required String studyId,
    required String partId,
    required DateTime needDate,
    DateTime? materialDate,
    int batchSize = 1,
    int? atSequence,
  }) => _db.transaction(() async {
    final orders = await loadOrders(studyId);
    final position = (atSequence ?? orders.length).clamp(0, orders.length);
    final now = DateTime.now();

    // Shifted from the back so no intermediate state collides with the
    // (study, sequence) uniqueness constraint.
    for (var i = orders.length - 1; i >= position; i--) {
      await (_db.update(_db.demandOrders)
            ..where((o) => o.id.equals(orders[i].id)))
          .write(DemandOrdersCompanion(sequence: Value(i + 1)));
    }

    final id = newId();
    await _db
        .into(_db.demandOrders)
        .insert(
          DemandOrdersCompanion.insert(
            id: id,
            studyId: studyId,
            partId: partId,
            sequence: position,
            batchSize: Value(batchSize),
            needDate: needDate,
            materialDate: Value(materialDate),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  });

  Future<void> updateOrder(
    String id, {
    required String partId,
    required DateTime needDate,
    DateTime? materialDate,
    required int batchSize,
  }) => (_db.update(_db.demandOrders)..where((o) => o.id.equals(id))).write(
    DemandOrdersCompanion(
      partId: Value(partId),
      needDate: Value(needDate),
      materialDate: Value(materialDate),
      batchSize: Value(batchSize),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Empties the sequence, leaving the parts and their process times.
  ///
  /// A separate operation rather than a loop over [deleteOrder]: re-importing a
  /// month's demand starts by clearing the old one, and renumbering after each
  /// of two thousand deletions would be two thousand renumbers.
  Future<void> deleteAllOrders(String studyId) => (_db.delete(
    _db.demandOrders,
  )..where((o) => o.studyId.equals(studyId))).go();

  Future<void> deleteOrder(String studyId, String id) =>
      _db.transaction(() async {
        await (_db.delete(
          _db.demandOrders,
        )..where((o) => o.id.equals(id))).go();
        await _renumberOrders(studyId);
      });

  /// Moves the order at [from] to [to], keeping every other order's relative
  /// position — the resequencing MM3 exists to be improved by (§6.3).
  Future<void> moveOrder(String studyId, int from, int to) =>
      _db.transaction(() async {
        final orders = await loadOrders(studyId);
        if (from < 0 || from >= orders.length) return;
        final target = to.clamp(0, orders.length - 1);
        if (from == target) return;

        final reordered = [...orders];
        reordered.insert(target, reordered.removeAt(from));

        // Parked out of range first: sequence numbers are unique per study, so
        // a straight rewrite would collide part-way through.
        for (var i = 0; i < reordered.length; i++) {
          await (_db.update(_db.demandOrders)
                ..where((o) => o.id.equals(reordered[i].id)))
              .write(DemandOrdersCompanion(sequence: Value(-1 - i)));
        }
        for (var i = 0; i < reordered.length; i++) {
          await (_db.update(_db.demandOrders)
                ..where((o) => o.id.equals(reordered[i].id)))
              .write(DemandOrdersCompanion(sequence: Value(i)));
        }
      });

  Future<void> _renumberOrders(String studyId) async {
    final orders = await loadOrders(studyId);
    for (var i = 0; i < orders.length; i++) {
      if (orders[i].sequence == i) continue;
      await (_db.update(_db.demandOrders)
            ..where((o) => o.id.equals(orders[i].id)))
          .write(DemandOrdersCompanion(sequence: Value(i)));
    }
  }

  // --- Applying a pasted block --------------------------------------------

  /// Writes what [planPartsWrite] read out of a block, in one transaction.
  ///
  /// The plan keys its cells by **part number**, because a part it asks to
  /// create has no id until this runs. Resolving them is the only thing this
  /// method knows that the planner could not.
  Future<void> applyPartsPlan(String studyId, DemandPartsPlan plan) =>
      _db.transaction(() async {
        final ids = {
          for (final part in await loadParts(studyId))
            part.partNumber.toLowerCase(): part.id,
        };

        for (final write in plan.parts) {
          if (write.isNew) {
            ids[write.partNumber.toLowerCase()] = await createPart(
              studyId: studyId,
              partNumber: write.partNumber,
              customerProject: write.customerProject,
              description: write.description,
            );
          } else {
            await updatePart(
              write.id!,
              partNumber: write.partNumber,
              customerProject: write.customerProject,
              description: write.description,
            );
            ids[write.partNumber.toLowerCase()] = write.id!;
          }
        }

        await setProcessTimes([
          for (final cell in plan.times)
            if (ids[cell.partNumber.toLowerCase()] case final partId?)
              ProcessTimeEdit(
                partId: partId,
                targetId: cell.targetId,
                time: cell.time,
              ),
        ]);
      });

  /// Writes what [planSequenceWrite] read out of a block, in one transaction.
  Future<void> applySequenceWrites(
    String studyId,
    List<OrderWrite> writes,
  ) => _db.transaction(() async {
    for (final write in writes) {
      if (write.isNew) {
        await createOrder(
          studyId: studyId,
          partId: write.partId,
          needDate: write.needDate,
          materialDate: write.materialDate,
          batchSize: write.batchSize,
        );
      } else {
        await updateOrder(
          write.id!,
          partId: write.partId,
          needDate: write.needDate,
          materialDate: write.materialDate,
          batchSize: write.batchSize,
        );
      }
    }
  });

  // --- Duplication ---------------------------------------------------------

  /// Copies one study's demand onto another, as part of duplicating a study
  /// (DESIGN.md §10.1).
  ///
  /// Lives here rather than in [StudiesRepository] so the demand tables stay
  /// behind one door; the caller runs it inside its own transaction.
  Future<void> copyDemandInto({
    required String fromStudyId,
    required String toStudyId,
  }) async {
    final parts = await loadParts(fromStudyId);
    if (parts.isEmpty) return;

    final now = DateTime.now();
    final idMap = <String, String>{};
    for (final part in parts) {
      idMap[part.id] = newId();
    }

    await _db.batch((b) {
      for (final part in parts) {
        b.insert(
          _db.demandParts,
          DemandPartsCompanion.insert(
            id: idMap[part.id]!,
            studyId: toStudyId,
            partNumber: part.partNumber,
            customerProject: Value(part.customerProject),
            description: Value(part.description),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });

    final times = await (_db.select(_db.partProcessTimes).join([
      innerJoin(
        _db.demandParts,
        _db.demandParts.id.equalsExp(_db.partProcessTimes.partId),
      ),
    ])..where(_db.demandParts.studyId.equals(fromStudyId))).get();

    await _db.batch((b) {
      for (final row in times) {
        final cell = row.readTable(_db.partProcessTimes);
        b.insert(
          _db.partProcessTimes,
          PartProcessTimesCompanion.insert(
            partId: idMap[cell.partId]!,
            targetId: cell.targetId,
            seconds: cell.seconds,
          ),
        );
      }
    });

    final orders = await loadOrders(fromStudyId);
    await _db.batch((b) {
      for (final order in orders) {
        b.insert(
          _db.demandOrders,
          DemandOrdersCompanion.insert(
            id: newId(),
            studyId: toStudyId,
            partId: idMap[order.partId]!,
            sequence: order.sequence,
            batchSize: Value(order.batchSize),
            needDate: order.needDate,
            materialDate: Value(order.materialDate),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });
  }
}

/// One cell of the process-time grid, for a batched write.
class ProcessTimeEdit {
  const ProcessTimeEdit({
    required this.partId,
    required this.targetId,
    required this.time,
  });

  final String partId;
  final String targetId;

  /// Null clears the cell — "this part does not visit this step".
  final Duration? time;
}

// --- What a pasted block asks for ------------------------------------------
//
// Write intents rather than calculations, so they live beside the repository
// that carries them out. `application/demand_paste.dart` reads a block into
// these; nothing above it has to know how a part number becomes an id.

/// A part a block asks to exist, with the values it should carry.
class PartWrite {
  const PartWrite({
    required this.id,
    required this.partNumber,
    required this.customerProject,
    required this.description,
  });

  /// Null for a row past the end of the table — a part to be created.
  final String? id;

  final String partNumber;
  final String? customerProject;
  final String? description;

  bool get isNew => id == null;
}

/// A cell of the process-time grid a block asks to be written.
class PartTimeWrite {
  const PartTimeWrite({
    required this.partNumber,
    required this.targetId,
    required this.time,
  });

  /// Keyed by part number rather than id, because a part created by the same
  /// block has no id until the write happens.
  final String partNumber;

  final String targetId;

  /// Null clears the cell — the part does not visit that step (§5.1).
  final Duration? time;
}

/// What a block asks of the parts grid.
class DemandPartsPlan {
  const DemandPartsPlan({required this.parts, required this.times});

  /// Creates and updates, in row order. A part already carrying the values the
  /// block names is not listed — there is nothing to write.
  final List<PartWrite> parts;

  final List<PartTimeWrite> times;

  bool get isEmpty => parts.isEmpty && times.isEmpty;
}

/// An order a block asks to exist, with the values it should carry.
class OrderWrite {
  const OrderWrite({
    required this.id,
    required this.partId,
    required this.needDate,
    required this.materialDate,
    required this.batchSize,
  });

  /// Null for a row past the end of the sequence — an order to be appended.
  final String? id;

  final String partId;
  final DateTime needDate;
  final DateTime? materialDate;
  final int batchSize;

  bool get isNew => id == null;
}
