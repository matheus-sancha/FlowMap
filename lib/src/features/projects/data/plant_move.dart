import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// What moving a project to another plant finds, makes and carries.
class PlantMoveReport {
  const PlantMoveReport({
    required this.matched,
    required this.created,
    required this.studies,
  });

  /// Names already on the other plant, which the project now points at.
  final List<String> matched;

  /// Names that were not there, and are made from the rows they replace.
  final List<String> created;

  /// How many studies go with the project.
  final int studies;
}

/// Moves a project to another plant of its document (phase 8).
///
/// **Every project column that names a plant row is re-pointed**, and none is
/// left naming the old plant:
///
/// | column | names |
/// |---|---|
/// | `projects.plant_id` | the plant |
/// | `studies.production_cell_id`, `production_line_id` | a cell, a line |
/// | `studies.pace_setter_target_id`, `project_queues.target_id` | a workcenter or a pool |
/// | `flow_nodes.workcenter_id`, `pool_id` | a workcenter, a pool |
/// | `workcenter_schedule_periods.workcenter_id` | a workcenter |
/// | `takt_periods.production_line_id` | a line |
/// | `calendar_exceptions.scope_id` | a line or a workcenter |
///
/// `part_process_times` is keyed by flow node, not by target, so it follows its
/// node without being touched.
///
/// **The rule is #23's**: a row is matched **by name on the other plant** — a
/// line by name under its cell — and one that is not there is made. Unlike a
/// template, a move has the original row to hand, so what is made is a **copy
/// of that row** rather than a stub: its capacity, its type, its crew, and every
/// column added after this was written (#30). A pool is made over all its
/// members, never a subset.
///
/// **The old plant is left exactly as it was.** Moving back finds every name
/// it left behind, so a move is undone by another move.
class PlantMove {
  const PlantMove(this._db);

  final GeneratedDatabase _db;
  static const _uuid = Uuid();

  /// What [apply] would do, without writing anything.
  Future<PlantMoveReport> preview({
    required String projectId,
    String? toPlantId,
    String? newPlantName,
  }) => _run(
    projectId: projectId,
    toPlantId: toPlantId,
    newPlantName: newPlantName,
    write: false,
  );

  /// Moves the project to [toPlantId], or to a new plant named [newPlantName],
  /// in one transaction.
  Future<PlantMoveReport> apply({
    required String projectId,
    String? toPlantId,
    String? newPlantName,
  }) => _db.transaction(
    () => _run(
      projectId: projectId,
      toPlantId: toPlantId,
      newPlantName: newPlantName,
      write: true,
    ),
  );

  Future<PlantMoveReport> _run({
    required String projectId,
    required String? toPlantId,
    required String? newPlantName,
    required bool write,
  }) async {
    assert(
      (toPlantId == null) != (newPlantName == null),
      'a move goes to an existing plant or a new one, not both',
    );
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final matched = <String>[];
    final created = <String>[];

    Future<List<Map<String, Object?>>> rows(
      String sql, [
      List<Object?> args = const [],
    ]) async => [
      for (final row in await _db
          .customSelect(sql, variables: [for (final a in args) Variable(a)])
          .get())
        Map<String, Object?>.from(row.data),
    ];
    Future<Set<String>> ids(String sql, [List<Object?> args = const []]) async =>
        {
          for (final row in await rows(sql, args))
            if (row.values.first case final String id) id,
        };

    // **Every write names its table**, so the document session sees the move
    // and saves it, and every list on screen re-reads.
    Set<TableInfo> touches(String table) => {
      _db.allTables.firstWhere((t) => t.actualTableName == table),
    };

    /// A new id when writing; a stand-in that matches nothing when previewing,
    /// so a preview walks exactly the path the move will.
    String newId() => write ? _uuid.v4() : 'preview:${_uuid.v4()}';

    Future<void> insert(String table, Map<String, Object?> row) async {
      if (!write) return;
      final columns = row.keys.toList();
      await _db.customInsert(
        'INSERT INTO "$table" (${columns.map((c) => '"$c"').join(', ')}) '
        'VALUES (${List.filled(columns.length, '?').join(', ')})',
        variables: [for (final c in columns) Variable(row[c])],
        updates: touches(table),
      );
    }

    /// [source] with a new identity under a new parent — every other column
    /// as it was, including ones this file has never heard of.
    Map<String, Object?> copyOf(
      Map<String, Object?> source,
      String id,
      Map<String, Object?> parent,
    ) => {
      ...source,
      'id': id,
      ...parent,
      if (source.containsKey('created_at')) 'created_at': now,
      if (source.containsKey('updated_at')) 'updated_at': now,
    };

    // --- the plant it goes to -------------------------------------------------
    final project = (await rows(
      'SELECT plant_id FROM projects WHERE id = ?',
      [projectId],
    )).single;
    final fromPlantId = project['plant_id']! as String;
    final studyCount = (await ids(
      'SELECT id FROM studies WHERE project_id = ?',
      [projectId],
    )).length;

    final String plantId;
    if (toPlantId != null) {
      plantId = toPlantId;
      if (plantId == fromPlantId) {
        return PlantMoveReport(
          matched: const [],
          created: const [],
          studies: studyCount,
        );
      }
    } else {
      plantId = newId();
      await insert('plants', {
        'id': plantId,
        'name': newPlantName,
        'created_at': now,
        'updated_at': now,
      });
    }

    // --- what the project uses of the plant it leaves -------------------------
    const inProject = 'study_id IN (SELECT id FROM studies WHERE project_id = ?)';
    final targets = {
      ...await ids(
        'SELECT pace_setter_target_id FROM studies WHERE project_id = ?',
        [projectId],
      ),
      ...await ids(
        'SELECT target_id FROM project_queues WHERE project_id = ?',
        [projectId],
      ),
    };

    Future<List<Map<String, Object?>>> onOldPlant(
      String table,
      Set<String> wanted,
    ) async {
      if (wanted.isEmpty) return const [];
      final marks = List.filled(wanted.length, '?').join(', ');
      return rows(
        'SELECT * FROM "$table" WHERE plant_id = ? AND id IN ($marks)',
        [fromPlantId, ...wanted],
      );
    }

    final lineIds = {
      ...await ids(
        'SELECT production_line_id FROM studies WHERE project_id = ?',
        [projectId],
      ),
      ...await ids(
        'SELECT production_line_id FROM takt_periods WHERE project_id = ?',
        [projectId],
      ),
      ...await ids(
        "SELECT scope_id FROM calendar_exceptions WHERE project_id = ? "
        "AND scope = 'productionLine'",
        [projectId],
      ),
    };
    final sourceLines = lineIds.isEmpty
        ? const <Map<String, Object?>>[]
        : await rows(
            'SELECT l.* FROM production_lines l '
            'JOIN production_cells c ON c.id = l.cell_id '
            'WHERE c.plant_id = ? AND l.id IN '
            '(${List.filled(lineIds.length, '?').join(', ')})',
            [fromPlantId, ...lineIds],
          );

    final sourceCells = await onOldPlant('production_cells', {
      ...await ids(
        'SELECT production_cell_id FROM studies WHERE project_id = ?',
        [projectId],
      ),
      for (final line in sourceLines) line['cell_id']! as String,
    });

    final sourcePools = await onOldPlant('workcenter_pools', {
      ...await ids('SELECT pool_id FROM flow_nodes WHERE $inProject', [
        projectId,
      ]),
      ...targets,
    });

    // --- cells, then the lines under them -------------------------------------
    final cellMap = <String, String>{};
    for (final cell in sourceCells) {
      final name = cell['name']! as String;
      final found = await ids(
        'SELECT id FROM production_cells WHERE plant_id = ? AND name = ?',
        [plantId, name],
      );
      if (found.isNotEmpty) {
        cellMap[cell['id']! as String] = found.single;
        matched.add(name);
      } else {
        final id = newId();
        await insert('production_cells', copyOf(cell, id, {'plant_id': plantId}));
        cellMap[cell['id']! as String] = id;
        created.add(name);
      }
    }

    final lineMap = <String, String>{};
    for (final line in sourceLines) {
      final name = line['name']! as String;
      final cellId = cellMap[line['cell_id']]!;
      final found = await ids(
        'SELECT id FROM production_lines WHERE cell_id = ? AND name = ?',
        [cellId, name],
      );
      if (found.isNotEmpty) {
        lineMap[line['id']! as String] = found.single;
        matched.add(name);
      } else {
        final id = newId();
        await insert('production_lines', copyOf(line, id, {'cell_id': cellId}));
        lineMap[line['id']! as String] = id;
        created.add(name);
      }
    }

    // --- pools are looked up first, because a pool that has to be made needs
    // --- every one of its members ----------------------------------------------
    final poolMap = <String, String>{};
    final poolsToMake = <Map<String, Object?>>[];
    for (final pool in sourcePools) {
      final name = pool['name']! as String;
      final found = await ids(
        'SELECT id FROM workcenter_pools WHERE plant_id = ? AND name = ?',
        [plantId, name],
      );
      if (found.isNotEmpty) {
        poolMap[pool['id']! as String] = found.single;
        matched.add(name);
      } else {
        poolsToMake.add(pool);
      }
    }
    final membersOf = <String, Set<String>>{
      for (final pool in poolsToMake)
        pool['id']! as String: await ids(
          'SELECT workcenter_id FROM workcenter_pool_members WHERE pool_id = ?',
          [pool['id']],
        ),
    };

    // --- workcenters ----------------------------------------------------------
    final sourceWorkcenters = await onOldPlant('workcenters', {
      ...await ids('SELECT workcenter_id FROM flow_nodes WHERE $inProject', [
        projectId,
      ]),
      ...await ids(
        'SELECT workcenter_id FROM workcenter_schedule_periods '
        'WHERE project_id = ?',
        [projectId],
      ),
      ...await ids(
        "SELECT scope_id FROM calendar_exceptions WHERE project_id = ? "
        "AND scope = 'workcenter'",
        [projectId],
      ),
      ...targets,
      for (final members in membersOf.values) ...members,
    });

    final workcenterMap = <String, String>{};
    for (final workcenter in sourceWorkcenters) {
      final name = workcenter['name']! as String;
      final sourceId = workcenter['id']! as String;
      final found = await ids(
        'SELECT id FROM workcenters WHERE plant_id = ? AND name = ?',
        [plantId, name],
      );
      if (found.isNotEmpty) {
        workcenterMap[sourceId] = found.single;
        matched.add(name);
        continue;
      }
      final id = newId();
      await insert('workcenters', copyOf(workcenter, id, {'plant_id': plantId}));
      workcenterMap[sourceId] = id;
      created.add(name);

      // Filed under the lines its original was, where those lines came along.
      for (final lineId in await ids(
        'SELECT line_id FROM workcenter_lines WHERE workcenter_id = ?',
        [sourceId],
      )) {
        if (lineMap[lineId] case final mapped?) {
          await insert('workcenter_lines', {
            'workcenter_id': id,
            'line_id': mapped,
            'created_at': now,
          });
        }
      }
    }

    for (final pool in poolsToMake) {
      final sourceId = pool['id']! as String;
      final id = newId();
      await insert('workcenter_pools', copyOf(pool, id, {'plant_id': plantId}));
      for (final member in membersOf[sourceId]!) {
        await insert('workcenter_pool_members', {
          'pool_id': id,
          'workcenter_id': workcenterMap[member],
          'created_at': now,
        });
      }
      poolMap[sourceId] = id;
      created.add(pool['name']! as String);
    }

    // --- re-point the project -------------------------------------------------
    if (write) {
      Future<void> repoint(
        String table,
        String column,
        Map<String, String> map, {
        String scope = 'project_id = ?',
      }) async {
        for (final MapEntry(key: from, value: to) in map.entries) {
          await _db.customUpdate(
            'UPDATE "$table" SET "$column" = ? WHERE "$column" = ? AND $scope',
            variables: [Variable(to), Variable(from), Variable(projectId)],
            updates: touches(table),
            updateKind: UpdateKind.update,
          );
        }
      }

      final targetMap = {...workcenterMap, ...poolMap};
      await _db.customUpdate(
        'UPDATE projects SET plant_id = ?, updated_at = ? WHERE id = ?',
        variables: [Variable(plantId), Variable(now), Variable(projectId)],
        updates: touches('projects'),
        updateKind: UpdateKind.update,
      );
      await repoint('studies', 'production_cell_id', cellMap);
      await repoint('studies', 'production_line_id', lineMap);
      await repoint('studies', 'pace_setter_target_id', targetMap);
      await repoint('flow_nodes', 'workcenter_id', workcenterMap, scope: inProject);
      await repoint('flow_nodes', 'pool_id', poolMap, scope: inProject);
      await repoint('project_queues', 'target_id', targetMap);
      await repoint('workcenter_schedule_periods', 'workcenter_id', workcenterMap);
      await repoint('takt_periods', 'production_line_id', lineMap);
      await repoint(
        'calendar_exceptions',
        'scope_id',
        {...lineMap, ...workcenterMap},
      );
    }

    return PlantMoveReport(
      matched: matched.toSet().toList()..sort(),
      created: created.toSet().toList()..sort(),
      studies: studyCount,
    );
  }
}
