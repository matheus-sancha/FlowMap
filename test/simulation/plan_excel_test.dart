import 'package:excel/excel.dart' as xl;
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/simulation/application/run_metrics.dart';
import 'package:flowmap/src/features/simulation/application/sim_result.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flowmap/src/features/simulation/presentation/plan_excel.dart';
import 'package:flutter_test/flutter_test.dart';

/// The plan as a workbook (DESIGN.md §8.5, §13).
///
/// The export is built and then **decoded again**, so these assert the cell
/// types the file actually carries rather than that a file was produced. That
/// is the whole claim §13 makes for Excel over PDF: the numbers have to be
/// arithmetic on the other side, and a date rendered as `8/3/2026` or a lead
/// time rendered as `9.1 d` is a string that sorts wrong and pivots into
/// nothing.
void main() {
  final aug1 = DateTime(2026, 8);

  const strings = PlanExcelStrings(
    runSheet: 'Run',
    unnamedStudy: 'Study',
    generated: 'FlowMap 0.1.0-test · generated 8/8/2026 10:12',
    runLabel: '8/8/2026 · FIFO',
    dispatchOverrides: ['CLAD04: Earliest due date'],
    headers: [
      'Order',
      'Part number',
      'Description',
      'Project',
      'Batch no.',
      'Batch size',
      'Need date',
      'Material date',
      'Order start',
      'Order end',
      'Theoretical LT (d)',
      'Actual LT (d)',
      'Float (d)',
    ],
  );

  SimulationRunStudy study(String id, String name) => SimulationRunStudy(
    runId: 'run-1',
    studyId: id,
    name: name,
    releaseSeconds: 3600,
    priority: 0,
  );

  ProductionPlanRow planRow({
    required int sequence,
    String studyId = 'study-1',
    String partNumber = 'PN1',
    String? description = 'PWB 10K',
    String? project = 'Wing 7',
    String? batchNumber = 'B-001',
    int? batchSize = 4,
    DateTime? materialDate,
    DateTime? released,
    DateTime? delivered,
    Duration? theoretical = const Duration(hours: 6),
  }) => ProductionPlanRow(
    outcome: SimOrderOutcome(
      studyId: studyId,
      orderId: 'o$sequence',
      sequence: sequence,
      partId: 'part-1',
      needDate: DateTime(2026, 8, 20),
      released: released ?? DateTime(2026, 8, 3, 6, 30),
      // Thirty hours later, which is the figure that catches a duration
      // written as a clock reading.
      delivered: delivered ?? DateTime(2026, 8, 4, 12, 30),
    ),
    partNumber: partNumber,
    partDescription: description,
    customerProject: project,
    batchNumber: batchNumber,
    batchSize: batchSize,
    materialDate: materialDate ?? DateTime(2026, 8),
    theoreticalLeadTime: theoretical,
  );

  StoredRun runOf({
    required List<ProductionPlanRow> plan,
    List<SimulationRunStudy> studies = const [],
  }) {
    final result = SimRunResult(
      start: DateTime(2026, 8, 3),
      end: DateTime(2026, 8, 28),
      guard: DateTime(2027),
      steps: const [],
      orders: [for (final row in plan) row.outcome],
      emptySlots: const [],
      busyByWorkcenter: const {},
      openByWorkcenter: const {},
    );

    return StoredRun(
      id: 'run-1',
      projectId: 'project-1',
      createdAt: aug1,
      dispatch: DispatchRule.fifo,
      dispatchOverrides: const [],
      studies: studies,
      result: result,
      plan: plan,
      metrics: summariseRun(
        result: result,
        partNumbers: const {'part-1': 'PN1'},
        workcenterNames: const {},
        theoreticalByOrder: const {},
      ),
    );
  }

  xl.Excel decoded(StoredRun run, {String projectName = 'H2 2026'}) =>
      xl.Excel.decodeBytes(
        buildPlanWorkbook(run: run, projectName: projectName, strings: strings),
      );

  List<xl.CellValue?> row(xl.Excel book, String sheet, int index) =>
      book.tables[sheet]!.rows[index].map((cell) => cell?.value).toList();

  group('the sheets', () {
    test('one per study, plus the run it came from', () {
      final book = decoded(
        runOf(
          studies: [
            study('study-1', 'Célula 11B'),
            study('study-2', 'Célula 12A'),
          ],
          plan: [
            planRow(sequence: 0),
            planRow(sequence: 1, studyId: 'study-2'),
          ],
        ),
      );

      expect(book.tables.keys, ['Run', 'Célula 11B', 'Célula 12A']);
    });

    test('the placeholder the package opens with is gone', () {
      // `Excel.createExcel()` starts with a sheet of its own, and a workbook
      // whose first tab is an empty `Sheet1` reads as a broken export.
      final book = decoded(
        runOf(studies: [study('study-1', 'A')], plan: [planRow(sequence: 0)]),
      );

      expect(book.tables.keys, isNot(contains('Sheet1')));
    });

    test('a name a workbook will not take is made into one', () {
      // Excel forbids `: \ / ? * [ ]` in a sheet name and caps it at 31
      // characters. Neither is hypothetical: a study is named by the user.
      final book = decoded(
        runOf(
          studies: [
            study('study-1', 'Line 3 / Cell 11B: current state, as measured'),
          ],
          plan: [planRow(sequence: 0)],
        ),
      );

      final sheet = book.tables.keys.last;
      expect(sheet.length, lessThanOrEqualTo(31));
      expect(sheet, isNot(contains('/')));
      expect(sheet, isNot(contains(':')));
    });

    test('two studies of the same name land on two sheets', () {
      // Nothing stops a project having two studies called the same thing, and
      // a workbook cannot hold two sheets that are.
      final book = decoded(
        runOf(
          studies: [
            study('study-1', 'Current state'),
            study('study-2', 'Current state'),
          ],
          plan: [
            planRow(sequence: 0),
            planRow(sequence: 1, studyId: 'study-2'),
          ],
        ),
      );

      expect(book.tables.keys, ['Run', 'Current state', 'Current state (2)']);
    });
  });

  group('the stamp', () {
    test('names the build, the project and the run (§13)', () {
      final book = decoded(
        runOf(
          studies: [study('study-1', 'Célula 11B')],
          plan: [planRow(sequence: 0)],
        ),
      );

      expect(row(book, 'Run', 0).first.toString(), contains('0.1.0-test'));
      expect(row(book, 'Run', 1).first.toString(), 'H2 2026');
      expect(row(book, 'Run', 2).first.toString(), '8/8/2026 · FIFO');
      // Which stations dispatched by something else (§7.4): without it the
      // file would report a rule that did not happen everywhere.
      expect(row(book, 'Run', 3).first.toString(), 'CLAD04: Earliest due date');
    });

    test('maps each study to the sheet it went to', () {
      // The only place a truncated name survives in full, which is what makes
      // two long studies tellable apart in the file.
      final book = decoded(
        runOf(
          studies: [
            study('study-1', 'Line 3 / Cell 11B: current state, as measured'),
          ],
          plan: [planRow(sequence: 0)],
        ),
      );

      final mapping = row(book, 'Run', 4).map((c) => c.toString()).toList();
      expect(mapping.first, 'Line 3 / Cell 11B: current state, as measured');
      expect(mapping[1], book.tables.keys.last);
    });
  });

  group('the rows', () {
    xl.Excel single({
      String? description = 'PWB 10K',
      String? project = 'Wing 7',
      String? batchNumber = 'B-001',
      int? batchSize = 4,
      Duration? theoretical = const Duration(hours: 6),
    }) => decoded(
      runOf(
        studies: [study('study-1', 'Line')],
        plan: [
          planRow(
            sequence: 0,
            description: description,
            project: project,
            batchNumber: batchNumber,
            batchSize: batchSize,
            theoretical: theoretical,
          ),
        ],
      ),
    );

    test('the header is §8.5\'s thirteen columns', () {
      final headers = row(single(), 'Line', 0);

      expect(headers, hasLength(13));
      expect(headers.first.toString(), 'Order');
      expect(headers.last.toString(), 'Float (d)');
    });

    test('the order number is a number', () {
      expect(row(single(), 'Line', 1)[0], const xl.IntCellValue(1));
      expect(row(single(), 'Line', 1)[5], const xl.IntCellValue(4));
    });

    test('a date is a date, not the string the screen shows', () {
      // Need date and material date carry no time of day, because none was
      // ever entered for them.
      expect(
        row(single(), 'Line', 1)[6],
        const xl.DateCellValue(year: 2026, month: 8, day: 20),
      );
      expect(
        row(single(), 'Line', 1)[7],
        const xl.DateCellValue(year: 2026, month: 8, day: 1),
      );
    });

    test('order start and end carry the instant, not just the day', () {
      // The table shows a date because thirteen columns leave no room for a
      // clock; the file has no such constraint, and the two agree about the
      // moment.
      expect(
        row(single(), 'Line', 1)[8],
        isA<xl.DateTimeCellValue>()
            .having((v) => v.day, 'day', 3)
            .having((v) => v.hour, 'hour', 6)
            .having((v) => v.minute, 'minute', 30),
      );
      expect(
        row(single(), 'Line', 1)[9],
        isA<xl.DateTimeCellValue>().having((v) => v.day, 'day', 4),
      );
    });

    test('a duration is a number of days, and survives past 24 hours', () {
      // The trap this column exists to avoid: `TimeCellValue.fromDuration`
      // takes the hour, minute and second of `DateTime.utc(0) + duration`, so
      // this thirty-hour lead time would have landed in the file as `06:00:00`
      // — silently a day short, in a column meant to be averaged.
      final cells = row(single(), 'Line', 1);

      expect(cells[10], const xl.DoubleCellValue(0.25)); // 6 h theoretical
      expect(cells[11], const xl.DoubleCellValue(1.25)); // 30 h actual
      expect(cells[12], isA<xl.DoubleCellValue>());
    });

    test('float keeps its sign, because negative is late (§8)', () {
      // Need date 20 Aug 00:00, order end 4 Aug 12:30 — fifteen days and
      // eleven and a half hours in hand.
      final float = row(single(), 'Line', 1)[12]! as xl.DoubleCellValue;

      expect(float.value, closeTo(15.479166, 0.000001));
    });

    test('a value the run did not record is blank, not a dash', () {
      // A dash is a screen convention that says "this run predates the column"
      // (§16.13). In a column about to be pivoted it is text, and text in a
      // number column is what turns the pivot into a mess.
      final cells = row(
        single(
          description: null,
          project: null,
          batchNumber: null,
          batchSize: null,
          theoretical: null,
        ),
        'Line',
        1,
      );

      expect(cells[2], isNull);
      expect(cells[3], isNull);
      expect(cells[4], isNull);
      expect(cells[5], isNull);
      expect(cells[10], isNull);
      // And the columns the run *did* record are untouched by it.
      expect(cells[0], const xl.IntCellValue(1));
      expect(cells[1]!.toString(), 'PN1');
    });

    test('an empty string is blank too', () {
      // A batch number nobody typed reaches storage as `''` rather than null
      // (§9.1), and two ways of saying "nothing" in one column is one too many.
      expect(row(single(batchNumber: ''), 'Line', 1)[4], isNull);
    });

    test('rows follow the sequence, which is also release order', () {
      final book = decoded(
        runOf(
          studies: [study('study-1', 'Line')],
          plan: [
            planRow(sequence: 0),
            planRow(sequence: 1),
            planRow(sequence: 2),
          ],
        ),
      );

      expect(row(book, 'Line', 1)[0], const xl.IntCellValue(1));
      expect(row(book, 'Line', 2)[0], const xl.IntCellValue(2));
      expect(row(book, 'Line', 3)[0], const xl.IntCellValue(3));
    });
  });
}
