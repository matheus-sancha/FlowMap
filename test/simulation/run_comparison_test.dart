import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/simulation/application/run_comparison.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The comparison is arithmetic over two stored runs, so it can be asserted
/// without a screen — which matters, because the screen it feeds cannot.
void main() {
  SimulationRunStudy study({
    required String name,
    int releaseSeconds = 86400,
    double? takt = 1,
    int? wipCap,
    int startBuffer = 0,
    String? cell = 'Célula 11',
    String? line = 'Fluxo 11B',
  }) => SimulationRunStudy(
    runId: 'r',
    studyId: name,
    name: name,
    releaseSeconds: releaseSeconds,
    taktValue: takt,
    startBufferDays: startBuffer,
    wipCap: wipCap,
    productionCellName: cell,
    productionLineName: line,
  );

  StoredRun run({
    required int delivered,
    required int onTime,
    int emptySlots = 0,
    Duration? float,
    Duration? leadTime,
    String? appVersion,
    List<SimulationRunStudy>? studies,
  }) => StoredRun(
    id: 'run',
    projectId: 'doc',
    createdAt: DateTime(2026, 9, 13),
    appVersion: appVersion,
    queues: const RunQueues([]),
    studies: studies ?? [study(name: 'Célula 11B')],
    // The comparison reads only `metrics` and `studies`; the result is here
    // because a StoredRun cannot exist without one.
    result: SimRunResult(
      start: DateTime(2026),
      end: DateTime(2026),
      guard: DateTime(2026),
      steps: const [],
      orders: const [],
      emptySlots: const [],
      busyByWorkcenter: const {},
      openByWorkcenter: const {},
    ),
    metrics: RunMetrics(
      orders: delivered,
      delivered: delivered,
      onTime: onTime,
      emptySlots: emptySlots,
      averageFloat: float,
      averageLeadTime: leadTime,
      theoreticalLeadTime: null,
      parts: const [],
      workcenters: const [],
    ),
    plan: const [],
  );

  test('the verdict is on-time delivery', () async {
    final before = run(delivered: 100, onTime: 88);
    final after = run(delivered: 100, onTime: 92);

    final comparison = RunComparison.of(before, after);

    expect(comparison.verdict!.before, 88);
    expect(comparison.verdict!.after, 92);
    expect(comparison.verdict!.delta, closeTo(4, 0.001));
    expect(comparison.verdict!.isBetter, isTrue);
  });

  test('better is not the same as larger', () async {
    // Lead time falling is an improvement; OTD falling is not. A table that
    // painted every increase green would call a longer lead time a win.
    final a = run(
      delivered: 10,
      onTime: 10,
      leadTime: const Duration(days: 14),
    );
    final b = run(
      delivered: 10,
      onTime: 10,
      leadTime: const Duration(days: 12),
    );

    final lead = RunComparison.of(a, b).deltas
        .firstWhere((d) => d.metric == ComparedMetric.leadTime);
    expect(lead.delta, lessThan(0));
    expect(lead.isBetter, isTrue);
  });

  test('float counts positive as early', () async {
    // §10.4: float is slack against the need date, so -3 days moving to -1 is
    // an improvement even though both are late.
    final a = run(delivered: 5, onTime: 1, float: const Duration(days: -3));
    final b = run(delivered: 5, onTime: 1, float: const Duration(days: -1));

    final float = RunComparison.of(a, b).deltas
        .firstWhere((d) => d.metric == ComparedMetric.float);
    expect(float.isBetter, isTrue);
  });

  test('a run that delivered nothing is not an improvement', () async {
    // The failure mode a naive delta has: 0 of 0 on time reads as 100 %.
    final a = run(delivered: 100, onTime: 90);
    final b = run(delivered: 0, onTime: 0);

    final comparison = RunComparison.of(a, b);
    expect(comparison.verdict!.after, isNull);
    expect(comparison.verdict!.delta, isNull);
    expect(comparison.verdict!.isBetter, isNull);
  });

  test('the inputs that differed are named, and only those', () async {
    final a = run(
      delivered: 1,
      onTime: 1,
      studies: [study(name: 'Célula 11B', releaseSeconds: 86400, wipCap: 40)],
    );
    final b = run(
      delivered: 1,
      onTime: 1,
      studies: [study(name: 'Célula 11B', releaseSeconds: 43200, wipCap: 40)],
    );

    final differences = RunComparison.of(a, b).differences;
    expect(differences, hasLength(1));
    expect(differences.single.field, InputField.releaseSeconds);
    expect(differences.single.study, 'Célula 11B');
    expect(differences.single.before, '86400');
    expect(differences.single.after, '43200');
  });

  test('identical runs differ in nothing', () async {
    final a = run(delivered: 10, onTime: 9);
    expect(RunComparison.of(a, a).differences, isEmpty);
    expect(RunComparison.of(a, a).warnings, isEmpty);
  });

  test('a study present in one run only is itself a difference', () async {
    final a = run(
      delivered: 1,
      onTime: 1,
      studies: [study(name: 'Célula 11B'), study(name: 'Célula 11D')],
    );
    final b = run(delivered: 1, onTime: 1, studies: [study(name: 'Célula 11B')]);

    final differences = RunComparison.of(a, b).differences;
    expect(differences, hasLength(1));
    expect(differences.single.study, 'Célula 11D');
    expect(differences.single.field, InputField.presence);
  });

  group('warnings', () {
    test('two equally unknown runs compare without one', () {
      // What makes the 165 already stored usable with each other (#24).
      final a = run(delivered: 10, onTime: 9);
      final b = run(delivered: 10, onTime: 8);
      expect(RunComparison.of(a, b).warnings, isEmpty);
    });

    test('a stamped run against an unstamped one warns', () {
      final a = run(delivered: 10, onTime: 9, appVersion: '0.1.0-a');
      final b = run(delivered: 10, onTime: 8);
      expect(
        RunComparison.of(a, b).warnings,
        contains(ComparisonWarning.differentBuilds),
      );
    });

    test('two different builds warn', () {
      // #19 changed what a run *means* with no migration, so the build is the
      // only thing that separates two runs at the same schema version.
      final a = run(delivered: 10, onTime: 9, appVersion: '0.1.0-a');
      final b = run(delivered: 10, onTime: 8, appVersion: '0.1.0-b');
      expect(
        RunComparison.of(a, b).warnings,
        contains(ComparisonWarning.differentBuilds),
      );
    });

    test('different lines warn rather than refuse', () {
      // #26 made this a gate; the run history demoted it — across 165 runs the
      // gate matched zero pairs. It is a caution, and the reader's call.
      final a = run(
        delivered: 10,
        onTime: 9,
        studies: [study(name: 'A', line: 'Fluxo 11B')],
      );
      final b = run(
        delivered: 10,
        onTime: 9,
        studies: [study(name: 'B', line: 'Fluxo 11D')],
      );

      final comparison = RunComparison.of(a, b);
      expect(comparison.warnings, contains(ComparisonWarning.differentScope));
      // Warned, not refused: the deltas are still there to read.
      expect(comparison.deltas, isNotEmpty);
    });

    test('the same scope does not warn', () {
      final a = run(delivered: 10, onTime: 9);
      final b = run(delivered: 10, onTime: 8);
      expect(
        RunComparison.of(a, b).warnings,
        isNot(contains(ComparisonWarning.differentScope)),
      );
    });
  });
}
