import 'package:drift/drift.dart';

import '../../../data/database/database.dart';

/// A project is one plant plus one shift pattern, and the container every
/// period-scoped number hangs off (DESIGN.md §3).
class ProjectsRepository {
  ProjectsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Project>> watchProjects({bool includeArchived = false}) {
    final query = _db.select(_db.projects)
      ..orderBy([(p) => OrderingTerm(expression: p.name)]);
    if (!includeArchived) query.where((p) => p.archivedAt.isNull());
    return query.watch();
  }

  Stream<Project?> watchProject(String id) => (_db.select(
    _db.projects,
  )..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<String> createProject({
    required String name,
    required String plantId,
    required String shiftPatternId,
    String? notes,
  }) async {
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: id,
            name: name,
            plantId: plantId,
            shiftPatternId: shiftPatternId,
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// The plant is deliberately not editable after creation.
  ///
  /// Every study, schedule period and flow node in the project references
  /// workcenters of that plant; repointing it would leave all of them dangling
  /// with no sensible remapping. Duplicating the project onto another plant is
  /// the operation that makes sense, and it is a different one.
  /// Writes the editable half of the row.
  ///
  /// **The float thresholds are absent rather than defaulted when omitted**
  /// (§10.4). A caller that does not care about them - the Projects list's
  /// Rename - leaves them out and they are not written, which is what
  /// `Value.absent()` is for and is the difference between "unchanged" and
  /// "set it back to zero".
  Future<void> updateProject(
    String id, {
    required String name,
    required String shiftPatternId,
    String? notes,
    int? floatRedDays,
    int? floatGreenDays,
    int? occupationAmberPct,
    int? occupationRedPct,
  }) => (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
    ProjectsCompanion(
      name: Value(name),
      shiftPatternId: Value(shiftPatternId),
      notes: Value(notes),
      floatRedDays: floatRedDays == null
          ? const Value.absent()
          : Value(floatRedDays),
      floatGreenDays: floatGreenDays == null
          ? const Value.absent()
          : Value(floatGreenDays),
      // #9's two, absent-when-null for the reason the float pair is: this
      // method writes every field it is given, so a caller editing one
      // threshold must not clear the other three.
      occupationAmberPct: occupationAmberPct == null
          ? const Value.absent()
          : Value(occupationAmberPct),
      occupationRedPct: occupationRedPct == null
          ? const Value.absent()
          : Value(occupationRedPct),
      updatedAt: Value(DateTime.now()),
    ),
  );

  Future<void> setProjectArchived(String id, bool archived) =>
      (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
        ProjectsCompanion(
          archivedAt: Value(archived ? DateTime.now() : null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deleteProject(String id) =>
      (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();
}
