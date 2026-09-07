import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a run reports (DESIGN.md §8), over runs small enough to check by hand.
void main() {
  /// Open round the clock, so a metric about queueing is about queueing.
  final always = ShiftPatternSpec(
    name: 'Continuous',
    cycleType: ShiftCycleType.rotating,
    workingWeekdays: ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5, 6, 7]),
    shifts: const [
      ShiftWindow(
        label: 'All day',
        position: 0,
        startMinute: 0,
        endMinute: 24 * 60,
        breakSeconds: 0,
      ),
    ],
  );

  SimWorkcenter workcenter(
    String id, {
    List<int> operatorsPerShift = const [1],
    bool labourPaced = false,
  }) {
    final schedule = WorkcenterScheduleSpec([
      WorkcenterSchedulePeriodSpec(
        startDate: DateTime(2020),
        endDate: DateTime(2030),
        operatorsPerShift: operatorsPerShift,
      ),
    ]);
    return SimWorkcenter(
      id: id,
      name: id,
      calendar: WorkingCalendar.scheduled(pattern: always, staffing: schedule),
      schedule: schedule,
      labourPaced: labourPaced,
    );
  }

  SimStep step(
    int position,
    String target, {
    Duration? changeover,
    Duration stock = Duration.zero,
  }) => SimStep(
    id: 'node-$position',
    position: position,
    title: target,
    candidates: [target],
    demandKey: target,
    queue: SimQueue(targetId: target),
    queueStock: stock,
    setupValue: changeover?.inSeconds.toDouble(),
    setupUnit: TaktUnit.seconds,
  );

  final aug1 = DateTime(2026, 8, 1);

  ({List<SimStudy> studies, Map<String, SimWorkcenter> workcenters}) scenario({
    required List<SimStep> nodes,
    required Map<String, SimPart> parts,
    required List<SimOrder> orders,
    required Map<String, SimWorkcenter> workcenters,
    Duration release = const Duration(hours: 10),
  }) => (
    studies: [
      SimStudy(
        id: 'study-1',
        name: 'Current state',
        nodes: nodes,
        parts: parts,
        orders: orders,
        releaseInterval: release,
      ),
    ],
    workcenters: workcenters,
  );

  group('delivery', () {
    test('float, OTD and the late count', () {
      // Two orders, one hour of work each, released ten hours apart. The first
      // is wanted well after it finishes; the second is wanted before it does.
      final setup = scenario(
        nodes: [step(0, 'W')],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {'W': Duration(hours: 1)},
          ),
        },
        orders: [
          SimOrder(
            id: 'o0',
            sequence: 0,
            partId: 'p1',
            needDate: aug1.add(const Duration(hours: 5)),
          ),
          SimOrder(
            id: 'o1',
            sequence: 1,
            partId: 'p1',
            needDate: aug1.add(const Duration(hours: 5)),
          ),
        ],
        workcenters: {'W': workcenter('W')},
      );

      final result = runSimulation(
        studies: setup.studies,
        workcenters: setup.workcenters,
        start: aug1,
      );
      final metrics = computeRunMetrics(
        result: result,
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      // o0 finishes at +1 h against a +5 h need date: four hours early.
      // o1 releases at +10 h and finishes at +11 h: six hours late.
      expect(metrics.orders, 2);
      expect(metrics.delivered, 2);
      expect(metrics.onTime, 1);
      expect(metrics.late, 1);
      expect(metrics.onTimeDelivery, 0.5);
      // Float is slack, so early is positive: (+4 h − 6 h) ÷ 2 = −1 h. The two
      // orders are unchanged; only which way the sign points is.
      expect(metrics.averageFloat, const Duration(hours: -1));
    });

    test('an order that never came out is not on time', () {
      final shut = WorkcenterScheduleSpec([
        WorkcenterSchedulePeriodSpec(
          startDate: DateTime(2020),
          endDate: DateTime(2030),
          operatorsPerShift: const [0],
        ),
      ]);
      final setup = scenario(
        nodes: [step(0, 'SHUT')],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {'SHUT': Duration(hours: 1)},
          ),
        },
        orders: [
          SimOrder(
            id: 'o0',
            sequence: 0,
            partId: 'p1',
            needDate: aug1.add(const Duration(days: 400)),
          ),
        ],
        workcenters: {
          'SHUT': SimWorkcenter(
            id: 'SHUT',
            name: 'SHUT',
            calendar: WorkingCalendar.scheduled(
              pattern: always,
              staffing: shut,
            ),
            schedule: shut,
          ),
        },
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      // Its need date is far away, so a naive "delivered late?" test would
      // call it on time. OTD counts over every order, not the delivered ones.
      expect(metrics.delivered, 0);
      expect(metrics.onTime, 0);
      expect(metrics.onTimeDelivery, 0);
      expect(metrics.averageFloat, isNull);
    });
  });

  group('lead time', () {
    test('efficiency is 1.0 when nothing queues', () {
      final setup = scenario(
        nodes: [step(0, 'W'), step(1, 'X')],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {
              'W': Duration(hours: 1),
              'X': Duration(hours: 2),
            },
          ),
        },
        orders: [
          SimOrder(
            id: 'o0',
            sequence: 0,
            partId: 'p1',
            needDate: aug1.add(const Duration(hours: 10)),
          ),
        ],
        workcenters: {'W': workcenter('W'), 'X': workcenter('X')},
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      // One order alone in an empty plant waits for nothing, so the run and
      // the standard agree exactly. Both averages count it, because they are
      // facts about an order someone was promised.
      expect(metrics.averageLeadTime, const Duration(hours: 3));
      expect(metrics.theoreticalLeadTime, const Duration(hours: 3));

      // **But the efficiency is a dash**, and that is the warm-up rule working
      // rather than a gap (§8.7). This order was released before its study had
      // delivered anything — it crossed a flow nothing had queued in — so there
      // is no settled order to compute a comparable ratio from. A number here
      // would be a figure that moves with the length of the run, which is what
      // the rule exists to stop.
      expect(metrics.leadTimeEfficiency, isNull);
      expect(metrics.warmUpOrders, 1);
      expect(metrics.settledOrders, 0);
    });

    test('queueing pulls efficiency below 100 %, over the settled orders', () {
      // Six orders released an hour apart onto a station that takes four hours
      // each, so the queue builds and never drains.
      final setup = scenario(
        nodes: [step(0, 'W')],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {'W': Duration(hours: 4)},
          ),
        },
        orders: [
          for (var i = 0; i < 6; i++)
            SimOrder(
              id: 'o$i',
              sequence: i,
              partId: 'p1',
              needDate: aug1.add(const Duration(days: 2)),
            ),
        ],
        workcenters: {'W': workcenter('W')},
        release: const Duration(hours: 1),
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      // The station runs back to back from the start, finishing at 4, 8, 12,
      // 16, 20 and 24 h. The first delivery is therefore at 4 h, so the four
      // orders released at 0, 1, 2 and 3 h are warm-up and the two released at
      // 4 and 5 h are settled.
      expect(metrics.warmUpOrders, 4);
      expect(metrics.settledOrders, 2);

      // Those two took 16 h and 19 h against a standard of 4 h each.
      expect(metrics.settledActual, const Duration(hours: 17, minutes: 30));
      expect(metrics.settledTheoretical, const Duration(hours: 4));

      // **Below 100 % is more queueing than the standard allows for** (§8.7).
      expect(metrics.leadTimeEfficiency, closeTo(4 / 17.5, 0.0001));

      // And the two averages on the card still count every order, warm-up
      // included: they are facts, not a ratio against a standard.
      expect(metrics.averageLeadTime, const Duration(hours: 11, minutes: 30));
      expect(metrics.theoreticalLeadTime, const Duration(hours: 4));
    });

    test('efficiency goes above 100 % when a queue holds stock (§7.9)', () {
      // **The reading §8 used to call impossible.** The standard charges the
      // order for standing behind the two hours of stock in front of W; the
      // engine charges nothing for it (§5.5). So a run that met no contention
      // beats the standard, and that is a finding rather than a defect.
      final setup = scenario(
        nodes: [step(0, 'W', stock: const Duration(hours: 2))],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {'W': Duration(hours: 1)},
          ),
        },
        orders: [
          for (var i = 0; i < 3; i++)
            SimOrder(
              id: 'o$i',
              sequence: i,
              partId: 'p1',
              needDate: aug1.add(const Duration(days: 2)),
            ),
        ],
        workcenters: {'W': workcenter('W')},
        release: const Duration(hours: 4),
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      // An hour of work each, four hours apart, so nothing ever waits.
      expect(metrics.averageLeadTime, const Duration(hours: 1));
      // Three hours of standard: two of stock on the wall clock, one of work.
      expect(metrics.theoreticalLeadTime, const Duration(hours: 3));
      expect(metrics.settledOrders, 2);
      expect(metrics.leadTimeEfficiency, closeTo(3.0, 0.0001));
    });
  });

  group('per part (§8)', () {
    test('each part number is averaged on its own', () {
      final setup = scenario(
        nodes: [step(0, 'W')],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {'W': Duration(hours: 1)},
          ),
          'p2': SimPart(
            id: 'p2',
            partNumber: 'PN2',
            processTimes: const {'W': Duration(hours: 3)},
          ),
        },
        orders: [
          SimOrder(
            id: 'o0',
            sequence: 0,
            partId: 'p1',
            needDate: aug1.add(const Duration(days: 2)),
          ),
          SimOrder(
            id: 'o1',
            sequence: 1,
            partId: 'p2',
            needDate: aug1.add(const Duration(days: 2)),
          ),
        ],
        workcenters: {'W': workcenter('W')},
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      expect(metrics.parts.map((p) => p.partNumber), ['PN1', 'PN2']);
      expect(metrics.parts.first.averageLeadTime, const Duration(hours: 1));
      expect(metrics.parts.last.averageLeadTime, const Duration(hours: 3));
      expect(metrics.parts.every((p) => p.orders == 1), isTrue);
    });
  });

  group('the bottleneck rankings (§8.1)', () {
    test('the headline names the station orders wait at longest', () {
      // W is slow and orders pile up behind it; X is quick and never queues.
      final setup = scenario(
        nodes: [step(0, 'W'), step(1, 'X')],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {
              'W': Duration(hours: 5),
              'X': Duration(minutes: 10),
            },
          ),
        },
        orders: [
          for (var i = 0; i < 4; i++)
            SimOrder(
              id: 'o$i',
              sequence: i,
              partId: 'p1',
              needDate: aug1.add(const Duration(days: 3)),
            ),
        ],
        workcenters: {'W': workcenter('W'), 'X': workcenter('X')},
        release: const Duration(hours: 1),
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      expect(metrics.bottleneck!.name, 'W');
      expect(metrics.bottleneck!.queueTime, greaterThan(Duration.zero));
      expect(
        metrics.workcenters.firstWhere((w) => w.name == 'X').queueTime,
        Duration.zero,
      );

      // The second ranking agrees here, but is computed separately because
      // §8.1 wants the disagreement visible when it happens.
      expect(metrics.byContribution.first.name, 'W');
      expect(metrics.shareOfFlow(metrics.bottleneck!), greaterThan(0.9));
    });

    test('visits and changeovers are counted per station', () {
      final setup = scenario(
        nodes: [step(0, 'W', changeover: const Duration(minutes: 30))],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {'W': Duration(hours: 1)},
          ),
          'p2': SimPart(
            id: 'p2',
            partNumber: 'PN2',
            processTimes: const {'W': Duration(hours: 1)},
          ),
        },
        orders: [
          for (var i = 0; i < 4; i++)
            SimOrder(
              id: 'o$i',
              sequence: i,
              partId: i.isEven ? 'p1' : 'p2',
              needDate: aug1.add(const Duration(days: 3)),
            ),
        ],
        workcenters: {'W': workcenter('W')},
        release: const Duration(hours: 2),
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      final w = metrics.workcenters.single;
      expect(w.visits, 4);
      // Alternating parts: every order pays a setup, including the first —
      // cold start is a change, because an empty station is set up for nothing
      // (§7.6).
      expect(w.changeovers, 4);
      expect(w.utilization, isNotNull);
    });

    test('a run that touched nothing has no bottleneck to name', () {
      final setup = scenario(
        nodes: [step(0, 'W')],
        parts: const {},
        orders: const [],
        workcenters: {'W': workcenter('W')},
      );

      final metrics = computeRunMetrics(
        result: runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ),
        studies: setup.studies,
        workcenters: setup.workcenters,
      );

      expect(metrics.bottleneck, isNull);
      expect(metrics.orders, 0);
      expect(metrics.onTimeDelivery, 0);
      expect(metrics.leadTimeEfficiency, isNull);
    });
  });

  test('empty slots are carried through to the report (§7.2)', () {
    final setup = scenario(
      nodes: [step(0, 'W')],
      parts: {
        'p1': SimPart(
          id: 'p1',
          partNumber: 'PN1',
          processTimes: const {'W': Duration(hours: 1)},
        ),
      },
      orders: [
        SimOrder(
          id: 'o0',
          sequence: 0,
          partId: 'p1',
          needDate: aug1.add(const Duration(days: 2)),
          materialDate: aug1.add(const Duration(hours: 25)),
        ),
      ],
      workcenters: {'W': workcenter('W')},
    );

    final metrics = computeRunMetrics(
      result: runSimulation(
        studies: setup.studies,
        workcenters: setup.workcenters,
        start: aug1,
      ),
      studies: setup.studies,
      workcenters: setup.workcenters,
    );

    // Slots at 0, 10 and 20 all go out before the material lands at 25.
    expect(metrics.emptySlots, 3);
  });

  group('two studies sharing a part number (§8.1.2)', () {
    // A part number is unique inside a study, not inside a project (§16.15),
    // so a run spanning two lines can carry two genuinely different parts
    // called `PN2`. Built through `summariseRun` rather than a run, because
    // what is under test is how the report keeps them apart.
    SimRunResult twoLines() => SimRunResult(
      start: aug1,
      end: aug1.add(const Duration(days: 10)),
      guard: aug1.add(const Duration(days: 50)),
      steps: const [],
      orders: [
        SimOrderOutcome(
          studyId: 'study-b',
          orderId: 'o-b',
          sequence: 0,
          partId: 'part-b',
          needDate: aug1.add(const Duration(days: 9)),
          released: aug1,
          delivered: aug1.add(const Duration(days: 8)),
        ),
        SimOrderOutcome(
          studyId: 'study-a',
          orderId: 'o-a',
          sequence: 0,
          partId: 'part-a',
          needDate: aug1.add(const Duration(days: 5)),
          released: aug1,
          delivered: aug1.add(const Duration(days: 2)),
        ),
      ],
      emptySlots: const [],
      busyByWorkcenter: const {},
      openByWorkcenter: const {},
    );

    RunMetrics report() => summariseRun(
      result: twoLines(),
      partNumbers: const {'part-a': 'PN2', 'part-b': 'PN2'},
      workcenterNames: const {},
      theoreticalByOrder: const {},
    );

    test('stay two rows, each naming its own study', () {
      final parts = report().parts;

      expect(parts.length, 2);
      expect(parts.map((p) => p.partNumber), ['PN2', 'PN2']);
      // The only thing on the row that tells them apart.
      expect(parts.map((p) => p.studyId), ['study-a', 'study-b']);
      // And they are not merged: each carries its own order.
      expect(parts.map((p) => p.orders), [1, 1]);
    });

    test('are not averaged together', () {
      final parts = report().parts;

      // Two days for study-a's part, eight for study-b's. Merged, both would
      // read five, which is a figure neither part ever had.
      expect(parts.first.averageLeadTime, const Duration(days: 2));
      expect(parts.last.averageLeadTime, const Duration(days: 8));
    });

    test('sort the same way twice, on the study id', () {
      // The orders arrive study-b first, so an unbroken tie would leave the
      // pair in whatever order the map yielded — a list that reorders itself
      // between two reads of one run.
      expect(report().parts.map((p) => p.studyId), ['study-a', 'study-b']);
      expect(report().parts.map((p) => p.studyId), ['study-a', 'study-b']);
    });
  });

  group('a crew is the throughput at a labour-paced station (v30)', () {
    /// The same one-hour order at one station, run at [crew] and with the
    /// station paced one way or the other.
    Duration ran({required int crew, required bool labourPaced}) {
      final setup = scenario(
        nodes: [step(0, 'W')],
        parts: {
          'p1': SimPart(
            id: 'p1',
            partNumber: 'PN1',
            processTimes: const {'W': Duration(hours: 6)},
          ),
        },
        orders: [
          SimOrder(
            id: 'o1',
            sequence: 0,
            partId: 'p1',
            needDate: DateTime(2026, 12),
          ),
        ],
        workcenters: {
          'W': workcenter(
            'W',
            operatorsPerShift: [crew],
            labourPaced: labourPaced,
          ),
        },
      );
      final result = runSimulation(
        studies: setup.studies,
        workcenters: setup.workcenters,
        start: aug1,
      );
      final step0 = result.steps.single;
      return step0.processEnd.difference(step0.processStart);
    }

    test('three operators finish one operator’s work three times sooner', () {
      // The whole of phase 10: a process time is one operator's labour content.
      expect(ran(crew: 1, labourPaced: true), const Duration(hours: 6));
      expect(ran(crew: 3, labourPaced: true), const Duration(hours: 2));
    });

    test('a machine-paced station is unmoved by its crew', () {
      // The CNC case, still true and still the default: the operators open the
      // shift and nothing else. This is what the field reported as a bug, and
      // it is correct here.
      expect(ran(crew: 1, labourPaced: false), const Duration(hours: 6));
      expect(ran(crew: 3, labourPaced: false), const Duration(hours: 6));
    });

    test('capacity rises where the crew does, and demand does not fall', () {
      // **What the field asked for, and the correction to how it was first
      // built.** A crew does not shrink the work; it enlarges the room. The
      // step still stores the labour content - six hours of one person's work
      // is six hours of it whoever does it - while the station's capacity is
      // counted in operator-hours.
      ({Duration labour, Duration capacity, Duration held}) run({
        required int crew,
        required bool labourPaced,
      }) {
        final setup = scenario(
          nodes: [step(0, 'W')],
          parts: {
            'p1': SimPart(
              id: 'p1',
              partNumber: 'PN1',
              processTimes: const {'W': Duration(hours: 6)},
            ),
          },
          orders: [
            SimOrder(
              id: 'o1',
              sequence: 0,
              partId: 'p1',
              needDate: DateTime(2026, 12),
            ),
          ],
          workcenters: {
            'W': workcenter(
              'W',
              operatorsPerShift: [crew],
              labourPaced: labourPaced,
            ),
          },
        );
        final result = runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        );
        final only = result.steps.single;
        return (
          labour: Duration(seconds: only.processSeconds!),
          // **The monthly rows, not the whole-run figure.** That one is
          // utilization's denominator and is bounded by the run, which a crew
          // makes *shorter* - so it cannot show the room growing. Occupation's
          // capacity spans the station's schedule (phase 9) and is what §10.3
          // draws against.
          capacity: result.openByWorkcenterMonth['W']!.values.fold(
            Duration.zero,
            (a, b) => a + b,
          ),
          held: only.processEnd.difference(only.processStart),
        );
      }

      final alone = run(crew: 1, labourPaced: true);
      final crewed = run(crew: 3, labourPaced: true);

      // The work is the same work.
      expect(crewed.labour, alone.labour);
      expect(crewed.labour, const Duration(hours: 6));
      // The room is three times the room.
      expect(crewed.capacity, alone.capacity * 3);
      // And the station is genuinely held for less of it, which is what makes
      // the dates move.
      expect(crewed.held, const Duration(hours: 2));
      expect(alone.held, const Duration(hours: 6));
    });

    test('a machine-paced station counts capacity in station hours', () {
      // The crew must not enlarge a CNC's room either.
      Duration capacityAt(int crew) {
        final setup = scenario(
          nodes: [step(0, 'W')],
          parts: {
            'p1': SimPart(
              id: 'p1',
              partNumber: 'PN1',
              processTimes: const {'W': Duration(hours: 6)},
            ),
          },
          orders: [
            SimOrder(
              id: 'o1',
              sequence: 0,
              partId: 'p1',
              needDate: DateTime(2026, 12),
            ),
          ],
          workcenters: {
            'W': workcenter('W', operatorsPerShift: [crew]),
          },
        );
        return runSimulation(
          studies: setup.studies,
          workcenters: setup.workcenters,
          start: aug1,
        ).openByWorkcenterMonth['W']!.values.fold(
          Duration.zero,
          (a, b) => a + b,
        );
      }

      expect(capacityAt(3), capacityAt(1));
    });

    test('the default pacing leaves every existing run identical', () {
      // v30 must be a no-op on a plant nobody has repaced, whatever its crews.
      for (final crew in const [1, 2, 5]) {
        expect(
          ran(crew: crew, labourPaced: false),
          const Duration(hours: 6),
          reason: 'crew of $crew',
        );
      }
    });
  });
}
