import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/migration_backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// The backup exists for a migration that fails halfway, which is a state no
/// test can reach on purpose — `onUpgrade`'s own preamble records a machine
/// that got there and could not be opened again at all.
///
/// So what is asserted here is the part that *is* reachable: that the copy is
/// taken **before** anything opens the file, that it is taken exactly when a
/// migration would run and never otherwise, and that it cannot be the thing
/// that stops the app opening.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('flowmap_backup'));
  tearDown(() => dir.deleteSync(recursive: true));

  File dbFile() => File(p.join(dir.path, 'flowmap.sqlite'));

  /// A real database left at [version], with one row to recognise it by.
  Future<File> databaseAt(int version) async {
    final file = dbFile();
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      "INSERT INTO plants (id, name, created_at, updated_at) "
      "VALUES ('plant-1', 'Planta 1', 0, 0)",
    );
    await db.close();
    sqlite3.open(file.path)
      ..execute('PRAGMA user_version = $version')
      ..close();
    return file;
  }

  test('copies aside when opening would migrate', () async {
    final file = await databaseAt(30);

    final backup = await MigrationBackup.copyAside(file, schemaVersion: 31);

    expect(backup, isNotNull);
    // Named for the version being *left*: at the moment of copying that is the
    // only version true of the contents.
    expect(p.basename(backup!.path), 'flowmap.pre-v30.sqlite');
    expect(backup.lengthSync(), file.lengthSync());
    expect(backup.parent.path, file.parent.path);
  });

  test('the copy is the data as it stood, not an empty file', () async {
    final file = await databaseAt(30);
    final backup = await MigrationBackup.copyAside(file, schemaVersion: 31);

    final copy = sqlite3.open(backup!.path);
    addTearDown(copy.close);
    expect(copy.select('SELECT name FROM plants').single['name'], 'Planta 1');
    // And it is still the old version inside, which is what makes it a way back.
    expect(copy.select('PRAGMA user_version').single.values.first, 30);
  });

  test('does nothing when the database is already current', () async {
    final file = await databaseAt(31);
    expect(await MigrationBackup.copyAside(file, schemaVersion: 31), isNull);
    expect(dir.listSync().whereType<File>().map((f) => p.basename(f.path)),
        isNot(contains('flowmap.pre-v31.sqlite')));
  });

  test('does nothing on a fresh install', () async {
    // The case that matters for the drop: an employee's first launch *creates*
    // the schema rather than migrating to it, so there is nothing to copy and
    // no 170 MB written for no reason.
    expect(
      await MigrationBackup.copyAside(dbFile(), schemaVersion: 31),
      isNull,
    );
    expect(dbFile().existsSync(), isFalse);
  });

  test('does nothing for a database with no schema yet', () async {
    final file = await databaseAt(0);
    expect(await MigrationBackup.copyAside(file, schemaVersion: 31), isNull);
  });

  test('overwrites the previous backup rather than accumulating', () async {
    // One file, deliberately: a chain would leave several that look equally
    // plausible to someone already in trouble, at 170 MB each.
    final file = await databaseAt(30);
    await MigrationBackup.copyAside(file, schemaVersion: 31);
    final first = File(p.join(dir.path, 'flowmap.pre-v30.sqlite')).lengthSync();

    await file.writeAsBytes(
      [...await file.readAsBytes(), ...List.filled(4096, 0)],
    );
    await MigrationBackup.copyAside(file, schemaVersion: 31);

    final backups = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).contains('pre-v'))
        .toList();
    expect(backups, hasLength(1));
    expect(backups.single.lengthSync(), greaterThan(first));
  });

  test('never throws, and reports instead, when the file is not a database',
      () async {
    // Insurance that can deny you the building is worse than none: a failure
    // here must not stop the app opening.
    final file = dbFile()..writeAsStringSync('this is not a database');
    final errors = <Object>[];

    expect(
      await MigrationBackup.copyAside(
        file,
        schemaVersion: 31,
        onError: errors.add,
      ),
      isNull,
    );
    // Not a SQLite file is answered by reading the header, not by failing.
    expect(errors, isEmpty);
  });

  test('never throws when the file is too short to hold a header', () async {
    final file = dbFile()..writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
    expect(await MigrationBackup.copyAside(file, schemaVersion: 31), isNull);
  });

  test('reads the version without opening a connection', () async {
    // The whole point of reading the header as bytes: a connection, even a
    // read-only one, can create sidecar files and take locks on the very file
    // about to be copied. Nothing but the database may exist afterwards.
    final file = await databaseAt(30);
    final before = dir.listSync().map((e) => p.basename(e.path)).toSet();

    await MigrationBackup.copyAside(file, schemaVersion: 31);

    final after = dir.listSync().map((e) => p.basename(e.path)).toSet();
    expect(after.difference(before), {'flowmap.pre-v30.sqlite'});
  });

  test('names the backup after the database it came from', () {
    expect(MigrationBackup.backupNameFor('flowmap.sqlite', 30),
        'flowmap.pre-v30.sqlite');
    expect(MigrationBackup.backupNameFor('other.sqlite', 7),
        'other.pre-v7.sqlite');
  });
}
