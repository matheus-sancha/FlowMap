import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/projects/data/projects_repository.dart';
import 'package:flowmap/src/features/resources/data/resources_repository.dart';
import 'package:flowmap/src/features/studies/data/studies_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ResourcesRepository resources;
  late ProjectsRepository projects;
  late StudiesRepository studies;

  late String projectId;
  late String cellId;
  late String lineId;
  late String otherLineId;
  late String workcenterA;
  late String workcenterB;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    resources = ResourcesRepository(db);
    projects = ProjectsRepository(db);
    studies = StudiesRepository(db);

    final plantId = await resources.createPlant(name: 'Plant 1');
    cellId = await resources.createCell(plantId: plantId, name: 'Cell A');
    lineId = await resources.createLine(cellId: cellId, name: 'Line 1');
    otherLineId = await resources.createLine(cellId: cellId, name: 'Line 2');
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
  });

  tearDown(() => db.close());

  Future<String> newStudy([String name = 'Current state']) =>
      studies.createStudy(
        projectId: projectId,
        productionCellId: cellId,
        productionLineId: lineId,
        name: name,
      );

  group('the flow spine keeps dense, ordered positions', () {
    late String studyId;

    setUp(() async => studyId = await newStudy());

    test('inserting at the end appends', () async {
      await studies.insertStep(
        studyId: studyId,
        atPosition: 0,
        workcenterId: workcenterA,
      );
      await studies.insertStep(
        studyId: studyId,
        atPosition: 1,
        workcenterId: workcenterB,
      );

      final nodes = await studies.loadNodes(studyId);
      expect(nodes.map((n) => n.position), [0, 1]);
      expect(nodes.map((n) => n.workcenterId), [workcenterA, workcenterB]);
    });

    test('inserting between nodes pushes the rest along', () async {
      await studies.insertStep(
        studyId: studyId,
        atPosition: 0,
        workcenterId: workcenterA,
      );
      await studies.insertStep(
        studyId: studyId,
        atPosition: 1,
        workcenterId: workcenterB,
      );

      // The "+ Insert here" affordance between the two.
      await studies.insertInventory(
        studyId: studyId,
        atPosition: 1,
        mode: InventoryMode.quantity,
        quantity: 5,
      );

      final nodes = await studies.loadNodes(studyId);
      expect(nodes.map((n) => n.position), [0, 1, 2]);
      expect(nodes.map((n) => n.kind), [
        FlowNodeKind.step,
        FlowNodeKind.inventory,
        FlowNodeKind.step,
      ]);
      expect(nodes.last.workcenterId, workcenterB);
    });

    test('an out-of-range insert position is clamped, not rejected', () async {
      await studies.insertStep(studyId: studyId, atPosition: 99);
      await studies.insertStep(studyId: studyId, atPosition: -5);
      final nodes = await studies.loadNodes(studyId);
      expect(nodes.map((n) => n.position), [0, 1]);
    });

    test('deleting closes the gap', () async {
      for (var i = 0; i < 4; i++) {
        await studies.insertStep(studyId: studyId, atPosition: i, label: 'S$i');
      }
      final nodes = await studies.loadNodes(studyId);
      await studies.deleteNode(studyId, nodes[1].id);

      final after = await studies.loadNodes(studyId);
      expect(after.map((n) => n.position), [0, 1, 2]);
      expect(after.map((n) => n.label), ['S0', 'S2', 'S3']);
    });

    test('moving a node forward keeps everything else in order', () async {
      for (var i = 0; i < 4; i++) {
        await studies.insertStep(studyId: studyId, atPosition: i, label: 'S$i');
      }

      await studies.moveNode(studyId, 0, 2);

      final after = await studies.loadNodes(studyId);
      expect(after.map((n) => n.label), ['S1', 'S2', 'S0', 'S3']);
      expect(after.map((n) => n.position), [0, 1, 2, 3]);
    });

    test('moving a node backward keeps everything else in order', () async {
      for (var i = 0; i < 4; i++) {
        await studies.insertStep(studyId: studyId, atPosition: i, label: 'S$i');
      }

      await studies.moveNode(studyId, 3, 0);

      final after = await studies.loadNodes(studyId);
      expect(after.map((n) => n.label), ['S3', 'S0', 'S1', 'S2']);
      expect(after.map((n) => n.position), [0, 1, 2, 3]);
    });

    test('moving to the same place changes nothing', () async {
      for (var i = 0; i < 3; i++) {
        await studies.insertStep(studyId: studyId, atPosition: i, label: 'S$i');
      }
      await studies.moveNode(studyId, 1, 1);
      final after = await studies.loadNodes(studyId);
      expect(after.map((n) => n.label), ['S0', 'S1', 'S2']);
    });

    test('an inventory node keeps its mode and value', () async {
      await studies.insertInventory(
        studyId: studyId,
        atPosition: 0,
        mode: InventoryMode.duration,
        wait: const Duration(hours: 24),
        waitUnit: DurationUnit.hours,
        usesWorkingTime: false,
        label: 'Cooling',
      );
      final node = (await studies.loadNodes(studyId)).single;
      expect(node.inventoryMode, InventoryMode.duration);
      expect(node.inventorySeconds, 24 * 3600);
      expect(node.inventoryUsesWorkingTime, isFalse);
      expect(node.label, 'Cooling');
    });

    test('a fixed wait remembers the unit it was typed in', () async {
      // Stored canonically in seconds, but `2 days` must read back as `2 days`
      // rather than `48 h`.
      await studies.insertInventory(
        studyId: studyId,
        atPosition: 0,
        mode: InventoryMode.duration,
        wait: const Duration(days: 2),
        waitUnit: DurationUnit.days,
        usesWorkingTime: false,
      );
      final node = (await studies.loadNodes(studyId)).single;
      expect(node.inventorySeconds, 48 * 3600);
      expect(node.inventoryUnit, DurationUnit.days);
    });

    test('a step equivalent round-trips, value and unit together', () async {
      await studies.insertStep(
        studyId: studyId,
        atPosition: 0,
        workcenterId: workcenterA,
        equivalentValue: 4,
        equivalentUnit: TaktUnit.hours,
      );
      await studies.insertStep(
        studyId: studyId,
        atPosition: 1,
        workcenterId: workcenterB,
      );

      final nodes = await studies.loadNodes(studyId);
      expect(nodes[0].equivalentValue, 4);
      expect(nodes[0].equivalentUnit, TaktUnit.hours);
      expect(
        nodes[1].equivalentValue,
        isNull,
        reason: 'null follows the line takt, which is the usual case',
      );
      expect(nodes[1].equivalentUnit, isNull);
    });

    test('clearing a step equivalent puts it back on the takt', () async {
      await studies.insertStep(
        studyId: studyId,
        atPosition: 0,
        workcenterId: workcenterA,
        equivalentValue: 4,
        equivalentUnit: TaktUnit.hours,
      );
      final node = (await studies.loadNodes(studyId)).single;

      await studies.updateStep(
        node.id,
        workcenterId: workcenterA,
        changeover: Duration.zero,
      );

      final after = (await studies.loadNodes(studyId)).single;
      expect(after.equivalentValue, isNull);
      expect(after.equivalentUnit, isNull);
    });

    test('a quantity buffer has no wait unit of its own', () async {
      // Its wait comes from takt, which carries its own unit.
      await studies.insertInventory(
        studyId: studyId,
        atPosition: 0,
        mode: InventoryMode.quantity,
        quantity: 3,
      );
      final node = (await studies.loadNodes(studyId)).single;
      expect(node.inventoryUnit, isNull);
      expect(node.inventoryQuantity, 3);
    });

    test('duplicating a study carries the wait unit across', () async {
      await studies.insertInventory(
        studyId: studyId,
        atPosition: 0,
        mode: InventoryMode.duration,
        wait: const Duration(days: 2),
        waitUnit: DurationUnit.days,
        usesWorkingTime: true,
      );
      final copyId = await studies.duplicateStudy(studyId, newName: 'Copy');
      final copied = (await studies.loadNodes(copyId)).single;
      expect(copied.inventoryUnit, DurationUnit.days);
      expect(copied.inventoryUsesWorkingTime, isTrue);
    });

    test('deleting a workcenter leaves the step in place, unbound', () async {
      await studies.insertStep(
        studyId: studyId,
        atPosition: 0,
        workcenterId: workcenterA,
      );
      await resources.deleteWorkcenter(workcenterA);

      final node = (await studies.loadNodes(studyId)).single;
      expect(
        node.workcenterId,
        isNull,
        reason:
            'the step survives so the flow shape is not silently rewritten; '
            'readiness reports it as unbound',
      );
    });
  });

  group('include in simulation', () {
    test('flagging one study clears its siblings on the same line', () async {
      final first = await newStudy('Current state');
      final second = await newStudy('With 3rd shift');

      await studies.setIncludedInSimulation(first, true);
      await studies.setIncludedInSimulation(second, true);

      expect((await studies.loadStudy(first))!.includeInSimulation, isFalse);
      expect((await studies.loadStudy(second))!.includeInSimulation, isTrue);
    });

    test('a study on another line is untouched', () async {
      final onLine1 = await newStudy('Line 1 study');
      final onLine2 = await studies.createStudy(
        projectId: projectId,
        productionCellId: cellId,
        productionLineId: otherLineId,
        name: 'Line 2 study',
      );

      await studies.setIncludedInSimulation(onLine1, true);
      await studies.setIncludedInSimulation(onLine2, true);

      expect((await studies.loadStudy(onLine1))!.includeInSimulation, isTrue);
      expect((await studies.loadStudy(onLine2))!.includeInSimulation, isTrue);
    });

    test('unflagging clears only itself', () async {
      final study = await newStudy();
      await studies.setIncludedInSimulation(study, true);
      await studies.setIncludedInSimulation(study, false);
      expect((await studies.loadStudy(study))!.includeInSimulation, isFalse);
    });
  });

  group('duplicating a study', () {
    test('copies the flow and the annotations, with new ids', () async {
      final source = await newStudy();
      await studies.insertStep(
        studyId: source,
        atPosition: 0,
        workcenterId: workcenterA,
        changeover: const Duration(minutes: 30),
        equivalentValue: 4,
        equivalentUnit: TaktUnit.hours,
      );
      await studies.insertInventory(
        studyId: source,
        atPosition: 1,
        mode: InventoryMode.quantity,
        quantity: 4,
      );
      await studies.addAnnotation(
        studyId: source,
        symbol: AnnotationSymbol.kaizenBurst,
        x: 100,
        y: 40,
        caption: 'Reduce setup',
      );

      final copyId = await studies.duplicateStudy(
        source,
        newName: 'Scenario B',
      );

      final copiedNodes = await studies.loadNodes(copyId);
      expect(copiedNodes.map((n) => n.position), [0, 1]);
      expect(
        copiedNodes.first.workcenterId,
        workcenterA,
        reason: 'a duplicate targets the same capacity — that is the point',
      );
      expect(copiedNodes.first.changeoverSeconds, 30 * 60);
      expect(copiedNodes.first.equivalentValue, 4);
      expect(copiedNodes.first.equivalentUnit, TaktUnit.hours);
      expect(copiedNodes.last.inventoryQuantity, 4);

      final sourceNodes = await studies.loadNodes(source);
      expect(
        copiedNodes.map((n) => n.id).toSet()
          ..retainAll(sourceNodes.map((n) => n.id)),
        isEmpty,
      );

      final annotations = await studies.watchAnnotations(copyId).first;
      expect(annotations.single.caption, 'Reduce setup');
    });

    test('the copy is never flagged for simulation', () async {
      final source = await newStudy();
      await studies.setIncludedInSimulation(source, true);

      final copyId = await studies.duplicateStudy(
        source,
        newName: 'Scenario B',
      );

      expect((await studies.loadStudy(copyId))!.includeInSimulation, isFalse);
      expect(
        (await studies.loadStudy(source))!.includeInSimulation,
        isTrue,
        reason: 'duplicating must not silently deselect the original',
      );
    });

    test('editing the copy does not touch the original', () async {
      final source = await newStudy();
      await studies.insertStep(studyId: source, atPosition: 0, label: 'Step');
      final copyId = await studies.duplicateStudy(
        source,
        newName: 'Scenario B',
      );

      final copyNode = (await studies.loadNodes(copyId)).single;
      await studies.deleteNode(copyId, copyNode.id);

      expect(await studies.loadNodes(source), hasLength(1));
      expect(await studies.loadNodes(copyId), isEmpty);
    });
  });

  group('deleting a study', () {
    test('takes its flow with it', () async {
      final studyId = await newStudy();
      await studies.insertStep(studyId: studyId, atPosition: 0);
      await studies.addAnnotation(
        studyId: studyId,
        symbol: AnnotationSymbol.note,
        x: 0,
        y: 0,
      );

      await studies.deleteStudy(studyId);

      expect(await studies.loadNodes(studyId), isEmpty);
      expect(await studies.watchAnnotations(studyId).first, isEmpty);
    });
  });
}
