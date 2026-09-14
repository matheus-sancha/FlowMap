import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../app/build_info.dart';
import '../../../common/date_style_scope.dart';
import '../../../common/pdf_document.dart';
import '../../../common/unit_labels.dart';
import '../../../common/vector_pen.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../diagnostics/application/diagnostics.dart';
import '../application/occupation_graph.dart';
import '../application/run_filter.dart';
import '../application/run_report.dart';
import 'occupation_chart_scale.dart';

/// The simulation report, already worded (DESIGN.md §13, #27).
///
/// **Every string is set before the document is built**, as `FlowPdfStrings`
/// does for the map: `AppLocalizations` is read from a `BuildContext`, and the
/// document is built off the widget tree. What is *ranked and listed* is decided
/// in `run_report.dart`; this only carries the words.
class RunReport {
  const RunReport({
    required this.title,
    required this.subtitle,
    required this.generated,
    required this.inputsHeading,
    required this.inputs,
    required this.headline,
    required this.metrics,
    required this.rankingHeading,
    required this.rankingColumns,
    required this.ranking,
    required this.occupationHeading,
    required this.chart,
    required this.lateHeading,
    required this.lateColumns,
    required this.late,
    required this.noneLate,
  });

  final String title;
  final String subtitle;
  final String generated;

  final String inputsHeading;

  /// One line per study the slice covers, and the run's caveats after them.
  final List<String> inputs;

  /// `On-time delivery: 72 %` — §8's verdict, set largest.
  final String headline;
  final List<(String label, String value)> metrics;

  final String rankingHeading;
  final List<String> rankingColumns;
  final List<List<String>> ranking;

  final String occupationHeading;

  /// Null on a run that cannot draw one (before v25), and the heading goes too.
  final RunReportChart? chart;

  final String lateHeading;
  final List<String> lateColumns;
  final List<List<String>> late;
  final String noneLate;
}

/// The occupation chart, as data a page can draw without a `BuildContext`.
class RunReportChart {
  const RunReportChart({
    required this.months,
    required this.scale,
    required this.legendDemand,
    required this.legendCapacity,
    required this.hoursUnit,
  });

  /// Label, demand and capacity per month, in order.
  final List<({String label, int demand, int capacity})> months;
  final ChartScale scale;
  final String legendDemand;
  final String legendCapacity;

  /// `h`, set once under the axis rather than on every tick.
  final String hoursUnit;
}

/// Words the report for [slice] and asks where to put it.
///
/// **The slice, not the run** — the button sits over a filtered view and
/// reports that view, as the plan's Excel button does (§12.1).
Future<void> exportRunReport(
  BuildContext context, {
  required FilteredRun slice,
  required String projectName,
}) async {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  final dateStyle = DateStyleScope.of(context);
  final timestamp = DateFormat.yMd(locale).add_Hm();
  final report = runReportFor(
    slice: slice,
    projectName: projectName,
    l10n: l10n,
    locale: locale,
    date: dateStyle.format,
    now: timestamp.format(DateTime.now()),
  );

  final bytes = await buildRunReportPdf(
    theme: await loadPdfTheme(),
    report: report,
  );

  final location = await getSaveLocation(
    suggestedName:
        '${projectName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')} — '
        '${l10n.simReport}.pdf',
    acceptedTypeGroups: const [
      XTypeGroup(label: 'PDF', extensions: ['pdf']),
    ],
  );
  if (location == null) return;

  await XFile.fromData(
    bytes,
    mimeType: 'application/pdf',
  ).saveTo(location.path);
  Diag.event('sim.report', 'late ${report.late.length}');

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.exportSaved(location.path))));
  }
}

/// Words a [RunReport] for [slice]. Public so a test can word one with real
/// localizations and a fixed clock.
RunReport runReportFor({
  required FilteredRun slice,
  required String projectName,
  required AppLocalizations l10n,
  required String locale,
  required String Function(DateTime? date) date,
  required String now,
}) {
  final run = slice.run;
  final metrics = slice.metrics;
  String duration(Duration? value) =>
      value == null ? '—' : formatAdaptiveDuration(l10n, value);
  String percent(double? value) =>
      value == null ? '—' : '${(value * 100).toStringAsFixed(0)}%';

  final queues = runQueueLabel(l10n, run.queues);
  final created = date(run.createdAt);
  final names = {for (final s in run.studies) s.studyId: s.name};

  final graph = occupationGraph(run: run, filter: slice.filter);
  final monthLabel = DateFormat.yMMM(locale);

  return RunReport(
    title: '${l10n.simReport} · $projectName',
    subtitle: queues == null ? created : l10n.simRunLabel(created, queues),
    generated: l10n.exportGenerated(kBuildLabel, now),
    inputsHeading: l10n.simReportInputs,
    inputs: [
      l10n.simRunSpan(date(run.result.start), date(run.result.end)),
      for (final study in run.studies)
        if (slice.studyIds.isEmpty || slice.studyIds.contains(study.studyId))
          [
            qualifiedStudyLabel(
              study.name,
              study.productionCellName,
              study.productionLineName,
            ),
            '${l10n.studyWipCap}: '
                '${study.wipCap == null ? l10n.studyWipCapUnlimited : '${study.wipCap}'}',
            if (study.startBufferDays > 0)
              '${l10n.studyStartBuffer}: ${study.startBufferDays}',
          ].join('  ·  '),
      if (run.queues.isMixed)
        [
          for (final workcenter in run.queues.workcenters)
            l10n.simRunQueueRow(
              workcenter.name,
              dispatchRuleLabel(l10n, workcenter.rule),
            ),
        ].join('  ·  '),
    ],
    headline: '${l10n.simOnTimeDelivery}: ${percent(metrics.onTimeDelivery)}',
    metrics: [
      (
        l10n.simOnTimeDelivery,
        l10n.simOnTimeOfOrders('${metrics.onTime}', '${metrics.orders}'),
      ),
      (
        l10n.simDelivered,
        l10n.simDeliveredOf('${metrics.delivered}', '${metrics.orders}'),
      ),
      (l10n.simAverageFloat, duration(metrics.averageFloat)),
      (l10n.simAverageLeadTime, duration(metrics.averageLeadTime)),
      (l10n.simTheoreticalLeadTime, duration(metrics.theoreticalLeadTime)),
      (l10n.simLeadTimeEfficiency, percent(metrics.leadTimeEfficiency)),
      (l10n.simEmptySlots, '${metrics.emptySlots}'),
    ],
    rankingHeading: l10n.simByQueue,
    rankingColumns: [
      l10n.workcenter,
      l10n.utilization,
      l10n.simQueue,
      l10n.simQueueAverage,
      l10n.simShareOfFlow,
    ],
    ranking: [
      for (final w in bottleneckRanking(metrics))
        [
          w.name,
          percent(w.utilization),
          duration(w.queueTime),
          duration(w.averageQueue),
          percent(metrics.shareOfFlow(w)),
        ],
    ],
    occupationHeading: l10n.occupation,
    chart: graph == null || graph.isEmpty
        ? null
        : RunReportChart(
            months: [
              for (final month in graph.months)
                (
                  label: monthLabel.format(month.month),
                  demand: month.total.inSeconds,
                  capacity: month.capacity.inSeconds,
                ),
            ],
            scale: chartScaleFor(graph, locale),
            legendDemand: l10n.occupationTipDemand,
            legendCapacity: l10n.occupationTipCapacity,
            hoursUnit: l10n.unitHoursShort,
          ),
    lateHeading: l10n.simReportLateOrders,
    lateColumns: [
      l10n.simPlanStudy,
      l10n.simPlanOrder,
      l10n.demandPartNumber,
      l10n.demandNeedDate,
      l10n.simPlanOrderEnd,
      l10n.simAverageFloat,
    ],
    late: [
      for (final row in lateOrders(slice.plan))
        [
          names[row.studyId] ?? '—',
          '${row.orderNumber}',
          row.partNumber,
          date(row.outcome.needDate),
          row.delivery == null
              ? l10n.simReportNotDelivered
              : date(row.delivery),
          duration(row.float),
        ],
    ],
    noneLate: l10n.simReportNoneLate,
  );
}

/// Builds the document. Separated from the dialog so it renders in a test.
///
/// **A4 portrait, flowing over pages**: a late-order list can be a hundred
/// rows, and `MultiPage` breaks a table where a single `Page` would throw.
Future<Uint8List> buildRunReportPdf({
  required pw.ThemeData theme,
  required RunReport report,
}) async {
  final document = pw.Document(title: report.title, theme: theme);

  pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget table(List<String> columns, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headers: columns,
        data: rows,
        headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        headerAlignment: pw.Alignment.centerLeft,
        cellAlignment: pw.Alignment.centerLeft,
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(width: 0.3, color: PdfColors.grey400),
        ),
      );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pdfHeader(title: report.title, subtitle: report.subtitle),
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pdfStamp(report.generated),
          pdfStamp('${context.pageNumber} / ${context.pagesCount}'),
        ],
      ),
      build: (context) => [
        pw.Text(
          report.headline,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        for (final (label, value) in report.metrics)
          pw.Row(
            children: [
              pw.SizedBox(
                width: 160,
                child: pw.Text(
                  label,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        heading(report.inputsHeading),
        for (final line in report.inputs)
          pw.Text(line, style: const pw.TextStyle(fontSize: 8)),
        if (report.ranking.isNotEmpty) ...[
          heading(report.rankingHeading),
          table(report.rankingColumns, report.ranking),
        ],
        if (report.chart case final chart?) ...[
          heading(report.occupationHeading),
          _chart(chart),
        ],
        heading(report.lateHeading),
        if (report.late.isEmpty)
          pw.Text(report.noneLate, style: const pw.TextStyle(fontSize: 9))
        else
          table(report.lateColumns, report.late),
      ],
    ),
  );

  return document.save();
}

/// Demand as bars, capacity as a line per month, on the screen's own scale.
///
/// **`chartScaleFor` and `hoursTicks`, not a second derivation** — the reason
/// they were public before this page existed. Demand is the whole bar the
/// screen stacks (process, rework, changeover and anything a filter left out);
/// on paper the split is one colour, because a greyscale printer cannot keep
/// four segments apart.
pw.Widget _chart(RunReportChart chart) {
  const height = 180.0;
  const plotWidth = 440.0;
  const axisWidth = 44.0;
  final scale = chart.scale;
  final slot = plotWidth / chart.months.length;
  const barColor = Color(0xFF1F5C8B);
  const over = Color(0xFFB3261E);
  const ink = Color(0xFF000000);

  // Month labels thin out so they never collide: about 40 points each.
  final every = (40 / slot).ceil().clamp(1, chart.months.length);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        height: height,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: axisWidth,
              height: height,
              child: pw.Stack(
                children: [
                  pw.Positioned(
                    right: 6,
                    top: 0,
                    child: pw.Text(
                      chart.hoursUnit,
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ),
                  for (final tick in scale.ticks)
                    pw.Positioned(
                      right: 6,
                      top: scale.y(height, tick.seconds) - 5,
                      child: pw.Text(
                        tick.label,
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(
              width: plotWidth,
              height: height,
              child: pw.Stack(
                children: [
                  pw.Positioned.fill(
                    child: pw.CustomPaint(
                      size: const PdfPoint(plotWidth, height),
                      painter: (canvas, size) {
                        final pen = PdfPen(canvas, size.y);
                        final floor = scale.floorOf(height);
                        for (final tick in scale.ticks) {
                          final y = scale.y(height, tick.seconds);
                          pen.line(
                            Offset(0, y),
                            Offset(plotWidth, y),
                            const Color(0x33000000),
                            0.4,
                          );
                        }
                        for (var i = 0; i < chart.months.length; i++) {
                          final month = chart.months[i];
                          final left = i * slot + slot * 0.18;
                          final right = (i + 1) * slot - slot * 0.18;
                          final top = scale.y(height, month.demand);
                          if (month.demand > 0) {
                            pen
                              ..rect(Rect.fromLTRB(left, top, right, floor))
                              ..fill(
                                month.capacity > 0 &&
                                        month.demand > month.capacity
                                    ? over
                                    : barColor,
                              );
                          }
                          final line = scale.y(height, month.capacity);
                          pen.line(
                            Offset(i * slot + 1, line),
                            Offset((i + 1) * slot - 1, line),
                            ink,
                            1.2,
                          );
                        }
                        pen.line(
                          Offset(0, floor),
                          Offset(plotWidth, floor),
                          ink,
                          0.6,
                        );
                      },
                    ),
                  ),
                  // In the axis band the scale reserves under the floor, so a
                  // label sits beneath its own bar. Thinned to about one per 40
                  // points so they never collide.
                  for (var i = 0; i < chart.months.length; i += every)
                    pw.Positioned(
                      left: i * slot,
                      top: scale.floorOf(height) + 4,
                      child: pw.Text(
                        chart.months[i].label,
                        style: const pw.TextStyle(fontSize: 6),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      pw.Row(
        children: [
          pw.SizedBox(width: axisWidth),
          pw.Container(width: 10, height: 6, color: PdfColors.blue900),
          pw.SizedBox(width: 4),
          pw.Text(chart.legendDemand, style: const pw.TextStyle(fontSize: 7)),
          pw.SizedBox(width: 12),
          pw.Container(width: 14, height: 1.2, color: PdfColors.black),
          pw.SizedBox(width: 4),
          pw.Text(chart.legendCapacity, style: const pw.TextStyle(fontSize: 7)),
        ],
      ),
    ],
  );
}
