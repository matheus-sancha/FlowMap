/// Where everything sits on the Gantt (DESIGN.md §8.6).
///
/// **Two functions, not one.** [buildGanttChart] resolves rows and bars in
/// `DateTime` terms — the join, done once per run — and [layoutGantt] turns that
/// into rects and a content size, done once per zoom. Geometry is then testable
/// without constructing a whole run, and the join without a pixel.
///
/// Pure arithmetic in logical pixels — no widgets, so both halves can be
/// asserted without pumping a frame. This is §5.2's precedent, which moved arrow
/// geometry into `layoutFlow` so that what a link *is* could be asserted the
/// same way; the Gantt has strictly more geometry than the arrows did, and one
/// piece of it — the 2 px floor — is the reason the file exists at all. The
/// floor is applied here rather than in the painter, so the rects [barAt] picks
/// against are the rects that were drawn.
///
/// **It needs no new data.** `simulation_run_steps` already stores a workcenter,
/// a queue start, a process start, a process end and a changeover flag per
/// order-step, which §7.10 says in as many words exists to make an order Gantt a
/// query rather than a re-run. This is the first thing to collect on it.
///
/// The join takes a result and its metrics rather than a `StoredRun`: the
/// metrics are where the row order and the colour assignment come from, the
/// result is where the steps are, and nothing else on a stored run is geometry.
/// It keeps this file out of the data layer and its tests out of a database.
library;

import 'dart:ui' show Offset, Rect, Size;

import 'run_metrics.dart';
import 'sim_result.dart';

/// Fixed sizes, in logical pixels.
abstract final class GanttMetrics {
  /// One station's band. Fixed: §8.6 zooms in X only, so a taller pane shows
  /// more stations rather than fatter ones.
  static const rowHeight = 30.0;

  /// The bar inside it, centred.
  static const barHeight = 18.0;

  /// The narrowest a bar is ever drawn.
  ///
  /// At whole-run scale a step of a few hours is a fraction of a pixel and
  /// would simply not be there, which is worse than being drawn wider than it
  /// is: a station's row would read as empty during hours it was running. The
  /// bars that hit this floor are counted ([GanttLayout.flooredBars]) so the
  /// view can say so while it is true and stop when it stops being true.
  static const minBarWidth = 2.0;

  /// The narrowest bar that still carries the changeover mark (§7.6).
  ///
  /// The mark is a stroke on the leading edge, and on a bar at or near the
  /// floor it would *be* the bar. Below this it is omitted rather than faked;
  /// the hover card says it at every scale.
  static const changeoverBarWidth = 6.0;

  /// The axis strip along the top, inside the scrolled content so it pans with
  /// the bars.
  static const axisHeight = 26.0;

  /// The closest two ticks may be drawn.
  ///
  /// Any coarser unit clears it too, so the finest one that does is the one
  /// with the most labels a reader can still tell apart.
  static const minTickSpacing = 90.0;

  /// One press of zoom.
  ///
  /// The range is the whole run down to one hour, which for a two-year run is
  /// about four orders of magnitude. ×1.25 a press crosses that in thirty
  /// presses; ×2 takes ten.
  static const zoomStep = 2.0;

  /// The most zoomed-in the chart goes: one hour across the pane.
  ///
  /// Stated in time rather than as a multiplier, so it means the same thing on
  /// a two-week run and a two-year one.
  static const ceilingSpan = Duration(hours: 1);
}

/// One part, and the colour it is drawn in (§8.6).
///
/// [colourIndex] is the part's position in the run's sorted part list, which is
/// also its row in the Parts table — so the swatch there and the bars here are
/// the same lookup rather than two that agree by luck.
class GanttPart {
  const GanttPart({
    required this.partId,
    required this.partNumber,
    required this.studyId,
    required this.colourIndex,
  });

  final String partId;
  final String partNumber;

  /// The study it belongs to. A part number identifies a part only inside its
  /// study (§16.15), so a two-study run can carry two different parts both
  /// called `PN2` and the legend has to be able to say which is which.
  final String studyId;

  /// What `partColour` is keyed on.
  final int colourIndex;
}

/// One order's visit to one station: the span the station was committed to it.
///
/// `processStart → processEnd`, **closed hours included**. The engine ends a
/// step at `calendar.advance(now, occupancy)`, so a two-open-hour job started on
/// a Friday afternoon reaches Monday morning — and that is the same wall-clock
/// span the plan's Order Start and Order End are measured across and the same
/// one §8.3 calls occupation. Drawing the open hours only would give the tab two
/// meanings of a duration.
class GanttBar {
  const GanttBar({
    required this.orderId,
    required this.orderNumber,
    required this.studyId,
    required this.part,
    required this.start,
    required this.end,
    required this.wait,
    required this.changeover,
  });

  final String orderId;

  /// The sequence position, 1-based — the same number the plan's Order column
  /// and the demand grid's row header show.
  final int orderNumber;

  final String studyId;
  final GanttPart part;

  /// `processStart`.
  final DateTime start;

  /// `processEnd`.
  final DateTime end;

  /// What the order waited here before this bar began. Reported in the hover
  /// card rather than drawn: one station can hold dozens of orders at once, and
  /// drawing those spans would smear the row solid over the bars underneath.
  final Duration wait;

  /// Whether a changeover was paid to start it (§7.6).
  final bool changeover;

  /// Wall-clock time the station was committed.
  Duration get occupied => end.difference(start);
}

/// One station's row.
class GanttRow {
  const GanttRow({
    required this.workcenterId,
    required this.name,
    required this.bars,
  });

  final String workcenterId;

  /// The name the station had when the run was made (§7.10).
  final String name;

  /// In start order. They tile without overlapping: every workcenter is its own
  /// server and a pool reaches the run as several candidates, so three cladding
  /// machines are three rows each running one order at a time.
  final List<GanttBar> bars;
}

/// The whole run, resolved but not yet measured.
class GanttChart {
  const GanttChart({
    required this.rows,
    required this.parts,
    required this.start,
    required this.end,
  });

  /// One per station, in `RunMetrics.workcenters` order — the Queue table's own
  /// ranking, so the bottleneck is the first row read and the two cannot
  /// disagree about which station is which. A station that never ran has no row.
  final List<GanttRow> rows;

  /// Every part in the run, in the Parts table's order. The legend strip is
  /// this list, so it and the table's swatches cannot come apart.
  final List<GanttPart> parts;

  /// The run's own start and end, widened if a bar somehow falls outside them.
  ///
  /// The axis covers **the run**, not merely the work: a station idle for the
  /// last three months of a run should read as idle for three months rather
  /// than as the run having ended when the last bar did.
  final DateTime start;
  final DateTime end;

  /// At least one second, so a run in which nothing took any time still has a
  /// scale to be drawn at rather than a division by zero.
  Duration get span {
    final measured = end.difference(start);
    return measured.inSeconds < 1 ? const Duration(seconds: 1) : measured;
  }

  bool get isEmpty => rows.isEmpty;
}

/// Resolves [result] into rows and bars, using [metrics] for the orders they
/// are drawn in and the order they are drawn in.
///
/// **One chart for the whole run, all studies together** — deliberately the
/// opposite of §8.5's per-study sectioning, and for a stated reason: the plan's
/// rows are orders and an order belongs to one line, but a station is shared.
/// Splitting per study would draw a station idle during hours it was in fact
/// running another study's order, which is the one thing §7.7 exists to model.
///
/// A step whose order or part the run cannot name is dropped. It cannot happen
/// through `loadRun`, where the steps, the orders and the metrics are three
/// readings of the same stored run — but a bar that cannot be labelled is a bar
/// nothing can be said about, and drawing it anonymously would be worse than
/// leaving the row a little short.
GanttChart buildGanttChart({
  required SimRunResult result,
  required RunMetrics metrics,
}) {
  final parts = <GanttPart>[
    for (var i = 0; i < metrics.parts.length; i++)
      GanttPart(
        partId: metrics.parts[i].partId,
        partNumber: metrics.parts[i].partNumber,
        studyId: metrics.parts[i].studyId,
        colourIndex: i,
      ),
  ];
  final partsById = {for (final part in parts) part.partId: part};
  final ordersById = {for (final order in result.orders) order.orderId: order};

  var start = result.start;
  var end = result.end;
  final byStation = <String, List<GanttBar>>{};

  for (final step in result.steps) {
    final outcome = ordersById[step.orderId];
    final part = outcome == null ? null : partsById[outcome.partId];
    if (outcome == null || part == null) continue;

    byStation
        .putIfAbsent(step.workcenterId, () => [])
        .add(
          GanttBar(
            orderId: step.orderId,
            // 1-based, as `ProductionPlanRow.orderNumber` is, so the hover card and
            // the plan name one order the same way.
            orderNumber: outcome.sequence + 1,
            studyId: step.studyId,
            part: part,
            start: step.processStart,
            end: step.processEnd,
            wait: step.wait,
            changeover: step.changeoverIncurred,
          ),
        );

    if (step.processStart.isBefore(start)) start = step.processStart;
    if (step.processEnd.isAfter(end)) end = step.processEnd;
  }

  return GanttChart(
    rows: [
      for (final station in metrics.workcenters)
        if (byStation[station.workcenterId] case final bars?)
          GanttRow(
            workcenterId: station.workcenterId,
            name: station.name,
            bars: bars
              ..sort((a, b) {
                final byStart = a.start.compareTo(b.start);
                // Order id last, so a station handed two bars starting in the
                // same second draws them the same way twice running.
                return byStart != 0 ? byStart : a.orderId.compareTo(b.orderId);
              }),
          ),
    ],
    parts: parts,
    start: start,
    end: end,
  );
}

/// A bar, placed.
class GanttPlacedBar {
  const GanttPlacedBar({
    required this.bar,
    required this.rect,
    required this.floored,
  });

  final GanttBar bar;
  final Rect rect;

  /// Whether [rect] is wider than the bar really is, because the bar would
  /// otherwise have been thinner than [GanttMetrics.minBarWidth].
  final bool floored;

  /// Whether there is room to mark the changeover on the leading edge (§7.6).
  bool get showsChangeover =>
      bar.changeover && rect.width >= GanttMetrics.changeoverBarWidth;
}

/// A station's row, placed.
class GanttRowLayout {
  const GanttRowLayout({
    required this.row,
    required this.top,
    required this.bars,
  });

  final GanttRow row;

  /// The top of the band, which is [GanttMetrics.rowHeight] tall.
  final double top;

  final List<GanttPlacedBar> bars;
}

/// The chart, measured at one zoom.
class GanttLayout {
  const GanttLayout({
    required this.chart,
    required this.pixelsPerSecond,
    required this.rows,
    required this.unit,
    required this.flooredBars,
    required this.size,
  });

  final GanttChart chart;

  /// The zoom this was measured at.
  final double pixelsPerSecond;

  final List<GanttRowLayout> rows;

  /// What the axis is ticked in at this zoom.
  final GanttTickUnit unit;

  /// How many bars were drawn wider than they are.
  ///
  /// The view says so while this is above zero and stops when it reaches zero,
  /// so the warning is a fact about the current zoom rather than a permanent
  /// disclaimer — which would be a lie at the ceiling, where every bar is drawn
  /// true.
  final int flooredBars;

  /// The scrolled content: the whole run wide, the axis plus every row tall.
  final Size size;
}

/// Measures [chart] at [pixelsPerSecond].
///
/// Positions are in seconds because that is the resolution the run was stored
/// at — the schema keeps dates to the second — so nothing is lost by the
/// arithmetic and a bar cannot land on a fractional instant the storage could
/// not have held.
GanttLayout layoutGantt({
  required GanttChart chart,
  required double pixelsPerSecond,
}) {
  final origin = chart.start;
  var floored = 0;

  final rows = <GanttRowLayout>[];
  for (var i = 0; i < chart.rows.length; i++) {
    final top = GanttMetrics.axisHeight + i * GanttMetrics.rowHeight;
    final barTop = top + (GanttMetrics.rowHeight - GanttMetrics.barHeight) / 2;

    final placed = <GanttPlacedBar>[];
    for (final bar in chart.rows[i].bars) {
      final left = bar.start.difference(origin).inSeconds * pixelsPerSecond;
      final width = bar.occupied.inSeconds * pixelsPerSecond;
      final isFloored = width < GanttMetrics.minBarWidth;
      if (isFloored) floored++;
      placed.add(
        GanttPlacedBar(
          bar: bar,
          rect: Rect.fromLTWH(
            left,
            barTop,
            isFloored ? GanttMetrics.minBarWidth : width,
            GanttMetrics.barHeight,
          ),
          floored: isFloored,
        ),
      );
    }

    rows.add(GanttRowLayout(row: chart.rows[i], top: top, bars: placed));
  }

  return GanttLayout(
    chart: chart,
    pixelsPerSecond: pixelsPerSecond,
    rows: rows,
    unit: ganttTickUnit(pixelsPerSecond),
    flooredBars: floored,
    size: Size(
      chart.span.inSeconds * pixelsPerSecond,
      GanttMetrics.axisHeight + chart.rows.length * GanttMetrics.rowHeight,
    ),
  );
}

/// The bar under [position], in content coordinates, or null.
///
/// **The whole row band is the target, not the 18 px bar.** A bar at the floor
/// is two pixels wide and a reader aiming at it is aiming at its row; asking
/// them to hit the bar's own height as well would make the thin bars — the ones
/// most in need of a hover card — the hardest to ask about.
///
/// Horizontally it is exact, because bars tile: a tolerance either side would
/// make two adjacent bars both answer for the boundary between them. Floored
/// bars are the one case where two can overlap, and there the earlier one wins.
GanttPlacedBar? barAt(GanttLayout layout, Offset position) {
  if (position.dy < GanttMetrics.axisHeight) return null;
  final index =
      ((position.dy - GanttMetrics.axisHeight) / GanttMetrics.rowHeight)
          .floor();
  if (index < 0 || index >= layout.rows.length) return null;

  for (final placed in layout.rows[index].bars) {
    if (position.dx >= placed.rect.left && position.dx <= placed.rect.right) {
      return placed;
    }
  }
  return null;
}

/// How far the chart may be zoomed, in pixels per second.
///
/// **Absolute, not relative.** The floor is the whole run across [paneWidth] —
/// there is nothing past it, so zoom-out disables there — and the ceiling is
/// [GanttMetrics.ceilingSpan] across the same pane.
///
/// A relative `clamp(0.2, 3.0)` was tried against the real run and fails on the
/// arithmetic: 6.3e7 seconds in a 900 px pane is 1.4e-5 px/s, so even at 3× a
/// one-hour step is 0.15 px and the chart can never be zoomed into a state
/// where a bar is real.
///
/// [max] is never below [min]: a run shorter than an hour already fits, and a
/// ceiling under the floor would mean a chart that cannot be drawn at any zoom.
({double min, double max}) ganttScaleBounds({
  required Duration span,
  required double paneWidth,
}) {
  final pane = (paneWidth.isFinite && paneWidth > 1.0) ? paneWidth : 1.0;
  final seconds = span.inSeconds < 1 ? 1 : span.inSeconds;
  final min = pane / seconds;
  final max = pane / GanttMetrics.ceilingSpan.inSeconds;
  return (min: min, max: max < min ? min : max);
}

/// [scale] brought inside [ganttScaleBounds].
double clampGanttScale(
  double scale, {
  required Duration span,
  required double paneWidth,
}) {
  final bounds = ganttScaleBounds(span: span, paneWidth: paneWidth);
  return scale.clamp(bounds.min, bounds.max);
}

/// What the axis is ticked in, finest first.
///
/// Aligned to the calendar rather than counted off the run start, so a date
/// sits under the same label at every zoom: month starts, Mondays, the top of
/// the hour — never "every 30 days from wherever this run began".
enum GanttTickUnit {
  hour(Duration(hours: 1)),
  day(Duration(days: 1)),
  week(Duration(days: 7)),

  /// The mean Gregorian month, and likewise for the two below. They are used
  /// only to ask whether ticks would be too close together, and a February that
  /// is 8 % short of the mean is not a different answer to that question.
  month(Duration(seconds: 2629746)),
  quarter(Duration(seconds: 7889238)),
  year(Duration(seconds: 31556952));

  const GanttTickUnit(this.nominal);

  /// Roughly how long one of these is.
  final Duration nominal;
}

/// The finest unit whose ticks land at least [GanttMetrics.minTickSpacing]
/// apart at [pixelsPerSecond].
///
/// Falls back to the coarsest when none of them does. That takes a run of some
/// centuries, which §7.8's guard would have abandoned long before.
GanttTickUnit ganttTickUnit(double pixelsPerSecond) {
  for (final unit in GanttTickUnit.values) {
    if (unit.nominal.inSeconds * pixelsPerSecond >=
        GanttMetrics.minTickSpacing) {
      return unit;
    }
  }
  return GanttTickUnit.values.last;
}

/// One tick on the axis.
class GanttTick {
  const GanttTick({required this.at, required this.x});

  /// The instant it marks. The **label is the widget's**: this never sees a
  /// `BuildContext`, and dates follow the locale while clock readings are
  /// 24-hour (§12.4).
  final DateTime at;

  /// Where it falls in content coordinates.
  final double x;
}

/// The ticks between content x [from] and [to].
///
/// **Only the visible ones**, which is why this is not part of [layoutGantt].
/// At the ceiling a two-year run is sixteen million pixels wide and carries
/// seventeen thousand hourly ticks; §16.9 measured local `DateTime`
/// construction on Windows at ~13 µs, so building them all would cost a fifth
/// of a second on a zoom press and throw away all but the ten on screen. A
/// scroll listener asks for the range it can see instead.
///
/// The unit comes from the layout, so the ticks and the content they are drawn
/// over were decided at one zoom.
List<GanttTick> ganttTicks(
  GanttLayout layout, {
  required double from,
  required double to,
}) {
  final scale = layout.pixelsPerSecond;
  if (scale <= 0 || !scale.isFinite || to < from) return const [];

  final origin = layout.chart.start;
  final first = origin.add(Duration(seconds: (from / scale).floor()));
  final last = origin.add(Duration(seconds: (to / scale).ceil()));

  final ticks = <GanttTick>[];
  var at = _alignTick(first, layout.unit);
  if (at.isBefore(first)) at = _nextTick(at, layout.unit);
  while (!at.isAfter(last)) {
    ticks.add(GanttTick(at: at, x: at.difference(origin).inSeconds * scale));
    at = _nextTick(at, layout.unit);
  }
  return ticks;
}

/// [at] rounded **down** to the start of its own [unit].
///
/// Written as a `DateTime` construction per unit rather than as subtraction:
/// months are not a fixed length and a local day is not always 24 hours, so
/// arithmetic on the field is the only thing that lands on midnight either side
/// of a clock change.
DateTime _alignTick(DateTime at, GanttTickUnit unit) => switch (unit) {
  GanttTickUnit.hour => DateTime(at.year, at.month, at.day, at.hour),
  GanttTickUnit.day => DateTime(at.year, at.month, at.day),
  // Monday, which is `weekday` 1.
  GanttTickUnit.week => DateTime(at.year, at.month, at.day - (at.weekday - 1)),
  GanttTickUnit.month => DateTime(at.year, at.month),
  GanttTickUnit.quarter => DateTime(at.year, at.month - (at.month - 1) % 3),
  GanttTickUnit.year => DateTime(at.year),
};

DateTime _nextTick(DateTime at, GanttTickUnit unit) => switch (unit) {
  GanttTickUnit.hour => DateTime(at.year, at.month, at.day, at.hour + 1),
  GanttTickUnit.day => DateTime(at.year, at.month, at.day + 1),
  GanttTickUnit.week => DateTime(at.year, at.month, at.day + 7),
  GanttTickUnit.month => DateTime(at.year, at.month + 1),
  GanttTickUnit.quarter => DateTime(at.year, at.month + 3),
  GanttTickUnit.year => DateTime(at.year + 1),
};
