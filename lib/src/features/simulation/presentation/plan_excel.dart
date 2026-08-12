/// The production plan as a workbook (DESIGN.md §8.5, §13).
///
/// §13 assigns Excel "any grid in the app, plus **per-order simulation results
/// for pivoting**", and the production plan is per-order simulation results. A
/// planner merges it into their own system, which no PDF allows.
///
/// **Dates as dates and durations as durations**, never as the strings the
/// screen shows. A column of `9.1 d` sorts `1.2 d` after `10.4 d` and pivots
/// into nothing; the whole reason this is a spreadsheet rather than a printout
/// is that the numbers can be arithmetic on the other side.
///
/// Built from the same [StoredRun] the table renders, so the file and the
/// screen cannot disagree about what the run did (§7.10).
library;

import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/build_info.dart';
import '../../../common/unit_labels.dart';
import '../../../common/date_input.dart';
import '../../../common/date_style_scope.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../diagnostics/application/diagnostics.dart';
import '../data/simulation_runs_repository.dart';

/// The strings the workbook needs, captured before the export goes async.
///
/// `AppLocalizations` is read from a `BuildContext` and the file is built off
/// the widget tree, so the labels travel as data rather than the builder
/// holding a context it should not outlive — the shape `FlowPdfStrings`
/// already has.
class PlanExcelStrings {
  const PlanExcelStrings({
    required this.runSheet,
    required this.headers,
    required this.generated,
    required this.runLabel,
    required this.dispatchOverrides,
    required this.unnamedStudy,
  });

  /// The stamp sheet's own name.
  final String runSheet;

  /// §8.5's thirteen columns, in order, with the unit on the three that carry
  /// one.
  final List<String> headers;

  /// `FlowMap 0.1.0-2026-08-08 · generated 8/8/2026 10:12`.
  final String generated;

  /// `8/8/2026 · FIFO`.
  final String runLabel;

  /// One line per station that dispatched by something else (§7.4).
  final List<String> dispatchOverrides;

  /// What a study whose name is nothing a sheet can be called falls back to.
  final String unnamedStudy;
}

/// Builds the workbook.
///
/// Separated from the file dialog so it can be built — and read back — in a
/// test without a widget tree or a file system, which is the arrangement
/// `buildFlowPdf` already has. Unlike the PDF, what comes out here can be
/// decoded again, so the tests assert the actual cell *types* rather than only
/// that a document was produced.
Uint8List buildPlanWorkbook({
  required StoredRun run,
  required String projectName,
  required PlanExcelStrings strings,
  required DateStyle dateStyle,
}) {
  final book = xl.Excel.createExcel();
  // Whatever `createExcel` opens with. Deleted once there is something else in
  // the file, because `delete` refuses to remove the last sheet.
  final placeholders = book.sheets.keys.toList();

  final taken = <String>{};
  final runSheetName = _sheetName(
    strings.runSheet,
    taken,
    strings.unnamedStudy,
  );
  final stamp = book[runSheetName];

  // The names the studies had when the run was made (§7.10).
  final studyNames = {
    for (final study in run.studies) study.studyId: study.name,
  };

  // Grouped in the order the plan presents them, which within a study is
  // sequence order — and §7.2 releases strictly from the head, so that is also
  // release order (§8.5).
  final byStudy = <String, List<ProductionPlanRow>>{};
  for (final row in run.plan) {
    byStudy.putIfAbsent(row.outcome.studyId, () => []).add(row);
  }

  stamp.appendRow([xl.TextCellValue(strings.generated)]);
  stamp.appendRow([xl.TextCellValue(projectName)]);
  stamp.appendRow([xl.TextCellValue(strings.runLabel)]);
  for (final override in strings.dispatchOverrides) {
    stamp.appendRow([xl.TextCellValue(override)]);
  }

  for (final entry in byStudy.entries) {
    final name = studyNames[entry.key] ?? entry.key;
    final sheetName = _sheetName(name, taken, strings.unnamedStudy);
    // Which study went to which sheet. Not decoration: a sheet name is capped
    // at 31 characters and cannot carry `:` `/` `?` `*` `[` `]`, so two long
    // study names can reach the workbook shortened and near-identical, and this
    // is the only place the full name survives.
    stamp.appendRow([xl.TextCellValue(name), xl.TextCellValue(sheetName)]);

    final sheet = book[sheetName];
    sheet.appendRow([
      for (final header in strings.headers) xl.TextCellValue(header),
    ]);
    for (final row in entry.value) {
      sheet.appendRow(_planRow(row));
      _formatDates(sheet, sheet.maxRows - 1, dateStyle);
    }
  }

  for (final sheet in placeholders) {
    book.delete(sheet);
  }

  final bytes = book.encode();
  // `encode` is nullable for the cases where there is nothing to write, which
  // cannot happen here: the stamp sheet always has rows.
  return Uint8List.fromList(bytes ?? const []);
}

/// The date columns of the row just written, in the user's own format (§12.4).
///
/// **Without this a date column reads `45 872`.** The cells are already typed —
/// §13.1's whole claim is that they are dates rather than strings that look
/// like dates — but a typed cell with no number format is rendered by whatever
/// the *viewer's* Excel defaults to, which for this package is `mm-dd-yy`. So
/// the one thing the file could not say was which way round it meant.
///
/// The pattern comes from the same [DateStyle] the screen renders with, so the
/// exported file and the table it was exported from cannot disagree.
///
/// Applied per cell after the row is appended, because `appendRow` takes values
/// and not styles.
void _formatDates(xl.Sheet sheet, int row, DateStyle dateStyle) {
  final date = xl.NumFormat.custom(formatCode: dateStyle.excelPattern);
  // The two Order columns carry the instant, which is why the file says more
  // than the screen does (§13.1). 24-hour, which is §12.4's split: dates follow
  // the user, clock readings do not.
  final instant = xl.NumFormat.custom(
    formatCode: '${dateStyle.excelPattern} hh:mm',
  );

  for (final (column, format) in [
    (_needDateColumn, date),
    (_materialDateColumn, date),
    (_orderStartColumn, instant),
    (_orderEndColumn, instant),
  ]) {
    final cell = sheet.cell(
      xl.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
    );
    // An empty cell is left alone: a blank means blank (see `_planRow`), and
    // giving it a date format would be claiming it holds a date.
    if (cell.value == null) continue;
    cell.cellStyle = xl.CellStyle(numberFormat: format);
  }
}

/// Where the dates sit in [_planRow], which is §8.5's column order.
const _needDateColumn = 6;
const _materialDateColumn = 7;
const _orderStartColumn = 8;
const _orderEndColumn = 9;

/// One order, typed.
///
/// **A missing value is an empty cell, not the dash the table shows.** A dash is
/// a screen convention that says "the run did not record this" (§16.13) to
/// someone reading; in a column about to be averaged it is text, and text in a
/// number column is what turns a pivot into a mess. Blank means blank to a
/// spreadsheet, which is the same statement in that language.
List<xl.CellValue?> _planRow(ProductionPlanRow row) => [
  xl.IntCellValue(row.orderNumber),
  xl.TextCellValue(row.partNumber),
  _text(row.partDescription),
  _text(row.customerProject),
  _text(row.batchNumber),
  row.batchSize == null ? null : xl.IntCellValue(row.batchSize!),
  _date(row.outcome.needDate),
  _date(row.materialDate),
  // The instant, where the screen shows only the date: a thirteen-column table
  // has no room for a clock and a spreadsheet has no such constraint. They
  // agree about the moment; the file simply says more of it.
  _instant(row.orderStart),
  _instant(row.delivery),
  _days(row.theoreticalLeadTime),
  _days(row.actualLeadTime),
  _days(row.float),
];

xl.TextCellValue? _text(String? value) =>
    (value == null || value.isEmpty) ? null : xl.TextCellValue(value);

/// A date the plant works to — no time of day, because none was ever entered.
xl.DateCellValue? _date(DateTime? value) =>
    value == null ? null : xl.DateCellValue.fromDateTime(value);

xl.DateTimeCellValue? _instant(DateTime? value) =>
    value == null ? null : xl.DateTimeCellValue.fromDateTime(value);

/// A duration, in days.
///
/// **A number, not a clock reading.** Excel's own duration is a fraction of a
/// day, and `TimeCellValue.fromDuration` maps onto it by taking the hour,
/// minute and second of `DateTime.utc(0) + duration` — so a lead time of 30
/// hours would land in the file as `06:00:00`, silently a day short. Every
/// figure in this column runs to days.
///
/// A day is 24 hours here, which is what §17.4 calls a day for a headline
/// figure and what the metrics card already divides by. The unit is in the
/// column heading, because a column has one unit where
/// `formatAdaptiveDuration` picks one per value.
///
/// Not rounded: the value is the stored seconds ÷ 86 400, so it is exactly the
/// figure the app holds, and how many decimals to show is the spreadsheet's
/// business rather than this file's.
xl.DoubleCellValue? _days(Duration? value) => value == null
    ? null
    : xl.DoubleCellValue(value.inSeconds / Duration.secondsPerDay);

/// A name a workbook will accept, unique within [taken].
///
/// Excel caps a sheet name at 31 characters and forbids `: \ / ? * [ ]`.
/// A collision is real rather than theoretical: two studies may share a name,
/// and two long ones can be shortened into the same thirty-one characters.
String _sheetName(String name, Set<String> taken, String fallback) {
  var base = name.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').trim();
  if (base.isEmpty) base = fallback;
  if (base.length > 31) base = base.substring(0, 31).trim();

  var candidate = base;
  var next = 2;
  while (taken.contains(candidate.toLowerCase())) {
    final suffix = ' ($next)';
    final head = base.length + suffix.length > 31
        ? base.substring(0, 31 - suffix.length).trim()
        : base;
    candidate = '$head$suffix';
    next++;
  }

  taken.add(candidate.toLowerCase());
  return candidate;
}

/// Builds the workbook and asks where to put it.
Future<void> exportPlanExcel(
  BuildContext context, {
  required StoredRun run,
  required String projectName,
}) async {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  final dates = DateFormat.yMd(locale);
  final timestamp = DateFormat.yMd(locale).add_Hm();

  final bytes = buildPlanWorkbook(
    run: run,
    projectName: projectName,
    dateStyle: DateStyleScope.of(context),
    strings: PlanExcelStrings(
      runSheet: l10n.simExportRunSheet,
      unnamedStudy: l10n.study,
      generated: l10n.exportGenerated(
        kBuildLabel,
        timestamp.format(DateTime.now()),
      ),
      runLabel: l10n.simRunLabel(
        dates.format(run.createdAt),
        dispatchRuleLabel(l10n, run.dispatch),
      ),
      dispatchOverrides: [
        for (final override in run.dispatchOverrides)
          l10n.simDispatchOverrideRow(
            override.name,
            dispatchRuleLabel(l10n, override.rule),
          ),
      ],
      // The three duration columns carry their unit, because a column has one
      // where the screen picks one per figure.
      headers: [
        l10n.simPlanOrder,
        l10n.demandPartNumber,
        l10n.demandDescription,
        l10n.demandProject,
        l10n.demandBatchNumber,
        l10n.demandBatchSize,
        l10n.demandNeedDate,
        l10n.demandMaterialDate,
        l10n.simPlanOrderStart,
        l10n.simPlanOrderEnd,
        '${l10n.simPlanTheoreticalLeadTime} (${l10n.unitDaysShort})',
        '${l10n.simPlanActualLeadTime} (${l10n.unitDaysShort})',
        '${l10n.simAverageFloat} (${l10n.unitDaysShort})',
      ],
    ),
  );

  final location = await getSaveLocation(
    suggestedName: '${_safeFileName(projectName)}.xlsx',
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Excel', extensions: ['xlsx']),
    ],
  );
  if (location == null) return;

  await XFile.fromData(
    bytes,
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ).saveTo(location.path);
  Diag.event('plan.xlsx', 'orders ${run.plan.length}');

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.exportSaved(location.path))));
  }
}

String _safeFileName(String name) =>
    name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
