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
      await studies.insertStep(
        studyId: studyId,
        atPosition: 1,
        notes: 'Wedged in',
      );

      final nodes = await studies.loadNodes(studyId);
      expect(nodes.map((n) => n.position), [0, 1, 2]);
      expect(nodes.map((n) => n.notes), [null, 'Wedged in', null]);
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
        await studies.insertStep(studyId: studyId, atPosition: i, notes: 'S$i');
      }
      final nodes = await studies.loadNodes(studyId);
      await studies.deleteNode(studyId, nodes[1].id);

      final after = await studies.loadNodes(studyId);
      expect(after.map((n) => n.position), [0, 1, 2]);
      expect(after.map((n) => n.notes), ['S0', 'S2', 'S3']);
    });

    test('moving a node forward keeps everything else in order', () async {
      for (var i = 0; i < 4; i++) {
        await studies.insertStep(studyId: studyId, atPosition: i, notes: 'S$i');
      }

      await studies.moveNode(studyId, 0, 2);

      final after = await studies.loadNodes(studyId);
      expect(after.map((n) => n.notes), ['S1', 'S2', 'S0', 'S3']);
      expect(after.map((n) => n.position), [0, 1, 2, 3]);
    });

    test('moving a node backward keeps everything else in order', () async {
      for (var i = 0; i < 4; i++) {
        await studies.insertStep(studyId: studyId, atPosition: i, notes: 'S$i');
      }

      await studies.moveNode(studyId, 3, 0);

      final after = await studies.loadNodes(studyId);
      expect(after.map((n) => n.notes), ['S3', 'S0', 'S1', 'S2']);
      expect(after.map((n) => n.position), [0, 1, 2, 3]);
    });

    test('moving to the same place changes nothing', () async {
      for (var i = 0; i < 3; i++) {
        await studies.insertStep(studyId: studyId, atPosition: i, notes: 'S$i');
      }
      await studies.moveNode(studyId, 1, 1);
      final after = await studies.loadNodes(studyId);
      expect(after.map((n) => n.notes), ['S0', 'S1', 'S2']);
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
      );

      final after = (await studies.loadNodes(studyId)).single;
      expect(after.equivalentValue, isNull);
      expect(after.equivalentUnit, isNull);
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

  group('the settings a run reads (§7.2, §7.3, §7.8)', () {
    late String studyId;
    setUp(() async => studyId = await newStudy());

    Future<Study> read() =>
        (db.select(db.studies)..where((s) => s.id.equals(studyId))).getSingle();

    /// Everything but the one field under test, so a write cannot pass by
    /// leaving the others alone.
    Future<void> write({
      int? wipCap,
      int? startBufferDays,
      String? paceSetterTargetId,
      bool paceSetterGiven = false,
    }) async {
      final study = await read();
      await studies.updateStudy(
        studyId,
        name: study.name,
        wipCap: wipCap,
        startBufferDays: startBufferDays ?? study.startBufferDays,
        paceSetterTargetId: paceSetterTargetId,
        paceSetterGiven: paceSetterGiven,
      );
    }

    test('a WIP cap round-trips, and null is unlimited rather than none',
        () async {
      // Stored since M3, read by the engine since M4, and reachable from
      // nothing until the Study Settings tab (§17.5). So this is the first test
      // of any kind that a user can set it.
      expect((await read()).wipCap, isNull, reason: 'unlimited by default');

      await write(wipCap: 4);
      expect((await read()).wipCap, 4);

      // **Clearing it must give back unlimited, not zero.** A cap of zero would
      // stop the study releasing anything at all, so the difference between
      // "no cap" and "a cap of none" is the whole of §7.3 working or not.
      await write(wipCap: null);
      expect((await read()).wipCap, isNull);
    });

    test('a start buffer round-trips in calendar days (§7.8)', () async {
      expect((await read()).startBufferDays, 0);
      await write(startBufferDays: 30);
      expect((await read()).startBufferDays, 30);
    });

    test('the pacemaker distinguishes "derive it" from "not given"', () async {
      // Null is a real answer here — derive it from work content — so absence
      // has to be said separately, or every write that is not about the
      // pacemaker would silently clear a chosen one.
      await write(paceSetterTargetId: workcenterA, paceSetterGiven: true);
      expect((await read()).paceSetterTargetId, workcenterA);

      await write(wipCap: 3);
      expect(
        (await read()).paceSetterTargetId,
        workcenterA,
        reason: 'a write that did not mention it left it alone',
      );

      await write(paceSetterTargetId: null, paceSetterGiven: true);
      expect((await read()).paceSetterTargetId, isNull);
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
        setupValue: 30,
        setupUnit: TaktUnit.minutes,
        teardownValue: 10,
        teardownUnit: TaktUnit.minutes,
        samePartPercent: 25,
        balanceDisabled: true,
        equivalentValue: 4,
        equivalentUnit: TaktUnit.hours,
      );
      await studies.insertStep(
        studyId: source,
        atPosition: 1,
        workcenterId: workcenterB,
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
      // Every field a step carries, asked after one at a time. §2.6b found this
      // method silently dropping `batch_number` and it had been doing so since
      // the column arrived — found only because a new test happened to ask
      // about the field beside it.
      expect(copiedNodes.first.setupValue, 30);
      expect(copiedNodes.first.setupUnit, TaktUnit.minutes);
      expect(copiedNodes.first.teardownValue, 10);
      expect(copiedNodes.first.teardownUnit, TaktUnit.minutes);
      expect(copiedNodes.first.samePartPercent, 25);
      expect(copiedNodes.first.balanceDisabled, isTrue);
      expect(copiedNodes.first.equivalentValue, 4);
      expect(copiedNodes.first.equivalentUnit, TaktUnit.hours);
      expect(copiedNodes.last.workcenterId, workcenterB);

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
      await studies.insertStep(studyId: source, atPosition: 0, notes: 'Step');
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

  /// The stock standing at the two ends of the flow (§7.3).
  group('the flow ends', () {
    test('one end is written and the other is left alone', () async {
      final id = await newStudy();

      await studies.setFlowEnd(
        id,
        inbound: true,
        name: 'Steel Co',
        stock: 40,
      );
      await studies.setFlowEnd(
        id,
        inbound: false,
        name: 'Assembly',
        stock: 12,
      );

      final study = (await studies.loadStudy(id))!;
      expect(study.supplierName, 'Steel Co');
      expect(study.inboundStock, 40);
      expect(study.customerName, 'Assembly');
      expect(study.outboundStock, 12);
    });

    test('editing one end does not clear the other', () async {
      // The bug this method exists to make impossible: `updateStudy` writes
      // every field it is given, so an endpoint edit that named only its own
      // half used to null the other one.
      final id = await newStudy();
      await studies.setFlowEnd(id, inbound: false, name: 'Assembly', stock: 12);

      await studies.setFlowEnd(id, inbound: true, name: 'Steel Co', stock: 40);

      final study = (await studies.loadStudy(id))!;
      expect(study.customerName, 'Assembly');
      expect(study.outboundStock, 12);
    });

    test('nobody counted and counted zero are different answers', () async {
      final id = await newStudy();
      expect((await studies.loadStudy(id))!.inboundStock, isNull);

      await studies.setFlowEnd(id, inbound: true, name: null, stock: 0);
      expect((await studies.loadStudy(id))!.inboundStock, 0);

      // And it can be put back to uncounted, which is what an emptied field
      // means rather than a zero.
      await studies.setFlowEnd(id, inbound: true, name: null, stock: null);
      expect((await studies.loadStudy(id))!.inboundStock, isNull);
    });

    test('a duplicate carries both figures across', () async {
      // §2.6b's lesson: this method has silently dropped a column before, and
      // it did so from the round the column was added until a test asked.
      final source = await newStudy();
      await studies.setFlowEnd(source, inbound: true, name: 'S', stock: 40);
      await studies.setFlowEnd(source, inbound: false, name: 'C', stock: 12);

      final copyId = await studies.duplicateStudy(source, newName: 'B');

      final copy = (await studies.loadStudy(copyId))!;
      expect(copy.inboundStock, 40);
      expect(copy.outboundStock, 12);
    });

    test('an unrelated edit leaves both ends standing', () async {
      // `updateStudy` does not mention these columns at all, which is the
      // point — a caller that has never heard of end stock cannot clear it.
      final id = await newStudy();
      await studies.setFlowEnd(id, inbound: true, name: 'S', stock: 40);

      await studies.updateStudy(id, name: 'Renamed', wipCap: 5);

      final study = (await studies.loadStudy(id))!;
      expect(study.name, 'Renamed');
      expect(study.inboundStock, 40);
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
