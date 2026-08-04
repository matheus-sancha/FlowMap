import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../common/formatters.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/database.dart';
import '../../../data/database/staffing_codec.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/flow_layout.dart';
import '../application/flow_providers.dart';
import '../application/flow_view.dart';
import 'flow_node_editor.dart';
import 'flow_pdf.dart';
import 'period_label.dart';
import 'vsm_symbols.dart';

/// The VSM canvas (DESIGN.md §5, §12.2).
///
/// Nodes are widgets positioned by [layoutFlow]; the arrows and the lead-time
/// ladder are painted behind them. Nothing here computes a number — every
/// figure comes from [FlowView], which the PDF renders from too.
class FlowTab extends ConsumerWidget {
  const FlowTab({super.key, required this.study});

  final Study study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(flowViewProvider(study.id));

    return Column(
      children: [
        _Toolbar(study: study),
        const Divider(height: 1),
        Expanded(
          child: flow.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('$error')),
            data: (view) => view == null
                ? const SizedBox.shrink()
                : _Canvas(view: view, study: study),
          ),
        ),
        const Divider(height: 1),
        _FooterMetrics(view: flow.value),
      ],
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.study});

  final Study study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final period = ref.watch(viewedPeriodProvider(study.id));
    final source = ref.watch(flowDataSourceSelectionProvider(study.id));
    final view = ref.watch(flowViewProvider(study.id)).value;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: l10n.periodPrevious,
              icon: const Icon(Icons.chevron_left),
              onPressed: () =>
                  ref.read(viewedPeriodProvider(study.id).notifier).previous(),
            ),
            // Every number on the map is period-dependent, so the period is
            // part of the map's identity, not a filter.
            SizedBox(
              width: 96,
              child: Text(
                periodLabel(context, period.anchor, period.granularity),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: l10n.periodNext,
              icon: const Icon(Icons.chevron_right),
              onPressed: () =>
                  ref.read(viewedPeriodProvider(study.id).notifier).next(),
            ),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<PeriodGranularity>(
                value: period.granularity,
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(viewedPeriodProvider(study.id).notifier)
                        .setGranularity(value);
                  }
                },
                items: [
                  for (final granularity in PeriodGranularity.values)
                    DropdownMenuItem(
                      value: granularity,
                      child: Text(granularityLabel(l10n, granularity)),
                    ),
                ],
              ),
            ),
            if (view?.scheduleVariesInPeriod ?? false)
              Tooltip(
                message: l10n.periodVariesHelp,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ),
            const SizedBox(width: 16),
            Text(
              l10n.flowDataSource,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<FlowDataSource>(
                value: source,
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(
                          flowDataSourceSelectionProvider(study.id).notifier,
                        )
                        .select(value);
                  }
                },
                items: [
                  for (final source in FlowDataSource.values)
                    DropdownMenuItem(
                      value: source,
                      // The other two are offered but not selectable: both need
                      // the demand table, which arrives in M3. Showing them
                      // keeps the shape of the choice visible instead of adding
                      // it later as a surprise.
                      enabled: source == FlowDataSource.flowEquivalent,
                      child: Text(flowDataSourceLabel(l10n, source)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: view == null
                  ? null
                  : () => exportFlowPdf(context, ref, view: view),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(l10n.exportPdf),
            ),
          ],
        ),
      ),
    );
  }
}

class _Canvas extends ConsumerStatefulWidget {
  const _Canvas({required this.view, required this.study});

  final FlowView view;
  final Study study;

  @override
  ConsumerState<_Canvas> createState() => _CanvasState();
}

class _CanvasState extends ConsumerState<_Canvas> {
  /// Owned here rather than by the toolbar: the transform belongs to the
  /// viewport, and fit-to-screen needs the viewport's measured size.
  final _controller = TransformationController();

  /// Set once the first layout is known, so a map opens fitted rather than at
  /// 100 % with its right-hand steps off-screen.
  bool _fittedOnce = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scales the whole map to [viewport], centred, capped at 100 %.
  ///
  /// Capped because scaling a six-step flow up to fill a wide screen makes the
  /// boxes cartoonish without showing anything more.
  void _fit(Size viewport, Size content) {
    if (content.width <= 0 || content.height <= 0) return;
    final scale = (viewport.width / content.width).clamp(0.1, 1.0).toDouble();
    final dx = (viewport.width - content.width * scale) / 2;
    setState(() {
      _controller.value = Matrix4.identity()
        ..translateByDouble(dx.clamp(0.0, double.infinity), 0, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    });
  }

  /// Zooms about the centre of [viewport], keeping what is under it there.
  ///
  /// Rebuilt from the current scale rather than from identity: starting over
  /// threw the pan away, so zooming in on the sixth step of a flow jumped back
  /// to the first. The translation correction is what keeps the centred point
  /// fixed — scaling alone moves everything away from the canvas origin.
  void _zoomBy(double factor, Size viewport) {
    final current = _controller.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.2, 3.0);
    if (next == current) return;

    final translation = _controller.value.getTranslation();
    final centre = Offset(viewport.width / 2, viewport.height / 2);
    // Where the viewport's centre falls in canvas coordinates now, and what the
    // translation has to be for it to fall there again at the new scale.
    final focus = (centre - Offset(translation.x, translation.y)) / current;
    final dx = centre.dx - focus.dx * next;
    final dy = centre.dy - focus.dy * next;

    setState(() {
      _controller.value = Matrix4.identity()
        ..translateByDouble(dx, dy, 0, 1)
        ..scaleByDouble(next, next, 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final view = widget.view;
    final study = widget.study;
    final layout = layoutFlow(view);

    final segments = <(Offset, Offset)>[];
    var previousRight = Offset(layout.supplier.right, layout.spineY);
    for (final placed in layout.nodes) {
      segments.add((previousRight, Offset(placed.rect.left, layout.spineY)));
      previousRight = Offset(placed.rect.right, layout.spineY);
    }
    segments.add((previousRight, Offset(layout.customer.left, layout.spineY)));

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_fittedOnce && viewport.width.isFinite && viewport.width > 0) {
          _fittedOnce = true;
          // After the frame: fitting calls setState, and the first layout pass
          // is not a legal moment to do that.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fit(viewport, layout.size);
          });
        }
        return Stack(
          children: [
            Positioned.fill(
              child: _viewer(theme, layout, segments, view, study),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _ZoomControls(
                onFit: () => _fit(viewport, layout.size),
                onZoomIn: () => _zoomBy(1.25, viewport),
                onZoomOut: () => _zoomBy(0.8, viewport),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _viewer(
    ThemeData theme,
    FlowLayout layout,
    List<(Offset, Offset)> segments,
    FlowView view,
    Study study,
  ) {
    final l10n = AppLocalizations.of(context);
    return InteractiveViewer(
      constrained: false,
      transformationController: _controller,
      minScale: 0.2,
      maxScale: 3,
      boundaryMargin: const EdgeInsets.all(200),
      child: SizedBox(
        width: layout.size.width,
        height: layout.size.height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: FlowConnectionsPainter(
                  segments: segments,
                  color: theme.colorScheme.onSurfaceVariant,
                  ladderColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: LeadTimeLadderPainter(
                  rungs: [
                    for (final rung in layout.ladder)
                      (rung.rect, rung.isWaiting),
                  ],
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _Endpoint(
              rect: layout.supplier,
              label: view.study.supplierName ?? l10n.flowSupplier,
            ),
            _Endpoint(
              rect: layout.customer,
              label: view.study.customerName ?? l10n.flowCustomer,
            ),
            for (final placed in layout.nodes)
              Positioned(
                left: placed.rect.left,
                top: placed.rect.top,
                width: placed.rect.width,
                height: placed.rect.height,
                child: switch (placed.view) {
                  final FlowStepView step => _StepBox(
                    step: step,
                    study: study,
                    layout: layout,
                  ),
                  final FlowInventoryView buffer => _InventoryNode(
                    buffer: buffer,
                    study: study,
                  ),
                },
              ),
            for (final insertion in layout.insertionPoints)
              Positioned(
                left: insertion.center.x - 18,
                top: insertion.center.y - 18,
                width: 36,
                height: 36,
                child: _InsertButton(
                  study: study,
                  position: insertion.position,
                ),
              ),
            // Centred over the rung it belongs to: a left-aligned label sits
            // under the previous step and reads as that step's time.
            for (final rung in layout.ladder)
              Positioned(
                left: rung.rect.left,
                top: rung.rect.top - 20,
                width: rung.rect.width,
                child: Text(
                  formatAdaptiveDuration(
                    l10n,
                    rung.duration,
                    workingDay: rung.referenceWorkingDay,
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Supplier and customer: the same factory symbol, told apart by position.
class _Endpoint extends StatelessWidget {
  const _Endpoint({required this.rect, required this.label});

  final Rect rect;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height + 24,
      child: Column(
        children: [
          SizedBox(
            width: rect.width,
            height: rect.height,
            child: CustomPaint(
              painter: _FactoryPainter(color: theme.colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FactoryPainter extends CustomPainter {
  const _FactoryPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      VsmSymbols.factory(Offset.zero & size),
      Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_FactoryPainter old) => old.color != color;
}

/// A process box: header, then the data rows of the mockup.
class _StepBox extends ConsumerWidget {
  const _StepBox({
    required this.step,
    required this.study,
    required this.layout,
  });

  final FlowStepView step;
  final Study study;
  final FlowLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasProblem = step.problems.isNotEmpty;

    return Tooltip(
      message: hasProblem
          ? _problemText(l10n, step.problems)
          : _targetText(l10n, step),
      child: InkWell(
        onTap: () => showStepEditor(context, ref, study: study, step: step),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: hasProblem
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
              width: hasProblem ? 1.6 : 1,
            ),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: FlowMetrics.nodeHeaderHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.colorScheme.outline),
                  ),
                ),
                child: Text(
                  step.title,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      _DataRow(
                        // A step whose equivalent is its own, not one takt,
                        // is marked — a reader comparing two boxes has to know
                        // one of them is not measured in takts.
                        label: step.usesLocalEquivalent
                            ? '${l10n.stepProcessTime} *'
                            : l10n.stepProcessTime,
                        value: step.processTime == null
                            ? '—'
                            : formatDurationHms(step.processTime!),
                      ),
                      _DataRow(
                        label: l10n.stepChangeover,
                        value: formatDurationHms(step.changeover),
                      ),
                      _DataRow(
                        label: l10n.availability,
                        value: step.availability == null
                            ? '—'
                            : '${(step.availability! * 100).round()}%',
                      ),
                      _DataRow(
                        label: l10n.stepOperators,
                        value: step.operatorsPerShift.isEmpty
                            ? '—'
                            : formatOperatorsPerShift(step.operatorsPerShift),
                      ),
                      _DataRow(
                        label: l10n.scheduleShifts,
                        value: step.operatorsPerShift.isEmpty
                            ? '—'
                            : '${step.staffedShiftCount}',
                      ),
                      // Occupation needs demand to divide into capacity, so it
                      // stays a dash until M3 rather than showing a zero
                      // someone might read as "idle".
                      _DataRow(label: l10n.occupation, value: '—'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// What the box is, beyond what it is called: the workcenter's type, or how
  /// many workcenters a pool holds.
  ///
  /// The name itself is already the box's header, so repeating it in the
  /// tooltip would answer a question nobody asked.
  static String _targetText(AppLocalizations l10n, FlowStepView step) {
    if (step.poolMemberCount != null) {
      return l10n.stepPoolMembers('${step.poolMemberCount}');
    }
    return step.typeName ?? l10n.workcenterTypeUnset;
  }

  static String _problemText(
    AppLocalizations l10n,
    List<StepProblem> problems,
  ) {
    return problems
        .map(
          (problem) => switch (problem) {
            StepProblem.unbound => l10n.stepProblemUnbound,
            StepProblem.archivedTarget => l10n.stepProblemArchived,
            StepProblem.noSchedule => l10n.stepProblemNoSchedule,
            StepProblem.emptyPool => l10n.stepProblemEmptyPool,
          },
        )
        .join('\n');
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label, style: style, overflow: TextOverflow.ellipsis),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _InventoryNode extends ConsumerWidget {
  const _InventoryNode({required this.buffer, required this.study});

  final FlowInventoryView buffer;
  final Study study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () =>
          showInventoryEditor(context, ref, study: study, buffer: buffer),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _TrianglePainter(color: theme.colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            buffer.quantity == null ? '' : '${buffer.quantity}',
            style: theme.textTheme.titleSmall,
          ),
          Text(
            // The same rendering as this node's own rung on the ladder
            // directly below it. Showing the value as typed instead put two
            // different numbers for one wait on the screen at once.
            buffer.label.isNotEmpty
                ? buffer.label
                : formatAdaptiveDuration(
                    l10n,
                    buffer.wait,
                    workingDay: buffer.referenceWorkingDay,
                  ),
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      VsmSymbols.inventoryTriangle(Offset.zero & size),
      Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

/// Fit-to-screen and zoom, floating over the bottom-right of the canvas.
///
/// Over the canvas rather than in the toolbar: they act on what is under them,
/// and a map wide enough to need them is a map whose toolbar has scrolled out
/// of reach.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onFit,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onFit;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.flowZoomOut,
              icon: const Icon(Icons.zoom_out),
              onPressed: onZoomOut,
            ),
            IconButton(
              tooltip: l10n.flowZoomIn,
              icon: const Icon(Icons.zoom_in),
              onPressed: onZoomIn,
            ),
            TextButton.icon(
              onPressed: onFit,
              icon: const Icon(Icons.fit_screen_outlined),
              label: Text(l10n.flowFitToScreen),
            ),
          ],
        ),
      ),
    );
  }
}

/// The `+ Insert here` affordance between two nodes (DESIGN.md §5.3).
class _InsertButton extends ConsumerWidget {
  const _InsertButton({required this.study, required this.position});

  final Study study;
  final int position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.flowInsertHere,
      child: Material(
        color: Theme.of(context).colorScheme.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showInsertNodeMenu(
            context,
            ref,
            study: study,
            position: position,
          ),
          child: Icon(
            Icons.add,
            size: 18,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// The metrics band along the bottom of the mockup.
class _FooterMetrics extends StatelessWidget {
  const _FooterMetrics({required this.view});

  final FlowView? view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (view == null) return const SizedBox(height: 56);

    final takt = view!.takt;
    return Container(
      height: 56,
      color: theme.colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 16),
            _Metric(
              label: l10n.takt,
              value: takt == null
                  ? '—'
                  : '${_number(takt.value)} ${taktUnitShort(l10n, takt.unit)}',
              help: l10n.footerTaktHelp,
              warning: view!.taktMissing,
            ),
            // Measured in the same days as the rungs above them, so the footer
            // is the sum of the ladder rather than a second opinion about it
            // (DESIGN.md §17.4).
            _Metric(
              label: l10n.footerProcessTime,
              value: formatAdaptiveDuration(
                l10n,
                view!.processTime,
                workingDay: view!.processTimeWorkingDay,
              ),
              help: l10n.footerProcessTimeHelp,
            ),
            _Metric(
              label: l10n.footerLeadTime,
              value: formatAdaptiveDuration(
                l10n,
                view!.leadTime,
                workingDay: view!.leadTimeWorkingDay,
              ),
              help: l10n.footerLeadTimeHelp,
            ),
            _Metric(
              label: l10n.footerEndDate,
              value: view!.runningDays == null
                  ? '—'
                  : l10n.footerRunningDays(
                      '${view!.runningDays}',
                      DateFormat.yMMMd(
                        Localizations.localeOf(context).toString(),
                      ).format(view!.endDate!),
                    ),
              help: l10n.footerEndDateHelp,
            ),
            _Metric(
              label: l10n.footerPce,
              value:
                  '${(view!.processCycleEfficiency * 100).toStringAsFixed(1)}%',
              help: l10n.footerPceHelp,
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  /// `3` rather than `3.0` — a takt is written the way it is spoken.
  static String _number(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.help,
    this.warning = false,
  });

  final String label;
  final String value;

  /// What the figure means, on hover. These are derived numbers whose
  /// definitions are decisions (DESIGN.md §6.1, §8) — a label alone leaves the
  /// reader guessing which of several plausible readings is meant.
  final String help;

  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: help,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            Text(
              value,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: warning ? theme.colorScheme.error : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
