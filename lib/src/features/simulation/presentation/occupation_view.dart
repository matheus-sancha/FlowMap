/// The Occupation view: a chart **and** a grid, switched (DESIGN.md §10.3, #9).
///
/// **The grid was added; the chart was not removed.** #9 concluded the stacked
/// bar should be deleted outright, and it was — the live database is a strong
/// argument for the grid: across the runs that can draw this view the aggregate
/// bar has **never once broken its capacity line**, peak 87 %, while single
/// stations reached 149 % and seven of seventeen were over in one month. A small
/// red `7` above an 87 % bar was carrying the whole signal.
///
/// **The field then said the chart was wanted adjusted, not deleted**, which
/// settles it: that is what a drive is for, and it outranks the ticket.
///
/// **And there is no switch between them any more** (#16). `795ac6e` put one
/// in, #13 chose which side it opened on, and the third answer in three rounds
/// was to stop asking: the chart is drawn as the grid's own header, through
/// [PeriodMatrix.banner], so the two share one column width, one frozen gutter
/// and one horizontal scrollbar. A bar sits directly above its own row of
/// cells, which is what makes them one surface rather than two stacked ones.
///
/// **#13 is why the argument above does not stop the chart leading.** The chart
/// is *demand against capacity of whatever is selected* — so the
/// aggregate is not hiding a station, it is answering the question that was
/// asked. Narrow with the structural filters and the same label reads 147 %;
/// leave them wide and 87 % is a true statement about the plant. The reader
/// drills, and the chart does not have to second-guess them.
///
/// **What that costs, recorded rather than lost.** #13 also dropped the small
/// red count of stations over their own line, so on an unnarrowed chart nothing
/// says that April's comfortable 87 % holds seven overloaded machines. That was
/// chosen with the cost stated: one figure per column, and the grid one press
/// away.
///
/// What the grid adds that the chart could not: a per-station figure, so an
/// overloaded machine is visible under an aggregate that is not; two groupings;
/// three units; and the project's own bands. What the chart keeps that the grid
/// does not: the process / rework / changeover split, which exists nowhere else
/// on screen — though since #16 its **hours** live in the bar's tooltip, which
/// is where the deleted badge's signal was asked to go and did not — the shape
/// of a month read against the one before it, and, since #13, an hours axis, so
/// a bar has a size and not only a ratio.
///
/// **The two switches govern the grid half only.** The chart is always the
/// aggregate of the stations in view, so grouping and unit do nothing to it;
/// they sit directly over the rows they reorder, and adjacency is what says so.
///
/// **One filter, both surfaces.** They read the same `stationsInView`, so they
/// cannot disagree about which stations are being looked at.
library;

import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../app/tokens.dart';
import '../../../common/period_matrix.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/occupation_graph.dart';
import 'occupation_chart_scale.dart';
import '../application/occupation_grid.dart';
import '../application/run_filter.dart';

class OccupationView extends StatefulWidget {
  const OccupationView({super.key, required this.slice, required this.project});

  final FilteredRun slice;

  /// Whose thresholds band the cells — the project's own (§10.1, v29), the same
  /// shape and the same settings card as the float matrix's.
  final Project project;

  @override
  State<OccupationView> createState() => _OccupationViewState();
}

class _OccupationViewState extends State<OccupationView> {
  /// **View state, not a location.** §12.1 keeps the results filters out of the
  /// URL bar `?study=`, and how a reader is reading one tab is the same kind of
  /// thing as which of the plan's two shapes they chose.
  OccupationGrouping _grouping = OccupationGrouping.workcenter;
  OccupationUnit _unit = OccupationUnit.percent;

  /// Which month the rows are ordered by, or **null for the arrival order** —
  /// worst month first, which is the question the view exists to answer and so
  /// the order it should already be in (#10).
  int? _sortedMonth;
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final graph = occupationGraph(
      run: widget.slice.run,
      filter: widget.slice.filter,
    );
    final grid = occupationGrid(
      run: widget.slice.run,
      filter: widget.slice.filter,
      grouping: _grouping,
    );

    // **A run before v25 offers no grid rather than an empty one** (§10.2). 144
    // of 147 stored runs are in this state, so this is the common case rather
    // than the edge — and inventing capacity from today's schedules would draw
    // a 2025 plant out of a 2026 one.
    if (grid == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.occupationUngraphable,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    final status = FlowStatus.of(context);
    final amber = widget.project.occupationAmberPct / 100;
    final red = widget.project.occupationRedPct / 100;

    PeriodMatrixCell? cellOf(OccupationRow row, int index) {
      final month = grid.months[index];
      final cell = row.cells[month];
      if (cell == null) return null;

      final ratio = cell.ratio;
      // **Three bands, from the project's own two thresholds** (v29) — the
      // float matrix's shape next door. `FlowStatus` is picked rather than
      // derived, so re-seeding the chrome cannot move a band (#8).
      final (Color background, Color foreground) = switch (ratio) {
        null => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.outline,
        ),
        final value when value > red => (
          status.critical.fill,
          status.critical.ink,
        ),
        final value when value > amber => (
          status.warning.fill,
          status.warning.ink,
        ),
        _ => (status.good.fill, status.good.ink),
      };

      final text = switch (_unit) {
        OccupationUnit.percent =>
          ratio == null ? '—' : '${(ratio * 100).round()}%',
        // Asked of, over open — §15's rule that a derived figure expands to
        // show its inputs, and what a percentage drops: 3,296 h of capacity in
        // one month and 9,384 in another read alike as a ratio.
        OccupationUnit.hours => '${cell.asked.inHours}/${cell.open.inHours}',
        OccupationUnit.gap => '${cell.gap.inHours}',
      };

      return PeriodMatrixCell(
        text: text,
        background: background,
        foreground: foreground,
        tooltip: l10n.occupationCellHelp(
          '${cell.asked.inHours}',
          row.name.isEmpty ? l10n.occupationPlant : row.name,
          DateFormat.yMMM().format(month),
          '${cell.open.inHours}',
          '${cell.filtered.inHours}',
        ),
        // The fill along the base is the filtered orders' share. It is what
        // tells "CEU27 is at 100 % and 80 of it is yours" from "CEU32 is at
        // 147 % and none of it is" — same colour, opposite action.
        share: cell.share,
      );
    }

    // **Sorted here rather than in the model** (#10): which month a reader is
    // ranking by is a way of reading the grid, not a fact about the run.
    // Descending first, because the row you came for is the overloaded one.
    final rows = [...grid.rows];
    if (_sortedMonth case final index?) {
      final month = grid.months[index];
      rows.sort((a, b) {
        // A row with nothing in that month sorts last either way — it is an
        // absence, not a value of zero, the same call the combined plan makes
        // about an empty release slot.
        final ka = a.cells[month]?.ratio;
        final kb = b.cells[month]?.ratio;
        if (ka == null || kb == null) {
          return ka == null ? (kb == null ? 0 : 1) : -1;
        }
        return _sortAscending ? ka.compareTo(kb) : kb.compareTo(ka);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // **No `Chart | Grid` switch** (#16). It was added by `795ac6e`
              // when the field wanted the chart back, and #13 chose which side
              // it opened on — three answers to one question in three rounds.
              // The fourth is to stop asking: both are on the page, the chart
              // drawn as the grid's own header so they share a column width, a
              // left gutter and one horizontal scrollbar.
              //
              // These two switches govern the grid half only; the chart is
              // always the aggregate of the stations in view. Adjacency is what
              // says so — they sit directly over the rows they reorder.
              SegmentedButton<OccupationGrouping>(
                segments: [
                  ButtonSegment(
                    value: OccupationGrouping.workcenter,
                    label: Text(l10n.occupationByWorkcenter),
                  ),
                  ButtonSegment(
                    value: OccupationGrouping.line,
                    label: Text(l10n.occupationByLine),
                  ),
                ],
                selected: {_grouping},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _grouping = s.first),
              ),
              SegmentedButton<OccupationUnit>(
                segments: [
                  ButtonSegment(
                    value: OccupationUnit.percent,
                    label: Text(l10n.occupationUnitPercent),
                  ),
                  ButtonSegment(
                    value: OccupationUnit.hours,
                    label: Text(l10n.occupationUnitHours),
                  ),
                  ButtonSegment(
                    value: OccupationUnit.gap,
                    label: Text(l10n.occupationUnitGap),
                  ),
                ],
                selected: {_unit},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _unit = s.first),
              ),
              _Bands(project: widget.project),
            ],
          ),
          const SizedBox(height: 12),
          if (graph != null) ...[
            _Legend(graph: graph),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: SingleChildScrollView(
              child: PeriodMatrix(
                // **The chart, as the grid's header** (#16) — split into the
                // half that stays put and the half that scrolls. The axis
                // sits over the frozen labels, which is what keeps #13's rule
                // that a bar is never measured against nothing; the plot sits
                // over the month columns and is laid out to exactly their
                // width, so a bar cannot drift off the cells it describes.
                banner: graph == null
                    ? null
                    : (
                        height: 240,
                        gutter: _ChartAxis(graph: graph),
                        body: _ChartPlot(graph: graph),
                      ),
                months: grid.months,
                headerLabel: _grouping == OccupationGrouping.workcenter
                    ? l10n.occupationWorkcenter
                    : l10n.occupationLine,
                rows: [
                  for (final row in rows)
                    PeriodMatrixRow(label: row.name, qualifier: row.qualifier),
                ],
                cellAt: (row, month) => cellOf(rows[row], month),
                sortedMonth: _sortedMonth,
                sortAscending: _sortAscending,
                onSortMonth: (index) => setState(() {
                  if (_sortedMonth == index) {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortedMonth = index;
                    _sortAscending = false;
                  }
                }),
                // **Only when nothing has narrowed the station set** — once a
                // line or a type is chosen, a total across what is left would
                // be a partial wearing the plant's name.
                pinned: grid.plant == null
                    ? null
                    : PeriodMatrixRow(
                        label: l10n.occupationPlant,
                        emphasis: true,
                      ),
                pinnedCellAt: grid.plant == null
                    ? null
                    : (month) => cellOf(grid.plant!, month),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two thresholds, named beside the grid they band.
///
/// The float matrix carries a legend for the same reason: the thresholds are the
/// project's own, so a reader cannot know what amber means without being told.
class _Bands extends StatelessWidget {
  const _Bands({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = FlowStatus.of(context);

    Widget swatch(Color fill, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );

    return Wrap(
      spacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        swatch(status.good.fill, '≤ ${project.occupationAmberPct}%'),
        swatch(status.warning.fill, '> ${project.occupationAmberPct}%'),
        swatch(status.critical.fill, '> ${project.occupationRedPct}%'),
      ],
    );
  }
}

/// What the four segments are, and how many stations the bars aggregate.
class _Legend extends StatelessWidget {
  const _Legend({required this.graph});

  final OccupationGraph graph;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colours = _SegmentColours.of(context);

    Widget swatch(Color colour, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: colour),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        swatch(colours.process, l10n.occupationProcess),
        swatch(colours.rework, l10n.occupationRework),
        swatch(colours.changeover, l10n.occupationChangeover),
        // Named for what it is rather than "other": it is the demand of orders
        // the filter excluded, and a reader has to know the bar still holds it.
        //
        // **Only when the bar actually holds some.** A key for a colour that is
        // nowhere on the chart is a reader looking for a segment that does not
        // exist — and since only an order-level filter can produce one, this is
        // absent on every unfiltered chart and under every structural filter,
        // which is most of the time.
        if (graph.months.any((m) => m.other > Duration.zero))
          swatch(colours.other, l10n.occupationOutsideFilter),
        Text(
          l10n.occupationStations(graph.stationsInView.length),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _SegmentColours {
  const _SegmentColours({
    required this.process,
    required this.rework,
    required this.changeover,
    required this.other,
    required this.line,
    required this.over,
  });

  /// **From [OccupationRamp], not from the colour scheme** (#8). These read
  /// `primary`, `tertiary` and `secondary` in v1.0 — three *generated* hues
  /// carrying meaning nobody picked, and the exact coupling `tokens.dart` was
  /// written to remove. The stack is an ordered quantity, so it is one hue
  /// light-to-dark; `over` is [FlowStatus.critical]'s ink, because exceeding
  /// capacity is a state rather than more of the same quantity.
  factory _SegmentColours.of(BuildContext context) {
    final ramp = OccupationRamp.of(context);
    final theme = Theme.of(context);
    return _SegmentColours(
      process: ramp.process,
      rework: ramp.rework,
      changeover: ramp.changeover,
      other: ramp.other,
      line: theme.colorScheme.onSurface,
      over: FlowStatus.of(context).critical.ink,
    );
  }

  final Color process;
  final Color rework;
  final Color changeover;
  final Color other;
  final Color line;
  final Color over;
}

/// The scale both halves of the chart read.
///
/// **Built once per build and handed to both**, so the axis in the frozen
/// gutter and the plot in the scrolling body cannot disagree about where
/// 8,000 h is.
ChartScale _scaleFor(OccupationGraph graph, String locale) {
  // **The tallest bar or the line, whichever is higher.** A scale fitted to the
  // bars alone would push the capacity line off the top on a quiet month and
  // make an under-loaded plant look overloaded.
  var peak = 0;
  for (final month in graph.months) {
    if (month.total.inSeconds > peak) peak = month.total.inSeconds;
    if (month.capacity.inSeconds > peak) peak = month.capacity.inSeconds;
  }
  return ChartScale(peakSeconds: peak, ticks: hoursTicks(peak, locale));
}

/// The hours axis, in the matrix's frozen gutter (#16).
///
/// **It sits over the row labels rather than beside the bars**, which is what
/// keeps #13's rule — an axis inside the scroll slides off the left edge and
/// leaves the bars measured against nothing — while letting the plot align to
/// the month columns.
class _ChartAxis extends StatelessWidget {
  const _ChartAxis({required this.graph});

  final OccupationGraph graph;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return CustomPaint(
      painter: _AxisPainter(
        scale: _scaleFor(graph, Localizations.localeOf(context).toString()),
        caption: l10n.occupationUnitHours,
        label: theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurface,
        grid: theme.colorScheme.outlineVariant,
        direction: Directionality.of(context),
      ),
    );
  }
}

/// The bars, in the matrix's scrolling body — one column per month, each
/// exactly as wide as the grid column beneath it.
class _ChartPlot extends StatelessWidget {
  const _ChartPlot({required this.graph});

  final OccupationGraph graph;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scale = _scaleFor(graph, locale);
    final hours = NumberFormat.decimalPattern(locale)
      ..maximumFractionDigits = 0;

    String h(Duration value) =>
        l10n.occupationHours(hours.format(value.inHours));

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _OccupationPainter(
              graph: graph,
              scale: scale,
              colours: _SegmentColours.of(context),
              grid: theme.colorScheme.outlineVariant,
              label:
                  theme.textTheme.bodySmall?.color ??
                  theme.colorScheme.onSurface,
              direction: Directionality.of(context),
            ),
          ),
        ),
        // **A transparent column per month rather than a hit test on the
        // painter** (#16). The columns are already a fixed width, so the month
        // under the pointer is a division rather than a search — and letting
        // `Tooltip` own the hover gives the same delay, the same styling and
        // the same dismissal as every other tooltip in the app, which a painter
        // reimplementing hover would not.
        Positioned.fill(
          child: Row(
            children: [
              for (final month in graph.months)
                SizedBox(
                  width: PeriodMatrix.defaultMonthWidth,
                  child: Tooltip(
                    richMessage: TextSpan(
                      children: [
                        TextSpan(
                          text: DateFormat.yMMM().format(month.month),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text:
                              '\n${l10n.occupationTipDemand}  ${h(month.total)}'
                              '\n${l10n.occupationTipCapacity}  ${h(month.capacity)}'
                              '\n'
                              '\n${l10n.occupationProcess}  ${h(month.process)}'
                              '\n${l10n.occupationRework}  ${h(month.rework)}'
                              '\n${l10n.occupationChangeover}  ${h(month.changeover)}'
                              // Only when there is any — an order-level filter
                              // is the only thing that produces it, so on most
                              // charts this line would be a permanent zero.
                              '${month.other > Duration.zero ? '\n${l10n.occupationOutsideFilter}  ${h(month.other)}' : ''}',
                        ),
                      ],
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Paints the ticks and their labels.
class _AxisPainter extends CustomPainter {
  _AxisPainter({
    required this.scale,
    required this.caption,
    required this.label,
    required this.grid,
    required this.direction,
  });

  final ChartScale scale;
  final String caption;
  final Color label;
  final Color grid;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final floor = scale.floorOf(size.height);

    // The unit once, at the top — rather than an `h` on every tick, which is
    // four repetitions of a fact that does not change.
    _paintText(
      canvas,
      caption,
      Offset(size.width - 6, 0),
      label,
      direction,
      rightAligned: true,
    );

    for (final tick in scale.ticks) {
      final y = scale.y(size.height, tick.seconds);
      _paintText(
        canvas,
        tick.label,
        Offset(size.width - 8, y - 6),
        label,
        direction,
        rightAligned: true,
      );
      canvas.drawLine(
        Offset(size.width - 4, y),
        Offset(size.width, y),
        Paint()
          ..color = grid
          ..strokeWidth = 1,
      );
    }

    canvas.drawLine(
      Offset(size.width, ChartScale.headroom),
      Offset(size.width, floor),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_AxisPainter old) =>
      old.scale.peakSeconds != scale.peakSeconds ||
      old.label != label ||
      old.caption != caption;
}

/// Stacked bars, a capacity line, a month label under each column, and the
/// month's occupation above it.
class _OccupationPainter extends CustomPainter {
  _OccupationPainter({
    required this.graph,
    required this.scale,
    required this.colours,
    required this.grid,
    required this.label,
    required this.direction,
  });

  final OccupationGraph graph;
  final ChartScale scale;
  final _SegmentColours colours;
  final Color grid;
  final Color label;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final months = graph.months;
    if (months.isEmpty || scale.peakSeconds <= 0) return;

    final plot = scale.floorOf(size.height);
    double y(int seconds) => scale.y(size.height, seconds);
    final columnWidth = size.width / months.length;

    // **Dotted, and behind everything else.** The capacity line is solid, thick
    // and coloured, and it is the one line the chart exists to show a bar
    // breaking — so the gridlines have to be unmistakably not it.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final tick in scale.ticks) {
      if (tick.seconds == 0) continue;
      _dotted(canvas, y(tick.seconds), size.width, gridPaint);
    }

    for (var i = 0; i < months.length; i++) {
      final month = months[i];
      final left = i * columnWidth + columnWidth * 0.18;
      final right = (i + 1) * columnWidth - columnWidth * 0.18;

      // Stacked from the floor up in the order they are charged: the work, then
      // rework on top of it, then the changeover, then whatever the filter is
      // not showing.
      var floor = 0;
      void segment(Duration part, Color colour) {
        if (part <= Duration.zero) return;
        final top = floor + part.inSeconds;
        canvas.drawRect(
          Rect.fromLTRB(left, y(top), right, y(floor)),
          Paint()..color = colour,
        );
        floor = top;
      }

      segment(month.process, colours.process);
      segment(month.rework, colours.rework);
      segment(month.changeover, colours.changeover);
      segment(month.other, colours.other);

      // The capacity line, drawn per column rather than as one polyline: it is
      // a step function — a month with a shutdown genuinely has less capacity
      // than the one before — and a sloping line between two months would claim
      // a capacity neither had.
      final capacity = y(month.capacity.inSeconds);
      canvas.drawLine(
        Offset(i * columnWidth, capacity),
        Offset((i + 1) * columnWidth, capacity),
        Paint()
          ..color = colours.line
          ..strokeWidth = 2,
      );

      _paintText(
        canvas,
        DateFormat('MMM/yy').format(month.month),
        Offset((i + 0.5) * columnWidth, plot + 6),
        label,
        direction,
        centred: true,
      );

      // **The month's occupation, above its bar** (#13) — demand over capacity
      // for the stations in view, counting the neutral segment, so the figure
      // is the stations' true load rather than the filter's share of it.
      //
      // Absent where there is no capacity to divide by: a month every station
      // was closed for is a real state, and `0 %` would be a claim about a
      // plant that was not open.
      if (month.occupation case final ratio?) {
        _paintText(
          canvas,
          '${(ratio * 100).round()}%',
          Offset((i + 0.5) * columnWidth, y(month.total.inSeconds) - 14),
          label,
          direction,
          centred: true,
        );
      }
    }

    canvas.drawLine(
      Offset(0, plot),
      Offset(size.width, plot),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );
  }

  void _dotted(Canvas canvas, double y, double width, Paint paint) {
    const on = 2.0;
    const off = 5.0;
    for (var x = 0.0; x < width; x += on + off) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + on, width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_OccupationPainter old) =>
      old.graph != graph ||
      old.scale.peakSeconds != scale.peakSeconds ||
      old.colours.process != colours.process;
}

void _paintText(
  Canvas canvas,
  String text,
  Offset at,
  Color colour,
  TextDirection direction, {
  bool centred = false,
  bool rightAligned = false,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: colour, fontSize: 10),
    ),
    textDirection: direction,
  )..layout();
  final dx = centred
      ? -painter.width / 2
      : rightAligned
      ? -painter.width
      : 0.0;
  painter.paint(canvas, at.translate(dx, 0));
}
