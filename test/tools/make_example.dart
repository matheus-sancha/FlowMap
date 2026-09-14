// A render tool, not a test: `flutter test test/tools/make_example.dart`.
// ignore_for_file: avoid_print
//
// Builds `tool/drop/example.flowmap` — the zip's worked example (#28) — from the
// developer's own plant, **by the path the field will take**: a copy of the
// live database is migrated to the current schema, the one-time document
// conversion (#37) writes its project out, and the result is opened again in a
// fresh database and simulated. So producing the example also rehearses the one
// upgrade that touches real data, on a copy.
//
// Never touches the live file: it is copied first, read-only.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/database_providers.dart';
import 'package:flowmap/src/features/documents/data/document_migration.dart';
import 'package:flowmap/src/features/documents/data/document_store.dart';
import 'package:flowmap/src/features/documents/data/flowmap_document.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/application/simulation_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('make example.flowmap', () async {
    final appData = Platform.environment['APPDATA']!;
    final live = File(p.join(appData, 'com.sancha', 'flowmap', 'flowmap.sqlite'));
    expect(live.existsSync(), isTrue, reason: 'no live database to build from');

    final work = Directory.systemTemp.createTempSync('flowmap-example-');
    final copy = await live.copy(p.join(work.path, 'flowmap.sqlite'));

    // 1. The upgrade, on the copy.
    final upgraded = AppDatabase(NativeDatabase(copy));
    final version = await upgraded.customSelect('PRAGMA user_version').getSingle();
    print('migrated copy to v${version.data.values.first}');
    final problems = await upgraded.customSelect('PRAGMA foreign_key_check').get();
    expect(problems, isEmpty, reason: 'the upgraded copy has dangling rows');

    // 2. The one-time conversion, into the work folder.
    final written = await DocumentMigration(
      upgraded,
      DatabaseSettingsAccess(upgraded),
    ).run(work);
    await upgraded.close();
    expect(written, hasLength(1), reason: 'expected exactly one project');
    final bytes = written.single.readAsBytesSync();
    print('document ${p.basename(written.single.path)}: ${bytes.length} bytes');

    // 3. Opened again, fresh, the way a new install opens it.
    final fresh = AppDatabase(NativeDatabase.memory());
    final document = FlowmapDocument.read(bytes);
    final store = DocumentStore(fresh);
    await store.load(document);
    expect(await store.checkIntegrity(), isEmpty);

    // 4. And simulated: the example has to run on arrival.
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(fresh)],
    );
    final projectId = document.project['projects']!.single['id']! as String;
    final input = await container
        .read(simulationRepositoryProvider)
        .assembleRun(projectId);
    for (final study in input.readiness) {
      print('  ${study.name}: ${study.isReady ? 'ready' : study.problems}');
    }
    expect(input.canRun, isTrue, reason: 'the example must run on arrival');
    final result = runSimulation(
      studies: input.studies,
      workcenters: input.workcenters,
      scheduledWorkcenters: input.scheduledWorkcenters,
      scheduleHorizon: input.scheduleHorizon,
    );
    final onTime = result.orders.where((o) => o.isOnTime).length;
    print('simulated: ${result.orders.length} orders, $onTime on time');
    container.dispose();
    await fresh.close();

    final out = File('tool/drop/example.flowmap');
    await out.writeAsBytes(bytes);
    print('wrote ${out.path}');
    work.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
