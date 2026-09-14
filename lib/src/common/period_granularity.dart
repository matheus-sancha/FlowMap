/// How wide a span of calendar time a period is (DESIGN.md §12.8).
///
/// **Shared, because two features bucket by it and they must agree.** It was
/// the Flow map's period navigator alone — how far one step of the stepper
/// moves — until #17 gave the Occupation grid the same four columns. A plant
/// whose Flow map steps a quarter at a time and whose Occupation grid cannot
/// show one would be two apps, so there is one enum and one definition of what
/// a semester is.
///
/// **A semester is a calendar half**, January–June and July–December. Nothing
/// in the schema carries a fiscal year start, so there is no other half to
/// mean; making it configurable is a schema question and not this one.
library;

enum PeriodGranularity {
  month,
  quarter,
  semester,
  year;

  /// The first day of the span containing [date].
  ///
  /// This is also **the bucketing key**: two dates in the same span share a
  /// `startOf`, which is what lets a matrix column, a chart bar and a stepper
  /// position all be the same `DateTime` without anyone converting.
  DateTime startOf(DateTime date) => switch (this) {
    PeriodGranularity.month => DateTime(date.year, date.month),
    PeriodGranularity.quarter => DateTime(
      date.year,
      ((date.month - 1) ~/ 3) * 3 + 1,
    ),
    PeriodGranularity.semester => DateTime(date.year, date.month <= 6 ? 1 : 7),
    PeriodGranularity.year => DateTime(date.year),
  };

  /// The last day of that span.
  DateTime endOf(DateTime date) {
    final start = startOf(date);
    return DateTime(start.year, start.month + months, 0);
  }

  int get months => switch (this) {
    PeriodGranularity.month => 1,
    PeriodGranularity.quarter => 3,
    PeriodGranularity.semester => 6,
    PeriodGranularity.year => 12,
  };

  /// The span [steps] spans away, keeping the same granularity.
  DateTime shift(DateTime date, int steps) {
    final start = startOf(date);
    return DateTime(start.year, start.month + months * steps);
  }
}
