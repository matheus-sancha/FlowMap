# FlowMap — Design

Why the app behaves the way it does. Cited from code by section number, e.g. `(DESIGN.md §6.4)`.
Read before changing behaviour; update in the same commit that changes it.

Status: agreed 2026-08-03 in design interview. No code yet.

---

## 1. What FlowMap is

A Value Stream Mapping builder and production-flow simulator for manufacturing engineers and
planners running load-vs-capacity studies. Local-first Flutter desktop app for Windows, shipped
as a zip drop (see the `flutter-desktop-app` skill; worked example `C:\src\Chronus`).

**Scope of v1: everything.** Builder, static capacity math, and the discrete-event simulation all
ship in the first drop. Consequence: every model decision below had to be settled before build.

### 1.1 Stack

Flutter · Riverpod · Drift/SQLite · go_router · `pdf` · `excel` · `window_manager`.
Feature slices `data → application → presentation`; repositories are the only code touching Drift;
all arithmetic lives in `application/` as pure functions.

---

## 2. Storage and portability

**One local Drift DB** in the app directory holds Resources, Projects, Studies, Templates and
Simulation runs. Sharing is explicit export/import of a project or template to a `.flowmap` file
(zipped JSON), with a conflict-resolution step for resources that already exist by name.

_Rejected: file-per-project documents._ Resources and templates are shared across projects, so a
document model duplicates the resource tree and produces projects referencing resources the
receiving machine lacks — plus dirty-state handling and a file format to migrate separately from
the schema.

---

## 3. Resources ↔ Project seam

Identity lives in **Resources**; period-scoped numbers live in the **Project**.

| Resources (identity) | Project (per-project data) |
|---|---|
| Plant, Production Cell, Production Line, Workcenter (name, type), Workcenter Pool, Shift Pattern | Which shift pattern the plant uses, takt schedule per line, workcenter schedule periods, calendar exceptions |

- Projects reference resources **by stable id**, so renames and type changes propagate everywhere.
- Deletion is **soft (archive)**: the row stays, disappears from pickers, and projects still using
  it show it flagged as archived rather than breaking.
- Each **simulation run additionally snapshots its inputs**, so a completed run stays explainable
  after the resources beneath it change.

_Rejected: copy-on-add into the project._ Self-contained projects can't share workcenter identity,
and cross-study contention (§7.7) requires one identity per physical workcenter.

### 3.1 Workcenter Pool

A named group of real workcenters in one plant, normally of the same type (`CNC Lathes` =
LAT01..LAT04). A flow step targets **either** a specific workcenter **or** a pool. An order sent to
a pool is dispatched to whichever member frees first; ties break by lowest utilisation, then name
(deterministic). Capacity, operators, availability and rework come from each member's own schedule.

Pools are how two production lines genuinely compete for the same capacity.

_Rejected: pool as an N-slot capacity bucket._ Loses per-machine availability/operators and cannot
say which machine ran an order.

---

## 4. Calendar engine

Everything numeric is computed against a working-time calendar. The core seam is a pure function
`advanceWorkingTime(workcenter, from, duration) → DateTime` that skips non-working time; it is
shared by the static occupation math and the simulation, and carries the heaviest test suite in
the app.

### 4.1 Shift patterns

A **Shift Pattern** is a Resources-level entity: name, cycle type (fixed weekly | rotating), an
ordered list of shifts (label, start, end, break duration, crosses-midnight flag), and the base
working weekdays. A project picks one pattern for its plant. `ABC` and `ABCD` ship as **seed data**
and are editable.

_Rejected: hard-coded ABC/ABCD enum._ Shift times change more often than plants do, and the
spec's own ABC example had 2nd and 3rd shift with identical times — a data fix, not a migration.

**A rotating pattern's shifts are time windows, not crews.** `ABCD` describes four crews
rotating through two 12-hour windows. Storing four shift rows would make the pattern worth 48
hours a day. Under a deterministic model (§4.4) which crew is on a given day changes nothing
observable, so `ABCD` seeds as two windows — `Day (A/C)` and `Night (B/D)` — and staffing both
gives exactly 24 hours of continuous coverage.

**The seeded ABC 3rd shift closes the day at 23:40–05:45.** The source specification listed 2nd
and 3rd shift with identical times, which cannot be right; seeding a duplicate window would have
counted the afternoon's capacity twice. The seed completes the 24-hour cycle instead, and is
editable like any other.

### 4.2 Staffing

A workcenter schedule period stores **one operator count per shift** in the plant's pattern
(ABC → `[1,1,1]`, or `[2,1,0]`), in the `1/1/1` notation the shop floor writes. `Shifts: 3` is
*derived* = count of shifts with operators > 0. A 0 means the workcenter is closed for that shift.

**The calendar takes a staffing *schedule*, not a fixed list.** Staffing changes between schedule
periods — three shifts in H1, two in H2 — so `WorkingCalendar` asks a `StaffingSchedule` per day
rather than holding one list. That is what lets a single `advance()` walk across 1 July and spend
the right capacity on each side of it.

_Rejected: a shift-count integer filled from the top._ Cannot express "runs 2nd and 3rd only", and
the count and the operators list can disagree about length.

### 4.3 Calendar exceptions

A project owns a list of exceptions: date or range, type `NON_WORKING` (holiday, shutdown) or
`EXTRA_WORKING` (which shifts, which operator counts), and a **scope** — whole plant | one
production line | one workcenter or pool. Base days come from the pattern; exceptions override,
most-specific scope wins.

Covers "plant closed 24–27 Dec" and "Saturday extra hours on CLAD04 only" — the latter being the
most common capacity lever there is. Rotating 24/7 patterns need no exceptions at all.

### 4.4 Losses: Availability and Rework

```
effective_process_time = process_time × (1 + rework) ÷ availability
```

A 10 h job on a 74 % / 3.7 % workcenter occupies it for 14.0 h of open working time.

**The simulation is deterministic**: same inputs always produce the same output, so two scenarios
differ only by what was changed, and a run is one pass rather than N replications.

_Rejected: stochastic breakdowns and rework._ Needs replication counts, seed management and
confidence intervals on every metric, and makes two runs of the same study disagree — unacceptable
when the output is a headcount decision.

---

## 5. The flow graph

### 5.1 Topology — linear spine

A study is an ordered sequence: `Supplier → [step | inventory]* → Customer`. A step targets a
workcenter or a pool. All demand parts share the step order; a part that skips a step has a blank
process time in that column. Parallelism comes from pools, not branches.

_Rejected: DAG with converging branches._ Forces part-specific routings (the flat demand table
breaks), join synchronisation, and branch-aware lead-time roll-up.
_Rejected: rework loops._ Double-counts against §4.4 and leaves theoretical lead time with no
closed form.

### 5.2 Symbols

- **Semantic** (on the spine, carry data, feed every calculation): Process step, Inventory,
  Supplier, Customer.
- **Decorative** (free-placed annotation, never affects numbers): shipment truck, supermarket,
  kanban post, production-control box, information arrows, kaizen burst, operator icon, text note.

Kanban *rules* live in the study's release settings (§7.3), not in the kanban icon — drawing
documents intent; the number that drives the engine is typed where it can be validated.

### 5.3 Layout

Semantic nodes are **auto-laid-out** left-to-right from their sequence. "Moving" a node means
dragging it to a new position in the order; `+ Insert here` between nodes adds one. Decorative
icons are freely placed at stored x/y.

Sequence is the single source of truth, so the lead-time ladder, the PDF and the calculations can
never disagree with what is drawn.

_Rejected: free placement._ The most common source of wrong VSMs is a node drawn third that is
fourth in the routing.

### 5.4 Process box fields

Nothing on the box is typed except **Changeover**. Everything else is derived:

| Field | Source |
|---|---|
| Process time | selected data source: Flow equivalent \| one part \| all variants weighted by demand mix |
| Availability, Operators, Shifts | that workcenter's project schedule for the displayed period |
| Occupation | required hours ÷ available productive hours for the period |

Hence the period navigator (`Aug 2026`) and the timeline selector in the toolbar. A schedule edit
redraws the map.

### 5.5 Inventory nodes

Two modes:

- **QUANTITY** — N pieces, displayed as days = `N × takt of the current period` (classic VSM "days
  of stock"; re-reads correctly when takt changes).
- **DURATION** — a fixed wait (24 h cooling, 2 days transport) in working or calendar time.

In simulation an order simply waits that long between steps.

_Rejected: capacity-limited buffers that block upstream._ Real pull behaviour, but it couples the
engine, can deadlock, and needs blocking-time metrics to be interpretable.

---

## 6. Equivalency

### 6.1 Flow Equivalent

A dummy part whose process time at each step equals **one takt of that workcenter's own capacity**:

```
FE_pt(W) = takt × open_hours_per_working_day(W)
open_hours_per_working_day(W) = union of staffed shift windows, breaks removed
```

**Takt is stored as a value plus a unit, never as a canonical duration.** "3
days" cannot be reduced to seconds without saying whose working day is meant,
and the answer differs per workcenter: a 3-day takt is 68 h at a station open
22:40 a day and 26:24 at one open 8:48. Both are "one takt of that station's own
capacity", which is the comparison this method exists to make. Hours, minutes
and seconds are literal and resolve identically everywhere
(`TaktPeriodSpec.equivalentAt`).

**Availability is deliberately absent from the capacity figure.** It is applied
exactly once, in §4.4's effective process time; derating the open hours as well
would count the loss twice.

**Availability is part of capacity; rework is not.**

```
productive_hours_per_working_day(W) = open_hours_per_working_day(W) × availability(W)
FE_pt(W)                            = takt × productive_hours_per_working_day(W)
```

Availability is a property of the station's capacity, so it is in the hours per
day. Rework is a loss on the work a **part** requires, so it attaches to demand
part process times instead (§6.2) and never moves the equivalent.

The worked reference — ABC three shifts at 74 %, takt 3 days:

| | |
|---|---|
| open hours per working day | 22:40 |
| productive hours per day | 22:40 × 0.74 = **16.77 h** |
| equivalent process time | 3 × 16.77 = **50.32 h** |
| a demand part at 55 h, 3.7 % rework | 55 × 1.037 = 57.035 h |
| that part's lead time here | 57.035 ÷ 16.77 = **3.40 d** |
| that part's equivalent | 57.035 ÷ 50.32 = **1.13** |

**The ladder measures days in productive days** — it divides by the same 16.77.
That is why availability cancels for the equivalent and one takt reads as
exactly `3.0 d` however bad a station's uptime, while a real part at 57 h reads
`3.40 d`. The box, the ladder and the footer totals all read the one figure, so
PCE stays a ratio of like with like.

### 6.1.1 Process Specific Takt Time

A flow step can carry its own takt — its **Process Specific Takt Time**, which
is what the field is called on screen (`flow_nodes.equivalent_value` +
`equivalent_unit`, null = follow the line's takt; the columns keep their
original names, since renaming them would cost a table rebuild for nothing).

This is a property of the **yardstick, not the station**: an inspection that
genuinely takes a fraction of a takt would otherwise make the equivalent claim a
full takt there, dragging every real part's equivalence at that step toward zero
and skewing the balance measure. It is stated as an absolute value with a
[TaktUnit], where `days` means productive days of that station — so `1 day`
equals one takt-day, and a step overridden to the takt's own value reads
identically to one left alone.

Stored per **flow step**, not per workcenter: the same station is not worth the
same share of a 1-day line and a 4-day one, and a duplicated study must be
rebalanceable without disturbing the original. Overridden steps are marked on the
map, because a reader comparing two boxes has to know one is not measured in
takts.

_Consequence, accepted deliberately:_ an absolute override does not follow the
takt, so a step overridden under a 3-day takt keeps its value when July's takt
becomes 4 days, and its share of the equivalent shifts.

**A quantity buffer still uses the line's takt**, never a downstream step's
override: stock drains at the rate units leave the line.

**Overlapping shifts count once.** The seeded ABC pattern has A running to 15:13
and B starting at 14:26 — a 47-minute handover overlap, 7 minutes of it after
A's break is taken off the end. A workcenter is a single server (§7.5), so the
open time is the *union* of its staffed windows, not their sum. ABC with all
three shifts staffed is therefore 22:40 a day, not the 22:47 the three net
windows add up to.

**The union is taken on the 24-hour circle**, so a night shift that overruns the
next morning's start is counted once too — see §17.3.

_Rejected: a project-level hours-per-day constant._ A 1-shift and a 3-shift workcenter would get
the same equivalent, hiding exactly the imbalance the method exists to expose.
_Rejected: 1 day = 24 h calendar._ The equivalent would say nothing about capacity consumption.

### 6.2 Part equivalence

```
eq(part, W)    = part_pt(W) ÷ FE_pt(W)          per workcenter / process type
eq(part, flow) = Σ part_pt  ÷ Σ FE_pt           whole flow
```

`part_pt(W)` is the **stored per-piece time with that station's rework charged
against it** — `55 h × 1.037 = 57.035 h` in §6.1's worked reference. Availability
is not applied here a second time: it is already in `FE_pt`'s productive day, and
the ladder divides by the same day, so it cancels exactly where it should.

**`eq(part, flow)` is a ratio of sums, never a mean of the per-step ratios.** The
two differ the moment the steps are unequal, and only the ratio of sums answers
the question the measure exists for — how many takts of the *whole flow's*
capacity this part consumes. A part that is twice as slow as the takt on a
half-hour inspection has not made the flow 1.5× harder.

**A step the selected part has no process time for is a blocking error** (§11),
not a zero and not a quiet fall-back to the takt. The yardstick is still computed
there, because it is a property of the station and the reader may need it; what
is missing is the part's own number, and the map says so.

The two data sources that read this:

- **One part** — that part's own times, with the part named in the toolbar and in
  the printed map's header. The equivalence appears on every box and, summed, in
  the footer band.
- **All variants weighted by demand mix** — `Σ(pt × pieces) ÷ Σ pieces` at each
  step, over the orders with a need date **inside the viewed period**. Weighted by
  *pieces*, not by order count, because process times are per piece (§7.6). A
  part that skips the step is left out of the denominator too: averaging its
  absence in would claim the station is faster than any piece passing through it
  ever is.

A step targeting a pool reads the **pool's** cell (§3.1, §9), never that of the
member standing in for it on the map.

### 6.3 MM3 — sequence smoothness

**Centered** moving average of 3 over the equivalence of the demand sequence: `(prev + current +
next) ÷ 3`, blank at both ends. (Verified against the spec's worked example: 1.11, 1.01, 0.97.)
Closer to 1.0 = better balanced.

Computed per selectable scope — whole flow, or one process type / workcenter, with the highest
total-process-time workcenter preselected. Shown as a table column plus a line chart against the
1.0 reference, with configurable warning bands (default ±10 % amber, ±20 % red) and a headline
smoothness figure. The user reorders manually and watches it improve.

_Rejected: automatic resequencing._ That is a scheduling optimiser with its own objective function
and constraint set; it is not in the spec, and a suggestion that violates a need date is worse than
no suggestion.

---

## 7. Simulation

### 7.1 Engine

Discrete-event: a priority queue of timestamped events (order released, step started, step
finished, buffer expired) advanced in absolute time, every duration added through the §4 calendar
function. Cost scales with events, not horizon length. Runs on a background isolate.

### 7.2 Order release — strict takt slots, no skipping

Release slots are generated at takt intervals from the study start date. At each slot the engine
looks at the **head of the user's sequence only** and releases it if:

1. material delivery date ≤ slot time, **and**
2. orders currently in the flow < kanban WIP cap.

Otherwise the slot is recorded **EMPTY** and the head waits for the next slot. No reordering.

The user's sequence is the thing under study — the app must not silently repair a bad one.

### 7.3 Kanban — study-level CONWIP cap

One optional number per study: maximum orders open in the flow at once. A release requires a
completion. Default off (unlimited), so a first run shows raw demand-vs-capacity behaviour.

_Rejected: per-buffer kanban card counts._ Re-opens §5.5, can deadlock, needs starvation
diagnostics.

### 7.4 Dispatching

Default **FIFO** by arrival at the step; ties break by (arrival, study priority, sequence #) so
shared-workcenter contention is reproducible. A per-simulation setting offers **EDD** (earliest
need date) and **SPT** (shortest processing time) — "what if we dispatched by due date" is exactly
the experiment this app exists to run.

### 7.5 Operators

A workcenter is a **single server**: one order at a time. Real parallel capacity is modelled by
putting several workcenters in a pool. A shift with 0 operators is closed; any count ≥ 1 runs
identically. **Operators Needed** is computed from load (required hours ÷ productive hours per
operator) and compared against Allocated — the "6.7 operators required" figure.

_Rejected: operators as parallel capacity._ Two operators on one CNC do not double its output.
_Rejected: a shared operator pool across workcenters._ A second contended resource class with its
own assignment policy; nothing in the spec asks for it.

### 7.6 Batching and changeover

```
occupancy = changeover_if_part_changed + (part_pt × batch_size)   … then derated per §4.4
```

**Process times in the demand table are per piece.** An order of batch 10 occupies the workcenter
for ten times the tabulated time, so Batch Size is a real lever for testing lot sizing.

_Rejected: process time per order with batch size as metadata._ Correct only for one-piece-flow
heavy fabrication, and it makes the Batch Size column inert in every calculation.
_Rejected: a separate batch-independent setup component alongside changeover._ More faithful to a
real routing, but it adds a second time field per step and a rule for how setup and changeover
interact.

Changeover is incurred **only when the previous order on that workcenter had a different part
number** — so running like-with-like is genuinely cheaper and the sequence has a real cost, which
is what makes §6.3 worth optimising. The whole batch moves to the next step together.

_Rejected: overlapping/piece transfer._ Multiplies event count by batch size and stops an order
being a single object moving through the flow.

### 7.7 Run unit and contention

A run takes the set of selected studies (**at most one per production line**) and builds **one**
resource model of the plant — each workcenter and pool exists once regardless of how many studies
point at it. Each study releases on its own takt slots into that shared model, so line A's orders
genuinely delay line B's. Each study carries an explicit priority used in dispatch tie-breaking.
Results are reported per study and rolled up per plant.

### 7.8 Initial state and horizon

**Cold start**: the plant is empty at the study start date (= first order's need date − that part's
theoretical lead time, §7.9). The run ends when every order in every selected study is delivered,
with a hard guard (≈5× the horizon implied by demand) that aborts and reports "demand exceeds
capacity — N orders never completed" rather than looping forever.

### 7.9 Theoretical lead time

```
theoretical_LT(part) = Σ_steps (part_pt × batch ÷ availability × (1 + rework)) + Σ inventory delays
```

walked through the working calendar so it lands on real dates. **Excludes queueing** (the point of
the measure) and **excludes changeover** (it depends on what ran before, so it is not a property of
the part). Used for both the study start offset and the Lead Time Efficiency denominator.

Flow-equivalent lead time (`takt × steps + inventory`) is kept as a separate footer reference — the
mockup shows both (6.0 vs 9.0 working days).

### 7.10 What a run stores

The frozen input snapshot, **one row per order-step** (queue start, process start, process end,
workcenter actually used, changeover incurred, wait time), and the computed aggregates. ~4k rows
for 500 orders × 8 steps. Makes order Gantts, queue histories, bottleneck evidence and "why was PN2
late" into queries rather than re-runs. Two runs can be compared side by side.

---

## 8. Metrics

Per the spec: delivery float (actual − need date), average float per order, OTD (on-time ÷ total),
average lead time per part number, lead-time efficiency (actual ÷ theoretical, §7.9), sequence
evaluation (§6.3), operators allocated vs needed (§7.5), empty-slot count (§7.2).

### 8.1 Bottleneck

Primary ranking: **Occupation** = required ÷ available productive hours per workcenter per period —
available before any simulation, so the Summary flags constraints from static data alone; > 100 %
is a hard constraint. After a run, workcenters are also ranked by total queue hours and by share of
total lead time contributed. The headline names one bottleneck; the table shows both rankings,
because their disagreement is itself diagnostic — high queue at a low-occupation station means a
sequencing problem, not a capacity one.

### 8.2 Demand takt

Two rows on the Summary, per takt-schedule period, with a month/quarter view toggle:

- **Raw** = available working time ÷ orders with a need date in the period.
- **Equivalent-adjusted** = available time ÷ Σ part-equivalents due in the period.

Both compared against the line's configured takt. The raw figure is what a visitor expects; the
adjusted one is what actually matters under a mixed part mix.

### 8.3 Capacity glossary — three distinct terms

| Term | Kind | Meaning |
|---|---|---|
| **Availability** | input | fraction of open time the machine can run (74 %), on the workcenter schedule |
| **Occupation** | static output | required hours ÷ available productive hours for a period |
| **Utilisation** | simulated output | busy time ÷ open time observed in a run |

Occupation and Utilisation differ whenever sequencing or starvation gets in the way. Defined once
in an in-app glossary and translated consistently across en/es/pt.

_Rejected: the mockup's naming ("Utilization 100 %" on the box)._ It conflates an input with an
output, and the inconsistency becomes permanent once it is in three `.arb` files and every PDF.

---

## 9. Data entry

One editable grid per table with keyboard navigation and multi-cell TSV paste from Excel. File
upload accepts `.xlsx`/`.csv` and opens a **mapping step** (their columns → our fields; workcenter
columns matched by name, unmatched listed) then a **validation preview**: bad dates, unknown part
numbers, negative times, need date before material date — row by row, accept or cancel. Nothing is
written until accepted.

Process times are stored **keyed by the step's target**, so adding a step to the flow adds an empty
column and removing one hides the values without destroying them.

### 9.1 The grid, as built

- **Every column is text.** A dropdown for the part or a date picker for the need date would read
  better in isolation and would make that column unpasteable — and pasting a block out of the
  planner's spreadsheet is how this data actually arrives. What a cell means is decided by the
  parser behind it: `parseDurationInput` accepts `30:00:00`, `1.5h`, `90min`, `2d` and a bare
  number in hours; `parseDateInput` accepts ISO in every locale and the locale's own form second.
- **A typed cell and a paste are the same operation** — a 1×1 block and a rectangle. There is one
  commit path, so a rule proved for one holds for the other.
- **The reading of a block is a pure function** (`planPartsWrite`, `planSequenceWrite`) that returns
  what the block *asks for*; the repository resolves part numbers to ids and writes it in one
  transaction. Which rows append, which renames are refused, what an emptied cell means: all unit
  tests, none of them widget tests.
- **A blank cell is not a zero.** A part that skips a step has no row in `part_process_times` at
  all, and clearing a cell deletes the row rather than storing `0`. This is §11's rule in the one
  place a user can most easily trip it.
- **The last row of each grid is blank and appends.** Typing a part number into it adds a part;
  pasting a block onto it adds as many parts as the block has rows. A row with no part number, or
  an order row with no part and no need date, is skipped — never defaulted.
- **Keyed by the step's target, and a pool is a target.** Pool members are interchangeable (§3.1),
  so a part has one process time at `CNC Lathes`, not one per lathe. Two steps targeting the same
  workcenter are two columns over one stored value, and a total counts it twice — which is correct,
  since the part passes twice.
- **A demand part belongs to a study, not to a project.** Its process times are keyed by that
  flow's own step targets, and §10.2 leaves demand out of a template by default. Duplicating a
  study deep-copies its demand, so a scenario can be re-sequenced against the same orders (§6.3).

---

## 10. Studies, templates, scenarios

### 10.1 Cardinality

A study is scoped to exactly one (cell, line) pair; a project may hold **several per line as
scenarios** ("current state", "with 3rd shift on CLAD04"). Each carries an include-in-simulation
flag; the project enforces at most one flagged per line before a run. This is what makes
duplication meaningful and gives run comparison something to compare.

### 10.2 Templates

A template stores the flow structure (step order, inventory nodes and modes, changeover values,
decorative layer, release/kanban settings), with each step recording the source workcenter's
**name and type** rather than its id. Applying it opens a **binding step**: exact name matches
auto-bind, the rest are picked from the target plant filtered by type; unbound steps block
simulation. Demand is excluded by default, with an "include demand parts & sequence" checkbox at
save time.

Duplication *within* a project is a deep copy with ids intact — no binding needed.

---

## 11. Readiness and validation

Every study shows a **live readiness panel** splitting issues into:

- **Blocking errors** — a step with no bound workcenter; a date in the demand horizon not covered
  by a takt or workcenter schedule period; overlapping schedule periods; a part with no process
  time at a step it must visit; a demand row referencing an unknown part.
- **Warnings** — occupation > 100 %, need date before material delivery date, unusually large
  changeover.

Simulate is disabled while any error stands; each error deep-links to the offending field.

**Gaps are never silently defaulted.** A zero that should have been a number is the one bug this
app cannot afford.

### 11.1 The tail past the last schedule period

A gap *inside* the demand horizon (first to last need date) is a blocking error — a real data hole.
Time *after* the last defined takt or workcenter schedule period carries the last period forward
indefinitely, flagged as a run warning: *"12 orders completed after 31/12/2026 using the last
defined schedule."*

Without this, an overloaded plant becomes unsimulatable exactly when the simulation is most
informative — and the user cannot know how far to extend their periods until they have run it.

---

## 12. UI

### 12.1 Shell

A persistent left rail: Projects · Study Templates · Resources · Settings (· About/diagnostics).
Opening a project gives a workspace with a studies sidebar and, per study, tabs
**Flow / Takt / Workcenters / Demand / Summary**, plus a project-level **Simulation** tab since a
run spans studies. Resources uses a hierarchical tree (Plant → Cells → Lines → Workcenters, plus
Pools and Shift Patterns). All routes deep-linkable via go_router.

### 12.2 Canvas

Each node is a real Flutter widget positioned by the layout engine in a `Stack`; connectors, the
sawtooth lead-time ladder and the VSM symbol shapes are `CustomPaint`. `InteractiveViewer` gives
pan, zoom, fit-to-width and the % readout. Hit testing, hover, tooltips, focus and keyboard
navigation come free from the widget layer. A **separate renderer** draws the same layout model
into the `pdf` package, so exports are vector and text-selectable rather than screenshots.

### 12.3 Undo

Flow and grid edits inside an open study go through **command objects that know their inverse**
(add/remove/reorder step, edit field, paste block, delete rows). The stack is in memory for the
open workspace and discarded on close; writes still hit the DB immediately, so nothing is ever
unsaved. Resources edits and destructive project actions are **not** undoable — they use confirm
dialogs, the right trade for infrequent deliberate operations.

### 12.4 Units, dates, locales

All durations stored as **integer seconds**. Process time, changeover and takt carry a display unit
(d/h/min/s) — a 3-day takt reads `3 d`, a 30-hour process time reads `30:00:00`. Inputs accept
`1.5h`, `90m`, `30:00`, `2d` and normalise on commit. Dates render per app locale (dd/MM/yyyy under
pt/es) with a Settings override, stored as local dates — a shift calendar is inherently local.

Localised en / es / pt, mirroring Chronus.

---

## 13. Exports

- **PDF — VSM map**: vector, text-selectable, honouring the current data-source and period
  selection, with the footer metrics band.
- **PDF — study report**: map, takt schedule, workcenter schedules, demand summary, occupation and
  operator tables.
- **PDF — simulation report**: input snapshot summary, OTD/float/lead-time metrics, bottleneck
  ranking, late-order list.
- **Excel**: any grid in the app, plus per-order simulation results for pivoting.

All exports stamped with app version, project/study name and run timestamp.

---

## 14. Scale target

Design target: one plant, ~50 workcenters, ≤10 studies of ~10 steps, ~500 parts, ~2000 orders over
a 1–3 year horizon. A run is well under a second; grids need only ordinary lazy lists. The
simulation still runs on a background isolate so the UI cannot freeze. Treat 4× these numbers as
the "must not fall over" ceiling.

---

## 15. Correctness

- Pure-function tests for the calendar (shift boundaries, midnight crossing, breaks, exceptions),
  equivalency, occupation and theoretical lead time, each with hand-computed expected values.
- **Golden scenarios**: small studies whose complete simulation output is committed as a fixture,
  so any engine change that moves a number fails loudly.
- **In-app explainability**: every derived figure expands to show its inputs and formula —
  `Occupation 112 % = 1 340 h required ÷ 1 196 h available`. This is what lets an engineer defend a
  result in a meeting, and what makes a wrong input findable in the field where no one is watching.

---

## 16. Build order

| Milestone | Contents |
|---|---|
| **M1** ✅ | Resources, shift patterns, calendar engine + its test suite. Everything downstream is wrong if this is. |
| **M2** ✅ | Project, studies, flow canvas, takt & workcenter schedules, PDF map export. |
| **M3** | Demand grids, Excel import, flow equivalent, MM3, Summary/occupation. |
| **M4** | Simulation engine, run storage, metrics, bottleneck views. |
| **M5** | Reports, run comparison, templates & binding, polish, drop. |

Every milestone ends in an app that runs and does something useful, so the model is validated
against real data long before the engine is written.

### 16.1 M1 as built

Shipped in M1: the app shell (left rail, four destinations, two of them placeholders), the
diagnostics log and its three error channels, window geometry persistence, the Drift schema at
`schemaVersion` 1 with its seeds, the Resources area (plant tree, pools, shift patterns,
workcenter types), and the calendar engine with 76 tests.

The calendar's public surface — the seam everything downstream calls:

| Member | Answers |
|---|---|
| `openTimePerWorkingDay` | nominal capacity of an ordinary day (§6.1, occupation) |
| `intervalsStartingOn(date)` / `openTimeOnDate(date)` | that day's shifts and their capacity |
| `isOpenAt(t)` | is this workcenter running at that instant |
| `nextOpen(from)` | when work could start |
| `openTimeBetween(from, to)` | capacity in a window (occupation, utilisation) |
| `advance(from, work)` | when `work` of open time finishes (lead time, simulation) |

`advance` and `nextOpen` throw `StateError` rather than looping if the calendar can supply no
open time within ten years — the simulation's abort guard (§7.8) depends on that failing loudly.

### 16.2 M2 as built

Schema v2 (migrated in place on an existing v1 install), the project layer, the study workspace,
both schedule editors, the VSM canvas and PDF export. 144 tests.

The seam that joins M1 to project data is `SchedulesRepository.loadWorkcenterCalendar` — the only
place a `WorkingCalendar` is constructed outside a test. It pulls the plant's shift pattern, the
workcenter's staffing over time, and the project's exceptions narrowed to that workcenter.

Decisions taken while building it:

- **A workcenter's `homeLineId` is where it is drawn, not what owns it.** The resource tree is
  Plant → Cell → Line → Workcenter, but studies on different lines must be able to share a
  workcenter (§7.7). So the plant owns it and the line is a nullable home; deleting a line leaves
  its workcenters on the plant rather than destroying them.
- **Supplier and Customer are fields on the study, not nodes.** They carry no data and take part in
  no calculation, so a row for each would be a row that can only ever be renamed.
- **Calendar exception ranges are expanded to one row per day** on entry, so every lookup
  downstream is a map hit rather than an interval search.
- **`CalendarExceptions.scopeId` is `''` for plant scope, not null.** SQLite treats NULLs as
  distinct in a UNIQUE constraint, so a nullable column would have allowed two plant-wide
  exceptions on the same day — the exact duplicate the key exists to prevent. Caught by a test.
- **The PDF re-renders the same `FlowView` through the `pdf` package's own layout**, rather than
  replaying canvas pixel geometry. Same model, same numbers, but it page-breaks and keeps text
  selectable, which a transplanted pixel layout would not.
- **`Occupation` shows a dash until M3.** It needs demand to divide into capacity; a zero would be
  read as "idle".
- The data-source selector offers all three sources but disables the two that need the demand
  table, so the shape of the choice is visible from the start rather than appearing later.

### 16.3 Schema v3, from field feedback

- **A workcenter has one name, not a name and a code.** Both fields were filled with the same
  value in practice, and every picker showed it twice. `workcenters.code` is dropped by a table
  rebuild; the name is what the process box is labelled with.
- **"Add existing" puts a workcenter under a line in the tree.** A plant-unique name meant the
  only way to show `CLAD04` under a second line was to invent a second name for it — which read
  as "I can't use the same workcenter in two flows". The workcenter still belongs to the plant and
  any study could always target it; this makes that visible instead of implied.
- **Never call an extension getter through `dynamic`.** The footer read `takt.unit.name` off a
  `dynamic`, and `Enum.name` is an extension, so it resolved statically and was absent at runtime:
  the flow screen greyed out the moment a takt was saved. Unit labels now come from exhaustive
  switches the compiler checks (`common/unit_labels.dart`), with a regression test. The
  diagnostics log caught this one exactly as §15 intends — a release build shows a blank panel and
  nothing else.

### 16.4 Schema v4, and the second grey window

- **A fixed inventory wait stores its unit** (`flow_nodes.inventory_unit`), so `2 days` reads back
  as `2 days` rather than `48 h`. Unlike a takt, this `days` is a plain 24 hours — resolving it
  needs no workcenter — so it is a separate enum (`DurationUnit`) from `TaktUnit`, which makes the
  two meanings of "day" impossible to confuse. Changing the unit in the editor converts the number
  rather than reinterpreting it.
- **Never put a `Spacer` in `AlertDialog.actions`.** Actions lay out in an `OverflowBar`, which is
  not a Flex, so a `Flexible` child throws `_OverflowBarParentData is not a subtype of
  FlexParentData` on mount — the node editors were a blank grey dialog. Move and delete now live in
  the dialog's *content*, which is a Column.
- **The node dialogs are pumped in a widget test.** Both UI crashes so far were mount-time failures
  invisible to unit tests and silent in a release build. The test caught a third defect on its
  first run: both dialogs overflowed vertically and now scroll.
- **A guarded `addColumn`, exactly as DATA.md predicts.** The v2 step's `createTable(flowNodes)`
  builds from the *current* definition, so a v1 database arrives at the v4 step already carrying
  `inventory_unit` and the plain `addColumn` failed the whole upgrade. It is guarded on
  `from >= 2`; the next column added to `flow_nodes` needs the same guard.

### 16.5 Schema v6, the demand table

Three tables, additive, so the migration step is unguarded `createTable` at any starting version —
unlike the two `addColumn` steps above, which a v1 database reaches with the column already present.

- `demand_parts` — part number and description, unique per study.
- `part_process_times` — `(part, target) → seconds`, **per piece** (§7.6). The primary key is the
  pair; there is no id, because a cell has no identity beyond which part and which step it is.
  `target_id` carries no foreign key, for the reason `calendar_exceptions.scope_id` does not: it
  points at a workcenter *or* a pool, and one column cannot reference two tables.
- `demand_orders` — the sequence, dense and zero-based like the flow spine, with batch size, need
  date and an optional material date.

Decisions taken while building it:

- **Deleting a part deletes its orders through the repository, not the cascade.** The foreign key
  would have left holes in the sequence, and a sequence with holes is one the release slots (§7.2)
  cannot walk and MM3 (§6.3) cannot average over.
- **`demand_orders` has no notes column.** It was written and then removed before it shipped:
  nothing writes it, the order number already carries "their own reference", and §17.5 is the
  argument against keeping a field ahead of the UI that would justify it.
- **A Drift stream inside a widget test leaves timers pending.** Disposing a `StreamProvider` over a
  Drift query schedules a zero-duration timer, and the test binding asserts on `!timersPending`
  after the tree comes down — the test hangs rather than failing. The Demand tab's mounting tests
  override the providers with plain values instead; what the writes do is proved against a real
  in-memory database at the repository level, where there is no `fakeAsync`.

---

## 17. Done between M2 and M3

### 17.1 A buffer's time now agrees with itself

Reported against the built map, and it had two independent causes:

- **The ladder divided every rung by the productive day.** A fixed wait is
  calendar time unless its working-time flag is set, so 48 h of cooling read as
  2.9 d against a 16.77-hour day. A calendar wait is now measured in calendar
  days; only working-time waits and quantity buffers — whose wait is
  takt-derived — use the station's productive day
  (`FlowInventoryView.isCalendarWait`).
- **The triangle and its own rung rendered differently.** The triangle showed
  the value as typed while the rung showed the ladder's units, putting two
  numbers for one wait on screen. The triangle now uses the ladder's rendering;
  the value as typed lives in the editor, where it is entered.

A one-piece quantity buffer and the step it feeds are asserted equal, since both
are one takt of the same station.

### 17.2 Running days in the footer

Beside the working-time lead time, the footer states the calendar span:
`11 running days · Aug 13, 2026`.

It is a **walk, not a conversion** (`_walkCalendar`). Process time is spent in
its own station's open hours, a working-time buffer in the hours of the station
it feeds — or, at the end of a flow, the one it just left — and a calendar
buffer on the wall clock, weekends included. The gap between the two figures is
the closed time, which no ratio could produce.

The walk starts at the **first day of the viewed period**, since no demand
exists yet to supply a real start date; M3 replaces that with the first order's.
It returns nothing rather than a guess when a step cannot be costed or its
calendar can never open, and the footer shows a dash.

### 17.3 A day is worth a day

The single-server rule (§6.1.1) was applied only within one calendar date. A
shift window is attributed to the day it starts on, so a night shift running to
07:00 and the next morning's shift starting at 06:00 were merged in separate
passes and never compared — the shared hour was counted twice. A pattern of
`06:00–18:00` and `18:00–07:00` reported **25 hours of open time in a 24-hour
day**, and `openTimeBetween` said the same across any window containing the
overlap.

It matters beyond the shift editor's own preview: that figure is the flow
equivalent's divisor (§6.1), the working day the lead-time ladder renders
against, and — from M3 — the denominator of Occupation (§8.1). An overstated
day understates occupation, which is the number the app exists to produce.

Two fixes, because the same rule has two forms:

- `openTimePerWorkingDay` is nominal minute arithmetic over a pattern that
  repeats daily, so its union is taken **on the 24-hour circle**: a window
  running past midnight wraps to the start of the cycle and merges with what
  is already there.
- `openTimeOnDate` and `openTimeBetween` walk real dates, so each day
  contributes only what the day before did not already claim. The overrun is
  credited to the day whose shift reached it first, which is what makes
  `Σ openTimeOnDate` equal `openTimeBetween` over the same span.

`advance` and `nextOpen` needed no change and deliberately got none: they walk a
cursor that never moves backwards, so an overlapping interval is already clipped
to it and the shared time is spent once. Trimming inside `intervalsStartingOn`
was rejected — it would make a method asked about one day answer about two.

The seeded ABC and ABCD patterns never tripped this (ABC's overlap is inside a
day; ABCD's windows touch without overlapping), which is why 76 calendar tests
did not catch it. The regression case is a pattern with an hour of real
overrun.

### 17.4 One kind of day per screen

§6.1 says the box, the ladder and the footer totals all read the one figure.
Three places did not.

- **The PDF's ladder and buffers were in 24-hour days** while the canvas drew
  the same rungs in each station's productive day. A one-takt step read `3.0 d`
  on screen and `2.1 d` on the printed map. The renderer took a
  `String Function(Duration)`, which simply could not be handed a working day —
  the type made the bug unfixable at the call site. It now takes a
  `FlowDurationFormat` that carries one, so the omission would be a compile
  error rather than a quieter number.
- **The footer totals were in 24-hour days** while the rungs directly above
  them were in productive ones: three steps of one 3-day takt showed three
  rungs of `3.0 d` over a lead time of `6.3 d`. The totals are now summed as
  ladder days — each node against its own rung's working day — and rendered
  against the divisor that reproduces that sum. A derived divisor rather than a
  chosen one, because the steps of a flow legitimately differ in how long their
  day is, so there is no single station's day to pick; only the one that makes
  a total agree with what it totals. A calendar wait keeps its plain 24 hours,
  which is what its own rung reads (§17.1).
- **The PDF named the data source and the override marker wrongly.** The header
  was hardcoded to "Flow equivalent" and the `*` on a step carrying its own
  Process Specific Takt (§6.1.1) was missing, so a printed map could not be read
  the way §6.1.1 requires. Both now come from the view, through an exhaustive
  switch that M3's two extra sources cannot be added without updating.

The PDF's numbers live in a compressed content stream and cannot be read back
out of the bytes, so the tests assert on what the renderer *asks* to be
formatted — a recording formatter, rather than a golden file that would have to
be regenerated on every layout tweak.

### 17.5 What is built but cannot be reached

An audit before M3 found two kinds of unused code, and they deserve opposite
treatment.

**Superseded, and deleted.** `formatLadderTime` (replaced by
`formatAdaptiveDuration`'s working day in §17.1), `durationUnitShort`,
`FlowStepView.isCostable`, `FlowView.flowEquivalentProcessTime` — a duplicate of
`processTime` that would have started lying the moment M3 gave the two different
meanings — `SchedulePeriodIssue.isBlocking` (a constant `true`),
`ViewedPeriodState.end`, `linesProvider`, `watchPlant`, `loadProject`,
`Diag.shortId`, `Diag.installForTest`, and two painter fields nothing painted.
None had a caller, in the app or in a test.

**Written ahead of its UI, and kept.** These are complete, tested through their
repositories, and reachable from nothing a user can click. Listed here so the
next milestone plans them rather than rediscovering them:

| What | State | Wanted by |
|---|---|---|
| Calendar exceptions (§4.3) | schema, resolution, calendar assembly, tests | **M3** — "Saturday extra hours on CLAD04" is the commonest capacity lever there is, and it cannot currently be entered |
| Supplier / Customer names (§16.2) | stored, drawn on canvas and PDF | M3 — the only writer is the rename dialog passing the old value back, so the endpoints always read their defaults |
| The decorative layer (§5.2) | table, enum, five repository methods, provider | M5 — nothing draws or creates an annotation; `duplicateStudy` deep-copies a table that is always empty |
| `DiagnosticsLog.compose` / `addFeedback` | written, never called | M5 — there is no About screen (§12.1), so the log has no in-app way out |
| `wipCap`, `priority`, `reworkOn`, `effectiveProcessTime` | stored / computed | M4, as planned |

---

## 18. Open assumptions

Recorded here rather than silently coded. Each needs a yes/no before the milestone that depends on
it.

1. ~~Delivery definition~~ — **confirmed**: an order is delivered when it completes its last
   semantic step. No shipping lead time is charged before the need-date comparison. (§8)
2. **A workcenter may belong to several pools**, but a step targets exactly one workcenter or one
   pool. (§3.1, M1)
3. **Takt changes mid-flight** affect only future release slots; orders already in the flow are not
   re-planned. (§7.2, M4)
4. **Single user, single machine.** No concurrent access, no file locking, no sync. (§2, M1)
5. **Empty slots are a reported metric**, not an error — count and dates listed in the simulation
   report. (§7.2, M4)
6. **Rework adds time only.** It does not create additional physical orders, scrap, or material
   consumption. (§4.4, M1)
7. **One plant per project**, per the spec; a project cannot span plants. (§3, M1)
