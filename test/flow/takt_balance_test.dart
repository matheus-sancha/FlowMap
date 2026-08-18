import 'package:flowmap/src/features/flow/application/takt_balance.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rebalancing rule on its own (DESIGN.md §7.4) — no database, no view and
/// no engine, because the map and the run both have to get the same answer out
/// of it and the arithmetic is the thing worth pinning.
void main() {
  const takt = Duration(minutes: 40);

  BalanceStep step(String? type, {int? measured, Duration? cap = takt}) => (
    typeName: type,
    measured: measured == null ? null : Duration(minutes: measured),
    takt: cap,
  );

  group('what makes a group', () {
    test('adjacent steps of one type are one group', () {
      final groups = balanceFlow([
        step('Cladding', measured: 30),
        step('Cladding', measured: 30),
        step('Cladding', measured: 30),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.typeName, 'Cladding');
      expect(groups.single.indices, [0, 1, 2]);
    });

    test('a furnace between two claddings makes two groups', () {
      // Adjacency is what makes the rule physical: work cannot move across an
      // intervening operation, so cladding again after heat treat is a
      // different operation rather than more of the same one.
      final groups = balanceFlow([
        step('Cladding', measured: 30),
        step('Cladding', measured: 30),
        step('Heat treat', measured: 60),
        step('Cladding', measured: 20),
        step('Cladding', measured: 20),
      ]);

      expect(groups, hasLength(2));
      expect(groups.first.indices, [0, 1]);
      expect(groups.last.indices, [3, 4]);
    });

    test('a lone station is not a group and keeps what was measured', () {
      // The case that has to stay exactly as it was: a flow of unlike machines
      // must behave as it did before this rule existed.
      final groups = balanceFlow([
        step('Cladding', measured: 30),
        step('Heat treat', measured: 60),
        step('Test', measured: 10),
      ]);

      expect(groups, isEmpty);
      expect(balancedProcessTimes([
        step('Cladding', measured: 30),
        step('Heat treat', measured: 60),
      ]), isEmpty);
    });

    test('a step with no type joins nothing, and breaks the run', () {
      // An unbound step, or one whose station was never typed. It cannot be
      // balanced against anything, and it separates what is on either side of
      // it for the same reason a furnace does.
      final groups = balanceFlow([
        step('Cladding', measured: 30),
        step(null, measured: 30),
        step('Cladding', measured: 30),
      ]);

      expect(groups, isEmpty);
    });
  });

  group('the split', () {
    test('each fills to takt and the last takes the remainder', () {
      // 90 minutes of work across three 40-minute stations: 40, 40, and 10 left
      // over on the last.
      final groups = balanceFlow([
        step('Cladding', measured: 30),
        step('Cladding', measured: 30),
        step('Cladding', measured: 30),
      ]);

      expect(groups.single.derived, {
        0: const Duration(minutes: 40),
        1: const Duration(minutes: 40),
        2: const Duration(minutes: 10),
      });
    });

    test('the last station may be over takt, and that is the finding', () {
      // 150 minutes across three: the group is the bottleneck and the overflow
      // shows at the end of the run rather than being smeared across it.
      final groups = balanceFlow([
        step('Cladding', measured: 50),
        step('Cladding', measured: 50),
        step('Cladding', measured: 50),
      ]);

      expect(groups.single.derived[2], const Duration(minutes: 70));
    });

    test('a group with slack leaves later stations empty', () {
      // 30 minutes across three 40-minute stations: the first swallows it and
      // the two behind it have nothing left to do.
      final groups = balanceFlow([
        step('Cladding', measured: 25),
        step('Cladding', measured: 4),
        step('Cladding', measured: 1),
      ]);

      expect(groups.single.derived, {
        0: const Duration(minutes: 30),
        1: Duration.zero,
        2: Duration.zero,
      });
    });

    test('the split always sums to what was measured', () {
      // The invariant that makes this a redistribution rather than a rewrite:
      // no work is created or lost, whatever the takt is.
      for (final cap in [1, 7, 40, 500]) {
        final group = balanceFlow([
          step('Cladding', measured: 30, cap: Duration(minutes: cap)),
          step('Cladding', measured: 45, cap: Duration(minutes: cap)),
          step('Cladding', measured: 15, cap: Duration(minutes: cap)),
        ]).single;

        expect(
          group.derived.values.fold(Duration.zero, (a, b) => a + b),
          const Duration(minutes: 90),
          reason: 'at a $cap-minute takt',
        );
        expect(group.measuredTotal, const Duration(minutes: 90));
      }
    });

    test('changing the takt moves the balance with no other edit', () {
      // The whole ask, stated as a test: the same measurements, two takts.
      List<BalanceStep> flow(int cap) => [
        step('Cladding', measured: 30, cap: Duration(minutes: cap)),
        step('Cladding', measured: 30, cap: Duration(minutes: cap)),
        step('Cladding', measured: 30, cap: Duration(minutes: cap)),
      ];

      expect(balancedProcessTimes(flow(40)), {
        0: const Duration(minutes: 40),
        1: const Duration(minutes: 40),
        2: const Duration(minutes: 10),
      });
      expect(balancedProcessTimes(flow(25)), {
        0: const Duration(minutes: 25),
        1: const Duration(minutes: 25),
        2: const Duration(minutes: 40),
      });
    });

    test('each station fills to its own takt, not to a shared one', () {
      // A three-shift station and a one-shift one of the same type: one takt is
      // worth more clock at the first, so it takes more of the work.
      final group = balanceFlow([
        step('Cladding', measured: 60, cap: const Duration(minutes: 60)),
        step('Cladding', measured: 60, cap: const Duration(minutes: 20)),
        step('Cladding', measured: 60, cap: const Duration(minutes: 20)),
      ]).single;

      expect(group.derived[0], const Duration(minutes: 60));
      expect(group.derived[1], const Duration(minutes: 20));
      expect(group.derived[2], const Duration(minutes: 100));
    });
  });

  /// A zero is how the plant says a part does not route through a station
  /// (§7.7.1). Giving one a share puts work on a machine the part never visits.
  group('a station this part does not run on', () {
    test('a zero keeps its zero and is not a member', () {
      // The defect, as data. `P1000247599` stores 0 h at CEU30 and 146 h at
      // CEU32; §7.4 gave CEU30 94.3 h of CEU32's work.
      final groups = balanceFlow([
        step('Machining', measured: 0),
        step('Machining', measured: 146),
      ]);

      // One member is not a group, so CEU32 keeps every minute of it.
      expect(groups, isEmpty);
      expect(balancedProcessTimes([
        step('Machining', measured: 0),
        step('Machining', measured: 146),
      ]), isEmpty);
    });

    test('a null is not a member either', () {
      // A blank cell is a different statement from a zero — it blocks the run
      // (§6.2) rather than saying the part skips the station — but neither is
      // positive work, so neither takes a share.
      expect(
        balanceFlow([step('Machining'), step('Machining', measured: 146)]),
        isEmpty,
      );
    });

    test('a station sitting out does not wall off its neighbours', () {
      // Transparent, not a wall: it is the same operation, it simply has no
      // work of this part. Walling here would stop two machines sharing for a
      // reason nobody asked for and nothing on screen would say.
      final group = balanceFlow([
        step('Machining', measured: 60),
        step('Machining', measured: 0),
        step('Machining', measured: 60),
      ]).single;

      expect(group.indices, [0, 2]);
      expect(group.measuredTotal, const Duration(minutes: 120));
      expect(group.derived, {
        0: const Duration(minutes: 40),
        2: const Duration(minutes: 80),
      });
      // And the station sitting out is untouched — no share, no entry.
      expect(group.derived.containsKey(1), isFalse);
    });

    test('a member sitting out takes its missing takt with it', () {
      // A station with no schedule would stop the group (see below) — but only
      // if it is a member. One this part does not run on has no cap to fill and
      // its missing schedule is not this group's problem.
      final group = balanceFlow([
        step('Machining', measured: 60),
        step('Machining', measured: 0, cap: null),
        step('Machining', measured: 60),
      ]).single;

      expect(group.indices, [0, 2]);
    });
  });

  group('when the rule refuses to answer', () {
    test('a group nothing was measured in is left alone', () {
      // Zero split three ways is three zeroes, and a zero is a number someone
      // will add up. The step's own readiness problem is what should speak.
      expect(
        balanceFlow([step('Cladding'), step('Cladding'), step('Cladding')]),
        isEmpty,
      );
    });

    test('one member with no takt stops the whole group', () {
      // No cap to fill to, so the split would be an invention. The measured
      // figures stand and the missing schedule is what gets reported.
      expect(
        balanceFlow([
          step('Cladding', measured: 30),
          step('Cladding', measured: 30, cap: null),
          step('Cladding', measured: 30),
        ]),
        isEmpty,
      );
    });

    test('an empty flow balances nothing', () {
      expect(balanceFlow(const []), isEmpty);
      expect(balancedProcessTimes(const []), isEmpty);
    });
  });
}
