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

The plan below is the output of the wayfinder map
**[FlowMap v2.0 — re-designed surface, simpler plant model](https://github.com/matheus-sancha/FlowMap/issues/4)**,
whose last ticket was
[What are v2.0's phases, and in what order?](https://github.com/matheus-sancha/FlowMap/issues/11).
Every phase below is the *summary*; the ticket linked beside it holds the reasoning, the rejected
alternatives and the live-database evidence, and is what a session building that phase should read
first. Nothing here restates a decision — it points at the one place each lives.

### How a phase works

- **Shippable and drivable on its own.** A phase ends with the suite green, `flutter analyze`
  clean, and the evidence that phase owes (below) recorded.
- **Its strings land in all three locales.** `app_en.arb`, `app_es.arb`, `app_pt.arb` and a
  `flutter gen-l10n`, in the same commit as the code. This is no longer a habit: `l10n_test.dart`
  asserts `lib/src/l10n/untranslated.json` is empty, so a phase cannot ship English-only without
  failing the build. 567 keys, three locales, currently clean.
- **Migrations are one per phase and never combined.** The live database is opened daily, and one
  merged migration would make *"don't open the app between phases"* an unwritten precondition
  ([#6](https://github.com/matheus-sancha/FlowMap/issues/6)).

### The phases

| # | Phase | Schema | Ticket |
|---|---|---|---|
| 1 | Queue as an aspect | **v27** | [#5](https://github.com/matheus-sancha/FlowMap/issues/5) — **done, driven** |
| 2 | Priority goes | **v28** | [#6](https://github.com/matheus-sancha/FlowMap/issues/6) — **done** |
| 3 | Navigation | — | [#7](https://github.com/matheus-sancha/FlowMap/issues/7) |
| 4 | Grids | — | [#10](https://github.com/matheus-sancha/FlowMap/issues/10) |
| 5 | Occupation | **v29** | [#9](https://github.com/matheus-sancha/FlowMap/issues/9) |
| — | ~~Part identity~~ | — | [#12](https://github.com/matheus-sancha/FlowMap/issues/12) — **executed, not phased** |

**The plant model first, then the surface.** The two tracks barely touch, and this order means the
two migrations land while the presentation layer is still the one the tests were written against,
and the large surface work then runs on a settled model. It is also the order the tickets already
recorded their migration numbers in, so no resolution has to be corrected.

Schema is at **v28** (`database.dart:78`). **147 runs are stored** — 146 with step rows and one
empty. (`DRIVE-2026-08-29.md` says 104; that was true at schema v22 on 29 August.)

---

#### Phase 1 — Queue as an aspect · schema v27

A queue was only ever keyed by its target, so it does not need a name of its own.

- `project_queues.name` is dropped; the caption is **derived** as `<queue type> - <target>` —
  `FIFO - CLAD07`, and `Queue - CEU27` for an untyped lane, renamed from *Push*. The striped VSM
  arrow keeps the word *Push*.
- The step's `label` goes with it, so a box is its station everywhere.
- The invariant: **one queue per dispatch target, not per workcenter.** A machine reached both
  directly and through a pool genuinely has two lines.
- **Short queue-type names, in three languages.** The derived caption needs them —
  `Earliest need date - CLAD07` does not fit a 140 pt process box. Left to this phase by #5 as too
  small to ticket.

*The live database decided three of these*: all 15 queue names are `FIFO ` plus a mangled target
name, only 2 of 25 steps carry a label and both spell one pool differently, and no spine revisits a
target. **Stored runs survive untouched.**

**Evidence — the live-database check is done** (`19813d6`). The migration ran against a copy of
the real 149 MB database: it upgraded to v27, `PRAGMA integrity_check` returned `ok`, both columns
are gone, and **all 15 queues and all 25 steps survived** with 250 orders, 147 runs and 189,623
step rows untouched. Seven of the fifteen are untyped, exactly the seven #5 predicted, and every
caption derives — including `FIFO · CLAD Pool - Célula 11B/C`, the pool whose own name contains a
hyphen and is why the separator is a middot. `live_db_check_test.dart` carries the assertions.

**The drive is done** — `docs/DRIVE-queue.md`, 2026-08-30 under `0.1.0-2026-08-30a`, session
21:20:45, `db.open schema 27 from 27`. Reported correct for the group; recorded there as a group
result and not itemised, which §5.3 is the standing warning about.

**What the drive settled that nothing else could.** The Gantt read against a *stored* run shows the
caption unchanged — `gantt_view.dart:355` draws `lane.name` when the run carries one, and all 147
runs stored before this phase do. That is §7.10 working, and it means those runs' Gantts keep saying
`FIFO BAN` and `FIFO CLAD` permanently while the map says `Queue · BAN11` and
`FIFO · CLAD Pool - Célula 11B/C`. Left standing; nobody decided otherwise. A simulation was then
run — `e0d93a45`, 21:26, **148 runs** — and stores **`name` NULL on all 15 lanes**, so the derive
path is live. That is the first evidence for `19813d6`'s one deliberate deviation from #5, which
asked for the caption to be written in and got null instead so it re-derives in the reader's
language.

**One finding, recorded and not actioned — phase 2 carries it.** That run stores `rule = fifo` on
all 15 lanes, including the seven `project_queues` holds as null.
`simulation_repository.dart:129` loads a queue as `rule: row.rule ?? DispatchRule.fifo`, erasing the
null at the boundary into the sim model — correct for the engine, and harmless while `SimLane.rule`
was write-only. **This phase made it load-bearing**, so those seven derive `FIFO · CEU27` on the
Gantt while the map draws `Queue · CEU27`: §5.5's *null is not FIFO* holds on the map and is lost on
the run. The fix is a nullable `SimQueue.rule` with the FIFO default applied where the engine sorts
rather than where the project loads — **which is phase 2's own comparator**, so it goes there rather
than reopening this phase.

---

#### Phase 2 — Priority goes · schema v28

Study Priority is **a lever nobody has ever pulled, wired below arrival so it could not expedite
anything even if they had**. One read site, `engine.dart:955`.

- Study priority is deleted, and `simulation_run_studies.priority` with it — that column is
  **write-only**, read by no surface in the app.
- The vacated comparator slot is refilled with the **need date**, because 27 of the 78 real
  cross-study ties in 189,623 step rows were settled by comparing two **UUIDs**. *"Why did this
  order go first?"* was unanswerable a third of the time.

- **Inherited from phase 1's drive: `SimQueue.rule` becomes nullable**, and the FIFO default moves
  to where the engine sorts rather than `simulation_repository.dart:129`, which currently loads
  `rule: row.rule ?? DispatchRule.fifo` and erases the null before the run's copy-in can see it.
  Run `e0d93a45` stores `fifo` on all 15 lanes while the project holds 8 and 7. Harmless while the
  column was write-only; phase 1 made it the Gantt caption, so seven untyped lanes now derive
  `FIFO · CEU27` there while the map draws `Queue · CEU27`. This phase is already rewriting the
  comparator that applies the default, which is why it lands here.

*The live database proves it never fired*: all 3 studies and all 324 stored study rows across 147
runs sit at the default 100, so deleting it is a provable no-op on every run ever stored.

**A re-run after this phase will not match a run stored before it.** Nothing is stamped on the run
to say so — a run already carries `created_at` and the history picker already orders by it.
**`docs/HISTORY.md` gets the line** instead: the date this phase landed, and that runs before it
break cross-study ties by UUID while runs after it break them by need date.

**Evidence — the live-database check is done.** The migration ran against a copy of the real 150 MB
database: upgraded to v28, `integrity_check` ok, both priority columns gone, and **3 studies, 327
stored study rows, 148 runs, 191,494 run steps, 250 orders and 15 queues** intact. All 3 studies and
all 327 stored study rows sat at the default 100, so the drop is a provable no-op on every run ever
stored. `live_db_check_test.dart` carries the assertions; `HISTORY.md` §6.2 carries the figures and
the tie-break line.

**The re-run diff is done too, and it corrects this phase's own prediction.**
`live_tiebreak_check_test.dart` re-runs Célula 11B/C/D on today's input and diffs against
`e0d93a45` — the newest stored run, and the last made under the old fall-through, so it is the least
drifted baseline available. Result: **1,871 steps on both sides, zero input drift, and not one step
starting at a different second.**

#6 expected a re-run not to match. Both figures are true and they answer different questions: *27 of
78 ties settled by a UUID* is about how a run was **explained**, which is why the slot was refilled;
*how many orders move* is smaller. Across all 148 stored runs there are **80 cross-study arrival
ties, 61 still resolvable** — the other 19 name deleted orders — **and the need date reorders 4.**
`e0d93a45` has two, and the need date agrees with the old key on both. **The comparability worry is
much smaller than this phase assumed.** `HISTORY.md` §6.2 has the figures.

*The check had a defect worth knowing about*: comparing the moments directly reported 1,862 of 1,871
steps moved, all by a fraction of a second — `simulation_run_steps` stores whole seconds and the
in-memory result does not. It compares at the stored resolution now.

**No drive: nothing visual changed.** The one caption that did is covered by a query and by
`run_storage_test.dart`.

*One assertion was written for the live check and removed after it failed correctly* — see
`HISTORY.md` §6.2. Null in `simulation_run_lanes.rule` means both *unset* and *never recorded*
across generations, so it cannot prove the fix; `run_storage_test.dart` does that instead.

---

#### Phase 3 — Navigation

**Two modes of one project, and every tab is a route.** The largest phase, and the one that closes
the gap between §12.1's *"all routes deep-linkable"* and six screens that had no URL.

- A `Study | Simulation` switch above the tab strip. Flow stays a study tab.
- The run is the *Simulation results* destination, with five tabs: **Simulation Overview,
  Production Plan, Production Gantt, Occupation, Delivery Float**.
- **Ten `go_router` locations** replace a `TabController` and a `setState` switcher.
- Readiness becomes a red strip under the app bar; the period control is hidden rather than greyed.
- The filter bar governs all five tabs, with §12.1's whole-run caveat kept inline.
- `simWorkspace` — unused in `lib/` since the pre-map renames — is either used as this
  destination's title or deleted.

**Left to this phase deliberately:** whether the results filter rides in the URL. `?study=` already
does; §12.1 argued the other six should not. Nothing has decided otherwise, so keep §12.1's answer
unless this phase finds a reason.

Settled by four driven rounds of a prototype on the real database, which also rejected *"Define vs
Read"* and a flat nine-tab strip. The prototype is deleted, so **#7's write-up is what this phase
lifts from.**

**Evidence owed:** `docs/DRIVE-nav.md` — ten routes reached by URL, the mode switch, the readiness
strip. **Plus the first light-mode pass since the tokens drive**: light is still visually
unverified, and this is the phase where the most screens change at once.

---

#### Phase 4 — Grids

Three interaction adjustments turned out to be three local behaviours, not one shared one.

- **`onReorder(int from, int to)` on `DataGrid`, and exactly one caller passes it.**
  `demand_orders` is the only table with a `sequence` column; `demand_parts` has none and its row
  number is a display index. Drag by the **row-header number** — already a frozen 44 px slot — so
  nothing inside a cell is draggable and text selection is untouched.
  `moveOrder(studyId, from, to)` already does an arbitrary insert, so **the data layer needs
  nothing**. The studies hold 60, 60 and 130 orders; expect edge auto-scroll to be the hard part.
- **Sorting, wired to the surfaces the rule names.** The rule: *a surface sorts unless its row
  order is itself data.* Queue ranking, share of flow, the parts table and the summary table sort.
  The production plan does not — its order is the release sequence — and neither does the float
  matrix, whose row *r* means rank *r* in that column. No editable grid sorts.
  `resultTable`'s `sortColumn` / `sortAscending` / `onSort` have had no caller since #7; this is
  what gives them one.
- **The paired-layout rule into `docs/DESIGN.md` §12.5**: *two tables pair when they are one
  question read two ways*, collapsing to stacked under 1100 px. Already implemented on the
  Overview by #7; recorded here as the rule, honestly noted as inferred from its single instance.

**Evidence owed:** `docs/DRIVE-grids.md` — drag a row across all 130, sort each of the four
surfaces and confirm the two that must not offer it do not.

---

#### Phase 5 — Occupation · schema v29

**A station × month grid, not a chart.** Across all three runs that can draw this view — 3 of 147;
the rest predate v25's monthly capacity — the aggregate bar has **never once broken its capacity
line** (peak 87 %) while single stations hit **149 %**.

- **`period_matrix.dart` extracted here rather than in phase 4**, so it has both its callers from
  the start: the float matrix and this grid.
- `occupation_graph.dart` → rows × months, two groupings (per workcenter, per line), three units
  (`%`, `733/499` hours, `-234` gap).
- `occupation_view.dart` → the grid, a PLANT row shown only when nothing has narrowed the station
  set, two switches. **The stacked-bar painter and its legend are deleted.**
- `run_filter.dart` gains `typeIds` and `workcenterIds`; `OccupationStations` is absorbed and
  deleted. **Structural filters** (studies, cells, lines, type, workcenter) choose the station set
  so demand and capacity move together; **order-level filters** (projects, parts, order numbers)
  leave capacity fixed and dim the remainder.
- `simulation_workspace.dart` — the two station pickers are **promoted** into the shared filter
  bar, not deleted. `gantt_view.dart` and `simulation_tab.dart` obey them, because their rows are
  stations too.
- **Schema v29**: `occupationAmberPct` and `occupationRedPct` on the project, defaulting to 85 and
  100, plus the settings surface beside the float thresholds.
- `tokens.dart` — **`OccupationRamp` is retired.** It coloured a stack that no longer exists;
  `FlowStatus` good/warning/critical is what the bands use.
- The grid is built sortable, per phase 4's rule.

**No stored run is invalidated.** The 3 graphable runs already carry everything the grid reads, and
the 144 that cannot draw it could not draw the chart either.

**Evidence owed:** `docs/DRIVE-occupation.md` — the grid on the real run, both groupings, all three
units, and a project whose thresholds have been changed from the defaults.

---

#### Phase 6 — Part identity · **there isn't one**

It was named here as a slot [#12](https://github.com/matheus-sancha/FlowMap/issues/12) would fill
in. #12 resolved by **disproving its own premise** — eight mutually-distinguishable colours do
exist under FlowMap's constraints, so no encoding had to change — and the whole of it was small
enough to execute inside the ticket (`2cb0126`). Nothing is left to phase.

The one thing a later phase inherits is a *rule*, not a task: **a hue changed in
`part_palette.dart` is re-validated, never eyeballed.** Headroom over the floors is 0.7 and 1.6 ΔE,
and `part_palette_test` now measures all pairs — which is what would have caught both of the
palettes it has replaced.

---

### Already executed, and so not a phase

Each was unambiguous enough to land inside its own ticket, per the map's rule that a ticket whose
answer is unambiguous is executed rather than planned.

| Commit | What |
|---|---|
| `1d4cb0d` | Four renames, before the map opened: the duplicate **Simulation** button under *New study* gone; *View results* → **Simulation results**; *In simulation* → **Simulation settings**; *Include in runs* → **Include in simulation**. |
| `8daf2a8` | [#8](https://github.com/matheus-sancha/FlowMap/issues/8) — the seed off green to blueprint blue `#1F5C8B`, status colours and the occupation ramp chosen explicitly, space/radius/motion scales named. Two palette defects fixed that two tests had agreed were fine. |
| `3d82715` | [#7](https://github.com/matheus-sancha/FlowMap/issues/7) — the Delivery Float was painting the band named *green* in the brand's blue; a real legend in three locales; `fill:` on the overview tables; optional sorting on `resultTable`. |
| `9264a90` | [#10](https://github.com/matheus-sancha/FlowMap/issues/10) — the arrows leave a cell only once the caret cannot; the Gantt pans on middle-drag or space+drag; `centred_table.dart` deleted, having had zero callers. |
| `2cb0126` | [#12](https://github.com/matheus-sancha/FlowMap/issues/12) — eight all-pairs part colours, which the ticket had recorded as infeasible; `part_palette_test` switched from adjacent to all pairs, and checked against the palette it replaces. |

### Standing constraints

- **Nothing in the suite renders a pixel.** v1.0's drives repeatedly found defects the tests had
  nothing to say about, and this map's own record is the same — the tokens palette and the float
  matrix colour were both corrected by driving, within the hour, against a green suite. **A visual
  phase is not finished by a green suite.**
- **But more is testable than it looks.** `part_palette_test` catches a genuinely visual defect
  while rendering nothing, by asserting the *property*. Phase 4's own work went in the same way:
  which cell holds focus, where the caret sits, and the scroll offset before and after a drag.
  Reach for that before reaching for a drive; what is left over is genuinely only *feel*.
- `docs/DESIGN.md` is why, `docs/HISTORY.md` is what happened. Both survive from v1.0 and are
  still authoritative.
- §7.10's copy-in rule is the precedent for what a stored run must carry to stay readable.
