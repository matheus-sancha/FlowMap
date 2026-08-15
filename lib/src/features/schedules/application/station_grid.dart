/// The row model of the combined station grid (DESIGN.md §12.6).
///
/// One grid holds every station of a study's flow, so a planner reads staffing
/// down a column instead of across seven cards — and a year of periods for the
/// whole line arrives from Excel in one block, which is how they actually
/// arrive. What that costs is a row index that no longer means "the nth period
/// of the station this grid is about", because the grid is about all of them.
///
/// Pure and widget-free for the reason `gantt_layout.dart` is: resolving a
/// pasted block across station boundaries is the part that can be wrong in ways
/// nobody notices, and it should be checkable without pumping a frame.
library;

/// One row of the combined grid: a station's period, or its blank append row.
///
/// **Every station gets its own append row**, rather than one blank row at the
/// bottom with a station picker on it. A picker would be a control that has to
/// be set before the row means anything, and a row that means nothing until a
/// dropdown is touched is not the "type into the row past the end" rule §9.1
/// established — it is a dialog wearing a row's clothes.
typedef StationGridRow = ({
  String workcenterId,
  String name,
  /// The index of this row within its own station's periods. Equal to the
  /// station's period count on the append row.
  int localRow,
  bool isAppend,
});

/// A station and how many periods it currently holds.
typedef StationPeriods = ({String workcenterId, String name, int periods});

/// Lays the stations out as one list of rows, in the order given.
///
/// The order is the caller's: the tab sorts by name, which is what the cards
/// this replaces did.
List<StationGridRow> stationGridRows(List<StationPeriods> stations) => [
  for (final station in stations) ...[
    for (var i = 0; i < station.periods; i++)
      (
        workcenterId: station.workcenterId,
        name: station.name,
        localRow: i,
        isAppend: false,
      ),
    (
      workcenterId: station.workcenterId,
      name: station.name,
      localRow: station.periods,
      isAppend: true,
    ),
  ],
];

/// One station's share of a pasted block.
typedef StationPasteSlice = ({
  String workcenterId,
  int localRow,
  List<List<String>> block,
});

/// Splits a block pasted at [row] across the stations its rows land on.
///
/// **Row for row, the way a spreadsheet paste means it.** A forty-row block
/// dropped on the third row of the first station covers the rows beneath it,
/// and those rows belong to whichever stations they belong to — so the block is
/// cut at each station boundary and each piece is planned against its own
/// station's periods by `planSchedulePeriodWrite`, which stays pure and
/// per-station and did not have to learn about any of this.
///
/// _Rejected: clipping the block at the first station boundary._ It makes a
/// paste that writes some of what was pasted and silently drops the rest, which
/// is the one outcome worse than refusing.
///
/// _Rejected: appending everything past a station's last row to that station._
/// It reads well for one station and means a block pasted mid-grid writes rows
/// nowhere near where the reader dropped it.
///
/// Rows past the end of the grid are **dropped**: there is no station below the
/// last one, so there is nothing they could be about. A block longer than the
/// grid is the one case where a paste is knowingly partial, and it is partial in
/// the direction the reader can see.
List<StationPasteSlice> splitStationPaste({
  required List<StationGridRow> rows,
  required int row,
  required List<List<String>> block,
}) {
  final slices = <StationPasteSlice>[];

  for (var r = 0; r < block.length; r++) {
    final target = row + r;
    if (target < 0 || target >= rows.length) continue;
    final at = rows[target];

    // Extend the open slice while the rows keep belonging to one station and
    // stay consecutive within it — which they do by construction, but stating
    // it here is what makes the append below safe to read.
    final open = slices.isEmpty ? null : slices.last;
    if (open != null &&
        open.workcenterId == at.workcenterId &&
        open.localRow + open.block.length == at.localRow) {
      open.block.add(block[r]);
      continue;
    }

    slices.add((
      workcenterId: at.workcenterId,
      localRow: at.localRow,
      block: [block[r]],
    ));
  }

  return slices;
}
