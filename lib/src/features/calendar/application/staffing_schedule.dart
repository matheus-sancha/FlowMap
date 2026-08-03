/// Who is on shift, and when.
///
/// A workcenter's staffing changes between schedule periods — three shifts in
/// the first half of the year, two in the second (DESIGN.md §4.2) — so the
/// calendar cannot hold one list of operators. It holds one of these and asks
/// per day.
abstract class StaffingSchedule {
  /// Operators on each shift for [date], indexed by shift position. An empty
  /// list means the workcenter is closed that day, which is also the answer for
  /// a date no schedule period covers.
  List<int> operatorsOn(DateTime date);

  /// Whether any day is staffed at all. Guards the calendar's search loops
  /// against a schedule that could never open.
  bool get isEverStaffed;
}

/// One staffing for all time — the pattern preview in Resources, and every
/// calendar test that is not about periods.
class ConstantStaffing implements StaffingSchedule {
  ConstantStaffing(List<int> operatorsPerShift)
    : operatorsPerShift = List.unmodifiable(operatorsPerShift);

  final List<int> operatorsPerShift;

  @override
  List<int> operatorsOn(DateTime date) => operatorsPerShift;

  @override
  bool get isEverStaffed => operatorsPerShift.any((o) => o > 0);
}
