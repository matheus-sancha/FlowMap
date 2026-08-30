import 'package:drift/drift.dart';

import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';

/// The queue in front of each dispatch target, for one project
/// (DESIGN.md §7.3, §5.5).
///
/// **Its own repository rather than a corner of the studies one.** A queue is
/// keyed `{projectId, targetId}` and shared by every study whose flow reaches
/// that target — that sharing is the whole correction §7.3 made — so it is not
/// a study's to own, and `StudiesRepository` exists precisely for the rows that
/// have no life outside one study. It is not the project row's either, and
/// hanging it off `ProjectsRepository` would put a per-station table in the
/// class that knows what a project *is*.
///
/// Lives in the flow feature because the map is where a queue is drawn and, as
/// of §7.3, where it is set: reading a rule on one surface and setting it on
/// another is the split §6.4 finished undoing on the Flow toolbar.
class FlowQueuesRepository {
  FlowQueuesRepository(this._db);

  final AppDatabase _db;

  /// Every queue the project has, by target.
  ///
  /// Whole-project rather than per study, which is what makes two studies
  /// through CLAD07 draw the same row: the map asks for the plant's queues and
  /// each step picks out its own.
  Stream<Map<String, ProjectQueue>> watchQueues(String projectId) =>
      (_db.select(_db.projectQueues)
            ..where((q) => q.projectId.equals(projectId)))
          .watch()
          .map((rows) => {for (final row in rows) row.targetId: row});

  /// Writes the queue in front of [targetId], creating the row if the target
  /// has never been configured.
  ///
  /// **Every field is passed on every call**, and null means "unset" rather
  /// than "leave alone". The editor is a dialog over the whole queue — the
  /// discipline, the capacity and what is standing there — so a partial write
  /// would be a second way to reach one row, and §12.6 is the record of what two
  /// write paths into one row cost. (The name went in v27: a queue is an aspect
  /// of its target and its caption is derived, so there is nothing to write.)
  Future<void> saveQueue({
    required String projectId,
    required String targetId,
    DispatchRule? rule,
    int? capacity,
    InventoryMode? stockMode,
    int? stockQuantity,
    int? stockSeconds,
    DurationUnit? stockUnit,
  }) {
    final now = DateTime.now();
    return _db
        .into(_db.projectQueues)
        .insert(
          ProjectQueuesCompanion.insert(
            projectId: projectId,
            targetId: targetId,
            rule: Value(rule),
            capacity: Value(capacity),
            stockMode: Value(stockMode),
            stockQuantity: Value(stockQuantity),
            stockSeconds: Value(stockSeconds),
            stockUnit: Value(stockUnit),
            createdAt: now,
            updatedAt: now,
          ),
          // Upsert on the composite key, and **the update leaves `createdAt`
          // alone**: when this floor space was first described is a fact about
          // the project, and `insertOnConflictUpdate` would quietly restamp it
          // on every edit.
          onConflict: DoUpdate(
            (_) => ProjectQueuesCompanion(
              rule: Value(rule),
              capacity: Value(capacity),
              stockMode: Value(stockMode),
              stockQuantity: Value(stockQuantity),
              stockSeconds: Value(stockSeconds),
              stockUnit: Value(stockUnit),
              updatedAt: Value(now),
            ),
            target: [_db.projectQueues.projectId, _db.projectQueues.targetId],
          ),
        );
  }
}
