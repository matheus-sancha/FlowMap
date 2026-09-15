import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/calendar/application/shift_pattern_spec.dart';
import 'package:flowmap/src/features/calendar/application/working_calendar.dart';
import 'package:flowmap/src/features/schedules/application/workcenter_schedule.dart';
import 'package:flowmap/src/features/simulation/application/engine.dart';
import 'package:flowmap/src/features/simulation/application/run_filter.dart';
import 'package:flowmap/src/features/simulation/application/run_report.dart';
import 'package:flowmap/src/features/simulation/application/sim_model.dart';
import 'package:flowmap/src/features/simulation/data/simulation_runs_repository.dart';
import 'package:flowmap/src/features/simulation/presentation/run_report_pdf.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../common/pdf_support.dart';

/// The simulation report (DESIGN.md §13, #27).
///
/// What it lists is asserted against the run's own metrics, so the page and
/// the headline beside the button cannot disagree about how many orders were
/// late.
void main() {
  late AppDatabase db;
  late SimulationRunsRepository runs;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    runs = SimulationRunsRepository(db);
  });

  tearDown(() => db.close());

  /// One workcenter, eight orders of eight hours each, released every four
  /// hours against need dates a day apart from the first — so the queue grows
  /// and the tail of the sequence is late.
  Future<StoredRun> stored() async {
    final now = DateTime.now();
    await db
        .into(db.plants)
        .insert(
          PlantsCompanion.insert(
            id: 'plant-1',
            name: 'Werk Nord',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final pattern = (await db.select(db.shiftPatterns).get()).first;
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'proj-1',
            name: 'H2 2026',
            plantId: 'plant-1',
            shiftPatternId: pattern.id,
            createdAt: now,
            updatedAt: now,
          ),
        );

    final always = ShiftPatternSpec(
      name: 'Always',
      cycleType: ShiftCycleType.fixedWeekly,
      workingWeekdays: ShiftPatternSpec.weekdayMask([1, 2, 3, 4, 5, 6, 7]),
      shifts: const [
        ShiftWindow(
          label: 'A',
          position: 0,
          startMinute: 0,
          endMinute: 1439,
          breakSeconds: 0,
        ),
      ],
    );
    final schedule = WorkcenterScheduleSpec([
      WorkcenterSchedulePeriodSpec(
        startDate: DateTime(2026),
        endDate: DateTime(2026, 12, 31),
        operatorsPerShift: const [1],
        availability: 1,
      ),
    ]);
    final plant = {
      'wc-1': SimWorkcenter(
        id: 'wc-1',
        name: 'CLAD04',
        calendar: WorkingCalendar.scheduled(pattern: always, staffing: schedule),
        schedule: schedule,
      ),
    };
    final studies = [
      SimStudy(
        id: 'study-a',
        name: 'Célula 11B',
        productionCellId: 'cell-1',
        productionCellName: 'Célula 11',
        productionLineId: 'line-b',
        productionLineName: 'Fluxo 11B',
        nodes: [
          SimStep(
            id: 'node-0',
            position: 0,
            title: 'Cladding',
            candidates: const ['wc-1'],
            demandKey: 'wc-1',
            queue: SimQueue(targetId: 'wc-1'),
          ),
        ],
        parts: {
          'part-1': SimPart(
            id: 'part-1',
            partNumber: 'PN-1085-1',
            processTimes: const {'wc-1': Duration(hours: 8)},
          ),
        },
        orders: [
          for (var i = 0; i < 8; i++)
            SimOrder(
              id: 'o$i',
              sequence: i,
              partId: 'part-1',
              needDate: DateTime(2026, 8, 21 + i ~/ 4),
            ),
        ],
        releaseInterval: const Duration(hours: 4),
        releaseCalendarId: 'wc-1',
      ),
    ];
    final result = runSimulation(studies: studies, workcenters: plant);
    final runId = await runs.saveRun(
      projectId: 'proj-1',
      result: result,
      studies: studies,
      workcenters: plant,
    );
    return (await runs.loadRun(runId))!;
  }

  test('late orders are every order not on time, worst first', () async {
    final slice = filterRun(await stored(), const RunFilter());
    final late = lateOrders(slice.plan);

    // **The headline's count, not a subset of it**: an order that never
    // delivered is late under §8 and has to be on the list.
    expect(late, hasLength(slice.metrics.orders - slice.metrics.onTime));
    expect(late, isNotEmpty, reason: 'the fixture has to produce lateness');

    final floats = late.map((r) => r.float).toList();
    final firstDelivered = floats.indexWhere((f) => f != null);
    if (firstDelivered > 0) {
      expect(floats.take(firstDelivered), everyElement(isNull));
    }
    final delivered = floats.whereType<Duration>().toList();
    expect(delivered, orderedEquals(delivered.toList()..sort()));
  });

  test('the ranking names only workcenters something visited', () async {
    final slice = filterRun(await stored(), const RunFilter());
    final ranking = bottleneckRanking(slice.metrics);
    expect(ranking.first.workcenterId, slice.metrics.bottleneck!.workcenterId);
    expect(ranking.every((w) => w.visits > 0), isTrue);
  });

  test('the report renders, embedded, with its chart drawn', () async {
    await initializeDateFormatting('pt');
    final slice = filterRun(await stored(), const RunFilter());
    final l10n = lookupAppLocalizations(const Locale('pt'));
    final report = runReportFor(
      slice: slice,
      projectName: 'H2 2026',
      l10n: l10n,
      locale: 'pt',
      date: (d) => d == null ? '' : '${d.day}/${d.month}/${d.year}',
      now: '13/09/2026 15:00',
    );

    expect(report.late, hasLength(lateOrders(slice.plan).length));
    expect(report.chart, isNotNull);
    expect(report.inputs.join(), contains('Célula 11B (Célula 11 · Fluxo 11B)'));

    final bytes = await buildRunReportPdf(
      theme: testPdfTheme(),
      report: report,
    );
    final raw = latin1.decode(bytes);
    expect(raw, startsWith('%PDF-'));
    expect(raw, contains('/FontFile2'));
    // Bars are filled rectangles; the mark in the header is curves.
    final streams = contentStreams(bytes);
    expect(operatorCount(streams, 're'), greaterThan(0));
    expect(operatorCount(streams, 'c'), greaterThanOrEqualTo(2));
  });
}
