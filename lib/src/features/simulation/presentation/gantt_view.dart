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

import '../../../common/date_style_scope.dart';
import '../../../common/formatters.dart';
import '../../../common/horizontal_scroll.dart';
import '../../../common/part_palette.dart';
import '../../../common/unit_labels.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/gantt_layout.dart';
import '../application/run_filter.dart';
import '../data/simulation_runs_repository.dart';

/// The frozen left column carrying the station names.
///
/// Outside the horizontal scroll view, so the row a bar belongs to is readable
/// however far into the run the reader has scrolled — the answer `DataGrid`
/// already gives its row header (§12.6).
///
/// **It is measured, not fixed.** A row's label is `pool · name` since the
/// heading band went away, and a pool name is free text: the real plant's is
/// `CLAD Pool - Célula 11B/C`, which at 168 px filled the column by itself and
/// ellipsised away the machine name on every row of the pool. Five rows then
/// read identically and the one word distinguishing them was the one that had
/// been cut. So the column takes the width its widest label actually needs,
/// between these two bounds.
const _labelMinWidth = 168.0;

/// The widest the column may grow.
///
/// A pool name has no length limit, and a column that honoured one would be a
/// chart with no room left for the run. Past this the label ellipsises — and
/// [_LabelText] is careful about *what* it drops.
const _labelMaxWidth = 260.0;

/// The horizontal padding inside the column, which the measurement has to add
/// back. Kept beside the two bounds so the three cannot drift apart.
const _labelPaddingLeft = 12.0;
const _labelPaddingRight = 10.0;
const _labelPadding = _labelPaddingLeft + _labelPaddingRight;

/// The hover card's size. The height is used only to keep the card inside the
/// pane; being a few pixels out puts it somewhere slightly less convenient,
/// never off screen.
const _cardWidth = 300.0;

/// Never exact — the card is `mainAxisSize.min` and a lane's lines are not a
/// bar's — so it is the tallest the card gets, and it grew by two lines when
/// the project and the description joined it.
const _cardHeight = 168.0;

/// The narrowest bar that can carry its own part number.
const _labelledBarWidth = 46.0;

/// What a bar fades to while another order is being followed (§7.5).
///
/// Low enough that the followed order is unmistakable at a glance, and high
/// enough that the rest of the plant is still *there* — a reader following one
/// order is asking what it queued behind, and dimming the answer to nothing
/// would remove the context the selection exists to put it in.
const _dimmedBar = 0.16;

/// And what a stay in a lane fades to. Smaller because a stay is already drawn
/// at 0.30 rather than solid, so the same visual step is a smaller number.
const _dimmedVisit = 0.08;

/// The narrowest that can carry the order number after it.
///
/// A part number alone is what a bar has always shown, so the threshold for it
/// is untouched and the order number is strictly additional: a bar between the
/// two widths reads exactly as it did before. `_text` still ellipsizes at the
/// bar's own width, so an unusually long part number cannot push the number
/// past the edge — this decides whether to *offer* it, not whether it fits.
const _numberedBarWidth = 92.0;

/// The painted chart itself, so a test can put a pointer on a known bar.
///
/// The bars are painted rather than built, which is the point — 20 000 of them
/// at §14 scale — so there is no widget under the cursor for a finder to reach.
/// The key gives a test the canvas's origin; `layoutGantt` gives it the rect.
@visibleForTesting
const ganttCanvasKey = ValueKey('gantt-canvas');

/// The frozen label column, so a test can measure the width it settled on.
const ganttLabelsKey = ValueKey('gantt-labels');

/// What the plan knows about an order that the run's steps do not (§8.5).
///
/// A class rather than a record so both fields are named at every use, and so
/// the doc explaining why they are nullable has somewhere to live.
class _OrderFacts {
  const _OrderFacts({this.project, this.description});

  /// The customer project this batch is for — `MANIFOLD`, `Global 23`.
  ///
  /// **The order's, not the part's.** §16.15 moved it off `demand_parts` on the
  /// field's own correction: a part is a part, and the project is what a given
  /// batch of it is for. Null on a run stored before v12, and null for the 11 %
  /// of live orders that simply have none.
  final String? project;

  /// The part's own description — `PWB 10K 1.0`. Null before v13.
  ///
  /// It identifies nothing: two parts legitimately share one, which is why it
  /// is a label on the card rather than anything the chart is keyed by.
  final String? description;
}

class GanttView extends StatefulWidget {
  const GanttView({super.key, required this.slice});

  /// The run as this view of it reads (§12.1). A study's own tab passes its
  /// slice; the combined workspace passes whatever its filters resolved to.
  final FilteredRun slice;

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
  GanttHit? _hovered;

  /// The order the reader is following, or null.
  ///
  /// **An order id, not a hit.** An order is on the chart many times over — one
  /// bar per station it visited and one stay per lane it waited in — and
  /// following it is the whole point, so what is remembered is the order rather
  /// than the bar that was clicked. It is also why this cannot be the order
  /// *number*: that is a position in one study's sequence, so on a two-study run
  /// it names two different orders and would light up both (§7.5).
  String? _selected;

  GanttLayout? _cached;

  /// How wide the frozen label column is for *this* chart's labels.
  ///
  /// **Measured here rather than in `build`, because `build` runs on hover.**
  /// Moving the pointer across the chart sets [_hovered], and re-laying out
  /// thirty `TextPainter`s per mouse-move to reach a number that only changes
  /// with the chart would be paid on every frame of a gesture that cannot
  /// change it.
  double _labelWidth = _labelMinWidth;

  /// What the hover card says about an order beyond what the run's steps do:
  /// the customer project the batch is for, and the part's own description.
  ///
  /// **Read from the plan rather than from the chart**, and deliberately not
  /// carried on `GanttBar`. Neither is ever drawn on a bar — the canvas has room
  /// for a part number and an order number and no more — so putting them
  /// through `buildGanttChart` would push two label fields into a file whose
  /// subject is geometry, and would put `ProductionPlanRow` in front of an
  /// `application/` library that is careful to have no data layer in it.
  ///
  /// Keyed by order, because that is how `run.plan` is keyed and it answers
  /// both: the project belongs to the order, and the description reaches this
  /// map on the same row it is stored on (§8.5).
  late Map<String, _OrderFacts> _facts;

  @override
  void initState() {
    super.initState();
    _chart = _buildChart();
    _facts = _readFacts();
  }

  /// **Nullable all the way down, and never invented.** `customer_project`
  /// arrived in v12 and `part_description` in v13, so a run stored before either
  /// has no answer and the card leaves the line out rather than showing a blank
  /// one. 11 % of the live database's orders genuinely have no project, which is
  /// the same absence and reads the same way.
  Map<String, _OrderFacts> _readFacts() => {
    // Orders only: a slot that produced nothing has no bar to caption (§8.5).
    for (final entry in widget.slice.plan)
      if (entry case ProductionPlanRow(
        :final outcome,
        :final customerProject,
        :final partDescription,
      ) when customerProject != null || partDescription != null)
        outcome.orderId: _OrderFacts(
          project: customerProject,
          description: partDescription,
        ),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The theme is what the measurement is made in, so it is remade when the
    // theme changes as well as when the chart does.
    _measureLabels();
  }

  @override
  void didUpdateWidget(GanttView old) {
    super.didUpdateWidget(old);
    if (old.slice.signature == widget.slice.signature) return;
    // A different run is a different chart, a different fit, and nothing under
    // the pointer.
    _chart = _buildChart();
    _facts = _readFacts();
    _measureLabels();
    _cached = null;
    _scale = null;
    _hovered = null;
    // **The selection goes with it, and only here.** A zoom or a lane toggle
    // leaves the order on the chart, so following it survives both; a different
    // run or a narrowed filter may not contain it at all, and an id matching
    // nothing would dim every bar and light none.
    _selected = null;
    if (_across.hasClients) _across.jumpTo(0);
    if (_down.hasClients) _down.jumpTo(0);
  }

  void _measureLabels() =>
      _labelWidth = ganttLabelWidth(_chart, Theme.of(context));

  @override
  void dispose() {
    _across.dispose();
    _down.dispose();
    super.dispose();
  }

  /// Whether the queue bands between stations are drawn (§8.6).
  ///
  /// **View state, not a stored preference.** It survives switching to the
  /// results and back, the way the zoom does, and resets on restart — a setting
  /// that silently hid rows would be a chart lying to whoever opened the app
  /// next.
  bool _showLanes = true;

  GanttChart _buildChart() => buildGanttChart(
    result: widget.slice.result,
    metrics: widget.slice.metrics,
    includeLanes: _showLanes,
  );

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
    for (final study in widget.slice.run.studies) study.studyId: study.name,
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
                labelWidth: _labelWidth,
                facts: _facts,
                hovered: _hovered,
                selected: _selected,
                onHover: (bar) => setState(() => _hovered = bar),
                // **Tapping the order again clears it, and so does tapping
                // nothing.** Both are needed: a reader who has found what they
                // came for reaches for the bar they are looking at, and one who
                // has lost the thread reaches for the empty space around it.
                onSelect: (hit) => setState(() {
                  final order = hit == null ? null : _Chart._orderIdOf(hit);
                  _selected = order == _selected ? null : order;
                }),
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
              showLanes: _showLanes,
              onShowLanes: (value) => setState(() {
                _showLanes = value;
                _chart = _buildChart();
                // The rows moved, so nothing is under the pointer any more and
                // the cached layout describes a chart that no longer exists.
                _cached = null;
                _hovered = null;
              }),
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
    required this.labelWidth,
    required this.facts,
    required this.hovered,
    required this.selected,
    required this.onHover,
    required this.onSelect,
    required this.onCtrlScroll,
    required this.studies,
  });

  final GanttLayout layout;
  final ScrollController across;
  final ScrollController down;
  final double pane;
  final double labelWidth;
  final Map<String, _OrderFacts> facts;
  final GanttHit? hovered;

  /// The order being followed, or null. See `_GanttViewState._selected`.
  final String? selected;

  /// The hit that was tapped, or null where the tap landed on no bar at all.
  final ValueChanged<GanttHit?> onSelect;
  final ValueChanged<GanttHit?> onHover;
  final ValueChanged<PointerScrollEvent> onCtrlScroll;
  final Map<String, String> studies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStyle = DateStyleScope.of(context);

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
              (x: tick.x, label: _tickLabel(layout.unit, tick.at, dateStyle.locale)),
          ];

          return Stack(
            children: [
              SingleChildScrollView(
                controller: down,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Labels(layout: layout, width: labelWidth),
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
                              if (!identical(hit, hovered)) onHover(hit);
                            },
                            onExit: (_) => onHover(null),
                            child: _CtrlScroll(
                              onZoom: onCtrlScroll,
                              // **Inside the scroll views, like the ctrl-scroll
                              // above it**, so the position it reports is in the
                              // same content coordinates `barAt` answers in and
                              // no scroll offset has to be subtracted back out.
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) =>
                                    onSelect(barAt(layout, details.localPosition)),
                                child: CustomPaint(
                                key: ganttCanvasKey,
                                painter: GanttPainter(
                                  layout: layout,
                                  ticks: ticks,
                                  visibleFrom: offset,
                                  visibleTo: offset + pane,
                                  hovered: hovered,
                                  selected: selected,
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
                    ),
                  ],
                ),
              ),
              if (hovered case final bar?)
                _HoverCard(
                  hit: bar,
                  bandTop: layout.rows[bar.bandIndex].top,
                  bandHeight: layout.rows[bar.bandIndex].band.height,
                  across: offset,
                  down: scrolledDown,
                  pane: pane,
                  paneHeight: constraints.maxHeight,
                  labelWidth: labelWidth,
                  facts: facts[_orderIdOf(bar)],
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

  /// The order behind a hit, whichever kind it is. A stay in a lane belongs to
  /// an order exactly as a bar does, so the card says the same two things about
  /// both — the project and the description are the order's, not the station's.
  static String _orderIdOf(GanttHit hit) => switch (hit) {
    GanttPlacedBar(:final bar) => bar.orderId,
    GanttPlacedVisit(:final visit) => visit.orderId,
  };
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

/// The pool a band is qualified by, or null where it stands on its own name.
String? _poolOf(GanttBand band) => switch (band) {
  GanttRow(:final poolName) => poolName,
  GanttLaneRow(:final poolName) => poolName,
};

/// How a band's own name is set.
///
/// **A lane is italic and dimmed; a station is upright and plain.** That is the
/// one distinction the label column carries, so it is stated once here and read
/// by both the measurement and the widget — two copies of it would be two rules
/// that agree until one is edited.
TextStyle _bandNameStyle(GanttBand band, ThemeData theme) {
  final base = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);
  return switch (band) {
    GanttLaneRow() => base.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontStyle: FontStyle.italic,
    ),
    GanttRow() => base.copyWith(fontStyle: FontStyle.normal),
  };
}

/// How the `CLAD Pool · ` prefix in front of that name is set.
///
/// Dimmer and a size smaller than the name it qualifies, because it repeats
/// down every member of the pool and the machine is what the reader is looking
/// for. **It keeps the row's own slant** — italic over a lane, upright over a
/// station — so the row still reads as one label rather than as two fragments
/// that happen to be adjacent.
TextStyle _poolStyle(GanttBand band, ThemeData theme) =>
    _bandNameStyle(band, theme).copyWith(
      color: theme.colorScheme.outline,
      fontSize: 10,
    );

/// The width the frozen label column needs for [chart]'s labels, bounded.
///
/// Measured rather than assumed, for the reason [_labelMinWidth] gives: the
/// pool prefix is free text and a long one used to consume the column on its
/// own. Exported for a test, which is the only way to assert a width that
/// depends on a font.
double ganttLabelWidth(GanttChart chart, ThemeData theme) {
  final painter = TextPainter(textDirection: TextDirection.ltr);
  var widest = 0.0;

  for (final band in chart.rows) {
    painter.text = TextSpan(
      children: [
        if (_poolOf(band) case final pool?)
          TextSpan(text: '$pool · ', style: _poolStyle(band, theme)),
        TextSpan(text: band.name, style: _bandNameStyle(band, theme)),
      ],
    );
    painter.layout();
    if (painter.width > widest) widest = painter.width;
  }
  painter.dispose();

  // Half a pixel of slack, so a label measured at exactly the width it was
  // given does not ellipsise on a rounding difference between this pass and
  // the one the framework makes.
  return (widest + _labelPadding + 0.5).clamp(_labelMinWidth, _labelMaxWidth);
}

/// The station and lane names, one per band, aligned to the bands beside them.
class _Labels extends StatelessWidget {
  const _Labels({required this.layout, required this.width});

  final GanttLayout layout;

  /// From [ganttLabelWidth], measured once per chart.
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ganttLabelsKey,
      width: width,
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
                padding: const EdgeInsets.only(
                  left: _labelPaddingLeft,
                  right: _labelPaddingRight,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Tooltip(
                    message: switch (row.band) {
                      // The capacity is on the label rather than only implied
                      // by the band's depth, so a lane drawn shallower than it
                      // is (§8.6's cap) still says how deep it really was.
                      final GanttLaneRow lane when lane.capacity != null =>
                        '${_qualified(lane)} (${lane.capacity})',
                      final band => _qualified(band),
                    },
                    child: _LabelText(
                      band: row.band,
                      available: width - _labelPadding,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// What the tooltip says: the whole label, pool included, since the tooltip
  /// exists for exactly the case where the drawn one was cut.
  static String _qualified(GanttBand band) {
    final pool = _poolOf(band);
    return pool == null ? band.name : '$pool · ${band.name}';
  }
}

/// One band's label: `CLAD Pool · CLAD07`, or just `CLAD07`.
///
/// **The pool travels on the row**, rather than on a heading band above the
/// rows it named. That band read as a lane — an empty strip between the axis
/// and the first thing with bars — so it is gone, and every member and every
/// lane feeding the pool now says which pool it is. What belongs together says
/// so without a band that belongs to nothing.
///
/// **When it still does not fit, the pool is what gets cut, never the name.**
/// This was one `Text.rich` with a trailing ellipsis, which drops from the end
/// — so `CLAD Pool - Célula 11B/C · CLAD07` lost `CLAD07`, the only word on the
/// row that was not on the four rows around it. The name is laid out first at
/// the size it needs and the prefix flexes into what is left, which is the
/// ordering `Row` already gives an inflexible child.
class _LabelText extends StatelessWidget {
  const _LabelText({required this.band, required this.available});

  final GanttBand band;

  /// The content width, padding already taken off.
  final double available;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = ConstrainedBox(
      // Bounded, so a name longer than the whole column ellipsises rather than
      // overflowing the row it is in. It cannot be laid out unbounded here:
      // an inflexible child of a `Row` is offered infinite width.
      constraints: BoxConstraints(maxWidth: math.max(available, 0)),
      child: Text(
        band.name,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: _bandNameStyle(band, theme),
      ),
    );

    if (_poolOf(band) case final pool?) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '$pool · ',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: _poolStyle(band, theme),
            ),
          ),
          name,
        ],
      );
    }
    return name;
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
    required this.showLanes,
    required this.onShowLanes,
  });

  final GanttChart chart;
  final Map<String, String> studies;
  final int flooredBars;
  final bool canZoomOut;
  final bool canZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final bool showLanes;
  final ValueChanged<bool> onShowLanes;

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
          // Beside the zoom, because both are view controls over the same
          // chart. **One toggle rather than two labelled segments**: the labels
          // are 216 px the footer does not have, and taking them squeezed the
          // legend to nothing and overflowed the row. The tooltip carries what
          // the labels would have said, including which state it is in.
          IconButton(
            isSelected: showLanes,
            icon: const Icon(Icons.view_stream_outlined),
            selectedIcon: const Icon(Icons.table_rows_outlined),
            tooltip:
                '${showLanes ? l10n.simGanttRowsWithLanes : l10n.simGanttRowsStations}'
                ' — ${l10n.simGanttRowsHelp}',
            onPressed: () => onShowLanes(!showLanes),
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
    required this.hit,
    required this.bandTop,
    required this.bandHeight,
    required this.across,
    required this.down,
    required this.pane,
    required this.paneHeight,
    required this.labelWidth,
    required this.facts,
    required this.studies,
    required this.station,
  });

  /// The bar or the stay in a lane. One card describes both, because a reader
  /// asking "what is this" wants the same six answers either way — which order,
  /// which part, where, when, how long, and what it was doing.
  final GanttHit hit;

  /// The top of the band it sits in, so the card can be put under it without
  /// assuming every band is the same height.
  final double bandTop;

  /// And that band's height, for the same reason.
  final double bandHeight;

  final double across;
  final double down;
  final double pane;
  final double paneHeight;

  /// The frozen column the card is offset past, which is measured per chart
  /// rather than fixed — so the card follows it instead of assuming a constant.
  final double labelWidth;

  /// The plan's answers for this order, or null on a run stored before they
  /// were recorded.
  final _OrderFacts? facts;

  final Map<String, String> studies;
  final String station;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dateStyle = DateStyleScope.of(context);

    // The band's own top, carried on the hit. It used to be divided back out
    // of the rect, which held only while every band was `rowHeight` tall.
    final rowTop = bandTop;
    final left = (labelWidth + hit.rect.left - across)
        .clamp(
          labelWidth + 4,
          math.max(labelWidth + 4, labelWidth + pane - _cardWidth - 4),
        )
        .toDouble();
    // Below the band, whatever height the band is — a lane's is its depth.
    final top = (rowTop + bandHeight + 6 - down)
        .clamp(0.0, math.max(0.0, paneHeight - _cardHeight))
        .toDouble();

    String instant(DateTime value) =>
        '${dateStyle.format(value)} '
        '${formatMinuteOfDay(value.hour * 60 + value.minute)}';

    // The two kinds, reduced to what the card actually shows. Pulled apart
    // once here rather than switched at every line below.
    final (
      GanttPart part,
      int orderNumber,
      String studyId,
      DateTime from,
      DateTime to,
    ) = switch (hit) {
      GanttPlacedBar(:final bar) => (
        bar.part,
        bar.orderNumber,
        bar.studyId,
        bar.start,
        bar.end,
      ),
      GanttPlacedVisit(:final visit) => (
        visit.part,
        visit.orderNumber,
        visit.studyId,
        visit.entered,
        visit.left,
      ),
    };

    final study = studies.length > 1 ? studies[studyId] ?? studyId : null;

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
                          color: partColour(part.colourIndex).fill,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l10n.simGanttOrder('$orderNumber')}'
                          '  ·  ${part.partNumber}',
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // **Directly under the part number it describes**, and
                  // indented past the swatch so it reads as a subtitle of the
                  // title rather than as the first of the facts below. It is a
                  // label and not a key — two parts legitimately share one — so
                  // it is dimmed like every other line the reader is not meant
                  // to identify the bar by.
                  if (facts?.description case final description?)
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: _CardLine(text: description),
                    ),
                  const SizedBox(height: 6),
                  _CardLine(
                    text: study == null ? station : '$station  ·  $study',
                  ),
                  // What the batch is *for*, which is the order's own answer and
                  // the reason §16.15 moved it off the part. Omitted rather than
                  // blanked when the order has none — a labelled empty value
                  // would read as a project called nothing.
                  if (facts?.project case final project?)
                    _CardValue(label: l10n.simGanttProject, value: project),
                  _CardLine(text: l10n.simRunSpan(instant(from), instant(to))),
                  switch (hit) {
                    // What the station was committed to it for.
                    GanttPlacedBar(:final bar) => _CardValue(
                      label: l10n.simGanttCommitted,
                      value: formatAdaptiveDuration(l10n, bar.occupied),
                    ),
                    // What it stood in the lane for, which is the same question
                    // the row below answers as `Waited before starting`.
                    GanttPlacedVisit(:final visit) => _CardValue(
                      label: l10n.simGanttWaited,
                      value: formatAdaptiveDuration(l10n, visit.waited),
                    ),
                  },
                  if (hit case GanttPlacedBar(:final bar)) ...[
                    _CardValue(
                      label: l10n.simGanttWaited,
                      value: formatAdaptiveDuration(l10n, bar.wait),
                    ),
                    // Said at every scale, including the zooms where the mark
                    // on the bar itself is omitted for want of room.
                    if (bar.changeover)
                      _CardLine(text: l10n.simGanttChangeover),
                  ],
                  if (hit case GanttPlacedVisit(:final lane, :final visit)) ...[
                    // How deep the lane really is, not how deep it is drawn:
                    // §8.6 caps the band, and a reader measuring the stack
                    // against the capacity would otherwise be measuring the cap.
                    _CardLine(
                      text: lane.capacity == null
                          ? l10n.simGanttLaneUncapped
                          : l10n.simGanttLaneHolds(lane.capacity!),
                    ),
                    // The order never left. Its bar ends at the run's end
                    // because that is where the chart stops, not because
                    // anything happened there.
                    if (visit.open) _CardLine(text: l10n.simGanttStillWaiting),
                  ],
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
///
/// **Public only so a test can read what it was handed.** The bars are painted
/// rather than built, so a selection has no widget to find and no text to match
/// — the only honest assertion is that the painter was given the order the tap
/// named. The same reasoning made [ganttCanvasKey] and `ganttLabelWidth`
/// public; nothing outside this file constructs one.
@visibleForTesting
class GanttPainter extends CustomPainter {
  const GanttPainter({
    required this.layout,
    required this.ticks,
    required this.visibleFrom,
    required this.visibleTo,
    required this.hovered,
    required this.selected,
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

  final GanttHit? hovered;

  /// The order being followed, or null for the ordinary chart.
  final String? selected;

  final Color band;
  final Color rule;
  final TextStyle axisStyle;
  final Color outline;

  /// Whether [orderId] is one the reader is not following, and is therefore
  /// drawn back. False whenever nothing is selected, which is what keeps an
  /// unselected chart pixel-for-pixel what it was.
  bool _isDimmed(String orderId) => selected != null && orderId != selected;

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
        //
        // A stay already sits at 0.30, so following an order takes it down
        // rather than up: the dimmed figure is a fraction of a fraction, and
        // the 1 px edge that makes an empty-looking slot readable goes with it,
        // or every dimmed stay would still be outlined on a chart whose point is
        // that one order is.
        final dimmed = _isDimmed(placed.visit.orderId);
        canvas.drawRRect(
          shape,
          Paint()
            ..color = colour.fill.withValues(
              alpha: dimmed ? _dimmedVisit : 0.30,
            ),
        );
        if (!dimmed) {
          canvas.drawRRect(
            shape,
            Paint()
              ..color = colour.fill
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
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
        final dimmed = _isDimmed(placed.bar.orderId);
        canvas.drawRRect(
          shape,
          Paint()
            ..color = dimmed
                ? colour.fill.withValues(alpha: _dimmedBar)
                : colour.fill,
        );

        // **Nothing else is drawn on a bar that is not the one being followed.**
        // The changeover mark and the part number are the detail a reader is
        // reading *this* bar for, and left at full strength over a washed-out
        // fill they would be the loudest thing on a chart whose subject is
        // somewhere else. The fill still carries the part's hue, so the plant is
        // legible as shape and colour while one order is legible as text.
        if (dimmed) continue;

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
          // The part number first and the order number after it, and only when
          // there is room for both — so every label that reads correctly at a
          // given zoom today reads the same way, and the order number is what
          // the extra width buys rather than what it costs.
          final label = placed.rect.width >= _numberedBarWidth
              ? '${placed.bar.part.partNumber}  #${placed.bar.orderNumber}'
              : placed.bar.part.partNumber;
          _text(
            canvas,
            label,
            Offset(placed.rect.left + 6, placed.rect.top + 2),
            axisStyle.copyWith(color: colour.onFill),
            maxWidth: placed.rect.width - 10,
          );
        }

        // The same stroke answers both, because they mean the same thing to a
        // reader — *this* is the one you are asking about. A bar of the followed
        // order is outlined whether or not the pointer is on it, which is what
        // makes the order findable at a glance rather than by sweeping for it.
        if (identical(placed, hovered) || selected != null) {
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
  bool shouldRepaint(covariant GanttPainter old) =>
      old.layout != layout ||
      old.ticks != ticks ||
      old.visibleFrom != visibleFrom ||
      old.visibleTo != visibleTo ||
      !identical(old.hovered, hovered) ||
      old.selected != selected ||
      old.band != band ||
      old.rule != rule ||
      old.outline != outline;
}
