import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmap/src/app/drop_files.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/database_providers.dart';
import 'package:flowmap/src/features/documents/data/document_store.dart';
import 'package:flowmap/src/features/documents/data/flowmap_document.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/application/simulation_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The example every drop carries, opened the way *Open the example* opens it.
///
/// **The file is frozen, and anonymised.** It began as the developer's own plant
/// and was rewritten once, by hand and outside the repository, so that nothing
/// in a public zip names a real part, customer or site (2.1.4). There is no tool
/// that rebuilds it: to change it, open it in FlowMap and Save As. So this test
/// is the only thing standing between a schema change and a first screen whose
/// one inviting button opens nothing — `package_windows.ps1` copies the file
/// without reading it.
void main() {
  test('the shipped example opens clean and runs on arrival', () async {
    final file = File(p.join('tool', 'drop', exampleFileName));
    expect(file.existsSync(), isTrue, reason: 'the drop copies this file');

    final document = FlowmapDocument.read(file.readAsBytesSync());
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DocumentStore(db);
    await store.load(document);
    expect(await store.checkIntegrity(), isEmpty);

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final projectId = document.project['projects']!.single['id']! as String;
    final input = await container
        .read(simulationRepositoryProvider)
        .assembleRun(projectId);
    expect(
      input.canRun,
      isTrue,
      reason: [
        for (final study in input.readiness)
          if (!study.isReady) '${study.name}: ${study.problems}',
      ].join('\n'),
    );

    final result = runSimulation(
      studies: input.studies,
      workcenters: input.workcenters,
      scheduledWorkcenters: input.scheduledWorkcenters,
      scheduleHorizon: input.scheduleHorizon,
    );
    expect(result.orders, hasLength(document.project['demand_orders']!.length));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
