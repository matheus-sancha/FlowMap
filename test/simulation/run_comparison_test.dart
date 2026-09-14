import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/simulation/application/run_comparison.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The comparison is arithmetic over two studies' sides of their latest runs,
/// so it can be asserted without a screen — which matters, because the screen
/// it feeds cannot.
void main() {
  final now = DateTime(2026, 9, 13);

  SimulationRunStudy snapshot({
    String id = 's',
    String name = 'Célula 11B',
    int releaseSeconds = 86400,
    double? takt = 1,
    String? taktUnit = 'days',
    int? wipCap,
    int startBuffer = 0,
  }) => SimulationRunStudy(
    runId: 'r',
    studyId: id,
    name: name,
    releaseSeconds: releaseSeconds,
    taktValue: takt,
    taktUnit: taktUnit,
    startBufferDays: startBuffer,
    wipCap: wipCap,
    productionCellName: 'Célula 11',
    productionLineName: 'Fluxo 11B',
  );

  ComparedSide side({
    required int delivered,
    required int onTime,
    int? orders,
    int emptySlots = 0,
    Duration? float,
    Duration? leadTime,
    String? appVersion,
    SimulationRunStudy? study,
    RunQueues queues = const RunQueues([]),
  }) => ComparedSide(
    study: study ?? snapshot(),
    queues: queues,
    appVersion: appVersion,
    runAt: now,
    metrics: RunMetrics(
      orders: orders ?? delivered,
      delivered: delivered,
      onTime: onTime,
      emptySlots: emptySlots,
      averageFloat: float,
      averageLeadTime: leadTime,
      theoreticalLeadTime: null,
      parts: const [],
      workcenters: const [],
    ),
  );

  test('the verdict is on-time delivery', () {
    final comparison = RunComparison.between(
      side(delivered: 100, onTime: 88),
      side(delivered: 100, onTime: 92),
    );
    expect(comparison.verdict!.before, 88);
    expect(comparison.verdict!.after, 92);
    expect(comparison.verdict!.delta, closeTo(4, 0.001));
    expect(comparison.verdict!.isBetter, isTrue);
  });

  test("the verdict is the headline's on-time delivery, over every order", () {
    // §8 counts an order that never came out as not on time.
    final verdict = RunComparison.between(
      side(orders: 10, delivered: 5, onTime: 5),
      side(orders: 10, delivered: 10, onTime: 10),
    ).verdict!;
    expect(verdict.before, 50);
    expect(verdict.after, 100);
  });

  test('better is not the same as larger', () {
    // Lead time falling is an improvement; OTD falling is not.
    final lead = RunComparison.between(
      side(delivered: 10, onTime: 10, leadTime: const Duration(days: 14)),
      side(delivered: 10, onTime: 10, leadTime: const Duration(days: 12)),
    ).deltas.firstWhere((d) => d.metric == ComparedMetric.leadTime);
    expect(lead.delta, lessThan(0));
    expect(lead.isBetter, isTrue);
  });

  test('float counts positive as early', () {
    final float = RunComparison.between(
      side(delivered: 5, onTime: 1, float: const Duration(days: -3)),
      side(delivered: 5, onTime: 1, float: const Duration(days: -1)),
    ).deltas.firstWhere((d) => d.metric == ComparedMetric.float);
    expect(float.isBetter, isTrue);
  });

  test('a side with no orders is not an improvement', () {
    final verdict = RunComparison.between(
      side(delivered: 100, onTime: 90),
      side(delivered: 0, onTime: 0),
    ).verdict!;
    expect(verdict.after, isNull);
    expect(verdict.isBetter, isNull);
  });

  test('two studies differ in what they were given, not in their names', () {
    // Different studies with different names. Matched by name, as the run
    // comparison did, each would read as missing from the other.
    final differences = RunComparison.between(
      side(
        delivered: 1,
        onTime: 1,
        study: snapshot(id: 'a', name: 'Célula 11B', startBuffer: 30),
      ),
      side(
        delivered: 1,
        onTime: 1,
        study: snapshot(id: 'b', name: 'Célula 11B (copy)', startBuffer: 0),
      ),
    ).differences;
    expect(differences, hasLength(1));
    expect(differences.single.field, InputField.startBuffer);
    expect(differences.single.before, '30');
    expect(differences.single.after, '0');
  });

  test('the release interval is not a difference of its own', () {
    // Derived from the takt and the pace setter's calendar, so it only ever
    // repeated the takt row less readably (drive, 2026-09-13).
    expect(
      RunComparison.between(
        side(delivered: 1, onTime: 1, study: snapshot(releaseSeconds: 86400)),
        side(delivered: 1, onTime: 1, study: snapshot(releaseSeconds: 43200)),
      ).differences,
      isEmpty,
    );
  });

  test(
    'occupation lists the total first, then every type either side used',
    () {
      final a = ComparedSide(
        study: SimulationRunStudy(
          runId: 'r',
          studyId: 'a',
          name: 'a',
          releaseSeconds: 1,
          startBufferDays: 0,
        ),
        metrics: RunMetrics(
          orders: 0,
          delivered: 0,
          onTime: 0,
          emptySlots: 0,
          averageFloat: null,
          averageLeadTime: null,
          theoreticalLeadTime: null,
          parts: [],
          workcenters: [],
        ),
        queues: const RunQueues([]),
        appVersion: null,
        runAt: DateTime(2026),
        occupationTotal: 0.8,
        occupationByType: {'Milling': 0.9, 'Cladding': 1.2},
      );
      final b = ComparedSide(
        study: a.study,
        metrics: a.metrics,
        queues: a.queues,
        appVersion: null,
        runAt: DateTime(2026),
        occupationTotal: 0.7,
        occupationByType: const {'Cladding': 1.0, 'Coating': 0.5},
      );

      final rows = RunComparison.between(a, b).occupation;
      expect(rows.map((r) => r.type), [null, 'Cladding', 'Coating', 'Milling']);
      expect(rows.first.delta, closeTo(-0.1, 1e-9));
      expect(
        rows[2].before,
        isNull,
        reason: 'only the second side used Coating',
      );
    },
  );

  test('a takt is its value and its unit', () {
    final differences = RunComparison.between(
      side(delivered: 1, onTime: 1, study: snapshot(takt: 4, taktUnit: 'days')),
      side(
        delivered: 1,
        onTime: 1,
        study: snapshot(takt: 4, taktUnit: 'hours'),
      ),
    ).differences;
    expect(differences.single.field, InputField.takt);
  });

  test('a workcenter dispatching differently is a difference', () {
    final difference = RunComparison.between(
      side(
        delivered: 1,
        onTime: 1,
        queues: const RunQueues([(name: 'CLAD04', rule: DispatchRule.fifo)]),
      ),
      side(
        delivered: 1,
        onTime: 1,
        queues: const RunQueues([
          (name: 'CLAD04', rule: DispatchRule.earliestDueDate),
        ]),
      ),
    ).differences.single;
    expect(difference.field, InputField.dispatch);
    expect(difference.workcenter, 'CLAD04');
  });

  group('warnings', () {
    test('two equally unknown runs compare without one', () {
      expect(
        RunComparison.between(
          side(delivered: 10, onTime: 9),
          side(delivered: 10, onTime: 8),
        ).warnings,
        isEmpty,
      );
    });

    test('a stamped run against an unstamped one warns', () {
      expect(
        RunComparison.between(
          side(delivered: 10, onTime: 9, appVersion: '2.1-2026-09-13'),
          side(delivered: 10, onTime: 8),
        ).warnings,
        contains(ComparisonWarning.differentBuilds),
      );
    });
  });

  group('which lines Compare can offer', () {
    Study study(String id, {String line = 'line-b', String cell = 'cell-11'}) =>
        Study(
          id: id,
          projectId: 'doc',
          productionCellId: cell,
          productionLineId: line,
          name: id,
          includeInSimulation: false,
          startBufferDays: 0,
          createdAt: now,
          updatedAt: now,
        );

    RunListing run(String id, DateTime at, List<String> studyIds) => (
      run: SimulationRun(
        id: id,
        documentId: 'doc',
        dispatch: 'fifo',
        runStart: at,
        runEnd: at,
        guard: at,
        createdAt: at,
      ),
      queues: const RunQueues([]),
      studies: [
        for (final s in studyIds)
          (id: s, name: s, cellName: 'Célula 11', lineName: 'Fluxo 11B'),
      ],
    );

    test('the live plant, three studies on three lines, offers nothing', () {
      // What #26 found: no two studies share a line, so the screen is empty
      // and has to say how to make a pair.
      final lines = comparableLines(
        [
          study('11B', line: 'b'),
          study('11C', line: 'c'),
          study('11D', line: 'd'),
        ],
        [
          run('r1', now, ['11B', '11C', '11D']),
        ],
      );
      expect(lines, isEmpty);
    });

    test(
      'a copy on the same line, simulated, makes a pair at each latest run',
      () {
        // Runs newest first, as watchRuns lists them. At most one study per line
        // is flagged in a run, so the pair is always two runs.
        final lines = comparableLines(
          [study('11B'), study('11B copy')],
          [
            run('r3', now, ['11B copy']),
            run('r2', now.subtract(const Duration(hours: 1)), ['11B']),
            run('r1', now.subtract(const Duration(days: 1)), ['11B']),
          ],
        );
        expect(lines, hasLength(1));
        expect(lines.single.label, 'Célula 11 · Fluxo 11B');
        expect(lines.single.studies.map((s) => (s.studyId, s.runId)), [
          ('11B copy', 'r3'),
          ('11B', 'r2'),
        ]);
      },
    );

    test('a study never simulated is not offered', () {
      expect(
        comparableLines(
          [study('11B'), study('11B copy')],
          [
            run('r1', now, ['11B']),
          ],
        ),
        isEmpty,
      );
    });
  });
}
