import 'package:flowmap/src/common/part_palette.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/simulation/application/gantt_layout.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart'
    show StationPool;
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flowmap/src/features/simulation/presentation/gantt_view.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flowmap/src/features/simulation/application/run_filter.dart';
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
    List<SimLane> lanes = const [],
    // The view rebuilds its chart when the id changes and not otherwise, which
    // is right for an app where a run is written once and never edited — so a
    // test pumping a second run into the same tree has to give it its own id or
    // it is asserting against the first one's chart.
    String id = 'run-1',
    // Empty by default, which is what a chart with nothing to say beyond the
    // steps looks like — and is exactly a run stored before v12 and v13.
    List<ProductionPlanRow> plan = const [],
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
      lanes: lanes,
    );

    return StoredRun(
      id: id,
      projectId: 'project-1',
      createdAt: jan1,
      dispatch: DispatchRule.fifo,
      dispatchOverrides: const [],
      studies: studies,
      result: result,
      plan: plan,
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
        // The whole run, unfiltered — this file is about the chart, and
        // filtering is `run_filter_test.dart`'s subject.
        home: Scaffold(body: GanttView(slice: filterRun(run, const RunFilter()))),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A point on [hit], in global coordinates.
  ///
  /// Built from the same `layoutGantt` the view drew with, which is the point of
  /// having the geometry outside the widget: a test can ask where a bar is
  /// without reading pixels back off a canvas.
  ///
  /// It aims at the rect's own middle rather than at a row's. That used to be
  /// computed by dividing the band index out of the rect's top, which held only
  /// while every band was `rowHeight` tall — it would aim at the wrong row on
  /// any chart with a buffer in it now, and it has to work for a lane's slot as
  /// well as for a station's bar.
  Offset onBar(WidgetTester tester, GanttHit hit) {
    final origin = tester.getTopLeft(find.byKey(ganttCanvasKey));
    return origin + Offset(hit.rect.left + 2, hit.rect.center.dy);
  }

  GanttRowLayout rowNamed(GanttLayout layout, String name) =>
      layout.rows.firstWhere((row) => row.band.name == name);

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

  testWidgets('hovering an order waiting in a lane names it and the lane', (
    tester,
  ) async {
    // The same run, with the buffer CEU27 pulls from carried on it. Both orders
    // waited there — o1 from 10:00 and o2 from 20:00 — so the band has stays in
    // it to pick.
    final run = runOf(
      id: 'run-lane',
      orders: twoDayRun().result.orders,
      steps: [
        for (final step in twoDayRun().result.steps)
          if (step.workcenterId == 'W2')
            SimOrderStep(
              studyId: step.studyId,
              orderId: step.orderId,
              nodeId: step.nodeId,
              workcenterId: step.workcenterId,
              queueStart: step.queueStart,
              processStart: step.processStart,
              processEnd: step.processEnd,
              changeoverIncurred: step.changeoverIncurred,
              laneNodeId: 'lane-1',
            )
          else
            step,
      ],
      lanes: const [
        SimLane(
          studyId: 'study-1',
          nodeId: 'lane-1',
          position: 1,
          name: 'FIFO CEU27',
          capacity: 2,
        ),
      ],
    );
    await pump(tester, run);

    final layout = shownLayout(tester, run);
    final lane = rowNamed(layout, 'FIFO CEU27');
    expect(lane.band, isA<GanttLaneRow>());

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await gesture.moveTo(onBar(tester, lane.visits.first));
    await tester.pumpAndSettle();

    expect(find.text('Order 1  ·  PN1'), findsOne);
    // What it stood there for — the lane's own question, and the same label the
    // station below uses for the same duration.
    expect(find.text('Waited before starting'), findsOne);
    // The lane's real depth, which is not necessarily the depth it is drawn at.
    expect(find.text('Lane holds 2 orders'), findsOne);
    // A station's card would say this; a lane's must not.
    expect(find.text('Committed'), findsNothing);
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

  /// What the card says beyond the run's own steps (§7.5).
  ///
  /// Both come off the Production Plan (§8.5), which is where they were stored —
  /// `customer_project` in v12 and `part_description` in v13 — and neither is
  /// ever drawn on a bar, so the chart's geometry knows nothing about them.
  group('the project and the description on the card (§7.5)', () {
    ProductionPlanRow planRow(
      SimOrderOutcome outcome, {
      required String partNumber,
      String? project,
      String? description,
    }) => ProductionPlanRow(
      outcome: outcome,
      partNumber: partNumber,
      partDescription: description,
      customerProject: project,
      batchNumber: null,
      batchSize: null,
      materialDate: null,
      theoreticalLeadTime: null,
    );

    /// The two-day run with the plan the real database would have beside it.
    StoredRun described({String? project = 'MANIFOLD', String? description = 'PWB 10K 1.0'}) {
      final base = twoDayRun();
      return runOf(
        id: 'run-described',
        orders: base.result.orders,
        steps: base.result.steps,
        plan: [
          for (final outcome in base.result.orders)
            planRow(
              outcome,
              partNumber: outcome.partId == 'p1' ? 'PN1' : 'PN2',
              project: project,
              description: description,
            ),
        ],
      );
    }

    Future<void> hoverFirstBar(WidgetTester tester, StoredRun run) async {
      final layout = shownLayout(tester, run);
      final bar = rowNamed(layout, 'CLAD04').bars.first;
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(onBar(tester, bar));
      await tester.pumpAndSettle();
    }

    testWidgets('the card names the project and the description', (
      tester,
    ) async {
      final run = described();
      await pump(tester, run);
      await hoverFirstBar(tester, run);

      expect(find.text('Project'), findsOne);
      expect(find.text('MANIFOLD'), findsOne);
      expect(find.text('PWB 10K 1.0'), findsOne);
      // And it still says everything it said before.
      expect(find.text('Order 1  ·  PN1'), findsOne);
      expect(find.text('Committed'), findsOne);
    });

    testWidgets('a run stored before v12 leaves the lines out rather than '
        'blanking them', (tester) async {
      // Exactly what `loadRun` produces for a pre-v12 run: plan rows that exist
      // and answer null. A labelled empty value would read as a project called
      // nothing, which is the one thing worse than not saying.
      final run = described(project: null, description: null);
      await pump(tester, run);
      await hoverFirstBar(tester, run);

      expect(find.text('Order 1  ·  PN1'), findsOne);
      expect(find.text('Project'), findsNothing);
    });

    testWidgets('an order with no project keeps its description', (
      tester,
    ) async {
      // 11 % of the live database's orders are this: the run recorded a project
      // column and this order simply has none.
      final run = described(project: null);
      await pump(tester, run);
      await hoverFirstBar(tester, run);

      expect(find.text('PWB 10K 1.0'), findsOne);
      expect(find.text('Project'), findsNothing);
    });

    testWidgets('an order waiting in a lane is asked the same two things', (
      tester,
    ) async {
      // The project and the description belong to the order, not to what it is
      // standing in front of, so a lane's card answers them exactly as a bar's
      // does. This is the assertion behind `_orderIdOf` switching on both kinds.
      final base = twoDayRun();
      final run = runOf(
        id: 'run-lane-described',
        orders: base.result.orders,
        steps: [
          for (final step in base.result.steps)
            if (step.workcenterId == 'W2')
              SimOrderStep(
                studyId: step.studyId,
                orderId: step.orderId,
                nodeId: step.nodeId,
                workcenterId: step.workcenterId,
                queueStart: step.queueStart,
                processStart: step.processStart,
                processEnd: step.processEnd,
                changeoverIncurred: step.changeoverIncurred,
                laneNodeId: 'lane-1',
              )
            else
              step,
        ],
        lanes: const [
          SimLane(
            studyId: 'study-1',
            nodeId: 'lane-1',
            position: 1,
            name: 'FIFO CEU27',
            capacity: 2,
          ),
        ],
        plan: [
          for (final outcome in base.result.orders)
            planRow(
              outcome,
              partNumber: outcome.partId == 'p1' ? 'PN1' : 'PN2',
              project: 'MANIFOLD',
              description: 'PWB 10K 1.0',
            ),
        ],
      );

      await pump(tester, run);
      final layout = shownLayout(tester, run);
      final lane = rowNamed(layout, 'FIFO CEU27');
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(onBar(tester, lane.visits.first));
      await tester.pumpAndSettle();

      expect(find.text('Waited before starting'), findsOne);
      expect(find.text('MANIFOLD'), findsOne);
      expect(find.text('PWB 10K 1.0'), findsOne);
    });
  });

  /// The frozen label column, once the pool started travelling on the rows.
  ///
  /// The field's report was a picture of five rows all reading
  /// `CLAD Pool - Célula 11B/…`: the pool name on the real plant is 24
  /// characters, it filled a 168 px column by itself, and the trailing ellipsis
  /// dropped the machine name — the one word that told the five rows apart.
  group('the label column (§8.6)', () {
    /// A run whose stations sit in a pool named [pool].
    StoredRun pooledRun(String pool) {
      final run = twoDayRun();
      return StoredRun(
        id: 'run-pooled',
        projectId: run.projectId,
        createdAt: run.createdAt,
        dispatch: run.dispatch,
        dispatchOverrides: run.dispatchOverrides,
        studies: run.studies,
        result: run.result,
        plan: run.plan,
        metrics: summariseRun(
          result: run.result,
          partNumbers: const {'p1': 'PN1', 'p2': 'PN2'},
          workcenterNames: const {'W1': 'CLAD04', 'W2': 'CEU27'},
          theoreticalByOrder: const {},
          pools: {
            'W1': StationPool(id: 'pool-1', name: pool),
            'W2': StationPool(id: 'pool-1', name: pool),
          },
        ),
      );
    }

    /// The same run with a lane in front of CEU27, so a chart under test has
    /// one band of each kind in it.
    StoredRun laned() => runOf(
      id: 'run-laned',
      orders: twoDayRun().result.orders,
      steps: [
        for (final step in twoDayRun().result.steps)
          if (step.workcenterId == 'W2')
            SimOrderStep(
              studyId: step.studyId,
              orderId: step.orderId,
              nodeId: step.nodeId,
              workcenterId: step.workcenterId,
              queueStart: step.queueStart,
              processStart: step.processStart,
              processEnd: step.processEnd,
              changeoverIncurred: step.changeoverIncurred,
              laneNodeId: 'lane-1',
            )
          else
            step,
      ],
      lanes: const [
        SimLane(
          studyId: 'study-1',
          nodeId: 'lane-1',
          position: 1,
          name: 'FIFO CEU27',
        ),
      ],
    );

    /// The style the column drew [name] in. Each label is its own `Text` since
    /// the pool and the name stopped being two spans of one, so this reads the
    /// style that was actually applied rather than one merged at paint time.
    /// `.first` because a pool prefix repeats down every row of its pool —
    /// which is the reason it is drawn dimmer in the first place.
    TextStyle styleOf(WidgetTester tester, String name) => tester
        .widget<Text>(
          find
              .descendant(
                of: find.byKey(ganttLabelsKey),
                matching: find.text(name),
              )
              .first,
        )
        .style!;

    /// The width the column settled on.
    double columnWidth(WidgetTester tester) =>
        tester.getSize(find.byKey(ganttLabelsKey)).width;

    testWidgets('a long pool name widens the column rather than cutting the '
        'name it qualifies', (tester) async {
      await pump(tester, pooledRun('CLAD Pool - Célula 11B/C'));

      // The defect, stated as its absence: the station name is a `Text` of its
      // own, laid out at the size it needs before the prefix gets any of the
      // column. An ellipsised `CLAD04` is a different string and would not be
      // found at all.
      expect(find.text('CLAD04'), findsOne);
      expect(find.text('CEU27'), findsOne);
      expect(find.text('CLAD Pool - Célula 11B/C · '), findsNWidgets(2));

      // And the column grew past its minimum to hold them.
      expect(columnWidth(tester), greaterThan(168.0));
      expect(columnWidth(tester), lessThanOrEqualTo(260.0));
    });

    testWidgets('a pool name past any width cuts the pool, never the station', (
      tester,
    ) async {
      await pump(tester, pooledRun('A' * 200));

      // Clamped, or one long name would leave no chart beside it.
      expect(columnWidth(tester), 260.0);
      expect(find.text('CLAD04'), findsOne);
      expect(find.text('CEU27'), findsOne);
    });

    testWidgets('a run with no pools leaves the column where it was', (
      tester,
    ) async {
      await pump(tester, twoDayRun());

      expect(columnWidth(tester), 168.0);
    });

    testWidgets('a lane is italic and dimmed, a station is upright', (
      tester,
    ) async {
      await pump(tester, laned());

      final station = styleOf(tester, 'CEU27');
      final lane = styleOf(tester, 'FIFO CEU27');

      expect(station.fontStyle, FontStyle.normal);
      expect(lane.fontStyle, FontStyle.italic);
      expect(lane.color, isNot(station.color));
      // Same size — a lane is a different kind of row, not a smaller one.
      expect(lane.fontSize, station.fontSize);
    });

    testWidgets('the pool prefix is dimmer and a size smaller than the name, '
        'and keeps its row own slant', (tester) async {
      await pump(tester, pooledRun('CAL Pool'));

      final name = styleOf(tester, 'CLAD04');
      final prefix = styleOf(tester, 'CAL Pool · ');

      expect(prefix.fontSize, lessThan(name.fontSize!));
      expect(prefix.color, isNot(name.color));
      // Upright over a station, so the row still reads as one label.
      expect(prefix.fontStyle, name.fontStyle);
    });
  });
}
