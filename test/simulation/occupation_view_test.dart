import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/simulation/application/run_filter.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flowmap/src/features/simulation/presentation/occupation_view.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Occupation pane at the two ends of its height (#54, DESIGN.md §10.3).
///
/// **Mounted directly, at the pane's own size**, because what #52's sweep found
/// is a fact about this `Column` and the height it is handed — ~150 logical
/// pixels at 150 % in a 1280x720 window. Driving the whole app there to reach it
/// would be testing `AppScale`, which `app_scale_test.dart` already does.
void main() {
  final now = DateTime(2026, 8, 1);

  final project = Project(
    id: 'project-1',
    name: 'H2 2026',
    plantId: 'plant-1',
    shiftPatternId: 'pattern-1',
    createdAt: now,
    updatedAt: now,
    floatRedDays: 0,
    floatGreenDays: 30,
    occupationAmberPct: 85,
    occupationRedPct: 100,
  );

  /// A run carrying monthly capacity — the v25 column without which the pane
  /// says it cannot draw rather than drawing anything to overflow.
  ///
  /// **Twenty workcenters**, so the grid is taller than any pane here and there
  /// is something to scroll at both heights.
  FilteredRun slice() {
    final ids = [for (var i = 0; i < 20; i++) 'wc-$i'];
    final result = SimRunResult(
      start: DateTime(2026, 8, 3),
      end: DateTime(2026, 9, 28),
      guard: DateTime(2027),
      steps: const [],
      orders: const [],
      emptySlots: const [],
      busyByWorkcenter: {for (final id in ids) id: const Duration(hours: 60)},
      openByWorkcenter: {for (final id in ids) id: const Duration(hours: 200)},
      openByWorkcenterMonth: {
        for (final id in ids)
          id: {
            DateTime(2026, 8): const Duration(hours: 100),
            DateTime(2026, 9): const Duration(hours: 100),
          },
      },
    );
    final run = StoredRun(
      id: 'run-1',
      projectId: project.id,
      createdAt: now,
      queues: const RunQueues([]),
      studies: const [],
      result: result,
      plan: const [],
      metrics: summariseRun(
        result: result,
        partNumbers: const {},
        workcenterNames: const {},
        theoreticalByOrder: const {},
      ),
    );
    return filterRun(run, const RunFilter());
  }

  Future<void> mount(WidgetTester tester, Size pane) async {
    // The width #52 measured at 150 % — narrow enough that the controls'
    // `Wrap` takes a second run, which is what made the header 197 — and at
    // least that window's height, so a taller pane is not clipped by the view.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(853, pane.height < 480 ? 480 : pane.height);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: pane,
              child: OccupationView(slice: slice(), project: project),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dy;

  final grouping = find.text('Per Workcenter');

  testWidgets('a pane too short for its header scrolls as one, and fits', (
    tester,
  ) async {
    // #52's check 12: `BOTTOM OVERFLOWED BY 47 PIXELS`. A debug overflow is a
    // reported exception, so reaching the expectations is the first assertion.
    await mount(tester, const Size(700, 150));
    expect(tester.takeException(), isNull);

    // **Reachable, not pinned.** The controls scroll away with the grid here —
    // but they are still directly above it, which is the adjacency #16 argued
    // for, and a drag brings the grid under them.
    expect(grouping, findsOne);
    final before = top(tester, grouping);
    await tester.drag(find.byType(OccupationView), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(
      top(tester, grouping),
      lessThan(before),
      reason: 'below the threshold the controls scroll with the grid',
    );
  });

  testWidgets('a pane with room pins the controls, as it always has', (
    tester,
  ) async {
    await mount(tester, const Size(700, 700));
    expect(tester.takeException(), isNull);

    final before = top(tester, grouping);
    await tester.drag(find.text('wc-0').first, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(
      top(tester, grouping),
      before,
      reason: 'anywhere that fits today behaves exactly as it did',
    );
  });

  testWidgets('the legend sits with the chart it keys, not the controls', (
    tester,
  ) async {
    // It keys the bars' three colours and counts the workcenters they
    // aggregate — so when the chart scrolls away, so does its key.
    await mount(tester, const Size(700, 700));
    final legend = find.text('Process');
    final before = top(tester, legend);
    await tester.drag(find.text('wc-0').first, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(top(tester, legend), lessThan(before));
  });
}
