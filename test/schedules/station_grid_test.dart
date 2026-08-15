import 'package:flowmap/src/features/schedules/application/station_grid.dart';
import 'package:flutter_test/flutter_test.dart';

/// The combined station grid's row model (DESIGN.md §12.6).
///
/// This is the part of the merge that can be wrong without looking wrong: a
/// pasted block lands on rows belonging to several stations, and writing it to
/// the wrong one produces a schedule that is plausible and false.
void main() {
  const stations = <StationPeriods>[
    (workcenterId: 'w1', name: 'CLAD07', periods: 2),
    (workcenterId: 'w2', name: 'CEU27', periods: 1),
  ];

  group('rows', () {
    test('every station carries its own append row', () {
      final rows = stationGridRows(stations);

      // 2 + append, then 1 + append.
      expect(rows.map((r) => '${r.workcenterId}:${r.localRow}'), [
        'w1:0',
        'w1:1',
        'w1:2',
        'w2:0',
        'w2:1',
      ]);
      expect(rows.map((r) => r.isAppend), [false, false, true, false, true]);
    });

    test('a station with no periods is one blank row, not none', () {
      // Otherwise a station in the flow that nobody has scheduled yet has no
      // way into the grid at all — which is exactly the station most in need
      // of a row.
      final rows = stationGridRows(const [
        (workcenterId: 'w1', name: 'CLAD07', periods: 0),
      ]);

      expect(rows, hasLength(1));
      expect(rows.single.isAppend, isTrue);
      expect(rows.single.localRow, 0);
    });
  });

  group('splitting a pasted block', () {
    final rows = stationGridRows(stations);

    test('a block inside one station stays one slice', () {
      final slices = splitStationPaste(
        rows: rows,
        row: 0,
        block: [
          ['a'],
          ['b'],
        ],
      );

      expect(slices, hasLength(1));
      expect(slices.single.workcenterId, 'w1');
      expect(slices.single.localRow, 0);
      expect(slices.single.block, hasLength(2));
    });

    test('a block crossing a station boundary is cut at it', () {
      // **The case the merge exists to get right.** Four rows dropped on the
      // second row of CLAD07 cover its last period, its append row, and then
      // CEU27's period and append row — and every one of those has to be
      // planned against the station that owns it.
      final slices = splitStationPaste(
        rows: rows,
        row: 1,
        block: [
          ['a'],
          ['b'],
          ['c'],
          ['d'],
        ],
      );

      expect(slices, hasLength(2));
      expect(slices[0].workcenterId, 'w1');
      expect(slices[0].localRow, 1);
      expect(slices[0].block, [
        ['a'],
        ['b'],
      ]);
      expect(slices[1].workcenterId, 'w2');
      expect(slices[1].localRow, 0);
      expect(slices[1].block, [
        ['c'],
        ['d'],
      ]);
    });

    test('rows past the end of the grid are dropped, not stacked', () {
      // There is no station below the last one, so there is nothing those rows
      // could be about. Stacking them onto the last station would write
      // periods the reader never aimed at.
      final slices = splitStationPaste(
        rows: rows,
        row: 4,
        block: [
          ['a'],
          ['b'],
          ['c'],
        ],
      );

      expect(slices, hasLength(1));
      expect(slices.single.workcenterId, 'w2');
      expect(slices.single.localRow, 1);
      expect(slices.single.block, hasLength(1));
    });

    test('a single typed cell is a one-row block like any other', () {
      final slices = splitStationPaste(
        rows: rows,
        row: 3,
        block: [
          ['x'],
        ],
      );

      expect(slices, hasLength(1));
      expect(slices.single.workcenterId, 'w2');
      expect(slices.single.localRow, 0);
    });
  });
}
