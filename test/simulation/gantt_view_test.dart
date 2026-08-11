import 'package:flowmap/src/common/part_palette.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/simulation/application/gantt_layout.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flowmap/src/features/simulation/presentation/gantt_view.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The zoom cluster. `find.byTooltip` reaches the `Tooltip` an `IconButton`
/// wraps its icon in rather than the button, and it is the button that carries
/// the enabled state under test.
final _zoomIn = find.widgetWithIcon(IconButton, Icons.zoom_in);
final _zoomOut = find.widgetWithIcon(IconButton, Icons.zoom_out);

/// The Gantt as it mounts (DESIGN.md §8.6).
///
/// The geometry is asserted in `gantt_layout_test` without a frame; what is left
/// for a frame is the wiring — that the labels, the legend and the hover card
/// say what the layout resolved, that the zoom cluster is dead at the floor, and
/// that the floor note is a fact about the current zoom rather than a permanent
/// disclaimer. What none of this reaches is the painter, which is why §3 drives
/// it by hand.
void main() {
  final jan1 = DateTime(2026);
  DateTime at(int hours) => jan1.add(Duration(hours: hours));

  SimOrderStep stepOf({
    required String orderId,
    required String workcenterId,
    required DateTime processStart,
    required DateTime processEnd,
    DateTime? queueStart,
    bool changeover = false,
    String studyId = 'study-1',
  }) => SimOrderStep(
    studyId: studyId,
    orderId: orderId,
    nodeId: 'node-$workcenterId',
    workcenterId: workcenterId,
    queueStart: queueStart ?? processStart,
    processStart: processStart,
    processEnd: processEnd,
    changeoverIncurred: changeover,
  );

  SimOrderOutcome orderOf({
    required String orderId,
    required int sequence,
    required String partId,
    String studyId = 'study-1',
  }) => SimOrderOutcome(
    studyId: studyId,
    orderId: orderId,
    sequence: sequence,
    partId: partId,
    needDate: at(72),
    released: jan1,
    delivered: at(48),
  );

  StoredRun runOf({
    required List<SimOrderStep> steps,
    required List<SimOrderOutcome> orders,
    Map<String, String> partNumbers = const {'p1': 'PN1', 'p2': 'PN2'},
    List<SimulationRunStudy> studies = const [],
    // The view rebuilds its chart when the id changes and not otherwise, which
    // is right for an app where a run is written once and never edited — so a
    // test pumping a second run into the same tree has to give it its own id or
    // it is asserting against the first one's chart.
    String id = 'run-1',
  }) {
    final result = SimRunResult(
      start: jan1,
      end: at(48),
      guard: at(480),
      steps: steps,
      orders: orders,
      emptySlots: const [],
      busyByWorkcenter: const {},
      openByWorkcenter: const {},
    );

    return StoredRun(
      id: id,
      projectId: 'project-1',
      createdAt: jan1,
      dispatch: DispatchRule.fifo,
      dispatchOverrides: const [],
      studies: studies,
      result: result,
      plan: const [],
      metrics: summariseRun(
        result: result,
        partNumbers: partNumbers,
        workcenterNames: const {'W1': 'CLAD04', 'W2': 'CEU27'},
        theoreticalByOrder: const {},
      ),
    );
  }

  /// Two orders through a two-station routing, CLAD04 then CEU27, plus a
  /// twenty-second step that is under the floor at whole-run scale and over it
  /// near the ceiling.
  ///
  /// **The queue is all at the second station**, so the Queue table ranks CEU27
  /// first and the chart has to put CLAD04 there anyway — which is what makes
  /// the row order a real assertion rather than one alphabetical order would
  /// satisfy by accident. The tests below still reach for a row by name, so
  /// only the one test about the order depends on it.
  StoredRun twoDayRun() => runOf(
    orders: [
      orderOf(orderId: 'o1', sequence: 0, partId: 'p1'),
      orderOf(orderId: 'o2', sequence: 1, partId: 'p2'),
      orderOf(orderId: 'o3', sequence: 2, partId: 'p1'),
    ],
    steps: [
      stepOf(
        orderId: 'o1',
        workcenterId: 'W1',
        queueStart: jan1,
        processStart: jan1,
        processEnd: at(10),
      ),
      // Reached CEU27 at 10:00 and waited two hours for it.
      stepOf(
        orderId: 'o1',
        workcenterId: 'W2',
        queueStart: at(10),
        processStart: at(12),
        processEnd: at(22),
      ),
      stepOf(
        orderId: 'o2',
        workcenterId: 'W1',
        queueStart: at(10),
        processStart: at(10),
        processEnd: at(20),
      ),
      stepOf(
        orderId: 'o2',
        workcenterId: 'W2',
        queueStart: at(20),
        processStart: at(22),
        processEnd: at(32),
        changeover: true,
      ),
      stepOf(
        orderId: 'o3',
        workcenterId: 'W1',
        processStart: at(40),
        processEnd: at(40).add(const Duration(seconds: 20)),
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, StoredRun run) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: GanttView(run: run)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Where the pointer has to be to sit on [bar]'s row, in global coordinates.
  ///
  /// Built from the same `layoutGantt` the view drew with, which is the point of
  /// having the geometry outside the widget: a test can ask where a bar is
  /// without reading pixels back off a canvas.
  Offset onBar(WidgetTester tester, GanttPlacedBar bar) {
    final origin = tester.getTopLeft(find.byKey(ganttCanvasKey));
    final rowIndex =
        ((bar.rect.top - GanttMetrics.axisHeight) / GanttMetrics.rowHeight)
            .floor();
    return origin +
        Offset(
          bar.rect.left + 2,
          GanttMetrics.axisHeight +
              rowIndex * GanttMetrics.rowHeight +
              GanttMetrics.rowHeight / 2,
        );
  }

  GanttRowLayout rowNamed(GanttLayout layout, String name) =>
      layout.rows.firstWhere((row) => row.row.name == name);

  /// A mouse parked at [at], for the scroll signals the zoom listens to.
  TestPointer testPointer(Offset at) =>
      TestPointer(1, PointerDeviceKind.mouse)..hover(at);

  /// The layout the view is showing, recomputed here from the pane the test
  /// window gives it.
  GanttLayout shownLayout(WidgetTester tester, StoredRun run) {
    final chart = buildGanttChart(result: run.result, metrics: run.metrics);
    final pane = tester.getSize(find.byType(GanttView)).width - 168;
    return layoutGantt(
      chart: chart,
      pixelsPerSecond: ganttScaleBounds(span: chart.span, paneWidth: pane).min,
    );
  }

  testWidgets('one row per station, named as the run named them', (
    tester,
  ) async {
    await pump(tester, twoDayRun());

    // The names the stations had when the run was made (§7.10).
    expect(find.text('CLAD04'), findsOne);
    expect(find.text('CEU27'), findsOne);

    // Down the page in the order the work flows, so an order is read
    // diagonally down the chart the way it is read left to right along the map.
    // CEU27 holds all the queue in this run and would be first under the Queue
    // table's ranking, which is what the rows followed until the chart was
    // driven against a real plant.
    expect(
      tester.getTopLeft(find.text('CLAD04')).dy,
      lessThan(tester.getTopLeft(find.text('CEU27')).dy),
    );
  });

  testWidgets('a run with no steps says so rather than drawing nothing', (
    tester,
  ) async {
    await pump(tester, runOf(steps: const [], orders: const []));

    expect(
      find.text('This run recorded no steps, so there is nothing to draw.'),
      findsOne,
    );
  });

  testWidgets('the legend carries every part, in the palette order', (
    tester,
  ) async {
    await pump(tester, twoDayRun());

    expect(find.text('PN1'), findsOne);
    expect(find.text('PN2'), findsOne);

    // The strip is the legend for a view with no table (§8.6), and it takes its
    // colours from the same list the Parts table's swatches do — so the two
    // cannot come apart.
    final swatches = tester
        .widgetList<Container>(
          find.descendant(
            of: find.ancestor(of: find.text('PN1'), matching: find.byType(Row)),
            matching: find.byType(Container),
          ),
        )
        .toList();
    expect(
      (swatches.first.decoration! as BoxDecoration).color,
      partPalette.first.fill,
    );
  });

  testWidgets('the legend names the study only when there are two', (
    tester,
  ) async {
    final one = twoDayRun();
    await pump(tester, one);
    expect(find.textContaining('·'), findsNothing);

    // Two lines can legitimately carry two different parts of the same number
    // (§16.15), so on a two-study run the legend has to say which is which —
    // the Parts table's rule for its Study column, applied to the strip.
    await pump(
      tester,
      runOf(
        id: 'run-2',
        studies: [
          SimulationRunStudy(
            runId: 'run-1',
            studyId: 'study-1',
            name: 'Célula 11B',
            releaseSeconds: 3600,
            priority: 0,
            startBufferDays: 0,
          ),
          SimulationRunStudy(
            runId: 'run-1',
            studyId: 'study-2',
            name: 'Célula 12A',
            releaseSeconds: 3600,
            priority: 0,
            startBufferDays: 0,
          ),
        ],
        partNumbers: const {'p1': 'PN2', 'p2': 'PN2'},
        orders: [
          orderOf(orderId: 'o1', sequence: 0, partId: 'p1'),
          orderOf(orderId: 'o2', sequence: 0, partId: 'p2', studyId: 'study-2'),
        ],
        steps: [
          stepOf(
            orderId: 'o1',
            workcenterId: 'W1',
            processStart: jan1,
            processEnd: at(24),
          ),
          stepOf(
            orderId: 'o2',
            workcenterId: 'W1',
            processStart: at(24),
            processEnd: at(48),
            studyId: 'study-2',
          ),
        ],
      ),
    );

    expect(find.text('PN2 · Célula 11B'), findsOne);
    expect(find.text('PN2 · Célula 12A'), findsOne);
  });

  testWidgets('hovering a bar names the order, the part and the station', (
    tester,
  ) async {
    final run = twoDayRun();
    await pump(tester, run);

    // Nothing under the pointer, nothing said.
    expect(find.textContaining('Order '), findsNothing);

    final layout = shownLayout(tester, run);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await gesture.moveTo(onBar(tester, rowNamed(layout, "CLAD04").bars.first));
    await tester.pumpAndSettle();

    expect(find.text('Order 1  ·  PN1'), findsOne);
    // Once on the frozen label and once in the card.
    expect(find.text('CLAD04'), findsExactly(2));
    expect(find.text('Committed'), findsOne);
    expect(find.text('Waited before starting'), findsOne);
  });

  testWidgets('the card says a changeover was paid, at any zoom', (
    tester,
  ) async {
    final run = twoDayRun();
    await pump(tester, run);

    final layout = shownLayout(tester, run);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    // CEU27 runs o1 and then o2, and only o2 paid a changeover — the two parts
    // are different, which is what §7.6's batching rule charges for.
    await gesture.moveTo(onBar(tester, rowNamed(layout, 'CEU27').bars.last));
    await tester.pumpAndSettle();

    expect(find.text('Order 2  ·  PN2'), findsOne);
    expect(find.text('A changeover was paid to start it'), findsOne);
  });

  testWidgets('leaving the chart takes the card with it', (tester) async {
    final run = twoDayRun();
    await pump(tester, run);

    final layout = shownLayout(tester, run);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await gesture.moveTo(onBar(tester, rowNamed(layout, "CLAD04").bars.first));
    await tester.pumpAndSettle();
    expect(find.text('Order 1  ·  PN1'), findsOne);

    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.text('Order 1  ·  PN1'), findsNothing);
  });

  testWidgets('zoom out is dead at the fit, which is the whole run', (
    tester,
  ) async {
    await pump(tester, twoDayRun());

    // Fitted once per run, and the fit *is* the floor — there is nothing past
    // it to show.
    expect(tester.widget<IconButton>(_zoomOut).onPressed, isNull);
    expect(tester.widget<IconButton>(_zoomIn).onPressed, isNotNull);

    await tester.tap(_zoomIn);
    await tester.pumpAndSettle();

    expect(tester.widget<IconButton>(_zoomOut).onPressed, isNotNull);
  });

  testWidgets('ctrl and the wheel zoom; the wheel alone does not', (
    tester,
  ) async {
    await pump(tester, twoDayRun());
    final over = tester.getCenter(find.byKey(ganttCanvasKey));

    // A plain wheel is left alone (§12.6): hijacking it would strand the
    // vertical scroll this chart sits in.
    await tester.sendEventToBinding(
      testPointer(over).scroll(const Offset(0, -80)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(_zoomOut).onPressed,
      isNull,
      reason: 'a bare wheel must leave the chart at its fit',
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    addTearDown(() => tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft));
    await tester.sendEventToBinding(
      testPointer(over).scroll(const Offset(0, -80)),
    );
    await tester.pumpAndSettle();

    // Off the floor, so there is now something to zoom back out to.
    expect(tester.widget<IconButton>(_zoomOut).onPressed, isNotNull);
  });

  testWidgets('the floor note appears while it is true, and then goes', (
    tester,
  ) async {
    await pump(tester, twoDayRun());

    // The twenty-second step is a fraction of a pixel across two days, so it is
    // drawn at the minimum width and the view says so.
    expect(find.text('1 bar drawn wider than it is'), findsOne);

    // Zooming in makes it real. A permanent warning would be a lie here, which
    // is why the count comes out of `layoutGantt` rather than being a constant
    // line of help text.
    for (var i = 0; i < 6; i++) {
      await tester.tap(_zoomIn);
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('drawn wider'), findsNothing);
  });

  testWidgets('what a gap means is on screen, not left to be inferred', (
    tester,
  ) async {
    await pump(tester, twoDayRun());

    // Both halves said: the chart cannot tell closed from starved, and where
    // that is answered is named (§8.6).
    expect(find.textContaining('A gap is a station not running'), findsOne);
    expect(find.textContaining('Queue table'), findsOne);
  });
}
