import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatters.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/database.dart';
import '../../../data/database/staffing_codec.dart';
import '../../../common/dialogs.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../demand/application/demand_providers.dart';
import '../../demand/application/demand_table.dart' show demandTargetOf;
import '../../studies/application/studies_providers.dart';
import '../../summary/application/summary_providers.dart';
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
    final parts =
        ref.watch(demandPartsProvider(study.id)).value ?? const <DemandPart>[];
    // The view resolves "no choice made" to the first part; the picker has to
    // show the same one, or it would read as unset.
    final selectedPart =
        parts
            .where(
              (p) => p.id == ref.watch(selectedDemandPartProvider(study.id)),
            )
            .firstOrNull
            ?.id ??
        parts.firstOrNull?.id;

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
                      // The two demand sources need a part to read. Offered but
                      // not selectable until there is one, so the shape of the
                      // choice stays visible and the reason it is unavailable
                      // is in the tooltip rather than in a support call.
                      enabled: !source.isDemandPart || parts.isNotEmpty,
                      child: Tooltip(
                        message: !source.isDemandPart || parts.isNotEmpty
                            ? ''
                            : l10n.flowSourceNeedsDemand,
                        child: Text(flowDataSourceLabel(l10n, source)),
                      ),
                    ),
                ],
              ),
            ),
            // Which part, when the map is showing one. The weighted source
            // reads every part, so it needs no picker.
            if (source == FlowDataSource.singlePart && parts.isNotEmpty) ...[
              const SizedBox(width: 12),
              Text(l10n.flowPart, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedPart,
                  onChanged: (value) => ref
                      .read(selectedDemandPartProvider(study.id).notifier)
                      .select(value),
                  items: [
                    for (final part in parts)
                      DropdownMenuItem(
                        value: part.id,
                        child: Text(part.partNumber),
                      ),
                  ],
                ),
              ),
            ],
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

  /// The transform [_fit] last installed, or null before the first fit.
  ///
  /// This is how the canvas knows whether the view on screen is still its own
  /// doing: if the controller still holds exactly what was put there, nobody
  /// has zoomed or panned since, and the map is free to refit itself when the
  /// viewport changes. The moment it differs, the view belongs to the user and
  /// a sidebar toggle must not throw it away — which is the same complaint
  /// [_zoomBy] was written to answer, arriving from the other direction.
  ///
  /// Compared rather than tracked through gesture callbacks because
  /// `onInteractionEnd` fires for a bare tap that moved nothing, and a tap
  /// would then be enough to stop the map ever fitting again.
  Matrix4? _fitted;

  /// What the last fit was computed against, so a rebuild at an unchanged size
  /// does not refit — and so the post-frame fit below cannot loop.
  Size? _lastViewport;
  Size? _lastContent;

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
    final next = Matrix4.identity()
      ..translateByDouble(dx.clamp(0.0, double.infinity), 0, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    setState(() {
      _controller.value = next;
      // Cloned: the controller is free to mutate the matrix it was handed, and
      // a shared reference would compare equal to itself forever after.
      _fitted = next.clone();
    });
  }

  /// Renames one endpoint, leaving the other alone.
  ///
  /// `updateStudy` takes both names, so passing only the one that changed would
  /// null the other — the same shape of bug that left these fields unwritable
  /// in the first place (§17.5).
  Future<void> _renameEndpoint(
    WidgetRef ref, {
    String? supplier,
    String? customer,
    bool supplierGiven = false,
    bool customerGiven = false,
  }) {
    final study = widget.study;
    return ref
        .read(studiesRepositoryProvider)
        .updateStudy(
          study.id,
          name: study.name,
          supplierName: supplierGiven ? supplier : study.supplierName,
          customerName: customerGiven ? customer : study.customerName,
          wipCap: study.wipCap,
          priority: study.priority,
          notes: study.notes,
        );
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
    // The arrows now come from the layout, which knows what each of them is
    // (§5.2) and can be asserted without a frame.
    final layout = layoutFlow(view);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);

        // The sidebar is an `AnimatedSize` over 160 ms, so this runs at each
        // width along the way and the map follows the pane rather than
        // snapping after it.
        if (shouldRefitCanvas(
          viewport: viewport,
          content: layout.size,
          lastViewport: _lastViewport,
          lastContent: _lastContent,
          fitted: _fitted,
          current: _controller.value,
        )) {
          // Recorded before the frame, not inside it: two rebuilds at the same
          // size must schedule one fit, or the post-frame `setState` below
          // rebuilds into another fit and never stops.
          _lastViewport = viewport;
          _lastContent = layout.size;
          // After the frame: fitting calls setState, and a layout pass is not
          // a legal moment to do that.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fit(viewport, layout.size);
          });
        }
        return Stack(
          children: [
            Positioned.fill(
              child: _viewer(theme, layout, view, study),
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
                  connections: layout.connections,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: LeadTimeLadderPainter(
                  rungs: [for (final rung in layout.ladder) rung.rect],
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _Endpoint(
              rect: layout.supplier,
              label: view.study.supplierName ?? l10n.flowSupplier,
              onRename: (name) =>
                  _renameEndpoint(ref, supplier: name, supplierGiven: true),
            ),
            _Endpoint(
              rect: layout.customer,
              label: view.study.customerName ?? l10n.flowCustomer,
              onRename: (name) =>
                  _renameEndpoint(ref, customer: name, customerGiven: true),
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
///
/// One writer for both, so the field the caller does not name keeps its value
/// rather than being nulled by an update that was not about it.
class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.rect,
    required this.label,
    required this.onRename,
  });

  final Rect rect;
  final String label;

  /// Naming the real supplier and customer is the whole point of the fields
  /// (§16.2): they were stored and drawn from M2, and until now nothing could
  /// write them, so both endpoints always read their defaults.
  final ValueChanged<String?> onRename;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height + 24,
      child: Tooltip(
        message: l10n.flowEndpointRename,
        child: InkWell(
          onTap: () async {
            final name = await promptForName(
              context,
              title: l10n.flowEndpointRename,
              label: l10n.fieldName,
              initialValue: label,
            );
            // An emptied name puts the default back, rather than leaving a
            // blank factory nobody can click.
            if (name != null) onRename(name.trim().isEmpty ? null : name.trim());
          },
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
              Text(
                label,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
    final notes = step.node.notes;

    return Tooltip(
      // A note is the reader's own writing and outranks the box's description
      // of itself — but never a problem, which is a reason the map cannot be
      // trusted yet (§11).
      message: hasProblem
          ? _problemText(l10n, step.problems)
          : (notes?.isNotEmpty ?? false) ? notes! : _targetText(l10n, step),
      child: InkWell(
        onTap: () => showStepEditor(
          context,
          ref,
          study: study,
          step: step,
        ),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        step.title,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // A pool is several machines behind one box, and a reader
                    // comparing two boxes has to know which one is four
                    // stations. `#4` is how a shop floor writes it — drawn
                    // rather than chipped, so it is part of the map.
                    if (step.poolMemberCount != null) ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 22,
                        height: 16,
                        child: CustomPaint(
                          painter: _PoolBadgePainter(
                            count: step.poolMemberCount!,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                    // That there *is* a note has to be visible without
                    // hovering — a finding nobody can see is a finding nobody
                    // acts on. The words themselves are in the tooltip and on
                    // the PDF, because a box sized for eight data rows has no
                    // room for a paragraph.
                    if (notes?.isNotEmpty ?? false) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 14,
                        color: theme.colorScheme.tertiary,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  // The vertical half is what `FlowMetrics.nodeHeight` budgets
                  // for, so the two are the same number rather than two that
                  // happen to agree.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: FlowMetrics.nodeDataPadding,
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
                      // One takt of this station's own capacity (§6.1) — the
                      // yardstick the row above is measured against. Shown
                      // whatever the data source, so a part's process time can
                      // be read against the takt without changing anything;
                      // under the flow equivalent the two are the same number
                      // by construction, which is itself worth seeing.
                      _DataRow(
                        label: l10n.stepCycleTime,
                        value: step.equivalentProcessTime == null
                            ? '—'
                            : formatDurationHms(step.equivalentProcessTime!),
                      ),
                      // How many takts of this station's capacity the part
                      // actually consumes (DESIGN.md §6.2). Only under a demand
                      // source: the equivalent's own equivalence is 1.00 by
                      // construction, and a row of ones says nothing.
                      if (step.dataSource.isDemandPart)
                        _DataRow(
                          label: l10n.stepEquivalence,
                          value: step.equivalence == null
                              ? '—'
                              : step.equivalence!.toStringAsFixed(2),
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
                      // Required hours over available productive hours for
                      // the period (§8.1). It comes from the Summary because
                      // that is the only thing that knows what demand asks of
                      // this station; a station two steps both visit reports
                      // the load of both, because it is one machine.
                      _DataRow(
                        label: l10n.occupation,
                        value: _occupation(ref, step),
                        warning: (_occupationValue(ref, step) ?? 0) > 1,
                      ),
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

  double? _occupationValue(WidgetRef ref, FlowStepView step) {
    final targetId = demandTargetOf(step.node);
    if (targetId == null) return null;
    return ref
        .watch(summaryViewProvider(study.id))
        ?.occupationByTarget[targetId];
  }

  String _occupation(WidgetRef ref, FlowStepView step) {
    final value = _occupationValue(ref, step);
    // A dash, never a zero: a station nobody has given demand to is not idle,
    // it is unmeasured, and the two must not look alike.
    return value == null ? '—' : '${(value * 100).round()}%';
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
            StepProblem.noProcessTime => l10n.stepProblemNoProcessTime,
          },
        )
        .join('\n');
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;

  /// Colours the value, for the one figure on the box that can be a hard
  /// constraint: occupation above 100 % (DESIGN.md §8.1).
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label, style: style, overflow: TextOverflow.ellipsis),
          ),
          Text(
            value,
            style: warning
                ? style?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  )
                : style,
          ),
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
    final notes = buffer.node.notes;
    return Tooltip(
      message: (notes?.isNotEmpty ?? false) ? notes! : '',
      child: InkWell(
      onTap: () =>
          showInventoryEditor(context, ref, study: study, buffer: buffer),
      // A Stack rather than a Column: the triangle has to sit *on* the spine,
      // and a centred column of symbol-plus-two-labels puts its middle above
      // the line the arrows run along.
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: FlowMetrics.bufferSymbol,
            height: FlowMetrics.bufferSymbol,
          ),
          Center(
            child: SizedBox(
              width: FlowMetrics.bufferSymbol,
              height: FlowMetrics.bufferSymbol,
              child: CustomPaint(
                painter: _TrianglePainter(color: theme.colorScheme.onSurface),
              ),
            ),
          ),
          Positioned(
            top: FlowMetrics.nodeHeight / 2 + FlowMetrics.bufferSymbol / 2 + 4,
            left: 0,
            right: 0,
            child: Column(
              children: [
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
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Same marker as a process box carries, in the triangle's own
          // corner: a buffer is exactly where a walk finds something to say.
          if (notes?.isNotEmpty ?? false)
            Positioned(
              top: FlowMetrics.nodeHeight / 2 - FlowMetrics.bufferSymbol / 2,
              right: FlowMetrics.bufferInset - 14,
              child: Icon(
                Icons.sticky_note_2_outlined,
                size: 14,
                color: theme.colorScheme.tertiary,
              ),
            ),
        ],
      ),
      ),
    );
  }
}

class _PoolBadgePainter extends CustomPainter {
  const _PoolBadgePainter({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the stroke so the square's edge lands inside the box
    // rather than being clipped in half by it.
    VsmSymbols.drawPoolBadge(
      canvas,
      Rect.fromLTWH(0.6, 0.6, size.width - 1.2, size.height - 1.2),
      count,
      color: color,
    );
  }

  @override
  bool shouldRepaint(_PoolBadgePainter old) =>
      old.count != count || old.color != color;
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
            // Two lead times, and the second is the first restated. The map
            // states the seven-over-five planning convention rather than
            // measuring the calendar — a walk was built first and rejected in
            // use, and `FlowView.runningDayFactor` records why.
            //
            // Both render against the same working-day divisor, so the running
            // figure reads as exactly 1.4× the working one and a reader can
            // check it. PCE divides the working figure, which is also on
            // screen, so that stays checkable too.
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
              label: l10n.footerLeadTimeRunning,
              value: formatAdaptiveDuration(
                l10n,
                view!.leadTimeInRunningDays,
                workingDay: view!.leadTimeWorkingDay,
              ),
              help: l10n.footerLeadTimeRunningHelp,
            ),
            if (view!.flowEquivalence != null)
              _Metric(
                label: l10n.footerEquivalence,
                value: view!.flowEquivalence!.toStringAsFixed(2),
                help: l10n.footerEquivalenceHelp,
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
