import 'package:flowmap/src/features/flow/application/flow_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dragging a step to a new place in the spine (§8.4).
///
/// **The arithmetic is the whole risk here.** An `InsertionPoint.position` is a
/// gap in the list as drawn; `moveNode`'s `to` is an index in the list after
/// the dragged step has been taken out of it. Off by one in either direction
/// and the map still reorders, still looks plausible, and puts the step
/// somewhere the reader did not point at — which is the kind of defect that
/// only shows up as "the drag feels wrong".
void main() {
  /// What `StudiesRepository.moveNode` does to a list, so the mapping is
  /// checked against the order a reader is left looking at rather than against
  /// an index nobody sees.
  List<String> dropped(
    List<String> spine, {
    required int from,
    required int gap,
  }) {
    final to = dropTarget(from: from, gap: gap);
    if (to == null) return spine;
    final out = [...spine];
    out.insert(to, out.removeAt(from));
    return out;
  }

  // Five steps, so there are six gaps: 0 before A, 5 after E.
  const spine = ['A', 'B', 'C', 'D', 'E'];

  group('the gaps a step already sits between do nothing', () {
    test('the gap immediately before it', () {
      expect(dropTarget(from: 2, gap: 2), isNull);
      expect(dropped(spine, from: 2, gap: 2), spine);
    });

    test('the gap immediately after it', () {
      expect(dropTarget(from: 2, gap: 3), isNull);
      expect(dropped(spine, from: 2, gap: 3), spine);
    });

    test('both ends of the spine, where only one neighbour exists', () {
      expect(dropTarget(from: 0, gap: 0), isNull);
      expect(dropTarget(from: 0, gap: 1), isNull);
      expect(dropTarget(from: 4, gap: 4), isNull);
      expect(dropTarget(from: 4, gap: 5), isNull);
    });
  });

  group('dragging right', () {
    test('one place', () {
      expect(dropped(spine, from: 1, gap: 3), ['A', 'C', 'B', 'D', 'E']);
    });

    test('to the far end', () {
      expect(dropped(spine, from: 0, gap: 5), ['B', 'C', 'D', 'E', 'A']);
    });

    test('into the middle', () {
      expect(dropped(spine, from: 0, gap: 3), ['B', 'C', 'A', 'D', 'E']);
    });
  });

  group('dragging left', () {
    test('one place', () {
      expect(dropped(spine, from: 3, gap: 2), ['A', 'B', 'D', 'C', 'E']);
    });

    test('to the front', () {
      expect(dropped(spine, from: 4, gap: 0), ['E', 'A', 'B', 'C', 'D']);
    });

    test('into the middle', () {
      expect(dropped(spine, from: 4, gap: 2), ['A', 'B', 'E', 'C', 'D']);
    });
  });

  group('what the two index spaces do not share', () {
    test('a gap right of the step is one place left once it is lifted', () {
      // The mapping stated as the difference it exists to absorb. Gap 4 with
      // the step at 1 is `to` 3, because lifting B moves D and E down one.
      expect(dropTarget(from: 1, gap: 4), 3);
      expect(dropped(spine, from: 1, gap: 4), ['A', 'C', 'D', 'B', 'E']);
    });

    test('a gap left of the step is itself', () {
      expect(dropTarget(from: 3, gap: 1), 1);
      expect(dropped(spine, from: 3, gap: 1), ['A', 'D', 'B', 'C', 'E']);
    });

    test('the gap past the end is the last index once the step is lifted', () {
      // Six gaps over five steps: gap 5 is past E. Lifting one leaves four
      // steps, so the last index is 4 — never 5, which `moveNode` would clamp
      // and quietly turn into a different move.
      expect(dropTarget(from: 2, gap: 5), 4);
      expect(dropped(spine, from: 2, gap: 5), ['A', 'B', 'D', 'E', 'C']);
    });
  });

  group('every drop is either a no-op or lands where it was aimed', () {
    test('across every step and every gap of a five-step spine', () {
      // The exhaustive version of the cases above, and the one that would have
      // caught an off-by-one anywhere in the range rather than at the ends
      // somebody happened to write a case for.
      for (var from = 0; from < spine.length; from++) {
        for (var gap = 0; gap <= spine.length; gap++) {
          final result = dropped(spine, from: from, gap: gap);

          expect(
            result.toSet(),
            spine.toSet(),
            reason: 'from $from into gap $gap lost or duplicated a step',
          );
          expect(result.length, spine.length);

          if (dropTarget(from: from, gap: gap) == null) {
            expect(result, spine, reason: 'a no-op left the spine alone');
            continue;
          }

          // The step lands between whatever the gap was between. Read off the
          // original spine, so this says nothing about how the move was made.
          final before = gap == 0 ? null : spine[gap - 1];
          final after = gap == spine.length ? null : spine[gap];
          final landed = result.indexOf(spine[from]);

          if (before != null) {
            expect(
              result.indexOf(before),
              lessThan(landed),
              reason: 'from $from into gap $gap: $before should be before it',
            );
          }
          if (after != null) {
            expect(
              result.indexOf(after),
              greaterThan(landed),
              reason: 'from $from into gap $gap: $after should be after it',
            );
          }
        }
      }
    });
  });
}
