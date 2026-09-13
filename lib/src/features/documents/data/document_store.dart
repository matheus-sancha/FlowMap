import 'dart:io';

import 'package:drift/drift.dart';

import 'flowmap_document.dart';

/// Loads a `.flowmap` into the working database, and writes it back out.
///
/// **The working database holds exactly one document at a time** (#37). Opening
/// empties every plant and project table and inserts the document whole, so
/// what is in the database *is* what is in the file — which is the only way
/// collisions stay impossible. `workcenter_types.name` and
/// `shift_patterns.name` are unique and `seedReferenceData` installs built-ins
/// on every machine and re-seeds on every upgrade, so a merge would collide by
/// name every single time.
///
/// **Runs are not touched by any of this.** They belong to a document id rather
/// than a project row (v32), which is the whole reason that migration exists:
/// this class deletes from `projects`, and before v32 that cascade would have
/// taken every stored run with it.
class DocumentStore {
  const DocumentStore(this._db);

  final GeneratedDatabase _db;

  /// The tables the working database holds on behalf of the open document,
  /// **in dependency order** — parents first.
  static List<String> get workingTables => [
    ...FlowmapDocument.plantTables,
    ...FlowmapDocument.projectTables,
  ];

  /// Replaces everything in the working database with [document].
  ///
  /// **Foreign keys are off for the duration.** A bulk swap cannot satisfy them
  /// row by row: deleting a plant before its workcenters, or inserting a
  /// workcenter before its type, is unavoidable in any single ordering that
  /// also has to handle the rows already there. They are enforced again
  /// afterwards, and [checkIntegrity] is what proves the result is sound rather
  /// than merely quiet.
  ///
  /// Not a transaction, deliberately: SQLite refuses to change `foreign_keys`
  /// inside one, which is the same constraint `onUpgrade` lives under and for
  /// the same reason.
  Future<void> load(FlowmapDocument document) async {
    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      // Children first, so a half-finished clear leaves less that references
      // something gone.
      for (final table in workingTables.reversed) {
        await _db.customStatement('DELETE FROM "$table"');
      }

      for (final table in workingTables) {
        final rows = document.plant[table] ?? document.project[table];
        if (rows == null || rows.isEmpty) continue;
        for (final row in rows) {
          await _insert(table, row);
        }
      }
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }
  }

  /// Writes one row by the columns it actually has.
  ///
  /// **Never a column list written by hand**, which is the rule the whole
  /// document format is built on (#30): the row says which columns it carries
  /// and they go in as they are. A document written by a build with a column
  /// this one lacks is refused here rather than silently dropping it.
  Future<void> _insert(String table, Map<String, Object?> row) async {
    final known = _columnsOf(table);
    final unknown = row.keys.where((c) => !known.contains(c)).toList();
    if (unknown.isNotEmpty) {
      throw DocumentFormatException(
        'This document has data this version of FlowMap does not understand '
        '($table.${unknown.join(', ')}). Open it with a newer FlowMap.',
      );
    }

    final columns = row.keys.toList();
    final placeholders = List.filled(columns.length, '?').join(', ');
    final quoted = columns.map((c) => '"$c"').join(', ');
    await _db.customInsert(
      'INSERT INTO "$table" ($quoted) VALUES ($placeholders)',
      variables: [for (final c in columns) Variable(row[c])],
    );
  }

  Set<String> _columnsOf(String table) {
    for (final info in _db.allTables) {
      if (info.actualTableName == table) {
        return {for (final column in info.$columns) column.name};
      }
    }
    return const {};
  }

  /// Asks SQLite whether the loaded document left anything dangling.
  ///
  /// Foreign keys are off during a load, so nothing complains at the time. This
  /// is how a document that references a workcenter it does not carry is caught
  /// at all — and it is cheap, because a document is ~765 rows.
  Future<List<String>> checkIntegrity() async {
    final rows = await _db.customSelect('PRAGMA foreign_key_check').get();
    return [
      for (final row in rows)
        '${row.data['table']} row ${row.data['rowid']} references a missing '
            '${row.data['parent']}',
    ];
  }

  /// Reads the open document out of the working database.
  Future<FlowmapDocument> capture({
    required String projectId,
    required String projectName,
  }) => FlowmapDocument.fromDatabase(
    _db,
    projectId: projectId,
    projectName: projectName,
  );

  /// Writes [bytes] to [file] **whole, or not at all**.
  ///
  /// A temporary sibling is written and flushed, then renamed over the target.
  /// Rename is atomic on the same volume, so a reader — or a sync client —
  /// observes either the old document or the new one and never half of either.
  ///
  /// That is not a detail: #37 put documents on OneDrive and network shares by
  /// design, and `app_directory.dart` records what a sync client does to a file
  /// it catches mid-write. A zipped document is only safe there because of this
  /// method.
  static Future<void> writeAtomically(File file, Uint8List bytes) async {
    final temp = File('${file.path}.saving');
    final handle = await temp.open(mode: FileMode.write);
    try {
      await handle.writeFrom(bytes);
      await handle.flush();
    } finally {
      await handle.close();
    }
    await temp.rename(file.path);
  }
}
