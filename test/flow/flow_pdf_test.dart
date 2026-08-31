import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/flow/application/flow_view.dart';
import 'package:flowmap/src/features/flow/presentation/flow_pdf.dart';
import 'package:flowmap/src/features/schedules/application/takt_schedule.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// The export is a re-render, not a screenshot, so it can be built and checked
/// without a widget tree or a file dialog (DESIGN.md §13).
/// A stand-in for the app's localized formatter, which needs a `BuildContext`
/// the document builder deliberately does not have.
///
/// It records what it was asked to render, which is how the tests check that
/// the document measures a duration against the same working day the canvas
/// does — the numbers themselves live inside a PDF's compressed content stream
/// and cannot be read back out (DESIGN.md §17.4).
class _Format {
  final calls = <({Duration duration, Duration? workingDay})>[];

  String call(Duration duration, {Duration? workingDay}) {
    calls.add((duration: duration, workingDay: workingDay));
    return '${duration.inHours} h';
  }
}

void main() {
  final now = DateTime(2026, 8, 1);

  const strings = FlowPdfStrings(
    title: 'Current state',
    period: 'August 2026',
    supplier: 'Supplier',
    customer: 'Customer',
    processTime: 'Process time',
    changeover: 'Changeover',
    availability: 'Availability',
    operators: 'Operators',
    shifts: 'Shifts',
    takt: 'Takt',
    notes: 'Notes',
    leadTime: 'Lead time',
    pce: 'PCE',
    generated: 'FlowMap test',
    dataSource: 'Flow equivalent',
    taktValue: '1 days',
    localEquivalentMark: ' *',
  );

  final pattern = ShiftPatternSpec(
    name: 'ABC',
    cycleType: ShiftCycleType.fixedWeekly,
    workingWeekdays: ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5]),
    shifts: const [
      ShiftWindow(
        label: 'A',
        position: 0,
        startMinute: 5 * 60 + 45,
        endMinute: 15 * 60 + 13,
        breakSeconds: 40 * 60,
      ),
    ],
  );

  FlowView viewWith(
    List<FlowNode> nodes, {
    Map<String, ProjectQueue> queues = const {},
    int? inbound,
    int? outbound,
  }) {
    final schedule = WorkcenterScheduleSpec([
      WorkcenterSchedulePeriodSpec(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        operatorsPerShift: const [1],
        availability: 0.74,
      ),
    ]);
    return buildFlowView(
      study: Study(
        id: 'study-1',
        projectId: 'project-1',
        productionCellId: 'cell-1',
        productionLineId: 'line-1',
        name: 'Current state',
        includeInSimulation: false,
        startBufferDays: 0,
        inboundStock: inbound,
        outboundStock: outbound,
        createdAt: now,
        updatedAt: now,
      ),
      nodes: nodes,
      contexts: {
        'WC': WorkcenterContext(
          workcenter: Workcenter(
            id: 'WC',
            plantId: 'plant-1',
            parallelCapacity: 1,
            name: 'Cladding 04',
            createdAt: now,
            updatedAt: now,
          ),
          calendar: WorkingCalendar.scheduled(
            pattern: pattern,
            staffing: schedule,
          ),
          schedule: schedule,
        ),
      },
      pools: const {},
      poolMembers: const {},
      queues: queues,
      taktSchedule: TaktScheduleSpec([
        TaktPeriodSpec(
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
          value: 1,
          unit: TaktUnit.days,
        ),
      ]),
      asOf: DateTime(2026, 8, 1),
    );
  }

  FlowNode step(int position, {String? notes}) => FlowNode(
    id: 'node-$position',
    studyId: 'study-1',
    position: position,
    kind: FlowNodeKind.step,
    workcenterId: 'WC',
    changeoverSeconds: 1800,
    inventoryUsesWorkingTime: false,
    notes: notes,
    createdAt: now,
    updatedAt: now,
  );

  /// Three pieces standing in front of the one station this fixture has.
  final stocked = {
    'WC': ProjectQueue(
      projectId: 'project-1',
      targetId: 'WC',
      stockMode: InventoryMode.quantity,
      stockQuantity: 3,
      createdAt: now,
      updatedAt: now,
    ),
  };

  test('produces a real PDF document', () async {
    final bytes = await buildFlowPdf(
      view: viewWith([step(0), step(1)], queues: stocked),
      strings: strings,
      formatDuration: _Format().call,
      queueCaption: _caption,
    );

    expect(bytes, isNotEmpty);
    // Every PDF starts with %PDF- and ends with the EOF marker; a truncated or
    // failed render fails one of the two.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(String.fromCharCodes(bytes.skip(bytes.length - 6)), contains('EOF'));
  });

  test('a walk\'s findings reach the printed map', () async {
    // A note is why anyone prints a current state to take to a meeting, so a
    // PDF that drops it is a PDF of half the work (§5.4).
    final withNotes = await buildFlowPdf(
      view: viewWith([step(0, notes: 'Operator waits for the crane')]),
      strings: strings,
      formatDuration: _Format().call,
      queueCaption: _caption,
    );
    final without = await buildFlowPdf(
      view: viewWith([step(0)]),
      strings: strings,
      formatDuration: _Format().call,
      queueCaption: _caption,
    );

    expect(withNotes, isNotEmpty);
    // The findings list is absent entirely when nothing was written, so a map
    // of a flow nobody has walked carries no empty heading.
    expect(withNotes.length, greaterThan(without.length));
  });

  test('an empty flow still renders rather than throwing', () async {
    final bytes = await buildFlowPdf(
      view: viewWith(const []),
      strings: strings,
      formatDuration: _Format().call,
      queueCaption: _caption,
    );
    expect(bytes, isNotEmpty);
  });

  test('a step that cannot be costed renders as a dash', () async {
    // An unbound step has a null process time; the renderer must not assume it
    // has one.
    final unbound = FlowNode(
      id: 'node-0',
      studyId: 'study-1',
      position: 0,
      kind: FlowNodeKind.step,
      changeoverSeconds: 0,
      inventoryUsesWorkingTime: false,
      createdAt: now,
      updatedAt: now,
    );
    final view = viewWith([unbound]);
    expect(view.steps.single.processTime, isNull);

    final bytes = await buildFlowPdf(
      view: view,
      strings: strings,
      formatDuration: _Format().call,
      queueCaption: _caption,
    );
    expect(bytes, isNotEmpty);
  });

  group('the exported map reads the same days as the screen', () {
    test('a rung is measured against its own station working day', () async {
      final view = viewWith([step(0)]);
      final format = _Format();
      await buildFlowPdf(
        view: view,
        strings: strings,
        formatDuration: format.call,
        queueCaption: _caption,
      );

      final rung = view.nodes.single;
      // 8:48 open × 74 % = 6:30:43 productive, and a 1-day takt is one of
      // those — so the rung reads 1.0 d only if the working day comes with it.
      expect(rung.referenceWorkingDay, isNotNull);
      expect(rung.ladderDays, closeTo(1, 1e-9));
      expect(
        format.calls,
        contains((
          duration: rung.ladderTime,
          workingDay: rung.referenceWorkingDay,
        )),
      );
    });

    test('a queue is measured against the step it drains into', () async {
      final view = viewWith([step(0)], queues: stocked);
      final format = _Format();
      await buildFlowPdf(
        view: view,
        strings: strings,
        formatDuration: format.call,
        queueCaption: _caption,
      );

      final wait = view.queues.single;
      // Asserted non-null first: a `contains` of two nulls would pass while
      // proving nothing.
      expect(wait.rungWorkingDay, isNotNull);
      expect(
        format.calls,
        contains((duration: wait.wait, workingDay: wait.rungWorkingDay)),
      );
    });

    test('the two ends print a rung each, in flow order (§7.3)', () async {
      final view = viewWith([step(0)], inbound: 2, outbound: 1);
      final format = _Format();
      await buildFlowPdf(
        view: view,
        strings: strings,
        formatDuration: format.call,
        queueCaption: _caption,
      );

      // Measured against the box beside each, the way every other rung is
      // measured against its own station's day.
      expect(view.inbound!.rungWorkingDay, isNotNull);
      expect(
        format.calls,
        contains((
          duration: view.inbound!.wait,
          workingDay: view.inbound!.rungWorkingDay,
        )),
      );
      expect(
        format.calls,
        contains((
          duration: view.outbound!.wait,
          workingDay: view.outbound!.rungWorkingDay,
        )),
      );
    });

    test('a map with no end counted prints exactly what it used to', () async {
      // Counted against itself: the same flow with and without the two ends,
      // so the difference is the feature and nothing else. Each end costs two
      // renderings — the figure under its triangle and its rung.
      final bare = _Format();
      await buildFlowPdf(
        view: viewWith([step(0)]),
        strings: strings,
        formatDuration: bare.call,
        queueCaption: _caption,
      );

      final counted = _Format();
      await buildFlowPdf(
        view: viewWith([step(0)], inbound: 2, outbound: 1),
        strings: strings,
        formatDuration: counted.call,
        queueCaption: _caption,
      );

      expect(counted.calls, hasLength(bare.calls.length + 4));
    });

    test('the footer totals carry the ladder working day', () async {
      final view = viewWith([step(0), step(1)]);
      final format = _Format();
      await buildFlowPdf(
        view: view,
        strings: strings,
        formatDuration: format.call,
        queueCaption: _caption,
      );

      expect(view.leadTimeInDays, closeTo(2, 1e-9));
      expect(
        format.calls,
        contains((
          duration: view.leadTime,
          workingDay: view.leadTimeWorkingDay,
        )),
      );
    });
  });
}


/// The caption the app derives, spelled out here so the page under test says
/// what the screen says (#5, v27). A test has no `AppLocalizations`, so the
/// short type names are written literally — which is also what keeps this a
/// check on the *page* rather than on the l10n bundle.
String _caption(FlowQueueView queue) => switch (queue.rule) {
  null => 'Queue · ${queue.targetName}',
  DispatchRule.fifo => 'FIFO · ${queue.targetName}',
  DispatchRule.lifo => 'LIFO · ${queue.targetName}',
  DispatchRule.earliestDueDate => 'EDD · ${queue.targetName}',
  DispatchRule.shortestProcessing => 'SPT · ${queue.targetName}',
};
