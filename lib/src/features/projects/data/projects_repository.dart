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

  Future<Project?> loadProject(String id) => (_db.select(
    _db.projects,
  )..where((p) => p.id.equals(id))).getSingleOrNull();

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
  Future<void> updateProject(
    String id, {
    required String name,
    required String shiftPatternId,
    String? notes,
  }) => (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
    ProjectsCompanion(
      name: Value(name),
      shiftPatternId: Value(shiftPatternId),
      notes: Value(notes),
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
