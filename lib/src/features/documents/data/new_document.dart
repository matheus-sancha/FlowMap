import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../data/database/database.dart';
import 'document_store.dart';

/// Builds a new, empty document.
///
/// **It starts with the reference data and nothing else** — the seeded
/// workcenter types and shift patterns a fresh install has always had. No
/// example plant, no sample studies: a reference plant is something you *open*
/// and Save As, which is a copy the user chose rather than content the app
/// pressed on them.
///
/// **One plant is invented, because the schema requires it.** `projects` has a
/// non-null `plant_id` and a non-null `shift_pattern_id`, so a document that
/// held a project with neither could not exist. The pattern comes from the
/// seed; the plant is the one row with nowhere else to come from, and its name
/// is asked of the user, so the first thing they see is a word they chose.
class NewDocument {
  const NewDocument(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Empties the working database, seeds it, and writes [path].
  ///
  /// The caller opens the result in the ordinary way, so a document created is
  /// indistinguishable from a document opened — there is only one load path,
  /// and only one thing that can be wrong with it.
  Future<File> create(
    String path, {
    required String projectName,
    required String plantName,
  }) async {
    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      for (final table in DocumentStore.workingTables.reversed) {
        await _db.customStatement('DELETE FROM "$table"');
      }
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }

    // The same seed a fresh install runs, so a new document and a new
    // installation start from exactly the same reference data.
    await _db.seedReferenceData();

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final plantId = _uuid.v4();
    await _db.customInsert(
      'INSERT INTO plants (id, name, created_at, updated_at) '
      'VALUES (?, ?, ?, ?)',
      variables: [
        Variable<String>(plantId),
        Variable<String>(plantName),
        Variable<int>(now),
        Variable<int>(now),
      ],
    );

    final pattern = await _db
        .customSelect('SELECT id FROM shift_patterns ORDER BY rowid LIMIT 1')
        .getSingleOrNull();
    if (pattern == null) {
      throw StateError(
        'the reference seed produced no shift pattern, so a project cannot be '
        'created — see seedReferenceData',
      );
    }

    await _db.customInsert(
      'INSERT INTO projects (id, name, plant_id, shift_pattern_id, '
      'float_red_days, float_green_days, occupation_amber_pct, '
      'occupation_red_pct, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, 0, 30, 85, 100, ?, ?)',
      variables: [
        Variable<String>(_uuid.v4()),
        Variable<String>(projectName),
        Variable<String>(plantId),
        Variable<String>(pattern.data['id']! as String),
        Variable<int>(now),
        Variable<int>(now),
      ],
    );

    final project = await _db
        .customSelect('SELECT id, name FROM projects LIMIT 1')
        .getSingle();
    final store = DocumentStore(_db);
    final document = await store.capture(
      projectId: project.data['id']! as String,
      projectName: project.data['name']! as String,
    );

    final file = File(path);
    await file.parent.create(recursive: true);
    await DocumentStore.writeAtomically(file, document.write());
    return file;
  }

  /// The project name a file name implies, so *New* does not ask twice.
  ///
  /// The extension is stripped by hand rather than through
  /// `basenameWithoutExtension`, which treats `.flowmap` as a dotfile with no
  /// extension at all and hands back the whole thing.
  static String projectNameFor(String path) {
    var stem = p.basename(path);
    if (stem.toLowerCase().endsWith('.flowmap')) {
      stem = stem.substring(0, stem.length - '.flowmap'.length);
    }
    stem = stem.trim();
    return stem.isEmpty ? 'Project' : stem;
  }
}
