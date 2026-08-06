# FlowMap — what is next

Working state as of 2026-08-05. `docs/DESIGN.md` remains the source of truth for *why*; this file
is only a plan, and each item should be deleted from it as it lands.

Branch `m1-m2-foundation`, clean, `flutter analyze` clean, 473 tests passing, not pushed.
Schema is at **v11**. M4 is code-complete.

**The Release bundle is ten commits stale.** `build/windows/x64/runner/Release/data/app.so` was
compiled 2026-08-04 07:15, hours before `f97bb68` and `970eb7c` gave the run its button — that
build has no Simulation tab at all. The Debug bundle is current. `flowmap.exe`'s own timestamp
means nothing either way: it is the C++ host shell from `windows/runner/`, which has not changed
since Aug 3, so CMake rightly declines to relink it. Rebuild Release at the end of §1 below, with
a real `--dart-define=BUILD_LABEL=…` — the default is `dev`, and a field report against `dev`
cannot be placed against a specific zip.

---

## 1. Field feedback, 2026-08-05

Ten items from driving the Debug build by hand, each settled by interview before any of it was
written. Ordered so the schema lands once and the UI work sits on top of it.

### 1.1 One migration, v11 → v12 — **done 2026-08-05**

Landed as described, plus two things only doing it could show, both in §16.13:

- `DispatchRule` had to move to `data/database/enums.dart` before a table could name it — the schema
  cannot import `sim_model`, which reaches the calendar. `sim_model` re-exports it, so all 40 call
  sites are untouched.
- **The v9 rebuild broke three versions after the fact.** `TableMigration` copies from the *current*
  Dart definition, so adding `batch_number` made the v9 step that drops `order_number` reach for a
  column no v6-shaped table has ever had. Caught by the existing v6 and v8 fixtures; fixed with a
  constant `NULL` in its `columnTransformer`. **Every future column on `demand_orders` needs the
  same line.**


| Change | Why |
|---|---|
| `demand_orders.batch_number` — nullable text | The identifier of a part number's batch within a customer project. A **free-text label**: no unique key, no validation, blank allowed. It is the planner's number from their own system, the way a works order number would be — and unlike `customer_project` it is not part of what identifies anything, because the order already has an identity in its sequence position. |
| `simulation_run_orders` + `customer_project`, `batch_number`, `batch_size`, `material_date` — all nullable | The Production Plan (§1.5) needs them, and §7.10's rule is that a run copies values in rather than joining, so it stays readable after the demand beneath it is edited. **Nullable, and not backfilled**: the existing Célula 11B run predates them and shows blanks, which is true. Backfilling from today's demand would make one stored run a hybrid of two moments, which is exactly what the copy-in rule exists to prevent. |
| New `workcenter_dispatch(project_id, target_id, rule)` | §1.3's per-station queue discipline. |
| New `simulation_run_dispatch(run_id, target_id, name, rule)` | §1.3's snapshot. |

Add a v11 → v12 fixture to `test/data/migration_test.dart`, and check the half-upgraded-database
path from §16.11 still holds.

### 1.2 Float changes sign — **done 2026-08-05**

`run_metrics.dart` defines float as `delivered − need date`, so positive means **late** — the real
run reported "average float +230.7 d" for a sequence that was badly over-committed. A planner reads
float as slack, where positive means room to spare, and the Production Plan puts the figure in front
of exactly that reader.

Flip it to `need date − delivered` in one place: `RunMetrics.averageFloat`, `simAverageFloatHelp`,
`run_metrics_test.dart`, and the +230.7 d recorded above becomes −230.7 d. One definition, so the
plan's column and the tab's headline figure cannot disagree.

### 1.3 A queue discipline per station — **done 2026-08-05**

One thing the interview did not anticipate, now in §7.4: the rule is stored per *target* but the
engine picks per *server*, and one machine can be a candidate for two steps — its own and a pool's.
Left on the step, two orders at one machine would be ordered by different comparators. `resolveDispatch`
flattens target → member at assembly time, so each server has exactly one rule.

Also found: `ref.read(streamProvider.future)` can be cancelled by Riverpod 3's default auto-dispose
before the stream emits, so the step editor's dialog never opened. The map is now watched by the tab
and passed in. **Worth remembering — the same shape would hang any dialog that reads a stream that way.**


§7.4 has one dispatch rule for the whole run. Each station gets its own FIFO / EDD / SPT instead,
defaulting to the run's, so nothing changes until something is changed.

- **Keyed by `target_id`** — a workcenter id or a pool id, the convention `part_process_times` and
  the demand grid already use. §3.1 makes pool members interchangeable, so the queue forms at the
  pool and the rule belongs to the pool, not to whichever lathe stands for it on the map.
- **Project-scoped, not study-scoped.** §7.7 builds one resource model per run: a station exists
  once however many studies point at it, so a study-scoped rule could have two studies demanding
  different disciplines of one machine, and the engine would have no way to choose.
- **Edited in the flow step editor**, which is the only surface that already knows a node's target
  whether it is a workcenter or a pool — and it is where the queue is visible. Needs a line of
  helper text saying the setting belongs to the station across every study in the project, so the
  shared effect is stated rather than discovered.
- **Recorded in the run.** `simulation_runs.dispatch` alone would report "FIFO" for a run in which
  three stations ran EDD. One row per overridden station with its name copied in, as
  `simulation_run_workcenters` copies `CLAD04`; the run label reads `FIFO (3 stations overridden)`.
  Without this, M5's run comparison could not tell you that the dispatch is what changed.

Ties still break by (arrival, study priority, sequence #), so a run of the same inputs still
produces the same output.

### 1.4 Batch Number on the sequence grid

Between Project and Batch Size, matching the Production Plan's column order. That shifts
`orderBatchColumn` 2 → 3, `orderNeedColumn` 3 → 4 and `orderMaterialColumn` 4 → 5, so a paste block
a user has habitually anchored at a column now lands one over — worth a line in the release note.

**The import's synonyms collide.** `demand_import.dart` gives Batch *Size* the synonyms
`['batch', 'batch size', 'qty', 'quantity', 'lot']`, and bare `batch` and `lot` are precisely what a
column of batch *numbers* is headed. Left alone it would write someone's lot identifier into the
quantity field silently, which is §11's one intolerable bug. So:

- Batch Size keeps `batch size`, `qty`, `quantity`, `lot size`, `size`.
- Batch Number takes `batch number`, `batch no`, `lot number`, `lot no`, `batch id`.
- Bare `batch` and bare `lot` match **neither**, and land in the dialog's unmatched-columns list for
  the user to place by hand. §9.2 already refuses to guess by position; an ambiguous name is not
  evidence either.

Batch Number is per **order**, not per part — nothing changes on the Parts grid.

### 1.5 The Production Plan

`Order | Part Number | Project | Batch Number | Batch Size | Need Date | Material Date | Order Start
Date | Delivery Date | Float`

- **A section in `_Results` on the Simulation tab**, below the per-part table. It reads the stored
  run, so its dates cannot disagree with the run that produced them, and opening an earlier run from
  the history menu opens its plan with it.
- **Order = the sequence position**, 1-based and derived — the same number the sequence grid's row
  header shows. `demand_paste.dart`'s decision that FlowMap carries no works order number stands;
  Batch Number is now the identifier a planner matches against their own paperwork, and a second
  free-text identifier on the same row would be double typing.
- **Order Start Date = `released`** — when the order took its takt slot and entered the flow (§7.2).
  Already stored per order, no join.
- **Delivery Date = `delivered`** — its last semantic step, per §18.1.
- **One section per study, rows in sequence order.** A study is one production line and a production
  plan is a line's plan. §7.2 releases strictly from the head with no reordering, so within a study
  release order *is* sequence order and "over time" needs no sort that could disagree with the Order
  column. No Study column, so the ten columns stand as written.

### 1.6 Arrows become derived

Every arrow is hatched today because `FlowConnectionsPainter` calls `drawPushArrow` unconditionally.
Strictly that is correct — with no supermarkets in the model (§5.5 rejected capacity-limited
buffers) everything is a push. But it is correct by accident, and the map should say so on purpose.

Two inputs, both already real and both typed somewhere they can be validated, which is §5.2's rule:

- **No WIP cap** → hatched push arrows, as now.
- **A CONWIP cap (§7.3)** → open pull arrows. A release that requires a completion is a pull system.
- **A link into a FIFO station** → drawn as a FIFO lane.

Needs `VsmSymbols.drawPullArrow` and a lane rendering, and `flow_pdf.dart` draws the same shapes
from the same descriptions so the PDF follows for free. Left open: whether a FIFO lane should carry
the max-quantity label the notation usually gives it — we have no concept for the quantity.

### 1.7 The canvas, three smaller things

- **The `+` insert button is off-centre beside a buffer.** Vertically it is exact —
  `InsertionPoint.center.y` and `FlowLayout.spineY` are the same expression. Horizontally it sits at
  the gap's midpoint, but an arrow touching an inventory node is inset by `bufferInset` =
  `(168 − 56) / 2` = 56 px on the buffer's side, so that segment's visible midpoint is 28 px away
  from the button. Compute each insertion point from the segment it belongs to rather than from the
  gap. Pure geometry in `flow_layout.dart`, so `flow_view_test.dart` asserts it without a frame.
- **The pool badge is a Material chip** — `'#$poolMemberCount'` on a rounded `secondaryContainer` —
  sitting inside a hand-drawn map next to a factory and a triangle that are stroked paths. Replace it
  with `VsmSymbols.poolBadge`: a square outline carrying `#N` at the same 1.2 px stroke and theme
  colour, so it becomes part of the drawing and the PDF renders the identical shape.
- **Node notes.** `FlowNodes.notes` is stored, carried through the repository and editable from
  nothing — the same shape the supplier and customer names were in before M3 (§17.5). One free-text
  field per node, edited in both editors beside Changeover, a marker on the box when there is one,
  the text in the tooltip, and carried into the PDF so a printed current state has the findings on
  it. This is where a walk records problems and opportunities.

### 1.8 The shell

- **Simulate moves to the project app bar**, on the right, reachable from every tab. §7.7 makes a
  run project-level, so its trigger belongs on the project chrome rather than inside one tab. The
  Simulation tab keeps the dispatch dropdown, the readiness panel and the results.
- **Pressing it never moves you.** The spinner stays on the button; on completion a snackbar reports
  the headline with an action that jumps to the Simulation tab. Being yanked out of a half-typed
  sequence cell is not worth saving one click.
- **The disabled tooltip names the first blocking problem and its study.** Otherwise a user on the
  Flow tab sees a grey button whose explanation lives on a tab they are not looking at.
- **The sidebar toggle moves to the right of the project name.** Still near-left, so the argument at
  `project_workspace_screen.dart:81` — that a control across the window from what it moves reads as
  belonging to whatever is under it — survives, but rewrite the comment to match.

### 1.9 Utilisation → Utilization

One spelling everywhere: `app_en.arb`'s string, the l10n key, the Dart identifiers in `RunMetrics`,
`sim_result.dart` and `engine.dart`, and the prose in DESIGN.md §8.3 and in this file. All of it
compiler-checked or mechanical, so it cannot be half-done. `es` and `pt` keep Utilización and
Utilização, which are already right in their own languages. The rest of the app stays British
("Organisational only", "a centred moving average") — a known inconsistency, left deliberately.

### 1.10 DESIGN.md

None of the above is real until §5.2 (arrow semantics), §7.4 (per-station dispatch), §7.10 (what a
run stores), §8 (float's sign), §9.1 and §9.3 (the batch number and the synonym rule) say it, in the
same commits that change the behaviour.

---

## 2. Verify in the running app

The rest of this has not been driven by hand — it is covered by unit, repository and mounting tests
only.

- [x] ~~**Upgrade a real database.**~~ Done 2026-08-05. It was at v6 with v8-shaped tables from an
      upgrade that had died part-way, and the app could not open it at all; §16.11 has the fix and
      the fixture. It now migrates v6 → v11 with everything intact. A backup of the pre-migration
      file is beside it as `flowmap.sqlite.backup-20260805-054746` — delete it once you are happy.
- [x] ~~**A real run.**~~ Done 2026-08-05. `Célula 11B` flagged, readiness clean, Simulate ran 33
      orders through 231 steps in 1432 ms and stored it; reopening the tab after a restart shows the
      same run without recomputing it. The result says the sequence is badly over-committed — 3 %
      on time, average float +230.7 d, lead-time efficiency 2.39×, 63 empty release slots, CEU27 at
      86 % utilisation holding 4487 d of queue and 58 % of the flow's total time. Worth reading as
      a finding rather than a smoke test. (Both figures are restated under §1.2's new sign once it
      lands: −230.7 d.)
- [x] ~~**MM3's two columns.**~~ Confirmed: `Equivalent` is per part (PN3 is 0.70 at every batch
      size) and `Slot load` is equivalent × batch, which is what MM3 averages.
- [x] ~~The canvas.~~ Confirmed: push arrows meeting the triangle, the triangle centred on the
      spine, the `#3` chip on the CLAD Pool box, the `Takt C/T` row, the sidebar toggle on the
      left. Two defects found and fixed while looking — §16.12. A second pass on 2026-08-05 found
      the three in §1.7.
- [ ] **The pool fix, against célula 11B.** The CLAD Pool of three reads 63 % occupation and a flow
      equivalent of 0.99, which is the right shape; comparing against what it read *before* the fix
      still needs the old build.
- [ ] **The readiness panel against a real gap.** It has only been seen clean. Unbind a step or
      clear a takt period and check it names the study and disables Simulate.
- [ ] **Rebuild Release when §1 lands**, with a `BUILD_LABEL`, and drive the v11 → v12 migration
      against the real database before trusting it.

---

## 3. Known gaps, deliberately left

- [ ] **§14's performance target is not met.** A 2000-order, 10-step run takes ~2.8 s against "well
      under a second". §16.9 has the measurements: the cost is local `DateTime` arithmetic on
      Windows (~13 µs per construction, versus 0.03 µs for the UTC equivalent). Closing it means
      working in epoch integers inside `WorkingCalendar` and converting only at its edges — a real
      refactor of the most heavily tested code in the app. Worth doing deliberately.
- [ ] **§18.3 is still open**: takt changes mid-flight. A run keeps one release cadence throughout,
      resolved at its start by the second assembly pass (§16.10).
- [ ] **§18.5 is still open**: empty slots as a reported metric. They are counted, dated, stored and
      shown on the Simulation tab; what is missing is a decision about whether anything more should
      happen — a list of *which* slots, and whether an empty slot should ever be a warning.
- [ ] **§11.1's tail warning is not shown.** A run that completes past the last defined schedule
      period carries the last one forward, and the user is not told. The engine does the right
      thing; nothing reports it.
- [ ] **The decorative layer (§5.2)** and **`DiagnosticsLog.compose`** are still built-but-unreachable,
      both wanted by M5. Listed in §17.5. §1.7's node notes deliberately do **not** use the
      decorative layer: a free-placed sticker near a box is not a note belonging to it.

---

## 4. M5

Reports (§13), run comparison, templates and binding (§10.2), the About screen, and the drop.

Run comparison has what it needs: two `StoredRun`s report through the same `summariseRun`, so the
figures on either side of a comparison cannot have been computed two different ways. §1.3's stored
dispatch overrides are what lets a comparison say the dispatch is what differed.

Export of the Production Plan (§1.5) belongs here, with the other reports.
