import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../common/horizontal_scroll.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/occupation_graph.dart';
import '../application/run_filter.dart';

/// Demand against capacity, month by month (DESIGN.md §8.2, `TODO.md` §10.3).
///
/// **Drawn rather than charted**, for the reason `mm3_view.dart` gives: the
/// figure is a run of stacked rectangles and one polyline, and a charting
/// dependency would be a package to keep current for that.
///
/// The station pickers sit above the chart rather than in the workspace's filter
/// bar. They belong to this view alone — the tables and the Gantt have no notion
/// of a station filter — and putting them in the shared bar would offer every
/// other view a control that did nothing to it.
class OccupationView extends StatefulWidget {
  const OccupationView({super.key, required this.slice});

  final FilteredRun slice;

  @override
  State<OccupationView> createState() => _OccupationViewState();
}

class _OccupationViewState extends State<OccupationView> {
  final _types = <String>{};
  final _workcenters = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final run = widget.slice.run;

    final graph = occupationGraph(
      run: run,
      filter: widget.slice.filter,
      stations: OccupationStations(
        typeIds: {..._types},
        workcenterIds: {..._workcenters},
      ),
    );

    // Offered from the run rather than the plant, the same rule the filter bar
    // follows: a type no station in this run has is a filter that returns
    // nothing and looks broken.
    final typeOptions = <String, String>{
      for (final station in run.metrics.workcenters)
        if (station.typeId != null)
          station.typeId!: station.typeName ?? station.typeId!,
    };
    final stationOptions = <String, String>{
      for (final station in run.metrics.workcenters)
        station.workcenterId: station.name,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StationPicker(
                label: l10n.occupationType,
                options: typeOptions,
                selected: _types,
                onChanged: () => setState(() {}),
              ),
              _StationPicker(
                label: l10n.occupationStation,
                options: stationOptions,
                selected: _workcenters,
                onChanged: () => setState(() {}),
              ),
              if (_types.isNotEmpty || _workcenters.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    _types.clear();
                    _workcenters.clear();
                  }),
                  child: Text(l10n.simFilterClear),
                ),
            ],
          ),
        ),
        if (graph == null)
          // **A run made before v25 offers no graph rather than an empty one**
          // (§10.2). Said out loud, because a blank panel reads as a defect and
          // this is the model refusing to invent a capacity line for a plant
          // that may have been retuned since.
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.occupationUngraphable,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Legend(graph: graph),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 280,
                    child: _OccupationChart(graph: graph),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.occupationPivotTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.occupationPivotHelp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Pivot(graph: graph),
                ],
              ),
            ),
          ),
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
    final colours = _SegmentColours.of(theme);

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
        // Named for what it is rather than "other": it is the demand of lines
        // the filter excluded, and a reader has to know the bar still holds it.
        swatch(colours.other, l10n.occupationOutsideFilter),
        Text(
          l10n.occupationStations('${graph.stationsInView.length}'),
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

  factory _SegmentColours.of(ThemeData theme) {
    final scheme = theme.colorScheme;
    return _SegmentColours(
      process: scheme.primary,
      // Rework and changeover are losses on top of the work, so they read as
      // shades of the same bar rather than as three unrelated colours.
      rework: scheme.tertiary,
      changeover: scheme.secondary,
      // Deliberately the quietest of the four (§10.3): it is in the bar so an
      // overload cannot be filtered away, not to be read as this filter's own
      // load.
      other: scheme.outlineVariant,
      line: scheme.onSurface,
      over: scheme.error,
    );
  }

  final Color process;
  final Color rework;
  final Color changeover;
  final Color other;
  final Color line;
  final Color over;
}

class _OccupationChart extends StatelessWidget {
  const _OccupationChart({required this.graph});

  final OccupationGraph graph;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A month is 64 px, so a two-year run scrolls rather than shrinking its
    // bars into stripes.
    final width = graph.months.length * 64.0;
    return HorizontalScroll(
      child: SizedBox(
        width: width < 320 ? 320 : width,
        child: CustomPaint(
          painter: _OccupationPainter(
            graph: graph,
            colours: _SegmentColours.of(theme),
            grid: theme.colorScheme.outlineVariant,
            label: theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurface,
            direction: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

/// Stacked bars, a capacity line, and a month label under each column.
class _OccupationPainter extends CustomPainter {
  _OccupationPainter({
    required this.graph,
    required this.colours,
    required this.grid,
    required this.label,
    required this.direction,
  });

  final OccupationGraph graph;
  final _SegmentColours colours;
  final Color grid;
  final Color label;
  final TextDirection direction;

  static const _axis = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final months = graph.months;
    if (months.isEmpty) return;

    final plot = size.height - _axis;
    // **The tallest bar or the line, whichever is higher.** A scale fitted to
    // the bars alone would push the capacity line off the top on a quiet month
    // and make an under-loaded plant look overloaded.
    var peak = 0;
    for (final month in months) {
      final total = month.total.inSeconds;
      if (total > peak) peak = total;
      if (month.capacity.inSeconds > peak) peak = month.capacity.inSeconds;
    }
    if (peak <= 0) return;

    double y(int seconds) => plot * (1 - seconds / peak);
    final columnWidth = size.width / months.length;

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

      _text(
        canvas,
        DateFormat('MMM/yy').format(month.month),
        Offset((i + 0.5) * columnWidth, plot + 6),
        label,
        centred: true,
      );

      // How many individual stations are over, where the sum alone would not
      // say (§10.3). Only when there are any — a badge on every column would be
      // noise on a plant that is coping.
      if (month.stationsOver > 0) {
        _text(
          canvas,
          '${month.stationsOver}',
          Offset((i + 0.5) * columnWidth, y(month.total.inSeconds) - 14),
          colours.over,
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

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    Color colour, {
    bool centred = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: colour, fontSize: 10),
      ),
      textDirection: direction,
    )..layout();
    painter.paint(
      canvas,
      centred ? at.translate(-painter.width / 2, 0) : at,
    );
  }

  @override
  bool shouldRepaint(_OccupationPainter old) =>
      old.graph != graph || old.colours.process != colours.process;
}

/// Lines down, workcenter types across (§10.3).
class _Pivot extends StatelessWidget {
  const _Pivot({required this.graph});

  final OccupationGraph graph;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pivot = graph.pivot;
    if (pivot.rows.isEmpty) return const SizedBox.shrink();

    String percent(double? value) =>
        value == null ? '—' : '${(value * 100).round()}%';

    // The cell name is written once per run of rows, so Cell → Line reads as a
    // hierarchy rather than as a column repeating one name three times. The
    // rows arrive sorted by cell, so "the same as the row above" is enough.
    final firstOfCell = <int>{};
    String? seen;
    for (var i = 0; i < pivot.rows.length; i++) {
      if (pivot.rows[i].cellName != seen) {
        firstOfCell.add(i);
        seen = pivot.rows[i].cellName;
      }
    }

    return HorizontalScroll(
      child: DataTable(
        columns: [
          DataColumn(label: Text(l10n.occupationCell)),
          DataColumn(label: Text(l10n.occupationLine)),
          for (final type in pivot.typeIds)
            DataColumn(
              label: Text(pivot.typeNames[type] ?? type),
              numeric: true,
            ),
          DataColumn(label: Text(l10n.occupationTotal), numeric: true),
        ],
        rows: [
          for (final (index, row) in pivot.rows.indexed)
            DataRow(
              cells: [
                DataCell(Text(firstOfCell.contains(index) ? row.cellName : '')),
                DataCell(Text(row.lineName)),
                for (final type in pivot.typeIds)
                  DataCell(Text(percent(row.byType[type]))),
                DataCell(Text(percent(row.total))),
              ],
            ),
          // **The TOTAL row counts every line touching those stations, filtered
          // out or not**, so under a filter it will not equal the sum of the
          // cells above it — which is the point rather than a defect (§10.3).
          DataRow(
            cells: [
              DataCell(
                Text(
                  l10n.occupationTotal,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const DataCell(Text('')),
              for (final type in pivot.typeIds)
                DataCell(
                  Text(
                    percent(pivot.totals[type]),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: (pivot.totals[type] ?? 0) > 1
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ),
                ),
              DataCell(
                Text(
                  percent(pivot.total),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The same menu the workspace's filter bar uses, kept here because these two
/// narrow stations rather than orders and belong to this view alone.
class _StationPicker extends StatelessWidget {
  const _StationPicker({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final Map<String, String> options;
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sorted = options.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return MenuAnchor(
      menuChildren: [
        for (final entry in sorted)
          CheckboxMenuButton(
            closeOnActivate: false,
            value: selected.contains(entry.key),
            onChanged: (checked) {
              if (checked ?? false) {
                selected.add(entry.key);
              } else {
                selected.remove(entry.key);
              }
              onChanged();
            },
            child: Text(entry.value),
          ),
      ],
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.arrow_drop_down, size: 18),
        iconAlignment: IconAlignment.end,
        label: Text(
          selected.isEmpty
              ? '$label · ${l10n.simFilterAll}'
              : '$label · ${selected.length}',
        ),
      ),
    );
  }
}
