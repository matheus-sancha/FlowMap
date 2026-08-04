import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/demand/data/demand_repository.dart';
import 'package:flowmap/src/features/projects/data/projects_repository.dart';
import 'package:flowmap/src/features/resources/data/resources_repository.dart';
import 'package:flowmap/src/features/studies/data/studies_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ResourcesRepository resources;
  late ProjectsRepository projects;
  late StudiesRepository studies;
  late DemandRepository demand;

  late String projectId;
  late String cellId;
  late String lineId;
  late String studyId;
  late String workcenterA;
  late String workcenterB;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    resources = ResourcesRepository(db);
    projects = ProjectsRepository(db);
    studies = StudiesRepository(db);
    demand = DemandRepository(db);

    final plantId = await resources.createPlant(name: 'Plant 1');
    cellId = await resources.createCell(plantId: plantId, name: 'Cell A');
    lineId = await resources.createLine(cellId: cellId, name: 'Line 1');
    workcenterA = await resources.createWorkcenter(
      plantId: plantId,
      name: 'CLAD04',
    );
    workcenterB = await resources.createWorkcenter(
      plantId: plantId,
      name: 'TTAT',
    );

    final patterns = await resources.watchShiftPatterns().first;
    projectId = await projects.createProject(
      name: 'H2 2026',
      plantId: plantId,
      shiftPatternId: patterns.firstWhere((p) => p.name == 'ABC').id,
    );
    studyId = await studies.createStudy(
      projectId: projectId,
      productionCellId: cellId,
      productionLineId: lineId,
      name: 'Current state',
    );
  });

  tearDown(() => db.close());

  group('process times', () {
    test('a cleared cell is deleted, not stored as zero', () async {
      final partId = await demand.createPart(
        studyId: studyId,
        partNumber: 'PN1',
      );
      await demand.setProcessTime(
        partId: partId,
        targetId: workcenterA,
        time: const Duration(hours: 55),
      );
      expect(
        (await demand.watchProcessTimes(studyId).first)[partId],
        {workcenterA: const Duration(hours: 55)},
      );

      await demand.setProcessTime(
        partId: partId,
        targetId: workcenterA,
        time: null,
      );

      // Absent, not zero: "does not visit this step" and "takes no time" are
      // different claims, and only one of them is ever true by accident
      // (DESIGN.md §5.1, §11).
      final times = await demand.watchProcessTimes(studyId).first;
      expect(times[partId] ?? const {}, isEmpty);
    });

    test('rewriting a cell replaces it rather than duplicating it', () async {
      final partId = await demand.createPart(
        studyId: studyId,
        partNumber: 'PN1',
      );
      await demand.setProcessTimes([
        ProcessTimeEdit(
          partId: partId,
          targetId: workcenterA,
          time: const Duration(hours: 10),
        ),
        ProcessTimeEdit(
          partId: partId,
          targetId: workcenterA,
          time: const Duration(hours: 12),
        ),
      ]);

      expect(
        (await demand.watchProcessTimes(studyId).first)[partId],
        {workcenterA: const Duration(hours: 12)},
      );
    });

    test('only this study\'s times are read back', () async {
      final other = await studies.createStudy(
        projectId: projectId,
        productionCellId: cellId,
        productionLineId: lineId,
        name: 'With 3rd shift',
      );
      final mine = await demand.createPart(
        studyId: studyId,
        partNumber: 'PN1',
      );
      final theirs = await demand.createPart(
        studyId: other,
        partNumber: 'PN1',
      );
      await demand.setProcessTime(
        partId: mine,
        targetId: workcenterA,
        time: const Duration(hours: 1),
      );
      await demand.setProcessTime(
        partId: theirs,
        targetId: workcenterA,
        time: const Duration(hours: 2),
      );

      final times = await demand.watchProcessTimes(studyId).first;
      expect(times.keys, [mine]);
    });
  });

  group('the order sequence stays dense', () {
    late String pn1;
    late String pn2;

    setUp(() async {
      pn1 = await demand.createPart(studyId: studyId, partNumber: 'PN1');
      pn2 = await demand.createPart(studyId: studyId, partNumber: 'PN2');
    });

    Future<String> order(String partId, int day) => demand.createOrder(
      studyId: studyId,
      partId: partId,
      needDate: DateTime(2026, 8, day),
    );

    test('created orders append', () async {
      await order(pn1, 10);
      await order(pn2, 11);
      await order(pn1, 12);

      final orders = await demand.loadOrders(studyId);
      expect(orders.map((o) => o.sequence), [0, 1, 2]);
      expect(orders.map((o) => o.partId), [pn1, pn2, pn1]);
    });

    test('inserting in the middle pushes the rest along', () async {
      await order(pn1, 10);
      await order(pn1, 12);
      await demand.createOrder(
        studyId: studyId,
        partId: pn2,
        needDate: DateTime(2026, 8, 11),
        atSequence: 1,
      );

      final orders = await demand.loadOrders(studyId);
      expect(orders.map((o) => o.sequence), [0, 1, 2]);
      expect(orders.map((o) => o.partId), [pn1, pn2, pn1]);
    });

    test('moving an order keeps every other one in relative order', () async {
      final a = await order(pn1, 10);
      final b = await order(pn2, 11);
      final c = await order(pn1, 12);

      await demand.moveOrder(studyId, 2, 0);

      final orders = await demand.loadOrders(studyId);
      expect(orders.map((o) => o.id), [c, a, b]);
      expect(orders.map((o) => o.sequence), [0, 1, 2]);
    });

    test('deleting closes the gap', () async {
      final a = await order(pn1, 10);
      final b = await order(pn2, 11);
      final c = await order(pn1, 12);

      await demand.deleteOrder(studyId, b);

      final orders = await demand.loadOrders(studyId);
      expect(orders.map((o) => o.id), [a, c]);
      expect(orders.map((o) => o.sequence), [0, 1]);
    });

    test('deleting a part takes its orders out and renumbers', () async {
      final a = await order(pn1, 10);
      await order(pn2, 11);
      final c = await order(pn1, 12);

      await demand.deletePart(studyId, pn2);

      // The foreign key's own cascade would have left a hole at 1, and a
      // sequence with a hole is one the release slots cannot walk (§7.2).
      final orders = await demand.loadOrders(studyId);
      expect(orders.map((o) => o.id), [a, c]);
      expect(orders.map((o) => o.sequence), [0, 1]);
      expect(await demand.loadParts(studyId), hasLength(1));
    });
  });

  test('duplicating a study copies its demand onto new parts', () async {
    final pn1 = await demand.createPart(
      studyId: studyId,
      partNumber: 'PN1',
      description: 'Housing',
    );
    await demand.setProcessTimes([
      ProcessTimeEdit(
        partId: pn1,
        targetId: workcenterA,
        time: const Duration(hours: 55),
      ),
      ProcessTimeEdit(
        partId: pn1,
        targetId: workcenterB,
        time: const Duration(hours: 3),
      ),
    ]);
    await demand.createOrder(
      studyId: studyId,
      partId: pn1,
      needDate: DateTime(2026, 8, 13),
      batchSize: 4,
    );

    final copyId = await studies.duplicateStudy(studyId, newName: 'Scenario B');

    final copiedParts = await demand.loadParts(copyId);
    expect(copiedParts.single.partNumber, 'PN1');
    expect(copiedParts.single.description, 'Housing');
    expect(
      copiedParts.single.id,
      isNot(pn1),
      reason: 'a scenario is re-sequenced without disturbing the original',
    );

    expect((await demand.watchProcessTimes(copyId).first)[copiedParts.single.id], {
      workcenterA: const Duration(hours: 55),
      workcenterB: const Duration(hours: 3),
    });

    final copiedOrders = await demand.loadOrders(copyId);
    expect(copiedOrders.single.partId, copiedParts.single.id);
    expect(copiedOrders.single.batchSize, 4);

    // And the original is untouched by anything done to the copy.
    await demand.deletePart(copyId, copiedParts.single.id);
    expect(await demand.loadParts(studyId), hasLength(1));
    expect((await demand.watchProcessTimes(studyId).first)[pn1], hasLength(2));
  });

  test('deleting a study takes its demand with it', () async {
    final partId = await demand.createPart(
      studyId: studyId,
      partNumber: 'PN1',
    );
    await demand.setProcessTime(
      partId: partId,
      targetId: workcenterA,
      time: const Duration(hours: 1),
    );
    await demand.createOrder(
      studyId: studyId,
      partId: partId,
      needDate: DateTime(2026, 8, 13),
    );

    await studies.deleteStudy(studyId);

    expect(await demand.loadParts(studyId), isEmpty);
    expect(await demand.loadOrders(studyId), isEmpty);
    expect(await db.select(db.partProcessTimes).get(), isEmpty);
  });
}
