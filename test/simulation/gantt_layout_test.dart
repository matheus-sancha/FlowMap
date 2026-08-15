import 'package:flowmap/src/features/simulation/application/gantt_layout.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart' show StationPool;
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Gantt's geometry (DESIGN.md §8.6), over runs small enough to check by
/// hand.
///
/// No database and no frame: the join takes a result and its metrics, and the
/// layout takes the chart, so everything the view will draw can be asserted as
/// arithmetic. The one thing this cannot check is what the drawing looks like —
/// §2.5's rule stands, and §3 drives it by hand.
/// [barAt] narrowed to a station's bar.
///
/// It answers with a lane's waiting order too now, and every test below this
/// point is about a run with no lanes in it — so the cast states that, and
/// fails loudly rather than quietly if a fixture ever grows one.
GanttPlacedBar? stationAt(GanttLayout layout, Offset position) =>
    barAt(layout, position) as GanttPlacedBar?;

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
    String? laneNodeId,
  }) => SimOrderStep(
    studyId: studyId,
    orderId: orderId,
    nodeId: 'node-$workcenterId',
    workcenterId: workcenterId,
    queueStart: queueStart,
    processStart: processStart,
    processEnd: processEnd,
    changeoverIncurred: changeover,
    laneNodeId: laneNodeId,
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

  /// Three orders across two stations, each order visiting exactly one — so
  /// both stations are first in a routing and the tie falls through to the
  /// Queue table's ranking, where W1's three hours put it above W2.
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

  /// Two orders through three stations in routing order W1 → W2 → W3.
  ///
  /// Each station makes an order wait longer than the one before it, so the
  /// Queue table ranks them W3, W2, W1 — exactly backwards to the flow, which
  /// is what makes the row order worth asserting.
  SimRunResult threeStationResult() => SimRunResult(
    start: jan1,
    end: at(48),
    guard: at(240),
    steps: [
      for (final order in ['o1', 'o2'])
        for (final (index, station) in ['W1', 'W2', 'W3'].indexed)
          stepOf(
            orderId: order,
            workcenterId: station,
            queueStart: at(index * 6),
            processStart: at(index * 6 + index),
            processEnd: at(index * 6 + index + 1),
          ),
    ],
    orders: [
      orderOf(orderId: 'o1', sequence: 0, partId: 'p1'),
      orderOf(orderId: 'o2', sequence: 1, partId: 'p1'),
    ],
    emptySlots: const [],
    busyByWorkcenter: const {},
    openByWorkcenter: const {},
  );

  group('the join', () {
    test('rows are the stations that ran, in flow order', () {
      final chart = threeOrders();

      expect(chart.stations.map((r) => r.workcenterId), ['W1', 'W2']);
      expect(chart.stations.first.bars, hasLength(2));
      expect(chart.stations.last.bars, hasLength(1));
    });

    test('flow order beats the Queue table\'s ranking', () {
      // The rows *were* the Queue ranking until the chart was driven against a
      // real plant: an order is read left to right along the map, and reading
      // it diagonally down the chart needs the routing down the page. The
      // ranking still decides ties, and the Queue table is still where the
      // bottleneck is ranked.
      final result = threeStationResult();
      final metrics = summariseRun(
        result: result,
        partNumbers: const {'p1': 'PN1'},
        workcenterNames: const {'W1': 'W1', 'W2': 'W2', 'W3': 'W3'},
        theoreticalByOrder: const {},
      );

      // The fixture is built so the two orders genuinely disagree — otherwise
      // this passes whatever the sort does.
      expect(metrics.workcenters.map((w) => w.workcenterId), [
        'W3',
        'W2',
        'W1',
      ]);
      expect(
        buildGanttChart(result: result, metrics: metrics).stations.map(
          (r) => r.workcenterId,
        ),
        ['W1', 'W2', 'W3'],
      );
    });

    test('the routing comes from arrival, not from being served', () {
      // Sorted by queue start rather than process start: a station that made an
      // order wait three days is still the station it reached third, and
      // sorting on when it got served would float the fast ones up the list.
      final chart = chartOf(
        orders: [orderOf(orderId: 'o1', sequence: 0, partId: 'p1')],
        steps: [
          stepOf(
            orderId: 'o1',
            workcenterId: 'W1',
            queueStart: jan1,
            // Sat in the queue while the second station ran something else.
            processStart: at(10),
            processEnd: at(11),
          ),
          stepOf(
            orderId: 'o1',
            workcenterId: 'W2',
            queueStart: at(11),
            processStart: at(11),
            processEnd: at(12),
          ),
        ],
      );

      expect(chart.stations.map((r) => r.workcenterId), ['W1', 'W2']);
    });

    test('a station shared by two studies takes its earliest position', () {
      // §7.7 builds one model of the plant, so one line's third station and
      // another's first are one row. It has to sit somewhere, and the earliest
      // is what keeps both routings readable downwards.
      //
      // Study 1 runs W1 → W2 → W3; study 2 runs W3 → W4. W3 is third in one
      // routing and first in the other, so it rises to the top group rather
      // than sitting below W2 — nothing queues, so within a group the ranking
      // falls through to name order.
      final chart = chartOf(
        workcenterNames: const {'W1': 'W1', 'W2': 'W2', 'W3': 'W3', 'W4': 'W4'},
        orders: [
          orderOf(orderId: 'o1', sequence: 0, partId: 'p1'),
          orderOf(orderId: 'o2', sequence: 0, partId: 'p2', studyId: 'study-2'),
        ],
        steps: [
          for (final (index, station) in ['W1', 'W2', 'W3'].indexed)
            stepOf(
              orderId: 'o1',
              workcenterId: station,
              queueStart: at(index),
              processStart: at(index),
              processEnd: at(index + 1),
            ),
          for (final (index, station) in ['W3', 'W4'].indexed)
            stepOf(
              orderId: 'o2',
              workcenterId: station,
              queueStart: at(10 + index),
              processStart: at(10 + index),
              processEnd: at(11 + index),
              studyId: 'study-2',
            ),
        ],
      );

      expect(chart.stations.map((r) => r.workcenterId), ['W1', 'W3', 'W2', 'W4']);
    });

    test('stations at one position keep the Queue table\'s order', () {
      // What a pool looks like from here: §3.1 makes its members
      // interchangeable, so all three sit at one place in the routing and only
      // the ranking has anything left to say about them.
      final chart = chartOf(
        workcenterNames: const {'W1': 'W1', 'W2': 'W2'},
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
            processEnd: at(1),
          ),
          // The same position in the routing, and the longer queue.
          stepOf(
            orderId: 'o2',
            workcenterId: 'W2',
            queueStart: jan1,
            processStart: at(5),
            processEnd: at(6),
          ),
        ],
      );

      expect(chart.stations.map((r) => r.workcenterId), ['W2', 'W1']);
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

      expect(chart.stations.map((r) => r.workcenterId), ['W1']);
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

      expect(chart.stations.single.bars.map((b) => b.orderNumber), [1, 2]);
    });

    test('a bar carries the order number, the wait and the changeover', () {
      final bars = threeOrders().stations.first.bars;

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
      expect(chart.stations.first.bars[0].part.colourIndex, 0);
      expect(chart.stations.first.bars[1].part.colourIndex, 1);
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
      expect(chart.stations.single.bars.map((b) => b.part.colourIndex), [0, 1]);
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

      expect(chart.stations.single.bars.map((b) => b.orderId), ['o1']);
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
      // Plus the gutter the horizontal scrollbar sits in: it pins to the bottom
      // of a scroll view exactly as tall as the content, so without empty
      // content under the last row it lies across that row's bars and reaching
      // for the bar means reaching through them.
      expect(
        layout.size.height,
        GanttMetrics.axisHeight +
            2 * GanttMetrics.rowHeight +
            GanttMetrics.scrollbarGutter,
      );
    });

    test('the gutter belongs to no row', () {
      final layout = layoutGantt(chart: threeOrders(), pixelsPerSecond: 0.01);
      final inGutter = layout.size.height - GanttMetrics.scrollbarGutter / 2;

      // Otherwise the last row would answer for a pointer that is on the
      // scrollbar, which is the conflict the gutter exists to end.
      expect(stationAt(layout, Offset(60, inGutter)), isNull);
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
      final hit = stationAt(layout, Offset(60, rowMiddle(0)));

      expect(hit?.bar.orderNumber, 1);
    });

    test('picks the right row', () {
      expect(stationAt(layout, Offset(60, rowMiddle(1)))?.bar.orderNumber, 3);
    });

    test('the whole row band is the target, not the bar\'s own height', () {
      // A bar at the floor is two pixels wide, and a reader aiming at it is
      // aiming at its row. Asking them to hit 18 px of height as well would
      // make the thinnest bars the hardest to ask about.
      final top = GanttMetrics.axisHeight + 0.5;
      final bottom = GanttMetrics.axisHeight + GanttMetrics.rowHeight - 0.5;

      expect(stationAt(layout, Offset(60, top))?.bar.orderNumber, 1);
      expect(stationAt(layout, Offset(60, bottom))?.bar.orderNumber, 1);
    });

    test('a gap between bars is not a bar', () {
      // W2's only bar ends at 05:00, which is 180 px.
      expect(stationAt(layout, Offset(200, rowMiddle(1))), isNull);
    });

    test('the axis strip is not a row', () {
      expect(stationAt(layout, const Offset(60, 4)), isNull);
    });

    test('below the last row is nothing', () {
      expect(stationAt(layout, Offset(60, layout.size.height + 10)), isNull);
    });

    test('past the end of the run is nothing', () {
      expect(
        stationAt(layout, Offset(layout.size.width + 50, rowMiddle(0))),
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
      expect(stationAt(thin, Offset(left + 1.5, rowMiddle(0)))?.bar.orderId, 'o1');
    });
  });

  group('a station with more than one unit', () {
    /// One station running two orders whose spans overlap, which is what §3.2
    /// made possible and what §8.6 had assumed could not happen.
    GanttChart twoAtOnce() => chartOf(
      orders: [
        orderOf(orderId: 'o1', sequence: 0, partId: 'p1'),
        orderOf(orderId: 'o2', sequence: 1, partId: 'p2'),
      ],
      steps: [
        stepOf(
          orderId: 'o1',
          workcenterId: 'W1',
          queueStart: jan1,
          processStart: jan1,
          processEnd: at(10),
        ),
        stepOf(
          orderId: 'o2',
          workcenterId: 'W1',
          queueStart: at(2),
          processStart: at(2),
          processEnd: at(8),
        ),
      ],
      workcenterNames: const {'W1': 'TTAT'},
    );

    test('overlapping bars take their own sub-row', () {
      final row = twoAtOnce().stations.single;

      expect(row.bars.map((b) => b.slot), [0, 1]);
      expect(row.depth, 2);
      // Two units, so the band is twice a station's row.
      expect(row.height, 2 * GanttMetrics.rowHeight);
    });

    test('a station that never ran two at once is unchanged', () {
      // The premise §8.6 was written under, and the case that must keep
      // drawing exactly as it did: every bar on slot 0, one row deep.
      final row = threeOrders().stations.first;

      expect(row.bars.every((b) => b.slot == 0), isTrue);
      expect(row.depth, 1);
      expect(row.height, GanttMetrics.rowHeight);
    });

    test('the bars do not overlap once they are placed', () {
      final layout = layoutGantt(chart: twoAtOnce(), pixelsPerSecond: 0.01);
      final bars = layout.rows.single.bars;

      // The defect, stated as geometry: two bars covering the same instant
      // must not cover the same pixel. Both are true of the rects, so this
      // fails on the drawing rather than on the arithmetic behind it.
      expect(bars.first.rect.overlaps(bars.last.rect), isFalse);
      expect(bars.first.rect.top, isNot(bars.last.rect.top));
    });

    test('barAt tells the two units apart', () {
      final chart = twoAtOnce();
      final layout = layoutGantt(chart: chart, pixelsPerSecond: 0.01);
      final row = layout.rows.single;

      double slotMiddle(int slot) =>
          row.top + slot * GanttMetrics.rowHeight + GanttMetrics.rowHeight / 2;

      // Hour 4 has both orders running; only the sub-row separates them.
      final x = at(4).difference(chart.start).inSeconds * 0.01;
      expect(stationAt(layout, Offset(x, slotMiddle(0)))?.bar.orderId, 'o1');
      expect(stationAt(layout, Offset(x, slotMiddle(1)))?.bar.orderId, 'o2');
    });
  });

  group('lane bands', () {
    /// Orders queueing in one lane in front of W2, which W1 feeds.
    ///
    /// [stays] is one `(order, entered, left)` per visit in hours, so a test
    /// says what it is about — two orders waiting at once, or one after the
    /// other — without building a plausible-looking run around it.
    GanttChart laneChart({
      required List<({String order, int from, int to})> stays,
      int? capacity,
      String? laneName = 'FIFO W2',
      List<SimOpenLaneVisit> open = const [],
      bool laneOnResult = true,
      bool includeLanes = true,
    }) {
      final steps = [
        for (final stay in stays)
          stepOf(
            orderId: stay.order,
            workcenterId: 'W2',
            queueStart: at(stay.from),
            processStart: at(stay.to),
            processEnd: at(stay.to + 1),
            laneNodeId: 'lane-1',
          ),
      ];
      final orders = [
        for (final (index, stay) in stays.indexed)
          orderOf(orderId: stay.order, sequence: index, partId: 'p1'),
        for (final visit in open)
          orderOf(orderId: visit.orderId, sequence: 90, partId: 'p1'),
      ];

      final result = SimRunResult(
        start: jan1,
        end: at(48),
        guard: at(240),
        steps: steps,
        orders: orders,
        emptySlots: const [],
        busyByWorkcenter: const {},
        openByWorkcenter: const {},
        openLaneVisits: open,
        lanes: laneOnResult
            ? [
                SimLane(
                  studyId: 'study-1',
                  nodeId: 'lane-1',
                  position: 1,
                  name: laneName,
                  capacity: capacity,
                ),
              ]
            : const [],
      );

      return buildGanttChart(
        result: result,
        metrics: summariseRun(
          result: result,
          partNumbers: const {'p1': 'PN1'},
          workcenterNames: const {'W2': 'W2'},
          theoreticalByOrder: const {},
        ),
        includeLanes: includeLanes,
      );
    }

    test('the lane bands can be left out, and only they go', () {
      // Field feedback: a reader following an order down the page wants the
      // stations, and the queue bands between them are what is in the way. It is
      // a view control, so it removes rows and changes nothing else — the
      // stations keep their bars, their order and their names.
      final withLanes = laneChart(stays: [(order: 'o1', from: 0, to: 2)]);
      final without = laneChart(
        stays: [(order: 'o1', from: 0, to: 2)],
        includeLanes: false,
      );

      expect(withLanes.rows.map((b) => b.name), ['FIFO W2', 'W2']);
      expect(without.rows.map((b) => b.name), ['W2']);
      expect(without.lanes, isEmpty);
      expect(
        without.stations.single.bars.length,
        withLanes.stations.single.bars.length,
      );
      // The axis still covers the run rather than shrinking to what is drawn:
      // the span is a fact about the run, not about the rows on screen.
      expect(without.start, withLanes.start);
      expect(without.end, withLanes.end);
    });

    test('a lane is drawn immediately above the station it feeds', () {
      final chart = laneChart(
        stays: [(order: 'o1', from: 0, to: 2)],
      );

      expect(chart.rows.map((b) => b.name), ['FIFO W2', 'W2']);
      expect(chart.rows.first, isA<GanttLaneRow>());
      expect(chart.rows.last, isA<GanttRow>());
    });

    test('overlapping stays take different slots, sequential ones re-use one', () {
      final together = laneChart(
        stays: [
          (order: 'o1', from: 0, to: 6),
          (order: 'o2', from: 1, to: 6),
        ],
      ).lanes.single;
      expect(together.visits.map((v) => v.slot), [0, 1]);

      final apart = laneChart(
        stays: [
          (order: 'o1', from: 0, to: 2),
          (order: 'o2', from: 3, to: 5),
        ],
      ).lanes.single;
      // The second arrives after the first has gone, so the lane never held
      // two at once and the stack does not grow.
      expect(apart.visits.map((v) => v.slot), [0, 0]);
    });

    test('a capped lane is as deep as its capacity, however empty it stayed', () {
      final lane = laneChart(
        stays: [(order: 'o1', from: 0, to: 2)],
        capacity: 3,
      ).lanes.single;

      // The empty slots are the headroom. Drawing it one deep because only one
      // order ever stood there would make every capped lane look full.
      expect(lane.depth, 3);
      expect(lane.capacity, 3);
      expect(lane.truncated, isFalse);
    });

    test('an uncapped lane takes its depth from how full it got', () {
      final lane = laneChart(
        stays: [
          (order: 'o1', from: 0, to: 6),
          (order: 'o2', from: 1, to: 6),
        ],
      ).lanes.single;

      expect(lane.capacity, isNull);
      expect(lane.depth, 2);
    });

    test('a lane nothing ever waited in is still one band deep', () {
      // Every order passed straight through: entered and left at the same
      // instant. The lane existed, and drawing no band would say the flow had
      // no buffer at that point.
      final lane = laneChart(
        stays: [(order: 'o1', from: 2, to: 2)],
      ).lanes.single;

      expect(lane.depth, 1);
    });

    test('depth stops at the cap, and says that it did', () {
      final lane = laneChart(
        stays: [
          for (var i = 0; i < GanttMetrics.maxLaneDepth + 2; i++)
            (order: 'o$i', from: i, to: 20),
        ],
      ).lanes.single;

      expect(lane.depth, GanttMetrics.maxLaneDepth);
      expect(lane.truncated, isTrue);
    });

    test('an order still standing there when the run ended is drawn', () {
      final lane = laneChart(
        stays: [(order: 'o1', from: 0, to: 2)],
        open: [
          SimOpenLaneVisit(
            studyId: 'study-1',
            orderId: 'o9',
            laneNodeId: 'lane-1',
            enteredAt: at(30),
          ),
        ],
      ).lanes.single;

      final caught = lane.visits.firstWhere((v) => v.orderId == 'o9');
      expect(caught.open, isTrue);
      // It leaves no step, so without this the lane would read emptiest at
      // exactly the moment a jam is the finding.
      expect(caught.left, at(48));
    });

    test('a lane the run never names is not drawn', () {
      final chart = laneChart(
        stays: [(order: 'o1', from: 0, to: 2)],
        laneOnResult: false,
      );

      expect(chart.lanes, isEmpty);
      expect(chart.rows.map((b) => b.name), ['W2']);
    });

    test('bands stack by their own heights, not by a fixed row', () {
      final chart = laneChart(
        stays: [
          (order: 'o1', from: 0, to: 6),
          (order: 'o2', from: 1, to: 6),
        ],
      );
      final layout = layoutGantt(chart: chart, pixelsPerSecond: 0.01);

      final lane = layout.rows.first;
      final station = layout.rows.last;

      expect(lane.top, GanttMetrics.axisHeight);
      // Two slots deep, so the station below starts that much further down —
      // the arithmetic the old `i × rowHeight` could not have produced.
      expect(station.top, GanttMetrics.axisHeight + lane.band.height);
      expect(
        lane.band.height,
        2 * GanttMetrics.laneSlotHeight + 2 * GanttMetrics.lanePadding,
      );
    });

    test('barAt picks a waiting order by its slot', () {
      final chart = laneChart(
        stays: [
          (order: 'o1', from: 0, to: 6),
          (order: 'o2', from: 1, to: 6),
        ],
      );
      final layout = layoutGantt(chart: chart, pixelsPerSecond: 0.01);
      final lane = layout.rows.first;

      double slotMiddle(int slot) =>
          lane.top +
          GanttMetrics.lanePadding +
          slot * GanttMetrics.laneSlotHeight +
          GanttMetrics.laneBarHeight / 2;

      // Both are on the chart at hour 4; only the slot tells them apart, which
      // is the whole reason the stack exists.
      final x = at(4).difference(chart.start).inSeconds * 0.01;
      expect(
        (barAt(layout, Offset(x, slotMiddle(0))) as GanttPlacedVisit?)
            ?.visit
            .orderId,
        'o1',
      );
      expect(
        (barAt(layout, Offset(x, slotMiddle(1))) as GanttPlacedVisit?)
            ?.visit
            .orderId,
        'o2',
      );
    });
  });

  group('pools (§3.1) — the CAL pool bug, 2026-08-15', () {
    /// A run over a pool, optionally with a lane per study in front of it.
    ///
    /// `pools` maps each station to the pool the run recorded for it, which is
    /// what `stationPools` resolves at write time and what the metrics carry
    /// back out — so a test can state the case without assembling a plant.
    GanttChart poolChart({
      required Map<String, StationPool> pools,
      Map<String, String> workcenterNames = const {
        'CLAD07': 'CLAD07',
        'CLAD08': 'CLAD08',
      },
      List<({String order, String station, String? lane, int at})> visits =
          const [],
      List<({String node, String name})> lanes = const [],
    }) {
      final steps = [
        for (final visit in visits)
          stepOf(
            orderId: visit.order,
            workcenterId: visit.station,
            queueStart: at(visit.at),
            processStart: at(visit.at + 1),
            processEnd: at(visit.at + 2),
            laneNodeId: visit.lane,
          ),
      ];
      final orders = [
        for (final (index, visit) in visits.indexed)
          orderOf(orderId: visit.order, sequence: index, partId: 'p1'),
      ];

      final result = SimRunResult(
        start: jan1,
        end: at(48),
        guard: at(240),
        steps: steps,
        orders: orders,
        emptySlots: const [],
        busyByWorkcenter: const {},
        openByWorkcenter: const {},
        lanes: [
          for (final lane in lanes)
            SimLane(
              studyId: 'study-1',
              nodeId: lane.node,
              position: 1,
              name: lane.name,
            ),
        ],
      );

      return buildGanttChart(
        result: result,
        metrics: summariseRun(
          result: result,
          partNumbers: const {'p1': 'PN1'},
          workcenterNames: workcenterNames,
          theoreticalByOrder: const {},
          pools: pools,
        ),
      );
    }

    const cal = StationPool(id: 'pool-1', name: 'CAL Pool');

    test('a pool\'s machines sit under one heading', () {
      // The complaint itself: three cladding machines reading as three loose
      // stations, with nothing on screen carrying the name that was typed on
      // the map. §3.1 keeps them as separate rows on purpose — that is what
      // says which machine ran an order — so what was missing was only the
      // word above them.
      final chart = poolChart(
        pools: const {'CLAD07': cal, 'CLAD08': cal},
        visits: [
          (order: 'o1', station: 'CLAD07', lane: null, at: 0),
          (order: 'o2', station: 'CLAD08', lane: null, at: 0),
        ],
      );

      expect(chart.rows.map((b) => b.name), [
        'CAL Pool',
        'CLAD07',
        'CLAD08',
      ]);
      // The heading is not a band of the run: it carries nothing to hover and
      // it is not a station.
      expect(chart.rows.first, isA<GanttPoolGroup>());
      expect(chart.stations.map((r) => r.workcenterId), ['CLAD07', 'CLAD08']);
    });

    test('two studies\' lanes over one pool both draw', () {
      // **The defect.** `_laneRows` was a map keyed by workcenter, so the
      // second lane feeding a station overwrote the first and one FIFO band
      // left the chart with nothing saying it had. Two studies stepping on one
      // pool is exactly how that arises (§7.7).
      final chart = poolChart(
        pools: const {'CLAD07': cal, 'CLAD08': cal},
        lanes: [
          (node: 'lane-a', name: 'FIFO A'),
          (node: 'lane-b', name: 'FIFO B'),
        ],
        visits: [
          (order: 'o1', station: 'CLAD07', lane: 'lane-a', at: 0),
          (order: 'o2', station: 'CLAD08', lane: 'lane-b', at: 0),
        ],
      );

      expect(chart.lanes, hasLength(2));
      // Both above the heading's machines rather than one above each — a lane
      // feeds the pool, not the member that happened to pull the first order.
      expect(chart.rows.map((b) => b.name), [
        'CAL Pool',
        'FIFO A',
        'FIFO B',
        'CLAD07',
        'CLAD08',
      ]);
    });

    test('a pool\'s lane is not pinned to whichever member ran first', () {
      // The second half of the same bug: `feeds` took the first *step* out of
      // the lane, so the band landed on whichever machine happened to pull an
      // order first — which is the member that looked detached from its
      // siblings. Here CLAD08 runs first and the band still belongs to the
      // pool — and the members keep the Queue table's order underneath the
      // heading, which for two stations that queued equally is by name.
      final chart = poolChart(
        pools: const {'CLAD07': cal, 'CLAD08': cal},
        lanes: [(node: 'lane-a', name: 'FIFO CAL')],
        visits: [
          (order: 'o1', station: 'CLAD08', lane: 'lane-a', at: 0),
          (order: 'o2', station: 'CLAD07', lane: 'lane-a', at: 4),
        ],
      );

      expect(chart.rows.map((b) => b.name), [
        'CAL Pool',
        'FIFO CAL',
        'CLAD07',
        'CLAD08',
      ]);
    });

    test('a station in two pools stands on its own, naming both', () {
      // `stationPools` resolves this to a null id and a joined name, and the
      // chart honours it: no heading, because there is no one pool this
      // machine's work belonged to — and the name is still on the row's own
      // record so a reader can see why it is loose.
      final chart = poolChart(
        pools: const {
          'CLAD07': StationPool(id: null, name: 'All Lathes · CAL Pool'),
          'CLAD08': cal,
        },
        visits: [
          (order: 'o1', station: 'CLAD07', lane: null, at: 0),
          (order: 'o2', station: 'CLAD08', lane: null, at: 0),
        ],
      );

      expect(chart.rows.whereType<GanttPoolGroup>().map((g) => g.name), [
        'CAL Pool',
      ]);
      final loose = chart.stations.firstWhere(
        (r) => r.workcenterId == 'CLAD07',
      );
      expect(loose.poolId, isNull);
      expect(loose.poolName, 'All Lathes · CAL Pool');
    });

    test('a run with no pools draws exactly as it did before', () {
      // The regression guard. Every chart in this file predates v18 and none
      // of them may move: with no pool recorded, there is no heading and the
      // rows are the stations and their lanes, in the order they always were.
      final chart = poolChart(
        pools: const {},
        lanes: [(node: 'lane-a', name: 'FIFO W')],
        visits: [
          (order: 'o1', station: 'CLAD07', lane: 'lane-a', at: 0),
          (order: 'o2', station: 'CLAD08', lane: null, at: 0),
        ],
      );

      expect(chart.rows.whereType<GanttPoolGroup>(), isEmpty);
      expect(chart.rows.map((b) => b.name), ['FIFO W', 'CLAD07', 'CLAD08']);
    });
  });
}
