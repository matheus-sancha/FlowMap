import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/mm3.dart';
import '../application/mm3_providers.dart';

/// The sequence smoothness view (DESIGN.md §6.3).
///
/// A chart against the 1.0 reference and the table behind it, side by side, so
/// a reorder on the Sequence tab can be checked here in one glance. Nothing
/// reorders anything: this measures, and the user decides.
class Mm3View extends ConsumerWidget {
  const Mm3View({super.key, required this.study});

  final Study study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final series = ref.watch(mm3SeriesProvider(study.id));

    if (series == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (series.points.isEmpty) {
      return Center(
        child: Text(l10n.mm3NoSequence, style: theme.textTheme.bodyLarge),
      );
    }

    const bands = Mm3Bands();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(study: study, series: series),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: series.isEmpty
              ? Center(
                  child: Text(
                    l10n.mm3NotMeasurable,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                )
              : CustomPaint(
                  size: Size.infinite,
                  painter: _Mm3Painter(
                    series: series,
                    bands: bands,
                    line: theme.colorScheme.primary,
                    reference: theme.colorScheme.onSurface,
                    warning: theme.colorScheme.tertiary,
                    severe: theme.colorScheme.error,
                    grid: theme.colorScheme.outlineVariant,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _Mm3Table(series: series, bands: bands)),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.study, required this.series});

  final Study study;
  final Mm3Series series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scopes = ref.watch(mm3ScopesProvider(study.id));
    final deviation = series.averageDeviation;

    return Row(
      children: [
        Text(l10n.mm3Scope, style: theme.textTheme.bodySmall),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: series.scope.targetId ?? Mm3ScopeSelection.wholeFlow,
            onChanged: (value) => ref
                .read(mm3ScopeSelectionProvider(study.id).notifier)
                .select(value),
            items: [
              DropdownMenuItem(
                value: Mm3ScopeSelection.wholeFlow,
                child: Text(l10n.mm3WholeFlow),
              ),
              for (final scope in scopes)
                DropdownMenuItem(
                  value: scope.targetId,
                  child: Text(scope.title),
                ),
            ],
          ),
        ),
        const Spacer(),
        // The headline. Stated as a distance from takt rather than as a score,
        // because that is the number an engineer can act on.
        Tooltip(
          message: l10n.mm3SmoothnessHelp,
          child: Row(
            children: [
              Text(l10n.mm3Smoothness, style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              Text(
                deviation == null
                    ? '—'
                    : '±${(deviation * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Mm3Table extends StatelessWidget {
  const _Mm3Table({required this.series, required this.bands});

  final Mm3Series series;
  final Mm3Bands bands;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView.builder(
      itemCount: series.points.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _cell('#', theme.textTheme.labelLarge, width: 44),
                _cell(l10n.demandPartNumber, theme.textTheme.labelLarge),
                _cell(
                  l10n.demandBatchSize,
                  theme.textTheme.labelLarge,
                  width: 80,
                ),
                _cell(
                  l10n.stepEquivalence,
                  theme.textTheme.labelLarge,
                  width: 110,
                ),
                _cell(l10n.mm3Column, theme.textTheme.labelLarge, width: 110),
              ],
            ),
          );
        }

        final point = series.points[index - 1];
        final colour = _bandColour(context, point.movingAverage, bands);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _cell('${point.sequence + 1}', theme.textTheme.bodySmall,
                  width: 44),
              _cell(point.partNumber, theme.textTheme.bodyMedium),
              _cell('${point.batchSize}', theme.textTheme.bodyMedium,
                  width: 80),
              _cell(
                point.equivalence?.toStringAsFixed(2) ?? '—',
                theme.textTheme.bodyMedium,
                width: 110,
              ),
              _cell(
                point.movingAverage?.toStringAsFixed(2) ?? '—',
                theme.textTheme.bodyMedium?.copyWith(color: colour),
                width: 110,
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _cell(String text, TextStyle? style, {double width = 160}) =>
      SizedBox(
        width: width,
        child: Text(text, style: style, overflow: TextOverflow.ellipsis),
      );
}

Color? _bandColour(BuildContext context, double? value, Mm3Bands bands) {
  if (value == null) return null;
  final scheme = Theme.of(context).colorScheme;
  final off = (value - 1).abs();
  if (off >= bands.severe) return scheme.error;
  if (off >= bands.warning) return scheme.tertiary;
  return null;
}

/// The chart: the moving average against a 1.0 reference, with the two warning
/// bands shaded behind it.
///
/// Drawn rather than charted. The whole figure is one line against one
/// reference, and a charting dependency would be a package to keep current for
/// a polyline and two rectangles.
class _Mm3Painter extends CustomPainter {
  _Mm3Painter({
    required this.series,
    required this.bands,
    required this.line,
    required this.reference,
    required this.warning,
    required this.severe,
    required this.grid,
  });

  final Mm3Series series;
  final Mm3Bands bands;
  final Color line;
  final Color reference;
  final Color warning;
  final Color severe;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final points = series.points;
    if (points.length < 2) return;

    // The vertical range always contains both bands, so a well-levelled
    // sequence is not magnified into looking ragged.
    var low = 1 - bands.severe;
    var high = 1 + bands.severe;
    for (final point in points) {
      final value = point.movingAverage;
      if (value == null) continue;
      if (value < low) low = value;
      if (value > high) high = value;
    }
    final span = (high - low).abs() < 0.001 ? 1.0 : high - low;

    double y(double value) => size.height * (1 - (value - low) / span);
    double x(int index) =>
        points.length == 1 ? 0 : size.width * index / (points.length - 1);

    void band(double from, double to, Color colour) {
      canvas.drawRect(
        Rect.fromLTRB(0, y(to), size.width, y(from)),
        Paint()..color = colour.withValues(alpha: 0.10),
      );
    }

    band(1 - bands.severe, 1 + bands.severe, severe);
    band(1 - bands.warning, 1 + bands.warning, warning);

    canvas.drawLine(
      Offset(0, y(1)),
      Offset(size.width, y(1)),
      Paint()
        ..color = reference.withValues(alpha: 0.6)
        ..strokeWidth = 1,
    );

    final stroke = Paint()
      ..color = line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Broken where a point has no moving average, rather than bridged: a line
    // drawn across a gap claims a value that was never measured.
    Path? path;
    for (var i = 0; i < points.length; i++) {
      final value = points[i].movingAverage;
      if (value == null) {
        if (path != null) canvas.drawPath(path, stroke);
        path = null;
        continue;
      }
      final offset = Offset(x(i), y(value));
      if (path == null) {
        path = Path()..moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawCircle(offset, 2.5, Paint()..color = line);
    }
    if (path != null) canvas.drawPath(path, stroke);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = grid
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_Mm3Painter old) => old.series != series;
}
