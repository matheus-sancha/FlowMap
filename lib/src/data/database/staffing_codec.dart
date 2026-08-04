/// The `1/1/1` staffing notation, as the shop floor writes it.
///
/// Operators per shift is a short list indexed by shift position, always read
/// whole, and read on the hot path of every calendar walk — so it is stored in
/// one column rather than a child table (`WorkcenterSchedulePeriods`). This is
/// the only place that format is produced or interpreted.
library;

/// Renders `[1, 1, 0]` as `1/1/0`.
String formatOperatorsPerShift(List<int> operators) => operators.join('/');

/// Reads `1/1/1` back. Unparseable or negative entries read as zero — an
/// unstaffed shift — because a stored value the app cannot understand must not
/// silently become capacity.
List<int> parseOperatorsPerShift(String? encoded) {
  if (encoded == null || encoded.trim().isEmpty) return const [];
  return [
    for (final part in encoded.split('/'))
      switch (int.tryParse(part.trim())) {
        final int value when value > 0 => value,
        _ => 0,
      },
  ];
}

/// The number a schedule row displays as "Shifts", derived rather than stored:
/// a separate count is a second source of truth that can disagree with the list
/// it counts (DESIGN.md §4.2).
int staffedShiftCount(List<int> operators) =>
    operators.where((o) => o > 0).length;
