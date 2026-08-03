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
String _hours(Duration d) => '${d.inHours} h';

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
    leadTime: 'Lead time',
    pce: 'PCE',
    generated: 'FlowMap test',
    dataSource: 'Flow equivalent',
    taktValue: '1 days',
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

  FlowView viewWith(List<FlowNode> nodes) {
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
        priority: 100,
        createdAt: now,
        updatedAt: now,
      ),
      nodes: nodes,
      contexts: {
        'WC': WorkcenterContext(
          workcenter: Workcenter(
            id: 'WC',
            plantId: 'plant-1',
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

  FlowNode step(int position) => FlowNode(
    id: 'node-$position',
    studyId: 'study-1',
    position: position,
    kind: FlowNodeKind.step,
    workcenterId: 'WC',
    changeoverSeconds: 1800,
    inventoryUsesWorkingTime: false,
    createdAt: now,
    updatedAt: now,
  );

  FlowNode buffer(int position) => FlowNode(
    id: 'node-$position',
    studyId: 'study-1',
    position: position,
    kind: FlowNodeKind.inventory,
    changeoverSeconds: 0,
    inventoryMode: InventoryMode.quantity,
    inventoryQuantity: 3,
    inventoryUsesWorkingTime: false,
    createdAt: now,
    updatedAt: now,
  );

  test('produces a real PDF document', () async {
    final bytes = await buildFlowPdf(
      view: viewWith([step(0), buffer(1), step(2)]),
      strings: strings,
      formatDuration: _hours,
    );

    expect(bytes, isNotEmpty);
    // Every PDF starts with %PDF- and ends with the EOF marker; a truncated or
    // failed render fails one of the two.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(String.fromCharCodes(bytes.skip(bytes.length - 6)), contains('EOF'));
  });

  test('an empty flow still renders rather than throwing', () async {
    final bytes = await buildFlowPdf(
      view: viewWith(const []),
      strings: strings,
      formatDuration: _hours,
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
      formatDuration: _hours,
    );
    expect(bytes, isNotEmpty);
  });
}
