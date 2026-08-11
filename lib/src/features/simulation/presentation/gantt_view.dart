/// The Gantt (DESIGN.md §8.6).
///
/// Y is the workcenter, X is time, the bars are orders — one chart for the whole
/// run, all studies together, because a station is shared and splitting per
/// study would draw it idle during hours it was running another line's order.
///
/// **Everything geometric is in `gantt_layout.dart`** and nothing here decides a
/// position: this reads the layout, paints it, and hands the pointer back to
/// `barAt`. That is what keeps the rects the hover picks against identical to
/// the rects that were drawn, and it is why the zoom bounds, the tick unit and
/// the 2 px floor are all asserted without a frame.
///
/// **The chart is a real scroll view, not drag-to-pan.** §12.6's rule is that a
/// wide thing must scroll *and say so*; a bare drag re-creates the complaint
/// that rule exists to answer, because nothing on screen would say how much run
/// is off either edge. The window start is therefore the scroll offset rather
/// than a second piece of state that could disagree with it.
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// `DateFormat` only: `intl` also exports a `TextDirection`, which would shadow
// the one the painter's `TextPainter` needs.
import 'package:intl/intl.dart' show DateFormat;

import '../../../common/date_input.dart';
import '../../../common/formatters.dart';
import '../../../common/horizontal_scroll.dart';
import '../../../common/part_palette.dart';
import '../../../common/unit_labels.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/gantt_layout.dart';
import '../data/simulation_runs_repository.dart';

/// The frozen left column carrying the station names.
///
/// Outside the horizontal scroll view, so the row a bar belongs to is readable
/// however far into the run the reader has scrolled — the answer `DataGrid`
/// already gives its row header (§12.6).
const _labelWidth = 168.0;

/// The hover card's size. The height is used only to keep the card inside the
/// pane; being a few pixels out puts it somewhere slightly less convenient,
/// never off screen.
const _cardWidth = 300.0;
const _cardHeight = 132.0;

/// The narrowest bar that can carry its own part number.
const _labelledBarWidth = 46.0;

/// The painted chart itself, so a test can put a pointer on a known bar.
///
/// The bars are painted rather than built, which is the point — 20 000 of them
/// at §14 scale — so there is no widget under the cursor for a finder to reach.
/// The key gives a test the canvas's origin; `layoutGantt` gives it the rect.
@visibleForTesting
const ganttCanvasKey = ValueKey('gantt-canvas');

class GanttView extends StatefulWidget {
  const GanttView({super.key, required this.run});

  final StoredRun run;

  @override
  State<GanttView> createState() => _GanttViewState();
}

class _GanttViewState extends State<GanttView> {
  final _across = ScrollController();
  final _down = ScrollController();

  late GanttChart _chart;

  /// Null until the first layout knows how wide the pane is, and reset by a new
  /// run: **fitted once per run**, and thereafter the reader's.
  ///
  /// Unlike the canvas (§12.2) there is no refit rule, because a time axis has
  /// an intrinsic scale where a map has none: a wider pane keeps its pixels per
  /// second and shows more of the run. What a resize *can* do is move the floor,
  /// since the floor is the whole run across the pane, and the clamp in
  /// [_effectiveScale] is what enforces that.
  double? _scale;

  /// The bar under the pointer, if any. One at a time and no widget per bar: a
  /// `Tooltip` carries a fixed message, so naming the bar under the cursor that
  /// way would mean 231 widgets on the real run and 20 000 at §14 scale.
  GanttPlacedBar? _hovered;

  GanttLayout? _cached;

  @override
  void initState() {
    super.initState();
    _chart = _buildChart();
  }

  @override
  void didUpdateWidget(GanttView old) {
    super.didUpdateWidget(old);
    if (old.run.id == widget.run.id) return;
    // A different run is a different chart, a different fit, and nothing under
    // the pointer.
    _chart = _buildChart();
    _cached = null;
    _scale = null;
    _hovered = null;
    if (_across.hasClients) _across.jumpTo(0);
    if (_down.hasClients) _down.jumpTo(0);
  }

  @override
  void dispose() {
    _across.dispose();
    _down.dispose();
    super.dispose();
  }

  GanttChart _buildChart() =>
      buildGanttChart(result: widget.run.result, metrics: widget.run.metrics);

  /// The layout at [scale], remembered so that scrolling does not re-measure
  /// every bar in the run on every frame. A cache of a pure function of state
  /// already held, not a second copy of that state.
  GanttLayout _layoutAt(double scale) {
    final cached = _cached;
    if (cached != null && cached.pixelsPerSecond == scale) return cached;
    return _cached = layoutGantt(chart: _chart, pixelsPerSecond: scale);
  }

  double _effectiveScale(double pane) => clampGanttScale(
    _scale ?? ganttScaleBounds(span: _chart.span, paneWidth: pane).min,
    span: _chart.span,
    paneWidth: pane,
  );

  /// Zooms, holding one point of the pane still.
  ///
  /// [anchor] is where in the pane to hold, measured from its left edge; the
  /// centre when nothing says otherwise. Whatever instant is under that point
  /// is still under it afterwards, which is the only way a zoom into a
  /// sixteen-million-pixel run lands anywhere near what the reader was looking
  /// at. It is also why `HorizontalScroll` takes a controller: the window start
  /// *is* the offset, so moving the window means moving it.
  ///
  /// The buttons hold the centre, because a button press says nothing about
  /// where on the chart the reader's attention is. Ctrl-scroll holds the
  /// **pointer**, because it says exactly that.
  void _zoom(double factor, double pane, {double? anchor}) {
    final current = _effectiveScale(pane);
    final next = clampGanttScale(
      current * factor,
      span: _chart.span,
      paneWidth: pane,
    );
    if (next == current) return;

    final hold = anchor ?? pane / 2;
    final offset = _across.hasClients ? _across.offset : 0.0;
    final seconds = (offset + hold) / current;

    setState(() {
      _scale = next;
      // The rect it points into is about to be replaced.
      _hovered = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_across.hasClients) return;
      final target = seconds * next - hold;
      _across.jumpTo(target.clamp(0.0, _across.position.maxScrollExtent));
    });
  }

  /// One notch of ctrl-scroll, anchored on the pointer.
  ///
  /// A gentler step than the buttons' ×2 on purpose: a press is expensive and
  /// has to cross four orders of magnitude in ten of them, while a notch is
  /// cheap and a reader spins several without thinking about it. ×2 a notch
  /// overshoots whatever they were aiming at.
  static const _wheelStep = 1.25;

  void _zoomAtPointer(PointerScrollEvent event, double pane) {
    // `localPosition` is in the canvas's own coordinates, which are the
    // content's, so subtracting the offset gives the point in the pane.
    final offset = _across.hasClients ? _across.offset : 0.0;
    _zoom(
      event.scrollDelta.dy < 0 ? _wheelStep : 1 / _wheelStep,
      pane,
      anchor: (event.localPosition.dx - offset).clamp(0.0, pane),
    );
  }

  /// The names the studies had when the run was made (§7.10), so a study
  /// renamed since still reads as the one that ran — the map `_PartsTable` and
  /// `_ProductionPlan` build for the same reason.
  Map<String, String> get _studyNames => {
    for (final study in widget.run.studies) study.studyId: study.name,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_chart.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.simGanttEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final pane = math.max(constraints.maxWidth - _labelWidth, 1.0);
        final scale = _effectiveScale(pane);
        final layout = _layoutAt(scale);
        final bounds = ganttScaleBounds(span: _chart.span, paneWidth: pane);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              // Said rather than left to be inferred: a gap is a station not
              // running, and this chart cannot tell closed from starved.
              // Splitting a bar at closed time would need calendars a stored
              // run does not have (§7.10).
              child: Text(
                l10n.simGanttGapHelp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            Expanded(
              child: _Chart(
                layout: layout,
                across: _across,
                down: _down,
                pane: pane,
                hovered: _hovered,
                onHover: (bar) => setState(() => _hovered = bar),
                onCtrlScroll: (event) => _zoomAtPointer(event, pane),
                studies: _studyNames,
              ),
            ),
            const Divider(height: 1),
            _Footer(
              chart: _chart,
              studies: _studyNames,
              flooredBars: layout.flooredBars,
              canZoomOut: scale > bounds.min,
              canZoomIn: scale < bounds.max,
              onZoomOut: () => _zoom(1 / GanttMetrics.zoomStep, pane),
              onZoomIn: () => _zoom(GanttMetrics.zoomStep, pane),
            ),
          ],
        );
      },
    );
  }
}

/// The frozen labels, the scrolled canvas, and the card over both.
class _Chart extends StatelessWidget {
  const _Chart({
    required this.layout,
    required this.across,
    required this.down,
    required this.pane,
    required this.hovered,
    required this.onHover,
    required this.onCtrlScroll,
    required this.studies,
  });

  final GanttLayout layout;
  final ScrollController across;
  final ScrollController down;
  final double pane;
  final GanttPlacedBar? hovered;
  final ValueChanged<GanttPlacedBar?> onHover;
  final ValueChanged<PointerScrollEvent> onCtrlScroll;
  final Map<String, String> studies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        // The axis and the culling both need to know which slice of the run is
        // on screen, and the offset is the only thing that says. Rebuilding on
        // it is what makes "only the visible ticks are built" true at run time
        // rather than merely available.
        animation: Listenable.merge([across, down]),
        builder: (context, _) {
          final offset = across.hasClients ? across.offset : 0.0;
          final scrolledDown = down.hasClients ? down.offset : 0.0;
          final ticks = [
            for (final tick in ganttTicks(
              layout,
              from: offset,
              to: offset + pane,
            ))
              (x: tick.x, label: _tickLabel(layout.unit, tick.at, locale)),
          ];

          return Stack(
            children: [
              SingleChildScrollView(
                controller: down,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Labels(layout: layout),
                    Expanded(
                      child: HorizontalScroll(
                        controller: across,
                        child: SizedBox(
                          // Never narrower than the pane: at the floor the two
                          // are the same number bar a rounding error, and a
                          // scrollbar over nothing to scroll is worse than none.
                          width: math.max(layout.size.width, pane),
                          height: layout.size.height,
                          child: MouseRegion(
                            onHover: (event) {
                              final hit = barAt(layout, event.localPosition);
                              // A lane's waiting order is drawn and picked, but
                              // the card that would describe it is not built
                              // yet — so it reports nothing rather than putting
                              // a station's card over the wrong subject.
                              final next = hit is GanttPlacedBar ? hit : null;
                              if (!identical(next, hovered)) onHover(next);
                            },
                            onExit: (_) => onHover(null),
                            child: _CtrlScroll(
                              onZoom: onCtrlScroll,
                              child: CustomPaint(
                                key: ganttCanvasKey,
                                painter: _GanttPainter(
                                  layout: layout,
                                  ticks: ticks,
                                  visibleFrom: offset,
                                  visibleTo: offset + pane,
                                  hovered: hovered,
                                  band: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.04,
                                  ),
                                  rule: theme.colorScheme.outlineVariant,
                                  axisStyle:
                                      theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ) ??
                                      const TextStyle(fontSize: 12),
                                  outline: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hovered case final bar?)
                _HoverCard(
                  bar: bar,
                  bandTop: layout.rows[bar.bandIndex].top,
                  across: offset,
                  down: scrolledDown,
                  pane: pane,
                  paneHeight: constraints.maxHeight,
                  studies: studies,
                  station: _stationOf(layout, bar),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Which band the hit was placed on.
  ///
  /// This used to divide the index back out of the rect's top, which worked
  /// while every band was `rowHeight` tall. Lane bands are as deep as the lane
  /// is (§8.6), so the index is carried on the hit instead — the layout knows
  /// it for nothing and no arithmetic can drift from it.
  static String _stationOf(GanttLayout layout, GanttHit hit) =>
      hit.bandIndex < layout.rows.length
      ? layout.rows[hit.bandIndex].band.name
      : '';
}

/// Turns ctrl-scroll over the chart into a zoom, and leaves every other scroll
/// alone.
///
/// **A plain wheel is not touched**, which is §12.6's standing rule: hijacking
/// it would strand the vertical scroll this chart sits in, and park the pointer
/// over a tall chart and the page below could never be reached. Ctrl-scroll is
/// not that gesture — nothing else in the app claims it, and it is what every
/// other timeline a planner uses is zoomed with.
///
/// It has to be **inside** the two scroll views rather than wrapping them.
/// `PointerSignalResolver` gives the event to whoever registers first, and
/// registration runs from the innermost hit target outwards — an ancestor would
/// lose to the `Scrollable` beneath it and the chart would pan while it zoomed.
/// Registering is also what stops the scroll views from acting on the same
/// notch: exactly one handler wins.
class _CtrlScroll extends StatelessWidget {
  const _CtrlScroll({required this.onZoom, required this.child});

  final ValueChanged<PointerScrollEvent> onZoom;
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: (event) {
      if (event is! PointerScrollEvent) return;
      if (!HardwareKeyboard.instance.isControlPressed) return;
      GestureBinding.instance.pointerSignalResolver.register(
        event,
        (resolved) => onZoom(resolved as PointerScrollEvent),
      );
    },
    child: child,
  );
}

/// The station and lane names, one per band, aligned to the bands beside them.
class _Labels extends StatelessWidget {
  const _Labels({required this.layout});

  final GanttLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: _labelWidth,
      height: layout.size.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stands in for the axis strip, so row 0's label lines up with row
          // 0's band rather than with the dates above it.
          const SizedBox(height: GanttMetrics.axisHeight),
          for (final row in layout.rows)
            SizedBox(
              height: row.band.height,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Tooltip(
                    message: switch (row.band) {
                      // The capacity is on the label rather than only implied
                      // by the band's depth, so a lane drawn shallower than it
                      // is (§8.6's cap) still says how deep it really was.
                      final GanttLaneRow lane when lane.capacity != null =>
                        '${lane.name} (${lane.capacity})',
                      final band => band.name,
                    },
                    child: Text(
                      row.band.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: switch (row.band) {
                        // A lane is not a station, and the label column is
                        // where that reads most cheaply: same size, lighter.
                        GanttLaneRow() => theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        GanttRow() => theme.textTheme.bodySmall,
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The legend, the floor note and the zoom cluster.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.chart,
    required this.studies,
    required this.flooredBars,
    required this.canZoomOut,
    required this.canZoomIn,
    required this.onZoomOut,
    required this.onZoomIn,
  });

  final GanttChart chart;
  final Map<String, String> studies;
  final int flooredBars;
  final bool canZoomOut;
  final bool canZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The rule the Parts table's Study column follows (§8.1.2): a part number
    // identifies a part only inside its study, and on a one-study run every
    // entry would carry the same answer.
    final showStudy = studies.length > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final part in chart.parts)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _LegendEntry(
                        part: part,
                        study: showStudy ? studies[part.studyId] : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Only while it is true. A permanent note would be a lie at the
          // ceiling, where every bar is drawn to scale.
          if (flooredBars > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Tooltip(
                message: l10n.simGanttFlooredHelp,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.simGanttFloored(flooredBars),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: l10n.simGanttZoomOut,
            // Dead at the floor, which is the whole run: there is nothing past
            // it to show.
            onPressed: canZoomOut ? onZoomOut : null,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: l10n.simGanttZoomIn,
            onPressed: canZoomIn ? onZoomIn : null,
          ),
        ],
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.part, required this.study});

  final GanttPart part;
  final String? study;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: partColour(part.colourIndex).fill,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          study == null ? part.partNumber : '${part.partNumber} · $study',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// What the bar under the pointer is.
///
/// **One widget rather than one per bar**, which is the whole objection to a
/// `Tooltip` here — and being a widget rather than a painted box keeps its text
/// localized, themed and findable by a test.
///
/// Anchored to the bar rather than followed to the cursor: it moves only when
/// the answer changes, and a card that jitters under the pointer is harder to
/// read than one sitting still beside what it describes. `IgnorePointer` is what
/// stops it from taking the hover away from the bar it is describing.
class _HoverCard extends StatelessWidget {
  const _HoverCard({
    required this.bar,
    required this.bandTop,
    required this.across,
    required this.down,
    required this.pane,
    required this.paneHeight,
    required this.studies,
    required this.station,
  });

  final GanttPlacedBar bar;

  /// The top of the band the bar sits in, so the card can be put under it
  /// without assuming every band is the same height.
  final double bandTop;

  final double across;
  final double down;
  final double pane;
  final double paneHeight;
  final Map<String, String> studies;
  final String station;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

    // The band's own top, carried on the hit. It used to be divided back out
    // of the rect, which held only while every band was `rowHeight` tall.
    final rowTop = bandTop;
    final left = (_labelWidth + bar.rect.left - across)
        .clamp(
          _labelWidth + 4,
          math.max(_labelWidth + 4, _labelWidth + pane - _cardWidth - 4),
        )
        .toDouble();
    final top = (rowTop + GanttMetrics.rowHeight + 6 - down)
        .clamp(0.0, math.max(0.0, paneHeight - _cardHeight))
        .toDouble();

    String instant(DateTime value) =>
        '${formatDateInput(value, locale)} '
        '${formatMinuteOfDay(value.hour * 60 + value.minute)}';

    final study = studies.length > 1
        ? studies[bar.bar.studyId] ?? bar.bar.studyId
        : null;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: SizedBox(
          width: _cardWidth,
          child: Card(
            elevation: 6,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: partColour(bar.bar.part.colourIndex).fill,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l10n.simGanttOrder('${bar.bar.orderNumber}')}'
                          '  ·  ${bar.bar.part.partNumber}',
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _CardLine(
                    text: study == null ? station : '$station  ·  $study',
                  ),
                  _CardLine(
                    text: l10n.simRunSpan(
                      instant(bar.bar.start),
                      instant(bar.bar.end),
                    ),
                  ),
                  _CardValue(
                    label: l10n.simGanttCommitted,
                    value: formatAdaptiveDuration(l10n, bar.bar.occupied),
                  ),
                  _CardValue(
                    label: l10n.simGanttWaited,
                    value: formatAdaptiveDuration(l10n, bar.bar.wait),
                  ),
                  // Said at every scale, including the zooms where the mark on
                  // the bar itself is omitted for want of room.
                  if (bar.bar.changeover)
                    _CardLine(text: l10n.simGanttChangeover),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _CardValue extends StatelessWidget {
  const _CardValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(color: theme.colorScheme.outline),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// The tick's own label, which has to stand alone: `Jan 14`, not `14`.
///
/// §12.4's split — a date follows the locale, a clock reading is 24-hour
/// everywhere, because a shift boundary is a number the plant has written on a
/// board.
String _tickLabel(GanttTickUnit unit, DateTime at, String locale) =>
    switch (unit) {
      GanttTickUnit.hour => formatMinuteOfDay(at.hour * 60 + at.minute),
      GanttTickUnit.day ||
      GanttTickUnit.week => DateFormat.MMMd(locale).format(at),
      GanttTickUnit.month ||
      GanttTickUnit.quarter => DateFormat.yMMM(locale).format(at),
      GanttTickUnit.year => DateFormat.y(locale).format(at),
    };

/// Draws what the layout decided, and decides nothing itself.
class _GanttPainter extends CustomPainter {
  const _GanttPainter({
    required this.layout,
    required this.ticks,
    required this.visibleFrom,
    required this.visibleTo,
    required this.hovered,
    required this.band,
    required this.rule,
    required this.axisStyle,
    required this.outline,
  });

  final GanttLayout layout;
  final List<({double x, String label})> ticks;

  /// The slice of the content on screen. Everything outside it is skipped: at
  /// §14 scale a run carries 20 000 bars and at most a screenful can be seen.
  final double visibleFrom;
  final double visibleTo;

  final GanttPlacedBar? hovered;
  final Color band;
  final Color rule;
  final TextStyle axisStyle;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final bandPaint = Paint()..color = band;
    final rulePaint = Paint()
      ..color = rule
      ..strokeWidth = 1;

    // Alternate bands, so a bar hours away from its label still reads as that
    // row's. Counted over **stations only**: the lanes between them get a fill
    // of their own below, and striping the merged sequence would put the
    // stripe on a lane half the time and break the alternation a reader is
    // using to follow one station across.
    var stations = 0;
    for (final row in layout.rows) {
      switch (row.band) {
        case GanttRow():
          if (stations.isOdd) {
            canvas.drawRect(
              Rect.fromLTWH(0, row.top, size.width, row.band.height),
              bandPaint,
            );
          }
          stations++;

        case GanttLaneRow():
          // A lane is a channel, and the map draws it as one (§2.5): a fill
          // between two rails, so the band reads as somewhere orders stand
          // rather than as another machine.
          canvas.drawRect(
            Rect.fromLTWH(0, row.top, size.width, row.band.height),
            bandPaint,
          );
          for (final y in [row.top, row.top + row.band.height]) {
            canvas.drawLine(
              Offset(visibleFrom, y),
              Offset(visibleTo, y),
              rulePaint,
            );
          }
      }
    }

    // Down to the last row and no further: below it is the gutter the
    // horizontal scrollbar sits in, and a grid drawn behind a scrollbar reads
    // as part of the chart.
    final floor = size.height - GanttMetrics.scrollbarGutter;
    for (final tick in ticks) {
      canvas.drawLine(
        Offset(tick.x, GanttMetrics.axisHeight),
        Offset(tick.x, floor),
        rulePaint,
      );
      _text(canvas, tick.label, Offset(tick.x + 4, 5), axisStyle);
    }

    canvas.drawLine(
      Offset(visibleFrom, GanttMetrics.axisHeight),
      Offset(visibleTo, GanttMetrics.axisHeight),
      rulePaint,
    );

    // The waiting orders, under the bars so a station's work always wins the
    // pixel where the two meet.
    for (final row in layout.rows) {
      for (final placed in row.visits) {
        if (placed.rect.right < visibleFrom || placed.rect.left > visibleTo) {
          continue;
        }
        final colour = partColour(placed.visit.part.colourIndex);
        final shape = RRect.fromRectAndRadius(
          placed.rect,
          const Radius.circular(1),
        );
        // **Washed out and outlined, never solid.** The same part colour, so an
        // order is followed down the chart by hue, but a waiting order must not
        // read as a running one — which is the whole reason §2.7 refused to
        // draw queue spans on a station's own row.
        canvas.drawRRect(
          shape,
          Paint()..color = colour.fill.withValues(alpha: 0.30),
        );
        canvas.drawRRect(
          shape,
          Paint()
            ..color = colour.fill
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }

    for (final row in layout.rows) {
      for (final placed in row.bars) {
        if (placed.rect.right < visibleFrom || placed.rect.left > visibleTo) {
          continue;
        }
        final colour = partColour(placed.bar.part.colourIndex);
        final shape = RRect.fromRectAndRadius(
          placed.rect,
          const Radius.circular(2),
        );
        canvas.drawRRect(shape, Paint()..color = colour.fill);

        // A stroke, never a prefix with a width: the run stores only *that* a
        // changeover was paid, so anything measurable against the axis would be
        // an invention (§7.6).
        if (placed.showsChangeover) {
          canvas.drawRect(
            Rect.fromLTWH(
              placed.rect.left,
              placed.rect.top,
              2,
              placed.rect.height,
            ),
            Paint()..color = colour.onFill,
          );
        }

        if (placed.rect.width >= _labelledBarWidth) {
          _text(
            canvas,
            placed.bar.part.partNumber,
            Offset(placed.rect.left + 6, placed.rect.top + 2),
            axisStyle.copyWith(color: colour.onFill),
            maxWidth: placed.rect.width - 10,
          );
        }

        if (identical(placed, hovered)) {
          canvas.drawRRect(
            shape,
            Paint()
              ..color = outline
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset at,
    TextStyle style, {
    double? maxWidth,
  }) {
    TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )
      ..layout(maxWidth: maxWidth ?? double.infinity)
      ..paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _GanttPainter old) =>
      old.layout != layout ||
      old.ticks != ticks ||
      old.visibleFrom != visibleFrom ||
      old.visibleTo != visibleTo ||
      !identical(old.hovered, hovered) ||
      old.band != band ||
      old.rule != rule ||
      old.outline != outline;
}
