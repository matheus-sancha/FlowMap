# FlowMap — Design

Why the app behaves the way it does. Cited from code by section number, e.g. `(DESIGN.md §6.4)`.
Read before changing behaviour; update in the same commit that changes it.

Status: agreed 2026-08-03 in design interview. M1–M3 built; §16 tracks what each one settled.

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

**A workcenter is drawn under a set of production lines, not one.** `CLAD04` genuinely serves two
lines in a real plant, and membership is **organisational only** — it constrains nothing. Any study
of any line may target any workcenter of the plant whether it is filed under that line or not,
which is exactly what cross-line contention needs (§7.7). What membership affects is where the
workcenter appears in the Resources tree, and which line-scoped calendar exceptions reach it (§4.3).

_Rejected: a single `home_line_id`._ It shipped through M3 and was wrong: filing a workcenter under
a second line silently took it out of the first, so the tree fought the very arrangement the app
exists to analyse. Reported from the field; replaced by `workcenter_lines` in schema v7.

_Rejected: dropping line membership from Resources altogether._ Raised in the same report — if a
study names its workcenters anyway, filing them under a line looks like the same work twice. Weighed
and **kept** (2026-08-04): the duplication was really the bug above, and membership is what makes a
line-scoped calendar exception resolvable at all (§4.3). Without it that scope either disappears or
has to resolve through the studies that touch a workcenter, which couples the calendar to flow
structure. The tree also earns its keep at fifty workcenters. Membership stays optional, so a
workcenter filed nowhere is a perfectly ordinary one.

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
a pool is dispatched to whichever member frees first; ties break by lowest utilization, then name
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

**The arrows are derived, never chosen.** Every link on the spine is drawn as one of three things,
and each is explained by something typed somewhere it could be validated — which is the same rule as
the kanban icon's, applied to the connections:

| Drawn | When | Why that is honest |
|---|---|---|
| **Push** — hatched shaft | the default | With no supermarkets in the model (§5.5) and no WIP cap, material moves downstream whether or not the next step asked. The hatching *is* the mark of a push, so the map now says on purpose what it used to say by accident. |
| **Pull** — bare shaft | the study has a CONWIP cap (§7.3) | A release that requires a completion is a pull system. It is study-wide, so it reaches every link. |
| **FIFO lane** — a channel: two rails, `FIFO` between them, a tick in and a solid triangle out | the station the link feeds is **explicitly** set to FIFO (§7.4) | Someone decided that queue runs in arrival order, and a sequenced lane is what that is. |

**Push and pull share a shaft; a FIFO lane does not.** This section used to say all three were one
shaft told apart by what went inside it, and the drawing followed: a hatched arrow with a divider
line and the word written above. That was a principle invented to describe an implementation. A
reader of a real value stream map recognises a FIFO lane as a *channel* — a fixed width, so it holds
a sequence rather than a pile; an entry mark and an exit mark that differ, so it has a direction —
and none of that is available to an arrow. So the lane is its own figure, and the two that genuinely
are variants of one shaft remain variants of one shaft.

Its stroke is 1.2 px, the same weight as the factory, the inventory triangle and the pool badge,
for the reason §1.7 gave the badge: a symbol drawn in a different weight reads as pasted onto the
map rather than part of it. The lane is sized to the 64 px gap the layout leaves between nodes, and
drops its label rather than overrunning its own rails when a gap is narrower than the word.

- **The kind belongs to the arrow's destination.** A queue forms in front of a station, so it is that
  station's discipline the lane describes. The last link runs into the customer, which is not a
  station, and falls back to the study's own kind.
- **Only an explicit FIFO draws a lane.** Under the default rule every station in the plant
  dispatches FIFO, so "is this station FIFO" would be true everywhere and a lane on every link would
  say nothing. A stored row is a decision; an absent one is not (§7.4).
- **A lane beats the cap on the link it marks.** The cap describes the flow, the lane describes one
  queue in it, and the more specific of the two is what gets drawn.

_Rejected: a push/pull/FIFO picker per link._ Total freedom to draw the current state as it really
is, including flows the engine cannot run — but it creates a second source of truth about the flow,
free to disagree with the engine, which is exactly what §5.3 exists to prevent.

**The printed map labels rather than redraws.** `flow_pdf.dart` builds its map from the `pdf`
package's own widgets so text stays selectable and the document stays vector; it does not replay
`VsmSymbols`' paths, and a comment there claiming otherwise has been corrected. A pull link and a
FIFO lane therefore say `PULL` and `FIFO` under the arrow, and a push says nothing, because a
caption on every arrow is noise.

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

**Notes are the exception to "nothing is typed".** A node carries free text — what a walk of the
current state found here, a problem or an opportunity — and it affects no number. It was stored and
carried through the repository from M2 and editable from nothing, the same shape the supplier and
customer names were in (§17.5); reaching it cost a text field.

- **A marker on the box, the words in the tooltip.** A box is sized for eight data rows and a
  finding is a sentence, so the box says only that there *is* one. A finding nobody can see is a
  finding nobody acts on, which is why the marker is not itself hidden behind the hover.
- **A problem still wins the tooltip.** §11's problems are reasons the map cannot be trusted yet;
  a note is the reader's own writing, and outranks only the box's description of itself.
- **The PDF prints them as a list under the map**, named by the box each belongs to, and omits the
  heading entirely when nothing has been written. A 140pt-wide box cannot hold a sentence, and a
  current state is printed precisely so the findings can be read beside the drawing.

_Rejected: notes as free-placed annotations on the decorative layer (§5.2)._ `FlowAnnotations`
already has a `note` symbol and is still unreached, but a sticker near a box is not a note belonging
to it — it cannot travel with the node when the sequence is re-ordered, and nothing could list "every
problem in this study" without guessing from coordinates.

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

As built:

- **The measure runs over orders, and batch size multiplies the equivalence.** One takt slot
  releases one order (§7.2), so an order of ten pieces genuinely loads the flow ten times as hard
  as one of one, and lot sizing is exactly a lever this measure should respond to (§7.6). With
  batch 1 throughout it reduces to the per-part equivalence of §6.2 and reproduces the spec's
  worked example exactly. The source spec does not say; confirmed in the field (§18.7).
- **A blank cell is a skip, not a hole** (§5.1): it contributes nothing to the numerator and the
  part is still measurable. Only a part with no time *anywhere in scope* has no equivalence, and
  its row is blank rather than zero.
- **Both ends are blank, and so is any window with a missing neighbour.** A mean over two of the
  three is a different statistic wearing the same column heading. The chart breaks its line across
  such a gap rather than bridging it, because a line drawn across a gap claims a value nobody
  measured.
- **The headline is the mean distance from 1.0**, shown as `±4.2 %`. A mean rather than a worst
  case: one awkward order in two hundred is not what the measure is for, and a maximum would make
  every sequence look equally bad.
- **The chart is drawn, not charted.** One polyline, one reference line and two shaded bands do not
  justify a charting dependency to keep current.

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

**How fast slots come round, as built.** A takt in days means productive days of a station (§6.1),
so a cadence needs one station's clock. The engine is handed a resolved interval and the id of the
station whose open time it is measured in; slots then walk that calendar, so a 3-day takt is three
*working* days apart rather than 72 hours.

The station is the **busiest step by work content across the whole demand** — `Σ (part_pt × batch)`
at each step, over every order in the sequence. Deliberately not §8.2's occupation-based bottleneck,
which is the right answer to a different question: occupation is *per period*, and a run spans years.
This one needs no period and cannot change under the run's own feet. Ties break by id, so two runs
of the same study cannot disagree.

The takt is resolved **once, at the run's start**. §18.3 leaves mid-flight takt changes open, and
until it is settled a run keeps one cadence throughout.

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

**A station may keep its own rule**, which the run's default only fills in for. Stored in
`workcenter_dispatch` and set in the flow step editor, where the queue is visible.

- **Keyed by target**, a workcenter id or a pool id — the `part_process_times` convention. A queue
  forms at a pool and not at whichever member stands for it on the map (§3.1), so a pool of four
  lathes is one queue with one discipline.
- **Project-scoped, not study-scoped.** A run builds one resource model and a station exists in it
  once however many studies point at it (§7.7); a study-scoped rule would let two studies demand
  different disciplines of one machine with nothing able to choose. The editor says so, because it
  is set from inside a study.
- **Resolved onto the server at assembly time**, never carried on the step. The engine picks when a
  single machine frees, and one machine can be a candidate for two steps — its own and a pool's. If
  the rule travelled with the step, two orders waiting at one machine would be governed by different
  comparators and "which runs first" would have no answer. `resolveDispatch` flattens it: the
  workcenter's own rule, else a pool's, else the run's. Several pools may name one workcenter
  (§18.2) and may disagree — the lowest pool id wins, arbitrary but fixed, the same tie-break the
  pace setter uses and for the same reason. Setting the workcenter itself overrides all of it.
- **A missing row means "follow the run", and is not the same as FIFO.** Storing the default would
  pin every station the first time one was edited, and would freeze the run's own setting out.
- **The run records the overrides** in `simulation_run_dispatch`, per workcenter, name copied in.
  Without it `simulation_runs.dispatch` would report FIFO for a run in which three stations
  dispatched by due date, and M5's comparison could not say the dispatch is what differed.

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

**Everything a report needs is copied in, never joined to.** No row here points at a study, a part
or a workcenter with a foreign key, and the names travel with the rows — that is what keeps a run
readable after the plant beneath it is re-scoped, renamed or deleted, which is exactly when someone
goes back to ask what last month's run said. Three groups of it, and all three were added because
something could not be answered without them:

- **Per order**: part number, and since v12 the customer's project, batch number, batch size and
  material date, and since v13 the part's description — §8.5's plan cannot be printed from a join
  that may no longer resolve. Also each order's theoretical lead time (§7.9), stored rather than
  recomputed because the walk needs the plant as it was.
- **Per station**: name, busy and open time. Open time is a property of the calendar rather than of
  anything an order did, and it is what makes utilization different from occupation (§8.3).
- **Per override**: the stations that dispatched by something other than the run's rule (§7.4).
  Without them the header would report one rule for a run in which three stations used another.

_Rejected: backfilling a run stored before a column existed._ It would make one run a hybrid of two
moments, which is the one thing the copy-in rule exists to prevent. A blank says "this run did not
record that", which is true.

---

## 8. Metrics

Per the spec: delivery float (need date − actual), average float per order, OTD (on-time ÷ total),
average lead time per part number, lead-time efficiency (actual ÷ theoretical, §7.9), sequence
evaluation (§6.3), operators allocated vs needed (§7.5), empty-slot count (§7.2).

### 8.1 Bottleneck

Primary ranking: **Occupation** = required ÷ available productive hours per workcenter per period —
available before any simulation, so the Summary flags constraints from static data alone; > 100 %
is a hard constraint. After a run, workcenters are also ranked by total queue hours and by share of
total lead time contributed. The headline names one bottleneck; the table shows both rankings,
because their disagreement is itself diagnostic — high queue at a low-occupation station means a
sequencing problem, not a capacity one.

### 8.1.1 The two rankings, as built

`RunMetrics` ranks stations by **queue time** and, separately, by **share of the flow's total
time**. They are computed apart and both kept, because §8.1's whole point is that their disagreement
is the diagnostic — the second ranking would be redundant if it were derived from the first.

- **OTD counts over every order, not the delivered ones.** An order that never came out is not on
  time, whatever its need date says. Averaging float over the delivered ones alone, on the other
  hand, is right: an undelivered order has no float, and inventing one would flatter the run.
- **Float is slack, so positive is early.** It was `delivered − need date` through M4, which made an
  over-committed sequence report `average float +230.7 d` — seven months of apparent room to spare,
  meaning the exact opposite. Float has meant time in hand since long before this app, and §8.5's
  production plan puts the figure in front of exactly the reader who reads it that way. Defined once
  on `SimOrderOutcome.float`, which every other figure sums, so the plan's column and the
  Simulation tab's headline cannot point opposite ways. `isOnTime` is unaffected — it compares two
  instants and never had a sign.
- **Lead-time efficiency is `actual ÷ theoretical`**, the direction §8 states — so 1.0 is queue-free
  and higher is worse. The excess over 1.0 is exactly what §7.9 leaves out: waiting. Each order's
  theoretical figure is walked from **its own release instant**, so the comparison is the same
  order in the same plant minus the queueing, not an average against a fixture.

### 8.1.2 The per-part table, as built

Filed here rather than under a heading of its own because §8.1.1 already covers the two tables
beside it on the Simulation tab, and the three are read together.

`Part Number | Study | Orders | Delivered | On time | Average LT | Average float`, one row per
**part**, sorted by number.

- **Per part, not per part number.** `DemandParts` is unique on `{studyId, partNumber}` (§16.15), so
  a part number identifies a part only inside its study. A run spans studies (§7.7), which means two
  lines' `PN2` can both appear — two parts with their own routings and process times, and two rows
  that read identically. `PartMetrics` therefore carries `studyId`, and the sort breaks its ties on
  it so the pair land adjacent and in the same order on every read.
- **The Study column appears only when the run carries more than one.** §8.5's rule for the plan's
  section headings, for the same reason: on a single-study run every row holds the same answer, and
  a column of it says nothing the tab has not already said in its header. The names are the ones the
  studies had when the run was made (§7.10), so a study renamed since still reads as the one that
  ran.

_Rejected: keying the table on the part number and merging._ One row per number reads the way people
talk and never repeats itself — but it would average two different parts' lead times into one figure
and report it under a name that means neither. §16.15 moved the customer project off the part
precisely so that a part number would mean one part; merging here would undo that in the reporting.

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
| **Utilization** | simulated output | busy time ÷ open time observed in a run |

Occupation and Utilization differ whenever sequencing or starvation gets in the way. Defined once
in an in-app glossary and translated consistently across en/es/pt.

### 8.4 The Summary, as built

```
required  = Σ (part_pt × batch × (1 + rework)) + changeovers × changeover
available = open time across the span × availability
occupation = required ÷ available
```

- **Availability appears once, in the denominator.** The part's own time is left alone. Applying it
  to both sides is §4.4's oldest trap and would square the loss.
- **Ranked by target, not by step.** Two steps of a flow may visit the same station, and the
  station has one calendar and one set of hours: its load is the sum of both visits, and both
  process boxes report that same figure. A `×2` on the row says why.
- **Changeover is charged, because the sequence is known.** An order pays for a changeover when the
  order before it *at that station* was a different part (§7.6) — walked over the whole sequence,
  so the first order of the month is compared with the one that really preceded it rather than
  starting the month clean.
- **A pool is measured against the whole pool.** Four lathes are four lathes' worth of hours,
  because an order goes to whichever frees first (§3.1). The first version read every pool figure
  off its first member, so a full pool of four reported four times the occupation it had —
  reported from the field. `FlowStepView.capacityInPeriod` sums the members, and operators are
  summed with it.

  **The flow equivalent deliberately still measures one machine.** `FE_pt` is one takt of a
  *machine's* capacity (§6.1) because the dummy part is one piece, and one piece runs on one lathe
  however many there are. The two figures answer different questions and only one of them was
  wrong.
- **A station with no open hours is not the bottleneck.** Its occupation is a dash: a division by
  zero dressed up as "infinitely busy" would rank a shut station first and hide the real
  constraint.
- **A part due here with no process time is counted and flagged**, not treated as free. Until it is
  entered the required hours are an understatement, and the table says so rather than looking
  merely quiet.
- **Operators needed is occupation restated in people**, and deliberately so. A workcenter is a
  single server (§7.5) — a second operator on one CNC does not double its output — so the only
  honest meaning of "operators needed" is the crew the current pattern would have to become to
  carry this load. Headcount is what makes it actionable.
- **Available working time for the demand takt is the bottleneck's.** A line is a set of stations
  with different calendars and no single figure of its own; the constraint is what sets the pace,
  so its hours are the ones demand has to fit into, and the configured takt is resolved at that
  same station so all three figures are in the same hours. Confirmed in the field (§18.8).
- **The Summary shares the map's period navigator.** A user who steps the Flow tab to `Sep 2026`
  and then opens Summary is asking about September; a second period control would be a second
  answer to the same question.

_Rejected: the mockup's naming ("Utilization 100 %" on the box)._ It conflates an input with an
output, and the inconsistency becomes permanent once it is in three `.arb` files and every PDF.

### 8.5 The production plan — orders over time

`Order | Part Number | Description | Project | Batch Number | Batch Size | Need Date | Material
Date | Order Start | Order End | Theoretical LT | Actual LT | Float`, a section of the Simulation
tab's results.

- **A reading of a stored run, not of the demand.** It reads `simulation_run_orders`, so its dates
  cannot disagree with the run that produced them and opening an earlier run from the history menu
  opens its plan with it. Four of its columns are the copy-in §16.13 added for exactly this, and
  Description is §16.14's.
- **Description is capped and ellipsised, with the whole string on hover.** Free text with no
  length limit in a table that sizes each column to its widest cell: uncapped, one long description
  widens that column for every row and pushes Float off the right edge. The same answer §5.4 gave a
  node's notes, so the app has one way of putting long free text in a narrow place. It identifies
  nothing — two parts may share one (§16.14) — so nothing is lost by not reading it in full.
- **Both lead times, theoretical first.** Theoretical is the stored §7.9 walk, queue-free and
  changeover-free, from this order's own release. Actual is Order End minus Order Start, read off
  the outcome rather than stored, so it cannot come from a different subtraction than the tab's
  average lead time. Both are wall-clock from the same instant, so they are directly comparable, and
  **theoretical can never exceed actual** — the excess is exactly the queueing, which is why the two
  sit side by side. Both render through the same formatter the metrics card uses for the same two
  figures, so §17.4's one-kind-of-day rule holds by construction rather than by care.

_Rejected: a third column for actual ÷ theoretical, or for actual − theoretical._ Either only
restates the pair, on a table already scrolling horizontally at thirteen columns. The ratio is
already reported for the run as a whole on the metrics card.
- **Order is the sequence position, 1-based** — the number the demand grid's row header shows, and
  not a works order number. §9.1's decision that FlowMap carries none of those still holds; Batch
  Number is what a planner matches against their own paperwork.
- **Order Start is release into the flow** (§7.2), which is stored per order. **Order End is the
  last semantic step** (§18.1) — the moment production finishes, which is why it is not called
  Delivery: nothing here models shipping, and a column headed Delivery invited the reader to think
  it did. It pairs with Order Start, and the two together are what the order's actual lead time is
  measured across. Float is slack, positive early, taken from `SimOrderOutcome.float` so the column
  and the tab's average float cannot point opposite ways.

  The **metrics keep the customer's vocabulary**: `On-time delivery` and `Delivered 31 of 33` both
  compare against the need date, which is a promise to someone outside the plant, and OTD is what
  that measure is called everywhere. Only the column moved, because only the column was naming an
  instant rather than a promise. `SimOrderOutcome.delivered` and the stored column keep their names
  too — renaming them would be a migration for a word.
- **One section per study, rows in sequence order.** A study is one production line and a plan is a
  line's plan. §7.2 releases strictly from the head with no reordering, so within a study release
  order *is* sequence order — "over time" needs no sort that could disagree with the Order column,
  and no Study column is needed. The heading appears only when a run carries more than one.
- **A run stored before v12 shows dashes in four columns, and before v13 in a fifth.** It did not
  record them, and that is what a blank says. Backfilling from today's demand would make one run a
  hybrid of two moments. A dash in Description is doubly ambiguous — it may equally mean nobody
  typed one — and that is tolerable precisely because the field identifies nothing.

_Rejected: a flat table sorted by start date across studies._ It shows the true interleaving of the
plant, which §7.7 exists to model — but it answers "what does the plant do next" when the person
holding the printout runs one line.

### 8.6 Colour by part

The app's first categorical palette, in `common/part_palette.dart`: eight fixed colours, assigned by
a part's position in the run's sorted part list, so one run always colours the same way and adding a
part to the plant never recolours a run that has not changed. Past eight it wraps.

- **One set, the same in both themes.** `app.dart` sets no `themeMode`, so the app follows the
  system and both surfaces are real. A screenshot taken in light mode therefore names the colours a
  reader sees in dark, which two tuned sets would have given up.
- **All eight sit at one luminance (≈0.165), and that is the whole constraint.** A hue clears 3:1
  against a near-white surface *and* a near-black one only inside a band of roughly 0.13 to 0.28
  relative luminance. These were solved to the middle of it: every fill clears at least 3.5:1
  against all four surfaces they sit on — page and card, in each brightness — and white clears
  4.5:1 on all eight, which is why every `onFill` is white.
- **So they are separated by hue, not by lightness**, at ≥ 35° around the wheel, and none of them is
  a low-chroma colour. This is not a preference. At one luminance the only axes left are hue and
  chroma, and the first draft's brown and olive were desaturated oranges that collapsed onto
  vermillion and gold.
- **The palette is a tested artefact, not a list of hexes.** `part_palette_test` asserts the contrast
  against all four surfaces, the label contrast, the hue spacing and the saturation floor. Writing a
  hex down says nothing about any of them, and the field is where the failure would otherwise show
  up. The first draft's collapse was caught by the test rather than by looking.

**The Parts table is the legend.** A swatch in its Part Number cell, taken from the row's own
position — which *is* the part's position in the sorted list — so the swatch and the bar cannot come
from two different lookups. It is defined there, beside that part's orders, on-time and lead-time
figures, so the reader learns the mapping while reading the numbers.

_Rejected: rotating hue off the seed colour._ Never runs out and always in the app's family — but
adjacent hues stop being distinguishable past six or seven parts, and adding a part recolours a run
that has not changed.

_Rejected: colour by study._ Fewer colours to pick, and it shows contention at a shared station.
Within one study — the common case — every bar is the same colour.

_Rejected: colour by part number rather than by part._ `DemandParts` is unique on
`{studyId, partNumber}` (§16.15), so two lines' `PN2` are two parts; merging them would give one
colour to two routings. §8.1.2 is the other half of this decision.

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
- **Batch Number is a label, and the only column that can never be wrong.** It is the planner's own
  identifier for a batch of a part — free text, no uniqueness, blank allowed, and nothing downstream
  matches on it. It sits between Project and Batch Size, the order §8.5's production plan reads in,
  which moved the three columns after it along by one: a paste block anchored by habit at the old
  Batch column now lands on Batch Number. `demandBatchSize` was relabelled from `Batch` to `Batch
  size` at the same time, because two adjacent columns both reading "Batch" is the ambiguity in
  miniature.
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

### 9.3 What identifies a part

A part number identifies **one part** inside a study. The unique key is `(study, part number)`, and
the customer's project — their programme or contract — is a label on the **order**, because what a
project describes is what a batch is *for*, not what the part is.

- **Everything that matches a part matches on the number alone.** The paste planner, the import's
  part lookup and the sequence grid's validation all fold through `partKeyOf`, which is the one
  place that spelling lives.
- **The Project column lives only on the sequence**, beside Batch Number, and is a label like it:
  nullable, unkeyed, blank allowed, and nothing downstream matches on it. Two orders of one part may
  name different projects, which is the case the old model could not represent at all.
- **It is not the FlowMap project the study sits in**, and never was — §3's project is a plant plus
  a shift pattern.
- The Parts grid is therefore `Part Number | Description | one column per step | Total`.

_Rejected, and reversed in v14: project **and** number together identifying a part._ The argument
was that a part number is the id of a part and different clients' projects legitimately order the
same one, so `PN2 on Wing 7` and `PN2 on Wing 9` were two parts with their own process times and
their own places in the sequence. The field disagreed. A part number means one part: the process
times are a property of the part, not of who ordered it, and making the project part of the identity
forced a planner to type `PN2` twice — and to maintain two sets of times — to say that one part goes
to two programmes. It also put a Project column on the Parts grid that was empty in every real
database, because nobody was using it the way the model assumed.

The reversal is not free, and §16.15 records what it cost: a database that *did* carry twins has to
keep both, since each has its own times and merging them would silently give every order of one the
other's numbers.

### 9.2 The import, as built

Pick, map and preview live in one dialog, because they are one decision: a mapping is only
judgeable against what it produces, and a preview with no way back to the mapping is a dead end.

- **An unmapped column is left alone, never cleared.** That is the one way an import differs from a
  paste: a paste's blank cell is a deliberate erasure, and a file that does not carry a column has
  said nothing about it. A mapped column is present in the row; an unmapped one is absent.
- **Nothing is guessed by position.** Headings are matched case- and punctuation-insensitively,
  against the destination's own name first and then a short synonym list (`WO`, `SKU`, `Qty`,
  `Due date`). A workcenter column is found by the step's own title. A column that cannot be placed
  is listed for the user; a file whose columns happen to be in our order is not evidence that they
  mean what we think.
- **A required column with nothing mapped disables Import entirely.** Every other problem is
  reported row by row, worst first, by the **line number in the user's own file** — a preview whose
  problems are on page four is a preview nobody reads.
- **An ambiguous heading is not evidence either.** `Batch` and `Lot` on their own name a column of
  quantities exactly as often as a column of lot identifiers, and now that both destinations exist,
  guessing wrong writes someone's batch number into Batch Size — silently, in every row. Neither
  claims them: Batch Size answers to `batch size`, `lot size`, `qty`, `quantity`, `size`, and Batch
  Number to `batch number`, `batch no`, `batch id`, `lot number`, `lot no`, `lot id`. A bare one
  lands in the unmatched list for the user to place, which is this section's rule about position
  applied to names.
- **Blocking versus warning follows §11.** An unknown part number, an unreadable date or time, a
  duplicated part, a batch size of zero: skipped. A need date before its material date: imported and
  flagged, because it is real data that is simply late.
- **Every imported order appends.** An import is a batch of new orders, not an edit of the sequence;
  replacing it implicitly would destroy work nobody asked to lose.
- **The reader normalises before anything else sees the file.** A spreadsheet date arrives as ISO
  (a spreadsheet date has no locale of its own, and guessing one is how `03/08` becomes the wrong
  day); a duration cell arrives as `HH:MM:SS`; a CSV's delimiter is sniffed from the header line,
  because a European Excel writes `;`; a UTF-8 BOM is stripped and cp1252 is decoded rather than
  thrown on, since a `Gehäuse` that raises an exception is a row nobody can fix.

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

**A workcenter type carries an icon** from a fixed library, and workcenters are drawn with their
type's glyph in the tree and the pickers — a lathe and a furnace told apart at a glance in a list of
fifty. Stored as an **enum name, never a codepoint**: Flutter's icon tree-shaking removes every
glyph the compiler cannot see referenced, so an `IconData` built from a stored number is a blank box
in release and correct in debug. `workcenterIconGlyph` is an exhaustive switch of `const Icons.*`,
which the compiler does see, and which cannot gain a member without gaining a glyph. Naming a type
guesses its icon until the user picks one by hand.

**The studies sidebar collapses.** A property of the window rather than of the project, so it is
held in the screen's state and does not follow the user to another machine. Its toggle follows the
project name in the app bar — still on the left half, so the argument stands that a control across
the window from what it moves reads as belonging to whatever is under it.

**Simulate is on the project's app bar, not on the Simulation tab.** A run spans studies and belongs
to the project (§7.7), so it should not require being on one of six tabs to start.

- **Pressing it never moves the reader.** A run takes a second or two on a background isolate
  (§7.1); being thrown out of a half-typed sequence cell to watch it is worse than not seeing the
  result the instant it exists. The spinner stays on the button, and a snackbar reports the headline
  with a single action that brings you to the rest. The tab controller therefore belongs to the
  workspace rather than to the tab strip — a controller one level below the button that needs it
  cannot be reached without threading a callback down and an index back up.
- **The disabled tooltip names the first thing in the way, and the study it belongs to.** §11's
  readiness panel is on a tab the reader may not be looking at, so the reason travels with the
  button. One reason rather than all of them: a tooltip is a sentence and the panel is the list.
- **The Simulation tab keeps the rest** — the rule to dispatch by, the runs already made, the
  readiness panel and the results. Only the trigger moved.

### 12.2 Canvas

Each node is a real Flutter widget positioned by the layout engine in a `Stack`; connectors, the
sawtooth lead-time ladder and the VSM symbol shapes are `CustomPaint`. `InteractiveViewer` gives
pan, zoom, fit-to-width and the % readout. Hit testing, hover, tooltips, focus and keyboard
navigation come free from the widget layer. A **separate renderer** draws the same layout model
into the `pdf` package, so exports are vector and text-selectable rather than screenshots.

**Material flow between nodes is a push arrow**, not a hairline: a striped shaft that spans the
whole gap, with a barbed head. That is the VSM convention for material that is pushed rather than
pulled, and it is what `drawPushArrow` has always been named for — the first implementation drew a
plain line under a doc comment promising the shaft.

**The map refits itself when the space it has changes** — the studies sidebar collapsing or
reopening, the window being resized or maximised, a step being added to the flow. It opened fitted
already; it now stays fitted.

- **Only while the view is still the canvas's own.** The transform installed by the last fit is
  kept and compared against what the controller holds. Once they differ the user has zoomed or
  panned, the view is theirs, and a sidebar toggle must not discard a deliberate zoom onto the sixth
  step of a flow — which is the same complaint `_zoomBy` was written to answer, arriving from the
  other direction. Pressing Fit installs a new transform and hands ownership back.
- **Compared, rather than tracked through gesture callbacks.** `InteractiveViewer.onInteractionEnd`
  fires for a bare tap that moved nothing, so a single tap on the canvas would otherwise be enough
  to stop the map ever fitting again.
- **The decision is `shouldRefitCanvas` in `flow_layout.dart`**, not a condition inside `build` —
  the same reason the arrow kinds moved there (§5.2): it can then be asserted without pumping a
  frame, and it is worth asserting, because one of its clauses is a **loop guard**. Fitting calls
  `setState`, which rebuilds, which asks again; at an unchanged size the answer has to be no, or the
  canvas fits forever and the app hangs rather than merely misdraws. Nothing in the suite mounts the
  canvas, so that is the one failure a test could not otherwise see.
- The sidebar is an `AnimatedSize` over 160 ms, so the refit runs at each width along the way and
  the map follows the pane rather than snapping after it.

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

### 12.5 The read-only tables are centred

Header and cells sit in the middle of their column in all seven result tables — the production
plan, the queue and share-of-flow rankings, the per-part table, the occupation table, and the takt
and workcenter schedules. `numeric: true` is gone from them.

- **The editable grid keeps its right-aligned numerics.** `DataGridColumn.numeric` exists because
  you *type* into those cells and scan a column of process times for the one that is wrong, and a
  ragged left edge is what makes the outlier visible. That is a different job from reading a
  finished figure, so the two families deliberately differ rather than being made uniform.
- **How it is done depends on whether the column has a declared width.** Six of the seven do, since
  §12.6, and centre inside it — `ResultColumn` carries the alignment and `result_table.dart` applies
  it. The takt table is the exception: it stretches to fill rather than declaring widths, so it
  keeps `centredColumn` / `centredCell` / `centredText` from `common/centred_table.dart`. Either way
  it is a wrapper rather than a flag, because Material offers start or end alignment and no third,
  and doing it inline at forty call sites would leave forty chances to forget one.
- **Action columns are not centred.** The takt and workcenter schedules end in edit and delete
  buttons under a blank heading. Those are not data read down a column, and the takt table stretches
  to fill its card, so centring would strand them mid-cell away from the row they act on. In a
  declared-width table that is `ResultColumn.centred: false`.
- **The mechanism is tested, because it is a fact about Flutter rather than about this app.** A
  `DataTable` sizes each column to its widest participant and lays every cell out at that width, so
  a `Center` inside one expands to the column. That holds for tables of two columns or more; with a
  single column the column is stretched to the full table width, the heading does not participate in
  the stretch the way a cell does, and the two stop agreeing. `centred_table_test.dart` uses two and
  also covers the stretched case — which is now the takt table's own case rather than a hazard the
  other six could still meet, since a declared width is a width whatever else is in the column.

### 12.6 A wide table scrolls, and says so

Every read-only table except the takt schedule is a fixed-height pane: the heading holds still, the
body scrolls under it, and both scrollbars pin to the pane's edges. `common/result_table.dart` and
`common/horizontal_scroll.dart` hold it; `DataGrid` uses the second of those for the same reason.

The starting point was a real defect and not a missing feature. All seven tables *already* sat in a
horizontal `SingleChildScrollView` — what none of them had was a way to drive it. A plain wheel has a
vertical job everywhere (rows in the grid, the page on the Simulation tab), Flutter flips a wheel's
axis only while Shift is held, mouse drag-to-scroll is off by default on desktop, and the one
`Scrollbar` in the tree was given no controller, so it held no position to drag and faded in only
*while* scrolling — which is the thing that could not be started. With fifteen workcenters on the
parts grid, or thirteen columns on the production plan, the table simply read as cut off.

- **The bar is always visible while there is something to reach, and it is draggable.** Both are
  stated rather than inherited: `thumbVisibility` needs a controller of its own, and Material makes a
  scrollbar a read-only indicator on Android and a control elsewhere. This is the whole answer to
  "there is no way to scroll", so it is a control on purpose.
- **The wheel is deliberately untouched.** Hijacking it would strand the vertical scroll the pane
  sits in: park the pointer on a production plan and the tables below it could never be reached.
  Shift+wheel keeps working for anyone who knows it; the bar is for everyone else.
- **The pane is bounded, because a bar at the foot of a thousand rows is a bar you cannot get to.**
  `resultTableMaxHeight` is 360 px, and it is one constant so that the Simulation tab has a single
  answer to "a section taller than it is useful" rather than one per section — the Gantt, when it
  lands, is the next thing to take it. It only bites once the content reaches it, so a five-row table
  shrink-wraps and looks exactly as it did.
- **Except where the page's own scroll is enough, and then `maxHeight: null`.** A bounded pane inside
  a page that already scrolls puts two vertical bars a few pixels apart, one moving the table and one
  the page, and nothing on screen says which is which. The occupation table is the case: a row per
  workcenter is long enough to reach the cap but short enough that the page can simply carry it. So
  it is unbounded, and sits last on its tab — it is the one section there whose length is not known
  in advance, and above a short fixed card it would push that card off the bottom behind a scroll.
  The rule this leaves: bound a table whose length the data decides without limit, let the page carry
  one whose length the plant decides.
- **`fill: true` widens the columns when the window has room to spare.** Declared widths keep a
  heading over its own column; they do not oblige a six-column table to leave the right-hand third of
  a wide window empty. It only ever widens — when there is less room than the widths ask for they
  stand and the table scrolls, because shrinking to fit would put back exactly the squeeze the
  declared widths exist to prevent. Every column scales by the same factor, so the proportions a
  reader learns in one window are the ones they meet in the next.
- **The heading is pinned, so it is two `DataTable`s over one declared width list.** Material sizes a
  column to its widest participant, so two tables agree only if handed the same width — which is why
  `ResultColumn` carries one and why the heading cell and every body cell are built through the same
  helper. The plan has four adjacent date columns; a label over the wrong column is a misread, which
  is worse than a heading that scrolls away. The gutters are set to nothing so that
  `ResultColumn.width` describes the column it names — `DataTable`'s defaults would put 672 px of air
  into a thirteen-column plan.
- **The vertical bar sits outside the horizontal scroll view**, holding the inner controller. Nesting
  alone cannot pin both bars: inside, the vertical bar lands on the *table's* right edge, which on a
  wide table is off screen. The cost is that its track then spans the heading too, and Material's
  `Scrollbar` does not expose `RawScrollbar.padding` — it falls back to the ambient `MediaQuery`, so
  the inset is handed to it that way and the real one restored underneath.
- **Four facts are tested, because none of them has a compiler behind it**
  (`result_table_test.dart`): every heading sits over its own column, the heading holds still while
  the body scrolls, it tracks the body sideways, and each bar drags its own axis. The third is not
  redundant — a heading placed outside the horizontal scroll view would pass the second and be wrong.

**Not the takt table.** It fits, and §12.5 stretches it to fill on purpose; declared widths would end
that stretch for no gain. The app therefore has two read-only table shapes, which is a real cost and
is written down rather than left to be discovered.

**The parts grid freezes its part number** (`DataGrid.frozenColumns`), because a bar you can drag is
not on its own an answer to fifteen workcenters: the grid is ~2 500 px wide, and scrolling out to the
twelfth station takes with it the one column that says which part the row you are typing into belongs
to. The row header goes with it.

- **Two lists, kept equal.** The frozen cells sit outside the horizontal scroll view — that is what
  makes them frozen — so they cannot be rows of the same list as the cells inside it. Each pane
  pushes the other, so the wheel works over either; a re-entrancy guard is what stops that being a
  loop, and the follow clamps rather than trusting the extents equal.
- **Row height and heading height are declared, for the reason column width is.** The frozen pane
  carries the row header and the scrolling one the row actions, and an `IconButton` is 48 px where a
  cell is 44 — so the two panes drifted four pixels further apart with every row down the grid, which
  is invisible at the top and unusable by row ten. `itemExtent` also makes the two lists' scroll
  extents identical rather than merely similar. The heading has the same problem from the other end:
  a column with a `helper` under its title is two lines where one without is one.
- **A cell keys its focus node by absolute column**, so Tab crosses the seam without knowing there is
  one. That was true before the split and is what made the split cheap.
- **The sequence grid does not freeze anything.** Six columns fit, and a second scroll position that
  cannot disagree beats one that merely does not.

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

**The result tables are the exception to "ordinary lazy lists", and knowingly so.** A `DataTable`
builds every row, so a 2000-order production plan constructs 2000 rows to show the seven that fit
§12.6's pane. That was true before the pane existed; what the pane changes is that it now *looks*
lazy. Left alone deliberately: real runs are tens of orders, and the run that would produce 2000 of
them does not yet meet the run-time target stated above — so optimising the table before the engine
that feeds it would be the cheaper half done first.

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
| **M3** ✅ | Demand grids, Excel import, flow equivalent, MM3, Summary/occupation. |
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
| `openTimeBetween(from, to)` | capacity in a window (occupation, utilization) |
| `advance(from, work)` | when `work` of open time finishes (lead time, simulation) |
| `retreat(until, work)` | when `work` of open time would have to begin (§7.8, added in M4) |
| `openWindowFrom(from)` | the open window containing or following `from` (§7.1's dispatcher, M4) |

`advance` and `nextOpen` throw `StateError` rather than looping if the calendar can supply no
open time within ten years — the simulation's abort guard (§7.8) depends on that failing loudly.

### 16.2 M2 as built

Schema v2 (migrated in place on an existing v1 install), the project layer, the study workspace,
both schedule editors, the VSM canvas and PDF export. 144 tests.

The seam that joins M1 to project data is `SchedulesRepository.loadWorkcenterCalendar` — the only
place a `WorkingCalendar` is constructed outside a test. It pulls the plant's shift pattern, the
workcenter's staffing over time, and the project's exceptions narrowed to that workcenter.

Decisions taken while building it:

- **A workcenter's line is where it is drawn, not what owns it.** The resource tree is
  Plant → Cell → Line → Workcenter, but studies on different lines must be able to share a
  workcenter (§7.7). So the plant owns it and the line is a filing arrangement; deleting a line
  leaves its workcenters on the plant rather than destroying them. (Shipped as a single
  `homeLineId`; §16.7 replaces it with a set.)
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

### 16.5.1 Schema v9, from field feedback

- **An order has no order number.** It shipped in M3 and was work for nothing: a simulation
  identifies an order by the row it is, the planner already holds a works order number in their own
  system, and retyping it bought nothing any calculation reads. Dropped by a table rebuild, guarded
  on `from >= 6` for the reason §16.4's guards exist — the v6 step builds `demand_orders` from the
  *current* definition, so an older database never had the column.
- **A part carries the customer's project** — their programme or contract, not the FlowMap project
  the study sits in. Shown beside the part number in both grids and read-only in the sequence,
  because a project belongs to the part and two rows of one part must not disagree about it. Part
  numbers stay unique per study; if the same number recurs across two customer projects that key
  has to change, and it is worth deciding deliberately rather than discovering.

  **v10 made that change, and v14 reversed both** (§9.3, §16.15): the project is a label on the
  *order* now, and a part number identifies one part. The closing sentence above turned out to be
  the right instinct pointed the wrong way — the recurrence it worried about is the normal case, and
  the answer was to stop keying on the project rather than to key harder.
- **MM3 shows the part's equivalence and the slot's load as two columns.** They were one, headed
  "Equivalent", carrying `eq(part) × batch` — so §6.2's quantity, which belongs to the part and does
  not move, appeared to drift between orders. Reported from the field as a calculation bug; it was a
  labelling one. MM3 still averages the slot load (§18.7), which is the figure levelling is about.
- **Arrows stop at a buffer's triangle, not at its slot.** An inventory node occupies a full node
  width so the spine stays evenly spaced, but draws a 56-pixel symbol, and the connectors were
  running to the empty slot edge — which left a gap either side and made the triangle look off
  centre. The triangle now also sits *on* the spine rather than above it, with its labels beneath.
- **A pool's process box is marked `#N`.** A reader comparing two boxes has to know which one is
  four machines; it was only in a tooltip.

### 16.6 M3 as built

Schema v6, the demand layer, the two data sources that read it, MM3, the Summary, the spreadsheet
import, and the two things §17.5 listed as built-but-unreachable. 350 tests.

The seam M3 adds is `DemandTable` — the study's parts, the flow's steps as columns, and the times
between them. Everything downstream reads it: the map's two demand data sources (§6.2), MM3 (§6.3),
the Summary (§8) and, in M4, the engine.

Decisions taken while building it, beyond §9.1, §9.2, §6.2 and §8.4:

- **Splitting `processTime` from `equivalentProcessTime` closed a provider cycle the long way
  round.** With the map reading demand to show a real part, `demandTableProvider` could no longer
  read `flowViewProvider` for its column headers. Both now derive a header from one
  `flowStepTitle`, so a step renamed on the map still renames its column, and the dependency runs
  one way: `mm3 → flowView → flowDemand → demandTable`.
- **`FlowStepView.openInPeriod` is computed where the calendars already are.** Occupation's
  denominator is a walk of real dates across the whole span, not a working-day count times a daily
  figure; computing it in `buildFlowView` means the Summary and the process box divide by the same
  hours by construction.
- **A pool-scoped calendar exception is expanded to its members on entry.** The schema's scopes are
  plant, line and workcenter, and a pool is a name for a set of workcenters rather than a fourth
  kind of place — so the picker offers pools and the repository stores one workcenter-scoped row
  per member. No migration, and every lookup downstream stays a map hit.
- **The mounting tests paid for themselves three times.** The Import button pushed the Demand
  header past the bottom of a short window; the import dialog read localizations in `initState`,
  which is an assertion failure and a blank grey panel in release; and a Drift stream inside
  `fakeAsync` leaves timers pending that the binding fails on after the tree comes down, which is
  why the tab tests override providers with plain values instead.

### 16.7 Schema v7, from field feedback

- **A workcenter is filed under a *set* of lines.** `workcenters.home_line_id` allowed exactly one,
  so "add existing" to a second line was a move, not an addition — and a station shared by two
  lines, the case §7.7 exists for, could not be drawn. Replaced by `workcenter_lines`, a plain
  join table. The editor offers checkboxes rather than a dropdown, since a single-choice control is
  what made the removal silent.
- **The migration harvests `home_line_id` before any step runs, not in its own step.** The v3 step
  rebuilds `workcenters` from the *current* Dart definition, which no longer has the column — so on
  a v1 or v2 database it is already gone by the time the v7 step is reached. The rebuild that drops
  it is then guarded on `from >= 3`, the mirror image of the `from >= 2` guards in §16.4. Both
  directions of this trap have now been paid for once.
- **A v6 fixture was added to the migration tests.** v1 and v2 both reach v7 with the column already
  dropped, so neither of them exercised the branch a real user upgrades through. DATA.md asks for
  one fixture per version that has been on someone's machine, and v6 is the one that shipped.
- **A dialog's Save button must derive from its controller, not remember alongside it.** The name
  prompt cached its validation error and called `setState` only when that error *changed*, so
  typing a good name into an empty field rebuilt nothing and Save stayed disabled — every resource
  the prompt creates could only be saved with Enter. It is now built inside a
  `ValueListenableBuilder` on the controller, which leaves nothing to forget to refresh.

### 16.8 M4, first slice

The engine's inputs and the two walks it needs before it can start. No event loop yet, no storage,
no UI.

- **`SimStudy` and friends carry no Drift handle.** A run is assembled from the database once and
  then handed to a pure engine — which is what lets it be driven from a three-line test and, when
  the UI lands, from a background isolate (§7.1), because an isolate can only be passed things that
  hold no database connection.
- **The resource model is one workcenter per station**, however many studies point at it (§7.7).
  That is the whole reason a run is a plant-level object rather than a study-level one.
- **A buffer's wait is resolved before the run.** A quantity buffer is `pieces × takt` and which
  takt depends on the period — a question the map already answers. The engine is handed a duration
  and does not ask where it came from.
- **`WorkingCalendar.retreat` is the mirror of `advance`.** A run begins at the first order's need
  date minus its theoretical lead time (§7.8), and "minus" there is a walk, not a subtraction:
  taking fifteen open hours off a Monday morning lands on the previous Friday, not on the Saturday.
  Tested as a round trip — `retreat(advance(t, w), w) == t` — across the ABC pattern, whose
  overlapping night shift is exactly where a naive reversal would drift.
- **Availability and rework are read at the day the step starts**, not once for the run, because a
  walk may cross a schedule boundary. `effectiveProcessTime` has been waiting in the calendar
  feature since M1 for this one caller (§17.5).
- **The engine's occupancy and the Summary's occupation are the same arithmetic from two ends.**
  Inflating a step's time by `(1 + rework) ÷ availability` and spending open time gives exactly
  `required ÷ (open × availability)`. §7.6 reads as though rework should inflate changeover too;
  it does not, here or in §8.4, because rework is a loss on the work a *part* requires (§6.1).

### 16.9 The event loop, and what it cost to make it fast

The engine as built: a binary heap of timestamped events, one shared resource model, and a settle
pass that starts whatever can start.

- **All events at one instant, then one settle.** Dispatching after each event in turn let whichever
  arrival happened to be dequeued first take a free workcenter — so the queue's insertion order beat
  §7.4's rules, and two studies releasing on the same slot ignored their priorities. Caught by the
  test for exactly that. An event may schedule another at the same instant; that is picked up by the
  same pass, not left for the next.
- **The dispatch decision is made when a station actually opens**, not when it goes idle. A server
  with work but closed schedules a wake at its next opening and chooses there, so an order arriving
  overnight is not beaten to the shift by one that merely queued first.
- **Free stations are tried least-busy first, then by name** — §3.1's pool tie-break, and the reason
  a run of the same inputs cannot reorder itself.
- **Every ordering falls through to keys that cannot tie**: arrival, then study priority, then
  sequence number, then order id. Determinism is not a nice-to-have here (§4.4) — the output is a
  headcount decision.
- **The first order of a run never pays a changeover.** Cold start means no previous order on the
  station, and §7.6 charges only for a *different* part number.
- **The engine's occupancy and the Summary's occupation are the same arithmetic.** Inflating a
  step's time by `(1 + rework) ÷ availability` and spending open time equals `required ÷ (open ×
  availability)`. Availability derates the setup too; rework does not, matching §8.4 and §6.1.

**Performance.** The first working version took **6.2 s** for §14's target of 2000 orders through 10
steps — against a stated "well under a second". Measured rather than guessed at, and the cause was
not in the engine at all:

- **A local `DateTime(y, m, d)` costs ~13 µs on Windows; its UTC twin costs 0.03 µs**, because every
  local construction asks the OS for a zone offset. `dateOnly` is the hottest call in the app.
- Memoising it — verified against each day's real `[midnight, next midnight)` range, so a 23- or
  25-hour daylight-saving day is still exactly one day — and memoising a day's shift windows on the
  immutable calendar took the same run to **2.8 s**, with no behaviour change and all 91 calendar
  tests still passing.
- Routing `_nextDay`/`_previousDay` through the same cache was tried and **made it worse** (4.4 s):
  the previous-day lookup lands in a different cache slot and thrashes it. Reverted.

2.8 s is measured under `dart run`'s JIT; the shipped build is AOT and the run happens on a
background isolate (§7.1), so nothing freezes. It is still short of §14, and the remaining cost is
the same one: local `DateTime` arithmetic throughout the calendar. Closing it properly means working
in epoch integers inside `WorkingCalendar` and converting only at its edges — a real refactor of the
most heavily tested code in the app, worth doing deliberately rather than in the margins of building
the engine. Recorded here so the next person starts from the measurement rather than from the guess.

### 16.10 M4, as built: storage, assembly and the tab

The engine had nowhere to put a run and no button to press. Schema **v11** adds six tables, and the
Simulation tab (§12.1) is the first thing in the app that can start one.

- **Nothing a run stores points at a study, a part or a workcenter with a foreign key**, and the
  names are copied in rather than joined to. That is the whole point of §7.10: a run has to stay
  readable after the plant beneath it is edited, and a cascade from `studies` would destroy the
  evidence exactly when someone re-scoped a study to find out why last month's run said what it
  said. The one cascade that is right is from the project, which owns the run outright.
- **Each order's theoretical lead time is stored with it.** It is the one figure §8 asks for that
  needs the *plant* rather than the result — §7.9 walks it through calendars that may have been
  edited since — so it is frozen at the moment of the run like the names are.
- **A stored run and a fresh run report through the same function.** `computeRunMetrics` splits
  into `theoreticalLeadTimes`, which needs the plant, and `summariseRun`, which needs only what is
  in storage. What a run reports therefore cannot drift from what it reported when it was made,
  which is what M5's run comparison rests on.
- **Enums are stored as plain names, not `textEnum`.** Drift's typed version throws on a value it
  does not know, so a single run written by a later build would stop an older one from opening the
  list at all. The repository parses and falls back to the default.
- **The run is assembled twice.** §7.2 resolves the takt at the run's start, and §7.8 puts that
  start a theoretical lead time before the first need date — which cannot be walked until the study
  has been assembled. So the first pass uses the need date, the plan it produces gives the real
  start, and the second resolves the cadence there. There is no third: chasing a fixed point is the
  mid-flight takt change §18.3 has not settled, and a run keeps one cadence throughout.
- **Readiness is carried per study, and `canRun` requires all of them.** "A step has no workcenter"
  is not actionable until you know whose step it is, and a run the user asked for over three studies
  that quietly ran two would report a plant that was never contended for (§7.7).
- **Simulate is disabled by the same pass that would have built the run.** There is no second
  opinion about whether it is ready: `SimRunInput.canRun` gates the button, and the notifier behind
  it checks the same value rather than trusting the caller.
- **The tab opens on the run that was last made.** Most of what storing a run buys is that closing
  the app is not the same as throwing the answer away.
- **Simulation sits in the same tab strip as the five study tabs**, but switching studies does not
  throw the reader out of it — the other five reset to Flow, as they always have, and Simulation is
  not about the study that was just switched away from.

### 16.11 The upgrade that could not be replayed

Running the built exe against the developer's own database — the first time any of M4 had been
driven by hand — found the app unable to open it at all. `user_version` said **6**; the tables said
otherwise. `workcenters` had already been rebuilt by the v7 step and lost `home_line_id`,
`workcenter_lines` existed, `workcenter_types.icon` existed — while `demand_parts` and
`demand_orders` were still in their v6 shape.

**A migration cannot run inside a transaction.** `alterTable` needs foreign keys off, and SQLite
refuses to change that mid-transaction. So a step that throws leaves the database *part* upgraded
with its counter unchanged, and every later open replays from a number that no longer describes the
tables. Here the very first thing `onUpgrade` did was read `workcenters.home_line_id` — a column the
interrupted run had already dropped — so the replay died before it could reach the steps that were
genuinely outstanding. One interrupted upgrade had locked the user out of their own data
permanently, and no amount of restarting would help.

**Every step now asks the database what it has rather than inferring it from `from`.** `_hasTable`,
`_hasColumn`, `_ensureTable` and `_ensureColumn` make a step that has already run a no-op instead of
an error. That also retires the `from >= 2` and `from >= 6` guards this replaces: those were the
same lesson, learned one column at a time and re-derived by hand each time a column was added, and
they could only ever express what a *complete* earlier upgrade would have left behind.

The fixture for this state is in the migration suite beside the version fixtures, because it is not
a version — it is the shape an interrupted upgrade leaves, and it is the one that was actually on a
machine. The real database went v6 → v11 with everything intact: 40 workcenters, their 59 line
memberships, the pool and its members, the study's 13 flow nodes, 5 parts, 35 process times and 33
orders.

### 16.12 Two things only running it could show

Driving the built exe through a real study found both of these in the space of a few clicks, and
neither was reachable from any test in the suite.

- **The process box was two pixels too short.** `FlowMetrics.nodeHeight` was a flat `186.0` under a
  comment claiming it fitted the eight data rows the box can carry. It fitted seven: Equivalent
  appears only under a demand data source (§6.2), so switching the map to one overflowed the box —
  yellow stripes in a debug build, silently clipped in a release one. It is now spelled as the sum
  of its parts (`nodeHeaderHeight + padding × 2 + rows × rowHeight`), so the next row added resizes
  the box with it instead of quietly running out of room.
- **`1 studies in this run`.** The count was interpolated into a string. It is an ICU plural now, in
  all three languages — and the `=0` arm says "No studies selected" rather than counting to zero.

### 16.13 Schema v12, from field feedback

Five nullable columns and two tables, all additive — no table is rebuilt, so this step cannot leave
one half-rebuilt on a machine that has already survived §16.11 once.

- **`demand_orders.batch_number`.** The planner's own identifier for a batch of a part number —
  `B-0012`, `LOT7`. Nullable and unkeyed, because it is a **label and not identity**: unlike
  `customer_project` (§9.3), which had to be identity because a part number alone is genuinely
  ambiguous, the order a batch number names already has an identity in its sequence position. Two
  orders may carry the same one, or none. It is the mirror of v9's removal of `order_number`,
  reaching the opposite answer for a different reason — nobody needed a works order number the
  simulation identified by row, but a planner reading a printed plan does need the number their
  paperwork is filed under.
- **`simulation_run_orders` gains `customer_project`, `batch_number`, `batch_size`,
  `material_date`.** What §8.5's production plan reads and the engine does not, copied in for §7.10's
  reason: the plan has to keep saying what it said after the demand beneath it is re-sequenced or
  deleted. **Never backfilled** — a run stored before v12 has no answer, and a blank saying so is
  true; filling them from today's demand would make one run a hybrid of two moments, which is the
  exact thing the copy-in rule exists to prevent.
- **`workcenter_dispatch`** — a station's queue discipline where it differs from the run's (§7.4).
  Keyed by target, so a pool is a target for the reason `part_process_times` is keyed that way: the
  queue forms at the pool, not at whichever member stands for it on the map. Project-scoped, because
  a run builds one resource model and a station exists in it once however many studies point at it
  (§7.7) — a study-scoped rule would let two studies demand different disciplines of one machine.
  A missing row means "use the run's rule", which keeps a station never touched distinguishable from
  one deliberately set back to FIFO.
- **`simulation_run_dispatch`** — one row per override, so a stored run still explains its own
  numbers. `simulation_runs.dispatch` alone would report FIFO for a run in which three stations
  dispatched by due date, and M5's comparison could not say the dispatch is what differed.
- **`DispatchRule` moved to `data/database/enums.dart`.** A stored column has to name it, and the
  schema cannot import `sim_model`, which reaches the calendar. `sim_model` re-exports it, so every
  existing caller is untouched. The run tables still store it as plain text and parse on read, for
  the reason recorded on `simulation_runs.dispatch`; the live project table uses `textEnum`, as
  every other project table does.
- **A rebuild step is a hostage to every future column.** The v9 step that drops `order_number` is a
  `TableMigration`, and `TableMigration` copies column by column from the **current** Dart
  definition — so the moment `batch_number` was added, that step began reaching for a column no
  v6-shaped table has ever had, and the upgrade died three versions before the one that introduced
  it. It now names a constant `NULL` for it in its `columnTransformer`, and every future column on
  `demand_orders` needs the same line. Caught by the existing v6 and v8 fixtures, which is what they
  are for.

### 16.14 Schema v13, from field feedback

One nullable column: **`simulation_run_orders.part_description`**.

`demand_parts.description` has been stored since M3 and the Production Plan could not reach it,
because §7.10 forbids the join that would. So it is copied in at save time, the same shape v12 gave
`customer_project` — a passenger on `SimPart` the engine never reads, written by `saveRun` and read
straight back out with the plan. A part re-described or deleted since would otherwise rewrite what
a finished run says, which is the failure the copy-in rule exists to prevent; it had already been
rejected twice, in §16.13 and in §8.5, and rejecting it a third time is the rule working rather
than a decision being re-litigated.

- **It identifies nothing.** Two parts legitimately share one description — the field's own
  database has `PN2` and `PN4` both reading `AWB 10K 1.0` — so it is a label on the row, never a
  key, and it takes no part in any unique constraint. That is what separates it from
  `customer_project`, which had to be identity (§9.3) and is therefore blank-not-null.
  `part_description` is genuinely nullable: a part nobody described carries no description.
- **Never backfilled**, for §7.10's reason. A run stored before v13 shows a dash.
- **No rebuild, and no hostage.** `simulation_run_orders` is never touched by a `TableMigration`,
  so §16.13's closing warning — every future column on `demand_orders` needs a constant in the v9
  step's `columnTransformer` — does not reach this table. `addColumn` through the idempotent
  `_ensureColumn` is the whole step, so an upgrade interrupted here replays cleanly (§16.11).
- **Two tests, one per link of the chain**, because §16.13's own experience was a column that
  existed and nothing wrote: the assembly test asserts a `DemandPart`'s description reaches
  `SimPart`, and the run-storage test asserts it survives `saveRun` → `loadRun` and comes back on
  the plan row. Removing either half fails exactly one of them.

### 16.15 Schema v14, from field feedback

The customer's project moves from the part to the order (§9.3), reversing v10. `demand_parts` loses
`customer_project` and keys on `(study, part_number)`; `demand_orders` gains it, nullable and
unkeyed like `batch_number`.

**Three steps, and their order is the migration.** The values have to be read off the parts before
the column carrying them is dropped, and the numbers have to be made unique before a key demanding
it is applied:

1. Copy each order's project down from the part it is for. Blank becomes **null** — on the part an
   empty string was forced by SQLite's UNIQUE treating NULLs as distinct (§16.2); on an order, in no
   key at all, null is what "none" honestly is.
2. Disambiguate twins. Two parts differing only by project are about to collide, and **both are
   kept**: each has its own `part_process_times`, so merging them would silently give every order of
   one the other's numbers, which is §11's one intolerable bug. The earliest keeps the number the
   planner typed and the rest gain ` (project)`, so the rename is legible on the Parts grid rather
   than mysterious. A part with no project falls back to a fragment of its id — ugly, unique, and
   only reachable for an unprojected part that is not the earliest of its twins.
3. Rebuild `demand_parts` from the current definition, which drops the column precisely by not
   naming it, and takes the new key.

**Two older steps had to change, and the second is the interesting one.**

- The v9 step adds `customer_project` to `demand_parts`, and Drift can no longer name a column the
  current definition does not have. It is raw SQL now, still guarded so it stays idempotent. The
  step cannot simply be deleted: a database arriving from v8 has to grow the column here so v14 can
  read it, and lose it there.
- **The v10 step had to go entirely.** It rebuilt `demand_parts` to make the project non-null and
  put it in the key — via `TableMigration`, which copies from the **current** Dart definition. That
  definition no longer has the column, so replaying v10 would have *destroyed the very values v14
  exists to move*. Nothing is lost by dropping it: every upgrade that would have run it now runs
  v14, which rebuilds the same table with the right shape and key.

That is the mirror image of §16.13's warning, and worth stating as its own rule: **a `TableMigration`
in an old step is a hostage to every future column — and to every column ever removed.** Adding one
needs a constant in its `columnTransformer`; removing one can invalidate the step altogether.
`demand_orders`' new `customer_project` needed the constant, and is the second column to.

_Rejected: merging twins onto one part._ Tidier, and the part numbers stay untouched — but the
second part's process times vanish without the user being told, and every order that took 3 h at
CLAD04 silently starts taking 4 h.

_Rejected: refusing to migrate and naming the collisions._ Safest of all, and §16.11 is the record
of what a database that cannot be opened costs.

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
| ~~Calendar exceptions (§4.3)~~ | **reached in M3** — entered on the Workcenters tab, beside the schedules they override; a pool is expanded to its members on entry | — |
| ~~Supplier / Customer names (§16.2)~~ | **reached in M3** — the endpoints on the canvas are clickable, and an emptied name puts the default back | — |
| ~~`flow_nodes.notes`~~ | **reached 2026-08-05** — a field in both node editors, a marker on the box, the words in the tooltip and a findings list on the PDF (§5.4) | — |
| The decorative layer (§5.2) | table, enum, five repository methods, provider | M5 — nothing draws or creates an annotation; `duplicateStudy` deep-copies a table that is always empty. §5.4's node notes deliberately do **not** use it |
| `DiagnosticsLog.compose` / `addFeedback` | written, never called | M5 — there is no About screen (§12.1), so the log has no in-app way out |
| ~~`wipCap`, `priority`, `effectiveProcessTime`, `availabilityOn`, `reworkOn`~~ | **reached in M4** — the engine walks dates rather than periods, which is what the two `…On(date)` accessors were written for | — |

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
7. ~~MM3 batch weighting~~ — **confirmed 2026-08-04**: an order of ten pieces reads as ten takts of
   load in the sequence, because one slot releases one order whatever its size. Lot sizing is
   therefore visible to the one tool that should see it, and M4 releases against the same reading.
   (§6.3, M3)
8. ~~Demand takt denominator~~ — **confirmed 2026-08-04**: measured at the bottleneck's available
   hours. A line has no single calendar of its own, and the constraint is what sets the pace.
   (§8.2, M3)
9. **One plant per project**, per the spec; a project cannot span plants. (§3, M1)
