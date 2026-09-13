import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'flow_template.dart';

/// What applying a template did, so the report can say it in words.
class BindingResult {
  const BindingResult({
    required this.matched,
    required this.created,
    required this.studyId,
    required this.studyName,
  });

  /// Targets found on this plant by name.
  final List<String> matched;

  /// Targets that were not here and were made.
  final List<String> created;

  /// The study the template became.
  final String studyId;

  /// What it ended up called — the template's own name, or that name with a
  /// suffix when the project already had one.
  final String studyName;
}

/// Applies a template to the plant that is currently open.
///
/// **The rule is #23's, unchanged.** What binds is a **dispatch target** — a
/// workcenter xor a pool — matched **by name**, with what is missing created in
/// order: types, then workcenters, then the pools that hold them, members
/// resolved before the pool.
///
/// **Binding stopped being what opening a document does** (#37) and became this:
/// a document brings its own plant, but a template is a flow landing on a plant
/// that is not its own, which is the case #23 was written for.
///
/// **Three references live on the study's own row** and are bound here too:
/// `production_cell_id`, `production_line_id` and `pace_setter_target_id`. A
/// study is written `name (cell · line)` and is neither, so a study whose cell
/// and line did not bind cannot say where it is (#25, #29).
class TemplateBinding {
  const TemplateBinding(this._db);

  final GeneratedDatabase _db;
  static const _uuid = Uuid();

  Future<BindingResult> apply(
    FlowTemplate template, {
    required String projectId,
    required String plantId,
  }) async {
    final matched = <String>[];
    final created = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    Future<List<Map<String, Object?>>> q(String sql) async => [
      for (final row in await _db.customSelect(sql).get())
        Map<String, Object?>.from(row.data),
    ];
    String esc(String v) => v.replaceAll("'", "''");

    // --- types, first, because a created workcenter needs one -------------
    Future<String?> typeIdFor(String? typeName) async {
      if (typeName == null) return null;
      final existing = await q(
        "SELECT id FROM workcenter_types WHERE name = '${esc(typeName)}'",
      );
      if (existing.isNotEmpty) return existing.single['id'] as String;
      final id = _uuid.v4();
      await _db.customInsert(
        'INSERT INTO workcenter_types (id, name, is_built_in, created_at) '
        'VALUES (?, ?, 0, ?)',
        variables: [
          Variable<String>(id),
          Variable<String>(typeName),
          Variable<int>(now),
        ],
      );
      created.add(typeName);
      return id;
    }

    // --- workcenters ------------------------------------------------------
    final workcenterIds = <String, String>{};
    Future<String> workcenterIdFor(TargetRef ref) async {
      final existing = await q(
        "SELECT id FROM workcenters WHERE name = '${esc(ref.name)}'",
      );
      if (existing.isNotEmpty) {
        matched.add(ref.name);
        return existing.single['id'] as String;
      }
      final id = _uuid.v4();
      await _db.customInsert(
        'INSERT INTO workcenters (id, plant_id, type_id, name, '
        'parallel_capacity, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?)',
        variables: [
          Variable<String>(id),
          Variable<String>(plantId),
          Variable(await typeIdFor(ref.typeName)),
          Variable<String>(ref.name),
          Variable<int>(now),
          Variable<int>(now),
        ],
      );
      created.add(ref.name);
      return id;
    }

    for (final entry in template.targets.workcenters.entries) {
      workcenterIds[entry.key] = await workcenterIdFor(entry.value);
    }

    // --- pools, over members that now exist -------------------------------
    final poolIds = <String, String>{};
    for (final entry in template.targets.pools.entries) {
      final ref = entry.value;
      final existing = await q(
        "SELECT id FROM workcenter_pools WHERE name = '${esc(ref.name)}'",
      );
      if (existing.isNotEmpty) {
        poolIds[entry.key] = existing.single['id'] as String;
        matched.add(ref.name);
        continue;
      }

      final id = _uuid.v4();
      await _db.customInsert(
        'INSERT INTO workcenter_pools (id, plant_id, name, created_at, '
        'updated_at) VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable<String>(id),
          Variable<String>(plantId),
          Variable<String>(ref.name),
          Variable<int>(now),
          Variable<int>(now),
        ],
      );
      // **Never over a subset.** A pool of three landing as a pool of one
      // changes dispatch without saying so (#23), so any member not already
      // here is made.
      for (final member in ref.memberNames) {
        final id2 = await workcenterIdFor(TargetRef(name: member, typeName: null));
        await _db.customInsert(
          'INSERT OR IGNORE INTO workcenter_pool_members (pool_id, '
          'workcenter_id, created_at) VALUES (?, ?, ?)',
          variables: [
            Variable<String>(id),
            Variable<String>(id2),
            Variable<int>(now),
          ],
        );
      }
      poolIds[entry.key] = id;
      created.add(ref.name);
    }

    // --- the cell and line the study sat on -------------------------------
    Future<String?> cellIdFor(String? name) async {
      if (name == null) return null;
      final existing = await q(
        "SELECT id FROM production_cells WHERE name = '${esc(name)}'",
      );
      if (existing.isNotEmpty) return existing.single['id'] as String;
      final id = _uuid.v4();
      await _db.customInsert(
        'INSERT INTO production_cells (id, plant_id, name, created_at, '
        'updated_at) VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable<String>(id),
          Variable<String>(plantId),
          Variable<String>(name),
          Variable<int>(now),
          Variable<int>(now),
        ],
      );
      created.add(name);
      return id;
    }

    final cellId = await cellIdFor(template.targets.cellName);
    String? lineId;
    if (template.targets.lineName case final lineName?) {
      final existing = await q(
        "SELECT id FROM production_lines WHERE name = '${esc(lineName)}'",
      );
      if (existing.isNotEmpty) {
        lineId = existing.single['id'] as String;
      } else if (cellId != null) {
        lineId = _uuid.v4();
        await _db.customInsert(
          'INSERT INTO production_lines (id, cell_id, name, created_at, '
          'updated_at) VALUES (?, ?, ?, ?, ?)',
          variables: [
            Variable<String>(lineId),
            Variable<String>(cellId),
            Variable<String>(lineName),
            Variable<int>(now),
            Variable<int>(now),
          ],
        );
        created.add(lineName);
      }
    }

    // --- the study itself, with every id remade ---------------------------
    //
    // **And a name that is free.** `studies` is unique on (project, name), so
    // applying a template twice — or applying one whose study name a project
    // already uses — would fail outright. `duplicateStudy` takes a `newName`
    // for the same reason; here the app picks one rather than asking, because
    // applying a template is not the moment to stop and name things.
    final wanted = template.study['studies']!.single['name']! as String;
    var studyName = wanted;
    var attempt = 2;
    while ((await q(
      "SELECT id FROM studies WHERE project_id = '${esc(projectId)}' "
      "AND name = '${esc(studyName)}'",
    )).isNotEmpty) {
      studyName = '$wanted ($attempt)';
      attempt++;
    }

    final studyId = _uuid.v4();
    final nodeIds = <String, String>{
      for (final node in template.study['flow_nodes'] ?? const [])
        node['id']! as String: _uuid.v4(),
    };
    final partIds = <String, String>{
      for (final part in template.study['demand_parts'] ?? const [])
        part['id']! as String: _uuid.v4(),
    };

    Object? remap(String table, String column, Object? value) {
      if (value is! String) return value;
      return switch ((table, column)) {
        (_, 'study_id') => studyId,
        ('flow_nodes', 'id') => nodeIds[value] ?? value,
        (_, 'node_id') => nodeIds[value] ?? value,
        ('demand_parts', 'id') => partIds[value] ?? value,
        (_, 'part_id') => partIds[value] ?? value,
        ('demand_orders', 'id') => _uuid.v4(),
        ('flow_annotations', 'id') => _uuid.v4(),
        ('studies', 'id') => studyId,
        ('studies', 'project_id') => projectId,
        ('studies', 'production_cell_id') => cellId,
        ('studies', 'production_line_id') => lineId,
        ('studies', 'pace_setter_target_id') =>
          workcenterIds[value] ?? poolIds[value],
        ('flow_nodes', 'workcenter_id') => workcenterIds[value],
        ('flow_nodes', 'pool_id') => poolIds[value],
        _ => value,
      };
    }

    for (final table in FlowTemplate.studyTables) {
      for (final row in template.study[table] ?? const []) {
        final mapped = <String, Object?>{
          for (final column in row.entries)
            column.key: remap(table, column.key, column.value),
        };
        // **A copy is never included in a run.** Two flagged studies on one
        // production line is the state `setIncludedInSimulation` forbids, and
        // an applied template is exactly the second one.
        if (table == 'studies') {
          mapped['include_in_simulation'] = 0;
          mapped['name'] = studyName;
        }

        final columns = mapped.keys.toList();
        await _db.customInsert(
          'INSERT INTO "$table" (${columns.map((c) => '"$c"').join(', ')}) '
          'VALUES (${List.filled(columns.length, '?').join(', ')})',
          variables: [for (final c in columns) Variable(mapped[c])],
          updates: {},
        );
      }
    }

    return BindingResult(
      matched: matched.toSet().toList()..sort(),
      created: created.toSet().toList()..sort(),
      studyId: studyId,
      studyName: studyName,
    );
  }
}
