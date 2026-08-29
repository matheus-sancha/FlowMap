import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/database_providers.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/demand/data/demand_repository.dart';
import 'package:flowmap/src/features/projects/data/projects_repository.dart';
import 'package:flowmap/src/features/resources/data/resources_repository.dart';
import 'package:flowmap/src/features/schedules/data/schedules_repository.dart';
import 'package:flowmap/src/features/simulation/application/sim_assembly.dart';
import 'package:flowmap/src/features/simulation/application/simulation_providers.dart';
import 'package:flowmap/src/features/studies/data/studies_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the assembled run watches (DESIGN.md §6.2.1, §11).
///
/// `simRunInputProvider` is a cache with a hand-written watch list, and a watch
/// list is the kind of thing that is correct on the day it is written and
/// silently short a year later. That is not hypothetical here: it watched the
/// schedules, the flow and the demand and **nothing of the plant**, so editing a
/// workcenter's type left the cached input in place and Simulate re-ran the
/// plant as it stood before the edit — harmless while a type was an icon on a
/// box, load-bearing the moment §6.2.1 formed a balance group on one.
///
/// The repository beside this is tested by calling `assembleRun` directly,
/// which answers *what a project assembles into* and cannot answer *when*. So
/// this file is the first in the suite to build a `ProviderContainer`: a real
/// database under real providers, an edit written to it, and the assembled run
/// asked whether it noticed. Nothing here is a widget — what is under test is
/// the wiring between a table and a cache.
void main() {
  late AppDatabase db;
  late ResourcesRepository resources;
  late ProjectsRepository projects;
  late SchedulesRepository schedules;
  late StudiesRepository studies;
  late DemandRepository demand;
  late ProviderContainer container;

  late String lineId;
  late String cladId;
  late String millId;
  late String claddingId;
  late String projectId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    resources = ResourcesRepository(db);
    projects = ProjectsRepository(db);
    schedules = SchedulesRepository(db, resources);
    studies = StudiesRepository(db);
    demand = DemandRepository(db);

    final plantId = await resources.createPlant(name: 'Werk Nord');
    final cellId = await resources.createCell(plantId: plantId, name: 'Cell A');
    lineId = await resources.createLine(cellId: cellId, name: 'Line 1');

    // Two adjacent stations, both untyped to begin with — which is every flow
    // in the app before §6.2.1 existed, and the state the balance finds no
    // group in.
    cladId = await resources.createWorkcenter(
      plantId: plantId,
      name: 'CLAD04',
      lineIds: {lineId},
    );
    millId = await resources.createWorkcenter(
      plantId: plantId,
      name: 'CLAD05',
      lineIds: {lineId},
    );

    // Taken from the seeded picklist rather than created here, and that is not
    // only convenience: writing a type row would fire `workcenterTypesProvider`,
    // and the edit under test has to be a write to `workcenters` and nothing
    // else, or it would not say which watch caught it.
    final types = await resources.watchWorkcenterTypes().first;
    claddingId = types.firstWhere((t) => t.name == 'Cladding').id;

    final patterns = await resources.watchShiftPatterns().first;
    projectId = await projects.createProject(
      name: 'H2 2026',
      plantId: plantId,
      shiftPatternId: patterns.firstWhere((p) => p.name == 'ABC').id,
    );

    for (final workcenterId in [cladId, millId]) {
      await schedules.createWorkcenterSchedulePeriod(
        projectId: projectId,
        workcenterId: workcenterId,
        startDate: DateTime(2026),
        endDate: DateTime(2026, 12, 31),
        operatorsPerShift: const [1, 1, 1],
        availability: 1,
        rework: 0,
      );
    }
    await schedules.createTaktPeriod(
      projectId: projectId,
      productionLineId: lineId,
      startDate: DateTime(2026),
      endDate: DateTime(2026, 12, 31),
      takt: 6,
      unit: TaktUnit.hours,
    );

    final studyId = await studies.createStudy(
      projectId: projectId,
      productionCellId: cellId,
      productionLineId: lineId,
      name: 'Current state',
    );
    // The ids the steps came back with: §9 keys a process time by the node,
    // and the foreign key refuses a workcenter id standing in for one.
    final stepIds = <String>[];
    for (var i = 0; i < 2; i++) {
      stepIds.add(
        await studies.insertStep(
          studyId: studyId,
          atPosition: i,
          workcenterId: [cladId, millId][i],
        ),
      );
    }
    final partId = await demand.createPart(studyId: studyId, partNumber: 'PN1');
    for (final stepId in stepIds) {
      await demand.setProcessTime(
        partId: partId,
        nodeId: stepId,
        time: const Duration(hours: 2),
      );
    }
    await demand.createOrder(
      studyId: studyId,
      partId: partId,
      needDate: DateTime(2026, 8, 20),
    );
    await studies.setIncludedInSimulation(studyId, true);

    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    // Kept subscribed for the life of the test: an unlistened provider is not
    // recomputed when something it watches emits, so without this the test
    // would be asking a cache nobody is reading whether it had refreshed.
    container.listen(simRunInputProvider(projectId), (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// The assembled run once [settled] holds of it, or the last one seen.
  ///
  /// A write, a stream emission, a provider rebuild and an `assembleRun` are
  /// four asynchronous hops, so the value is polled rather than awaited once —
  /// and polled for what the test is about rather than for a fixed delay, so it
  /// is as quick as the machine allows and does not go flaky on a slow one.
  Future<SimRunInput> assembledUntil(bool Function(SimRunInput) settled) async {
    var input = await container.read(simRunInputProvider(projectId).future);
    for (var i = 0; i < 200 && !settled(input); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      input = await container.read(simRunInputProvider(projectId).future);
    }
    return input;
  }

  /// What the balance placed on each station, keyed by station.
  ///
  /// Written over every study rather than over the one there is, because the
  /// first value this provider produces carries none at all — see below.
  Map<String, Duration> sharesOf(SimRunInput input) => {
    for (final study in input.studies)
      for (final step in study.steps)
        step.candidates.single:
            ?step.balancedProcessTimes.values.firstOrNull?.values.firstOrNull,
  };

  test('a workcenter typed after the run was assembled reaches it', () async {
    // **The first value is empty and that is not a failure**: the flagged
    // studies arrive on a stream, and `simRunInputProvider` answers with
    // `SimRunInput.empty()` until it has emitted rather than blocking the
    // readiness panel behind it. So the starting state is settled for, exactly
    // as the state under test is.
    //
    // Nothing is alike yet, so there is no group and every station keeps what
    // was measured at it — asserted rather than assumed, because a test whose
    // first state is already its second one would pass against a provider that
    // never rebuilt at all.
    final before = await assembledUntil((input) => input.studies.isNotEmpty);
    expect(before.canRun, isTrue);
    expect(sharesOf(before), isEmpty);

    // The edit a planner makes on the Workcenters screen, and nothing else:
    // `lineIds` is left null so the write lands on `workcenters` alone.
    for (final id in [cladId, millId]) {
      await resources.updateWorkcenter(
        id,
        name: id == cladId ? 'CLAD04' : 'CLAD05',
        typeId: claddingId,
      );
    }

    // Two like stations in a row is a group, and 4 h of work fits inside one
    // 6 h takt — so the first station is filled to what it can hold and the
    // last is left the remainder, which here is none (§6.2.1).
    final after = await assembledUntil((input) => sharesOf(input).isNotEmpty);
    expect(
      sharesOf(after),
      {cladId: const Duration(hours: 4), millId: Duration.zero},
      reason: 'the run assembled against a plant the user has already changed',
    );
  });

  test('untyping a station puts the work back where it was measured', () async {
    for (final id in [cladId, millId]) {
      await resources.updateWorkcenter(
        id,
        name: id == cladId ? 'CLAD04' : 'CLAD05',
        typeId: claddingId,
      );
    }
    await assembledUntil((input) => sharesOf(input).isNotEmpty);

    // The other direction, and it is worth having both: a stale cache holding
    // the *balanced* figures describes a plant the user has just told the app
    // it does not have, and every box, ladder and bar downstream would go on
    // showing a split that no longer applies to anything.
    await resources.updateWorkcenter(millId, name: 'CLAD05');

    final after = await assembledUntil((input) => sharesOf(input).isEmpty);
    expect(
      sharesOf(after),
      isEmpty,
      reason: 'a station with no type is in no group (§6.2.1)',
    );
  });
}
