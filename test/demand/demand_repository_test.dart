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

  /// The flow steps those two workcenters are reached through.
  ///
  /// **A process time is keyed by the step since §9**, not by the station, so a
  /// study with no flow has nowhere to hang one — and the foreign key says so
  /// rather than letting a workcenter id stand in and look self-consistent.
  late String stepA;
  late String stepB;

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
    stepA = await studies.insertStep(
      studyId: studyId,
      atPosition: 0,
      workcenterId: workcenterA,
    );
    stepB = await studies.insertStep(
      studyId: studyId,
      atPosition: 1,
      workcenterId: workcenterB,
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
        nodeId: stepA,
        time: const Duration(hours: 55),
      );
      expect(
        (await demand.watchProcessTimes(studyId).first)[partId],
        {stepA: const Duration(hours: 55)},
      );

      await demand.setProcessTime(
        partId: partId,
        nodeId: stepA,
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
          nodeId: stepA,
          time: const Duration(hours: 10),
        ),
        ProcessTimeEdit(
          partId: partId,
          nodeId: stepA,
          time: const Duration(hours: 12),
        ),
      ]);

      expect(
        (await demand.watchProcessTimes(studyId).first)[partId],
        {stepA: const Duration(hours: 12)},
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
        nodeId: stepA,
        time: const Duration(hours: 1),
      );
      await demand.setProcessTime(
        partId: theirs,
        nodeId: stepA,
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
        nodeId: stepA,
        time: const Duration(hours: 55),
      ),
      ProcessTimeEdit(
        partId: pn1,
        nodeId: stepB,
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

    // **Keyed by the copy's own steps, not by the original's** (§9). This is
    // the trap that made §9 a round rather than a rename: a process time
    // belongs to a node, `duplicateStudy` gives every copied node a fresh id,
    // and a copy that carried the source's ids would hang every time off the
    // original study's steps. Nothing would fail to compile and nothing would
    // throw — `watchProcessTimes` returns a map of untyped keys, so the copy
    // would simply read uncosted and the readiness panel would name every part.
    //
    // Asserted against the copy's nodes rather than against two literals, so it
    // says *whose* steps rather than only that the times survived.
    final copiedNodes = await studies.loadNodes(copyId);
    expect(copiedNodes.map((n) => n.id), isNot(contains(stepA)));

    final copiedTimes =
        (await demand.watchProcessTimes(copyId).first)[copiedParts.single.id]!;
    expect(copiedTimes, {
      copiedNodes[0].id: const Duration(hours: 55),
      copiedNodes[1].id: const Duration(hours: 3),
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
      nodeId: stepA,
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

  group("an order carries the customer's project", () {
    test('two orders of one part can be for different projects', () async {
      // The case v14 exists for. Before it, the project was half of what
      // identified a part, so this was two parts with two sets of process
      // times — and a planner had to type PN1 twice to say that one part goes
      // to two programmes (§9.3).
      final partId = await demand.createPart(
        studyId: studyId,
        partNumber: 'PN1',
      );
      await demand.createOrder(
        studyId: studyId,
        partId: partId,
        needDate: DateTime(2026, 8, 10),
        customerProject: 'Wing 7',
      );
      await demand.createOrder(
        studyId: studyId,
        partId: partId,
        needDate: DateTime(2026, 8, 11),
        customerProject: 'Wing 9',
      );

      expect((await demand.loadParts(studyId)), hasLength(1));
      expect(
        (await demand.loadOrders(studyId)).map((o) => o.customerProject),
        ['Wing 7', 'Wing 9'],
      );
    });

    test('it is a label: blank is allowed and nothing matches on it', () async {
      final partId = await demand.createPart(
        studyId: studyId,
        partNumber: 'PN1',
      );
      final orderId = await demand.createOrder(
        studyId: studyId,
        partId: partId,
        needDate: DateTime(2026, 8, 10),
        customerProject: 'Wing 7',
      );

      // Cleared by an update that does not name it, exactly as the batch
      // number is — both are the planner's own labels (§9.1, §9.3).
      await demand.updateOrder(
        orderId,
        partId: partId,
        needDate: DateTime(2026, 8, 10),
        batchSize: 1,
      );
      expect(
        (await demand.loadOrders(studyId)).single.customerProject,
        isNull,
      );
    });

    test('a duplicated study keeps every label the planner typed', () async {
      final partId = await demand.createPart(
        studyId: studyId,
        partNumber: 'PN1',
      );
      await demand.createOrder(
        studyId: studyId,
        partId: partId,
        needDate: DateTime(2026, 8, 10),
        customerProject: 'Wing 7',
        batchNumber: 'B-0012',
      );
      final copyId = await studies.duplicateStudy(studyId, newName: 'Copy');

      // The batch number was being dropped here from the day it arrived, and
      // only showed when the project joined it: the copy carried the figures
      // the engine reads and silently lost the two labels a planner matches
      // against their own paperwork (§9.1, §9.3).
      final copied = (await demand.loadOrders(copyId)).single;
      expect((await demand.loadParts(copyId)).single.partNumber, 'PN1');
      expect(copied.customerProject, 'Wing 7');
      expect(copied.batchNumber, 'B-0012');
      expect(copied.needDate, DateTime(2026, 8, 10));
    });
  });

  test('deleting every order leaves the parts and their times', () async {
    final partId = await demand.createPart(
      studyId: studyId,
      partNumber: 'PN1',
    );
    await demand.setProcessTime(
      partId: partId,
      nodeId: stepA,
      time: const Duration(hours: 5),
    );
    for (var i = 0; i < 3; i++) {
      await demand.createOrder(
        studyId: studyId,
        partId: partId,
        needDate: DateTime(2026, 8, 13),
      );
    }

    await demand.deleteAllOrders(studyId);

    // Clearing the sequence is what a re-import starts with; it must not take
    // the process times with it.
    expect(await demand.loadOrders(studyId), isEmpty);
    expect(await demand.loadParts(studyId), hasLength(1));
    expect((await demand.watchProcessTimes(studyId).first)[partId], hasLength(1));
  });

}
