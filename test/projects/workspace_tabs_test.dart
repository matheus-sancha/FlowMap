import 'package:flowmap/src/features/projects/presentation/workspace_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ten locations, as the two things about them that can be got wrong
/// without a pixel being drawn (#7).
///
/// **This is the property, not the picture.** Phase 3 is a visual round and the
/// map's standing constraint says a green suite does not resolve one — but the
/// claim *"every tab is a location"* is arithmetic: a slug goes out, the same
/// tab comes back, and a slug nobody wrote resolves to something rather than
/// throwing. That is exactly the kind of thing `part_palette_test` proved is
/// worth asserting before reaching for a drive.
void main() {
  group('study tabs', () {
    test('every tab round-trips through its slug', () {
      for (final tab in StudyTab.values) {
        expect(
          StudyTab.fromSlug(tab.slug),
          tab,
          reason: '${tab.slug} must resolve to the tab that wrote it',
        );
      }
    });

    test('the five slugs are distinct', () {
      // Two tabs sharing a slug would make one of them unreachable, and the
      // round-trip above would still pass for whichever won.
      expect(
        StudyTab.values.map((t) => t.slug).toSet(),
        hasLength(StudyTab.values.length),
      );
    });

    test('an unknown slug falls back rather than throwing', () {
      // A hand-typed link, or a location stored by an older build. §12.1's rule
      // that the window reopens where it was left is worth more than being
      // strict about how it got there — so this must not be an exception.
      expect(StudyTab.fromSlug('gantt'), StudyTab.flow);
      expect(StudyTab.fromSlug(''), StudyTab.flow);
      expect(StudyTab.fromSlug(null), StudyTab.flow);
    });

    test('the period control governs Flow and Summary, and only those', () {
      // §12.1's claim, as a predicate. The other three are about the study
      // whatever month it is, and the control is hidden on them (#7).
      expect(
        StudyTab.values.where((t) => t.hasPeriod).toSet(),
        {StudyTab.flow, StudyTab.summary},
      );
    });
  });

  group('simulation tabs', () {
    test('every tab round-trips through its slug', () {
      for (final tab in SimulationTab.values) {
        expect(SimulationTab.fromSlug(tab.slug), tab);
      }
    });

    test('the five slugs are distinct', () {
      expect(
        SimulationTab.values.map((t) => t.slug).toSet(),
        hasLength(SimulationTab.values.length),
      );
    });

    test('an unknown slug falls back to the overview', () {
      expect(SimulationTab.fromSlug('results'), SimulationTab.overview);
      expect(SimulationTab.fromSlug(null), SimulationTab.overview);
    });

    test('the overview is first, because a bare destination redirects to it',
        () {
      // The router sends `/simulation` here, and `_ModeSwitch` sends the
      // Simulation segment here. Both write `SimulationTab.overview.slug`
      // rather than a literal, so this is the assertion that the *order* is
      // what those two mean by "first".
      expect(SimulationTab.values.first, SimulationTab.overview);
      expect(StudyTab.values.first, StudyTab.flow);
    });
  });

  test('the two strips do not share a slug vocabulary by accident', () {
    // Not a rule — `flow` and `float` are different words and `overview` is not
    // a study tab. This pins the one collision that would actually confuse a
    // reader of a URL: the same slug meaning two things in two places.
    final study = StudyTab.values.map((t) => t.slug).toSet();
    final sim = SimulationTab.values.map((t) => t.slug).toSet();
    expect(study.intersection(sim), isEmpty);
  });
}
