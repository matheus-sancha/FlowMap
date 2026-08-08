import 'package:flowmap/src/features/simulation/application/gantt_layout.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Gantt's geometry (DESIGN.md §8.6), over runs small enough to check by
/// hand.
///
/// No database and no frame: the join takes a result and its metrics, and the
/// layout takes the chart, so everything the view will draw can be asserted as
/// arithmetic. The one thing this cannot check is what the drawing looks like —
/// §2.5's rule stands, and §3 drives it by hand.
void main() {
  // January, so no test lands on a daylight-saving change wherever it is run.
  // 2026-01-01 is a Thursday, which is what makes the Monday alignment below a
  // real test rather than one the start date happens to satisfy.
  final jan1 = DateTime(2026);
  DateTime at(int hours) => jan1.add(Duration(hours: hours));

  SimOrderStep stepOf({
    required String orderId,
    required String workcenterId,
    required DateTime queueStart,
    required DateTime processStart,
    required DateTime processEnd,
    bool changeover = false,
    String studyId = 'study-1',
  }) => SimOrderStep(
    studyId: studyId,
    orderId: orderId,
    nodeId: 'node-$workcenterId',
    workcenterId: workcenterId,
    queueStart: queueStart,
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
    needDate: at(48),
    released: jan1,
    delivered: at(24),
  );

  GanttChart chartOf({
    required List<SimOrderStep> steps,
    required List<SimOrderOutcome> orders,
    DateTime? start,
    DateTime? end,
    Map<String, String> partNumbers = const {'p1': 'PN1', 'p2': 'PN2'},
    Map<String, String> workcenterNames = const {'W1': 'W1', 'W2': 'W2'},
  }) {
    final result = SimRunResult(
      start: start ?? jan1,
      end: end ?? at(24),
      guard: at(240),
      steps: steps,
      orders: orders,
      emptySlots: const [],
      busyByWorkcenter: const {},
      openByWorkcenter: const {},
    );
    return buildGanttChart(
      result: result,
      metrics: summariseRun(
        result: result,
        partNumbers: partNumbers,
        workcenterNames: workcenterNames,
        theoreticalByOrder: const {},
      ),
    );
  }

  /// Three orders across two stations. W1 accumulates three hours of queue and
  /// W2 none, so the Queue table ranks W1 first — and that is the row order the
  /// chart has to reproduce.
  GanttChart threeOrders() => chartOf(
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
        processStart: at(1),
        processEnd: at(3),
        changeover: true,
      ),
      stepOf(
        orderId: 'o2',
        workcenterId: 'W1',
        queueStart: at(1),
        processStart: at(3),
        processEnd: at(4),
        changeover: true,
      ),
      stepOf(
        orderId: 'o3',
        workcenterId: 'W2',
        queueStart: jan1,
        processStart: jan1,
        processEnd: at(5),
      ),
    ],
  );

  group('the join', () {
    test('rows are the stations that ran, in the Queue table\'s order', () {
      final chart = threeOrders();

      expect(chart.rows.map((r) => r.workcenterId), ['W1', 'W2']);
      expect(chart.rows.first.bars, hasLength(2));
      expect(chart.rows.last.bars, hasLength(1));
    });

    test('a station that never ran has no row', () {
      // W2 is named — it is in the model and in the workcenter table — but no
      // order reached it, so there is nothing to draw on its row and no row.
      final chart = chartOf(
        orders: [orderOf(orderId: 'o1', sequence: 0, partId: 'p1')],
        steps: [
          stepOf(
            orderId: 'o1',
            workcenterId: 'W1',
            queueStart: jan1,
            processStart: jan1,
            processEnd: at(2),
          ),
        ],
      );

      expect(chart.rows.map((r) => r.workcenterId), ['W1']);
    });

    test('bars run in start order however the steps arrived', () {
      final chart = chartOf(
        orders: [
          orderOf(orderId: 'o1', sequence: 0, partId: 'p1'),
          orderOf(orderId: 'o2', sequence: 1, partId: 'p1'),
        ],
        steps: [
          stepOf(
            orderId: 'o2',
            workcenterId: 'W1',
            queueStart: jan1,
            processStart: at(6),
            processEnd: at(7),
          ),
          stepOf(
            orderId: 'o1',
            workcenterId: 'W1',
            queueStart: jan1,
            processStart: at(2),
            processEnd: at(3),
          ),
        ],
      );

      expect(chart.rows.single.bars.map((b) => b.orderNumber), [1, 2]);
    });

    test('a bar carries the order number, the wait and the changeover', () {
      final bars = threeOrders().rows.first.bars;

      // 1-based, as the plan's Order column is.
      expect(bars[0].orderNumber, 1);
      expect(bars[1].orderNumber, 2);
      // o2 reached W1 at 01:00 and started at 03:00.
      expect(bars[1].wait, const Duration(hours: 2));
      expect(bars[1].changeover, isTrue);
      // Closed hours included: the span is process start to process end, which
      // is the same wall clock the plan's Order Start and Order End use.
      expect(bars[0].occupied, const Duration(hours: 2));
    });

    test('parts are the Parts table\'s own list, in its own order', () {
      final chart = threeOrders();

      expect(chart.parts.map((p) => p.partNumber), ['PN1', 'PN2']);
      expect(chart.parts.map((p) => p.colourIndex), [0, 1]);
      // Which is what makes the swatch beside a part in that table and the bars
      // for its orders here one lookup rather than two that agree by luck.
      expect(chart.rows.first.bars[0].part.colourIndex, 0);
      expect(chart.rows.first.bars[1].part.colourIndex, 1);
    });

    test('two studies\' PN2 are two parts, and are coloured apart', () {
      // A part number identifies a part only inside its study (§16.15). Keyed
      // on the part number these two would share a colour and a legend entry,
      // and nothing on the chart could tell them apart.
      final chart = chartOf(
        partNumbers: const {'p1': 'PN2', 'p2': 'PN2'},
        orders: [
          orderOf(orderId: 'o1', sequence: 0, partId: 'p1', studyId: 'study-1'),
          orderOf(orderId: 'o2', sequence: 0, partId: 'p2', studyId: 'study-2'),
        ],
        steps: [
          stepOf(
            orderId: 'o1',
            workcenterId: 'W1',
            queueStart: jan1,
            processStart: jan1,
            processEnd: at(1),
          ),
          stepOf(
            orderId: 'o2',
            workcenterId: 'W1',
            queueStart: jan1,
            processStart: at(1),
            processEnd: at(2),
            studyId: 'study-2',
          ),
        ],
      );

      expect(chart.parts.map((p) => p.studyId), ['study-1', 'study-2']);
      expect(chart.rows.single.bars.map((b) => b.part.colourIndex), [0, 1]);
    });

    test('a step whose order the run cannot name is dropped', () {
      // Impossible through `loadRun`, where the steps, the orders and the
      // metrics are three readings of one stored run — but a bar that cannot be
      // labelled is a bar nothing can be said about.
      final chart = chartOf(
        orders: [orderOf(orderId: 'o1', sequence: 0, partId: 'p1')],
        steps: [
          stepOf(
            orderId: 'o1',
            workcenterId: 'W1',
            queueStart: jan1,
            processStart: jan1,
            processEnd: at(2),
          ),
          stepOf(
            orderId: 'ghost',
            workcenterId: 'W1',
            queueStart: jan1,
            processStart: at(2),
            processEnd: at(3),
          ),
        ],
      );

      expect(chart.rows.single.bars.map((b) => b.orderId), ['o1']);
    });

    test('the axis covers the run, not merely the work', () {
      // W2 stops at 05:00 and the run ends at 24:00. A station idle for the
      // rest of it should read as idle rather than as the run having ended when
      // the last bar did.
      final chart = threeOrders();

      expect(chart.start, jan1);
      expect(chart.end, at(24));
      expect(chart.span, const Duration(hours: 24));
    });

    test('a bar outside the run widens the span rather than being clipped', () {
      final chart = chartOf(
        start: at(2),
        end: at(4),
        orders: [orderOf(orderId: 'o1', sequence: 0, partId: 'p1')],
        steps: [
          stepOf(
            orderId: 'o1',
            workcenterId: 'W1',
            queueStart: jan1,
            processStart: at(1),
            processEnd: at(6),
          ),
        ],
      );

      expect(chart.start, at(1));
      expect(chart.end, at(6));
    });

    test('a run in which nothing took any time still has a span', () {
      final chart = chartOf(start: jan1, end: jan1, orders: [], steps: []);

      expect(chart.isEmpty, isTrue);
      // One second rather than zero, so there is a scale to divide by.
      expect(chart.span, const Duration(seconds: 1));
    });
  });

  group('zoom bounds', () {
    const pane = 900.0;
    const twoDays = Duration(days: 2);

    test('the floor is the whole run across the pane', () {
      final bounds = ganttScaleBounds(span: twoDays, paneWidth: pane);

      expect(bounds.min * twoDays.inSeconds, closeTo(pane, 0.001));
    });

    test('the ceiling is one hour across the pane', () {
      final bounds = ganttScaleBounds(span: twoDays, paneWidth: pane);

      expect(bounds.max * 3600, closeTo(pane, 0.001));
      // Ten presses of ×2 cross the range for a two-day run; the real one is
      // wider still, which is why the step is ×2 and not ×1.25.
      expect(bounds.max / bounds.min, closeTo(48, 0.001));
    });

    test('a run shorter than an hour cannot be zoomed at all', () {
      // It already fits, and a ceiling under the floor would be a chart that
      // can be drawn at no zoom.
      final bounds = ganttScaleBounds(
        span: const Duration(minutes: 30),
        paneWidth: pane,
      );

      expect(bounds.max, bounds.min);
    });

    test('clamping holds both ends', () {
      expect(
        clampGanttScale(1e-9, span: twoDays, paneWidth: pane),
        ganttScaleBounds(span: twoDays, paneWidth: pane).min,
      );
      expect(
        clampGanttScale(1e9, span: twoDays, paneWidth: pane),
        ganttScaleBounds(span: twoDays, paneWidth: pane).max,
      );
    });

    test('a pane with no width yields a scale rather than an infinity', () {
      final bounds = ganttScaleBounds(span: twoDays, paneWidth: 0);

      expect(bounds.min.isFinite, isTrue);
      expect(bounds.min, greaterThan(0));
    });

    test('the real run cannot be zoomed in by a relative clamp', () {
      // 6.3e7 seconds in a 900 px pane. The canvas's own `clamp(0.2, 3.0)` was
      // tried here and rejected on this arithmetic: at 3× the fit, a one-hour
      // step is 0.15 px and no zoom reaches a state where a bar is real.
      const run = Duration(seconds: 63000000);
      final bounds = ganttScaleBounds(span: run, paneWidth: pane);

      expect(bounds.min * 3600 * 3, lessThan(1.0));
      expect(bounds.max * 3600, closeTo(pane, 0.001));
    });
  });

  group('tick selection', () {
    test('picks the finest unit whose ticks clear 90 px', () {
      // Hour ticks need 90 / 3600 px/s.
      expect(ganttTickUnit(0.025), GanttTickUnit.hour);
      expect(ganttTickUnit(0.02), GanttTickUnit.day);
      // Day ticks need 90 / 86400 ≈ 1.0417e-3.
      expect(ganttTickUnit(0.0011), GanttTickUnit.day);
      expect(ganttTickUnit(0.001), GanttTickUnit.week);
      expect(ganttTickUnit(2e-4), GanttTickUnit.week);
      expect(ganttTickUnit(5e-5), GanttTickUnit.month);
    });

    test('the real run opens on quarters', () {
      // 6.3e7 seconds fitted to a 900 px pane: months land 38 px apart and
      // quarters 113.
      final fit = ganttScaleBounds(
        span: const Duration(seconds: 63000000),
        paneWidth: 900,
      ).min;

      expect(ganttTickUnit(fit), GanttTickUnit.quarter);
    });

    test('falls back to the coarsest rather than running out', () {
      // A run of some centuries, which §7.8's guard would have abandoned long
      // before — but the function must still answer.
      expect(ganttTickUnit(1e-9), GanttTickUnit.year);
    });
  });

  group('ticks', () {
    /// A chart from [from] to [to], measured at [scale].
    GanttLayout span(DateTime from, DateTime to, double scale) => layoutGantt(
      chart: chartOf(
        start: from,
        end: to,
        orders: [orderOf(orderId: 'o1', sequence: 0, partId: 'p1')],
        steps: [
          stepOf(
            orderId: 'o1',
            workcenterId: 'W1',
            queueStart: from,
            processStart: from,
            processEnd: to,
          ),
        ],
      ),
      pixelsPerSecond: scale,
    );

    test('are aligned to the calendar, not counted off the run start', () {
      // Starting at 06:00 on the 1st, the first day tick is midnight on the
      // 2nd — never "every 24 hours from wherever this run began", so a date
      // sits under the same label at every zoom.
      final layout = span(
        DateTime(2026, 1, 1, 6),
        DateTime(2026, 1, 4),
        0.0011,
      );
      final ticks = ganttTicks(layout, from: 0, to: layout.size.width);

      expect(layout.unit, GanttTickUnit.day);
      expect(ticks.map((t) => t.at), [
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 3),
        DateTime(2026, 1, 4),
      ]);
    });

    test('x is measured from the chart start', () {
      final layout = span(
        DateTime(2026, 1, 1, 6),
        DateTime(2026, 1, 4),
        0.0011,
      );
      final ticks = ganttTicks(layout, from: 0, to: layout.size.width);

      // 18 hours from 06:00 on the 1st to midnight on the 2nd.
      expect(ticks.first.x, closeTo(18 * 3600 * 0.0011, 0.001));
      expect(ticks[1].x - ticks.first.x, closeTo(86400 * 0.0011, 0.001));
    });

    test('a week ticks on Mondays', () {
      // 2026-01-01 is a Thursday, so the first Monday is the 5th.
      final layout = span(DateTime(2026), DateTime(2026, 1, 20), 2e-4);
      final ticks = ganttTicks(layout, from: 0, to: layout.size.width);

      expect(layout.unit, GanttTickUnit.week);
      expect(ticks.map((t) => t.at), [
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 12),
        DateTime(2026, 1, 19),
      ]);
      expect(ticks.every((t) => t.at.weekday == DateTime.monday), isTrue);
    });

    test('a month ticks on the first', () {
      final layout = span(DateTime(2026, 1, 15), DateTime(2026, 4, 20), 5e-5);
      final ticks = ganttTicks(layout, from: 0, to: layout.size.width);

      expect(layout.unit, GanttTickUnit.month);
      expect(ticks.map((t) => t.at), [
        DateTime(2026, 2),
        DateTime(2026, 3),
        DateTime(2026, 4),
      ]);
    });

    test('a quarter ticks in January, April, July and October', () {
      final layout = span(DateTime(2026, 2, 10), DateTime(2027, 6), 1.4e-5);
      final ticks = ganttTicks(layout, from: 0, to: layout.size.width);

      expect(layout.unit, GanttTickUnit.quarter);
      expect(ticks.map((t) => t.at), [
        DateTime(2026, 4),
        DateTime(2026, 7),
        DateTime(2026, 10),
        DateTime(2027),
        DateTime(2027, 4),
      ]);
    });

    test('only the visible ones are built', () {
      // Which is the whole reason this is not part of the layout: at the
      // ceiling a two-year run carries seventeen thousand hourly ticks, and all
      // but the ten on screen would be thrown away.
      final layout = span(DateTime(2026), DateTime(2026, 1, 31), 0.0011);
      final day = 86400 * 0.0011;

      final all = ganttTicks(layout, from: 0, to: layout.size.width);
      final window = ganttTicks(layout, from: day * 4, to: day * 6);

      // The 1st through the 31st.
      expect(all, hasLength(31));
      expect(window.map((t) => t.at), [
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 6),
        DateTime(2026, 1, 7),
      ]);
    });

    test('an empty window yields nothing rather than looping', () {
      final layout = span(DateTime(2026), DateTime(2026, 1, 31), 0.0011);

      expect(ganttTicks(layout, from: 100, to: 0), isEmpty);
      expect(ganttTicks(layout, from: 0, to: 0), hasLength(1));
    });
  });

  group('layout', () {
    test('a bar sits where its span says', () {
      const scale = 0.01;
      final layout = layoutGantt(chart: threeOrders(), pixelsPerSecond: scale);
      final first = layout.rows.first.bars.first;

      // o1 runs 01:00 → 03:00 on a chart starting at 00:00.
      expect(first.rect.left, closeTo(3600 * scale, 0.001));
      expect(first.rect.width, closeTo(2 * 3600 * scale, 0.001));
      expect(first.floored, isFalse);
    });

    test('rows stack under the axis at a fixed height', () {
      final layout = layoutGantt(chart: threeOrders(), pixelsPerSecond: 0.01);

      expect(layout.rows.first.top, GanttMetrics.axisHeight);
      expect(
        layout.rows.last.top,
        GanttMetrics.axisHeight + GanttMetrics.rowHeight,
      );
      // The bar is centred in the band.
      expect(
        layout.rows.first.bars.first.rect.top,
        GanttMetrics.axisHeight +
            (GanttMetrics.rowHeight - GanttMetrics.barHeight) / 2,
      );
    });

    test('the content is the whole run wide and every row tall', () {
      const scale = 0.01;
      final layout = layoutGantt(chart: threeOrders(), pixelsPerSecond: scale);

      expect(layout.size.width, closeTo(24 * 3600 * scale, 0.001));
      expect(
        layout.size.height,
        GanttMetrics.axisHeight + 2 * GanttMetrics.rowHeight,
      );
    });

    test('a bar too thin to see is floored, and counted', () {
      // A one-minute step at whole-run scale. Drawn true it is a fraction of a
      // pixel and simply is not there, which would read as a station idle
      // during a minute it was running.
      final chart = chartOf(
        orders: [
          orderOf(orderId: 'o1', sequence: 0, partId: 'p1'),
          orderOf(orderId: 'o2', sequence: 1, partId: 'p1'),
        ],
        steps: [
          stepOf(
            orderId: 'o1',
            workcenterId: 'W1',
            queueStart: jan1,
            processStart: jan1,
            processEnd: jan1.add(const Duration(minutes: 1)),
          ),
          stepOf(
            orderId: 'o2',
            workcenterId: 'W1',
            queueStart: jan1,
            processStart: at(2),
            processEnd: at(6),
          ),
        ],
      );
      final layout = layoutGantt(chart: chart, pixelsPerSecond: 0.001);

      expect(layout.flooredBars, 1);
      expect(layout.rows.single.bars.first.floored, isTrue);
      expect(
        layout.rows.single.bars.first.rect.width,
        GanttMetrics.minBarWidth,
      );
      expect(layout.rows.single.bars.last.floored, isFalse);
    });

    test('zooming in stops the flooring, which is what retires the note', () {
      // The note the view shows is a fact about the current zoom, not a
      // permanent disclaimer: at the ceiling every bar is drawn true.
      final chart = chartOf(
        orders: [orderOf(orderId: 'o1', sequence: 0, partId: 'p1')],
        steps: [
          stepOf(
            orderId: 'o1',
            workcenterId: 'W1',
            queueStart: jan1,
            processStart: jan1,
            processEnd: jan1.add(const Duration(minutes: 1)),
          ),
        ],
      );

      expect(layoutGantt(chart: chart, pixelsPerSecond: 0.001).flooredBars, 1);
      expect(layoutGantt(chart: chart, pixelsPerSecond: 0.25).flooredBars, 0);
    });

    test('the changeover mark is omitted rather than faked on a thin bar', () {
      // `simulation_run_steps` stores only the bool — the setup is folded into
      // the occupancy and never recorded — so a mark with a width would be a
      // duration the reader could measure and the run never held.
      final chart = chartOf(
        orders: [orderOf(orderId: 'o1', sequence: 0, partId: 'p1')],
        steps: [
          stepOf(
            orderId: 'o1',
            workcenterId: 'W1',
            queueStart: jan1,
            processStart: jan1,
            processEnd: at(1),
            changeover: true,
          ),
        ],
      );

      // 3600 s at 0.01 px/s is 36 px: room for the stroke.
      expect(
        layoutGantt(
          chart: chart,
          pixelsPerSecond: 0.01,
        ).rows.single.bars.single.showsChangeover,
        isTrue,
      );
      // At 0.001 it is 3.6 px, under the 6 px the mark needs.
      expect(
        layoutGantt(
          chart: chart,
          pixelsPerSecond: 0.001,
        ).rows.single.bars.single.showsChangeover,
        isFalse,
      );
    });

    test('a bar with no changeover never shows the mark', () {
      final layout = layoutGantt(chart: threeOrders(), pixelsPerSecond: 0.01);

      expect(layout.rows.last.bars.single.showsChangeover, isFalse);
    });
  });

  group('barAt', () {
    const scale = 0.01;
    // o1 occupies W1 from 01:00 to 03:00: 36 px to 108 px on the first row.
    late GanttLayout layout;

    setUp(() {
      layout = layoutGantt(chart: threeOrders(), pixelsPerSecond: scale);
    });

    double rowMiddle(int index) =>
        GanttMetrics.axisHeight +
        index * GanttMetrics.rowHeight +
        GanttMetrics.rowHeight / 2;

    test('names the bar under the cursor', () {
      final hit = barAt(layout, Offset(60, rowMiddle(0)));

      expect(hit?.bar.orderNumber, 1);
    });

    test('picks the right row', () {
      expect(barAt(layout, Offset(60, rowMiddle(1)))?.bar.orderNumber, 3);
    });

    test('the whole row band is the target, not the bar\'s own height', () {
      // A bar at the floor is two pixels wide, and a reader aiming at it is
      // aiming at its row. Asking them to hit 18 px of height as well would
      // make the thinnest bars the hardest to ask about.
      final top = GanttMetrics.axisHeight + 0.5;
      final bottom = GanttMetrics.axisHeight + GanttMetrics.rowHeight - 0.5;

      expect(barAt(layout, Offset(60, top))?.bar.orderNumber, 1);
      expect(barAt(layout, Offset(60, bottom))?.bar.orderNumber, 1);
    });

    test('a gap between bars is not a bar', () {
      // W2's only bar ends at 05:00, which is 180 px.
      expect(barAt(layout, Offset(200, rowMiddle(1))), isNull);
    });

    test('the axis strip is not a row', () {
      expect(barAt(layout, const Offset(60, 4)), isNull);
    });

    test('below the last row is nothing', () {
      expect(barAt(layout, Offset(60, layout.size.height + 10)), isNull);
    });

    test('past the end of the run is nothing', () {
      expect(
        barAt(layout, Offset(layout.size.width + 50, rowMiddle(0))),
        isNull,
      );
    });

    test('the rects it picks against are the rects that were drawn', () {
      // The whole argument for the file: the 2 px floor is applied in the
      // layout, so a floored bar can be hovered at the width it was drawn.
      final chart = chartOf(
        orders: [orderOf(orderId: 'o1', sequence: 0, partId: 'p1')],
        steps: [
          stepOf(
            orderId: 'o1',
            workcenterId: 'W1',
            queueStart: jan1,
            processStart: at(1),
            processEnd: jan1.add(const Duration(hours: 1, minutes: 1)),
          ),
        ],
      );
      final thin = layoutGantt(chart: chart, pixelsPerSecond: 0.001);
      final left = thin.rows.single.bars.single.rect.left;

      expect(thin.rows.single.bars.single.floored, isTrue);
      expect(barAt(thin, Offset(left + 1.5, rowMiddle(0)))?.bar.orderId, 'o1');
    });
  });
}
