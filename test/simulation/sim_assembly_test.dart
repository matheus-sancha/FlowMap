import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/schedules/application/takt_schedule.dart';
import 'package:flowmap/src/features/simulation/application/sim_assembly.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Turning stored rows into a run (DESIGN.md §7, §5.5, §7.2).
void main() {
  final now = DateTime(2026, 8, 1);

  final study = Study(
    id: 'study-1',
    projectId: 'project-1',
    productionCellId: 'cell-1',
    productionLineId: 'line-1',
    name: 'Current state',
    includeInSimulation: true,
    startBufferDays: 0,
    priority: 7,
    wipCap: 3,
    createdAt: now,
    updatedAt: now,
  );

  FlowNode step(
    int position, {
    String? workcenterId,
    String? poolId,
    int changeover = 0,
  }) => FlowNode(
    id: 'node-$position',
    studyId: 'study-1',
    position: position,
    kind: FlowNodeKind.step,
    workcenterId: workcenterId,
    poolId: poolId,
    changeoverSeconds: 0,
    setupValue: changeover == 0 ? null : changeover.toDouble(),
    setupUnit: TaktUnit.seconds,
    inventoryUsesWorkingTime: false,
    createdAt: now,
    updatedAt: now,
  );

  FlowNode buffer(
    int position, {
    required InventoryMode mode,
    int? quantity,
    int? seconds,
    bool usesWorkingTime = false,
  }) => FlowNode(
    id: 'node-$position',
    studyId: 'study-1',
    position: position,
    kind: FlowNodeKind.inventory,
    changeoverSeconds: 0,
    inventoryMode: mode,
    inventoryQuantity: quantity,
    inventorySeconds: seconds,
    inventoryUsesWorkingTime: usesWorkingTime,
    createdAt: now,
    updatedAt: now,
  );

  DemandPart part(String id, String number, {String? description}) =>
      DemandPart(
        id: id,
        studyId: 'study-1',
        partNumber: number,
        description: description,
        createdAt: now,
        updatedAt: now,
      );

  DemandOrder order(
    int sequence,
    String partId, {
    int batch = 1,
    String? project,
  }) => DemandOrder(
    id: 'o$sequence',
    studyId: 'study-1',
    partId: partId,
    sequence: sequence,
    batchSize: batch,
    customerProject: project,
    needDate: DateTime(2026, 8, 20),
    createdAt: now,
    updatedAt: now,
  );

  TaktScheduleSpec taktOf(double value, TaktUnit unit) => TaktScheduleSpec([
    TaktPeriodSpec(
      startDate: DateTime(2026),
      endDate: DateTime(2026, 12, 31),
      value: value,
      unit: unit,
    ),
  ]);

  SimResourceContext resources({
    Map<String, List<String>> pools = const {},
    Map<String, Duration> productive = const {
      'W': Duration(hours: 10),
      'X': Duration(hours: 10),
    },
  }) => SimResourceContext(
    workcenterNames: const {
      'W': 'CLAD04',
      'X': 'TTAT',
      'L1': 'LAT01',
      'L2': 'LAT02',
    },
    poolNames: const {'pool-1': 'CNC Lathes'},
    poolMembers: pools,
    productivePerWorkingDay: productive,
    cellNames: const {'cell-1': 'Cell A'},
    lineNames: const {'line-1': 'Line 1'},
  );

  test('a plain flow assembles into steps, parts and a sequence', () {
    final built = assembleSimStudy(
      study: study,
      nodes: [
        step(0, workcenterId: 'W', changeover: 1800),
        step(1, workcenterId: 'X'),
      ],
      parts: [part('p1', 'PN1')],
      processTimes: {
        'p1': {'W': const Duration(hours: 2), 'X': const Duration(hours: 1)},
      },
      orders: [order(0, 'p1'), order(1, 'p1', batch: 4)],
      taktSchedule: taktOf(3, TaktUnit.hours),
      resources: resources(),
      asOf: now,
    );

    expect(built, isNotNull);
    expect(built!.steps.map((s) => s.title), ['CLAD04', 'TTAT']);
    // The setup travels as a value and a unit rather than a duration, because
    // `days` would mean a different thing at each member of a pool (§7.6).
    expect(built.steps.first.setupValue, 1800);
    expect(built.steps.first.setupUnit, TaktUnit.seconds);
    expect(built.orders.map((o) => o.batchSize), [1, 4]);
    expect(built.parts['p1']!.timeAt('W'), const Duration(hours: 2));
    // The study's own dispatch keys travel with it (§7.4, §7.3).
    expect(built.priority, 7);
    expect(built.wipCap, 3);

    // And where it sat in the plant, ids and names both, so §12.1's filters can
    // read a stored run without joining back to a study that may have moved
    // (§7.10). Assembled rather than looked up at save time, which is what
    // makes the run a record of the moment it ran (§8.5).
    expect(built.productionCellId, 'cell-1');
    expect(built.productionCellName, 'Cell A');
    expect(built.productionLineId, 'line-1');
    expect(built.productionLineName, 'Line 1');
  });

  group('release cadence (§7.2)', () {
    test('a takt in hours is that many hours between slots', () {
      final built = assembleSimStudy(
        study: study,
        nodes: [step(0, workcenterId: 'W')],
        parts: [part('p1', 'PN1')],
        processTimes: {
          'p1': {'W': const Duration(hours: 1)},
        },
        orders: [order(0, 'p1')],
        taktSchedule: taktOf(4, TaktUnit.hours),
        resources: resources(),
        asOf: now,
      );

      expect(built!.releaseInterval, const Duration(hours: 4));
    });

    test('a takt in days is that many productive days of the pace-setter', () {
      // W carries far more work than X, so it sets the pace — and a day there
      // is 10 productive hours (§6.1).
      final built = assembleSimStudy(
        study: study,
        nodes: [
          step(0, workcenterId: 'W'),
          step(1, workcenterId: 'X'),
        ],
        parts: [part('p1', 'PN1')],
        processTimes: {
          'p1': {'W': const Duration(hours: 9), 'X': const Duration(hours: 1)},
        },
        orders: [order(0, 'p1')],
        taktSchedule: taktOf(3, TaktUnit.days),
        resources: resources(
          productive: const {'W': Duration(hours: 10), 'X': Duration(hours: 4)},
        ),
        asOf: now,
      );

      expect(built!.releaseCalendarId, 'W');
      expect(built.releaseInterval, const Duration(hours: 30));
    });

    test('work content counts batch size, so the mix can move the pace', () {
      // Two parts that barely touch each other's station. Which one is built
      // in larger batches decides where the work lands — batch size cannot
      // flip the ranking within a single order, because it scales every step
      // of that order alike.
      String? paceFor({required int pn1Batch, required int pn2Batch}) =>
          assembleSimStudy(
            study: study,
            nodes: [
              step(0, workcenterId: 'W'),
              step(1, workcenterId: 'X'),
            ],
            parts: [part('p1', 'PN1'), part('p2', 'PN2')],
            processTimes: {
              'p1': {'W': const Duration(hours: 10)},
              'p2': {'X': const Duration(hours: 10)},
            },
            orders: [
              order(0, 'p1', batch: pn1Batch),
              order(1, 'p2', batch: pn2Batch),
            ],
            taktSchedule: taktOf(1, TaktUnit.days),
            resources: resources(),
            asOf: now,
          )?.releaseCalendarId;

      expect(paceFor(pn1Batch: 5, pn2Batch: 1), 'W');
      expect(paceFor(pn1Batch: 1, pn2Batch: 5), 'X');
    });
  });

  group('buffers (§5.5)', () {
    /// A run carries a buffer as a node and nothing else.
    ///
    /// Whatever was typed on it — a wait in hours, or a count of pieces — stays
    /// on the node for the map's lead-time ladder and never reaches the engine.
    /// The figure is an *observation* of a current state, and how long an order
    /// really waits is the question the run exists to answer.
    void expectsNoTime(InventoryMode mode, {int? seconds, int? quantity}) {
      final built = assembleSimStudy(
        study: study,
        nodes: [
          step(0, workcenterId: 'W'),
          buffer(1, mode: mode, seconds: seconds, quantity: quantity),
          step(2, workcenterId: 'X'),
        ],
        parts: [part('p1', 'PN1')],
        processTimes: {
          'p1': {'W': const Duration(hours: 1), 'X': const Duration(hours: 1)},
        },
        orders: [order(0, 'p1')],
        taktSchedule: taktOf(1, TaktUnit.days),
        resources: resources(
          productive: const {'W': Duration(hours: 10), 'X': Duration(hours: 4)},
        ),
        asOf: now,
      );

      // Still a node, so the engine's view of a flow stays a faithful image of
      // the map's — same nodes, same positions.
      expect(built!.nodes.whereType<SimBuffer>().single.position, 1);
    }

    test('a fixed wait reaches the run carrying no time', () {
      expectsNoTime(InventoryMode.duration, seconds: 48 * 3600);
    });

    test('a piece count reaches the run carrying no time', () {
      expectsNoTime(InventoryMode.quantity, quantity: 5);
    });
  });

  group('pools (§3.1)', () {
    test('a pool step offers every member, and keys on the pool', () {
      final built = assembleSimStudy(
        study: study,
        nodes: [step(0, poolId: 'pool-1')],
        parts: [part('p1', 'PN1')],
        processTimes: {
          'p1': {'pool-1': const Duration(hours: 2)},
        },
        orders: [order(0, 'p1')],
        taktSchedule: taktOf(1, TaktUnit.hours),
        resources: resources(
          pools: const {
            'pool-1': ['L2', 'L1'],
          },
          productive: const {
            'L1': Duration(hours: 10),
            'L2': Duration(hours: 10),
          },
        ),
        asOf: now,
      );

      final step0 = built!.steps.single;
      // Sorted, so two runs of the same study cannot disagree about which
      // member is tried first (§4.4).
      expect(step0.candidates, ['L1', 'L2']);
      expect(step0.demandKey, 'pool-1');
      expect(step0.title, 'CNC Lathes');
    });

    test('an empty pool is a refusal, not a step nobody can run', () {
      final problems = <SimAssemblyProblem>[];
      final built = assembleSimStudy(
        study: study,
        nodes: [step(0, poolId: 'pool-1')],
        parts: [part('p1', 'PN1')],
        processTimes: const {},
        orders: [order(0, 'p1')],
        taktSchedule: taktOf(1, TaktUnit.hours),
        resources: resources(pools: const {'pool-1': []}),
        asOf: now,
        problems: problems,
      );

      expect(built, isNull);
      expect(problems, contains(SimAssemblyProblem.unboundStep));
    });
  });

  group('refusals', () {
    test('an unbound step stops the run rather than guessing', () {
      final problems = <SimAssemblyProblem>[];
      final built = assembleSimStudy(
        study: study,
        nodes: [step(0)],
        parts: [part('p1', 'PN1')],
        processTimes: const {},
        orders: [order(0, 'p1')],
        taktSchedule: taktOf(1, TaktUnit.hours),
        resources: resources(),
        asOf: now,
        problems: problems,
      );

      expect(built, isNull);
      expect(problems, contains(SimAssemblyProblem.unboundStep));
    });

    test('no takt is no cadence', () {
      final problems = <SimAssemblyProblem>[];
      final built = assembleSimStudy(
        study: study,
        nodes: [step(0, workcenterId: 'W')],
        parts: [part('p1', 'PN1')],
        processTimes: {
          'p1': {'W': const Duration(hours: 1)},
        },
        orders: [order(0, 'p1')],
        taktSchedule: TaktScheduleSpec(const []),
        resources: resources(),
        asOf: now,
        problems: problems,
      );

      expect(built, isNull);
      expect(problems, [SimAssemblyProblem.noTakt]);
    });

    test('an empty sequence has nothing to release', () {
      final problems = <SimAssemblyProblem>[];
      final built = assembleSimStudy(
        study: study,
        nodes: [step(0, workcenterId: 'W')],
        parts: [part('p1', 'PN1')],
        processTimes: const {},
        orders: const [],
        taktSchedule: taktOf(1, TaktUnit.hours),
        resources: resources(),
        asOf: now,
        problems: problems,
      );

      expect(built, isNull);
      expect(problems, [SimAssemblyProblem.noOrders]);
    });
  });

  test('the part carries its description, the order carries its project', () {
    // Two orders of **one** part for two different projects — the case that
    // could not exist before v14, when the project was half of what identified
    // a part and this would have been two parts with two sets of times (§9.3).
    final built = assembleSimStudy(
      study: study,
      nodes: [step(0, workcenterId: 'W')],
      parts: [
        part('p1', 'PN1', description: 'PWB 10K'),
        part('p2', 'PN2'),
      ],
      processTimes: {
        'p1': {'W': const Duration(hours: 2)},
        'p2': {'W': const Duration(hours: 1)},
      },
      orders: [
        order(0, 'p1', project: 'Wing 7'),
        order(1, 'p1', project: 'Wing 9'),
        order(2, 'p2'),
      ],
      taktSchedule: taktOf(3, TaktUnit.hours),
      resources: resources(),
      asOf: now,
    );

    // Passengers the engine never reads. They ride here so `saveRun` can copy
    // them into the run (§7.10) — the only moment they are still guaranteed to
    // describe the demand this run was assembled from.
    expect(built!.parts['p1']!.partNumber, 'PN1');
    expect(built.parts['p1']!.description, 'PWB 10K');
    expect(built.parts['p2']!.description, isNull);

    // Both orders point at the same part and its single set of process times,
    // and each says which project it is for.
    expect(built.orders.map((o) => o.partId), ['p1', 'p1', 'p2']);
    expect(built.orders.map((o) => o.customerProject), [
      'Wing 7',
      'Wing 9',
      null,
    ]);
  });

  test('a part with no time anywhere still assembles — §11 reports it', () {
    // The assembler is not the readiness panel. A part missing a process time
    // is a blocking error the panel names; here it simply arrives with an
    // empty map, and the engine leaves its orders undelivered.
    final built = assembleSimStudy(
      study: study,
      nodes: [step(0, workcenterId: 'W')],
      parts: [part('p1', 'PN1'), part('p2', 'PN2')],
      processTimes: {
        'p1': {'W': const Duration(hours: 1)},
      },
      orders: [order(0, 'p1'), order(1, 'p2')],
      taktSchedule: taktOf(1, TaktUnit.hours),
      resources: resources(),
      asOf: now,
    );

    expect(built!.parts['p2']!.processTimes, isEmpty);
    expect(built.orders, hasLength(2));
  });

  group('stationPools — which pool a run says a station ran in (§3.1)', () {
    SimStudy built({
      required List<FlowNode> nodes,
      Map<String, List<String>> pools = const {},
    }) => assembleSimStudy(
      study: study,
      nodes: nodes,
      parts: [part('p1', 'PN1')],
      processTimes: {
        'p1': {
          'W': const Duration(hours: 1),
          'pool-1': const Duration(hours: 1),
          'pool-2': const Duration(hours: 1),
        },
      },
      orders: [order(0, 'p1')],
      taktSchedule: taktOf(1, TaktUnit.hours),
      resources: resources(pools: pools),
      asOf: now,
    )!;

    test('a pool names every one of its members', () {
      final map = stationPools([
        built(
          nodes: [step(0, poolId: 'pool-1')],
          pools: {
            'pool-1': ['L1', 'L2'],
          },
        ),
      ]);

      // Both members, under the name the reader typed — which is the whole
      // complaint: three loose machines where a pool was drawn.
      expect(map['L1']!.id, 'pool-1');
      expect(map['L1']!.name, 'CNC Lathes');
      expect(map['L2']!.id, 'pool-1');
    });

    test('a station named directly is absent, not grouped under nothing', () {
      final map = stationPools([
        built(nodes: [step(0, workcenterId: 'W')]),
      ]);

      // Absent rather than present-with-a-null-id: a station that no step
      // reached through a pool has nothing to say, and a row saying "no pool"
      // would be a row the views have to skip.
      expect(map.containsKey('W'), isFalse);
    });

    test('two pools over one station leave it ungrouped, naming both', () {
      // The case §7.7 makes reachable and `WorkcenterPoolMembers` allows: two
      // studies in one run, each reaching L1 through a different pool. There is
      // no correct single answer, so there is no grouping — and the names still
      // say why it is standing on its own.
      final map = stationPools([
        built(
          nodes: [step(0, poolId: 'pool-1')],
          pools: {
            'pool-1': ['L1'],
          },
        ),
        built(
          nodes: [step(0, poolId: 'pool-2')],
          pools: {
            'pool-2': ['L1'],
          },
        ),
      ]);

      expect(map['L1']!.id, isNull);
      // Sorted, so the label cannot depend on the order the project happens to
      // list its studies in.
      expect(map['L1']!.name, 'CNC Lathes · pool-2');
    });
  });
}
