import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/flow/data/flow_queues_repository.dart';
import 'package:flowmap/src/features/projects/data/projects_repository.dart';
import 'package:flowmap/src/features/resources/data/resources_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where a queue is stored (DESIGN.md §7.3).
///
/// The claim that matters is the **key**: `{projectId, targetId}`, so two
/// studies whose flows both reach CLAD07 read and write one row. That is the
/// correction §7.3 made, and a repository that quietly inserted a second row
/// would put the old model back without anything on screen changing.
void main() {
  late AppDatabase db;
  late FlowQueuesRepository queues;
  late String projectId;
  late String otherProjectId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    queues = FlowQueuesRepository(db);

    final resources = ResourcesRepository(db);
    final projects = ProjectsRepository(db);
    final plantId = await resources.createPlant(name: 'Werk Nord');
    final pattern = (await resources.watchShiftPatterns().first).first;
    projectId = await projects.createProject(
      name: 'H2 2026',
      plantId: plantId,
      shiftPatternId: pattern.id,
    );
    otherProjectId = await projects.createProject(
      name: 'H1 2027',
      plantId: plantId,
      shiftPatternId: pattern.id,
    );
  });
  tearDown(() => db.close());

  Future<ProjectQueue?> read(String targetId, {String? project}) async =>
      (await queues.watchQueues(project ?? projectId).first)[targetId];

  test('a queue round-trips whole', () async {
    await queues.saveQueue(
      projectId: projectId,
      targetId: 'wc-1',
      name: 'FIFO CEU27',
      rule: DispatchRule.lifo,
      capacity: 2,
      stockMode: InventoryMode.duration,
      stockSeconds: 48 * 3600,
      stockUnit: DurationUnit.days,
    );

    final row = await read('wc-1');
    expect(row!.name, 'FIFO CEU27');
    expect(row.rule, DispatchRule.lifo);
    expect(row.capacity, 2);
    expect(row.stockMode, InventoryMode.duration);
    expect(row.stockSeconds, 48 * 3600);
    // `2 days` has to read back as `2 days` rather than as `48 h`, which is why
    // the unit is stored beside the seconds.
    expect(row.stockUnit, DurationUnit.days);
  });

  test('saving twice edits one row rather than making two', () async {
    await queues.saveQueue(
      projectId: projectId,
      targetId: 'wc-1',
      name: 'FIFO CEU27',
      rule: DispatchRule.fifo,
    );
    await queues.saveQueue(
      projectId: projectId,
      targetId: 'wc-1',
      name: 'FIFO CEU27',
      rule: DispatchRule.earliestDueDate,
    );

    // One floor space in front of one station, however many studies reach it
    // and however often it is retuned (§7.3).
    expect(await db.select(db.projectQueues).get(), hasLength(1));
    expect((await read('wc-1'))!.rule, DispatchRule.earliestDueDate);
  });

  test('a field cleared on the dialog is cleared in the row', () async {
    await queues.saveQueue(
      projectId: projectId,
      targetId: 'wc-1',
      rule: DispatchRule.fifo,
      capacity: 2,
    );
    // The editor is a dialog over the whole queue, so a null means "unset"
    // rather than "leave alone" — a partial write would be a second way to
    // reach one row (§12.6).
    await queues.saveQueue(projectId: projectId, targetId: 'wc-1');

    final row = await read('wc-1');
    expect(row!.rule, isNull);
    expect(row.capacity, isNull);
  });

  test('an edit leaves the row created date where it was', () async {
    await queues.saveQueue(projectId: projectId, targetId: 'wc-1');
    final first = (await read('wc-1'))!.createdAt;

    await queues.saveQueue(
      projectId: projectId,
      targetId: 'wc-1',
      rule: DispatchRule.fifo,
    );

    final after = (await read('wc-1'))!;
    expect(after.createdAt, first);
    expect(
      after.updatedAt.isBefore(first),
      isFalse,
      reason: 'when the space was first described is not what an edit changes',
    );
  });

  test('two projects tune one station independently', () async {
    // Capping a lane is an *experiment* (§0's confounder run), and the seam §3
    // draws puts period-scoped numbers in the project — so it must not reach
    // every project that shares the plant.
    await queues.saveQueue(
      projectId: projectId,
      targetId: 'wc-1',
      capacity: 2,
    );
    await queues.saveQueue(projectId: otherProjectId, targetId: 'wc-1');

    expect((await read('wc-1'))!.capacity, 2);
    expect((await read('wc-1', project: otherProjectId))!.capacity, isNull);
  });

  test('deleting the project takes its queues with it', () async {
    await queues.saveQueue(projectId: projectId, targetId: 'wc-1');
    await ProjectsRepository(db).deleteProject(projectId);
    expect(await queues.watchQueues(projectId).first, isEmpty);
  });
}
