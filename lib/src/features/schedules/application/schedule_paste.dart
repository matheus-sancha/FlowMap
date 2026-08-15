/// Turning a block of raw grid cells into what it asks a dated schedule to
/// become (DESIGN.md §12.6).
///
/// A typed cell is a 1×1 block and a paste out of Excel is a rectangle, so both
/// arrive here. Pure and free of Drift, so every rule — what an unreadable cell
/// means, what a new row is worth before it is finished, how a block merges over
/// what is already there — is a unit test rather than a widget one. This is
/// `demand_paste.dart`'s shape applied to the two schedules, and §1.6's
/// precedent: what an edit *is* should be assertable without pumping a frame.
library;

import '../../../common/cell_parsers.dart';
import '../../../common/date_input.dart';
import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../../data/database/staffing_codec.dart';

/// One row of a takt schedule, as a write. A null [id] creates.
class TaktPeriodWrite {
  const TaktPeriodWrite({
    this.id,
    required this.startDate,
    required this.endDate,
    required this.takt,
    required this.unit,
  });

  final String? id;
  final DateTime startDate;
  final DateTime endDate;
  final double takt;
  final TaktUnit unit;
}

/// One row of a workcenter schedule, as a write. A null [id] creates.
class SchedulePeriodWrite {
  const SchedulePeriodWrite({
    this.id,
    required this.startDate,
    required this.endDate,
    required this.operatorsPerShift,
    required this.availability,
    required this.rework,
  });

  final String? id;
  final DateTime startDate;
  final DateTime endDate;
  final List<int> operatorsPerShift;
  final double availability;
  final double rework;
}

/// Reads the cells a block supplies for one row, by absolute column.
///
/// A block is anchored at a column, so a paste starting in the third column
/// supplies nothing for the first two — and "supplied nothing" has to stay
/// distinguishable from "supplied a blank", because only the second is an
/// instruction.
class _Row {
  const _Row(this.cells, this.anchor);

  final List<String> cells;
  final int anchor;

  String? operator [](int column) {
    final index = column - anchor;
    return index >= 0 && index < cells.length ? cells[index].trim() : null;
  }
}

/// The date a cell asks for, or [fallback] when it asks for nothing readable.
///
/// **An unreadable cell changes nothing.** The grid is already showing the user
/// why it is refused, and writing a value nobody typed is the one failure §11
/// will not tolerate — so the row keeps what it had rather than being rewritten
/// around a cell that did not parse.
DateTime _dateOr(DateStyle dates, String? text, DateTime fallback) {
  if (text == null || text.isEmpty) return fallback;
  return dates.parse(text) ?? fallback;
}

/// The first day a new period should start on: the day after the last one ends,
/// or the start of this year when there is none.
///
/// The suggestion the dialogs used to offer, kept because the app proposing what
/// it always proposed is one less thing to relearn.
DateTime suggestedPeriodStart(List<DateTime> lastEnds) {
  if (lastEnds.isEmpty) return DateTime(DateTime.now().year, 1, 1);
  final last = lastEnds.last;
  return DateTime(last.year, last.month, last.day + 1);
}

/// Reads a block anchored at ([row], [column]) of the takt grid.
///
/// Rows past the end append. **A new row is complete from the moment it is
/// touched** — it takes the suggested dates, one day of takt, and whatever the
/// block supplies over the top. The alternative was holding a half-built period
/// in widget state until it had all four values, which puts a row on screen that
/// does not exist and cannot be deleted.
List<TaktPeriodWrite> planTaktWrite({
  required List<TaktPeriod> periods,
  required int row,
  required int column,
  required List<List<String>> block,
  required DateStyle dates,
}) {
  final writes = <TaktPeriodWrite>[];
  var lastEnd = periods.isEmpty ? null : periods.last.endDate;

  for (var r = 0; r < block.length; r++) {
    final cells = _Row(block[r], column);
    final target = row + r;

    if (target < periods.length) {
      final period = periods[target];
      writes.add(
        TaktPeriodWrite(
          id: period.id,
          startDate: _dateOr(dates, cells[0], period.startDate),
          endDate: _dateOr(dates, cells[1], period.endDate),
          takt: parsePositive(cells[2] ?? '') ?? period.taktValue,
          unit: parseTaktUnit(cells[3] ?? '') ?? period.taktUnit,
        ),
      );
      continue;
    }

    // A blank row that a block says nothing about is not an instruction to
    // create anything — which is what a paste one row too tall would otherwise
    // do.
    if (!_saysAnything(cells, 4)) continue;

    final start = _dateOr(
      dates,
      cells[0],
      suggestedPeriodStart([?lastEnd]),
    );
    final end = _dateOr(dates, cells[1], DateTime(start.year, 12, 31));
    writes.add(
      TaktPeriodWrite(
        startDate: start,
        endDate: end,
        takt: parsePositive(cells[2] ?? '') ?? 1,
        unit: parseTaktUnit(cells[3] ?? '') ?? TaktUnit.days,
      ),
    );
    // So a block appending several rows staggers them rather than stacking
    // every one on the same suggested start.
    lastEnd = end;
  }

  return writes;
}

/// Reads a block anchored at ([row], [column]) of a workcenter schedule grid.
///
/// [shiftCount] is how many shifts the project's pattern has, which is what a
/// new row is staffed to: one operator on each, fully available, no rework —
/// the plant as it would be on a good day, which is the honest thing to assume
/// before anyone has said otherwise.
List<SchedulePeriodWrite> planSchedulePeriodWrite({
  required List<WorkcenterSchedulePeriod> periods,
  required int row,
  required int column,
  required List<List<String>> block,
  required DateStyle dates,
  required int shiftCount,
}) {
  final writes = <SchedulePeriodWrite>[];
  var lastEnd = periods.isEmpty ? null : periods.last.endDate;

  for (var r = 0; r < block.length; r++) {
    final cells = _Row(block[r], column);
    final target = row + r;
    final operators = cells[3];

    if (target < periods.length) {
      final period = periods[target];
      writes.add(
        SchedulePeriodWrite(
          id: period.id,
          startDate: _dateOr(dates, cells[0], period.startDate),
          endDate: _dateOr(dates, cells[1], period.endDate),
          operatorsPerShift: operators == null || operators.isEmpty
              ? parseOperatorsPerShift(period.operatorsPerShift)
              : parseOperatorsPerShift(operators),
          availability: parseFraction(cells[4] ?? '') ?? period.availability,
          rework: parseFraction(cells[5] ?? '') ?? period.rework,
        ),
      );
      continue;
    }

    if (!_saysAnything(cells, 6)) continue;

    final start = _dateOr(
      dates,
      cells[0],
      suggestedPeriodStart([?lastEnd]),
    );
    final end = _dateOr(dates, cells[1], DateTime(start.year, 12, 31));
    writes.add(
      SchedulePeriodWrite(
        startDate: start,
        endDate: end,
        operatorsPerShift: operators == null || operators.isEmpty
            ? [for (var i = 0; i < shiftCount; i++) 1]
            : parseOperatorsPerShift(operators),
        availability: parseFraction(cells[4] ?? '') ?? 1,
        rework: parseFraction(cells[5] ?? '') ?? 0,
      ),
    );
    lastEnd = end;
  }

  return writes;
}

/// Whether a row of a block asks for anything at all across [width] columns.
bool _saysAnything(_Row cells, int width) {
  for (var c = 0; c < width; c++) {
    final text = cells[c];
    if (text != null && text.isNotEmpty) return true;
  }
  return false;
}
