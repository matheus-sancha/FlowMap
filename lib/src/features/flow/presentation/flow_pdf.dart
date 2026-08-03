import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../app/build_info.dart';
import '../../../common/unit_labels.dart';
import '../../../data/database/staffing_codec.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../diagnostics/application/diagnostics.dart';
import '../application/flow_view.dart';

/// The strings the PDF needs, captured before the export goes async.
///
/// `AppLocalizations` is read from a `BuildContext`, and the document is built
/// off the widget tree — so the labels come along as data rather than the
/// renderer holding a context it should not outlive.
class FlowPdfStrings {
  const FlowPdfStrings({
    required this.title,
    required this.period,
    required this.supplier,
    required this.customer,
    required this.processTime,
    required this.changeover,
    required this.availability,
    required this.operators,
    required this.shifts,
    required this.takt,
    required this.leadTime,
    required this.pce,
    required this.generated,
    required this.dataSource,
    required this.taktValue,
  });

  /// The takt already rendered — `3 days` — because the unit's localized name
  /// needs a `BuildContext` the document builder does not have.
  final String taktValue;

  final String title;
  final String period;
  final String supplier;
  final String customer;
  final String processTime;
  final String changeover;
  final String availability;
  final String operators;
  final String shifts;
  final String takt;
  final String leadTime;
  final String pce;
  final String generated;
  final String dataSource;
}

/// Renders the map to a PDF and asks where to put it.
///
/// Not a screenshot of the canvas: the same [FlowView] is drawn again with the
/// `pdf` package's own layout, so text stays selectable, lines stay vector, and
/// the file is legible at any zoom (DESIGN.md §12.2, §13).
Future<void> exportFlowPdf(
  BuildContext context,
  WidgetRef ref, {
  required FlowView view,
}) async {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  final months = DateFormat.yMMMM(locale);
  final timestamp = DateFormat.yMd(locale).add_Hm();

  final strings = FlowPdfStrings(
    title: view.study.name,
    period: months.format(view.asOf),
    supplier: view.study.supplierName ?? l10n.flowSupplier,
    customer: view.study.customerName ?? l10n.flowCustomer,
    processTime: l10n.stepProcessTime,
    changeover: l10n.stepChangeover,
    availability: l10n.availability,
    operators: l10n.stepOperators,
    shifts: l10n.scheduleShifts,
    takt: l10n.takt,
    leadTime: l10n.footerLeadTime,
    pce: l10n.footerPce,
    generated: l10n.pdfGenerated(kBuildLabel, timestamp.format(DateTime.now())),
    dataSource: l10n.flowSourceEquivalent,
    taktValue: view.takt == null
        ? '—'
        : '${view.takt!.value} ${taktUnitLabel(l10n, view.takt!.unit)}',
  );

  // The same rendering the screen uses, so an exported map and the app never
  // state the same duration two different ways.
  final bytes = await buildFlowPdf(
    view: view,
    strings: strings,
    formatDuration: (duration) => formatAdaptiveDuration(l10n, duration),
  );

  final location = await getSaveLocation(
    suggestedName: '${_safeFileName(view.study.name)}.pdf',
    acceptedTypeGroups: const [
      XTypeGroup(label: 'PDF', extensions: ['pdf']),
    ],
  );
  if (location == null) return;

  await XFile.fromData(
    bytes,
    mimeType: 'application/pdf',
  ).saveTo(location.path);
  Diag.event('flow.pdf', 'nodes ${view.nodes.length}');

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.pdfSaved(location.path))));
  }
}

/// Builds the document. Separated from the file dialog so it can be rendered in
/// a test without a widget tree or a file system.
Future<Uint8List> buildFlowPdf({
  required FlowView view,
  required FlowPdfStrings strings,
  required String Function(Duration) formatDuration,
}) async {
  final document = pw.Document(title: strings.title);

  document.addPage(
    pw.Page(
      // Landscape: a value stream is wide, and a portrait page would either
      // shrink the boxes past legibility or split the flow across pages.
      pageFormat: PdfPageFormat.a3.landscape,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                strings.title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${strings.period} · ${strings.dataSource}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          // Wraps rather than scrolls: a PDF has no scrollbar, so a flow wider
          // than the page continues on the next line instead of being cut off.
          pw.Wrap(
            spacing: 0,
            runSpacing: 12,
            crossAxisAlignment: pw.WrapCrossAlignment.start,
            children: [
              _endpoint(strings.supplier),
              for (final node in view.nodes) ...[
                _arrow(),
                switch (node) {
                  final FlowStepView step => _stepBox(
                    step,
                    strings,
                    formatDuration,
                  ),
                  final FlowInventoryView buffer => _inventory(
                    buffer,
                    formatDuration,
                  ),
                },
              ],
              _arrow(),
              _endpoint(strings.customer),
            ],
          ),
          pw.Spacer(),
          pw.SizedBox(height: 12),
          _ladder(view, formatDuration),
          pw.SizedBox(height: 12),
          pw.Divider(),
          _footer(view, strings, formatDuration),
          pw.SizedBox(height: 6),
          pw.Text(
            strings.generated,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    ),
  );

  return document.save();
}

pw.Widget _endpoint(String label) => pw.Container(
  width: 90,
  child: pw.Column(
    children: [
      pw.Container(
        height: 40,
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
      ),
      pw.SizedBox(height: 4),
      pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
    ],
  ),
);

pw.Widget _arrow() => pw.Container(
  width: 28,
  height: 40,
  alignment: pw.Alignment.center,
  child: pw.Text('>', style: const pw.TextStyle(fontSize: 12)),
);

pw.Widget _stepBox(
  FlowStepView step,
  FlowPdfStrings strings,
  String Function(Duration) formatDuration,
) => pw.Container(
  width: 140,
  decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 0.8)),
        ),
        alignment: pw.Alignment.center,
        child: pw.Text(
          step.title,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Column(
          children: [
            _pdfRow(
              strings.processTime,
              step.processTime == null
                  ? '—'
                  : formatDuration(step.processTime!),
            ),
            _pdfRow(strings.changeover, formatDuration(step.changeover)),
            _pdfRow(
              strings.availability,
              step.availability == null
                  ? '—'
                  : '${(step.availability! * 100).round()}%',
            ),
            _pdfRow(
              strings.operators,
              step.operatorsPerShift.isEmpty
                  ? '—'
                  : formatOperatorsPerShift(step.operatorsPerShift),
            ),
            _pdfRow(
              strings.shifts,
              step.operatorsPerShift.isEmpty
                  ? '—'
                  : '${step.staffedShiftCount}',
            ),
          ],
        ),
      ),
    ],
  ),
);

pw.Widget _inventory(
  FlowInventoryView buffer,
  String Function(Duration) formatDuration,
) => pw.Container(
  width: 90,
  alignment: pw.Alignment.center,
  child: pw.Column(
    children: [
      pw.Text('▲', style: const pw.TextStyle(fontSize: 20)),
      if (buffer.quantity != null)
        pw.Text(
          '${buffer.quantity}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      pw.Text(
        buffer.label.isEmpty ? formatDuration(buffer.wait) : buffer.label,
        style: const pw.TextStyle(fontSize: 8),
      ),
    ],
  ),
);

pw.Widget _ladder(FlowView view, String Function(Duration) formatDuration) =>
    pw.Row(
      children: [
        for (final node in view.nodes)
          pw.Container(
            width: node is FlowStepView ? 168 : 118,
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                // Waiting rides high, processing low — the sawtooth shape a
                // value-stream map is read by.
                top: node is FlowInventoryView
                    ? const pw.BorderSide(width: 0.8)
                    : pw.BorderSide.none,
                bottom: node is FlowStepView
                    ? const pw.BorderSide(width: 0.8)
                    : pw.BorderSide.none,
              ),
            ),
            child: pw.Text(
              formatDuration(node.ladderTime),
              // Centred over its rung, as on the canvas.
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
      ],
    );

pw.Widget _footer(
  FlowView view,
  FlowPdfStrings strings,
  String Function(Duration) formatDuration,
) => pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  children: [
    _metric(strings.takt, strings.taktValue),
    _metric(strings.processTime, formatDuration(view.processTime)),
    _metric(strings.leadTime, formatDuration(view.leadTime)),
    _metric(
      strings.pce,
      '${(view.processCycleEfficiency * 100).toStringAsFixed(1)}%',
    ),
  ],
);

pw.Widget _metric(String label, String value) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      label,
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
    ),
    pw.Text(
      value,
      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
    ),
  ],
);

pw.Widget _pdfRow(String label, String value) => pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  children: [
    pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
    pw.Text(value, style: const pw.TextStyle(fontSize: 7)),
  ],
);

String _safeFileName(String name) =>
    name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
