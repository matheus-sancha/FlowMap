import 'dart:io';

import 'package:flowmap/src/data/app_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 2.1.3 renamed the exe, which renamed the data folder, and nothing brought
/// the old one's runs and settings across. This is the one-time repair.
void main() {
  late Directory root;
  late Directory legacy;
  late Directory current;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flowmap_adopt');
    legacy = Directory(p.join(root.path, 'com.sancha', 'flowmap'))
      ..createSync(recursive: true);
    current = Directory(p.join(root.path, 'Matheus Sancha', 'FlowMap'));
  });
  tearDown(() => root.deleteSync(recursive: true));

  void write(Directory dir, String name, String body) {
    dir.createSync(recursive: true);
    File(p.join(dir.path, name)).writeAsStringSync(body);
  }

  String? read(Directory dir, String name) {
    final f = File(p.join(dir.path, name));
    return f.existsSync() ? f.readAsStringSync() : null;
  }

  Future<LegacyAdoption?> adopt() =>
      adoptLegacyDataFolder(legacy: legacy, current: current);

  test('an upgraded machine gets its database, window and log back', () async {
    write(legacy, 'flowmap.sqlite', 'runs');
    write(legacy, 'window.json', '{}');
    write(legacy, 'log.txt', 'old log');

    final result = await adopt();

    expect(result?.error, isNull);
    expect(read(current, 'flowmap.sqlite'), 'runs');
    expect(read(current, 'window.json'), '{}');
    expect(read(current, 'log.txt'), 'old log');
    expect(
      File(p.join(current.path, 'flowmap.sqlite.adopting')).existsSync(),
      isFalse,
    );
  });

  test('copies, and leaves the old folder exactly as it was', () async {
    write(legacy, 'flowmap.sqlite', 'runs');
    await adopt();
    expect(read(legacy, 'flowmap.sqlite'), 'runs');
  });

  test('the pre-upgrade backups stay behind', () async {
    write(legacy, 'flowmap.sqlite', 'runs');
    write(legacy, 'flowmap.pre-v30.sqlite', 'gigabytes');
    await adopt();
    expect(read(current, 'flowmap.pre-v30.sqlite'), isNull);
  });

  test('a machine that already ran 2.1.3 keeps its newer database', () async {
    // Replacing it would lose whatever was done since the upgrade.
    write(legacy, 'flowmap.sqlite', 'old runs');
    write(current, 'flowmap.sqlite', 'new work');

    expect(await adopt(), isNull);
    expect(read(current, 'flowmap.sqlite'), 'new work');
  });

  test('a fresh install has nothing to adopt', () async {
    expect(await adopt(), isNull);
    expect(current.existsSync(), isFalse);
  });

  test('after an interrupted attempt, it is tried again', () async {
    // An earlier launch copied the sidecars and died before the database
    // appeared, then wrote a log of its own.
    write(legacy, 'flowmap.sqlite', 'runs');
    write(legacy, 'log.txt', 'old log');
    write(current, 'flowmap.sqlite.adopting', 'half');
    write(current, 'log.txt', 'the failed launch');

    final result = await adopt();

    expect(result?.error, isNull);
    expect(read(current, 'flowmap.sqlite'), 'runs');
    // The newer log is this machine's, and is not overwritten.
    expect(read(current, 'log.txt'), 'the failed launch');
  });
}
