import 'package:flowmap/src/features/flow/application/takt_balance.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rebalancing rule on its own (DESIGN.md §7.4) — no database, no view and
/// no engine, because the map and the run both have to get the same answer out
/// of it and the arithmetic is the thing worth pinning.
void main() {
  const takt = Duration(minutes: 40);

  BalanceStep step(
    String? type, {
    int? measured,
    Duration? cap = takt,
    bool pinned = false,
  }) => (
    typeName: type,
    measured: measured == null ? null : Duration(minutes: measured),
    takt: cap,
    pinned: pinned,
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

  /// Pinning a station out of its group (§7.7.4). On by default, so a pin is
  /// always something someone chose.
  group('a station pinned by the user', () {
    test('keeps its measurement and takes no share', () {
      final group = balanceFlow([
        step('Cladding', measured: 30),
        step('Cladding', measured: 30, pinned: true),
        step('Cladding', measured: 30),
      ]).single;

      expect(group.indices, [0, 2]);
      // Only the two that share are in the pot — the pinned one's 30 stays its
      // own, which is what "leave this station alone" has to mean.
      expect(group.measuredTotal, const Duration(minutes: 60));
      expect(group.derived, {
        0: const Duration(minutes: 40),
        2: const Duration(minutes: 20),
      });
    });

    test('is transparent, not a wall', () {
      // The decision that only bites at three members or more: pinning the
      // middle station must not stop the outer two sharing, because it is the
      // same operation and only its content is fixed.
      final group = balanceFlow([
        step('Cladding', measured: 50),
        step('Cladding', measured: 50, pinned: true),
        step('Cladding', measured: 50),
      ]).single;

      expect(group.indices, [0, 2]);
      expect(group.derived[0], const Duration(minutes: 40));
      expect(group.derived[2], const Duration(minutes: 60));
    });

    test('pinning one of a pair leaves the other whole', () {
      // Every group on the real plant is exactly two stations, so this is the
      // case the field will actually see: nothing moves at all.
      expect(
        balanceFlow([
          step('Cladding', measured: 30, pinned: true),
          step('Cladding', measured: 30),
        ]),
        isEmpty,
      );
    });

    test('pinning every member balances nothing', () {
      expect(
        balanceFlow([
          step('Cladding', measured: 30, pinned: true),
          step('Cladding', measured: 30, pinned: true),
        ]),
        isEmpty,
      );
    });
  });

  /// What a surface says about why a step is or is not sharing work (§7.7.4).
  group('the standing a step reports', () {
    test('names each reason, from the same walk as the split', () {
      final standings = balanceStandings([
        step('Cladding', measured: 30),
        step('Cladding', measured: 30),
        step('Cladding', measured: 30, pinned: true),
        step('Cladding', measured: 0),
        step(null, measured: 30),
        step('Heat treat', measured: 30),
      ]);

      expect(standings[0], BalanceStanding.balanced);
      // The last member that takes a share holds the remainder rather than a
      // fill, and says so — the two earn different sentences (§9.5).
      expect(standings[1], BalanceStanding.balancedRemainder);
      expect(standings[2], BalanceStanding.pinned);
      expect(standings[3], BalanceStanding.noWorkHere);
      expect(standings[4], BalanceStanding.noType);
      expect(standings[5], BalanceStanding.noLikeNeighbour);
    });

    test('only the last member of a group holds the remainder', () {
      // Three that all take a share: two fill to their own takt and the third
      // takes what is left. The caption written for a fill is false of the
      // third — on CEU32 it claimed 165.2 h of content used one takt of
      // 90.7 h — so the standing has to tell them apart (§9.5).
      final standings = balanceStandings([
        step('Cladding', measured: 30),
        step('Cladding', measured: 30),
        step('Cladding', measured: 30),
      ]);

      expect(standings[0], BalanceStanding.balanced);
      expect(standings[1], BalanceStanding.balanced);
      expect(standings[2], BalanceStanding.balancedRemainder);
    });

    test('a station sitting out does not become the remainder taker', () {
      // The last *member*, not the last step of the type-run. A zero is out of
      // the pot entirely (§7.7.1), so the remainder falls on the last station
      // that actually has work.
      final standings = balanceStandings([
        step('Cladding', measured: 30),
        step('Cladding', measured: 30),
        step('Cladding', measured: 0),
      ]);

      expect(standings[0], BalanceStanding.balanced);
      expect(standings[1], BalanceStanding.balancedRemainder);
      expect(standings[2], BalanceStanding.noWorkHere);
    });

    test('a lone station of its type says so', () {
      // The sentence that would have answered this round's opening question in
      // one click.
      expect(
        balanceStandings([step('Cladding', measured: 30)])[0],
        BalanceStanding.noLikeNeighbour,
      );
    });

    test('an untyped station says that first, before anything else', () {
      // CLAD06 on the real plant: it sits beside CLAD25 and would be a group,
      // and the reason it is not is the missing type rather than the
      // neighbour.
      final standings = balanceStandings([
        step(null, measured: 30),
        step('Cladding', measured: 30),
      ]);

      expect(standings[0], BalanceStanding.noType);
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

  group('the cap allows for rework (§9.8)', () {
    // **The defect the field found by reading a Gantt**: the balance filled
    // each station to one takt of its capacity using *measured* work, and the
    // engine then charged `measured × (1 + rework) ÷ availability`. Availability
    // cancels; rework does not — so a balanced station was over its takt by
    // exactly `(1 + rework)`, every time, on every station with any.
    //
    // Measured on the live plant at two availabilities, 1.00 and 0.83, and the
    // overshoot was 1.037 in both.

    /// What the engine charges for [measured] at a station, in its open clock.
    Duration charged(Duration measured, double rework, double availability) =>
        Duration(
          seconds: (measured.inSeconds * (1 + rework) / availability).round(),
        );

    test('a station filled to the cap is charged exactly one takt', () {
      // CLAD06 as it stands: 22.78 h open a day, availability 1.00, rework
      // 3.7 %, a four-day takt.
      const openPerDay = Duration(minutes: 1367); // 22.78 h
      const taktDays = 4;
      const rework = 0.037;
      const availability = 1.0;

      final capacity = openPerDay * taktDays * availability;
      final cap = contentThatFitsInOneTakt(capacity, rework);

      // The whole claim, in one line: fill to the cap, pay the rework, and the
      // station has used one takt of its open time and no more.
      final used = charged(cap, rework, availability);
      expect(used.inMinutes, closeTo((openPerDay * taktDays).inMinutes, 1));
    });

    test('and it holds at an availability that is not 1', () {
      // CEU27 and CEU26 run at 0.83. If availability did not cancel, this
      // would come out somewhere else entirely — which is why the fix divides
      // by rework alone.
      const openPerDay = Duration(minutes: 1367);
      const taktDays = 4;
      const rework = 0.037;
      const availability = 0.83;

      final capacity = Duration(
        seconds: ((openPerDay * taktDays).inSeconds * availability).round(),
      );
      final cap = contentThatFitsInOneTakt(capacity, rework);

      final used = charged(cap, rework, availability);
      expect(used.inMinutes, closeTo((openPerDay * taktDays).inMinutes, 2));
    });

    test('the old cap was over by exactly the rework, and this shows it', () {
      const capacity = Duration(hours: 100);
      const rework = 0.037;

      // What the balance used to fill to, charged:
      final before = charged(capacity, rework, 1);
      expect(before.inMinutes, closeTo(103.7 * 60, 1));

      // And what it fills to now:
      final after = charged(contentThatFitsInOneTakt(capacity, rework), rework, 1);
      expect(after.inMinutes, closeTo(100 * 60, 1));
    });

    test('no rework leaves the cap exactly as it was', () {
      // Every station without rework must balance byte for byte as before, or
      // this round would move figures it has no business moving.
      const capacity = Duration(hours: 100);
      expect(contentThatFitsInOneTakt(capacity, 0), capacity);
      expect(contentThatFitsInOneTakt(capacity, -1), capacity);
    });

    test('the group still fills the first and leaves the rest on the last', () {
      // The rule itself is untouched — only the cap it fills to. Two cladding
      // machines, 113 h measured between them, a cap of 91.1 h of capacity.
      final capacity = const Duration(minutes: 5466); // 91.1 h
      final cap = contentThatFitsInOneTakt(capacity, 0.037); // 87.8 h

      final groups = balanceFlow([
        (
          typeName: 'Cladding',
          measured: const Duration(minutes: 4620), // 77 h
          takt: cap,
          pinned: false,
        ),
        (
          typeName: 'Cladding',
          measured: const Duration(minutes: 2160), // 36 h
          takt: cap,
          pinned: false,
        ),
      ]);

      final derived = groups.single.derived;
      expect(derived[0], cap, reason: 'the first fills to the cap');
      expect(
        derived[0]! + derived[1]!,
        const Duration(minutes: 4620 + 2160),
        reason: 'and nothing is created or lost between them',
      );
      // The first is now charged exactly one takt rather than 3.7 % over it.
      expect(
        (derived[0]!.inSeconds * 1.037).round(),
        closeTo(capacity.inSeconds, 60),
      );
    });
  });
}
