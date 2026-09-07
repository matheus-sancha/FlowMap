import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/projects/presentation/project_workspace_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which study the workspace is about, in either mode (#18).
///
/// **A defect nobody reported, found under one that was.** The pane complaint
/// was *"when I click to the simulation it is opening the side pane"*; reading
/// the three lines that decide the pane's contents turned up something worse
/// sitting beside it. Study mode carries the study in the path, Simulation mode
/// in `?study=` (§12.1) — and this read only the path, so crossing into
/// Simulation quietly made `selected` the *first* study in the list. The mode
/// switch navigates back to `selected`, so a reader who went from study B to
/// the run and straight back arrived at study A. No error, no message, and the
/// correct id sitting in the URL the whole time.
///
/// No pixel is drawn: it is a property of three arguments, which is what this
/// ticket claimed of itself.
void main() {
  final now = DateTime(2026, 9, 7);

  Study study(String id) => Study(
    id: id,
    projectId: 'project-1',
    name: id.toUpperCase(),
    productionCellId: 'cell-1',
    productionLineId: 'line-1',
    includeInSimulation: true,
    startBufferDays: 0,
    createdAt: now,
    updatedAt: now,
  );

  final studies = [study('a'), study('b'), study('c')];

  test('study mode uses the path id', () {
    expect(
      selectedStudy(studies, pathStudyId: 'b', queryStudyId: null)?.id,
      'b',
    );
  });

  test('simulation mode uses the query id, which is the fix', () {
    // The path id is null on `/projects/p/simulation/:tab`; before #18 this
    // fell straight through to `studies.first` and the run's own `?study=` —
    // already in the URL, already correct — was never consulted.
    expect(
      selectedStudy(studies, pathStudyId: null, queryStudyId: 'b')?.id,
      'b',
      reason: 'arriving from B must not silently become A',
    );
  });

  test('the round trip returns the study it left from', () {
    // The whole defect in one assertion: B, into the run carrying `?study=b`,
    // and the mode switch's target on the way back.
    final inStudyMode = selectedStudy(
      studies,
      pathStudyId: 'b',
      queryStudyId: null,
    );
    final inSimulation = selectedStudy(
      studies,
      pathStudyId: null,
      queryStudyId: inStudyMode!.id,
    );
    expect(inSimulation?.id, inStudyMode.id);
  });

  test('the path wins when both are somehow present', () {
    // Only reachable by a hand-typed link. The path is the location's own
    // answer to which study is showing; the query is how the *other* mode
    // carries one, so the mode you are actually in decides.
    expect(
      selectedStudy(studies, pathStudyId: 'c', queryStudyId: 'a')?.id,
      'c',
    );
  });

  test('an unknown id falls back to the first study', () {
    // A stale link or a deleted study. §12.1's forgiving rule for a bad tab
    // slug applies here for the same reason: the window reopens where it was
    // left, and being strict about how it got there is worth less.
    expect(
      selectedStudy(studies, pathStudyId: 'gone', queryStudyId: null)?.id,
      'a',
    );
    expect(
      selectedStudy(studies, pathStudyId: null, queryStudyId: 'gone')?.id,
      'a',
    );
  });

  test('a project with no studies selects nothing rather than throwing', () {
    expect(
      selectedStudy(const [], pathStudyId: 'a', queryStudyId: null),
      isNull,
    );
  });
}
