import 'package:drift/drift.dart';

import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../../data/database/staffing_codec.dart';
import '../../calendar/application/shift_pattern_spec.dart';
import '../../calendar/application/working_calendar.dart';
import '../../resources/data/resources_repository.dart';
import '../application/takt_schedule.dart';
import '../application/workcenter_schedule.dart';

/// Takt periods, workcenter schedule periods and calendar exceptions — the
/// project-scoped numbers — plus the one place they are assembled into a
/// [WorkingCalendar].
///
/// That assembly is the seam between M1's engine and project data: the engine
/// knows nothing about projects, and nothing above this line constructs a
/// calendar by hand.
class SchedulesRepository {
  SchedulesRepository(this._db, this._resources);

  final AppDatabase _db;
  final ResourcesRepository _resources;

  // --- Takt periods -------------------------------------------------------

  Stream<List<TaktPeriod>> watchTaktPeriods(
    String projectId,
    String productionLineId,
  ) =>
      (_db.select(_db.taktPeriods)
            ..where(
              (t) =>
                  t.projectId.equals(projectId) &
                  t.productionLineId.equals(productionLineId),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.startDate)]))
          .watch();

  Future<String> createTaktPeriod({
    required String projectId,
    required String productionLineId,
    required DateTime startDate,
    required DateTime endDate,
    required double takt,
    required TaktUnit unit,
  }) async {
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.taktPeriods)
        .insert(
          TaktPeriodsCompanion.insert(
            id: id,
            projectId: projectId,
            productionLineId: productionLineId,
            startDate: startDate,
            endDate: endDate,
            taktValue: takt,
            taktUnit: unit,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updateTaktPeriod(
    String id, {
    required DateTime startDate,
    required DateTime endDate,
    required double takt,
    required TaktUnit unit,
  }) => (_db.update(_db.taktPeriods)..where((t) => t.id.equals(id))).write(
    TaktPeriodsCompanion(
      startDate: Value(startDate),
      endDate: Value(endDate),
      taktValue: Value(takt),
      taktUnit: Value(unit),
      updatedAt: Value(DateTime.now()),
    ),
  );

  Future<void> deleteTaktPeriod(String id) =>
      (_db.delete(_db.taktPeriods)..where((t) => t.id.equals(id))).go();

  Future<TaktScheduleSpec> loadTaktSchedule(
    String projectId,
    String productionLineId,
  ) async {
    final rows =
        await (_db.select(_db.taktPeriods)..where(
              (t) =>
                  t.projectId.equals(projectId) &
                  t.productionLineId.equals(productionLineId),
            ))
            .get();
    return TaktScheduleSpec([
      for (final row in rows)
        TaktPeriodSpec(
          startDate: row.startDate,
          endDate: row.endDate,
          value: row.taktValue,
          unit: row.taktUnit,
        ),
    ]);
  }

  // --- Workcenter schedule periods ----------------------------------------

  Stream<List<WorkcenterSchedulePeriod>> watchWorkcenterSchedule(
    String projectId,
    String workcenterId,
  ) =>
      (_db.select(_db.workcenterSchedulePeriods)
            ..where(
              (s) =>
                  s.projectId.equals(projectId) &
                  s.workcenterId.equals(workcenterId),
            )
            ..orderBy([(s) => OrderingTerm(expression: s.startDate)]))
          .watch();

  /// Every workcenter schedule in the project, for the readiness panel and the
  /// occupation roll-up — one query rather than one per workcenter.
  Stream<List<WorkcenterSchedulePeriod>> watchProjectSchedules(
    String projectId,
  ) =>
      (_db.select(_db.workcenterSchedulePeriods)
            ..where((s) => s.projectId.equals(projectId))
            ..orderBy([(s) => OrderingTerm(expression: s.startDate)]))
          .watch();

  Future<String> createWorkcenterSchedulePeriod({
    required String projectId,
    required String workcenterId,
    required DateTime startDate,
    required DateTime endDate,
    required List<int> operatorsPerShift,
    required double availability,
    required double rework,
  }) async {
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.workcenterSchedulePeriods)
        .insert(
          WorkcenterSchedulePeriodsCompanion.insert(
            id: id,
            projectId: projectId,
            workcenterId: workcenterId,
            startDate: startDate,
            endDate: endDate,
            operatorsPerShift: formatOperatorsPerShift(operatorsPerShift),
            availability: Value(availability),
            rework: Value(rework),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updateWorkcenterSchedulePeriod(
    String id, {
    required DateTime startDate,
    required DateTime endDate,
    required List<int> operatorsPerShift,
    required double availability,
    required double rework,
  }) =>
      (_db.update(
        _db.workcenterSchedulePeriods,
      )..where((s) => s.id.equals(id))).write(
        WorkcenterSchedulePeriodsCompanion(
          startDate: Value(startDate),
          endDate: Value(endDate),
          operatorsPerShift: Value(formatOperatorsPerShift(operatorsPerShift)),
          availability: Value(availability),
          rework: Value(rework),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deleteWorkcenterSchedulePeriod(String id) => (_db.delete(
    _db.workcenterSchedulePeriods,
  )..where((s) => s.id.equals(id))).go();

  Future<WorkcenterScheduleSpec> loadWorkcenterSchedule(
    String projectId,
    String workcenterId,
  ) async {
    final rows =
        await (_db.select(_db.workcenterSchedulePeriods)..where(
              (s) =>
                  s.projectId.equals(projectId) &
                  s.workcenterId.equals(workcenterId),
            ))
            .get();
    return WorkcenterScheduleSpec([for (final row in rows) _toSpec(row)]);
  }

  static WorkcenterSchedulePeriodSpec _toSpec(WorkcenterSchedulePeriod row) =>
      WorkcenterSchedulePeriodSpec(
        startDate: row.startDate,
        endDate: row.endDate,
        operatorsPerShift: parseOperatorsPerShift(row.operatorsPerShift),
        availability: row.availability,
        rework: row.rework,
      );

  // --- Calendar exceptions ------------------------------------------------

  Stream<List<CalendarException>> watchExceptions(String projectId) =>
      (_db.select(_db.calendarExceptions)
            ..where((e) => e.projectId.equals(projectId))
            ..orderBy([(e) => OrderingTerm(expression: e.date)]))
          .watch();

  /// Adds an exception for every day in `[from, to]`.
  ///
  /// Ranges are expanded on entry rather than stored as intervals, so every
  /// lookup downstream is a map hit instead of an interval search — and the
  /// "one exception per day per scope" rule the schema enforces stays
  /// expressible.
  Future<void> addExceptionRange({
    required String projectId,
    required DateTime from,
    required DateTime to,
    required CalendarExceptionKind kind,
    required CalendarExceptionScope scope,
    String? scopeId,
    List<int>? operatorsPerShift,
    String? note,
  }) async {
    final now = DateTime.now();
    final rows = <CalendarExceptionsCompanion>[];
    for (
      var day = dateOnly(from);
      !day.isAfter(dateOnly(to));
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      rows.add(
        CalendarExceptionsCompanion.insert(
          id: newId(),
          projectId: projectId,
          date: day,
          kind: kind,
          scope: scope,
          // `''` is the plant-wide sentinel; see `CalendarExceptions.scopeId`.
          scopeId: Value(scopeId ?? ''),
          operatorsPerShift: Value(
            operatorsPerShift == null
                ? null
                : formatOperatorsPerShift(operatorsPerShift),
          ),
          note: Value(note),
          createdAt: now,
        ),
      );
    }
    await _db.batch((b) {
      // Re-entering an overlapping range replaces what was there rather than
      // failing on the uniqueness constraint: the user's second answer for a
      // day is the one they mean.
      b.insertAll(
        _db.calendarExceptions,
        rows,
        onConflict: DoUpdate(
          (old) => CalendarExceptionsCompanion(
            kind: rows.first.kind,
            operatorsPerShift: rows.first.operatorsPerShift,
            note: rows.first.note,
          ),
          target: [
            _db.calendarExceptions.projectId,
            _db.calendarExceptions.date,
            _db.calendarExceptions.scope,
            _db.calendarExceptions.scopeId,
          ],
        ),
      );
    });
  }

  Future<void> deleteException(String id) =>
      (_db.delete(_db.calendarExceptions)..where((e) => e.id.equals(id))).go();

  Future<List<ScopedCalendarException>> _loadScopedExceptions(
    String projectId,
  ) async {
    final rows = await (_db.select(
      _db.calendarExceptions,
    )..where((e) => e.projectId.equals(projectId))).get();
    return [
      for (final row in rows)
        ScopedCalendarException(
          date: row.date,
          kind: row.kind,
          scope: row.scope,
          // Back to null at the boundary, so nothing above this line has to
          // know about the sentinel.
          scopeId: row.scopeId.isEmpty ? null : row.scopeId,
          operatorsPerShift: row.operatorsPerShift == null
              ? null
              : parseOperatorsPerShift(row.operatorsPerShift),
        ),
    ];
  }

  // --- Assembly -----------------------------------------------------------

  /// The calendar for one workcenter in one project.
  ///
  /// Pulls together the three things the engine needs and nothing else: the
  /// plant's shift pattern, the workcenter's staffing over time, and the
  /// project's exceptions narrowed to this workcenter. A line-scoped exception
  /// reaches a workcenter through its home line, which is the only line the
  /// resource tree says it belongs to.
  ///
  /// Returns null when the project or its pattern has gone missing — a state
  /// the readiness panel reports rather than one to throw on mid-render.
  Future<WorkingCalendar?> loadWorkcenterCalendar({
    required String projectId,
    required String workcenterId,
  }) async {
    final project = await (_db.select(
      _db.projects,
    )..where((p) => p.id.equals(projectId))).getSingleOrNull();
    if (project == null) return null;

    final pattern = await _resources.loadPatternSpec(project.shiftPatternId);
    if (pattern == null) return null;

    final workcenter = await (_db.select(
      _db.workcenters,
    )..where((w) => w.id.equals(workcenterId))).getSingleOrNull();
    if (workcenter == null) return null;

    final staffing = await loadWorkcenterSchedule(projectId, workcenterId);
    final scoped = await _loadScopedExceptions(projectId);

    return WorkingCalendar.scheduled(
      pattern: pattern,
      staffing: staffing,
      exceptions: resolveExceptions(
        scoped,
        workcenterId: workcenterId,
        productionLineIds: await _resources.loadWorkcenterLines(workcenterId),
      ),
    );
  }
}
