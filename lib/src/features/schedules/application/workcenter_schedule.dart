import '../../calendar/application/staffing_schedule.dart';
import 'schedule_periods.dart';

/// A workcenter's staffing and losses over one date range (DESIGN.md §4.2,
/// §4.4). Pure value object; repositories build it from rows.
class WorkcenterSchedulePeriodSpec implements DatedPeriod {
  const WorkcenterSchedulePeriodSpec({
    required this.startDate,
    required this.endDate,
    required this.operatorsPerShift,
    this.availability = 1,
    this.rework = 0,
  });

  @override
  final DateTime startDate;
  @override
  final DateTime endDate;

  /// Indexed by shift position; zero closes that shift.
  final List<int> operatorsPerShift;

  /// Fraction of open time the workcenter can run, 0 < a ≤ 1.
  final double availability;

  /// Fraction of work redone, ≥ 0.
  final double rework;

  /// Displayed as "Shifts", derived by counting rather than stored — a second
  /// number would be a second source of truth.
  int get staffedShiftCount => operatorsPerShift.where((o) => o > 0).length;
}

/// One workcenter's schedule across a project, and the [StaffingSchedule] the
/// calendar walks.
///
/// This is the join between M1's calendar engine and project data: the engine
/// asks "who is on shift that day", and this answers from the period table.
class WorkcenterScheduleSpec implements StaffingSchedule {
  WorkcenterScheduleSpec(Iterable<WorkcenterSchedulePeriodSpec> periods)
    : schedule = PeriodSchedule(periods);

  final PeriodSchedule<WorkcenterSchedulePeriodSpec> schedule;

  List<WorkcenterSchedulePeriodSpec> get periods => schedule.periods;

  @override
  List<int> operatorsOn(DateTime date) =>
      schedule.at(date)?.operatorsPerShift ?? const [];

  @override
  bool get isEverStaffed =>
      periods.any((p) => p.operatorsPerShift.any((o) => o > 0));

  /// Availability in force on [date], for [effectiveProcessTime].
  ///
  /// Falls back to 1.0 where no period covers the date — a date the readiness
  /// panel already blocks on, so the fallback exists to keep this function
  /// total rather than to be relied on.
  double availabilityOn(DateTime date) => schedule.at(date)?.availability ?? 1;

  double reworkOn(DateTime date) => schedule.at(date)?.rework ?? 0;

  PeriodLookup<WorkcenterSchedulePeriodSpec> lookup(DateTime date) =>
      schedule.lookup(date);
}
