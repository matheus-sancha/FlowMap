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

  /// One waiting order's slot down a lane band (§8.6).
  ///
  /// A lane's band is as deep as the lane is, so a full lane is visibly full
  /// rather than something a reader has to infer from a gap in the row below
  /// it. Shorter than [rowHeight] because a lane of three would otherwise be
  /// three times the height of the station it feeds and dominate a chart whose
  /// subject is the stations.
  static const laneSlotHeight = 10.0;

  /// The waiting bar inside that slot.
  static const laneBarHeight = 7.0;

  /// Above and below a lane's stack, so its orders do not touch the station
  /// bands either side.
  static const lanePadding = 3.0;

  /// The deepest a lane band is drawn, however deep the lane is.
  ///
  /// An uncapped lane takes its depth from how full it actually got (§5.5), and
  /// CEU27's held **8 orders at once** on the 2026-08-09 run — 80 px of band
  /// above a 30 px station, for a lane whose depth is an observation rather
  /// than a rule. Past this the stack is drawn full and the count is in the
  /// label, which is the same bargain [minBarWidth] makes: legible beats
  /// literal, and the number is never hidden.
  static const maxLaneDepth = 4;

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

  /// Empty content below the last row, for the horizontal scrollbar to sit in.
  ///
  /// The bar pins to the bottom of the scroll view, which is exactly as tall as
  /// the content — so without this it lies across the last row's bars, and
  /// reaching for the bar means reaching through them. Found by dragging it.
  static const scrollbarGutter = 18.0;

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
    this.slot = 0,
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

  /// Which unit of the station ran it, as far as the chart can tell: the
  /// topmost sub-row no overlapping bar is using.
  ///
  /// **A station's bars stopped tiling when §3.2 landed.** §8.6 was written when
  /// every workcenter was one server, so two bars could not overlap and one
  /// sub-row was enough; a station given parallel units genuinely runs two
  /// orders at once, and drawing both at one height puts one on top of the
  /// other. Found by looking at it — TTAT is set to two units on célula 11B.
  ///
  /// **Derived, not stored.** `simulation_run_workcenters` keeps no unit count,
  /// and §7.10 forbids joining back to the plant to ask — but the overlap is in
  /// the steps, so the depth a station needs is the depth it was observed to
  /// use. A station that never ran two at once draws exactly as it did before.
  final int slot;

  /// Wall-clock time the station was committed.
  Duration get occupied => end.difference(start);

  GanttBar _atSlot(int slot) => GanttBar(
    orderId: orderId,
    orderNumber: orderNumber,
    studyId: studyId,
    part: part,
    start: start,
    end: end,
    wait: wait,
    changeover: changeover,
    slot: slot,
  );
}

/// One order's stay in a lane: from reaching it to being pulled out (§5.5).
///
/// Read off [SimOrderStep] rather than stored twice — `queueStart` is when the
/// order entered the lane in front of that step and `processStart` is when the
/// station took it — with [SimOpenLaneVisit] supplying the orders the guard
/// caught still standing there, which produce no step at all.
class GanttLaneVisit {
  const GanttLaneVisit({
    required this.orderId,
    required this.orderNumber,
    required this.studyId,
    required this.part,
    required this.entered,
    required this.left,
    required this.slot,
    required this.open,
  });

  final String orderId;
  final int orderNumber;
  final String studyId;
  final GanttPart part;

  final DateTime entered;

  /// When the station pulled it out — or the run's end, when [open].
  final DateTime left;

  /// Which slot down the band it is drawn in, 0 at the top.
  ///
  /// Assigned so that no two overlapping stays share one, which is what makes a
  /// full lane read as full. A capped lane never needs more slots than its
  /// capacity, because the engine never let more in than that.
  final int slot;

  /// Still standing in the lane when the run ended. Its [left] is the run's end
  /// rather than a departure that happened.
  final bool open;

  Duration get waited => left.difference(entered);
}

/// A band down the chart: either a station or the lane feeding it.
///
/// A union rather than a flag, because the two carry different things and are
/// drawn differently — a station's bars tile along one line, a lane's stack
/// down its depth — and a reader of this file should not have to know which
/// fields are live for which kind.
sealed class GanttBand {
  const GanttBand();

  /// What the frozen label column shows.
  String get name;

  /// How tall the band is. **Not a constant**, since §8.6 makes a lane as deep
  /// as the lane is, so nothing downstream may assume a uniform row.
  double get height;
}

/// One station's row.
class GanttRow extends GanttBand {
  const GanttRow({
    required this.workcenterId,
    required this.name,
    required this.bars,
    this.depth = 1,
    this.poolId,
    this.poolName,
  });

  final String workcenterId;

  /// The pool the run says this station was dispatched through (§3.1), or null
  /// where it ran on its own name — or was reached through more than one pool,
  /// or the run predates v18. A non-null [poolId] is what puts a
  /// [GanttPoolGroup] header above it and its siblings.
  ///
  /// [poolName] can outlive [poolId]: a station reached two ways names them
  /// both and groups under neither.
  final String? poolId;
  final String? poolName;

  /// The name the station had when the run was made (§7.10).
  @override
  final String name;

  /// In start order, each carrying the sub-row it is drawn on.
  ///
  /// A pool still reaches the run as several candidates, so three cladding
  /// machines are three rows; what [depth] answers is one machine with more
  /// than one unit (§3.2).
  final List<GanttBar> bars;

  /// How many orders this station was ever running at once, at least one.
  ///
  /// Bounded by the station's parallel capacity, which the run does not store —
  /// so this is what was observed rather than what was allowed, and a two-unit
  /// station that never had two orders in hand at the same moment draws one
  /// deep. That is the honest reading: the chart shows the run, not the plant.
  final int depth;

  @override
  double get height => depth * GanttMetrics.rowHeight;
}

/// One lane's band, drawn immediately above the station it feeds (§3.4, §8.6).
class GanttLaneRow extends GanttBand {
  const GanttLaneRow({
    required this.laneNodeId,
    required this.name,
    this.poolName,
    required this.capacity,
    required this.depth,
    required this.visits,
  });

  final String laneNodeId;

  /// `FIFO CEU27`, or a stand-in when the buffer was never labelled.
  @override
  final String name;

  /// The pool this lane feeds, where it feeds one — so the label can read
  /// `CLAD Pool · FIFO CLAD` and say which machines are behind it (§3.1).
  final String? poolName;

  /// What the lane could hold, or null for unlimited (§5.5).
  final int? capacity;

  /// Slots drawn: the capacity, or for an uncapped lane the most it ever
  /// actually held. At least one, so a lane nothing ever waited in is still a
  /// band the reader can see — the lane existed, and drawing nothing there
  /// would say the flow had no buffer at that point.
  ///
  /// Capped at [GanttMetrics.maxLaneDepth].
  final int depth;

  final List<GanttLaneVisit> visits;

  /// Whether the stack is drawn shallower than the lane really went, so the
  /// view can say the depth is indicative here and stop saying it elsewhere.
  bool get truncated => capacity == null
      ? depth >= GanttMetrics.maxLaneDepth
      : capacity! > depth;

  @override
  double get height =>
      depth * GanttMetrics.laneSlotHeight + 2 * GanttMetrics.lanePadding;
}

/// The whole run, resolved but not yet measured.
class GanttChart {
  const GanttChart({
    required this.rows,
    required this.parts,
    required this.start,
    required this.end,
  });

  /// One per station, **in the order the work flows through them** — the first
  /// station of the routing on the first row, so an order is read diagonally
  /// down the chart the way it is read left to right along the map (§5.1) —
  /// with each lane's band immediately above the station it feeds, so the chart
  /// reads down the page the way the line runs.
  ///
  /// Ties fall back to `RunMetrics.workcenters`, the Queue table's ranking, so
  /// stations at one position in the routing — a pool's three machines — still
  /// come out busiest-first and in the same order twice running. A station that
  /// never ran has no row.
  final List<GanttBand> rows;

  /// Just the station bands, in the same order.
  Iterable<GanttRow> get stations => rows.whereType<GanttRow>();

  /// Just the lane bands, in the same order.
  Iterable<GanttLaneRow> get lanes => rows.whereType<GanttLaneRow>();

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
  bool includeLanes = true,
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

  // **What a lane feeds, and what a header labels, is the group** — the pool
  // where the station ran in one (§3.1), the station itself otherwise. Read off
  // the metrics, which read it off the run, so a plant re-pooled since cannot
  // move a band (§7.10).
  final groupOf = {
    for (final station in metrics.workcenters)
      station.workcenterId: station.poolId ?? station.workcenterId,
  };

  // Down the page in the order the work happens, with the Queue table's
  // ranking left to break ties.
  final flow = routingRanks(result);

  // **A group sorts where its busiest member would have sorted.** Each takes
  // the earliest routing rank and the best Queue rank any of its members has —
  // so a pool cannot be split by one machine also appearing later in the flow,
  // and an ungrouped station is its own group and lands exactly where it always
  // did. Ranking a group by its name instead would have been simpler and would
  // have thrown away the Queue table's order for every station that is not in
  // a pool.
  final groupFlow = <String, int>{};
  final groupQueue = <String, int>{};
  for (var i = 0; i < metrics.workcenters.length; i++) {
    final station = metrics.workcenters[i];
    final group = groupOf[station.workcenterId]!;
    final rank = flow[station.workcenterId] ?? _unrouted;
    if (rank < (groupFlow[group] ?? _unrouted)) groupFlow[group] = rank;
    groupQueue[group] = groupQueue[group] ?? i;
  }

  final ordered =
      [
        for (var i = 0; i < metrics.workcenters.length; i++)
          (station: metrics.workcenters[i], queueRank: i),
      ]..sort((a, b) {
        final groupA = groupOf[a.station.workcenterId]!;
        final groupB = groupOf[b.station.workcenterId]!;
        final byFlow = (groupFlow[groupA] ?? _unrouted).compareTo(
          groupFlow[groupB] ?? _unrouted,
        );
        if (byFlow != 0) return byFlow;
        // Two groups can share a routing rank — a step on a pool and a step on
        // a lone station at one position — and their members must not
        // interleave, or a header would sit above a machine belonging to the
        // other. Ordered by the Queue ranking rather than by name, which is
        // what keeps this identical to the old two-clause sort wherever no
        // pool is involved.
        final byGroup = (groupQueue[groupA] ?? 0).compareTo(
          groupQueue[groupB] ?? 0,
        );
        // The Queue table's own order underneath, which is what keeps a pool's
        // three machines — all at one position in the routing — in the same
        // order twice running, and puts the busiest of them first.
        return byGroup != 0 ? byGroup : a.queueRank.compareTo(b.queueRank);
      });

  final stations = <GanttRow>[];
  for (final entry in ordered) {
    final bars = byStation[entry.station.workcenterId];
    if (bars == null) continue;

    bars.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      // Order id last, so a station handed two bars starting in the same
      // second draws them the same way twice running.
      return byStart != 0 ? byStart : a.orderId.compareTo(b.orderId);
    });

    // The topmost sub-row free when each bar starts. One unit re-uses slot 0
    // throughout, which is what keeps every single-unit station drawn exactly
    // as it was before §3.2 gave a station more than one.
    final freeAt = <DateTime>[];
    final placed = <GanttBar>[];
    for (final bar in bars) {
      var slot = freeAt.indexWhere((free) => !free.isAfter(bar.start));
      if (slot < 0) {
        slot = freeAt.length;
        freeAt.add(bar.end);
      } else {
        freeAt[slot] = bar.end;
      }
      placed.add(bar._atSlot(slot));
    }

    stations.add(
      GanttRow(
        workcenterId: entry.station.workcenterId,
        name: entry.station.name,
        bars: placed,
        depth: freeAt.isEmpty ? 1 : freeAt.length,
        poolId: entry.station.poolId,
        poolName: entry.station.poolName,
      ),
    );
  }

  // The lane bands are what makes the chart read as a queue; without them it
  // reads as a flow, which is the other thing a reader comes to it for. The
  // toggle is a view control, so it is a parameter here rather than a second
  // chart — `barAt`, the hover card and the floored-bar count all follow from
  // the rows and need to know nothing about it.
  final lanes = includeLanes
      ? _laneRows(
          result: result,
          partsById: partsById,
          ordersById: ordersById,
          groupOf: groupOf,
          poolNameOf: {
            for (final station in metrics.workcenters)
              if (station.poolId != null && station.poolName != null)
                station.poolId!: station.poolName!,
          },
        )
      : const <String, List<GanttLaneRow>>{};

  // **Emitted a group at a time.** A pool's members sit under one header, the
  // lanes that feed the pool are drawn once above them rather than once per
  // machine, and a station standing on its own draws exactly as it always did.
  final rows = <GanttBand>[];
  var group = _noGroup;
  for (final station in stations) {
    final key = groupOf[station.workcenterId]!;
    if (key == group) {
      rows.add(station);
      continue;
    }
    group = key;

    // **No heading band.** A pool used to get a row of its own above its
    // machines, and it read as a lane rather than as a label — a band with
    // nothing in it, between the axis and the first thing that had bars. The
    // pool travels on the rows instead: every member and every lane feeding it
    // is labelled `CLAD Pool · CLAD07`, so what belongs together says so without
    // a band that belongs to nothing.
    //
    // The lanes come first: an order stands in the lane and is then taken by
    // the station, so upstream is up the page.
    rows.addAll(lanes[key] ?? const []);
    rows.add(station);
  }

  return GanttChart(rows: rows, parts: parts, start: start, end: end);
}

/// No group has been opened yet. A sentinel rather than null, so the first
/// station always opens one and the loop has no special first case.
const _noGroup = '';

/// Each lane's band, keyed by the workcenter whose row it is drawn above.
///
/// **The lane is placed by the step it feeds, not by its stored position.**
/// `SimLane.position` is a place on one study's spine, and the chart merges
/// every study into one set of station rows (§7.7) — so a spine position cannot
/// be turned into a row index without the very join to the flow §7.10 forbids.
/// What the run does keep is which lane each step waited in, and `routingRanks`
/// already places the stations; a lane therefore goes directly above the
/// station its own visits were pulled into.
///
/// A lane no step ever names is **dropped rather than guessed at**. It means no
/// order passed that point, so the run holds nothing that says where it sat.
/// Drawing it at an invented position would put a band between two stations it
/// may never have joined, which is worse than a chart that shows only the
/// buffers the run can actually place.
///
/// **Keyed by the group a lane feeds, and a group can have several.** A lane
/// feeds a *step*, and a step may target a pool — so the band belongs above the
/// pool's header rather than above whichever member happened to pull the first
/// order out of it, which is what made one machine look detached from its
/// siblings.
///
/// And the value is a list, because two studies can both step on one pool with
/// a lane of their own in front (§7.7). This was a `Map<String, GanttLaneRow>`
/// keyed by workcenter, so the second lane silently overwrote the first and one
/// FIFO band vanished from the chart with nothing on screen saying so — the
/// defect the field reported as *"CLAD07 out of the CAL pool with two FIFOs"*.
Map<String, List<GanttLaneRow>> _laneRows({
  required SimRunResult result,
  required Map<String, GanttPart> partsById,
  required Map<String, SimOrderOutcome> ordersById,
  required Map<String, String> groupOf,
  required Map<String, String> poolNameOf,
}) {
  if (result.lanes.isEmpty) return const {};

  final laneById = {for (final lane in result.lanes) lane.nodeId: lane};

  // Where each lane's orders went next, and every stay in it.
  final feeds = <String, String>{};
  final stays =
      <String, List<({DateTime from, DateTime to, String orderId, bool open})>>{};

  for (final step in result.steps) {
    final laneId = step.laneNodeId;
    if (laneId == null || !laneById.containsKey(laneId)) continue;
    // The group rather than the machine. Every step out of one lane feeds one
    // step of one study, so its candidates are one pool or one station — the
    // group is the same whichever member happened to take this order, which is
    // what makes `putIfAbsent` safe here where taking the first workcenter was
    // not.
    feeds.putIfAbsent(
      laneId,
      () => groupOf[step.workcenterId] ?? step.workcenterId,
    );
    stays
        .putIfAbsent(laneId, () => [])
        .add((
          from: step.queueStart,
          to: step.processStart,
          orderId: step.orderId,
          open: false,
        ));
  }

  // Orders the guard caught mid-wait leave no step, and dropping them would
  // draw the lane emptiest exactly when a jam is the finding.
  for (final open in result.openLaneVisits) {
    if (!laneById.containsKey(open.laneNodeId)) continue;
    stays
        .putIfAbsent(open.laneNodeId, () => [])
        .add((
          from: open.enteredAt,
          to: result.end,
          orderId: open.orderId,
          open: true,
        ));
  }

  final rows = <String, List<GanttLaneRow>>{};
  // In lane-node order, so two studies' bands above one pool are stacked the
  // same way twice running rather than following whatever order the steps
  // happened to arrive in.
  final byGroup = feeds.entries.toList()
    ..sort((a, b) {
      final byTarget = a.value.compareTo(b.value);
      return byTarget != 0 ? byTarget : a.key.compareTo(b.key);
    });
  for (final entry in byGroup) {
    final lane = laneById[entry.key]!;
    final held = stays[entry.key] ?? const [];

    final visits = _stackVisits(
      held,
      lane: lane,
      partsById: partsById,
      ordersById: ordersById,
    );

    // An uncapped lane's depth is how full it actually got — an observation,
    // which §5.5 is careful to say is not a rule. A capped one is drawn at its
    // capacity whether or not it ever filled, because the empty slots are the
    // headroom and hiding them would make every capped lane look full.
    final deepest = visits.fold(0, (most, v) => v.slot + 1 > most ? v.slot + 1 : most);
    final wanted = lane.capacity ?? deepest;
    final depth = wanted.clamp(1, GanttMetrics.maxLaneDepth);

    // Appended rather than assigned: a group fed by two lanes keeps both.
    rows.putIfAbsent(entry.value, () => []).add(
      GanttLaneRow(
        laneNodeId: lane.nodeId,
        name: lane.name ?? _unnamedLane,
        poolName: poolNameOf[entry.value],
        capacity: lane.capacity,
        depth: depth,
        visits: visits,
      ),
    );
  }
  return rows;
}

/// A buffer that was never labelled. Named rather than blank, so the frozen
/// label column does not have a nameless band in it.
const _unnamedLane = 'Buffer';

/// Assigns each stay the topmost slot no overlapping stay is using.
///
/// The classic greedy pass over intervals sorted by arrival: a lane holding
/// three orders at once uses three slots, and one holding them one after
/// another re-uses the first. A capped lane can never need more slots than its
/// capacity, because the engine did not let more in — so the stack fits the
/// band by construction rather than by clamping, and a slot past the drawn
/// depth means an **uncapped** lane deeper than [GanttMetrics.maxLaneDepth].
List<GanttLaneVisit> _stackVisits(
  List<({DateTime from, DateTime to, String orderId, bool open})> stays, {
  required SimLane lane,
  required Map<String, GanttPart> partsById,
  required Map<String, SimOrderOutcome> ordersById,
}) {
  final sorted = [...stays]..sort((a, b) {
    final byArrival = a.from.compareTo(b.from);
    return byArrival != 0 ? byArrival : a.orderId.compareTo(b.orderId);
  });

  // When each slot next falls free.
  final freeAt = <DateTime>[];
  final visits = <GanttLaneVisit>[];

  for (final stay in sorted) {
    final outcome = ordersById[stay.orderId];
    final part = outcome == null ? null : partsById[outcome.partId];
    if (outcome == null || part == null) continue;

    var slot = freeAt.indexWhere((free) => !free.isAfter(stay.from));
    if (slot < 0) {
      slot = freeAt.length;
      freeAt.add(stay.to);
    } else {
      freeAt[slot] = stay.to;
    }

    visits.add(
      GanttLaneVisit(
        orderId: stay.orderId,
        orderNumber: outcome.sequence + 1,
        studyId: lane.studyId,
        part: part,
        entered: stay.from,
        left: stay.to,
        slot: slot,
        open: stay.open,
      ),
    );
  }
  return visits;
}

/// A station nothing routed through, which sorts last.
const _unrouted = 1 << 30;

/// Where each station sits in the flow, as the run itself reveals it.
///
/// **The run stores no node positions.** §7.10's rule is that a run joins to
/// nothing, so `simulation_run_steps` keeps a node id and a workcenter id but
/// not the order the flow put them in — and the flow it was made from may have
/// been edited since. What the run *does* keep is every step of every order,
/// and §5.1 makes a study's topology a linear spine: one order visits its
/// stations in exactly the routing's order, so the order it visited them in is
/// the routing. Sorted by [SimOrderStep.queueStart], which is when the order
/// arrived rather than when it got served, so a station that made it wait does
/// not float up the list.
///
/// A station takes the **earliest** position it holds in any order's routing.
/// It matters for a run spanning two studies, where one line's third station is
/// another's first: there is one row for it either way (§7.7 builds one model
/// of the plant), so the chart has to choose, and choosing the earliest keeps
/// every routing readable top to bottom without any of them running backwards
/// more than it has to.
Map<String, int> routingRanks(SimRunResult result) {
  final byOrder = <String, List<SimOrderStep>>{};
  for (final step in result.steps) {
    byOrder.putIfAbsent(step.orderId, () => []).add(step);
  }

  final earliest = <String, int>{};
  for (final steps in byOrder.values) {
    steps.sort((a, b) => a.queueStart.compareTo(b.queueStart));
    for (var position = 0; position < steps.length; position++) {
      final id = steps[position].workcenterId;
      final known = earliest[id];
      if (known == null || position < known) earliest[id] = position;
    }
  }

  return earliest;
}

/// Something the pointer can be over: a station's bar or an order waiting in a
/// lane. Both answer [barAt], and the hover card asks which it got.
sealed class GanttHit {
  const GanttHit();

  Rect get rect;

  /// Which band it belongs to. **Carried rather than derived**: bands are no
  /// longer a uniform height, so `(top − axisHeight) ÷ rowHeight` stopped being
  /// able to answer it the moment lanes arrived.
  int get bandIndex;
}

/// A bar, placed.
class GanttPlacedBar extends GanttHit {
  const GanttPlacedBar({
    required this.bar,
    required this.rect,
    required this.floored,
    required this.bandIndex,
  });

  final GanttBar bar;

  @override
  final Rect rect;

  @override
  final int bandIndex;

  /// Whether [rect] is wider than the bar really is, because the bar would
  /// otherwise have been thinner than [GanttMetrics.minBarWidth].
  final bool floored;

  /// Whether there is room to mark the changeover on the leading edge (§7.6).
  bool get showsChangeover =>
      bar.changeover && rect.width >= GanttMetrics.changeoverBarWidth;
}

/// An order waiting in a lane, placed.
class GanttPlacedVisit extends GanttHit {
  const GanttPlacedVisit({
    required this.visit,
    required this.lane,
    required this.rect,
    required this.bandIndex,
  });

  final GanttLaneVisit visit;

  /// The lane it is standing in, so the hover card can name it and say how deep
  /// it was without a second lookup.
  final GanttLaneRow lane;

  @override
  final Rect rect;

  @override
  final int bandIndex;
}

/// A band, placed.
class GanttRowLayout {
  const GanttRowLayout({
    required this.band,
    required this.top,
    this.bars = const [],
    this.visits = const [],
  });

  final GanttBand band;

  /// The top of the band, which is [GanttBand.height] tall.
  final double top;

  /// Populated for a station band.
  final List<GanttPlacedBar> bars;

  /// Populated for a lane band.
  final List<GanttPlacedVisit> visits;
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

  double xOf(DateTime at) =>
      at.difference(origin).inSeconds * pixelsPerSecond;

  // Bands are stacked by accumulating their own heights rather than by
  // multiplying an index, because a lane is as deep as the lane is (§8.6).
  final rows = <GanttRowLayout>[];
  var top = GanttMetrics.axisHeight;

  for (var i = 0; i < chart.rows.length; i++) {
    final band = chart.rows[i];

    switch (band) {
      case GanttRow():
        double barTopFor(int slot) =>
            top +
            slot * GanttMetrics.rowHeight +
            (GanttMetrics.rowHeight - GanttMetrics.barHeight) / 2;
        final placed = <GanttPlacedBar>[];
        for (final bar in band.bars) {
          final barTop = barTopFor(bar.slot);
          final width = bar.occupied.inSeconds * pixelsPerSecond;
          final isFloored = width < GanttMetrics.minBarWidth;
          if (isFloored) floored++;
          placed.add(
            GanttPlacedBar(
              bar: bar,
              rect: Rect.fromLTWH(
                xOf(bar.start),
                barTop,
                isFloored ? GanttMetrics.minBarWidth : width,
                GanttMetrics.barHeight,
              ),
              floored: isFloored,
              bandIndex: i,
            ),
          );
        }
        rows.add(GanttRowLayout(band: band, top: top, bars: placed));

      case GanttLaneRow():
        final placed = <GanttPlacedVisit>[];
        for (final visit in band.visits) {
          // A stay deeper than the band is drawn in the last slot rather than
          // outside it. Only an uncapped lane past `maxLaneDepth` gets here.
          final slot = visit.slot >= band.depth ? band.depth - 1 : visit.slot;
          final left = xOf(visit.entered);
          final width = visit.waited.inSeconds * pixelsPerSecond;
          placed.add(
            GanttPlacedVisit(
              visit: visit,
              lane: band,
              rect: Rect.fromLTWH(
                left,
                top +
                    GanttMetrics.lanePadding +
                    slot * GanttMetrics.laneSlotHeight,
                // The same floor the bars get, and for the same reason: a wait
                // of a few hours at whole-run scale is otherwise not there at
                // all, and an empty lane is precisely the wrong thing to say
                // about a queue.
                width < GanttMetrics.minBarWidth
                    ? GanttMetrics.minBarWidth
                    : width,
                GanttMetrics.laneBarHeight,
              ),
              bandIndex: i,
            ),
          );
        }
        rows.add(GanttRowLayout(band: band, top: top, visits: placed));

    }

    top += band.height;
  }

  return GanttLayout(
    chart: chart,
    pixelsPerSecond: pixelsPerSecond,
    rows: rows,
    unit: ganttTickUnit(pixelsPerSecond),
    flooredBars: floored,
    size: Size(
      chart.span.inSeconds * pixelsPerSecond,
      top + GanttMetrics.scrollbarGutter,
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
///
/// **A lane band is picked by slot, not as one strip.** Its stays do not tile —
/// that is the whole point of stacking them — so two orders waiting at once are
/// only distinguishable by which slot the pointer is in. The band is scanned
/// for the row under the pointer and then along it, which is the station rule
/// applied one level down.
GanttHit? barAt(GanttLayout layout, Offset position) {
  if (position.dy < GanttMetrics.axisHeight) return null;

  for (final row in layout.rows) {
    if (position.dy < row.top) continue;
    if (position.dy >= row.top + row.band.height) continue;

    switch (row.band) {
      case GanttRow():
        // By sub-row first, for the same reason a lane is picked by slot: two
        // units running at once are only told apart by which one the pointer
        // is over. A one-unit station has a single sub-row and this is the
        // whole band, exactly as it was.
        final slot = ((position.dy - row.top) / GanttMetrics.rowHeight).floor();
        for (final placed in row.bars) {
          if (placed.bar.slot != slot) continue;
          if (position.dx >= placed.rect.left &&
              position.dx <= placed.rect.right) {
            return placed;
          }
        }
      case GanttLaneRow():
        final slot =
            ((position.dy - row.top - GanttMetrics.lanePadding) /
                    GanttMetrics.laneSlotHeight)
                .floor();
        for (final placed in row.visits) {
          final drawn =
              ((placed.rect.top - row.top - GanttMetrics.lanePadding) /
                      GanttMetrics.laneSlotHeight)
                  .round();
          if (drawn != slot) continue;
          if (position.dx >= placed.rect.left &&
              position.dx <= placed.rect.right) {
            return placed;
          }
        }

    }
    return null;
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
