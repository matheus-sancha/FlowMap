import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/demand/application/demand_table.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the demand grid says about itself, with no database and no widget tree
/// (DESIGN.md §9, §5.1).
void main() {
  final now = DateTime(2026, 8, 1);

  DemandPart part(String id, String number) => DemandPart(
    id: id,
    studyId: 'study-1',
    partNumber: number,
    createdAt: now,
    updatedAt: now,
  );

  FlowNode step(int position, {String? workcenterId, String? poolId}) =>
      FlowNode(
        id: 'node-$position',
        studyId: 'study-1',
        position: position,
        kind: FlowNodeKind.step,
        workcenterId: workcenterId,
        poolId: poolId,
        changeoverSeconds: 0,
        inventoryUsesWorkingTime: false,
        createdAt: now,
        updatedAt: now,
      );

  group('demandTargetOf', () {
    test('a pool step keys on the pool, not on a member', () {
      // Pool members are interchangeable (§3.1), so a part has one process time
      // at `CNC Lathes` — not one per lathe.
      expect(
        demandTargetOf(step(0, poolId: 'pool-1', workcenterId: null)),
        'pool-1',
      );
    });

    test('a workcenter step keys on the workcenter', () {
      expect(demandTargetOf(step(0, workcenterId: 'wc-1')), 'wc-1');
    });

    test('an unbound step keys on nothing', () {
      expect(demandTargetOf(step(0)), isNull);
    });
  });

  group('DemandTable', () {
    final pn1 = part('p1', 'PN1');
    final pn2 = part('p2', 'PN2');

    const columns = [
      DemandColumn(nodeId: 'node-0', targetId: 'wc-1', title: 'CLAD04'),
      DemandColumn(nodeId: 'node-1', targetId: 'wc-2', title: 'TTAT'),
    ];

    test('a total sums the columns the flow actually has', () {
      final table = DemandTable(
        parts: [pn1],
        columns: columns,
        times: {
          'p1': {
            'node-0': const Duration(hours: 55),
            'node-1': const Duration(hours: 3),
            // A time left behind by a step since removed from the flow. It is
            // kept — removing a step hides its values rather than destroying
            // them — but it is not paid for.
            'node-9': const Duration(hours: 100),
          },
        },
      );

      expect(table.totalFor('p1'), const Duration(hours: 58));
    });

    test('two visits to one station cost what each of them was given', () {
      // **§9's headline case, and it could not be written before.** These two
      // columns share a target and until v24 shared a stored value too, so the
      // second pass was always charged whatever the first was. It is charged
      // four hours here and the first ten, which is what a routing revisit
      // usually means: rough then finish, not the same operation twice.
      const revisit = [
        DemandColumn(nodeId: 'node-0', targetId: 'wc-1', title: 'CLAD04'),
        DemandColumn(nodeId: 'node-1', targetId: 'wc-2', title: 'TTAT'),
        DemandColumn(nodeId: 'node-2', targetId: 'wc-1', title: 'CLAD04'),
      ];
      final table = DemandTable(
        parts: [pn1],
        columns: revisit,
        times: {
          'p1': {
            'node-0': const Duration(hours: 10),
            'node-1': const Duration(hours: 3),
            'node-2': const Duration(hours: 4),
          },
        },
      );

      expect(table.totalFor('p1'), const Duration(hours: 17));
    });

    test('a second visit with no time of its own is missing, not inherited', () {
      // The other half of the same change. Sharing a target no longer shares a
      // value, so a step nobody has costed is uncosted — a blocking readiness
      // error (§11) rather than a silent copy of the first pass.
      const revisit = [
        DemandColumn(nodeId: 'node-0', targetId: 'wc-1', title: 'CLAD04'),
        DemandColumn(nodeId: 'node-2', targetId: 'wc-1', title: 'CLAD04'),
      ];
      final table = DemandTable(
        parts: [pn1],
        columns: revisit,
        times: {
          'p1': {'node-0': const Duration(hours: 10)},
        },
      );

      expect(table.totalFor('p1'), const Duration(hours: 10));
      expect(table.isFullyCosted('p1'), isFalse);
      expect(
        table.missingCells.map((c) => c.column.nodeId),
        ['node-2'],
        reason: 'the second visit is named, and the first is not',
      );
    });

    test('a blank cell costs nothing and is reported as missing', () {
      final table = DemandTable(
        parts: [pn1, pn2],
        columns: columns,
        times: {
          'p1': {
            'node-0': const Duration(hours: 55),
            'node-1': const Duration(hours: 3),
          },
          'p2': {'node-0': const Duration(hours: 8)},
        },
      );

      expect(table.totalFor('p2'), const Duration(hours: 8));
      expect(table.isFullyCosted('p1'), isTrue);
      expect(table.isFullyCosted('p2'), isFalse);

      final missing = table.missingCells.toList();
      expect(missing, hasLength(1));
      expect(missing.single.part.partNumber, 'PN2');
      expect(missing.single.column.title, 'TTAT');
    });

    test('an unbound column can hold nothing, and says so', () {
      final table = DemandTable(
        parts: [pn1],
        columns: const [
          DemandColumn(nodeId: 'node-0', targetId: null, title: '—'),
        ],
        times: {
          'p1': {'wc-1': const Duration(hours: 55)},
        },
      );

      expect(table.timeFor('p1', null), isNull);
      expect(table.totalFor('p1'), Duration.zero);
      expect(table.missingCells, hasLength(1));
    });
  });
}
