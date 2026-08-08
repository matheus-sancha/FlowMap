# FlowMap — what is next

Working state as of 2026-08-08. `docs/DESIGN.md` remains the source of truth for *why*; this file
is only a plan, and each item should be deleted from it as it lands.

Branch `m1-m2-foundation`, clean, `flutter analyze` clean, 525 tests passing, not pushed.
Schema is at **v14** — untouched by §2.10, which is UI only. M4 is code-complete.

**The Release bundle is current, and v12 is on the real database.** Both were done late on
2026-08-05 and this file did not record it — checked 2026-08-06 and written down here so it is not
re-done a third time. `Release/data/app.so` was compiled 23:45, four minutes after `ebde766`, the
last commit; the log's session at 23:45:30 reads `db.open schema 12 from 11` under build label
`0.1.0-2026-08-05` rather than `dev`, and a run on the migrated database succeeded at 23:46:36.
`flowmap.exe`'s own Aug 3 timestamp still means nothing: it is the C++ host shell from
`windows/runner/`, which has not changed, so CMake rightly declines to relink it.

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

- **A section in `_Results` on the Simulation tab**, below the Production Plan, ~360 px tall with
  its own scroll. It reads the same `StoredRun` as everything else there, so opening an earlier run
  from the history menu opens its Gantt with it — §8.5's rule for the plan, applied again.
- **One chart for the whole run, all studies together** — deliberately the opposite of §8.5's
  per-study sectioning, and for a stated reason: the plan's rows are orders and an order belongs to
  one line, but a **station is shared**. Splitting per study would draw a station idle during hours
  it was in fact running another study's order, which is the one thing §7.7 exists to model.
- **Bars are process only**, `processStart → processEnd`. They tile without overlapping — one server
  runs one order at a time, and a pool's members are separate `workcenterId`s with their own rows.
  Queue spans do not tile: CEU27 holds 4487 days of queue, which is dozens of orders waiting at
  once, and drawing those would smear the row solid over the bars underneath. Queue is already
  reported per station in the Queue table and per order by §2.3's two columns.
- **A gap means "not running" — closed and starved alike**, stated here rather than left to be
  inferred. Shading closed time is not a read: `run_metrics.dart:196` records that a stored run
  "has the numbers but not the calendars that produced them", and `simulation_run_workcenters`
  keeps only a total `openSeconds`. The station's utilization and open time sit in the Queue table
  on the same tab, which is where "how much of that gap was even available" is answered.
- **Rows follow `metrics.stations`**, in the order the Queue table above it uses, so the two cannot
  disagree about which station is which. That map is built from steps, so a station that never ran
  has no row.
- **X-only zoom, opening fitted to the run.** Station rows keep a fixed height and their labels stay
  pinned in a frozen left column; the painter takes pixels-per-second and a window start. A
  fit / zoom-in / zoom-out cluster shaped like the canvas's, and horizontal drag to pan. Bars get a
  ~2 px floor so a step of a few hours is never invisible at whole-run scale — indicative there,
  and said so.
- **Geometry lives in a pure `gantt_layout.dart` under `application/`**, returning rows and bar
  rects; the `CustomPainter` only strokes what it is handed and hover is a lookup against the same
  rects. This is §1.6's precedent, which moved arrow geometry into `layoutFlow` so that what a link
  *is* could be asserted without pumping a frame — and the Gantt has strictly more geometry than the
  arrows did.

**Colour by part number**, which gives the app its first categorical palette:

- **A fixed eight-colour `partPalette` in `common/`**, legible against both themes, assigned by the
  part's position in the run's sorted part list so the same run always colours the same way. Past
  eight it wraps; two parts share a hue and the bar label and hover still say which is which. One
  place to change it when the next part-coloured view arrives.
- **The Parts table is the legend.** A swatch in its Part Number cell, no separate strip — the
  table sits directly above the chart and lists exactly the same parts, so the colour is defined
  once beside that part's orders, on-time and lead-time figures, and the reader learns the mapping
  while reading the numbers.
- **Changeover is still marked**, as a short hatched prefix at a bar's leading edge. A colour change
  between adjacent bars is not the same fact: §7.6 decides changeover by the batching rule, so the
  two can disagree in both directions.

_Rejected: hue rotation off the seed colour._ Never runs out, always in the app's family — but
adjacent hues stop being distinguishable past six or seven parts, and adding a part recolours a run
that has not changed.

_Rejected: colour by study._ Fewer colours to pick, and it shows contention at a shared station.
Within one study — the common case — every bar is the same colour.

### 2.8 The plan, in Excel

`.xlsx`, one sheet per study, header row, §2.3's thirteen columns, from the same `StoredRun` the
table renders. **Dates as dates and durations as durations**, not text, so they sort and pivot;
stamped with app version, project name and run timestamp per §13's last line. `excel: ^4.0.6` and
`file_selector` are already in the tree.

This is what §13 already assigns it — "Excel: any grid in the app, plus **per-order simulation
results for pivoting**" — and the Production Plan is per-order simulation results. A planner merges
it with their own system, which no PDF allows.

_Rejected: a PDF of the plan._ §13 reserves PDF for the full simulation *report* — input snapshot,
metrics, bottleneck ranking, late-order list — and a standalone plan PDF pre-empts a document that
does not exist yet. Thirteen columns landscape is tight in any case.

**The Gantt does not export.** §4's parking of exports covers it: a chart spanning months has to be
paged across sheets or scaled to illegibility, and it is the hardest of the three to print well.

### 2.9 DESIGN.md

Written as each piece lands, not swept up at the end — §1.10 is the evidence that doing it that way
finds things. Sections this round touches: **§5.2** (the FIFO lane is its own figure), **§7.10**
and **§16.14** (schema v13, new), **§8.5** (three new columns, and Delivery → Order end), **§8.6**
(the Gantt, new), **§12.2** (refit on viewport change), **§13** (the plan's Excel export). None of
it is real until those say it, in the same commits that change the behaviour.

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

---

## 3. Verify in the running app

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
- [ ] **§2.10's tables and grid, in the real app.** Everything below is covered by widget tests and
      two rendered PNGs, which is what found the three defects §2.10 records — but nothing has been
      driven by hand. Worth looking at: the Summary table's first cell, where a long workcenter name
      now ellipsises inside a declared 190 px beside its `×3` badge and error icon; whether 360 px is
      the right pane height in a real window; and the parts grid on `Célula 11B` with its real
      station count, which is the case that started this.
- [ ] **The readiness panel against a real gap.** It has only been seen clean. Unbind a step or
      clear a takt period and check it names the study and disables Simulate. §2.0 says what is
      already covered underneath it, so this is a two-minute check of the wiring, not of the logic.
- [x] ~~**Rebuild Release and drive the v11 → v12 migration against the real database.**~~ Both done
      2026-08-05 under label `0.1.0-2026-08-05`; verified 2026-08-06 by inspecting the live file
      rather than trusting `user_version`. Evidence in the header and §2.0.

---

## 4. Known gaps, deliberately left

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

## 5. M5

Reports (§13), run comparison, templates and binding (§10.2), the About screen, and the drop.

Run comparison has what it needs: two `StoredRun`s report through the same `summariseRun`, so the
figures on either side of a comparison cannot have been computed two different ways. §1.3's stored
dispatch overrides are what lets a comparison say the dispatch is what differed.

Export of the Production Plan (§1.5) belongs here, with the other reports.
