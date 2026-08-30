# FlowMap — what is next

**Fresh start, 2026-08-30.** Everything that stood here before — every phase, every numbered
section from §0 to §9, every unstarted item carried forward since 2026-08-15 — has been scrapped
by decision. It is not lost: the last version is at the **`v1.0`** tag
(`git show v1.0:docs/TODO.md`), and `docs/HISTORY.md` still holds what actually happened while
`docs/DESIGN.md` still holds why. Both remain authoritative.

What was scrapped was the *forward* plan only. The shipped app is **Version 1.0**, tagged at
`0d32838`, and is not touched again.

## Version 2.0

Work happens on branch **`v2.0`**.

The v2.0 plan is not written here yet, on purpose. It is being charted as a **wayfinder map** on
GitHub Issues, and this file gets the phases once the map has made them clear — that is the map's
own last ticket.

**The map: [FlowMap v2.0 — re-designed surface, simpler plant model](https://github.com/matheus-sancha/FlowMap/issues/4)**

Read the map before starting a session; it is the index. Zoom into a ticket only when you take it.
The frontier — open, unclaimed, unblocked — is the GraphQL query in the wayfinder skill's
`GITHUB.md`, and it renders in GitHub's own UI too.

### Already landed on `v2.0`

Four unambiguous adjustments were executed before the map opened, rather than ticketed:

- The duplicate **Simulation** button under *New study* in the studies sidebar is gone. The run is
  now reached from where it is read — *Simulation results* on the tab strip, and the banner a
  finished run raises.
- *View results* → **Simulation results** (`simViewResults`).
- *In simulation* → **Simulation settings** (`studySettingsInRuns`).
- *Include in runs* → **Include in simulation** (`studyIncludeInRuns`).

All three in en, es and pt. `flutter analyze` clean, **989 tests passing**.

One loose end they left: **`simWorkspace` is now unused** in `lib/`. It is still in all three ARB
files, kept deliberately because the navigation ticket is likely to want a title for the results
destination. Delete it if that ticket decides otherwise.
