# FlowMap — what has already happened

Split out of `docs/TODO.md` on 2026-08-15, so that file could become a plan again rather than an
archive with a plan on the end of it. **§5 was moved across on 2026-08-29** for the same reason, and
closed the last of `TODO.md`'s §0. **Nothing here has been rewritten.** The rounds below are
verbatim, including the reasoning that was wrong at the time and the note saying so — that is what
they are for.

`docs/DESIGN.md` remains the source of truth for *why the app is the way it is*. This file is the
source of truth for *what was done, when, and what it met when it ran*: run identifiers, migration
timestamps, backup filenames, and the figures each round was read against. §2.0 exists because that
evidence was lost once already and a rebuild was nearly done a third time; keep appending to it
after every drop rather than trusting memory.

Read a figure in here against the engine of its own date. **Four changes have invalidated every
stored run as they landed** — §2.12 (buffers stopped charging their wait), §3.1 (the dispatch rule
moved onto the lane), §5's round one (availability came off setup, and cold start started paying
one), and `TODO.md`'s §8.1, which stops an order queueing at a station its part never visits. So a
number below describes the model as it stood, not as it stands.

**A fifth change moves some runs but not all of them: §6.2, v28**, which refilled the dispatch
fall-through's middle slot with the need date. It touches only orders that tie on arrival — 78 pairs
in 189,623 step rows — so most of a run is untouched and no figure here is retracted by it.

**A sixth changes what a run writes down without changing what it computes: phase 9, 2026-09-07**,
which stopped clipping monthly capacity to the run. Every station the plant has *scheduled* now gets
capacity rows spanning its own schedule, where before only the stations the routings reached got
them and only for the run's own months. No order moves and no date changes — the engine's answer is
identical — but the occupation grid of a run stored before this date is narrower than one stored
after, and **no marker distinguishes them**: `created_at` dates the run, and this line is the
record. On the live plant the newest run goes from **255 capacity rows across 17 stations and 15
months to 636 across 18 stations and up to 36**, and its whole-plant TOTAL column falls from 68.4 %
to 28.5 % because months with real capacity and no demand join the denominator. Per-month figures
are untouched. The 150 runs stored before it keep what they have (§7.10).

---

## The state this file was split at

_What follows is the header `docs/TODO.md` carried on 2026-08-15, at the moment of the split. It is
the working state the round after it started from._

Branch `m1-m2-foundation`, clean, `flutter analyze` clean, **669 tests passing** (one of them
`live`-tagged and skipped without a database). Schema is at **v16**. M4 is code-complete.

**§3 is code-complete except §3.8, which is deferred by decision until the rest of the plan is
done.** Rounds one, two and three have all landed; §3.5 was dropped on the field's verdict rather
than built. **So the initial plan has no code left in it** — what remains before M5 is §4's
hand-driven verification, and the two §4 items that need a second look after this round: the date
format in the demand grid and in Excel, and the results banner.

**§3's round one is done, in five commits, and about half of it has now been driven by hand.** The
lanes govern the flow, a station may hold more than one order, the pacemaker gates the release, a
study may add a start buffer, and every one of those is reachable from the UI. **All five of §4's
round-one checks have now met the real database**, in Release `0.1.0-2026-08-11` — evidence under
§4. The round did what it was for: with the gate on the capped lane, the average order lost 16 days
and `laneFull` was observed for the first time. What is owed is one run to settle the takt
confounder, and es and pt.

**What is next needs a human at the GUI, not more code**, and that is now true of the whole plan
rather than of one round. §4's Gantt item is only partly closed:
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
v15 baseline with nothing set.

**Round two is closed.** §3.4 landed and was driven, and §3.5 was dropped on the field's verdict
that the chart already reads correctly — so no schema bump this round and the Gantt is done being
changed. Rounds three and four are untouched.

**The v15 → v16 migration has run against the real database** — on 2026-08-15, in Release
`0.1.0-2026-08-15`, and the log line that says so is `db.open schema 16 from 15` at 10:04:58. It was
driven against a **copy first** and only then against the file: the copy is
`flowmap.sqlite.backup-v15-20260815-100223`, taken beside the live one, and
`test/data/live_db_check_test.dart` upgraded a scratch duplicate of it before Release was allowed
near the real thing. `schedule_horizon` is present on the real table, `integrity_check` ok, and
**0 of 35 runs carry a horizon**, which is right — every stored run predates v16, and a blank has
meant *made before this column existed* on this table since v12.

**That live check no longer names a version, and it is worth saying why.** It was
`live_v15_check_test.dart` and asserted `user_version == 15`; opening the file *runs* the migration,
so once v16 landed the test upgraded its own copy to 16 and then failed on its own first line. The
check that exists to catch a migration problem was broken by a migration, and nothing would have
made whoever bumped the schema edit the literal. It is `live_db_check_test.dart` now and asserts
`db.schemaVersion`, with each version's specific claims accumulating in it rather than replacing the
last. **This is the standing check to run before any future schema bump meets real data**, by hand,
with `--tags live` and `FLOWMAP_LIVE_DB` pointing at a **copy**.

**Three runs happened after this file was last written and none of them were recorded here** —
2026-08-11 20:19 and 20:47, and 2026-08-12 06:22, all 60 orders and 420 steps, under build labels
`0.1.0-2026-08-11b` and `d` that no item below mentions. The run count went 32 → 35. What they were
for is not known, so nothing is claimed about them; they are noted because an unrecorded run is
exactly what §2.0 and the rebuild paragraph below exist to stop. **The stored configuration is still
`2f4c8db4`'s** — `FIFO CEU27` capped at 2, TTAT at two units, Célula 11B on a 30-day buffer with a
named pacemaker — so whatever those runs were, the confounder run §4 still owes has not been done.

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

**The Release bundle was rebuilt again 2026-08-15 under label `0.1.0-2026-08-15`**, and launched:
the session header at 10:04:58 reads that label and `db.open schema 16 from 15`, which is the
migration evidence above. A v15 backup was taken first, as
`flowmap.sqlite.backup-v15-20260815-100223`.

This paragraph exists because the 2026-08-05 rebuild went unrecorded and was nearly done a third
time; keep it truthful after every drop. **The Aug 3 exe rule broke on 2026-08-15, and the new
timestamp is the thing that means nothing.** The rule was: `flowmap.exe` is the C++ host shell from
`windows/runner/`, which does not change, so CMake declines to relink it and only
`Release/data/app.so` moves — which held on 2026-08-05, on 2026-08-11 (`app.so` at 20:17, exe still
Aug 3), and stopped holding on 2026-08-15, when the exe relinked at 10:03:12 beside an `app.so` at
10:03:08. Nothing in `windows/runner/` was touched, so this is the toolchain's decision rather than
ours and was not chased further. **What survives of the rule is its useful half: `app.so`'s
timestamp is what says the Dart code was rebuilt, and the exe's says nothing either way.** Read the
session header's build label, which is the only claim that cannot be produced by a stale link.

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

**The card and the labels landed the same day.** One card describes both kinds, because a reader
asking *what is this* wants the same six answers either way — which order, which part, where, when,
how long, and what it was doing. Three new strings in en, es and pt. Two things worth keeping:

- **The card says the lane's real depth, not the depth it is drawn at.** §8.6 caps the band at four,
  so a reader measuring the stack against the capacity would otherwise be measuring the cap.
- **`onBar` in the view tests was computing a row from a rect's top**, which held only while every
  band was `rowHeight` tall. It aims at the rect's own middle now — it would have aimed at the wrong
  row on any chart with a buffer in it, and none of the existing tests would have caught that,
  because none of their fixtures had one.

The order number is appended to a bar's label above 92 px, where the part number alone starts at 46.
Strictly additional: a bar between the two widths reads exactly as it did before.

**Driven 2026-08-11, in Release `0.1.0-2026-08-11b`, and it found one defect** — the only thing that
looked off, and a real one: **a station running two or more orders at once drew them on top of each
other.** Not a drawing bug but a stale premise. §8.6 said bars tile without overlapping because every
workcenter was its own server, which **§3.2 made false this round** without anything coming back to
the chart; TTAT is the two-unit station, which is where it showed. Station bars take a sub-row each
now, by the same greedy pass the lane stacks use, and §8.6 records what happened. Four tests, 643 in
all.

**What is left of this item:**

- [ ] **Look at it again in `0.1.0-2026-08-11c`.** The overlap fix changes every band's height, so
      the things already looked at are worth a second glance rather than being taken as still true.
- [ ] **Drive it against célula 11B.** `2f4c8db4` is the run to open: `FIFO CEU27` is capped at 2
      and the band should be visibly full while TTAT's 4.6 d of blocking sits in the row above it.
      Nothing in the suite renders a pixel — §2.5's rule, and the lane bands, the wash-out fill and
      the two rails have never been looked at. In es and pt as well; `El carril admite 2 pedidos` is
      the longest of the three new strings.

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

### 3.5 Closed time on the Gantt — **dropped 2026-08-11**

**Dropped after looking at the chart, not on the argument.** The field verdict was that the Gantt
reads correctly as it stands, so §2.7's *"a gap means not running — closed and starved alike"*
stays, and it stays as a decision that has now been **checked against the running app** rather than
only reasoned about. §8.6 needs no change; the sentence it already carries is the one that stands.

Worth keeping, because the cost of the reversal is what makes dropping it cheap: this was the only
item in round two that needed **new stored data and a schema bump**. Each station's calendar would
have had to be snapshotted into the run — shift pattern, staffing and exceptions — because §7.10
forbids joining to the live plant, and shading that changed silently when someone edited a shift
pattern would be worse than none.

**If it ever comes back**, the design was settled and only the wanting was missing: snapshot per
station (compact — `ShiftPatternSpec` is a weekday bitmask plus shift windows, and
`staffing_codec.dart` already renders operators as `1/1/1`), rebuild `WorkingCalendar` in the view
and compute closed spans **for the visible window only**, the way `ganttTicks` already does for the
same reason (§16.9's ~13 µs per local `DateTime`).

_Rejected then and still rejected: one shading for the whole chart from the pace setter._ One
snapshot instead of eight and it reads like every other Gantt tool — and it is a lie on every row
whose station works a different pattern.

_The original request was_ **"Gantt not showing the weekends/holidays."** _It is answered by the
Queue table, which is where "how much of that gap was even available" already lives._

### 3.6 The date format is the user's — **done 2026-08-11**

Landed as described, written up in **§12.4** and **§13.1**. 17 tests, 660 in all. The
`app_settings` table and the Settings screen were both built-but-unreachable since M1 (§17.5) and
are now both reached. Three things worth keeping:

- **The Excel pattern is derived from the same `DateFormat` the screen renders with**, not listed
  per setting — which is the only way it can be right under the locale default, where no table in
  this repo could know what `intl` chose for that locale. `intl`'s `M` becomes Excel's `m`, and
  widths are padded so a locale's `M/d/y` does not reach a planner as `8/3/26`.
- **A scope, not a provider read at each site.** Almost nothing that renders a date is a consumer —
  the hover card, the run header and the plan table are plain widgets deep inside painted or
  scrolled trees — so one `Consumer` at the root installs `DateStyleScope`.
- **The round-trip test runs over every setting**, not the one being added, so a fifth format
  cannot land with only half of it wired.

### 3.6 The date format is the user's — _original wording_

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

### 3.7 The result stays until it is dismissed — **done 2026-08-11**

Landed as described, in **§12.1**. Two things the plan did not settle, both decided by writing it:

- **The action dismisses as well as navigating.** A bar still offering to take you to results you
  are now looking at is asking a question already answered.
- **A failed run offers no `View results`** — there is no run to look at, and a button promising
  one would be a lie. It stays dismissible either way, since a bar that cannot be got rid of would
  be worse than the snackbar it replaced.

`RunBanner` is `@visibleForTesting` rather than private: the workspace needs a project, a study
list and a database to mount, and **there is no test coverage of that screen at all** — §1.8 moved
the last of it out. Four widget tests, 664 in all.

### 3.7 The result stays until it is dismissed — _original wording_

*"View results persistent bar after run, add a close button."* Today it is a plain `SnackBar` with
Flutter's 4-second default (`project_workspace_screen.dart:221`), so it is not currently persistent.

**A `MaterialBanner` above the tabs**, carrying the headline figure, `View results` and a close
button. A snackbar anchors to the bottom of the window, and since §2.7 gave the Gantt the full body
height, a bar that never goes away parks permanently over the last station's row and the scrollbar
gutter §2.11 added to get at it. A banner pushes content down instead of covering it, and a
persistent statement about the project is not what a snackbar is for.

### 3.8 A map that never runs — **deferred 2026-08-11, until the initial plan is complete**

Not dropped and not disagreed with — **sequenced**. It is the one item in §3 that is M5-sized and
the one that buys nothing for the plant already being modelled, so it waits until everything else
in the plan has landed. The argument below stands as written; nothing about it needs revisiting when
it is picked up.

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
**§7.7**, **§7.8** (the start buffer), **§7.10** (lane visits, blocked seconds), **§8.6** (lane rows,
bar labels, and a station's sub-rows), **§12.1** (the results banner), **§12.4**
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

---

## 4. What has been verified in the running app

Carried out of `docs/TODO.md`'s §4 at the split. Only the checks that have actually been driven are
here; what is still owed stayed behind in the plan.

- [x] ~~**Upgrade a real database.**~~ Done 2026-08-05. It was at v6 with v8-shaped tables from an
      upgrade that had died part-way, and the app could not open it at all; §16.11 has the fix and
      the fixture. It now migrates v6 → v11 with everything intact. A backup of the pre-migration
      file is beside it as `flowmap.sqlite.backup-20260805-054746`.
- [x] ~~**A real run.**~~ Done 2026-08-05. `Célula 11B` flagged, readiness clean, Simulate ran 33
      orders through 231 steps in 1432 ms and stored it; reopening the tab after a restart shows the
      same run without recomputing it. The result says the sequence is badly over-committed — 3 %
      on time, average float +230.7 d (−230.7 d under §1.2's sign), lead-time efficiency 2.39×, 63
      empty release slots, CEU27 at 86 % utilization holding 4487 d of queue and 58 % of the flow's
      total time. Worth reading as a finding rather than a smoke test.
- [x] ~~**MM3's two columns.**~~ Confirmed: `Equivalent` is per part (PN3 is 0.70 at every batch
      size) and `Slot load` is equivalent × batch, which is what MM3 averages.
- [x] ~~The canvas.~~ Confirmed: push arrows meeting the triangle, the triangle centred on the
      spine, the `#3` chip on the CLAD Pool box, the `Takt C/T` row, the sidebar toggle on the
      left. Two defects found and fixed while looking — §16.12. A second pass on 2026-08-05 found
      the three in §1.7.
- [x] ~~**§2.10's tables and grid, in the real app.**~~ Done 2026-08-08, in Debug and then in
      Release. It found the two-bar defect on the Summary tab that §2.10's fourth commit fixed —
      which the widget tests could not have, because a bounded pane inside a page that also scrolls
      is a composition none of them mounted. The parts grid's frozen part number and the production
      plan's pane were both looked at and stand.
- [x] ~~**The v14 → v15 migration on the real database.**~~ Ran 2026-08-10; verified on a copy
      2026-08-11. Two rules carried, not the three predicted — a consequence of §3.1's own rule
      rather than a defect.
- [x] ~~**Give `FIFO CEU27` a capacity** and re-run.~~ Set to **2**, run twice — `7f541565` and
      `676fb0e3`, against `5bf76ac1` as the uncapped v15 baseline. **Blocked time appeared exactly
      where it should and nowhere else: TTAT 216.4 d, every other station 0.0 d.** TTAT is the
      station immediately behind the capped lane, and nothing propagated past it because
      `FIFO TTAT` above it is uncapped. **Utilization stayed at 20 %**, which is §3.1's requirement
      observed rather than asserted.
- [x] ~~**Name CEU27 the pacemaker.**~~ Done 2026-08-11 in Release `0.1.0-2026-08-11`, run
      `2f4c8db4`, together with a 30-day buffer. **`laneFull = 7`** — the first time
      `EmptySlotReason.laneFull` has been observed outside a test, and §18.5's *no material* versus
      *nowhere to put it* is now a distinction the app has actually drawn. `awaitingMaterial` went
      6 → 8.
- [x] ~~**A start buffer.**~~ 30 days, and it behaved as predicted: it moves the dates and leaves
      the lead times alone, because a uniform shift of every release cannot change
      `delivered − released`.
- [x] ~~**Set TTAT to two units.**~~ Set, and it is in the file.
- [x] ~~**And the WIP fell, once the gate was on the capped lane.**~~ Against `676fb0e3`:

      | | `676fb0e3` capped only | `2f4c8db4` capped + gated |
      |---|---|---|
      | avg lead time | 47.2 d | **31.1 d** |
      | TTAT blocked | 216.4 d | **4.6 d** |
      | empty slots | 6 material | 8 material + **7 lane-full** |

      This is what the round was for, and it corrects an assumption the list was built on: **the
      capacity does nothing to WIP until the gate is on the capped lane.** Capping alone moved the
      queue out of the lane and onto TTAT (216 d of blocking) without removing it, because release
      runs on the takt and only the pace setter's lane gates it (§3.1). Gating it stopped the line
      being stuffed: blocking nearly vanished and 16 days came out of the average order.
- [x] ~~**Drive the v15 → v16 migration against the real database.**~~ Done 2026-08-15 under label
      `0.1.0-2026-08-15`, against a copy first and then the file itself; the header has the
      evidence and `test/data/live_db_check_test.dart` is the check, now version-independent.
- [x] ~~**Rebuild Release and drive the v11 → v12 migration against the real database.**~~ Both done
      2026-08-05 under label `0.1.0-2026-08-05`; verified 2026-08-06 by inspecting the live file
      rather than trusting `user_version`. Evidence in the header and §2.0.
- [x] ~~**§11.1's tail warning.**~~ Built 2026-08-11 as schema **v16** — one nullable column,
      `simulation_runs.schedule_horizon`, written up as §16.17 and §11.1. **The migration met the
      real database on 2026-08-15** and the column is there on all 35 stored runs, all null. What
      has never happened is a run *writing* one; that check stayed in the plan.

---

## 5. Rounds one to four, 2026-08-15 — moved out of the plan

_Moved here 2026-08-29, closing the last item in `docs/TODO.md`'s §0._ These four rounds landed
on 2026-08-15 and were recorded nowhere else, which is why they sat in `TODO.md` in defiance of
its own contract that it holds **only unstarted work**. Until they moved, that file was carrying
two jobs and neither file could be trusted to answer *what already happened*.

**Verbatim, and their numbering is `TODO.md`'s rather than this file's.** They are demoted one
heading level to nest here and are otherwise untouched — so §1.7, §2.7, §3.6 and the rest still
resolve for the entries elsewhere that name them, and §10's known gaps still point at §1.7's node
notes and §2.7's "nothing in the suite renders a pixel". That is this file's standing rule: the
reasoning stays as it was written, including where it was wrong and the note saying so.

**They came out of driving the build, and they were about the map rather than the engine.** The
pull was towards using FlowMap as a thing you draw a value stream in and read numbers off — so the
work is the process box's fields, the figures under the map, how fast the input tables can be
typed into, and where the simulation lives now that it is no longer the point of every screen.
Settled by interview on 2026-08-15 before any of it was written.

**Round one invalidated every stored run.** Availability came off setup and cold start started
paying one, so no figure recorded above it is comparable with anything measured after. That was
the third such change, after §2.12 and §3.1 — and the reason `TODO.md`'s §0 comes before the round
that follows it.

---

### 1. Schema v17, and what a changeover is — round one

The schema lands once and the rest sits on top of it (§2.0). One migration carries all of it.

**Every stored run is invalidated by §1.2 and §1.3.** Re-run célula 11B before reading any figure
against anything, and do it after §0 rather than before.

#### 1.1 Setup and teardown replace changeover

*"Replace in the process step the changeover to setup time, and charge % of the setup considered
when the previous order was the same."*

One field becomes three, and **§7.6's standing rejection is answered rather than overridden**. That
rejection was of *"a separate batch-independent setup component alongside changeover"*, on the
grounds that it adds a second time field per step **and a rule for how setup and changeover
interact**. This design has no such rule: setup and teardown are two halves of one changeover,
charged together, governed by one test and one percentage.

- **Setup** — rigging the station for the order. Value + unit.
- **Teardown** — stripping it afterwards. Value + unit. **Named `Teardown`, not `Breakdown`**,
  deliberately: in a plant "breakdown" means the machine failed, and §4.4's Availability *is* the
  breakdown-maintenance figure and is drawn on the same process box. Two fields on one box, one
  meaning failure and one meaning strip-down, both called breakdown-something, is a wrong number
  waiting to happen. es `Desmontaje`, pt `Desmontagem` — the pairing the floor already says.
- **Same part %** — how much of the changeover is still paid when the previous order was the same
  part. **Default 0 %, which reproduces today's behaviour exactly**, so nothing changes until
  something is changed and no stored study shifts under its user.

**Teardown is charged with the next setup, not at the end of the order.** Setup looks backwards and
the engine already knows what it needs — `_Server.lastPartId`. Teardown looks *forwards*, and at the
moment an order finishes the engine has not yet picked the next one. So the server **remembers the
teardown it owes** and pays `teardown + setup` as one changeover when the next order arrives, which
is what a changeover physically is. One rule, one percentage, no clairvoyance:

```
charge = previous part == this part ? (teardown_owed + setup) × samePart%
                                    : (teardown_owed + setup)
```

**The last order at a station never pays its teardown**, and that is correct rather than an
omission: nothing waits on it, so it changes no figure that anyone reads.

**Stored per flow step, three columns on `flow_nodes`.** Per step rather than per workcenter for
§6.1.1's reason — it is this line's use of the station, and a duplicated study must be re-tunable
without disturbing the original — and because §1.3 already learned that a setting on a station
shared by two studies is one nobody can reason about locally.

_Rejected: teardown charged after every order regardless of what follows._ Right if the time were
really a clean-out that happens whatever comes next, and it needs no pending state on the server.
But it makes teardown not the opposite of setup: setup would be free on a repeat while teardown was
not, and ten identical orders would pay ten teardowns.
_Rejected: a second percentage for teardown._ More faithful — a strip-down and a rig-up need not
survive a repeat by the same fraction — but the two are always charged together under one rule, so
two percentages nobody has figures for would always move as one.

#### 1.2 `days` means a productive day, and availability comes off setup

The unit picker is where this gets a trap in it. `engine.dart:812` charges
`changeover × (1 / availability)` — availability derates setup as well as process time, deliberately,
*"which is what makes this the same arithmetic as the Summary's occupation seen from the other end
(§8.4)."* And §6.1 requires availability be applied **exactly once**, since *"derating the open
hours as well would count the loss twice."*

Meanwhile the dialog two fields above will already contain a `days`: Process Specific Takt's, which
means that station's **productive** day (§6.1.1). Two meanings of `days` in one dialog is §17.4's
scar — *"one kind of day per screen"* — arriving in the one place it has never been.

So: **`days` in Setup and Teardown means the same productive day it means in Process Specific
Takt**, and the `× 1/availability` **comes off setup**. One kind of day in the dialog, one
application of the loss.

```
ABC, 3 shifts, 74 %  → productive day = 16.77 h
  Setup 1 day  = 16.77 h      Setup 90 min = 90 min  (was 121.6)
```

**The cost is real and visible: every stored run's figures move.** A release-note line, and §0's
verification has to be finished before this lands or it cannot be finished at all.

_Rejected: `days` means the station's open day, derate kept._ No engine change and no stored run
moves. But Setup's day (22:40) and Process Specific Takt's day (16:46) would sit two fields apart
meaning different things, which is the defect §17.4 exists to record.
_Rejected: `days` is a literal 24 h._ No day to define and no derate question — but two days of
setup on a one-shift station becomes six working days of occupancy, and §6.1 already ruled that
`1 day = 24 h calendar` makes a figure say nothing about capacity.

#### 1.3 Cold start pays a setup

`engine.dart:796` returns zero when `lastPartId` is null, on the reading that the plant is handed
over already set for what it is about to run. An empty station at the start of a run is set up for
nothing, so **the first order pays in full** — and the rule collapses to one sentence with no
special case: *no previous order counts as not the same part.*

One extra setup per station per run, so runs get marginally longer. On the same commit as §1.2, so
it is one re-run rather than two.

#### 1.4 The run records the changeover it charged

`simulation_run_steps` stores `changeoverIncurred`, a **bool**, and §2.7 already recorded that as a
limitation: *"the engine folds the setup into `occupancy` and never records it, so a reader
measuring that prefix against the axis would be measuring an invention."* Under §1.1 the bool gets
weaker still — a repeat charged at 30 % is neither incurred nor not incurred.

**One nullable `changeover_seconds`**, written with what was actually charged; `incurred` becomes
`> 0`. The Gantt's hover card then states a figure rather than a yes, a partial charge is legible,
and the changeover stroke gains a true width if it is ever wanted. Null on all existing runs, which
means *made before this column existed* — the meaning a blank has had on these tables since v12.

Without it, the one place a user could check that the new setup / teardown / percentage rule did
what they meant is the run, and the run could not tell them. That is §1.5 and §2.3's
stored-by-someone-read-by-nobody defect arriving from the other direction.

_Rejected: separate setup and teardown columns._ The two are always charged together under one rule
and one percentage, so they would sit in fixed proportion — two columns that can never disagree are
one column and a multiplication.

#### 1.5 The run carries its studies' cell and line

§4.4's combined view filters by cell and production line, and **the run cannot answer that today**.
`Studies` carries `productionCellId` and `productionLineId`; `SimulationRunStudies` copies neither,
and §7.10 forbids joining to the live study.

**Four nullable columns on `simulation_run_studies`** — cell id and name, line id and name — copied
in at save time, exactly as v12 copied `customer_project` and v13 `part_description`. Blank on all
35 existing runs. Purely additive with no `TableMigration` trap: nothing rebuilds that table.

**Worth knowing before it is built: a cell or line filter is a *study* filter one level up.**
Workcenters belong to a **plant**, not to a cell or a line, so stations cannot be filtered that way
at all. The filter narrows which studies are in view, and the stations follow from them.

#### 1.6 The migration, and what it needs

Schema **v17**, one migration, written up as §16.18:

| Table | Columns |
|---|---|
| `flow_nodes` | setup value + unit, teardown value + unit, same-part % — all nullable |
| `simulation_run_steps` | `changeover_seconds`, nullable |
| `simulation_run_studies` | cell id + name, line id + name — all nullable |

- A **v16 → v17 fixture** in `test/data/migration_test.dart`, with the stored changeover populated
  so the step proves it survives — §2.1's lesson, that a fixture full of nulls passes whether or not
  the table was rebuilt.
- The half-upgraded-database path from §16.11 re-checked.
- `_ensureColumn` asks whether the table exists first (§3.1's finding) — every column here lands on
  a table that predates it, but the v13 fixture is the case that broke last time.
- `duplicateStudy` must copy the three new node fields. §2.6b found it silently dropping
  `batch_number` and had been since §1.4 added it; the same test shape catches this.
- **The live check before it meets real data**: `test/data/live_db_check_test.dart`, by hand, with
  `--tags live` and `FLOWMAP_LIVE_DB` pointing at a **copy**. It asserts `db.schemaVersion` rather
  than a literal, so it survives its own migration; add v17's specific claims to it rather than
  replacing v16's.

#### 1.7 Drive it — **done 2026-08-15**

Landed in two commits, driven in Release `0.1.0-2026-08-15c`. 676 tests, `flutter analyze` clean.

**The v16 → v17 migration has met the real database** — `db.open schema 17 from 16` at 11:53:44
under that label. Driven against a **copy first**: the copy was upgraded by
`test/data/live_db_check_test.dart` with `--tags live` before Release was allowed near the file, and
a backup was taken beside the live one as `flowmap.sqlite.backup-v16-20260815-115254`.
`user_version` 17, `integrity_check` ok, 60 orders and 37 runs intact. The live check now carries
v17's claims alongside v16's rather than replacing them, which is what that file is for.

**No node on this database has ever had a changeover typed into it** — all 17 are zero — and that
turned the re-run into a sharp test rather than a formality. With nothing to charge, both of v17's
behaviour changes multiply zero: the derate removal turns `0 ÷ 0.74` into `0`, and cold start pays a
setup in full, in full being nothing. So the re-run should have been **bit-identical** to the last
v16 run, and it was:

| | `a17b77ed` v17 | `ab587589` v16 |
|---|---|---|
| avg lead time | 34.1 d | 34.1 d |
| delivered / on time | 60 / 60 | 60 / 60 |
| blocked | 0.0 d | 0.0 d |
| empty slots | 13 | 13 |

Compared row by row rather than on the headline: **all 420 steps and all 60 orders are identical**,
including every timestamp. That is §1.1's "default 0 % reproduces today's behaviour exactly"
observed on real data instead of asserted in a fixture.

**So the claim that v17 invalidates every stored run needs qualifying, and this is where it is
qualified.** It is true of the arithmetic and the design notes are right to say so — a 90-minute
setup at 74 % moved from 121.6 minutes to 90. It is **not** true of *this* database, where the
arithmetic that changed only ever multiplied zero. Célula 11B's figures stay comparable across v17,
and the first run that will not be comparable is the first run made after a setup is typed — which
is §2.1's work.

**`changeover_seconds` is written, and null still means what it means.** The v17 run states `0` on
every step; the 35 runs before it read null. That distinction is the whole reason §1.4 stored a
number rather than deriving one, and it is now visible in the file rather than only in a test.

_Still owed from this round:_ the Summary read against the run. It could not be checked here for the
same reason the re-run was identical — with no changeover anywhere, §8.4's changeover term is zero
on both sides, so the two agree trivially. **It becomes a real check the moment a setup is typed**,
which is §2.7's drive step.

#### 1.7b Drive it — the original list

- Re-run célula 11B and record the run id here. Every figure in `HISTORY.md` is now stale.
- Give one step a setup and a teardown, run, and read `changeover_seconds` back through the hover
  card. Then set the same-part % to 100 and confirm batching stops buying anything — that is the
  cheapest proof the rule is wired the way it reads.
- Check the Summary's occupation against the run: §1.2 removed a derate, so occupation and
  utilization should have moved *together*, and a disagreement means the two ends of §8.4's
  arithmetic have come apart.
- The v16 → v17 migration against the real database, against a **copy first**. Take a backup beside
  the live file and name it here.

**DESIGN.md this round:** **§4.4** (availability applied once, and to what), **§5.4** (the process
box's fields), **§7.6** (rewritten — setup, teardown, the same-part rule, cold start), **§7.10**
(what a run stores), **§8.6** (the hover card states a figure), **§16.18** (schema v17, new).

---

### 2. The flow surface — round two

Nothing here touches the engine or the schema. It is what is under the map and what is typed into a
box.

#### 2.1 The step dialog

Field order, as asked, with the changeover pair grouped:

```
Workcenter / pool   [ CEU27          ▾ ]
Label               [                  ]
Process takt        [ 1    ][ days   ▾ ]
─ Changeover ──────────────────────────
  Setup             [ 90   ][ min    ▾ ]
  Teardown          [ 30   ][ min    ▾ ]
  Same part         [ 0    ] %
    ↳ 0 % — a repeat pays no changeover
Notes               [                  ]
```

**The percentage appears only once setup or teardown is non-zero.** That is what "optional for the
user" buys: a step with no changeover shows five fields, as it does today, and the dialog already
scrolls on the app's 700 px minimum height. Helper text states the rule in one sentence, and the
`days` note from §6.1.1 now covers three fields rather than one.

**Target moves to the top and Label follows it**, which is the order asked for and also the order
they are read in — what this step *is*, then what it is called, then what it costs.

#### 2.2 Working days and running days

*"Lead Time Running Days and Lead Time Working Days values are wrong. Lead Time (running days) =
1.4 × Lead Time (working days)."*

**The defect is real but it is not arithmetic — it is that the two figures are computed by
different methods and only one of them is a day.**

- `Lead time` (`flow_view.dart:518`) is Σ of each node's **ladder days**, where a day is that
  station's *productive* day (§6.1) — 16.77 h at ABC three shifts / 74 %, ~7 h at a one-shift
  station — then divided by a **derived** divisor chosen to make the total agree with the rungs
  above it (§17.4). Six of those is not six days on anyone's calendar.
- `N running days` (`flow_view.dart:660`) is a real calendar walk, inclusive of both ends, weekends
  and closed time included (§17.2).

The 1.4 is **7 ÷ 5**. It is what you get when "working days" means *days the plant was open* and the
plant runs a five-day week — which is what a planner means and is not what the number is.

**So working days becomes a second reading of the same walk.** Both figures come out of
`_walkCalendar`: running days is every day it spans; working days is only the days the plant was
open. The 1.4 then **falls out** of a five-day week rather than being imposed, and reads 1.0 on a
seven-day plant and higher across a shutdown — all of which a fixed factor gets wrong.

**A day is a working day when at least one workcenter the flow uses is open on it.** The union, not
a representative station: it reads as *a day the line could make progress*, it needs no station to
be nominated, and it is stable when a step is re-bound. A Saturday one station works counts; a
Sunday nobody works does not.

Two consequences worth stating rather than discovering:

- **A flow containing one seven-day station reports running ≈ working**, and the two figures
  converge. That is true, and it will look like the feature is broken until somebody reads this
  paragraph.
- **The walk starts at the first day of the viewed period** (§17.2), which may itself be closed. It
  counts as a running day always — the count is inclusive of both ends — and as a working day only
  if the union is open on it.

_Rejected: imposing running = 1.4 × working._ §17.2 already says the gap between the figures *is*
the closed time, *"which no ratio could produce"* — and a factor would make a holiday shutdown
invisible in the one figure whose whole job is to show elapsed reality.

#### 2.3 The summary bar carries seven figures

```
Takt   Process time   Lead time   Working days   Running days        Equivalent   PCE
3 d    6.0 d          9.0 d       8 d            11 d · Aug 13, 2026  1.13         67 %
```

- **The ladder `Lead time` stays**, which is one more than the list asked for and is the right
  answer: PCE is `process ÷ lead` computed off the ladder, and without its denominator on screen a
  reader dividing the two visible day-counts gets a different number from the one printed beside
  them. `6.0 ÷ 9.0 = 67 %` stays checkable, and §17.4's rule — the footer is the sum of the rungs
  drawn above it — survives intact.
- **Only the ladder figure keeps the name `Lead time`.** The two walk figures are named by their
  unit alone: `Working days`, `Running days`. Three chips prefixed *Lead time* would differ only in
  the part that gets clipped on a bar that scrolls. es and pt already ship the idiom — `días
  corridos` / `dias corridos` — so it is `Días hábiles` / `Dias úteis` beside them.
- **The end date rides on `Running days`**, which is how it is drawn today (`11 running days · Aug
  13, 2026`). Nothing is lost and no chip is added for it.
- **`Equivalent` is unchanged** and is already hidden under Flow equivalent — see §0's last check.

#### 2.4 `Timeline` becomes `Part`

`app_en.arb:411` has `"flowDataSource": "Timeline"`, which labels the picker choosing between the
flow equivalent, one part, and all variants weighted by the demand mix. It is simply the wrong word
and always has been.

**`Part` is the accurate one, not a convenient approximation.** §6.1 defines the flow equivalent as
*"a **dummy part** whose process time at each step equals one takt of that workcenter's own
capacity"* — so all three options are parts: one real, one synthetic, one weighted blend. Three
languages, one key.

#### 2.5 The help text comes down

Field feedback, 2026-08-15: *"dial back with the explaining text for each feature. It's too much,
when needed add a mouse hover tooltip instead."*

**The app already has two conventions and this unifies them.** `_Metric` in the flow footer wraps
its whole chip in a bare `Tooltip` with no visual affordance; form fields carry always-visible
`helperText` with `helperMaxLines: 2–3`. There are **18 `helperText` sites** against **74 `*Help`
strings** in the ARB, so most help is already hover-only — it is the dialogs that are heavy, and
`flow_node_editor.dart` alone has **8**. §2.1 was about to add three more fields to that exact
dialog, which is why this lands in the same round rather than after it.

**Split by what the text does, rather than moving all of it:**

- **Help that restates its label is deleted, not moved.** It was never earning the space, and moving
  it to a tooltip only hides the fact.
- **Help that carries a definition a wrong answer depends on keeps an affordance** — a small info
  icon beside the field, tooltip on hover. That is: what `days` means on a step (§6.1.1's productive
  day, and §17.4 is the scar that makes it non-optional), what the same-part percentage does, that a
  lane's rule is shared across every study in the project.

_Rejected: all of it to bare tooltips, matching `_Metric`._ One convention everywhere and maximum
quiet — but with no affordance nobody hovers, so the definitions would be gone rather than moved,
and `days` would be discoverable only by accident.
_Rejected: deleting the lot._ It forces every label to stand alone, which is a real discipline. But
a label cannot make `days` unambiguous, and §17.4 records what that costs.

**Sweep the whole tree in one commit**, not field-by-field as each dialog is touched: the point is a
consistent amount of noise, and a half-swept app is louder than either end state.

#### 2.6 The date format becomes a dropdown

Field feedback, same session. `settings_screen.dart:79` renders four `RadioListTile`s, each with the
format as its title and today's date in that format as its subtitle — which is most of the screen for
one setting with four values.

**A `DropdownButtonFormField`, with the sample carried into each item** — `DD/MM/YYYY —
15/08/2026` — so the preview that made the radio list worth reading survives the collapse, including
in the closed state where it describes the current choice. `settingsDateFormatHelp` becomes an
info-icon tooltip under §2.5's rule: it defines what `Locale` means, which the label does not.

#### 2.7 Drive it

The bar, in all three languages, against a real flow: that `Working days` is below `Running days`
and both are plausible against the map; that a flow crossing a weekend shows the gap; that `Lead
time` still divides into `Process time` to give the PCE printed beside it. The step dialog with and
without a changeover, so the revealed percentage is seen appearing and going away.

**DESIGN.md this round:** **§5.4** (the box's fields, again — the dialog's order), **§6.1**
(what each day means, and which figure uses which), **§17.2** (running days gains its companion),
**§17.4** (amended: the footer sums the rungs *and* states two calendar counts that do not),
**§12.4** (the date setting's control, and a units line if the walk's figures need one), and a new
**§12.7** stating the help convention — deleted where it restates, an info icon where it defines —
so the next dialog does not have to rediscover it.

---

### 3. The input tables — round three

*"The Takt, Workcenters, Demand input table are only editable when opening the edit window, can we
make them editable in the table. Trying to reduce clicks here."*

**Demand is already inline** — both its grids are `DataGrid` — so this is Takt and Workcenters.

**The cost is low, and it is low for a reason already in the repo.** `data_grid.dart`'s opening
comment: *"One text field per cell, keyboard navigation, and multi-cell TSV paste from Excel. Every
column is text, **deliberately**: a dropdown or a date picker in a column would make that column
unpasteable, and pasting a block out of the planner's spreadsheet is the way this data actually
arrives. What a cell means is decided by the parser the caller supplies."* Freezing, scrollbars,
keyboard navigation and per-keystroke validation all already exist. Takt is four text columns and a
parser; workcenter schedules are six.

**And it buys more than it was asked for: paste a block of periods straight out of Excel**, which
cuts more clicks than inline editing does.

#### 3.1 Both tables become grids, and both dialogs go

- A new period is **a blank row appended at the bottom**, the way the sequence grid works. Delete
  stays a row action.
- **The edit dialogs are removed entirely.** Keeping one would leave two write paths into one
  table, which is how the two halves of a rule drift apart.
- **Overlaps and gaps stay non-blocking.** `ScheduleIssuesBanner`, fed by `findSchedulePeriodIssues`,
  is **already on both tabs** — the guard exists and the dialog was duplicating it. §11's readiness
  already blocks Simulate on a real gap, which is the check that matters.
- The `Shifts` column on the workcenter table is derived by counting (§4.2) and stays `readOnly`,
  which `DataGridColumn` already supports.

#### 3.2 What a cell accepts

**Forgiving in, canonical out.** A cell takes anything unambiguous and redisplays it canonically
once committed, so a block pasted from a spreadsheet written in any of the three languages lands and
the table still reads consistently afterwards. Unparseable text stays on screen as an error rather
than being dropped, which is what `DataGrid` already does.

| Column | Accepts | Shows |
|---|---|---|
| Takt unit | `days` `d` `días` `dias` `hours` `h` `horas` `min` `m` `s`, case-insensitive | the unit in the user's language |
| Availability, Rework | `74%` `74` `0.74` | `74 %` |
| Start, End | the user's §3.6 format, and ISO | the user's §3.6 format |
| Operators per shift | the `1/1/1` codec, as now | `1/1/1` |

**§9.2's rule holds: forgiving is not guessing.** Anything genuinely ambiguous is refused and left
on screen as an error, exactly as a bare `batch` column is refused by the import rather than assumed
to be a size.

#### 3.3 Drive it

Paste a block of takt periods out of Excel. Type a date in the wrong format and check the error is
on the cell rather than silent. Create a gap and check the banner says so without blocking. In es
and pt, since the unit parser is the one thing here that is language-shaped.

**DESIGN.md this round:** **§9.1** (the grid is no longer only the demand tables), **§12.5** (two
fewer read-only tables — and the takt table was the one deliberately stretching to fill, so that
paragraph needs revisiting rather than deleting), **§12.6**, and the schedules sections that
currently describe a dialog.

---

### 4. The tabs, and where simulation lives — round four

#### 4.1 Seven study tabs

`Flow · Study Settings · Flow Takt · Workcenters · Demand · Summary · Simulation`

`Takt` becomes `Flow Takt`, `Study Settings` is new (§4.2), and `Simulation` stops being the
project-level tab and becomes this study's slice (§4.3).

#### 4.2 Study Settings

Everything about the study, in one place, and **the `Run settings` dialog goes** — two ways to set
one field is how they come to disagree.

```
─ Identity ──────────────────────────
  Name             Célula 11B
  Cell / Line      Cell 3 / Line B

─ In simulation ─────────────────────
  Include in runs  ■
  Pacemaker        CEU27   (derived: CLAD08)
  Start buffer     30  days
  WIP cap          —          ← first time reachable
  Priority         1          ← first time reachable
```

**`wipCap` and `priority` are reached at last.** Both are stored, both are read by the engine, and
§17.5 has listed them as reachable-from-nothing since M3; §3.3b said outright *"they belong in the
same dialog and were left for the round that needs them."* This is that round, and it closes two
§17.5 entries. §7.3's CONWIP behaviour meets a user for the first time here, so it wants driving
rather than assuming.

It is also the obvious home for §9's map-only flag when that lands.

#### 4.3 The Simulation tab becomes the study's slice

**One run, filtered — never a run of the study alone.** §7.7 builds one resource model of the plant
and lets line A's orders delay line B's, so a solo run is a different and always-optimistic answer
to a differently-worded question. Two runs of one study reporting two lead times, with nothing on
screen saying which is which, is the confusion this avoids.

The tab shows this study's orders, its production plan, its share of the Gantt and its own metrics,
all read out of the same `StoredRun` the combined view reads — so the two cannot disagree about a
number. **It costs no engine work**: `summariseRun` already carries `studyId` on orders, steps and
part metrics.

_Rejected: a `Run this study alone` action alongside._ It answers a real question, but run history
would then hold two kinds of run and every comparison would have to check which kind it was looking
at — a cost M5's run comparison would inherit.

#### 4.4 The simulation workspace

*"Simulation button below the New study button. Opens a new visualization with the combined
simulation results, with filters for the studies, cells, production lines and period."*

**A sidebar destination.** The studies sidebar gains a `Simulation` entry under New study; selecting
it swaps the study workspace for a full-width simulation workspace — filters, metrics, the plan, the
Gantt and a prominent Run button. Deep-linkable through go_router like every other route (§12.1),
because a filtered view and a run's history are both things worth sending someone a link to.

**Simulate stays on the project app bar as well**, same provider and same disabled reason. §12.1's
argument survives: a run spans studies and starting one must not require navigating somewhere first
— which is the complaint §1.8 moved the button to the app bar to fix. Two entry points, one action.

**The filters:**

- **Studies** — free. `studyId` is on orders, steps, lanes and part metrics already.
- **Cell, Production line** — needs §1.5's four columns. A study filter one level up, since
  workcenters belong to a plant rather than to a cell or line.
- **Period** — filters **orders**, by **need date**.

**Why need date.** It is the only one of the three candidate dates that is never null, so an order
the run never completed still appears in its period instead of vanishing — and §7.8's abort case,
*"N orders never completed"*, is exactly what a planner filters to find. It is also the date OTD and
float are already defined against, so the filter and the metrics agree by construction. Filtering by
`delivered` would drop every failure and make the filtered view systematically optimistic in the
runs most worth looking at.

**Station utilisation does not follow the period filter, and the card says so.** The denominator is
`openSeconds`, stored as a run total, and rebuilding open time for a sub-window needs each station's
calendar — which §7.10 deliberately does not store, and which is the exact cost that got §3.5
dropped in round two. Order-level figures recompute cleanly because every order carries its own
dates; utilisation and blocked time keep reporting the whole run, labelled.

```
Period  2026-Q3        Studies ▾2   Cell ▾all

  Orders            18 of 60      ← filtered
  On time           44 %          ← filtered
  Avg lead time     31.1 d        ← filtered
  ─────────────────────────────────────────
  CEU27  util 86 %  blocked 4.6 d  ⚠ whole run
```

_Left open, and the day it is wanted is the day §3.5 comes back:_ snapshotting each station's shift
pattern, staffing and exceptions into the run would make utilisation follow the filter honestly —
and would make closed-time shading on the Gantt possible at the same time. §3.5 records the design
in full; only the wanting was ever missing.

#### 4.5 The Gantt filters its rows

Field feedback, 2026-08-15: *"a filter for the Gantt chart so the user can select to only show
workcenter or workcenters + inventory."*

§3.4 gives célula 11B **14 rows** — seven stations interleaved with seven lanes — and the lane rows
are exactly what is in the way when the chart is being read as a flow rather than as a queue.

**A two-state toggle beside the zoom cluster**: `Stations` / `Stations + lanes`, defaulting to both,
so today's chart is unchanged until something is changed. Held in the view's state the way zoom is —
it survives switching to Results and back, and resets on restart, which is what a view control
should do rather than a stored preference.

**One parameter to `buildGanttChart`**, so `barAt`, the hover card and the floored-bar count all
follow for free. That is the whole argument for `gantt_layout.dart` being pure and widget-free
(§2.7) arriving a third time — nothing in the view decides a position, so nothing in the view has to
learn about a hidden row.

It applies in both the study tab's Gantt and §4.4's workspace, since they are the same widget.

_Rejected: a per-row filter menu with a checkbox per station and lane._ It answers this and also
"just show me CEU27 and TTAT", which is the question a forty-station plant asks. More UI than the ask,
and it needs a way to state what is currently hidden or a reader misreads a chart with rows silently
missing. Worth revisiting at §14 scale.
_Rejected: remembering the toggle across sessions._ §3.6's `app_settings` makes it nearly free, but a
stored setting that silently hides rows is a chart lying to whoever opens the app next.

#### 4.6 Drive it

The workspace screen **has no test coverage at all** (§3.7), and this round rebuilds it — so
everything here is only covered by pressing it. Specifically: that the study tab's figures equal the
combined view's for the same study; that a period filter changes the order counts and leaves
utilisation labelled and whole; that a cell filter on a pre-v17 run shows blanks rather than
dropping every study; that Simulate works from both places and reports the same disabled reason.

**DESIGN.md this round:** **§8.6** (the Gantt's row filter), **§12.1** (rewritten — seven tabs, the sidebar destination, two triggers
for one run), **§7.3** and **§7.7** (the cap and the priority are reachable, and what a study's
slice is), **§7.10** (the cell and line the run carries), **§10.1**, **§17.5** (two entries closed).


## 6. Version 2.0, 2026-08-30

The plan is `docs/TODO.md`; the reasoning behind each phase is its wayfinder ticket, and neither is
repeated here. This section is what the migrations **met when they ran**, which is what this file is
for.

### 6.1 Schema v27 — a queue is an aspect of its target

Landed `19813d6`. `project_queues.name` and `flow_nodes.label` dropped; the caption is derived as
`<type> · <target>`. Ticket [#5](https://github.com/matheus-sancha/FlowMap/issues/5), reasoning in
`DESIGN.md`.

**Met a copy of the real database on 2026-08-30**: upgraded to v27, `integrity_check` ok, both
columns gone, **15 queues and 25 steps survived** with 250 orders, 147 runs and 189,623 step rows
untouched. Seven of the fifteen queues are untyped — exactly the seven the ticket predicted — and
every caption derives, including `FIFO · CLAD Pool - Célula 11B/C`, the pool whose own name contains
a hyphen and is why the separator is a middot. Backed up first as
`flowmap.sqlite.backup-v26-20260830-171232`.

**And the live file itself**: `db.open schema 27 from 27` at **21:20:45 under `0.1.0-2026-08-30a`**,
the migration having run at 17:14 in the session before it.

**Driven the same evening** — `DRIVE-queue.md`, the process boxes, which no test in the suite
renders. Two things it established that the 997 tests could not. A run stored from v27 on writes
**no lane caption**: run `e0d93a45` at 21:26 carries `name` NULL on all 15 lanes, so the caption
re-derives in the reader's language rather than being frozen in whoever ran it — the ticket had
asked for it to be written in, and the commit stored null instead. And **the 147 runs stored before
it keep the caption they were saved with**, so their Gantts read `FIFO BAN` and `FIFO CLAD` against a
map now reading `Queue · BAN11` and `FIFO · CLAD Pool - Célula 11B/C`. That is §7.10 working as
written and it stands; it is recorded because nothing on screen explains it.

The drive also found what §16.24's last paragraph describes: an untyped lane was being stored as
FIFO. Fixed in v28 rather than here, since v28 was already rewriting the comparator the default
belongs in.

### 6.2 Schema v28 — study priority goes

Study priority dropped, and `simulation_run_studies.priority` with it; the vacated slot in the
dispatch fall-through refilled with the **need date**. Ticket
[#6](https://github.com/matheus-sancha/FlowMap/issues/6), reasoning in `DESIGN.md` §16.24.

**Runs created before 2026-08-30 break cross-study ties by UUID; runs created after it break them by
need date.** Nothing is stamped on the run to say which side of the line it falls on — a run already
carries `created_at` — so this line is the record.

**The ticket predicted a re-run would not match, and the measurement says otherwise.** Re-running
today's input under the new fall-through and diffing against `e0d93a45`, the newest stored run and
the last one made under the old one: **1,871 steps on both sides, zero input drift, and not one step
starting at a different second.** The two figures are both true and they answer different questions.
*27 of 78 ties were being settled by comparing two UUIDs* is a fact about how a run was **explained**
— unanswerable a third of the time, which is why the slot was refilled. *How many orders actually
move* is a different count, and it is small: across all 148 stored runs there are **80 cross-study
arrival ties, 61 of them still resolvable** — the other 19 name orders since deleted — **and the need
date reorders 4 of the 61.** `e0d93a45` has two such ties and the need date agrees with the old key
on both, so it re-runs identically.

So the comparability worry is much smaller than the phase assumed: the change is a legibility fix
that is very nearly invisible in output. It is still not zero, and this line still says which side of
it a run falls on.

*The check that produced this had a defect worth recording.* Its first version compared the two
moments directly and reported **1,862 of 1,871 steps moved** — every one by a fraction,
`21:33:21.000` against `21:33:21.428571`. That is `simulation_run_steps` storing whole seconds
meeting an in-memory `DateTime`, not the comparator. Comparing at the resolution the run was stored
at turns 1,862 false differences into zero real ones. `live_tiebreak_check_test.dart` carries it.

`SimQueue.rule` became nullable in the same step, with the FIFO default moved to where the engine
sorts. A run stored from here on keeps the difference between a lane someone typed FIFO on and one
nobody typed anything on.

**Met a copy of the real database on 2026-08-30**: upgraded to v28, `integrity_check` ok, both
priority columns gone, and **3 studies, 327 stored study rows, 148 runs, 191,494 run steps, 250
orders and 15 queues** all intact. Backed up first as `flowmap.sqlite.backup-v27-20260830-213823`.

*The drop is a provable no-op on every run ever stored*: all 3 studies and all 327 stored study rows
sat at the default 100, so nothing that was ever run had priority doing anything.

**And the live file itself the same evening**: `db.open schema 28 from 27` at **21:47:48 under
`0.1.0-2026-08-30b`**, the build label and the line both in `log.txt`. `integrity_check` ok
afterwards, and 3 studies / 327 stored study rows / 148 runs / 191,494 run steps / 250 orders / 15
queues all still there. **`v28.dropped` appears zero times in the log**, which is the evidence the
step was designed to produce: it logs only a priority someone actually set, so an empty result is the
migration confirming on the real file what the copy predicted.

One assertion was written for this check and **removed after it failed correctly**: *lanes with a
null rule belong only to runs newer than the fix*. 37 of the 148 runs here already carry null lane
rules, from before the column was written at all — null means both *unset* and *never recorded*
across generations, so it cannot be a sentinel for the newer one. The claim is about the moment a run
is stored, which this file never sees; it lives in `run_storage_test.dart` instead. That is the trap
at the top of `live_db_check_test.dart` arriving a third time.

### 6.3 Schema v29 — the Occupation view becomes a grid

The stacked bar, its capacity line, its four-segment legend and its
`CustomPainter` are deleted; the view is a station × month grid banded against
two thresholds the project now carries. Ticket
[#9](https://github.com/matheus-sancha/FlowMap/issues/9), reasoning in
`DESIGN.md` §10.3.

**Met a copy of the real database on 2026-08-30**: upgraded to v29,
`integrity_check` ok, the one project holding **85 / 100** with its float
thresholds beside it untouched at 0 / 30, and **3 studies, 150 runs, 195,236 run
steps, 250 orders and 15 queues** all intact. Backed up first as
`flowmap.sqlite.backup-v28-…`.

**One of #9's figures has moved, and the argument survives it.** The ticket said
**3 of 147** stored runs could draw this view at all; it is now **6 of 150** —
every run made since v25 can, and three were made while v2.0 was being built.
The claim it supports is unchanged: the grid reads
`simulation_run_workcenter_months`, a v25 table, so 144 runs still say nothing
here and §10.2 refuses to invent capacity from today's schedules. A run that
cannot draw the grid could not draw the chart either. `live_db_check_test.dart`
now prints this count rather than asserting it, because it only grows.

**No stored run is invalidated and none changes.** v29 adds two columns to
`projects` and touches nothing a run holds.

**`OccupationRamp` is retired from `tokens.dart`** with the stack it coloured.
It was the app's only *ordered* colour quantity; nothing else draws one, and
§17.5's own lesson — unreachable code with a plausible future consumer is a
loaded slot rather than inert — is why it is deleted rather than kept.

---

## 7. The surface captions removed, 2026-09-07

Ticket [#15](https://github.com/matheus-sancha/FlowMap/issues/15), rule in
`DESIGN.md` §12.7b. **A deleted explanation is the kind of thing someone re-adds
a year later**, so what went and why is written down here rather than left to a
diff.

**The rule existed and the complaint came back anyway.** §12.7 answered the same
field words on 2026-08-15 and held — one `helperText` left in the tree, nineteen
`ⓘ`. What it never covered was a *surface's* standing prose, and that is what
*"too much explanation and random text"* was pointing at on 2026-08-31.

**Deleted outright, as restatement:**

| String | Said | Why it went |
|---|---|---|
| `workcenterTypeIconHelp` | Workcenters of this type are drawn with it | Picking an icon visibly draws it |
| first sentence of `simGanttGapHelp` | One row per station, one bar per order… | Describes the picture below it |
| first sentence of `simProductionPlanHelp` | What this run says each order does | Restates the tab |
| last sentence of `mm3Help` | Reorder on the Sequence tab and watch it flatten | You can watch it flatten |
| `workcenterAddExistingHelp` | A workcenter belongs to the plant… | The same claim as `workcenterLinesHelp`, differently worded; they share one key now |

**Moved behind an `ⓘ` beside the name of the thing it explains**, unchanged in
substance: `simRankingsHelp`, `simProductionPlanHelp`, `simGanttGapHelp` and
`floatMatrixHelp` onto the four results tab labels; `exceptionsHelp` and
`exceptionsScope` onto their headings; `workcenterLinesHelp`,
`projectSettingsFloatHelp` and `occupationBands` onto theirs;
`resourcesUnassignedHelp` and `studyIncludeInRunsHelp` onto their tile titles;
`inventoryWaitHelp` onto its own field, which is §12.7's `days` case and the
reason that rule refuses to delete this class of text.

**Given a name it never had.** The two Occupation thresholds had no heading, so
`occupationBands` was introducing itself. `occupationBandsTitle` is new in three
locales and the paragraph sits behind it.

**Kept, and moved to where it is live.** *Paste a block from Excel with Ctrl+V*
was inside two captions. It is one key, `demandPasteHint`, shown above either
Demand grid **only while that grid is empty**. Pasting a block across rows and
columns is not what every grid does and nobody tries it unprompted — deleting it
would have lost how the app is actually filled.

**41 ARB keys deleted, in all three locales.** They rendered nowhere: 7 % of the
app's strings. Some were this map's own churn — `flowQueueName`'s neighbours
from [#5](https://github.com/matheus-sancha/FlowMap/issues/5), `occupationCell`
from [#9](https://github.com/matheus-sancha/FlowMap/issues/9),
`simProductionPlan` from [#7](https://github.com/matheus-sancha/FlowMap/issues/7)
— but most predate v2.0: `taktDaysHelp`, `availabilityHelp`, `reworkHelp`,
`mm3SlotLoadHelp`, `workcenterHomeLineHelp`, `scheduleShiftsDerived`,
`confirmArchiveBody`, `floatMatrixTally`, and thirty-odd bare labels.
**`flowQueueName` is deliberately kept**: three tests in
`flow_node_editor_test.dart` assert the *absence* of the field §7.3 removed, and
the key is how they name it.

**Two tests asserted the old placement and now assert the new one.**
`gantt_view_test` asserted *"what a gap means is on screen"*; it asserts the
chart paints none of it, because a caption is the thing that grows back, and
`simulation_tab_test` holds the tab strip to carrying all four definitions.
1,062 tests pass.

**A drive is owed.** Nothing in the suite renders a pixel, so what an `ⓘ` looks
like in a scrollable `TabBar` — and whether four of them crowd a five-tab strip
— has not been seen.

---

## 8. The period slicer and the granularity, 2026-09-07

Ticket [#17](https://github.com/matheus-sancha/FlowMap/issues/17), reasoning in `DESIGN.md` §12.8.

**Three of the ticket's own premises were wrong, and the live database corrected a fourth.**

- *"`semester` is a domain word this codebase has never used."* `PeriodGranularity` has shipped since
  §12.1 with **four** values — month, quarter, semester, year — a semester already defined as a
  calendar half, and `periodMonth` / `periodQuarterly` / `periodSemesterly` / `periodYearly` already
  translated in three locales. The l10n cost the ticket priced was **zero**, and the field asked for
  three values where the app had four.
- *"a year column is a sum the model does not currently produce."* It is a sum over
  `simulation_run_workcenter_months`, which is a **read-side aggregation**. Nothing reaches the
  schema, the engine, or a stored run — so this executed inside the ticket rather than landing as a
  phase, which the ticket had flagged as possible.
- *"the run's span is 15 months on the live database."* 15 is the **capacity** span. Orders span
  **10–13 months, median 12**, across all 149 runs that have any. Both figures are real and they
  measure different things, which is why `runMonths` is their union.

**What re-columning is worth, from real rows.** The widest run: month **15 columns**, quarter **5**,
semester **3**, year **2**. Quarter is the one that reads.

**And what it costs, which is the finding.** Coarsening **hides overload** — the same run's worst
station reads **148.5 %** in a month, **128.2 %** in its quarter, **118.9 %** in its semester and
**101.8 %** in the year. The view exists to find a station asking for more than it has; a wider
column averages a bad March against a quiet April. Month stays the default and the control is a
dropdown, so the coarse values are a deliberate reach.

**The arithmetic is not a rounding argument.** Ratio of sums gives **68.384 %** at every
granularity, as it must. Mean of ratios gives **64.8 / 66.9 / 67.5 / 67.2 %** — wrong by up to
**3.58 points**.

**The float matrix does not follow the control**, and that is the design rather than an omission.
Only surfaces whose cells *sum* can coarsen. The float matrix's rows are ranks within a column, so
by year it becomes one column of 250 rows — the same orders re-poured, with §10.4's warning that
rank 3 in January and rank 3 in April are unrelated orders made worse rather than better.

**A defect caught by writing its test, not by running the app.** Folding capacity to the granularity
*before* applying the date filter drops a period whose first day falls before the range: ask for
February onward while reading quarters and Q1 disappears, taking February and March with it. The
filter stays monthly and the fold happens after it. `a period survives when only part of it is in
range` holds it down.

**The date picker had a defect nobody had reported.** `showDateRangePicker` chose *days* while the
button printed only year and month, so 15 January – 20 February read back as `2026-01 → 2026-02`.
The slicer snaps to whole months and the control now says exactly what it takes. It also makes the
empty period range **unreachable**, so `occupationUngraphable` keeps its one meaning.

**`PeriodGranularity` moved to `common/`** and `flow_view.dart` re-exports it, so its ten existing
importers are untouched. `PeriodMatrix` gained a `columnLabel` callback rather than a granularity:
it has two callers, only one of which coarsens, and §12.5b keeps it from knowing which it is
drawing for.

**Seven tests, 1,069 passing.** They assert the fold both ways, that every granularity preserves the
total hours, that columns never outnumber the months they fold, that the chart and the grid produce
identical column lists at all four granularities, and that `runMonths` is a union. The group builds
its **own** 30-order run: the shared fixture is one month wide, on which every one of these would
pass vacuously — which is how the chart's tests came to say nothing for two commits (#13).

**A drive is owed.** Nothing in the suite renders a pixel, so a `RangeSlider` in a filter bar and a
five-column grid have not been looked at.

---

## 9. The studies pane stops forgetting, 2026-09-07

Ticket [#18](https://github.com/matheus-sancha/FlowMap/issues/18), reasoning in `DESIGN.md` §12.9.
Executed on `v2.0`, **1,081 tests**.

**The reported bug was dissolved rather than fixed.** The pane reopened on a mode switch because
`_sidebarCollapsed` was a `setState` flag on a screen that a route change rebuilds. But the question
underneath was whether Simulation mode should show a *studies* pane at all — and it should not: its
taps navigated **out** of Simulation mode, duplicating a job the results filter bar already does.
Project Settings keeps the pane, because that destination has no mode switch and the pane is its
only way back to a study.

**The collapse moved into `window.json`, beside `maximized`**, and `WindowGeometry.save` had to start
**merging**: the file has two writers now, and the obvious write would have dropped the pane key on
the next window move — a fault reportable only as *"it forgets, sometimes"*. Two of the six new
`window_chrome_test` cases exist for exactly that, one in each direction.

**A second defect, unreported, found under the first.** Simulation mode carries its study in
`?study=` while `selected` read only the path parameter, so crossing into Simulation silently made it
**the first study in the list**. The mode switch navigates back to `selected` — so leaving study B
for the run and switching straight back landed on **study A**, with the correct id in the URL the
whole time. `selectedStudy` is extracted and tested; six cases, no widget tree.

**And the sweep found the cause of two more.** The results tabs are an `IndexedStack`; the study tabs
were a `switch`. So the Occupation view's grouping, unit and granularity have never been lost, while
the VSM map's zoom and pan and Demand's `Parts | Sequence | MM3` reset on every trip to another study
tab. The study strip is an `IndexedStack` too now — at the cost, stated and accepted, of building
the VSM canvas, the demand grid and the summary on every study open.

**Nothing here needed a pixel**, which is what the ticket claimed of itself and the reason it was
worth taking without a drive: a merged file and a three-argument selection are both properties.
The pane's *animation* is the only part that is feel, and it is not what was reported.
