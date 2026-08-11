# FlowMap — what is next

Working state as of 2026-08-11. `docs/DESIGN.md` remains the source of truth for *why*; this file
is only a plan, and each item should be deleted from it as it lands.

Branch `m1-m2-foundation`, clean, `flutter analyze` clean, **628 tests passing** (one of them
`live`-tagged and skipped without a database). Schema is at **v15**. M4 is code-complete.

**§3's round one is done, in five commits, and about half of it has now been driven by hand.** The
lanes govern the flow, a station may hold more than one order, the pacemaker gates the release, a
study may add a start buffer, and every one of those is reachable from the UI. **All five of §4's
round-one checks have now met the real database**, in Release `0.1.0-2026-08-11` — evidence under
§4. The round did what it was for: with the gate on the capped lane, the average order lost 16 days
and `laneFull` was observed for the first time. What is owed is one run to settle the takt
confounder, and es and pt.

**What is next needs a human at the GUI, not more code.** §4's Gantt item is only partly closed:
§2.11 came out of a Debug session that changed three things, and the rest of that list — the axis at
the fit, ten zoom presses, the changeover stroke, both themes, es and pt — has still not been
looked at, nor has §2.8's file been opened in Excel.

**Célula 11B was re-run on 2026-08-09** — nine runs that evening, the last `01e61863` at 18:59.
§2.12's prediction held: the 14 days of buffer delay are gone and the wait reappeared at the plant,
almost all of it at CEU27. The demand has also grown from 33 orders to **60**, so every figure
recorded in §1 and §2 describes a smaller problem than the one on the screen now. §3.0 has the
measurements. (The header said 2026-08-10 until 2026-08-11; the runs are dated 08-09 in the file.)

**§3 is the plan that came out of that session**, settled by interview. Round one has landed and
moved the dispatch rule off the station onto the inventory node, which invalidated those nine runs
— and they have since been superseded by four v15 runs. **Read figures against `2f4c8db4`**
(2026-08-11, capacity 2 on `FIFO CEU27`, pacemaker CEU27, 30-day buffer — the configuration the
round was arguing for), with `676fb0e3` as the capped-but-ungated comparison and `5bf76ac1` as the
v15 baseline with nothing set. Rounds two to four are untouched.

**The v14 → v15 migration has run against the real database** — in the Debug build on 2026-08-10,
between the `flowmap.sqlite.backup-v14-20260810-222300` beside it and the first v15 run at 22:25:49.
Verified on a copy on 2026-08-11 by `test/data/live_v15_check_test.dart`, which is run by hand with
`--tags live` and `FLOWMAP_LIVE_DB` pointing at a **copy**: `user_version` 15, `integrity_check` ok,
both superseded tables gone, 60 orders and 32 runs intact.

**The carry-over landed on two lanes, not the three §3.1 predicted**, and the difference is
instructive rather than a defect. §3.1 said CEU26, CLAD04 and CLAD Pool would migrate onto the lane
in front of each target. In the file, `FIFO CLAD09` (which feeds the CLAD Pool step) and
`FIFO CEU26` carry `fifo`; **CLAD04's rule went nowhere, because CLAD04 is a pool member and never a
step target of its own**, so it has no lane in front of it — the same reason CLAD09's was dropped.
All four stored rules were `fifo`, so no behaviour changed either way.

**The Release bundle was rebuilt 2026-08-11 under label `0.1.0-2026-08-11`**, after round one, and
*launched* rather than merely inspected: the session header at 20:17:56 reads that label rather than
`dev`, and `db.open schema 15 from 15` — a no-op open, and so the proof that Release found the
database already migrated and did not touch it. Round one's five field checks were then driven in
that build. A v15 backup was taken first, as `flowmap.sqlite.backup-v15-20260811-201650`.

This paragraph exists because the 2026-08-05 rebuild went unrecorded and was nearly done a third
time; keep it truthful after every drop. **`flowmap.exe`'s own Aug 3 timestamp still means
nothing** — it is the C++ host shell from `windows/runner/`, which has not changed, so CMake rightly
declines to relink it and only `Release/data/app.so` moves. That held again on 2026-08-11: `app.so`
is stamped 20:17 and the exe beside it still reads Aug 3.

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

### 1.4 Batch Number on the sequence grid — **done 2026-08-05**

One thing the plan missed: the size column's own label was `Batch` (`Lote` in es and pt), so the
grid would have carried `Batch` next to `Batch no.`. It is `Batch size` / `Tamaño de lote` /
`Tamanho do lote` now. That label is also the import's first matching key, so the rename is what
makes a file headed `Batch size` land cleanly while a bare `Batch` goes to the user.


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

### 1.5 The Production Plan — **done 2026-08-05**

Written up as **§8.5**, not §8.4 — that number was already "The Summary, as built", and several
comments had been pointing at it. All references corrected.

`saveRun` had to start populating the four v12 columns, which nothing did: they were added in §1.1
but written by nobody. `SimPart` gained `customerProject` and `SimOrder` a `batchNumber` — passengers
the engine never reads, exactly as `SimPart.partNumber` has always been, so the snapshot is what was
*assembled* rather than a second read of the demand at save time.


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

### 1.6 Arrows become derived — **done 2026-08-05**

The interview left "a link into a FIFO station" ambiguous, and it matters: under the default rule
*every* station is FIFO, so a lane would have been drawn on every link and said nothing. Only an
**explicitly stored** FIFO draws one — which is exactly the "a missing row is not the same as FIFO"
distinction §1.3 already built and tested.

Two other things found while doing it:

- `vsm_symbols.dart` claimed "the PDF renderer draws the same shapes from the same descriptions".
  It does not and never did — `flow_pdf.dart` builds from the `pdf` package's own widgets. The
  comment is corrected, and the printed map now labels (`PULL`, `FIFO`) where the canvas hatches.
- Arrow geometry moved out of `flow_tab` into `layoutFlow`, so what each link *is* can be asserted
  without pumping a frame. Six tests.


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

### 1.7 The canvas, three smaller things — **done 2026-08-05**

The `+` fix fell out of §1.6 almost for free: once the arrows were in the layout, each insertion
point could be derived from the connection it sits on rather than from the gap, so the two cannot
drift apart again.

Two things the plan did not mention:

- **`insertStep` and `insertInventory` did not accept notes**, so the new field would have silently
  discarded whatever was typed on a node being created. Both take it now.
- **The PDF prints a findings list under the map**, not text in the boxes — a process box there is
  140pt wide and a finding is a sentence. Absent entirely when nothing has been written.


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

### 1.8 The shell — **done 2026-08-05**

The tab controller had to move from `_StudyTabs` up to the workspace: the snackbar's "View results"
has to switch tabs, and a controller one level below the button that raises it cannot be reached
without threading a callback down and an index back up.

Three tab tests asserted the button's enabled state. They moved out rather than being rewritten —
what the button is gated on (`SimRunInput.canRun`) is a pure predicate already covered eight ways in
`simulation_repository_test.dart`, and what those tests were adding was only "the button reads it".


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

### 1.9 Utilisation → Utilization — **done 2026-08-05**

The only spelling left in the tree is this heading, which names the change.


One spelling everywhere: `app_en.arb`'s string, the l10n key, the Dart identifiers in `RunMetrics`,
`sim_result.dart` and `engine.dart`, and the prose in DESIGN.md §8.3 and in this file. All of it
compiler-checked or mechanical, so it cannot be half-done. `es` and `pt` keep Utilización and
Utilização, which are already right in their own languages. The rest of the app stays British
("Organisational only", "a centred moving average") — a known inconsistency, left deliberately.

### 1.10 DESIGN.md — **done 2026-08-05**

Written as each piece landed rather than swept up at the end, so this was a check. It found two
things: §7.10 still described only what M4 stored and said nothing about v12's copied-in columns or
the dispatch overrides, and one `§8.4` in `demand_paste.dart` still pointed at the Summary when it
meant the production plan. `engine.dart`'s `§8.4` is correct — it really is about the Summary's
occupation arithmetic.

Sections touched across §1: **§5.2** (arrow kinds), **§5.4** (node notes), **§7.4** (per-station
dispatch), **§7.10** (what a run stores), **§8** (float's sign), **§8.5** (the plan, new),
**§9.1** and **§9.2** (batch number, import synonyms), **§12.1** (Simulate on the app bar),
**§16.13** (schema v12, new), **§17.5** (`flow_nodes.notes` now reached).


None of the above is real until §5.2 (arrow semantics), §7.4 (per-station dispatch), §7.10 (what a
run stores), §8 (float's sign), §9.1 and §9.3 (the batch number and the synonym rule) say it, in the
same commits that change the behaviour.

---

## 2. Field feedback, 2026-08-06

Six items from driving the Debug build by hand, each settled by interview before any of it was
written. Ordered the way §1 was — the schema lands once and the UI sits on top of it — and behind
the verification §2.0 asks for, because this round stacks v13 on v12.

### 2.0 Clear the debt first — **mostly done 2026-08-06**

The two big ones turned out to have been done on the night of 2026-08-05 and never written down;
the header now records the evidence so this is not re-done a third time. What was checked on
2026-08-06, beyond re-reading the log:

- **v12 is fully applied, not merely stamped.** `user_version` alone cannot show this — §16.11's
  database reported a version it did not have the tables for — so the live file was copied out and
  inspected. All 29 tables the schema declares are present, `integrity_check` is `ok`, all five v12
  columns exist (`demand_orders.batch_number`, and `customer_project` / `batch_number` /
  `batch_size` / `material_date` on `simulation_run_orders`), and `demand_orders.order_number`
  is still absent, which is what says the v9 rebuild did not silently come back.
- **Two things that looked wrong and are not**, both worth recording so they are not chased again:
  `simulation_run_dispatch` is empty while `workcenter_dispatch` has a row, because the override was
  saved 174 seconds *after* the last run and no run has happened since; and `batch_number` is null
  on all 33 orders because nobody has typed one, which is exactly what a blank-allowed free-text
  field looks like on the day it ships (§1.1).
- **The four pre-v12 runs show blanks and the fifth does not**, which is §8.5's predicted behaviour
  observed on real data rather than on a fixture.
- **`parts.description` is populated on all five parts** — `PWB 10K`, `AWB 10K 1.0`, `AWB 10K 2.0`,
  `AWB 10K 1.0`, `PXVB 20K`. So §2.3's new column has real content on day one, and PN2 and PN4
  sharing a description is a free reminder that it identifies nothing.
- `flutter analyze` clean, 501 tests passing, and the `v11 → v12` fixture §1.1 asked for is in
  `migration_test.dart:595`.

**Still owed, and it needs a human at the GUI:** the readiness panel against a real gap. Unbind a
step or clear a takt period on `Célula 11B` and check the panel names the study and greys Simulate.
Narrower than it looks — `SimRunInput.canRun` is covered eight ways in
`simulation_repository_test.dart` and `simulation_tab_test.dart:150` already mounts an unready study
and asserts the panel names it and states the problem. What has never been seen is the wiring
between them: a real edit, through the providers, to a non-empty problem list on screen.

_Rejected: land all six and verify once at the end._ Fewer context switches, and it is what
happened last time. §16.11 is the record of what it cost.

### 2.1 Schema v13 — the part's description — **done 2026-08-06**

Landed as described, written up as **§16.14**. Two things worth keeping:

- **The migration fixture had to distinguish two blanks.** A v12 run whose four plan columns are
  *populated* is what makes `v12 → v13` prove anything: had the step rebuilt the table, those values
  would vanish and a fixture full of nulls would have passed anyway. The v11 → v12 fixture did not
  face this, because before v12 there was nothing in those columns to lose.
- **A column nothing writes is the failure mode this repo has already had** (§1.5). So the chain is
  tested at both links rather than end to end — `sim_assembly_test` for `DemandPart` → `SimPart`,
  `run_storage_test` for `saveRun` → `loadRun` → plan row. Deleting the assembly line fails exactly
  the first, which is the check that they are not one test written twice. The assembly side had no
  coverage at all before this, not even for `customer_project`.

503 tests, `flutter analyze` clean.



One nullable column, `simulation_run_orders.part_description`, for §2.3's new column.

`parts.description` has existed since M3 and the plan cannot reach it, because §7.10's rule is that
a run copies every value in and joins to nothing. So it is copied in, exactly as §16.13 copied
`customer_project` and `batch_number`: `SimPart` gains a `description` the engine never reads,
`saveRun` writes it, and a run made before v13 shows a dash — which is true, and is what a blank has
meant on this table since v12.

**Purely additive, and no `columnTransformer` trap.** §1.1's warning — every future column on
`demand_orders` needs a constant `NULL` in the v9 step — does not apply here: no `TableMigration`
ever rebuilds `simulation_run_orders`, so `addColumn` is the whole migration. Still needs a
v12 → v13 fixture in `test/data/migration_test.dart`, and the half-upgraded path from §16.11
re-checked.

_Rejected: joining `simulation_run_orders.part_id` to `parts` at read time._ No migration, and it
silently rewrites what a stored run says the moment someone re-describes a part. Rejected twice
already in §1.1 and §8.5; rejecting it a third time is the rule working.

### 2.2 Delivery becomes Order end — **done 2026-08-06**

Landed as described. One thing the plan did not mention:

- **`simAverageFloatHelp` defined float as "need date minus delivery"**, and that text is the
  explanation of the Float column sitting directly beside the renamed one. Left alone, the table
  would have had a column headed `Order end` and a help bubble two columns over calling the same
  instant delivery. Changed in all three languages, along with "an undelivered order has no float"
  → "an order that never ended", which is the same instant under the same new name. This is the
  §1.2 rule again: one definition, so the column and the figure cannot disagree.

**`ProductionPlanRow.delivery` keeps its name**, and is now a getter called `delivery` feeding a
column headed `Order end`. Deliberate — renaming Dart identifiers was ruled out for this item — but
it is the one place a reader can be surprised, so it is written down rather than left to be found.
If it grates later it is a pure rename with no migration behind it.



The plan's ninth column is labelled `Delivery`. It reads `delivered`, which §18.1 defines as the
order's **last semantic step** — the moment production finishes, not a shipment. `Order end` says
that, and pairs with the `Order start` already sitting beside it.

`simPlanDelivery` → `simPlanOrderEnd` in en/es/pt, and §8.5's column list. es and pt already
shorten `Order start` to `Inicio` / `Início`, so they take `Fin` / `Fim`.

**Nothing else moves.** `SimOrderOutcome.delivered`, the `delivered` column, the `Delivered 31 of
33` metric and `On-time delivery` all stay: those measure the promise to the customer, which is a
different question from when the order came off the last station, and OTD is the term the industry
uses. One label, three files, no migration.

### 2.3 The Production Plan's three new columns — **done 2026-08-06**

Landed as described; §8.5 rewritten. Two things worth keeping:

- **`theoretical_seconds` was stored but never read back onto a plan row.** It reached `summariseRun`
  as an aggregate map and stopped there, so the column needed a field on `ProductionPlanRow` — the
  same "stored by someone, read by nobody" shape §1.5 found in v12's four columns, one layer up.
  Actual lead time needed nothing: it is `outcome.leadTime`, defined once already.
- **Theoretical ≤ actual is a real invariant, now asserted.** Both are wall-clock from the same
  release instant, and theoretical excludes queueing and changeover, so it cannot exceed what
  happened. That single assertion in `run_storage_test` is worth more than checking the figures
  render, because it is the property that makes the two columns mean anything side by side.

The description cell's tooltip is unconditional, including on a description short enough to be
fully visible. Showing it only when truncated means measuring the text against the cap on every
build, to save the reader a tooltip that repeats what they can already read.



`Order | Part Number | Description | Project | Batch Number | Batch Size | Need Date | Material
Date | Order Start | Order End | Theoretical LT | Actual LT | Float`

- **Description** sits next to the Part Number it describes, and comes from §2.1's copied-in column.
  Free text with no length limit, so it is capped at ~200 px with `TextOverflow.ellipsis` and the
  whole string in a `Tooltip` — the decision §5.4 already made for node notes, so the app has one
  answer for long free text in a narrow place. Uncapped, one long description stretches the column
  and pushes Float off the right edge for every row.
- **Both lead times already exist per order** and need no new computation. Actual is
  `SimOrderOutcome.leadTime` (`order end − order start`); theoretical is `theoreticalSeconds`,
  walked from that same order start with no queueing (§7.9) and stored since v11. Same instant,
  both wall-clock, so they are directly comparable — and dividing them is the headline
  lead-time efficiency the metrics card already reports.
- **Theoretical first, then actual**, because the baseline is what the actual is read against. Both
  through the existing `_duration`, which is what the metrics card above uses for the same two
  figures — so §17.4's one-kind-of-day rule holds by construction rather than by care.
- **The gap between them is that order's queueing**, visible by subtraction.

_Rejected: a third column for the ratio, or for `actual − theoretical`._ Both only restate the two,
on a table already scrolling horizontally at thirteen columns.

### 2.4 The read-only tables centre — **done 2026-08-06**

Landed as **§12.5**. Two things the plan did not anticipate, both found by writing the test first:

- **A one-column fixture lies about centring.** The first version of the test used a single column
  and failed: the cell centred at the middle of the *table* (400 px) while the heading sat at 165.
  A lone column is stretched to the full width and the heading does not participate in that stretch
  the way a cell does. With two columns — which every real table has — header and cell agree
  exactly. The test now uses two, and covers the stretched-to-fill case as well, because the takt
  table is the one table with no horizontal scroll view around it.
- **A `Row` inside a centred cell has to be told to shrink.** The Summary's first column is a
  workcenter name plus an optional `×3` badge and an error icon. `Row` defaults to filling its
  parent, so the centring around it did nothing until it got `mainAxisSize: MainAxisSize.min`.

Action columns are left start-aligned, which was a judgement call rather than an oversight: edit and
delete are not data read down a column, and the takt table stretches, so centring would put its
buttons mid-cell away from the row they act on.

506 tests.



Header and cells centred in all seven Material `DataTable`s — Production Plan, Queue, Share of flow,
Parts, Summary, Takt, Workcenter schedules — dropping `numeric`'s right-align there. Material has no
centre alignment for a `DataColumn`, so it is a small shared pair of helpers in `common/` rather
than forty hand-wrapped call sites; one place to change when the eighth table arrives.

**The editable `DataGrid` is untouched.** `DataGridColumn.numeric` is documented as right-aligning
because "times, quantities, dates read better that way", and that is truer where you type: scanning
a column of process times for the one that is wrong is what a ragged left edge is *for*. Centring
those would make `numeric` dead code and take the outlier with it.

### 2.5 The FIFO lane becomes its own figure — **done 2026-08-06**

Landed as described; §5.2 amended, including its table row. The condition is untouched — only an
explicitly stored FIFO draws a lane — so `flow_view.dart` and its six tests were not opened.

- **The drawing was checked by rendering it**, not by reading the arithmetic. A throwaway test drew
  all three kinds at both the narrowest gap the layout produces (64 px) and a wide one, wrote a PNG,
  and it was looked at. Worth doing again for any symbol change: the geometry compiled and analysed
  cleanly in a first version whose label sat outside its own rails. `VsmSymbols` has no tests and
  neither do `factory` or `inventoryTriangle`, which is the file's standing convention — kind
  *selection* is tested, shape is looked at.
- **1.2 px rails, not the heavier stroke of the reference clip-art.** §1.7 made the pool badge 1.2
  precisely so a symbol reads as part of one drawing rather than pasted onto it, and a bolder lane
  would undo that for the sake of matching a picture that was never drawn to this map's weights.



The lane drawn by §1.6 is the shared broad arrow plus a divider line and `FIFO` written above it.
The notation's actual symbol is a channel: two long rails, `FIFO` centred **between** them, a short
tick inside the left end and a small solid triangle inside the right. That is not a decorated
shaft, and drawing it as one is why it reads wrong on screen.

- **`VsmSymbols.drawConnection` gains a third geometry**, ~18 px tall. There is room: the gap is
  64 px and the ladder sits 220 px below the spine.
- **§5.2 is amended**, from "all three share one shaft" to *push and pull share one shaft; a FIFO
  lane is its own figure, because the notation makes it one.* The old sentence was a principle
  invented to describe an implementation, and the drawing is the thing being corrected.
- **The condition is unchanged.** Only an **explicitly** stored FIFO draws a lane (§5.2, §7.4).
  Under the default rule every station dispatches FIFO, so "any FIFO station" would put a lane on
  every link of every default map and say nothing — the outcome §1.6 recorded and rejected.
- **The PDF still labels rather than redraws.** §5.2 chose that deliberately and `flow_pdf.dart`
  builds from the `pdf` package's own widgets; it keeps printing `FIFO` under the arrow.

### 2.6 The map refits itself — **done 2026-08-06**

Landed as described, in §12.2. Three things worth keeping:

- **The "has the user touched it" signal is a matrix comparison, not a gesture callback.** The plan
  said to hook `onInteractionEnd`; that fires for a bare tap that moved nothing, so one tap on the
  canvas would have stopped the map ever fitting again. Keeping the transform the last fit installed
  and comparing it against the controller's is exact, and costs one field.
- **The decision moved into `flow_layout.dart` as `shouldRefitCanvas`** — §1.6's precedent, and here
  it earns more than tidiness: one of its clauses is a loop guard. Fitting calls `setState`, which
  rebuilds, which asks again, so an unchanged size *must* answer no or the app hangs. **Nothing in
  the suite mounts the canvas**, so no existing test would have caught that; seven unit tests now do.
- **`vector_math` is now a direct dependency.** `flow_layout.dart` is deliberately widget-free so its
  geometry can be asserted without a frame, and reaching `Matrix4` through `package:flutter` would
  have undone exactly that. It was already there transitively; it is declared now because it is
  genuinely used.

513 tests.



`_fit()` already exists and already runs once per map, gated by `_fittedOnce`. It should also run
when the viewport changes — which is what collapsing the 280 px sidebar does, and what resizing or
maximising the window does.

**But only while the transform is still the one `_fit` set.** A bool, cleared by `_fit`, set by
`_zoomBy` and by `InteractiveViewer.onInteractionEnd`. The first manual zoom or pan takes ownership
and later resizes leave it alone; pressing Fit hands ownership back. Without that, resizing the
window throws away a deliberate zoom-in on step 6 — the same complaint `_zoomBy`'s own comment
records, arriving from the other direction.

The sidebar is an `AnimatedSize` over 160 ms, so this refits about ten times across the animation
and the map follows the pane rather than snapping after it. Nothing needs plumbing down from the
workspace: `LayoutBuilder` already sees the width change.

### 2.6b The project moves to the order — schema v14 — **done 2026-08-06**

Not in the original six. Field feedback while driving the build: the Parts grid carried a Project
column that was empty in every real row, because a project is what a *batch* is for, not what a part
is. §9.3 rewritten, §16.15 new.

Settled by interview before any of it was written, and the answer was the larger of the two on
offer: the column does not merely move off the grid, the project stops identifying a part.
`demand_parts` keys on `(study, part_number)`; `demand_orders` carries the project as a label beside
the batch number. That reversed v10, which had put the project *into* the key eleven versions
earlier.

Three things worth keeping:

- **A `TableMigration` in an old step is a hostage to every column ever *removed*, not only to every
  column added.** §16.13 warned about the second; this found the first. The v10 step rebuilt
  `demand_parts` from the **current** Dart definition to put the project in the key — and with the
  column gone from that definition, replaying it would have destroyed the very values v14 exists to
  move onto the orders. It had to be deleted outright rather than amended. The v9 step's
  `_ensureColumn` had to become raw SQL for the same reason: Drift cannot name a column the current
  definition does not have, and the step still has to run so v14 has something to read.
- **`duplicateStudy` was silently dropping `batch_number`, and had been since §1.4 added it.** It
  copied the figures the engine reads and none of the labels a planner matches against their own
  paperwork. Found only because the new test asked whether the *project* survived a study copy — the
  batch number was sitting beside it, lost the whole time. Both are copied now, and both asserted.
- **The twin case is the whole risk of the migration**, so it is fixtured: two parts differing only
  by project, each with its own process times, one order for each. Both survive, the later renamed
  `PN2 (Wing 9)`, and every order still points where it pointed. Merging them would have handed
  every order of one the other's process times without saying so.

Left standing: a rename that collides with a part number already in the study would fail the new
unique key. It needs a part literally named `PN2 (Wing 9)` alongside the twins, and is not worth the
SQL to prevent.

515 tests.

### 2.7 The Gantt

Y is the work centre, X is time, the bars are orders. **It needs no new data**: `SimRunResult.steps`
is already read back from `simulation_run_steps` with `workcenterId`, `queueStart`, `processStart`,
`processEnd` and `changeoverIncurred` per order-step. §7.10 says in as many words that this storage
exists to make order Gantts a query rather than a re-run; this is the first thing to collect.

Settled by interview before any of it was written, and the interview moved five things the first
draft had wrong. Each is marked below, because the reason it moved is the part worth keeping.

**Its own view, not another block in `_Results`** — the first draft said "a section below the
Production Plan, ~360 px tall with its own scroll", and that was one section too many on a page
already carrying a header, a headline, a metrics card, three tables and a thirteen-column plan. The
run header, abort banner and headline stay put, because they describe *the run* rather than a view
of it; a **Results | Gantt** segmented control switches the body beneath them. The chart then takes
the full body height, which removes the 360 px cap, the second vertical scrollbar and the nested
scroll in one move. Held in an `IndexedStack`, so switching to Results and back returns the zoom the
reader left. It reads the same `StoredRun` as everything else on the tab, so opening an earlier run
from the history menu opens its Gantt with it — §8.5's rule for the plan, applied again.

- **One chart for the whole run, all studies together** — deliberately the opposite of §8.5's
  per-study sectioning, and for a stated reason: the plan's rows are orders and an order belongs to
  one line, but a **station is shared**. Splitting per study would draw a station idle during hours
  it was in fact running another study's order, which is the one thing §7.7 exists to model.
- **A bar is the station committed to an order**, `processStart → processEnd`, **closed hours
  included** — the second thing the interview moved. The first draft said "bars are process only"
  and left the inverse of the gap rule unstated, which is the half a reader gets wrong:
  `engine.dart:642` ends a step at `calendar.advance(now, occupancy)`, so a two-open-hour job started
  Friday afternoon draws a bar reaching Monday morning. It is the same wall-clock span the plan's
  Order Start / Order End use and the same one §8.3 calls occupation, so the tab has one meaning of a
  duration rather than two. Bars tile without overlapping: `engine.dart:521` gives every workcenter
  its own server, and a pool reaches the run as several `candidates`, so three cladding machines are
  three rows each running one order at a time.
- **A gap means "not running" — closed and starved alike**, and both halves are said on screen.
  Splitting a bar at closed time would need calendars a stored run does not have —
  `run_metrics.dart:196` records exactly that, and `simulation_run_workcenters` keeps only a total
  `openSeconds`. The station's utilization and open time sit in the Queue table, which is where "how
  much of that gap was even available" is answered.
- **Queue spans are not drawn.** CEU27 holds 4487 days of queue, which is dozens of orders waiting at
  once, and drawing those would smear the row solid over the bars underneath. Queue is reported per
  station in the Queue table, per order by §2.3's two columns, and per step in the hover card.
- **Rows follow `metrics.workcenters`**, in the Queue table's own order, so the bottleneck is the
  first row read and the two cannot disagree about which station is which. Built from steps, so a
  station that never ran has no row.
- **X-only zoom, fitted once per run.** Rows keep a fixed height and their labels stay pinned in a
  frozen left column. The third thing the interview moved: the canvas refits itself on every viewport
  change (§12.2) because a map has no intrinsic scale, but a time axis does — so a wider pane keeps
  its pixels-per-second and simply shows more days. No refit rule, no `Matrix4`, no tracking of
  whether the reader has zoomed.
- **A real scroll view, not drag to pan** — the fourth. The first draft said "horizontal drag to
  pan", written before §12.6 decided that a wide thing must scroll *and say so*, and a bare drag
  re-creates the complaint §12.6 exists to answer: nothing on screen says how much run is off either
  edge. The chart is a full-width `CustomPaint` inside `HorizontalScroll`, labels frozen outside it
  and the axis inside so it pans with the bars. `HorizontalScroll` gains an optional controller,
  because zooming about the pane's centre has to move the offset. The window start stops being state
  and becomes the scroll offset, so there is one answer to where you are.
- **Zoom bounds are absolute, ×2 a press.** Floor is the whole run — there is nothing past it, so
  zoom-out disables there — and the ceiling is *one hour across the pane*, stated in time so it means
  the same on a two-week run and a two-year one. The canvas's `clamp(0.2, 3.0)` was tried against the
  real run and rejected on the arithmetic: 6.3e7 seconds in a 900 px pane is 1.4e-5 px/s, so even at
  3× a one-hour step is 0.15 px and the chart can never be zoomed into a state where a bar is real.
  ×1.25 a press would take thirty presses to cross that range; ×2 takes ten.
- **One axis row, with labels that stand alone.** The first draft named no axis at all. The coarsest
  unit whose ticks land ≥ 90 px apart, from hour / day / week / month / quarter / year, aligned to
  the calendar — month starts, Mondays — never "every 30 days from the run start", so a date sits
  under the same label at every zoom. `Jan 14`, not `14`. Dates follow the locale and clock readings
  are 24-hour, which is §12.4's split.
- **Bars get a ~2 px floor** so a step of a few hours is never invisible at whole-run scale —
  indicative there, and said so *conditionally*: a permanent warning would be a lie at the ceiling,
  where every bar is drawn true. `layoutGantt` counts the floored bars, so the note appears and goes
  away on a number out of the pure function.
- **Hover is a `MouseRegion` and a painted card.** A Material `Tooltip` carries a fixed message per
  widget, so naming the bar under the cursor would mean one widget per bar — 231 now, 20 000 at §14
  scale. The card names the order, the part, the station, the span, the committed duration, the wait
  before starting and whether a changeover was paid.
- **Geometry lives in a pure `gantt_layout.dart` under `application/`**, in two functions rather than
  one: `buildGanttChart(StoredRun)` resolves rows and bars in `DateTime` terms — the join, once per
  run — and `layoutGantt` turns that into rects, tick instants and a content size, per zoom. Geometry
  is then testable without constructing a whole run, and the join without a pixel. The 2 px floor
  lives in `layoutGantt`, so the rects hover picks against are the rects that were drawn, which is
  the whole argument for the file. Tick *labels* are formatted by the widget: the function returns
  instants and a granularity and never sees a `BuildContext`. This is §1.6's precedent, which moved
  arrow geometry into `layoutFlow` so that what a link *is* could be asserted without pumping a
  frame — and the Gantt has strictly more geometry than the arrows did.

**Colour by part**, which gives the app its first categorical palette:

- **A fixed eight-colour `partPalette` in `common/`**, one set for both themes, assigned by the
  part's position in the run's sorted part list so the same run always colours the same way. Past
  eight it wraps. `app.dart` sets no `themeMode`, so dark is genuinely reachable and "legible against
  both themes" is a constraint rather than an intention — **a unit test asserts it**: every hue
  clears 3:1 against the light surface and against the dark one, and 4.5:1 against its own label
  colour. Mid-luminance hues clear both. One place to change when the next part-coloured view
  arrives.
- **Keyed on `partId`, not on the part number** — the fifth thing the interview moved.
  `project_tables.dart:334` makes the unique key `{studyId, partNumber}`, so a two-study run
  legitimately carries two distinct parts both called `PN2`, and the first draft's fallback for a
  shared hue — "the bar label and hover still say which is which" — would have had both of them
  saying `PN2`. So **the Parts table gains a Study column, shown only when the run carries more than
  one study**, which is §8.5's existing rule for the plan's headings. `PartMetrics` gains `studyId`;
  `summariseRun` already has it in hand from `result.orders`.
- **The Parts table keeps a swatch, and the chart carries a strip.** The first draft rejected a strip
  because the table would sit directly above the chart — with the Gantt on its own view that premise
  is gone, and the rejection with it. The swatch stays where it is, because defining a colour beside
  that part's orders, on-time and lead-time figures still teaches the mapping while the numbers are
  being read; the strip is the legend for a view that has no table.
- **Changeover is a leading-edge stroke, above a ~6 px bar width**, not a hatched prefix. A prefix
  has a width, and `simulation_run_steps` stores only the bool — `engine.dart:638` folds the setup
  into `occupancy` and never records it — so a reader measuring that prefix against the axis would be
  measuring an invention, and on a 2 px bar it becomes the whole bar. A line cannot imply a duration.
  Below the floor the mark is omitted rather than faked; the hover card says it at every scale. A
  colour change between adjacent bars is not the same fact: §7.6 decides changeover by the batching
  rule, so the two can disagree in both directions.

_Rejected: hue rotation off the seed colour._ Never runs out, always in the app's family — but
adjacent hues stop being distinguishable past six or seven parts, and adding a part recolours a run
that has not changed.

_Rejected: colour by study._ Fewer colours to pick, and it shows contention at a shared station.
Within one study — the common case — every bar is the same colour.

_Rejected: golden-image tests for the painter._ They would catch the class of defect §2.5 and §2.10
say only rendering finds — at the cost of the first golden infrastructure in the repo and goldens
that churn on any font, theme or locale change, across three languages and two brightnesses. §15's
golden scenarios are committed *numbers*. So: exhaustive pure tests on `buildGanttChart`,
`layoutGantt`, tick selection, the floored count and `barAt`; widget tests for the view switching,
hover, zoom changing granularity, the floor note appearing and going, the swatch and the conditional
Study column; then §4 drives it by hand. §2.10 is the evidence that last step earns its place.

**Four commits, logic before pixels**, kept separate the way §2.10's were:

1. ~~`studyId` on `PartMetrics`, and the Parts table's conditional Study column~~ — **done
   2026-08-08.** Independently useful, since it closes an ambiguity that predates the Gantt. §8.4.
2. ~~`common/part_palette.dart` with its contrast test, and the swatch in the Parts table~~ — **done
   2026-08-08.** §8.6's colour paragraph.
3. ~~`gantt_layout.dart` and its pure tests. No UI at all.~~ — **done 2026-08-08.** §8.6 gained the
   geometry, and the section is now *The Gantt* with colour under it. 41 tests, 582 in all. Three
   things the plan had wrong, each found by writing it:
   - **Ticks had to come out of `layoutGantt`.** The plan said it returns "rects, tick instants and
     a content size", and that is unaffordable at the ceiling: a two-year run is 16 million pixels
     wide there and carries **17 500 hourly ticks**, which at §16.9's ~13 µs per local `DateTime`
     is a fifth of a second on a zoom press — to throw away all but the ten on screen. `ganttTicks`
     takes the visible content range and the scroll listener asks for what it can see. Tick
     *selection* stayed on the layout, because the unit is a function of zoom alone and the ticks
     and the content under them must have been decided at one zoom.
   - **The join takes a result and its metrics, not the `StoredRun` the plan named.** Everything it
     needs is on those two — the row order and the colour assignment from the metrics, the steps
     from the result — and taking them keeps the file out of the data layer and its tests out of a
     database. Asserting geometry would otherwise mean constructing drift rows for studies that
     nothing reads. One line at the call site: `buildGanttChart(result: run.result, metrics:
     run.metrics)`.
   - **The axis covers the run, not the work.** Left unstated by the interview, and the two differ:
     taking the span from the bars would make a station idle for the last three months read as the
     run having ended when the last bar did. It is `result.start`/`result.end`, widened only if a
     bar somehow falls outside them.
4. ~~The view — segmented control, painter, hover, zoom cluster, legend strip, `HorizontalScroll`'s
   optional controller, l10n in three languages, widget tests.~~ — **done 2026-08-08.** §8.6 is
   complete and §12.1 carries the view switch. 11 tests, 593 in all. `gantt_layout.dart` turned out
   to be the whole contract, exactly as commit 3 left it: nothing in the view decides a position.
   Four things worth keeping:
   - **The tab's body stopped being one `ListView`.** A child of a list cannot take the viewport's
     height, and the Gantt has to. So `_Body` is a `Column` with an `Expanded` body, `_Results`
     splits into the part that describes *the run* — header, abort banner, headline — and the
     `IndexedStack` beneath it, and the results half moved into `_ResultTables` behind its own
     scroll view. The readiness panel stays above the switch, because it is about the *next* run.
   - **The hover card is a widget, not the painted box the interview specified.** The objection to a
     `Tooltip` was one widget *per bar*; a single card positioned at whichever bar is under the
     pointer answers that in full, and being a widget keeps its text localized, themed and findable
     by a test. `IgnorePointer` is what stops it taking the hover away from what it describes.
   - **`intl` exports a `TextDirection`** that shadows the one a `TextPainter` needs, so the import
     is `show DateFormat`. A one-line fix, but the error names the getter rather than the clash.
   - **The row order is the Queue table's, ties broken by name** — and the first draft of the widget
     tests assumed alphabetical station order was the *chart's* rule rather than the ranking's. They
     reach for a row by name now: asserting the order there would have been a second, weaker copy of
     what `run_metrics_test` already owns.

### 2.8 The plan, in Excel — **done 2026-08-08**

Landed as described, written up as **§13.1**. 15 tests, 608 in all. Four things worth keeping:

- **A duration cannot be an Excel duration, and finding out why is the point of the column.**
  `TimeCellValue.fromDuration` takes the hour, minute and second of `DateTime.utc(0) + duration`, so
  a thirty-hour lead time reaches the file as `06:00:00` — silently a day short, in the one column
  a planner is most likely to average. They are `DoubleCellValue` in 24-hour days with the unit in
  the heading, and the fixture's lead time is thirty hours precisely so the test fails if anyone
  ever "improves" it back to a clock reading.
- **The export is decoded again in its own tests.** A PDF's numbers live inside a compressed content
  stream and `flow_pdf_test` can only check that the renderer was *asked* the right things; an
  `.xlsx` reads straight back, so these assert the actual cell types. That is worth more here than
  anywhere else in the app, because "it is a date, not a string that looks like one" is the entire
  claim the format is making.
- **The stamp had to be its own sheet.** §13's last line asks every export to carry the build,
  the project and the timestamp, and a stamp row above the header would put the header in row 2 and
  break the pivot the file exists for. It earns its place twice over by mapping each study to its
  sheet: Excel caps a sheet name at 31 characters and forbids `: \ / ? * [ ]`, so two long study
  names can arrive shortened and near-identical, and the stamp is the only place the full name is.
- **`pdfGenerated` and `pdfSaved` are now `exportGenerated` and `exportSaved`.** Both strings were
  already generic and both exports need them; leaving them keyed to one format would have meant a
  second copy of the same sentence. Mechanical and compiler-checked, so it cannot be half-done —
  §1.9's rule.

_Rejected: a PDF of the plan._ §13 reserves PDF for the full simulation *report* — input snapshot,
metrics, bottleneck ranking, late-order list — and a standalone plan PDF pre-empts a document that
does not exist yet. Thirteen columns landscape is tight in any case.

**The Gantt does not export.** §5's parking of exports covers it: a chart spanning months has to be
paged across sheets or scaled to illegibility, and it is the hardest of the three to print well.

### 2.9 DESIGN.md — **done 2026-08-08**

Written as each piece landed, not swept up at the end — §1.10 is the evidence that doing it that way
finds things. Sections this round touched: **§5.2** (the FIFO lane is its own figure), **§7.10** and
**§16.14** (schema v13, new), **§8.5** (three new columns, and Delivery → Order end), **§8.6** (the
Gantt, new — geometry, view and colour), **§12.1** (the run's two views), **§12.2** (refit on
viewport change), **§12.5** and **§12.6** (the tables centre, and scroll), **§16.15** (schema v14,
new) and **§13.1** (the plan's Excel export, new).

One thing to be aware of when reading it back: **§8.6 grew from a heading about colour into the
Gantt's whole section**, so a comment pointing at §8.6 for the palette is still right, just no
longer pointing at the top of it.

### 2.10 A wide table scrolls, and says so — **done 2026-08-08**

Not in the original six, and dated 2026-08-08 rather than 2026-08-06 — kept in §2 the way §2.6b was,
because it is the same "driving the build by hand" round. Field feedback: the Parts grid overflows
with the number of workcenters and cannot be scrolled sideways; the same on the Simulation tab's
production plan. Settled by interview before any of it was written, and written up as **§12.6**, with
§12.5 amended and §14 given the eager-rows note.

**The complaint was not a missing scroll view.** All seven tables already had one. What none of them
had was a way to drive it — the whole diagnosis is in §12.6. Six of the seven now use
`common/result_table.dart`; the takt table is deliberately left stretching to fill (§12.5).

Four things worth keeping, three of them only findable by rendering it:

- **"Draggable" is not a default.** Material makes a scrollbar a read-only indicator on Android and a
  control elsewhere, and `flutter_test` runs as Android — so the drag test failed against a bar that
  would have worked on Windows. `interactive: true` is stated on both bars. The same test then failed
  a second time for an honest reason: the bar *fades in*, and a thumb at zero opacity is not
  hit-testable, so a single pumped frame has nothing to grab.
- **The vertical bar's track spanned the heading.** It has to sit outside the horizontal scroll view
  or it pins to the table's right edge instead of the pane's — but then its thumb draws beside rows
  that do not scroll. Material's `Scrollbar` does not expose `RawScrollbar.padding`; it falls back to
  the ambient `MediaQuery`, which is how the inset is handed to it, with the real one restored
  underneath. Found by cropping a rendered PNG, not by reading the widget tree — §2.5's rule again.
- **`_Description`'s 200 px cap is gone.** It existed because a `DataTable` sized a column to its
  widest cell and one long description would push Float off the right edge; the column declares its
  width now, so the cell no longer has to defend itself. The `Tooltip` stays.
- **es and pt were checked against the declared widths**, not assumed. No column's longest word
  clips in any of the three languages — `Cambios de referencia` and `Operadores necessários` are the
  ones that decided the numbers.

All three commits landed the same day. 525 tests, `flutter analyze` clean.

**The second and third commits**, planned separately and kept that way:

- `DataGrid` gets `HorizontalScroll`, replacing the inert `Scrollbar` that had no controller and so
  held no position to drag.
- **`DataGrid` freezes its row header and part number** (`frozenColumns`, 1 on the parts grid and 0
  on the sequence grid). Two things the plan did not anticipate, both found by rendering it:
  - **The two panes drifted four pixels apart per row.** The frozen pane carries the row header and
    the scrolling one the row actions, and an `IconButton` is 48 px where a cell is 44. Invisible at
    the top of the grid and unusable by row ten. Row height and heading height are declared now, the
    same answer §12.6 gave column width — and `itemExtent` has the side benefit of making the two
    lists' scroll extents identical rather than merely similar, which is what the follow assumes.
  - **The first version of the sync test could not have caught it.** Its harness had no
    `rowActions`, so there was no `IconButton` to make the panes disagree. Deleting `itemExtent` now
    fails the alignment test, which is the check that the test is about the defect rather than about
    the code.

  Also worth keeping: a horizontal drag inside a cell belongs to the caret, because every cell is a
  `TextField`. There is no drag-the-content escape hatch on this grid and never was, which is another
  way of saying the bar was the whole fix.

**A fourth commit, from driving it.** Two things the running app said that the interview had not:

- **The Summary tab showed two vertical bars a few pixels apart** — the occupation table's 360 px
  pane inside the tab's own scroll. Applying one `maxHeight` to all six was the mistake; the
  occupation table is long enough to reach the cap and short enough that the page can carry it. It is
  `maxHeight: null` now and sits last on the tab, and §12.6 states the rule that fell out: bound a
  table whose length the data decides without limit, let the page carry one whose length the plant
  decides. **The production plan is the next candidate** and is deliberately left alone — it can run
  to hundreds of rows where the occupation table is bounded by the workcenter count, so unbounding it
  makes the Simulation tab very long. Worth a look on real data before deciding.
- **`fill: true`.** Declared widths were leaving the right-hand third of a wide window empty. Columns
  scale by one factor when there is room and stand as declared when there is not.

- **A mouse gets a smaller scrollbar than a finger.** `RawScrollbar.hitTestInteractive` pads the
  thumb to a 48 px minimum for touch and trackpad, and gives a mouse the bare track — 12 px on
  Windows. Every test here drags with touch, so none of them exercises what a user on this app
  actually does. Not changed, because it turned out the first report was a stale build; but if the
  bar ever feels fiddly rather than broken, that is the reason and `thickness:` is the lever.

### 2.11 The Gantt, driven — **done 2026-08-08**

The first three things looking at it said. Kept in §2 the way §2.6b and §2.10 were, because it is
the same "driving the build by hand" round — the Debug build, against the real célula 11B run, the
day §2.7 landed.

- **Rows go in flow order, not the Queue table's ranking.** This reverses what §2.7 settled by
  interview, and the interview's reason was sound on paper: rows follow `metrics.workcenters` so the
  bottleneck is the first row read. Against a real plant it is wrong — a Gantt is read as a flow,
  and a ranked chart makes an order's path zig-zag down the page instead of running diagonally
  across it. The bottleneck is still ranked, in the Queue table, which is where a ranking belongs.

  **The run stores no node positions**, so the order had to be derived: §7.10 joins to nothing, and
  the flow may have been edited since. §5.1's linear spine is what makes it exact — one order visits
  its stations in routing order, so the order it visited them in *is* the routing. Two details that
  only writing it settled: it is measured from `queueStart` rather than `processStart`, or a station
  that made everything wait floats up the list; and a station shared by two studies takes the
  earliest position it holds in either, because §7.7 gives it one row whichever line is read.
  `metrics.workcenters` breaks ties, which is what keeps a pool's three machines together and in a
  stable order.
- **Ctrl-scroll zooms**, anchored on the pointer rather than the pane's centre — a wheel notch says
  exactly where the reader is looking where a button press does not. A notch steps ×1.25 where a
  button steps ×2, because a notch is cheap and gets spun several at a time. A plain wheel is still
  untouched (§12.6). The listener has to sit **inside** both scroll views: `PointerSignalResolver`
  gives the event to whoever registers first and registration runs innermost-outwards, so an
  ancestor would lose to the `Scrollable` beneath it and the chart would pan while it zoomed.
- **The content gained a gutter under the last row.** The horizontal scrollbar pins to the bottom of
  a scroll view exactly as tall as its content, so it was lying across the last row's bars — reaching
  for the bar meant reaching through them, and hovering that row meant reaching through the bar.
  In `layoutGantt`, so `barAt` returns nothing in the gutter and the two can never both answer.

614 tests.

### 2.12 A buffer stops holding orders — **done 2026-08-08**

Field feedback, from the same session: *"the inventories hold the orders even if the next workcenter
is not processing any order."* Correct, and it was §5.5 working as specified — "in simulation an
order simply waits that long between steps." The spec was wrong for what the field models.

**What the model showed.** Célula 11B's six inventory nodes are named `FIFO CLAD09`, `FIFO TTAT`,
`FIFO CEU27`, `FIFO CEU26`, `FIFO BAN`, `FIFO END`, `FIFO COATING`, five of them DURATION at
3/3/3/2/2/1 days in calendar time. The names are the tell: what is being modelled is the **queue
between stations**, and a queue is an outcome. Measured on the stored run, per order: **14.0 d of
buffer delay**, 5.9 d of queueing at stations, 19.9 d of processing, 39.8 d of lead time. So 35 % of
every order's lead time was a fixed wait that ignored the plant — and it was charged twice, since
the order then queued at the station anyway.

**It had to come out of the theoretical walk as well**, which is the part the interview did not
anticipate. §7.9 counted `Σ inventory delays`, and that figure is only meaningful as a floor under
what a run observes. Removing the delay from the engine alone would have given 35.1 theoretical days
against 25.8 actual ones — an efficiency of 0.73× where §8 says 1.0 is the queue-free minimum, and a
straight violation of the invariant §2.3 asserts. `coldStartDate` skips them for the same reason: a
run that will not spend the time must not reserve it.

**`SimBuffer` now carries no time at all** — not the wait, not `usesWorkingTime`. Keeping a field
nothing reads is the failure §1.5 already found once from the other direction. It stays a node so
the engine's view of a flow remains a faithful image of the map's, same nodes and same positions.
The stored columns are untouched: the map's lead-time ladder and its days-of-stock read them, and
neither goes near a run.

**Left open, and worth knowing:** a genuine process delay — cooling, curing, transport — really does
take its time whether or not the next station is free, and nothing now expresses that. A 24 h
cooling rack is modelled as free. It needs a per-node switch saying which of the two a buffer is;
the day a plant has one is the day to add it. Recorded in §5.5.

**The stored célula 11B run now describes a rule the engine no longer follows.** Re-run it before
reading its figures against anything.

---

## 3. Field feedback, 2026-08-10

Nine items from driving the build by hand against a re-run Célula 11B, each settled by interview
before any of it was written. Ordered the way §1 and §2 were — the schema lands once and the UI sits
on top of it — and split into **four rounds with a hand-driven pass between them**, which is §2.0's
rule and §16.11 is the record of what ignoring it costs.

**This changes what a dispatch rule is, so it invalidates all six stored runs**, exactly as §2.12
did. Re-run before reading any figure against anything.

### 3.0 What the re-run said

Measured off run `01e61863`, 2025-11-10 → 2026-11-13. The demand has grown to **60 orders**, so
none of §2's recorded figures carry over.

| Station | Bars | Max waiting at once | Avg wait |
|---|---|---|---|
| CEU27 | 60 | **8** | **21.3 d** |
| CLAD08 | 28 | 1 | 2.7 d |
| CLAD04 | 32 | 2 | 2.3 d |
| Coating | 60 | 1 | 0.1 d |
| TTAT | 60 | 1 | 0.0 d |
| BAN11 | 60 | 1 | 0.0 d |
| CEU26, END | 60 | 0 | 0.0 d |

Four things it settles before any of the work below, and each of them moved a decision:

- **CEU27 holds the whole queue** — 1 275 order-days of it. Every other station is starved rather
  than congested, which is what §2.12 predicted would happen once the buffers stopped charging their
  14 days: the wait did not vanish, it moved to where the plant actually causes it.
- **TTAT is not a constraint.** Zero average wait, never more than one order queued. §3.2 is a
  fidelity fix and will not move the lead time, and it is worth knowing that before it is built.
- **The sequence is scrambled by the pool, not by the dispatch rule.** TTAT ran order 4 before 3, 8
  before 7, 17 before 16, 19 before 18, 28 before 27 — and TTAT is strictly FIFO and never reorders
  anything. Cladding is a pool of two running at different speeds, so orders leave it out of
  sequence and every station downstream faithfully serves them in the order they turn up. **The
  dispatch rule was not the problem**, which is why §3.1 is about governance rather than about
  comparators.
- **The map claims 21 days the run ignores.** All seven 11B inventory nodes are DURATION —
  4/3/4/4/2/2/2 days — and §2.12 made the engine walk straight over every one. The lead-time ladder
  says 21 days of inventory and the run says nothing at all, and both are right by their own rules.
  That gap is what the field feedback was really pointing at.

### 3.1 Lanes govern the flow — schema v15 — **done 2026-08-10**

Landed in three commits, written up as **§16.16** (the schema), **§5.5** (what a lane does) and
**§7.4** (where the rule lives). Four things worth keeping, each found by doing it:

- **`_ensureColumn` was adding columns to tables it never checked existed.** The v13 fixture predates
  M4's run tables and died on `ALTER TABLE simulation_run_studies`. `_ensureTable` had always asked;
  this half had not, and `onUpgrade`'s own opening note says to ask. Skipping is safe rather than
  quiet — whatever creates the table later builds it from the current definition.
- **`workcenters` needed a `columnTransformer` constant in the v3 and v7 steps.** Third time this
  file has hit that trap, and the first on a second table.
- **A run of consecutive buffers had to be given a meaning**, and the interview had not covered it.
  It collapses to the last — the lane the station actually pulls from — and the earlier ones stay
  free to pass through. Two in a row is a modelling oddity rather than a case with an agreed
  meaning, and summing capacities while recording occupancy on one node would have been incoherent.
  11B alternates strictly, so nothing real is affected.
- **A full lane at the *head* of a flow had to do something**, which the interview also had not
  covered: there is no station behind it to block, so it sends the release slot out empty under its
  own reason. §3.4's pacemaker gate then sits on top of that rather than replacing it.

_Rejected: dropping `workcenter_dispatch` in the schema commit._ It would have stranded every reader
for two commits. The values are carried onto the lanes there and the table is dropped in the commit
that removes the code reading it.


*"I don't know if the dispatch method for the flow is making much sense — the inventories should have
the governance over it?"* Yes, and the answer is larger than the question: the discipline **moves
onto the buffer** and the station keeps none.

The argument is that on a physical FIFO lane you cannot take from the back, so "LIFO lane" is not a
property of the channel — it is how the next station **chooses** from what is standing in front of
it. Which is precisely what §7.4's per-station rule already was, stored where the map cannot draw it.
An invisible station property governing a queue the map draws as a visible lane is the whole
complaint.

- **The rule lives on the inventory node.** FIFO, LIFO, EDD and SPT. FEFO was asked for and is EDD
  under the name the floor uses — the need date *is* the expiry here — so it is not a fifth rule and
  no expiry column is stored. Whether the picker reads `FEFO` or `Earliest due date` is a wording
  call for the day it is built.
- **`workcenter_dispatch` goes.** Its four stored rows are all `fifo`: CEU26, CLAD04 and CLAD Pool
  migrate onto the lane immediately upstream of each target, and CLAD09 — which is in no flow —
  migrates to nothing and is dropped. `simulation_run_dispatch` becomes lane-keyed; it is empty
  today, so nothing is lost.
- **This reverses §1.3**, knowingly. That item put the rule on the station and flattened pool
  membership onto the server because *"one machine can be a candidate for two steps — its own and a
  pool's,"* and a rule travelling with the step would leave two orders at one machine governed by
  different comparators. §5.1's spine is what makes the reversal safe: a step has **at most one lane
  in front of it**, so there is exactly one comparator per queue. A step with no lane before it —
  Teste's CEU19 — falls back to the run's rule.
- **A capacity, in orders, nullable, null meaning unlimited.** The engine's unit of flow is the
  order, so a lane holding "up to 3 orders" is countable without inventing a piece-level model that
  the spine does not have. **Its own column, not `inventory_quantity`**: that figure means *N pieces
  standing there today*, an observation, and §2.12's entire lesson is that an observation must not be
  used as a rule. Nullable means every existing node keeps today's unbounded behaviour.
- **Blocking after service, recorded separately.** A station that finishes an order into a full lane
  holds it and stays occupied until room appears — physical, and the only version that needs no
  clairvoyance. Blocked seconds are stored per step and per workcenter and kept **out of
  `busySeconds`**, or a jammed CEU27 at 86 % utilization would report as a productive one and §8.3's
  three capacity terms would stop meaning what they say. Its own column in the Queue table.
- **§5.5's deadlock objection does not apply.** That rejection — *"it couples the engine, can
  deadlock, and needs blocking-time metrics to be interpretable"* — was written against a general
  graph. §5.1's spine is linear with no branches and no rework loops, so a blocked chain always
  drains from the last station and cannot deadlock. The third clause stands and is answered above.
- **A full lane can send a release slot out empty**, with a new `EmptySlotReason`. This reuses
  §7.3's machinery wholesale and finally lets the empty-slot count distinguish *no material* from
  *nowhere to put it* — which is §18.5's open question answering itself. The run already records 6
  `awaitingMaterial` slots, so the shape is proven.
- **The lane that gates release is the pace setter's**, not the first step's. Lean puts the schedule
  in at the pacemaker, and it makes the constraint govern the line directly rather than through a
  chain of blocked stations propagating backwards. In 11B those are different lanes: the first step
  is the CLAD Pool, the pace setter is CEU27.
- **So the pace setter becomes user-selectable**, defaulting to the derivation `_paceSetter` does
  today and shown on the Flow tab. It now decides both the release cadence and when the line stops,
  and a gate that can move to another station because someone edited a batch size is a gate nobody
  can reason about. One nullable column on `studies`; the derivation stays as the default.

The run has to store lane visits — order in, order out, per lane, with the lane's name, discipline
and capacity copied in — because §7.10 joins to nothing and §3.4 needs them to place its rows.
Same shape as `simulation_run_steps`.

_Rejected: the supermarket, for this round._ It was asked for alongside the four disciplines and it
is not the same mechanism. A supermarket **decouples**: downstream withdraws from stock rather than
waiting for a specific order, and the withdrawal is what authorises upstream to replace it — so the
part that comes out is not the order that went in, and the upstream segment stops being driven by
§7.2's takt release. It needs stock levels, a replenishment trigger and stockout metrics, and it
changes what an order *is* through a buffer. Its own round. §5.2 keeps it decorative until then.

_Rejected: defaulting a lane's capacity from its stored figure._ Every 11B lane would have a limit on
day one with no typing — by reading an observation as a rule, which is §2.12 arriving from the other
direction.

### 3.2 A station can hold more than one order — **done 2026-08-10**

Landed as described, in §3.1 of DESIGN.md and §8.3's glossary. One thing the plan did not settle,
decided while writing it:

- **Units multiply capacity and never the clock.** The interview said "everywhere", meaning
  occupation, utilization's denominator and the flow equivalent's available time. It cannot mean the
  takt clock: §7.2 measures a takt given in days on the pace setter's *productive day*, so folding
  units in there would have halved the release rate of a two-unit pacemaker. The pool turned out to
  be the exact precedent — three cladding machines already raise occupation while leaving the
  per-machine equivalent alone — so units use the same arithmetic and the Summary cannot disagree
  with the run.

The test that earns its place: four orders alternating two parts pay **three changeovers on one unit
and none on two**, because the units settle onto one part each. That is only true because
`lastPartId` lives on the unit rather than on the station.


*"TTAT can process two orders at the same time."* Workcenters gain a nullable parallel capacity,
default 1, and the engine builds that many servers for the station rather than one.

**Two independent units, not a batch process** — and the run says which: TTAT's process times are
0.3, 0.4, 0.7, 1.4 and 3.4 days across different orders, so they scale with batch size. An oven or
autoclave curing a load takes the same time whether one order goes in or three, and would need a
loading policy and a process time that belongs to the load rather than to the batch — which
contradicts §7.6's per-piece model. That is a different feature, and this is not it.

**Capacity means the same thing everywhere.** §8.4's occupation is `load ÷ available`, §6.1's flow
equivalent divides by a station's productive day, and utilization's denominator is `openSeconds` —
all three assume one unit, so a two-unit TTAT would read 200 % loaded on the Summary while the run
reported it comfortable. All of them take the capacity. **Any station given one has its existing
Summary figures change**, correctly but visibly, so it wants a line in the release note.

_Rejected: a pool of TTAT-A and TTAT-B._ Works today with no code — by inventing two machines that
do not exist, which the Summary, the Queue table and the Gantt would then report forever.

### 3.3 A start buffer per study — **done 2026-08-10**

Landed as described, in §7.8. Written together with the pacemaker because both are per-study run
settings and both needed the same new dialog.


*"Order Start = Need Date − Lead Time − Start Buffer."* §7.8's derivation is correct and stays; what
is added is a deliberate safety margin on top of it, per study.

**In calendar days, and the field says so.** A start buffer is protection against real-world
slippage and slippage accrues on a wall calendar — a week late is a week late whether or not the
plant was open. It also composes: the theoretical lead-time walk already returns a wall-clock
instant, so the cold start stays one subtraction on one clock. §17.4 is the scar that makes stating
the unit non-optional.

**It is one lever, not sixty.** `planRun` derives the cold start from the **first** order only and
every later order releases on a takt slot from there, so a 10-day buffer moves every release 10 days
earlier and gives the whole sequence the same margin. That is the wanted behaviour, and it is worth
writing down because the formula reads as if it were per order.

_Rejected: a run start override._ It was the first thing offered and the buffer is better: it keeps
§7.8's derivation working rather than replacing it with a date that goes stale the moment the demand
moves.

### 3.4 The Gantt reads as a flow — **round two, the geometry has landed**

**Done 2026-08-11**, in one commit: the bands, the stacking, the depth rule and `barAt`. 10 pure
tests, 638 in all, `flutter analyze` clean. The open question is answered — an uncapped lane takes
its depth from **how full it actually got**, which is what `SimLane.capacity` had already written
down when the lanes were carried out of the run. Three things only writing it settled, all three in
the commit message and in §8.6: a lane is placed by the step it feeds rather than by its stored
spine position; a capped lane is drawn at its capacity and an uncapped one at its observed depth;
and bands stopped being a uniform height, so the row index is carried on the hit rather than divided
back out of a rect.

**What is left of this item, and it needs no new decisions:**

- [ ] **The hover card for a stay in a lane.** `barAt` returns it and the view drops it on the
      floor deliberately — a waiting order is drawn and picked but reports nothing, rather than
      putting a station's card over the wrong subject. The card wants the order, the part, the lane,
      when it arrived, when it was pulled out and how long it stood there, which is new l10n in
      three languages.
- [ ] **Bar labels gain the order number** — part number first, order number appended when the bar
      is wide enough for both, so every label that reads correctly today reads the same way.
- [ ] **Drive it against célula 11B.** `2f4c8db4` is the run to open: `FIFO CEU27` is capped at 2
      and the band should be visibly full while TTAT's 4.6 d of blocking sits in the row above it.
      Nothing in the suite renders a pixel — §2.5's rule.

_Original wording, for the record:_

- **A lane row per inventory node, between the two station rows it connects**, so the chart reads
  down the page the way the line runs. **Orders stack inside it and the row's height is the
  capacity**, so a full lane is visibly full and blocking is something the reader *sees* rather than
  infers. Same part colours, drawn hatched or outlined so a waiting order never reads as a running
  one. Uncapped lanes need a height rule — the open question in this item.
- **This is what makes drawing the queue affordable at all.** §2.7 rejected queue spans because
  *"CEU27 holds dozens of orders waiting at once, and drawing those would smear the row solid"* — and
  it would, on a station row. A capacity bounds the height by a number the user typed, which is the
  premise that rejection did not have.
- **Row placement needs the stored lane visits** from §3.1. `routingRanks` derives station order from
  the run because §7.10 forbids joining to the flow, and buffers leave no trace in
  `simulation_run_steps` today.
- **Bar labels gain the order number**: part number first, order number appended when the bar is wide
  enough for both. Keeps every label that reads correctly today reading the same way. `barAt` and the
  hover card extend to lane rows unchanged.

### 3.5 Closed time on the Gantt — **round two**

*"Gantt not showing the weekends/holidays."* §2.7 ruled this out — *"splitting a bar at closed time
would need calendars a stored run does not have"* — so it needs new stored data whatever is chosen,
and joining to the live plant is not available: shading that changed silently when someone edited a
shift pattern would be worse than none.

**Each station's calendar is snapshotted into the run** — shift pattern, staffing and exceptions.
Compact: `ShiftPatternSpec` is a weekday bitmask plus shift windows, and `staffing_codec.dart`
already renders operators as `1/1/1`. `WorkingCalendar` is pure, so the view rebuilds it and computes
closed spans **for the visible window only**, the way `ganttTicks` already does for the same reason
(§16.9's ~13 µs per local `DateTime`). Per row, because stations genuinely differ and per-station
calendars are the whole of M1.

This turns §2.7's *"a gap means not running — closed and starved alike"* into two distinguishable
states, which is a knowing reversal rather than an oversight.

_Rejected: one shading for the whole chart from the pace setter._ One snapshot instead of eight and
it reads like every other Gantt tool — and it is a lie on every row whose station works a different
pattern.

### 3.6 The date format is the user's — **round three**

*"Date format DD/MM/YYYY — user set in settings."* §12.4 currently says dates follow the locale, and
the app has no locale setting at all: it follows Windows, so an en-US machine shows `8/10/2026`.

**An explicit format, independent of language** — DD/MM/YYYY, MM/DD/YYYY, YYYY-MM-DD — stored in the
`app_settings` table that exists and is unused, picked on the Settings screen that is still a
`PlaceholderScreen`. Independent of UI language deliberately: English UI with Brazilian dates is
reachable this way and is not reachable through a locale picker.

**It must reach the parser in the same commit.** `date_input.dart:30` parses typed dates with
`DateFormat.yMd(locale).parseStrict`, so a display format changed alone would make every date field
reject what it had just shown.

**And the Excel export**, as a number format on the date columns. §13.1 writes real `DateCellValue`s
with no format, which Excel renders by *the viewer's* Windows locale — which is exactly how a date
column ends up reading `45 872`. This closes the open §4 item about opening the file in Excel.

The Gantt axis keeps its month names (`Jan 14`); they are not a numeric format and `14/01/2026`
under every tick is worse. §12.4 is amended from *dates follow the locale* to *dates follow the
user's setting, defaulting to the locale*.

### 3.7 The result stays until it is dismissed — **round three**

*"View results persistent bar after run, add a close button."* Today it is a plain `SnackBar` with
Flutter's 4-second default (`project_workspace_screen.dart:221`), so it is not currently persistent.

**A `MaterialBanner` above the tabs**, carrying the headline figure, `View results` and a close
button. A snackbar anchors to the bottom of the window, and since §2.7 gave the Gantt the full body
height, a bar that never goes away parks permanently over the last station's row and the scrollbar
gutter §2.11 added to get at it. A banner pushes content down instead of covering it, and a
persistent statement about the project is not what a snackbar is for.

### 3.8 A map that never runs — **round four**

*"VSM only feature, without the simulation, just for visual but in a more free."* A study can be
marked map-only: excluded from runs, so readiness stops demanding takt periods, process times and
bound steps, and Simulate ignores it. §5.2's decorative layer — free-placed trucks, supermarkets,
kaizen bursts, notes — becomes reachable, which closes half of §17.5's built-but-unreachable list.

**And free topology**, which is the larger of the two options and was chosen deliberately. §5.1
rejected branching because it *"forces part-specific routings, join synchronisation, and branch-aware
lead-time roll-up"* — every one of those objections is about **simulating** it, and a map that never
runs owes none of them.

**The cost is a second layout path.** `flow_layout.dart`, §1.6's arrow geometry, `flow_pdf.dart` and
the lead-time ladder all assume the spine, so this is closer to a sibling of the existing canvas than
a flag on it. It is M5-sized and it is last for that reason.

### 3.9 DESIGN.md

Written as each piece lands rather than swept up at the end — §1.10 and §2.9 are the evidence that
doing it that way finds things. Sections this round will touch: **§5.2** (the supermarket stays
decorative; the decorative layer becomes reachable), **§5.5** (lanes govern: discipline, capacity,
blocking), **§6.1** and **§8.3** and **§8.4** (parallel capacity means the same thing everywhere),
**§7.2** (a full lane sends a slot out empty), **§7.3**, **§7.4** (the rule moves off the station),
**§7.7**, **§7.8** (the start buffer), **§7.10** (lane visits, blocked seconds, calendar snapshots),
**§8.6** (lane rows, closed-time shading, bar labels), **§12.1** (the results banner), **§12.4**
(dates follow the setting), **§13.1** (the export's number formats), **§16.16** (schema v15, new),
**§17.5**, **§18.5** (empty slots, answered) and **§18.8** (the pace setter is chosen, not derived).

---

### 3.3b The pacemaker, and where round one's settings live — **done 2026-08-10**

Not in the plan as its own item; it fell out of §3.1's release gate. The pace setter became a study
setting rather than a derivation, because it now decides both the cadence and when the line stops.
Written up in §7.2 and §12.1.

- **It is resolved as a node, not a workcenter id.** The gate is a place in the flow, and one machine
  may appear in two studies with only one of those appearances being this study's pacemaker. A named
  pacemaker that has since been deleted falls back to the derivation — a deleted node should not read
  as a broken study.
- **`Run settings` is a new dialog** on the study menu, carrying the buffer and the pacemaker.
  `wipCap` and `priority` belong in it and are still unreachable (§17.5); they were left rather than
  smuggled into this round.

---

## 4. Verify in the running app

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
      86 % utilization holding 4487 d of queue and 58 % of the flow's total time. Worth reading as
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
- [x] ~~**§2.10's tables and grid, in the real app.**~~ Done 2026-08-08, in Debug and then in
      Release. It found the two-bar defect on the Summary tab that §2.10's fourth commit fixed —
      which the widget tests could not have, because a bounded pane inside a page that also scrolls
      is a composition none of them mounted. The parts grid's frozen part number and the production
      plan's pane were both looked at and stand. **The plan keeps its 360 px pane by decision, not
      by omission**, and is the next candidate if it ever grates.
- [ ] **The Gantt, against célula 11B.** §2.7 is covered by pure and widget tests only, and the
      painter is the part none of them reach. Seven rows, 231 bars: check the fit opens on the whole
      run, that zooming to a day makes bars real rather than floored and the note saying so goes
      away, that hovering a bar names the right order, and that the colours hold in both themes and
      the strip matches the Parts table's swatches. In es and pt as well — §2.10's widths were only
      trustworthy because they were checked.

      Specifically worth looking at, because nothing in the suite can:
      - **The axis at the opening fit.** The run is ~2 years, so the ticks should be quarters and
        each label should read as a date that stands alone. At the ceiling they become hours.
      - **Zooming ten times from the fit** should reach one hour across the pane and stop, with
        zoom-in going dead there and zoom-out dead at the fit. The instant under the middle of the
        pane should still be under it after each press.
      - **The changeover stroke** on a bar wide enough to carry it, and its absence on one that is
        not — the hover card should say it either way.
      - **The frozen labels against a long station name**, and the hover card at the right-hand edge
        of the pane and on the bottom row, which are the two places it has to be pushed back inside.
- [ ] **The plan in Excel, opened in Excel.** §13.1 is asserted by decoding the file back, which
      proves the cells are typed but says nothing about how Excel *renders* them: a date column
      whose default format is `45 872` and a duration column reading `1.2500000000` are both
      technically correct and both unusable. Export the célula 11B plan, open it, and check the
      dates read as dates, that Order Start shows its time, and that sorting the Float column puts
      the late orders where a planner expects. In es and pt as well — a locale decides how Excel
      itself formats a date cell.
- [ ] **Round one, against célula 11B.** Half driven, on 2026-08-10 in Debug and confirmed off the
      stored runs on 2026-08-11. What is left is the pacemaker, the buffer, and es and pt.
      - [x] ~~**The v14 → v15 migration on the real database.**~~ Ran 2026-08-10; verified on a copy
        2026-08-11. Two rules carried, not the three predicted — the header says why, and it is a
        consequence of §3.1's own rule rather than a defect.
      - [x] ~~**Give `FIFO CEU27` a capacity** and re-run.~~ Set to **2**, and run twice — `7f541565`
        and `676fb0e3`, against `5bf76ac1` as the uncapped v15 baseline. **Blocked time appeared
        exactly where it should and nowhere else: TTAT 216.4 d, every other station 0.0 d.** TTAT is
        the station immediately behind the capped lane, and nothing propagated past it because
        `FIFO TTAT` above it is uncapped. **Utilization stayed at 20 %**, which is §3.1's requirement
        observed rather than asserted — blocked seconds are out of `busySeconds`, so a jammed station
        does not read as a productive one.
      - [x] ~~**Name CEU27 the pacemaker.**~~ Done 2026-08-11 in Release `0.1.0-2026-08-11`, run
        `2f4c8db4`, together with a 30-day buffer. **`laneFull = 7`** — the first time
        `EmptySlotReason.laneFull` has been observed outside a test, and §18.5's *no material* versus
        *nowhere to put it* is now a distinction the app has actually drawn. `awaitingMaterial` went
        6 → 8.
      - [x] ~~**A start buffer.**~~ 30 days rather than the ten this list guessed, and it behaved as
        predicted: it moves the dates and leaves the lead times alone, because a uniform shift of
        every release cannot change `delivered − released`.
      - [x] ~~**Set TTAT to two units.**~~ Set, and it is in the file. Still worth **one look at the
        Summary** — that its occupation halves while the Queue table keeps reporting one station is
        the part no stored run can show.
      - [x] ~~**And the WIP fell, once the gate was on the capped lane.**~~ Against `676fb0e3`:

        | | `676fb0e3` capped only | `2f4c8db4` capped + gated |
        |---|---|---|
        | avg lead time | 47.2 d | **31.1 d** |
        | TTAT blocked | 216.4 d | **4.6 d** |
        | empty slots | 6 material | 8 material + **7 lane-full** |

        This is what the round was for, and it corrects an assumption this list was built on: **the
        capacity does nothing to WIP until the gate is on the capped lane.** Capping alone moved
        the queue out of the lane and onto TTAT (216 d of blocking) without removing it, because
        release runs on the takt and only the pace setter's lane gates it (§3.1). Gating it stopped
        the line being stuffed: blocking nearly vanished and 16 days came out of the average order.
      - [ ] **One confounder, worth a run to settle.** Naming CEU27 the pacemaker also changed the
        **takt, 2.42 d → 3.14 d**, because §7.2 measures it on the pace setter's productive day and
        CEU27's calendar is not CLAD08's. Releases are therefore 30 % further apart in `2f4c8db4`,
        and that alone relieves congestion — so the 16-day drop is **not yet attributable to the
        lane gate alone**. A run with the pacemaker on CEU27 and the capacity taken off
        `FIFO CEU27` would isolate it: same takt, no gate. Worth doing before §3.4 draws lane rows
        that will be read as showing the gate working.
      - [ ] In es and pt as well — the four new dialogs carry the longest help text in the app.
- [ ] **Layout polish, from the 2026-08-11 session.** Noted at the GUI as wanting improvement and
      explicitly deferred; **the specifics were not captured**, so this is a placeholder rather than
      an item. Write down what grated before it is worked on, or it will be guessed at.
- [ ] **The readiness panel against a real gap.** It has only been seen clean. Unbind a step or
      clear a takt period and check it names the study and disables Simulate. §2.0 says what is
      already covered underneath it, so this is a two-minute check of the wiring, not of the logic.
- [x] ~~**Rebuild Release and drive the v11 → v12 migration against the real database.**~~ Both done
      2026-08-05 under label `0.1.0-2026-08-05`; verified 2026-08-06 by inspecting the live file
      rather than trusting `user_version`. Evidence in the header and §2.0.

---

## 5. Known gaps, deliberately left

- [ ] **§14's performance target is not met.** A 2000-order, 10-step run takes ~2.8 s against "well
      under a second". §16.9 has the measurements: the cost is local `DateTime` arithmetic on
      Windows (~13 µs per construction, versus 0.03 µs for the UTC equivalent). Closing it means
      working in epoch integers inside `WorkingCalendar` and converting only at its edges — a real
      refactor of the most heavily tested code in the app. Worth doing deliberately.
- [ ] **The result tables build every row.** A `DataTable` is not lazy, so §12.6's 360 px pane on a
      §14-scale 2000-order plan constructs 2000 rows to show seven. True before the pane existed —
      the pane only makes it *look* lazy — and it sits behind the item above, because the run that
      would produce 2000 orders does not finish in time either. Closing it means the read-only twin
      of `DataGrid`: a heading row over a `ListView.builder`, which is the structure the grid already
      uses. Recorded in §14.
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

## 6. M5

Reports (§13), run comparison, templates and binding (§10.2), the About screen, and the drop.

Run comparison has what it needs: two `StoredRun`s report through the same `summariseRun`, so the
figures on either side of a comparison cannot have been computed two different ways. §1.3's stored
dispatch overrides are what lets a comparison say the dispatch is what differed.

The Production Plan already exports (§2.8, §13.1). What is left for M5 is the *report* PDF §13
reserves — input snapshot, metrics, bottleneck ranking, late-order list — which the plan's `.xlsx`
was deliberately kept from pre-empting.
