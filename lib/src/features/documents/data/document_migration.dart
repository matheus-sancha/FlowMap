import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import 'document_store.dart';
import 'flowmap_document.dart';

/// Turns the projects already in the database into documents, once.
///
/// **This runs on exactly one machine.** Every employee installs fresh and
/// creates documents from the start, so the only database that has ever held a
/// project the document model does not know about is the developer's. That is
/// why this is a one-way conversion with no undo of its own — phase 1's backup
/// is already sitting beside the database, taken before any of this.
///
/// **Nothing is deleted.** The projects stay exactly where they are; this only
/// writes them out. A conversion that emptied the database would have no way
/// back if the write were wrong, and the whole point of the exercise is that
/// the data is irreplaceable. The working database is cleared later, by the
/// ordinary act of opening one of these documents.
class DocumentMigration {
  const DocumentMigration(this._db, this._settings);

  final GeneratedDatabase _db;
  final SettingsAccess _settings;

  /// Set once the conversion has run, so it never runs twice — a second pass
  /// would overwrite documents that have since been edited.
  static const settingKey = 'documents.migrated_at';

  /// Converts every project into a document in [directory].
  ///
  /// Returns the files written, newest project last. Returns empty when there
  /// is nothing to convert or when it has already run.
  Future<List<File>> run(Directory directory) async {
    if (await _settings.get(settingKey) != null) return const [];

    final projects = await _db
        .customSelect('SELECT id, name FROM projects ORDER BY created_at')
        .get();
    if (projects.isEmpty) {
      // Recorded even so. A fresh install has nothing to convert and must not
      // be asked again the first time it does have a project — which is the
      // shape of mistake `_seededAtKey` was written to avoid.
      await _settings.set(settingKey, DateTime.now().toIso8601String());
      return const [];
    }

    await directory.create(recursive: true);
    final written = <File>[];
    for (final row in projects) {
      final id = row.data['id']! as String;
      final name = row.data['name']! as String;
      final document = await FlowmapDocument.fromDatabase(
        _db,
        projectId: id,
        projectName: name,
      );
      final file = File(p.join(directory.path, fileNameFor(name, directory)));
      await DocumentStore.writeAtomically(file, document.write());
      written.add(file);
    }

    await _settings.set(settingKey, DateTime.now().toIso8601String());
    return written;
  }

  /// A file name a person will recognise, from a project name they chose.
  ///
  /// Project names are free text and have been since M2 — `Plan Q1` is the
  /// live one, and nothing has ever stopped someone typing a slash. So the name
  /// is reduced to what Windows will accept, and a collision takes a suffix
  /// rather than overwriting a document that is already there.
  static String fileNameFor(String projectName, Directory directory) {
    var stem = projectName
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Windows also refuses a trailing dot or space, and a handful of reserved
    // names regardless of extension.
    stem = stem.replaceAll(RegExp(r'[. ]+$'), '');
    // A name that was *entirely* characters Windows refuses reduces to a row of
    // dashes, which is a legal file name that tells the reader nothing. Falling
    // back is more honest than preserving punctuation nobody can act on.
    if (!RegExp(r'[a-zA-Z0-9]').hasMatch(stem)) stem = 'Project';
    if (_reserved.hasMatch(stem)) stem = '$stem-project';
    if (stem.length > 80) stem = stem.substring(0, 80).trim();

    var candidate = '$stem.flowmap';
    var n = 2;
    while (File(p.join(directory.path, candidate)).existsSync()) {
      candidate = '$stem ($n).flowmap';
      n++;
    }
    return candidate;
  }

  static final _reserved = RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$',
    caseSensitive: false,
  );
}

/// The two settings operations this needs, so the conversion can be tested
/// without dragging the settings feature in behind it.
abstract class SettingsAccess {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
}

/// [SettingsAccess] over the `app_settings` table.
class DatabaseSettingsAccess implements SettingsAccess {
  const DatabaseSettingsAccess(this._db);
  final GeneratedDatabase _db;

  @override
  Future<String?> get(String key) async {
    final rows = await _db
        .customSelect(
          'SELECT value FROM app_settings WHERE key = ?',
          variables: [Variable<String>(key)],
        )
        .get();
    return rows.isEmpty ? null : rows.first.data['value'] as String?;
  }

  @override
  Future<void> set(String key, String value) => _db.customInsert(
    'INSERT OR REPLACE INTO app_settings (key, value, updated_at) '
    'VALUES (?, ?, ?)',
    variables: [
      Variable<String>(key),
      Variable<String>(value),
      Variable<int>(DateTime.now().millisecondsSinceEpoch ~/ 1000),
    ],
  );
}
