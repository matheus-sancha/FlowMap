/// The two tab strips of the project workspace, as values rather than indices
/// (DESIGN.md §12.1, #7).
///
/// **Every tab is a location.** The workspace used to hold a `TabController`
/// for the study's five tabs and a `setState` segmented button for the run's
/// views, so six screens had no URL at all — while §12.1 claimed *"all routes
/// deep-linkable via `go_router`"* and `STRUCTURE.md` said *"no screen
/// reachable only by tapping through"*. These enums are what closed that gap:
/// the router parses a slug into one of them, and the strip reads it back.
///
/// **A slug rather than the index.** An index in a URL breaks the moment a tab
/// is inserted, and a stored window position outlives any such edit — the app
/// reopens where it was left. The slug also makes the location readable, which
/// is half the point of having one.
library;

/// The study's own tabs. Flow stays here: the map is what you *edit*, the Gantt
/// is what you *read*, and #7 drove and rejected splitting them the other way.
enum StudyTab {
  flow('flow'),
  settings('settings'),
  capacity('capacity'),
  demand('demand'),
  summary('summary');

  const StudyTab(this.slug);

  final String slug;

  /// **Falls back rather than throwing.** A bad slug arrives from a hand-typed
  /// link or a location stored by an older build, and neither is a crash —
  /// §12.1's rule that the window reopens where it was left is worth more than
  /// being strict about how it got there.
  static StudyTab fromSlug(String? slug) =>
      values.where((t) => t.slug == slug).firstOrNull ?? flow;

  /// Whether the workspace's period control governs this tab.
  ///
  /// Flow and Summary, the two that carried a stepper of their own. Settings,
  /// Capacity and Demand are about the study whatever month it is — so the
  /// control is **hidden** on them rather than greyed. *That reverses §12.1's
  /// "dimmed rather than hidden, so the strip does not jump"*: the strip no
  /// longer carries the results link, so there is nothing left to jump (#7).
  bool get hasPeriod => this == flow || this == summary;
}

/// The five tabs of the *Simulation results* destination.
///
/// **The destination and its first tab deliberately do not share a name** — the
/// entry point says *Simulation results*, the tab says *Simulation Overview*,
/// so the button and the tab never read as the same thing (#7).
enum SimulationTab {
  overview('overview'),
  plan('plan'),
  gantt('gantt'),
  occupation('occupation'),
  float('float');

  const SimulationTab(this.slug);

  final String slug;

  static SimulationTab fromSlug(String? slug) =>
      values.where((t) => t.slug == slug).firstOrNull ?? overview;
}
