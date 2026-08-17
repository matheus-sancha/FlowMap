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

**A run keeps the members and gains the name.** Field feedback, 2026-08-15, from the first run driven
with two studies in it: `CLAD07` read as a loose machine, because a run's stations are workcenters
and nothing recorded what the reader had actually typed on the map. The members stay individual —
that is what says which machine ran an order, and it is the per-machine yardstick this section
protects — and the pool is stored beside them (§7.10) so the surfaces can put the word back.

**The Gantt groups; the Queue and Share tables label.** The chart runs down the page in flow order,
where a pool's machines already sit together, so naming the pool on each of their rows costs nothing
and its lane has somewhere to attach (§8.6). §8.1's two tables are *rankings*: their first row is the station that
queued most, and clustering their rows by pool would mean the first row stopped answering that. They
name the pool beside the station instead.

_Rejected: one aggregate row per pool._ Closest to how a planner speaks about it, and it needs a
summed denominator that discards exactly the per-machine reading the paragraphs above are defending.

**A workcenter may itself hold more than one order at a time** — `parallel_capacity`, one by
default. The engine gives it that many servers, and they are independent in every way that matters:
each has its own clock, its own busy total and its own memory of the last part it ran, so two units
of one machine pay changeovers separately. That is what running two orders at once *is*.

**A pool is the precedent, not the alternative**, and the arithmetic is deliberately identical: a
station's units raise its capacity exactly as a pool's members do, and leave the per-machine
yardstick alone. So §8.4's occupation halves for two units while §6.1's flow equivalent still reads
one machine — which is what a pool of three already does, reporting 63 % occupation against an
equivalent of 0.99.

**Units multiply capacity and never the clock.** §7.2 measures a takt given in days on the pace
setter's *productive day*, so folding units into that figure would stretch the release cadence — and
how many machines a station has is not how long its day is. Utilization's denominator does take
them, because its numerator is summed across units: counting one clock against two servers' work is
how a busy station comes to report 200 %.

_Rejected: modelling it as a pool of invented members._ It needs no code at all — and it puts two
machines that do not exist into the plant, the Summary, the Queue table and every Gantt thereafter.

_Rejected: treating it as a batch process._ An oven or autoclave holds several orders in one window
and does not take twice as long for the second, which is a different model: it needs a loading policy
and a process time belonging to the load rather than to the batch size, contradicting §7.6. The
observed data decided it — TTAT's process times scale with batch size, so it is two units.

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

**It derates the part's work only, not the changeover** (§7.6). Setup and teardown are typed in a
station's productive day, which already has availability taken out of it, so derating the result as
well would apply the loss twice — the trap this section's own rule exists to prevent, seen from the
capacity side in §6.1.

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

- **Semantic** (on the spine, carry data, feed every calculation): Process step, Supplier, Customer
  — and the **queue on the link into each step**, which is not a node (§7.3).
- **Decorative** (free-placed annotation, never affects numbers): shipment truck, supermarket,
  kanban post, production-control box, information arrows, kaizen burst, operator icon, text note.

Kanban *rules* live in the study's release settings (§7.3), not in the kanban icon — drawing
documents intent; the number that drives the engine is typed where it can be validated.

**The arrow is the queue, and the queue type chooses it.** Every link on the spine is drawn from
something stored where it could be validated — the study's WIP cap, and the discipline on the queue
in front of the step the link runs into:

| Drawn | When | Why that is honest |
|---|---|---|
| **Push** — hatched shaft, with the inventory triangle beneath it | no discipline is set | Material moves downstream whether or not the next step asked, and piles up where it lands. The hatching *is* the mark of a push; the triangle says how much is standing there. |
| **Pull** — bare shaft | no discipline, and the study has a CONWIP cap (§7.3) | A release that requires a completion is a pull system. It is study-wide, so it reaches every link. |
| **A channel** — two rails, the rule's word between them, a tick in and a solid triangle out | the queue is set to FIFO, LIFO, EDD or SPT | Someone decided the order that queue comes off in, and a sequenced lane is what that is. |

**One channel shape for four rules, labelled.** The FIFO symbol already *is* a channel with `FIFO`
written in it, so `LIFO`, `EDD` and `SPT` in the same channel extend the convention rather than
inventing three glyphs — and nothing can be misread as a standard symbol meaning something else.
_Rejected: a colour per rule._ Cheap and legible on screen, and §13's PDF on a shop-floor wall is
often greyscale, where colour carrying meaning alone does not survive.

**Push and pull share a shaft; a channel does not.** This section used to say all three were one
shaft told apart by what went inside it, and the drawing followed: a hatched arrow with a divider
line and the word written above. That was a principle invented to describe an implementation. A
reader of a real value stream map recognises a FIFO lane as a *channel* — a fixed width, so it holds
a sequence rather than a pile; an entry mark and an exit mark that differ, so it has a direction —
and none of that is available to an arrow. So the channel is its own figure, and the two that
genuinely are variants of one shaft remain variants of one shaft.

**A link that carries a queue is drawn as wide as a process box.** The lead-time ladder puts one rung
over each link and one under each box, so equal slots make equal rungs — and a 64 px gap truncated
`FIFO COATING` to `FIFO COA…` the first time this was driven. The one link that stays narrow is the
last, into the customer: not a station, no queue, nothing to make room for. _Rejected: sizing the
ladder independently of the map._ Rungs would be equal at any gap width, but a rung that does not sit
under the box or link it measures reads as the wrong one's time.

**The ladder alternates strictly, and a queue rung is drawn even when it is zero.** That is what makes
the comb regular; a queue holding nothing has a real answer rather than no answer. A link whose queue
is null contributes zero — an unbound step has no floor space, and the *second* link into a station a
flow visits twice was already counted at the first — which is what keeps the rungs summing to the
footer's lead time (§17.4). The first build overlapped a queue's rung with the process rungs either
side by half a gap, and `LeadTimeLadderPainter` draws its riser at each rung's `left`: the path
doubled back 32 px at every queue, which is what made the teeth stubby and misplaced on the field's
first look at it.

Its stroke is 1.2 px, the same weight as the factory, the inventory triangle and the pool badge,
for the reason §1.7 gave the badge: a symbol drawn in a different weight reads as pasted onto the
map rather than part of it. The channel is sized to the 64 px gap the layout leaves between nodes,
and drops its label rather than overrunning its own rails when a gap is narrower than the word.

- **The kind belongs to the arrow's destination.** A queue forms in front of a station, so it is that
  station's discipline the channel describes. The last link runs into the customer, which is not a
  station and has no queue, and falls back to the study's own kind.
- **An unset rule draws a push, not a FIFO.** The engine takes an undisciplined pile in arrival order
  because something has to be first, so "does this queue behave as FIFO" would be true everywhere and
  a channel on every link would say nothing. A stored rule is a decision; an absent one is not.
- **A queue beats the cap on the link it marks.** The cap describes the flow, the queue describes one
  line in it, and the more specific of the two is what gets drawn.
- **A shared queue is drawn once.** Two steps of one flow on one station have one floor space between
  them, so the triangle and its figure go on the first link into it — and the lead-time ladder counts
  it once. The *discipline* still marks every link into that station: what is deduplicated is the
  stock, not the rule.

_Rejected: a push/pull/FIFO picker per link, storing nothing._ Total freedom to draw the current
state as it really is, including flows the engine cannot run — but it creates a second source of
truth about the flow, free to disagree with the engine, which is exactly what §5.3 exists to prevent.
What §7.3 does instead is make the link the place the *stored* queue is edited, so the picture and
the engine read one row.

**The printed map labels rather than redraws.** `flow_pdf.dart` builds its map from the `pdf`
package's own widgets so text stays selectable and the document stays vector; it does not replay
`VsmSymbols`' paths, and a comment there claiming otherwise has been corrected. A pull link says
`PULL` and a channel writes its own word — the same word the canvas puts between the rails, so the
two drawings of one map read alike — and a push says nothing, because a caption on every arrow is
noise.

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

**A box costs one order, not one piece** (§7.6). Process times are stored per piece, and the map
multiplied by nothing — so an order of ten read a tenth of what the engine charged it, and the map's
lead time could not be compared with any figure a run reports. It now shows
`pt × batch × (1 + rework)`, and the **changeover is in the lead-time ladder** rather than being a
figure on the box that fed no total. Reported from the field as *"I'm adding setup and breakdown
time, but it's not changing the LT of the station"*, which it did not.

- **The batch comes from the demand, and is overridable.** A field on the toolbar beside the part
  picker opens on the batch that part's orders actually use — the most common one, ties to the larger
  — so the map reconciles with a run without being told to. Typing over it is the lot-sizing
  experiment §7.6 says Batch Size exists to be; emptying it hands the question back to the demand
  table. Absent under the flow equivalent, whose dummy part is one piece by definition (§6.1).
- **Availability is applied once, and not here.** The engine works in open-clock hours and divides by
  availability to get there; the map works in *productive* hours throughout and divides each rung by
  a productive day. Dividing here as well counts the loss twice — §6.2 already said so, and the
  equivalence tests caught this making exactly that mistake.
- **What the three figures now are.** The map's `Process time` is Σ `(work + changeover)` — the same
  quantity §7.9 walks, plus the changeover §7.9 excludes because it depends on what ran before. The
  gap between the map and a run's actual lead time is therefore the **queueing**, which is the one
  thing a run exists to measure. The map's lead time additionally carries the days-of-stock in its
  queues, which a run charges nothing for (§5.5).

| Field | Source |
|---|---|
| Process time | selected data source: Flow equivalent \| one part \| all variants weighted by demand mix, × batch |
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

### 5.5 The queue in front of a step

**It is not a node.** An inventory used to be a second kind on the spine, between two boxes, with its
own name, discipline and capacity — so two studies whose flows both reached CLAD07 had one each, and
the engine simulated two floor spaces where the plant has one. §7.3 is the correction: a queue
belongs to what a step *targets*, is keyed `{projectId, targetId}`, and is drawn on the link into the
box rather than in a slot of its own. `FlowNodeKind.inventory` stays parseable because the rows stay
(§7.3's fold), and nothing constructs one: `StudiesRepository` lost its writers with the model.

**Every step has one**, including a target nobody has configured — which is an unlimited pile with
nothing standing in it, and is what gives the connector something to click before the first edit.

Two modes:

- **QUANTITY** — N pieces, displayed as days = `N × takt of the current period` (classic VSM "days
  of stock"; re-reads correctly when takt changes).
- **DURATION** — a fixed wait (24 h cooling, 2 days transport) in working or calendar time.

**In simulation a buffer costs nothing to pass through.** The figure on it is an *observation of a
current state* — what is standing between two stations today — and how long an order really waits is
the question a run exists to answer. Imposing the observed figure as a delay makes a run partly a
restatement of what was typed into it, and charges the order twice over: the fixed wait, and then
the queue at the next station anyway. So an order passes straight through and waits, if it waits, in
that station's queue, where the engine measures it and the Queue table reports it.

The figure keeps its two real jobs, neither of which is the engine's: the **lead-time ladder on the
map**, which is read off the flow rather than off a run, and the **days-of-stock** a current-state
VSM exists to state. Both are unchanged.

**§7.9's theoretical lead time counts it, and the engine's not counting it is the point of the
pair.** This paragraph once said the opposite — that theoretical had to exclude stock so it could
stay a floor under a run, citing célula 11B's 35.1 theoretical days against 25.8 actual as proof of
a defect. §7.9 overturns that: theoretical is a **standard** describing the plant as it stands,
including the pile in front of the machine, and a run beating it is a finding rather than an error.
What the engine must not do is *delay* an order for that stock, which is what this section is about
and is unchanged.

_This replaced "an order simply waits that long between steps."_ It survived until the model was
driven against a real plant, where six buffers named `FIFO CLAD09`, `FIFO TTAT`, `FIFO CEU27` and so
on held every order for a fixed 14 days of a 39.8-day lead time whether or not the next station was
free. The names are the tell: what was being modelled was the queue between stations, and a queue is
an outcome.

_Left open: a genuine process delay._ Cooling, curing and transport really do take their time
whether or not the next station is free, and nothing now expresses that — a 24 h cooling rack is
modelled as free. It needs a per-node switch saying which of the two a buffer is, and the day a
plant has one is the day to add it.

**The queue carries a discipline** (§7.4) **and a capacity in orders**; when it is full the station
behind it has finished an order it cannot put down, and stops. That is what the names on a real map
mean — `FIFO CEU27` is not a three-day delay, it is a channel with a rule and a floor space.

**Where it is edited: in the process step dialog**, under the workcenter the step targets. Choosing
the queue type is part of putting a station on the map — *"when a workcenter is added the user must
select the type"* — so it belongs in the dialog that adds the workcenter. Clicking the channel opens
that same dialog. The section **names the target and says the queue is shared** by every step that
feeds it, which is the answer to the complaint that started §7.3 and is not something a reader should
have to discover.

This reverses one round of its own history: the queue was editable on the connector alone, on the
argument that a planner setting a FIFO capacity is looking at the map when they think of it. That
argument still holds and is why the channel is still a click target; what it got wrong is that a
queue is not an afterthought to a step, it is part of describing one.

- **Push is a type, and the default.** The picker always shows a value, so adding a workcenter is
  always a conscious choice, and `rule` stays null for a push — no schema change, and §5.2 keeps its
  rule that a channel means somebody decided something. Supermarket is listed and disabled (§7.3).
- **The section follows the target picker.** Repointing a step from CLAD17 to CLAD09 reloads the
  fields from CLAD09's row — including one another study wrote, which is then *shown* rather than
  overwritten. What the heading names is what Save writes. On insert the section is absent until a
  workcenter is chosen, because a step that names no station has no floor space in front of it.
- **The row is written only when a queue field changed.** A step dialog is opened to change a label
  far more often than to retune a floor space, and the row is shared — five targets on the real
  database are reached by both studies. Writing on every save would let one study revert another's
  capacity by renaming a step, with neither of them seeing it. A target nobody has described
  therefore keeps no row at all.
- **The queues are handed to the dialog, not fetched by it.** The canvas is already watching them —
  it cannot draw a channel otherwise — so the answer is on screen before the click.

_Rejected: editing it on Capacity beside the station schedules._ Same key, same scope, same tab, and
it would put everything about a station in one place — but reading a rule on one surface and setting
it on another is the split §6.4 has just finished undoing on the Flow toolbar. _Rejected: keeping it
on the connector as well._ Two write paths into one shared row is how the two come to disagree
(§12.6).

**The working-time switch did not come across.** A fixed wait on an inventory node could be declared
wall-clock or working-time; `project_queues` stores no such flag, so every fixed wait is a calendar
wait and a quantity is takt-derived and therefore in the station's own hours. That is the honest pair
— cooling and transport really do run through a Saturday — and inventing the column inside a re-model
is what the paragraph below already declines to do.

**Blocking is after service.** A station cannot know whether the lane ahead will have room until it
has something to put down, so it finishes and then waits. While it waits it is neither idle nor
working, and that is what carries a jam backwards up the line. The held time is recorded per step
and per station and kept **out of `busySeconds`**: a blocked station is occupied and producing
nothing, and folding the two would make utilization report the jam as output (§8.3).

**A full lane at the head of the flow sends a release slot out empty**, with its own reason. There
is no station behind it to block, so the only thing that can be held back is the release itself —
and §7.2's slots are strict, so the slot is spent rather than deferred. Kept distinct from the WIP
cap's reason on purpose: one is a policy set for the whole flow, the other is the floor running out
in one place, and counting them together would say "the line was held back" without saying by what.

**Capacity is its own column, not `inventory_quantity`.** That figure means *N pieces standing here
today* — an observation — and the correction above is precisely that an observation must not be read
as a rule. They would share a unit and mean opposite things. Null capacity is unlimited, which is
what every lane was before.

_Rejected: capacity-limited buffers that block upstream_ — **reversed.** The original objection was
that it couples the engine, can deadlock, and needs blocking-time metrics to be interpretable. The
third is answered above. The second does not arise on §5.1's spine: it is linear with no branches
and no rework loops, so the last station always has an unlimited sink ahead of it and a blocked
chain always drains from the head. The rejection was written against a general graph.

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
2. orders currently in the flow < kanban WIP cap, **and**
3. the lane at the head of the flow, and the **pacemaker's** lane, both have room (§5.5).

Otherwise the slot is recorded **EMPTY** with the reason, and the head waits for the next slot. No
reordering.

**Why the pacemaker's lane and not just the first.** Lean injects the schedule at the pacemaker, so
"may another order start" is really "can the pacemaker take one" — and gating there makes the
constraint govern the line directly rather than through a chain of blocked stations propagating
backwards, which on célula 11B is four stations deep. The entry lane is checked as well because
nothing upstream of it can be blocked on its behalf. Both are no-ops until someone types a capacity.

The user's sequence is the thing under study — the app must not silently repair a bad one.

**How fast slots come round, as built.** A takt in days means productive days of a station (§6.1),
so a cadence needs one station's clock. The engine is handed a resolved interval and the id of the
station whose open time it is measured in; slots then walk that calendar, so a 3-day takt is three
*working* days apart rather than 72 hours.

**Which station that is, as built.** The study may name its pacemaker; the default is the step whose
work content across the whole demand is largest, ties broken by position (§4.4). It became a choice
rather than a derivation when it gained the second job above: a gate that moves to another machine
because someone edited a batch size, and tells nobody, is a gate nobody can reason about (§18.8). A
named pacemaker that is no longer in the flow falls back to the derivation rather than failing the
study — a deleted node should not read as a broken study.

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

Ties break by (arrival, study priority, sequence #) so shared-workcenter contention is reproducible.
Four rules: **FIFO** by arrival, **LIFO**, **EDD** (earliest need date) and **SPT** (shortest
processing time) — "what if we dispatched by due date" is exactly the experiment this app exists to
run.

**The queue in front of a station keeps the rule, and there is no run-level rule left** (§7.3, v19).
`project_queues.rule` is it, keyed `{projectId, targetId}`; unset reads as FIFO, which is what a shop
floor does. One place a dispatch decision is made, and the map draws every one of them.

This is the third position this section has held, and the two moves were not the same mistake. The
first build put the rule on the *station*, which governed a queue the reader could not see it on. The
second moved it onto the **lane** — the inventory node in front of the step — which was right about
where a discipline belongs and wrong about what a queue is: a node on one study's spine, so two
studies through CLAD07 had one each. §7.3's re-model keeps the argument and fixes the key.

- **A queue has exactly one comparator**, because there is exactly one queue per target and every
  step feeding that target reads it. The ambiguity a station-level rule could not resolve — a machine
  that is a candidate for its own step and for a pool's — does not arise: the pool is a target in its
  own right and carries its own queue.
- **The run records what each station dispatched by**, in `simulation_run_workcenters.queue_type`
  and `queue_capacity`, copied in for §7.10's reason. A run read back next month still says what each
  station did after the queues have been retuned, and M5's comparison can say *which* queues differed
  rather than only that something did.

**What a run is labelled with follows from that.** The runs-history row, the run header and the Excel
stamp read the date plus the queue type **when every station shared one**, and `mixed` otherwise —
and when it is mixed the header and the stamp list each station under it, because `mixed` alone says
the run is not one thing without saying what it is. A full breakdown does not fit a menu row, so the
menu stops at the one word.

- **One fold, read three times.** `RunQueues` derives both the one-line label and the breakdown from
  the same list of stations, so a menu row reading `FIFO` over a header reading `mixed` is not a
  state the code can reach — and the history query joins the stations in with the run list rather
  than asking per row.
- **`simulation_runs.dispatch` stays on the schema and stops being written.** The 35 runs made before
  v19 really did dispatch the whole plant by one rule, and reading it as the fill-in for a station
  that recorded no type is the only thing it is still for. A v19 run writes it empty, which parses to
  no rule at all rather than to FIFO: a station with nothing recorded is left out of the run's
  account of itself, because a run's job is to say what it observed. Widening the column to nullable
  would rebuild the table, and §16.11 is the record of what that costs.
- **A queue type the build has never heard of drops that station and opens the run.** The same
  fallback rule the rest of §7.10's enums have, one level gentler: a list of runs that cannot be
  opened at all is a worse answer than one run that names one station fewer.
- **The dispatch dropdown in the Simulate popover has gone**, with the run-level rule it set. So has
  the `dispatchOverrides` line on the run header, which counted overrides of a rule that no longer
  exists.

_The cost, and it is real._ §0's confounder run compared a whole plant under one rule against
another by turning one knob; that becomes an edit per station.

_Rejected: FEFO as a fifth rule._ It was asked for by name, and for this line the expiry that
matters *is* the need date — so it is EDD under the name the floor uses, and no expiry column is
stored. A real shelf life, independent of when the customer wants it, would be a column and a fifth
rule; nothing has one yet.

_Rejected: `resolveDispatch`, and the flattening of pool rules onto members._ It existed to give one
machine one comparator when the rule was a property of the machine. With the rule on the queue the
question does not arise, and the whole function went.

### 7.5 Operators

A workcenter is a **single server** by default: one order at a time. Parallel capacity is modelled
either by putting several workcenters in a pool or by raising the station's own
`parallel_capacity` (§3.1), which gives it that many independent servers. A shift with 0 operators is closed; any count ≥ 1 runs
identically. **Operators Needed** is computed from load (required hours ÷ productive hours per
operator) and compared against Allocated — the "6.7 operators required" figure.

_Rejected: operators as parallel capacity._ Two operators on one CNC do not double its output.
_Rejected: a shared operator pool across workcenters._ A second contended resource class with its
own assignment policy; nothing in the spec asks for it.

### 7.6 Batching and changeover

```
changeover = teardown_owed + setup            … × same_part% when the part repeated
occupancy  = changeover + (part_pt × batch_size × (1 + rework) ÷ availability)
```

**Process times in the demand table are per piece.** An order of batch 10 occupies the workcenter
for ten times the tabulated time, so Batch Size is a real lever for testing lot sizing.

_Rejected: process time per order with batch size as metadata._ Correct only for one-piece-flow
heavy fabrication, and it makes the Batch Size column inert in every calculation.
_Rejected: overlapping/piece transfer._ Multiplies event count by batch size and stops an order
being a single object moving through the flow.

**A changeover has two halves.** Setup rigs the station for the order that is arriving and teardown
strips it after the order that left. Both are optional and both are per flow step.

This reverses a standing rejection — *"a separate batch-independent setup component alongside
changeover: more faithful to a real routing, but it adds a second time field per step **and a rule
for how setup and changeover interact**"* — and it reverses it by removing the reason. There is no
interaction rule: the two halves are one operation, charged together, discounted together. What was
rejected was bolting a second concept beside the first; what this does is say the first was always
two things.

**Teardown is charged with the next order's setup, not at the end of the order that incurred it.**
Setup looks backwards — *was the previous order the same part* — and the engine already knows the
answer. Teardown looks **forwards**: a station is only stripped because something different is
coming, and when an order finishes the engine has not yet picked what follows. So the station
**remembers the teardown it owes** and settles it when the next order arrives. No lookahead, no
clairvoyance, and the result is what a changeover physically is: strip the last job, rig the next.

**The last order at a station never pays its teardown.** Correct rather than omitted — nothing waits
on it, so charging it would push the run past its final delivery for something no figure reads.

**A repeat pays a percentage rather than nothing.** `same_part%` is per step, defaults to 0, and
governs `setup + teardown` as a pair. Zero is exactly what this app did before v17, so an upgraded
study behaves identically until a number is typed into it; 100 % is the other end, where batching
buys nothing at all. Each half carries its own step's percentage, which matters only when one
station is the target of two steps — then each is governed by the step that specified it rather than
by whichever happened to arrive second.

_Rejected: teardown charged after every order regardless of what follows._ Right if the time were
really a clean-out that happens whatever comes next, and it needs no debt on the server. But then
teardown is not the opposite of setup — setup would be free on a repeat while teardown was not, and
ten identical orders would pay ten teardowns.
_Rejected: a second percentage for teardown._ A strip-down and a rig-up need not survive a repeat by
the same fraction, so it is more faithful. But they are always charged together under one rule, so
the second number would only ever move with the first, and nobody has a figure for it.

**No previous order counts as *not the same part*.** An empty station at cold start is set up for
nothing, so the first order of a run pays in full. This reverses the old behaviour, and what it buys
is that the rule has no special case left: setup is charged unless the part repeated, in one
sentence.

**Setup and teardown are a value plus a [TaktUnit], resolved at the server.** `days` means that
station's **productive** day, exactly as it does for takt (§6.1) and for the Process Specific Takt
sitting beside them in the same editor (§6.1.1) — one kind of day per dialog (§17.4). They are not
reduced to seconds at assembly, because a step may target a **pool** and a pool's members do not
share a working day: `1 day` of setup is ten hours at one machine and twenty-four at another, and
picking a representative member would be inventing a station.

**Availability does not derate the changeover**, and this changed with the units. §6.1 requires the
loss be applied exactly once, and a setup typed in productive days has already had it taken out of
the day it is measured in — so the old `changeover ÷ availability` would have counted it twice. A
literal setup is now literal: an hour is an hour however bad the station's uptime. The part's own
work is still derated, which is the half §4.4 owns.

**Every stored run made before this is invalidated by it** — a 90-minute setup at a 74 % station
occupied 121.6 minutes and now occupies 90. The third such break, after §5.5's buffers and §7.4's
lanes.

Running like-with-like is therefore genuinely cheaper and the sequence has a real cost, which is
what makes §6.3 worth optimising. The whole batch moves to the next step together.

**§8.4's occupation charges repeats the same way**, over the orders due in the period, or the
Summary and the run would describe the same plant differently — the failure §8.5 and §2.2 both exist
to prevent.

### 7.7 Run unit and contention

A run takes the set of selected studies (**at most one per production line**) and builds **one**
resource model of the plant — each workcenter and pool exists once regardless of how many studies
point at it. Each study releases on its own takt slots into that shared model, so line A's orders
genuinely delay line B's. Each study carries an explicit priority used in dispatch tie-breaking.
Results are reported per study and rolled up per plant.

### 7.8 Initial state and horizon

**Cold start**: the plant is empty at the study start date (= first order's need date − that part's
theoretical lead time (§7.9) − the study's **start buffer**).

The buffer is a deliberate margin on top of the derivation, in **calendar days**, zero by default.
Slippage accrues on a wall calendar — a week late is a week late whether or not the plant was open —
and the theoretical walk already returns a wall-clock instant, so the cold start stays one
subtraction on one clock (§17.4). It is subtracted outside the walk rather than inside it, because
the walk is the standard the plan reports and has to stay comparable with what the run observes
(§7.9); a margin someone chose is not part of what the flow costs.

**It is one lever, not one per order.** The cold start is derived from the *first* order and every
later one releases on a takt slot from there, so a 10-day buffer moves every release 10 days earlier
and gives the whole sequence the same margin. Worth saying because the formula reads as if it were
per order.

**One cold start per study, not one per run.** A run may carry several studies and each is a line
with its own flow, its own first order and its own need date, so each is walked back to its own
start. The run's clock begins at the earliest of them, because it has to begin somewhere, but a
study whose own cold start is three months later **does not release until then**.

This was `min()` across the studies, with every study's first slot scheduled at that one instant —
the per-study figure was computed correctly and discarded a line later. The damage was not only
cosmetic. A study released three months early delivers three months early, so its float reads as
slack that does not exist and OTD is flattered; worse, its orders occupy **shared stations** for
three months of simulated time they would never have been there, competing for capacity with the
study that legitimately started. Measuring real contention is the whole purpose of a run (§7.7), so
a multi-study run was reporting queueing that could not happen.

The run ends when every order in every selected study is delivered,
with a hard guard (≈5× the horizon implied by demand) that aborts and reports "demand exceeds
capacity — N orders never completed" rather than looping forever.

### 7.9 Theoretical lead time — one walk, two answers

**Two questions are asked of this walk and they want different contents**, so it
accumulates two figures in one traversal:

- **`elapsed` — when an order has to start.** Counts the step work, the changeover each step
  charges, and the stock already standing in each queue, walked on the real calendars. This is the
  production plan's `Theoretical LT` column and what the cold start is walked backwards from —
  **not** the map's footer, which is a different measure (see below). Stock is spent on the **wall
  clock**: a pile stands in front of the machine over the weekend too.
- **`workingTime` — work content.** Step work only, no changeover and no stock. It is computed and
  reported nowhere; see the warning below before giving it a consumer.

**Theoretical LT is a standard, not a floor.** It is what an order takes if it flows through the
plant as the plant stands today — waiting behind the stock that is really in front of each machine,
and paying a full cold changeover at every step. A run charges **neither** (§5.5 for stock, §7.6's
repeat discount for changeover), so **an actual lead time shorter than the theoretical one is a
normal result**, not a defect: the flow beat the standard because the standard assumed a queue the
run did not have.

This overturns what §7.9.1, §8 and §8.5 each used to assert — *"1.0 is the queue-free minimum"*,
*"theoretical can never exceed actual"*. That claim was false in both directions and it was written
down in three places, all agreeing with each other and none agreeing with the code, which is why an
inverted efficiency formula survived in the app for as long as it did. **Where a floor is wanted,
`workingTime` is the figure that can bear the weight** — it excludes stock, but it also excludes
changeover, which a run *does* spend, so it is not a floor either without adding the changeover
back. Nothing needs one today. Do not reintroduce the claim without deciding which of the three
spans it is about.

**Stock is counted once per target, at the same step in both directions.** Two steps of one flow on
one station share a floor space, and the map dedupes it the same way — charging it twice is the
doubling §7.3 exists to undo. The step it is charged at is the **first** in flow order to reach that
target, and `coldStartDate` walking backwards must use that same step rather than the first one it
happens to meet, which is the last in flow order.

That is not pedantry. Stock is spent on the **wall clock** and work on the **calendar**, so moving
a two-day jump from the front of a flow to the back changes which weekends the following work
crosses. Charged at opposite ends, the two walks disagreed: for a flow `A → B → A` with two days of
stock at A, the forward walk made 5 Jun → 10 Jun while the backward walk made 10 Jun → 4 Jun. The
first order's start date and its stated lead time then do not add up to its need date — visible on
row 1 of the production plan, and it shifts the release of every order in the study behind it
(§7.8). **The invariant, and it is worth a test:** walking forward from `coldStartDate(need)` lands
exactly on `need`. It holds for any flow, and it is the only thing that would have caught this.

**The map and the plan deliberately answer different questions**, and §17.2 already said so before
this section briefly claimed otherwise. The map is a **generic** view of a flow: the calendar's only
job there is to say what a day is worth in this period (`open hours × availability`), so the map's
lead time is work content in **working days** and does not depend on which weekday you happen to be
looking at. The plan is a **specific order on specific dates**: its Theoretical LT is an elapsed
span in **running days**, so it legitimately varies row to row — five working days released on a
Monday span 4.7 days and the same five released on a Thursday span 6.7, because one crossed a
weekend. Both are correct; they are different measures and are labelled as such.

What must **not** return is the state that produced the field's 48.8-against-23.3 complaint, which
was five differences at once under two labels both printed as `d`. Four of them stay closed: map and
plan both include queue stock, both include the full changeover, both apply rework, and both land on
the same day count despite the map working in productive hours and the engine in open ones (§17.3).
The fifth — the map shows the toolbar's batch, the plan each order's own — is accepted and known.
Converted to the same unit the two should agree to within the calendar's weekends, which is a
cross-check worth a test so they cannot silently drift again.

### 7.9.1 The original statement

```
theoretical_LT(part) = Σ_steps (part_pt × batch ÷ availability × (1 + rework))
```

walked through the working calendar so it lands on real dates. **Excludes queueing** (the point of
the measure) and **excludes changeover** (it depends on what ran before, so it is not a property of
the part). Used for both the study start offset and the Lead Time Efficiency denominator.

**Everything from here down is history, and §7.9 supersedes it.** It is kept because the reasoning
was sound against the question being asked at the time, and because knowing an argument was made
and then overturned is worth more than a clean page. What it says that is **no longer true**:

- The measure **includes** inventory and **includes** changeover today. It is a standard describing
  the plant as it stands, not a bound on a run (§7.9).
- `coldStartDate` **does** count the stock, and must, or the start date it produces will not
  reconcile with the lead time the plan reports for the same order.
- Lead Time Efficiency is **`theoretical ÷ actual`** and its denominator is the actual lead time,
  not this walk (§8.7). This paragraph naming this walk "the denominator" is the origin of the
  inversion that shipped.

The original argument, unedited: *"**Excludes inventory**, which it counted until §5.5's buffers
stopped delaying a run. This figure is only meaningful as a **floor** under what a run observes — the
gap between the two* is *the queueing — so it can count only what the engine can also charge.
Counted here and not there, célula 11B reported 35.1 theoretical days against 25.8 actual ones, an
efficiency of 0.73× where §8 says 1.0 is the queue-free minimum."*

The 11B numbers are real and the arithmetic is right; what was wrong was calling 0.73 a defect. Read
the current way round it is **137 %** — that cell ran better than a standard which charged it for a
queue it did not have to stand in. That is a finding, not a bug.

Flow-equivalent lead time (`takt × steps + inventory`) is kept as a separate footer reference — the
mockup shows both (6.0 vs 9.0 working days). **That one keeps its inventory**, because it is a
statement about the map rather than a bound on a run.

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
- **Per station, since v18: the pool it was dispatched through** (§3.1), id and name both. Nothing
  said which of a run's machines belonged together, so a pool of three read as three loose stations
  and its lane had nowhere to attach but one of them (§8.6). **Resolved when the run is written, by
  `stationPools`** — reading the plant's membership at open time would regroup every historical run
  the day a machine moves pools, which is the drift this whole section exists to prevent.

  **A workcenter may sit in several pools**, so there is not always one answer: `{poolId,
  workcenterId}` is the membership key, and with two studies in one run line A can reach CLAD07
  through `CAL Pool` while line B reaches it through `All Lathes`. **Exactly one pool is a grouping;
  none or several is a label** — the id is null in both the other cases and the name survives
  carrying what it served, so a station standing on its own says why rather than merely standing
  there. Null is *ungrouped*, never *every pool*, which is the rule below applied a third time.
- **Per override**: the stations that dispatched by something other than the run's rule (§7.4).
  Without them the header would report one rule for a run in which three stations used another.
- **Per step, since v17: what the changeover cost** in seconds, not merely that one happened. The
  bool was enough while the answer was all-or-nothing; a repeat charged at a percentage (§7.6) is
  neither incurred nor not, and the run is the only place the setup rule can be checked against what
  it actually did. `changeover_incurred` survives beside it, because a run made before v17 can
  answer that and can never answer the seconds.
- **Per study, since v17: the cell and the production line** it sat in, ids and names both. §12.1's
  combined view filters by them, and this is the rule's own consequence — the study may since have
  moved or been deleted, so the filter cannot go and ask. **A cell or line filter is a study filter
  one level up**: workcenters belong to a *plant*, not to a cell, so stations are never filtered this
  way — the studies narrow and their stations follow.

_Rejected: backfilling a run stored before a column existed._ It would make one run a hybrid of two
moments, which is the one thing the copy-in rule exists to prevent. A blank says "this run did not
record that", which is true.

---

## 8. Metrics

Per the spec: delivery float (need date − actual), average float per order, OTD (on-time ÷ total),
average lead time per part number, lead-time efficiency (**theoretical ÷ actual**, §7.9, §8.7),
sequence evaluation (§6.3), operators allocated vs needed (§7.5), empty-slot count (§7.2).

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

**Both tables name a station's pool beside it and neither groups by it** (§3.1). A ranking's first
row is its answer, and clustering a pool's members together would mean the top row was no longer the
station that queued most — so the pool is a suffix on the Workcenter cell, on one line because a
`DataTable` row is a fixed height. The Gantt does group, because flow order has already put a pool's
machines together and it has no ranking to lose (§8.6).

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
- **Lead-time efficiency is `theoretical ÷ actual`, shown as a percentage** — above 100 % means the
  flow beat the standard, below means it queued more than the standard allows (§8.7). This bullet
  said `actual ÷ theoretical` and the code matched it, which is how a metric shipped reading upside
  down. Each order's theoretical figure is walked from **its own release instant**, so the
  comparison is the same order in the same plant, not an average against a fixture — and both sides
  of the ratio are averaged over the **same** orders, which they were not (§8.7).

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

Both denominators are **unit-hours**: a station with `parallel_capacity` 2 has twice the available
time and twice the open time, because both numerators are summed across its units (§3.1).

Occupation and Utilization differ whenever sequencing or starvation gets in the way. Defined once
in an in-app glossary and translated consistently across en/es/pt.

### 8.4 The Summary, as built

```
required   = Σ (part_pt × batch × (1 + rework))
           + changeovers × changeover
           + repeats × changeover × same_part%
available  = open time across the span × availability
occupation = required ÷ available
```

- **Availability appears once, in the denominator.** The part's own time is left alone. Applying it
  to both sides is §4.4's oldest trap and would square the loss.
- **Ranked by target, not by step.** Two steps of a flow may visit the same station, and the
  station has one calendar and one set of hours: its load is the sum of both visits, and both
  process boxes report that same figure. A `×2` on the row says why.
- **Changeover is charged, because the sequence is known.** An order pays in full when the order
  before it *at that station* was a different part, and the step's `same_part%` of it when it was
  the same (§7.6) — walked over the whole sequence, so the first order of the month is compared with
  the one that really preceded it rather than starting the month clean. Only the very first order of
  a sequence has nothing before it, and that counts as a change, which is the engine's own rule.
  **Repeats are summed separately from changes** because each step carries its own percentage and
  two steps at one station need not agree.
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

### 8.5 The production plan — orders over time, and the slots that made none

**Empty release slots are rows.** The plan was the orders that survived §7.2's gate, so a study
spending eight of twenty-three slots waiting for material read as a plan with gaps nobody could see.
A slot now takes its own row where it happened, carrying the moment and **which gate held the line** —
awaiting material, the WIP cap, or a full lane. "8 empty slots" is not something a planner acts on;
which gate is.

- **Ordered by date, not by sequence.** For the orders alone the two are the same list — §7.2
  releases strictly from the head and never reorders — but a slot has a date and no sequence number,
  and only a timeline can say where it belongs. An order that never released has neither and sorts
  last, where a null would otherwise sort it first.
- **A slot row is mostly blank**, which is the honest shape: there is no order to describe. It fills
  the Order Start column, because that is the moment it happened.
- **Filters: a slot is kept by its study, an order by its own id.** A part or an order-number filter
  cannot speak about a slot — narrowing to a part would otherwise silently claim the line never
  stalled — so those drop them; a study or cell filter keeps them.
- The Excel export carries the same rows, for the same reason the table does.

### 8.5.1 The columns

`Order | Part Number | Description | Project | Batch Number | Batch Size | Need Date | Material
Date | Order Start | Order End | Theoretical LT | Actual LT | Efficiency | Float`, a section of the
Simulation tab's results.

- **A reading of a stored run, not of the demand.** It reads `simulation_run_orders`, so its dates
  cannot disagree with the run that produced them and opening an earlier run from the history menu
  opens its plan with it. Four of its columns are the copy-in §16.13 added for exactly this, and
  Description is §16.14's.
- **Description is capped and ellipsised, with the whole string on hover.** Free text with no
  length limit in a table that sizes each column to its widest cell: uncapped, one long description
  widens that column for every row and pushes Float off the right edge. The same answer §5.4 gave a
  node's notes, so the app has one way of putting long free text in a narrow place. It identifies
  nothing — two parts may share one (§16.14) — so nothing is lost by not reading it in full.
- **Both lead times, theoretical first.** Theoretical is the stored §7.9 walk from this order's own
  release — **including the queue stock and a full changeover at every step**, which is what makes
  it a statement about the plant as it stands. Actual is Order End minus Order Start, read off the
  outcome rather than stored, so it cannot come from a different subtraction than the tab's average
  lead time. Both are wall-clock from the same instant and in **running days**, so they are directly
  comparable. Both render through the same formatter the metrics card uses for the same two figures,
  so §17.4's one-kind-of-day rule holds by construction rather than by care.

  **Theoretical may exceed actual or fall short of it**, and either way round is a real reading —
  see §7.9. This bullet asserted the opposite (*"theoretical can never exceed actual"*) and was one
  of the three places the floor claim was written down.

- **Theoretical LT varies row to row, and that is the measure working.** It is an elapsed span, so
  it depends on which weekday the order released: five working days of content span 4.7 days from a
  Monday and 6.7 from a Thursday, and a shutdown moves one row by a fortnight. Since releases come
  one takt apart they drift through the week, so the column oscillates even with the capacity
  untouched. The alternative — a fixed standard per part, in working days, identical on every row —
  was considered and **rejected for this table**: a planner reading a plan wants to know when *this*
  order will be done, and that includes the weekend it is about to cross. The fixed-standard reading
  is what the **map** gives (§7.9), which is why both exist.

- **Lead Time Efficiency per order** sits beside the pair: `theoretical ÷ actual` for that row, as a
  percentage. This is §8.7's warm-up made visible — the headline figure on the metrics card excludes
  the warm-up orders, and this column is where a reader sees the ramp those orders form rather than
  having it silently averaged away.

_Rejected: a column for actual − theoretical._ It only restates the pair, on a table already
scrolling horizontally. _Superseded: the same rejection once covered the ratio._ It was reinstated
per order when §8.7 established that a single run-level ratio hides a warm-up ramp that changes
meaning with the length of the run.
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

### 8.6 The Gantt

Y is the workcenter, X is time, the bars are orders — **one chart for the whole run, all studies
together**. It needs no new data: `simulation_run_steps` already keeps a workcenter, a queue start,
a process start, a process end and a changeover flag per order-step, which is what §7.10 says that
storage exists for.

All studies together is deliberately the opposite of §8.5's per-study sectioning, and for a stated
reason: the plan's rows are orders and an order belongs to one line, but **a station is shared**.
Splitting per study would draw a station idle during hours it was in fact running another study's
order, which is the one thing §7.7 exists to model.

- **A bar is the station committed to an order** — `processStart → processEnd`, **closed hours
  included**. A step ends at `calendar.advance(now, occupancy)`, so a two-open-hour job started on a
  Friday afternoon reaches Monday morning. That is the same wall-clock span the plan's Order Start
  and Order End are measured across and the same one §8.3 calls occupation, so the tab has one
  meaning of a duration rather than two.
- **A station's bars take a sub-row each, and the band is as deep as the station was busy.** A pool
  still reaches the run as several candidates (§3.1), so three cladding machines are three rows;
  what this answers is one machine with more than one unit.

  _This sentence used to read "bars tile without overlapping: every workcenter is its own server."_
  That was true when it was written and **§3.2 made it false**, by letting a station hold more than
  one order at a time — and nothing came back to the chart, so two concurrent orders were drawn on
  top of each other. Found by looking at it, on a TTAT set to two units. It is worth keeping as an
  instance of the hazard §2.5 names from the other direction: a premise recorded as a principle
  outlives the implementation that made it true.

  **The depth is derived, not stored.** `simulation_run_workcenters` keeps no unit count and §7.10
  forbids joining back to the plant to ask, but the overlap is already in the steps — so the depth a
  station needs is the depth it was observed to use. A two-unit station that never held two orders
  at one instant draws one deep, which is the honest reading: the chart shows the run, not the
  plant.
- **A gap means "not running" — closed and starved alike.** Splitting a bar at closed time would
  need calendars a stored run does not have; `simulation_run_workcenters` keeps a total open time
  and nothing finer. How much of a gap was even available is answered by the station's utilization
  and open time in the Queue table, which is where that question belongs.
- **Queue spans are not drawn on a station's own row.** One station can hold dozens of orders at
  once — the real run has 4487 days of queue at CEU27 — and drawing those there would smear the row
  solid over the bars underneath. Queue is reported per station in the Queue table, per order by
  §8.5's two lead-time columns, and per step in the hover card.
- **A lane gets a band of its own, immediately above the station it feeds**, so the chart reads down
  the page the way the line runs (§5.5). Orders **stack** inside it and the band is as deep as the
  lane is, so a full lane is something the reader sees rather than infers from a gap in the row
  below it. They are drawn in the part's own colour but washed out and outlined, never solid: an
  order waiting must not read as one running.

  **This is what makes drawing a queue affordable at all**, and it is the premise the rejection
  above did not have. A capacity bounds the band's height by a number the user typed, where a
  station's row is bounded by nothing.

  **A lane is placed by the step it feeds, not by its stored position.** `SimLane.position` is a
  place on one study's spine, and the chart merges every study into one set of station rows (§7.7),
  so a spine position cannot become a row index without the join to the flow §7.10 forbids. What the
  run does keep is which lane each step waited in, and `queueStart → processStart` is the stay
  itself. **A lane no step ever
  names is not drawn**: no order passed that point, so the run holds nothing that says where it sat,
  and an invented position would put a band between two stations it may never have joined.

  **What it is placed above is the step's *target*, not a machine** — the pool where the step named
  one, the station otherwise. This sentence used to read "a lane fed by a pool sits above the first
  of that pool's machines, which is where the ordering has already put the busiest of them", and it
  was wrong twice over: the code took whichever member happened to pull an order out of the lane
  first, and even the intent was wrong, because a lane feeds a pool rather than a member of one. The
  band landed on an arbitrary machine, which is what made that machine look detached from its
  siblings. It now sits above the pool's members as a group, carrying the pool's name (§3.1).

  **A target carries a list of bands, not one.** This was a map keyed by workcenter, so a second lane
  feeding one station silently overwrote the first — and two studies both stepping on one pool, each
  with a lane in front of it, is exactly how that arises (§7.7). One FIFO left the chart with nothing
  on screen saying it had, which is worse than drawing it in the wrong place: a band drawn wrongly is
  a misread, a band not drawn is a run the reader cannot ask about. Both defects came back from the
  same field report on 2026-08-15 and are one fix.

  **A capped lane is drawn at its capacity; an uncapped one at how full it actually got.** The empty
  slots of a capped lane are its headroom, and hiding them would make every capped lane look full. An
  uncapped lane has no rule to draw, only the observation §5.5 is careful to say is not one — so the
  depth is capped, and the band says when it is drawn shallower than the lane went. An order the
  guard caught still standing in a lane leaves no step at all, and is carried separately: dropping it
  would draw the lane emptiest at exactly the moment a jam is the finding.

  **Bands are therefore not a uniform height**, which is the one thing this cost elsewhere. Anything
  that had been dividing a row index back out of a rect's top now takes it from the layout, which
  knew it already.
- **Rows are in flow order** — the first station of the routing on the first row — so an order is
  read diagonally down the chart the way it is read left to right along the map (§5.1). Built from
  steps, so a station that never ran has no row.

  **The run stores no node positions**, because §7.10's rule is that a run joins to nothing and the
  flow it was made from may have been edited since. So the order is derived from the steps: §5.1
  makes a study's topology a linear spine, so one order visits its stations in exactly the routing's
  order, and the order it visited them in *is* the routing. Measured from `queueStart` — when the
  order arrived, not when it got served — or a station that made everything wait would float up the
  list. A station shared by two studies takes the **earliest** position it holds in either, since
  §7.7 gives it one row whichever line is being read.

  **`RunMetrics.workcenters` breaks the ties**, so stations at one position in the routing — a
  pool's three machines (§3.1) — still come out busiest-queue first and in the same order twice
  running.

  **A pool sorts as a group, and the group sorts where its busiest member would have.** Its members
  have to stay adjacent or the label they share would run down some of them and not the rest — and a
  machine can hold two routing positions, which is what would otherwise split one. So a group takes
  the earliest routing rank and the best Queue rank any member holds, and the members keep the Queue
  order underneath it.

  _The first attempt ordered groups by name_, which was simpler and threw away the Queue ranking for
  every station **not** in a pool: an ungrouped station is its own group, so ranking groups
  alphabetically ranked those stations alphabetically. Ranking by the best member's Queue position
  instead makes the sort identical to the old two-clause one wherever no pool is involved, which is
  the property worth having — a run with no pools in it must draw exactly as it did before.

  **The pool travels on the rows it names, rather than on a heading above them.** A `GanttPoolGroup`
  band carried no bars, answered no hover and took no band fill, and that is exactly how it read: an
  empty lane between the axis and the first thing with bars. *"It looks like there is a pool lane,
  then a fifo, then the clads."* A band that belongs to nothing looks like a band with nothing in it,
  so it is gone and every member and every lane feeding the pool is labelled `CLAD Pool · CLAD07`
  instead. The band union is a station or a lane, which is what this section said it was before the
  heading was added.

  **The label column is measured, not fixed**, and the pool is what gets cut when it must be. The two
  halves are separate `Text`s in a `Row`: the name is inflexible and is laid out first at the size it
  needs, the prefix flexes into what is left. A pool name is free text — the real plant's is
  `CLAD Pool - Célula 11B/C` — and against a fixed 168 px with one trailing ellipsis it consumed the
  column and dropped the machine name, so five rows of a pool read identically and the one word
  telling them apart was the one that had been cut. `ganttLabelWidth` measures the widest label the
  chart actually has and clamps it between 168 and 260 px: below that a short-named plant keeps the
  column it always had, above it a pathological name cannot eat the chart. **Measured once per chart,
  not per build** — `build` runs on every hover, and the width cannot change with the pointer.

  _The prefix is dimmed and a size smaller, and keeps its row's own slant_ — italic over a lane,
  upright over a station — because it repeats down every member of the pool while the machine is what
  the reader is looking for, and because the row has to read as one label rather than two fragments
  that happen to be adjacent. That is the same distinction the column already drew between a lane and
  a station, applied one level in.

  _This reversed the first decision, which was that rows follow the Queue ranking outright so the
  bottleneck is the first row read._ It survived until the chart was driven against a real plant,
  where it turned out that a Gantt is read as a flow and a ranked chart makes an order's path
  zig-zag. The bottleneck is still ranked, in the Queue table, which is where a ranking belongs.

#### Geometry, in `gantt_layout.dart`

Pure, widget-free and under `application/`, in **two functions rather than one**: `buildGanttChart`
resolves rows and bars in `DateTime` terms — the join, once per run — and `layoutGantt` turns that
into rects and a content size, once per zoom. Geometry is then testable without constructing a whole
run and the join without a pixel. This is §5.2's precedent, which moved arrow geometry into
`layoutFlow` for the same reason; the Gantt has strictly more geometry than the arrows did.

It takes a result and its metrics rather than a `StoredRun`, which keeps the file out of the data
layer and its tests out of a database.

- **X-only zoom, fitted once per run.** A map has no intrinsic scale and refits itself on every
  viewport change (§12.2); a time axis does have one, so a wider pane keeps its pixels per second
  and simply shows more days. No refit rule and nothing to track about whether the reader has
  zoomed.
- **Zoom bounds are absolute, ×2 a press.** The floor is the whole run across the pane — there is
  nothing past it, so zoom-out disables there — and the ceiling is **one hour across the pane**,
  stated in time so it means the same on a two-week run and a two-year one. A relative
  `clamp(0.2, 3.0)`, which is what the canvas uses, was tried against the real run and fails on the
  arithmetic: 6.3e7 seconds in a 900 px pane is 1.4e-5 px/s, so even at 3× a one-hour step is 0.15 px
  and no zoom reaches a state where a bar is real. ×1.25 a press would take thirty presses to cross
  that range; ×2 takes ten.
- **One axis row, with labels that stand alone.** The finest unit whose ticks land ≥ 90 px apart,
  from hour / day / week / month / quarter / year, **aligned to the calendar** — month starts,
  Mondays, the top of the hour, never "every 30 days from wherever this run began" — so a date sits
  under the same label at every zoom. The function returns instants and a granularity and never sees
  a `BuildContext`: dates follow the user's setting and clock readings are 24-hour, which is
  §12.4's split.
- **Only the visible ticks are built**, which is why they are not part of the layout. At the ceiling
  a two-year run is sixteen million pixels wide and carries seventeen thousand hourly ticks, and
  §16.9 measured local `DateTime` construction on Windows at ~13 µs — building them all would cost a
  fifth of a second on a zoom press to throw away all but the ten on screen. A scroll listener asks
  for the range it can see.
- **Bars get a 2 px floor**, so a step of a few hours is never invisible at whole-run scale: drawn
  true it would be a fraction of a pixel, and a row would read as idle during hours it was running.
  The floor lives in `layoutGantt` rather than in the painter, so **the rects the hover picks against
  are the rects that were drawn** — which is the whole argument for the file. `layoutGantt` counts
  the floored bars, so the view's "indicative at this zoom" note appears and goes away on a number
  out of the pure function rather than on a permanent disclaimer, which would be a lie at the
  ceiling where every bar is drawn true.
- **Changeover is a leading-edge stroke above a 6 px bar, not a hatched prefix.** A prefix has a
  width, and `simulation_run_steps` stores only the bool — the setup is folded into the occupancy
  and never recorded — so a reader measuring that prefix against the axis would be measuring an
  invention, and on a 2 px bar it would be the whole bar. A line cannot imply a duration. Below the
  threshold the mark is omitted rather than faked; the hover card says it at every scale. A colour
  change between adjacent bars is **not** the same fact: §7.6 decides changeover by the batching
  rule, so the two can disagree in both directions.
- **Hit-testing takes the whole row band, and is exact horizontally.** A bar at the floor is two
  pixels wide and a reader aiming at it is aiming at its row; asking them to hit 18 px of height as
  well would make the thinnest bars — the ones most in need of a hover card — the hardest to ask
  about. Horizontally it is exact because bars tile: a tolerance either side would make two adjacent
  bars both answer for the boundary between them.

_Rejected: golden-image tests for the painter._ They would catch the class of defect §12.6 and §5.2
say only rendering finds — at the cost of the first golden infrastructure in the repo, and goldens
that churn on any font, theme or locale change across three languages and two brightnesses. §15's
golden scenarios are committed *numbers*. So: exhaustive pure tests on the join, the layout, tick
selection, the floored count and the hit test; widget tests for the view; then it is driven by hand.

#### The view, in `gantt_view.dart`

Its own view rather than a section of the results (§12.1), and **nothing in it decides a position**:
it reads the layout, paints it, and hands the pointer straight back to `barAt`.

- **A real scroll view, not drag-to-pan.** §12.6's rule is that a wide thing must scroll *and say
  so*, and a bare drag re-creates the complaint that rule exists to answer — nothing on screen would
  say how much run is off either edge. So the chart is a `CustomPaint` inside `HorizontalScroll`,
  which gains an optional controller for it: the window start **is** the scroll offset, so there is
  one answer to where the reader is, and zooming about the pane's centre is a matter of moving it.
  Labels are frozen outside the scroll view; the axis is inside it, so it pans with the bars.
- **The pane is repainted on scroll, and that is deliberate.** The axis and the bar culling both
  need to know which slice of the content is on screen. Rebuilding on the offset is what makes "only
  the visible ticks are built" true at run time rather than merely possible, and it is what lets the
  painter skip the bars outside the pane — at §14 scale a run carries 20 000 of them and at most a
  screenful can be seen. The layout itself is cached per zoom, so scrolling never re-measures a bar.
- **Zooming holds one point of the pane still**, so the instant under it is still under it
  afterwards; anything else lands a zoom into a sixteen-million-pixel run somewhere the reader was
  not looking. The **buttons hold the centre**, because a press says nothing about where the
  reader's attention is; **ctrl-scroll holds the pointer**, because it says exactly that. Zoom-out
  is dead at the floor and zoom-in at the ceiling, both read off `ganttScaleBounds`.
- **Ctrl-scroll zooms; a plain wheel is untouched.** §12.6's rule against hijacking the wheel stands
  — the chart sits inside a vertical scroll, and a pointer parked over a tall one would strand the
  page below it. Ctrl-scroll is a different gesture, claimed by nothing else in the app and the one
  every other timeline a planner uses is zoomed with. A notch steps ×1.25 where a button steps ×2: a
  press is expensive and has to cross four orders of magnitude in ten of them, while a notch is
  cheap and gets spun several at a time.

  The listener has to sit **inside** the two scroll views, not around them. `PointerSignalResolver`
  gives the event to whoever registers first and registration runs innermost-outwards, so an
  ancestor would lose to the `Scrollable` beneath it and the chart would pan while it zoomed.
  Registering is also what stops both scroll views acting on the same notch — exactly one handler
  wins.
- **The content carries a gutter below the last row** for the horizontal scrollbar. The bar pins to
  the bottom of a scroll view exactly as tall as its content, so without it the bar lies across the
  last row's bars: reaching for the scrollbar means reaching through them, and hovering that row
  means reaching through the scrollbar. Found by dragging it. `barAt` returns nothing in the gutter,
  so the two never both answer.
- **The hover card is one widget, not one per bar.** That is the whole objection to a `Tooltip`
  here: it carries a fixed message, so naming the bar under the cursor that way would mean 231
  widgets on the real run and 20 000 at §14 scale. One card, positioned at whichever bar is under
  the pointer, and `IgnorePointer` so it cannot take the hover away from what it is describing. It
  is **anchored to the bar rather than followed to the cursor** — it then moves only when the answer
  changes, and it is easier to read for standing still. It names the order, the part, the station,
  the span, the committed duration, the wait before starting, and the changeover at every scale
  including the zooms where the mark on the bar is omitted for want of room.

  It also names **the study, on a run that has more than one**. A part number identifies a part only
  inside its study (§16.15) and an order number is a position in *one* study's sequence, so on a
  two-study run `Order 1 · PN1` names two different orders and the study is what tells them apart —
  §8.1.2's rule for the Parts table's Study column, applied to the card for the same reason.

  And it names **the customer project and the part description** (§7.5). Both come off the Production
  Plan (§8.5) rather than through `buildGanttChart`: neither is ever drawn on a bar — a bar has room
  for a part number and an order number and no more — so routing them through the layout would put
  two label fields into a file whose subject is geometry, and `ProductionPlanRow` in front of an
  `application/` library that is careful to have no data layer in it. The view reads them off the
  slice's plan, keyed by order, which is how the plan is keyed and which answers both: the project
  belongs to the order (§16.15), and the description arrives on the same row.

  **Absent is not blank.** `customer_project` arrived in v12 and `part_description` in v13, so an
  older run has no answer — and 11 % of live orders genuinely have no project. The line is omitted in
  both cases rather than labelled with an empty value, which would read as a project called nothing.
  A stay in a lane is asked the same two questions as a bar, because they belong to the order rather
  than to what it is standing in front of.
- **A card, not a painted box**, which is a departure from how the bars are drawn and earns it: the
  text is then localized, themed and findable by a widget test, at no cost to the argument above.
- **Tapping a bar follows its order** (§7.5). Every other bar and every other stay fades back, and
  the order's own gain the stroke the hover already uses — so one order's path down the plant reads
  at a glance instead of being swept for. An order is on the chart many times over, which is the
  whole point: one bar per station it visited, one stay per lane it waited in.

  **What is remembered is an order id, not a hit and not an order number.** Not a hit, because the
  bar that was clicked is one of many and the others are the answer. Not a number, because that is a
  position in *one* study's sequence — on a two-study run it names two different orders and would
  light both.

  **A dimmed bar loses its label and its changeover mark as well as its fill.** They are the detail a
  reader reads a bar for, and at full strength over a washed-out fill they would be the loudest thing
  on a chart whose subject is elsewhere. The fill keeps the part's hue, so the plant stays legible as
  shape and colour while one order is legible as text. A stay is already drawn at 0.30 rather than
  solid, so it fades to a smaller number and drops its 1 px edge — otherwise every dimmed stay would
  still be outlined.

  **Tapping the order again clears it, and so does tapping no bar.** Both are wanted: a reader who has
  found what they came for reaches for the bar in front of them, and one who has lost the thread
  reaches for the space around it. A zoom or a lane toggle **keeps** the selection, because the order
  is still on the chart; a different run or a narrowed filter clears it, because it may not be.

  The gesture sits **inside both scroll views**, beside the ctrl-scroll and for the same reason: the
  position it reports is then in the content coordinates `barAt` answers in, with no offset to
  subtract back out.
- **What a gap means is on screen.** A gap is a station not running — closed and starved alike — and
  this chart cannot tell the two apart, because splitting a bar at closed time would need calendars
  a stored run does not have. The line above the chart says so and names the Queue table as where
  "how much of that gap was open at all" is answered.

#### Colour by part

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

**The Parts table is the legend, and the chart carries a strip.** A swatch in the table's Part
Number cell, taken from the row's own position — which *is* the part's position in the sorted list —
so the swatch and the bar cannot come from two different lookups. It is defined there, beside that
part's orders, on-time and lead-time figures, so the reader learns the mapping while reading the
numbers. The strip under the chart is the same list in the same order, because the Gantt is its own
view (§12.1) and the table is not on it; it names the study beside the part number when the run
carries more than one, which is §8.1.2's rule for the table's Study column.

_Rejected: rotating hue off the seed colour._ Never runs out and always in the app's family — but
adjacent hues stop being distinguishable past six or seven parts, and adding a part recolours a run
that has not changed.

_Rejected: colour by study._ Fewer colours to pick, and it shows contention at a shared station.
Within one study — the common case — every bar is the same colour.

_Rejected: colour by part number rather than by part._ `DemandParts` is unique on
`{studyId, partNumber}` (§16.15), so two lines' `PN2` are two parts; merging them would give one
colour to two routings. §8.1.2 is the other half of this decision.

### 8.7 Lead Time Efficiency, and the warm-up it has to survive

```
LTE = theoretical ÷ actual,  as a percentage
```

**Above 100 % is good.** The order crossed the flow faster than the standard, because it queued less
than the flow expects. Below 100 % is worse: more queueing than the standard allows for. That
direction is the whole reason a planner reads it, and it is the direction the field states it in.

**It shipped inverted.** The code computed `actual ÷ theoretical` and rendered it as `0.73×`, so a
flow running *well* displayed a *low* number and there was no unit on screen to give the reading
away. It survived because §7.9.1, §8 and §8.5 all described the reciprocal and all agreed with each
other (§7.9). Displayed as a percentage now, so the direction is legible without a tooltip.

**Both figures must come from the same orders.** Actual was averaged over the delivered orders and
theoretical over the ones that could be walked, and an order that delivered but could not be walked
— a step bound to a workcenter since removed from the model — landed in one average and not the
other. A ratio of two means over two different populations is not a ratio of anything. Only orders
carrying both figures count toward either.

#### The warm-up

**The plant starts empty, so the first orders cannot be compared with the later ones.** Theoretical
charges every order for standing behind the stock that is on the floor today; the run starts with
empty queues and never charges that stock at all (§5.5). The head of the sequence therefore meets a
plant nothing has queued in yet and scores far above 100 %, and the queues only build up as the run
fills.

The damage is not that early orders score well — they genuinely ran fast. It is that **the headline
average then depends on how many orders are in the run**: a ten-order run is mostly warm-up, a
five-hundred-order one barely notices it, and the same plant scores differently in each. A figure
that moves with the length of the run cannot be compared between runs, which is what a headline
metric is for.

**So the headline excludes the warm-up, and the plan shows every order.**

- **Warm-up is every order released before its own study's first delivery.** Until one order has
  crossed the whole flow, no downstream station has seen contention at all, so those orders are not
  measuring the same plant the rest are. Defined off the run's own numbers rather than as a fixed
  count, so it scales with the flow instead of needing a tuning knob.

  **Per study, not per run**, for the same reason §7.8 gives each study its own cold start: a study
  is a line with its own flow, and a line that begins three months later fills its own pipeline
  then, not when the earliest line filled its.

- **A run that never fills its pipeline reports no efficiency at all.** If every order released
  before the first delivery — a handful of orders, or a sequence released faster than the flow can
  clear — nothing settled and the figure is a dash. That is the rule working rather than a gap: a
  number computed over warm-up orders and labelled the same as one computed over settled ones is
  exactly the incomparability this exists to remove. Real runs fill within the first lead time and
  are unaffected; the per-order column carries every row either way.
- **It is a heuristic and it under-corrects**, which is worth stating plainly: queues keep growing
  after the pipeline fills, so the orders just past the cut still score a little high. It is the
  cheapest rule that removes the run-length dependence, and the per-order column is what makes the
  residual visible instead of hidden.
- **Only LTE excludes them.** Average lead time, float and OTD count every order, warm-up included.
  Those are facts about orders a planner promised to someone; LTE is a ratio against a standard, and
  only the ratio is distorted by comparing against a standard the early orders were never measured
  against.
- **The per-order column carries no exclusion** (§8.5.1). A planner should be able to see the ramp
  and judge it, and a column that silently blanked its first rows would be the same hiding in a
  different place.

_Rejected: seeding the queues with their stock at run start._ The faithful answer — the stock really
is on the floor on day one, and a run that modelled it would need no warm-up rule because it would
charge what the standard charges. It is a different simulation, not a correction to this one: it
reverses §5.5, and it needs answers this model does not have (is that stock processed, does it
consume capacity, whose orders are they, what is their sequence). Worth doing on its own terms one
day; not worth folding into a calculation fix.

_Rejected: comparing actual against a stock-free theoretical instead._ It removes the warm-up
distortion completely, because an empty plant *is* the queue-free case, and it costs the meaning the
field asked for: above 100 % would no longer read as "less queue than the flow expects" — there
would be no expectation to beat.

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
- **The grid is no longer only the demand tables.** The takt schedule and each workcenter's schedule
  are entered the same way since field feedback that re-tuning a takt cost a round trip through a
  dialog. `DataGrid` already had everything that needs — keyboard navigation, per-keystroke
  validation, frozen columns and the Excel paste — so the cost was a parser per column, and the
  paste is worth more than the inline editing was.
- **What a block means lives in a pure function, not in the widget.** `demand_paste.dart` for the
  demand tables and `schedule_paste.dart` for the two schedules: each returns a list of writes, so
  which rows append, what an unreadable cell means and how a block merges over what is already there
  are unit tests rather than widget ones. §1.6's precedent — what an edit *is* should be assertable
  without pumping a frame — and it earned its place immediately, since neither schedule tab had a
  widget test at all.
- **An unreadable cell changes nothing around it.** The grid is already showing the user why it is
  refused, and rewriting the rest of the row around it would write a value nobody typed — §11's one
  intolerable failure, arriving from the editing side rather than the import side.
- **A new row is complete from the moment it is touched.** Typing into the blank row at the bottom
  creates a real period carrying the suggestions the dialog used to offer: the day after the last
  one ends, running to the end of that year, and — for a workcenter — one operator per shift, fully
  available, with no rework. The alternative was a half-built period held in widget state until it
  had every value, which puts a row on screen that does not exist and cannot be deleted. Appending
  several rows staggers them rather than stacking every one on the same suggested start.
- **Forgiving in, canonical out** (`cell_parsers.dart`). A unit cell takes `days`, `d`, `días`,
  `dias`, `horas`, `min` or `s` and redisplays in the UI's own language; availability takes `74%`,
  `74` or `0.74` and redisplays as `74 %`; a comma is a decimal point, because two of the three
  languages shipped write it that way. **The unit parser is deliberately language-independent**: a
  planner pasting an English spreadsheet into a Portuguese UI is the case paste exists for.
  Forgiving is still not guessing (§9.2) — `weeks` is refused rather than assumed, because this app
  has no such concept and inventing one silently is how a figure ends up wrong by a factor of seven.
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
indefinitely, flagged as a run warning: *"12 orders finished after 31/12/2026 using the last defined
schedule."*

Without this, an overloaded plant becomes unsimulatable exactly when the simulation is most
informative — and the user cannot know how far to extend their periods until they have run it.

**The horizon is the earliest of each schedule's own last date, not the latest.** Past the first one
to run out, at least one schedule is being carried forward, and a figure is only as defined as the
least-defined thing that produced it. Taking the maximum would report a run as covered to whichever
station happened to have the longest schedule.

**It is stored on the run** (`simulation_runs.schedule_horizon`, §16.17), because how far the
periods reach is a fact about the plant and §7.10 forbids a stored run joining back to one — so a
run that could not say this would drop its own caveat the moment the reader reopened it, which is
exactly when they are most likely to quote the figures. **The date and not the count**: how many
orders finished past it is derivable from the stored orders, and keeping both would let the two
describe different sets.

**The engine carries it without reading it.** Past the horizon a schedule is simply carried forward,
which is what `PeriodSchedule` already does; the run's job is to say that happened, not to behave
differently. Null on any run made before v16 and on a plant with no periods, which reads as no
warning rather than as everything being past it.

---

## 12. UI

### 12.1 Shell

A persistent left rail: Projects · Study Templates · Resources · Settings (· About/diagnostics).
Opening a project gives a workspace with a studies sidebar and, per study, tabs
**Flow / Study Settings / Flow Takt / Workcenters / Demand / Summary / Simulation**. Resources uses a hierarchical tree (Plant → Cells → Lines → Workcenters, plus
Pools and Shift Patterns). All routes deep-linkable via go_router.

**Study Settings gathers what is not on the map.** Its name, the line it sits on, whether it takes
part in a run, its pacemaker, its start buffer, its WIP cap and its priority. Three of those were on
the study's sidebar menu, two were a `Run settings` dialog, and **two were reachable from nothing at
all** — `wipCap` and `priority` have been stored and read by the engine since M3 and listed in §17.5
ever since, and §3.3b said outright that they belonged with the others and were waiting for the round
that needed them. That round is this one, and gathering them closes two §17.5 entries.

The dialog is removed rather than kept beside the tab, for §12.6's reason: two ways to set one field
is how the two come to disagree. **Every field writes when it is left**, so there is no draft to lose
and nothing to cancel out of — and an unreadable value puts back what was stored rather than writing
a guess, which is the rule the schedule grids already follow. The line is shown and not edited: a
study's line decides which takt schedule it reads (§6.1), so moving one would silently repoint every
figure on the map.

It is also where §3.8's map-only flag goes when that is picked up, which is half of why the tab is
worth its place now rather than later.

**`Takt` is `Flow Takt`**, because the tab beside it is now `Study Settings` and one-word `Takt` read
as a setting rather than as the schedule it is.

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
  result the instant it exists. The spinner stays on the button, and a **banner above the tabs**
  reports the headline with one action that brings you to the rest and a close button. The tab
  controller therefore belongs to the workspace rather than to the tab strip — a controller one
  level below the button that needs it cannot be reached without threading a callback down and an
  index back up.

  **A banner, not a snackbar, and it stays until it is dismissed.** It was a plain `SnackBar` on
  Flutter's four-second default, which is not long enough to read a figure you asked for and is
  anchored to the bottom of the window — where, since the Gantt took the full body height (§8.6), a
  bar that never went away would park permanently over the last station's row and the scrollbar
  gutter §2.11 added to reach it. A banner pushes content down instead of covering it, and a run's
  outcome is a statement about the project rather than a transient acknowledgement.

  Two details: **the action dismisses as well as navigating**, because a bar still offering to take
  you to results you are now looking at is asking a question already answered; and **a failed run
  offers no `View results`**, since there is no run to look at and a button promising one would be
  a lie. It stays dismissible either way.
- **The disabled tooltip names the first thing in the way, and the study it belongs to.** §11's
  readiness panel is on a tab the reader may not be looking at, so the reason travels with the
  button. One reason rather than all of them: a tooltip is a sentence and the panel is the list.
- **The Simulation tab keeps the rest** — the rule to dispatch by, the runs already made, the
  readiness panel and the results. Only the trigger moved.

**The project's whole run is a destination in the studies sidebar**, under New study, and selecting
it replaces the tabs. A run spans studies (§7.7), so it sits beside them rather than inside one; a
route rather than an overlay, because a filtered view and a run's history are both things worth
sending someone a link to, and because the window should reopen where it was left.

Four filters — studies, cells, lines and a period. **Cells and lines are study filters one level up**:
workcenters belong to a plant rather than to a cell (§7.10), so they narrow which studies are in view
and the stations follow. The period selects orders by **need date**, the only one of an order's dates
that is never blank — so an order the run never completed still appears in its period, and §7.8's
abort case is exactly what a planner filters to find. Filtering by delivery would drop those and make
every filtered view optimistic.

**Simulate is in both places.** The workspace carries a Run button, and the project app bar keeps
its own: §12.1's rule is that starting a run must not require navigating somewhere first, which is
the complaint that put the button on the app bar to begin with. Two entry points, one action, one
disabled reason.

**A study's Simulation tab is its slice of the project's run, never a run of the study alone.**
§7.7 builds one resource model of the plant so that line A's orders genuinely delay line B's; a solo
run would answer a different and always-optimistic question, and the two would then disagree with
nothing on screen saying which was which. `run_filter.dart` reads one `StoredRun` through a
`RunFilter`, so the study tab and the combined view cannot report different numbers for the same
study.

**Order-level figures follow the filter; station-level figures do not, and the view says so.**
Counts, on-time, lead times, float, the plan and the Gantt all recompute over the slice, because
every order carries its own dates. Utilisation cannot: its denominator is `openSeconds`, stored as a
run total, and rebuilding open time for a subset needs each station's calendar — which §7.10
deliberately does not store and which is the exact cost that got §3.5 dropped. So the stations keep
describing the whole run and are labelled as doing so.

Two rules that only writing it settled, both of which had already gone wrong once:

- **Naming no study means every study, not no study.** Resolving the set from `run.studies` and then
  requiring membership emptied an unfiltered view of a run whose study rows were absent. A null set
  means *do not narrow*, kept distinct from an empty one, which means *narrowed to nothing*.
- **A run made before v17 matches no cell rather than every cell.** Its `production_cell_id` is null
  (§16.18), and treating a blank as a wildcard would make a filtered view silently describe studies
  nobody asked for.

**Three more filters, and they narrow *within* a study** (§7.5). Customer project, part number and
order number join the studies, cells, lines and period — so a slice can now hold some of a study's
orders where before it held all of them or none. Everything downstream follows unchanged, because
they narrow the same set of orders the period already did.

- **Their options come from the run, not from the plant.** Studies, cells and lines are structure and
  are offered before a run exists; these three are values the run recorded, so the controls have
  nothing to offer until there is one. That is the right dependency rather than an awkward one:
  offering a part number the run never made would be a filter that returns nothing and looks broken,
  which is §7.10's argument for a run joining to nothing, read from the other end.
- **The project is read off the plan and the part number off the metrics.** Only the plan carries a
  customer project (§8.5); the metrics always carry a part number and are what the existing part-name
  mapping already reads, so neither takes a source it does not have to.
- **`(no project)` is a value, not a gap.** 11 % of live orders have none, and offering the eighteen
  real names while silently dropping those orders from every one of them would hide a ninth of the
  run. It is offered only when the run actually has such an order. An order the plan cannot answer
  for is read as having none, so a project filter on a pre-v12 run selects nothing and `(no project)`
  selects all of it — both true, neither inventing a project.
- **One order number names one order per study, and the field says so.** The sequence is dense per
  study (§16.15), so `5` is order five of each; every 190-order run stored has each number twice.
  Combining with the Studies filter is what narrows it to one, and the helper text appears only while
  more than one study is in view. It is **typed rather than picked** — a 190-entry menu is a list to
  scroll, not a filter to use — and anything unparseable is dropped rather than refused, because a
  half-typed `5,` means five while the comma is being typed.
- **Empty slots are deliberately not narrowed by them.** A slot is a release opportunity nobody took:
  it carries a study and an instant and no order, so there is no part to match and no project it was
  for. Narrowing them would mean inventing which part the slot *would* have carried.
- **All three are in `FilteredRun.signature`**, or a chart would keep drawing the slice before last —
  the run id and the studies are unchanged by every one of them.

**A lane is kept by the steps that name it, not by its study.** A queue belongs to the station it
stands in front of since v19 (§7.3), so `simulation_run_lanes` writes one row per *target* and stamps
it with whichever study was written last — on the real run eight of ten lanes carry one study's id
and two carry the other's. Filtering by study therefore took most of the queues away, which the field
reported as *"when filtering one study, I can't see the CLAD pool queue"*. A step records the lane
the order actually waited in and is the same thing the band is placed by, so a lane is in the slice
exactly when an order in the slice queued there. Open stays follow their order, since an order the
guard caught leaves no step to be kept by.

**And a stay takes its study from the order, not from the lane**, for the same reason one level on:
the card names the study on a multi-study run, and a shared queue's row would have labelled every
order the other line put in it with the wrong one.

**Every picker offers what could still narrow what is on screen** (§7.6). Two field complaints are
one rule: the Cells and Lines menus listed every cell and line in the *plant*, most of which no study
had ever used, so most entries selected nothing; and choosing a study left the Part numbers menu
offering parts that study never makes. Both are a menu describing something other than the thing
under it.

- **Read off the run, not off the plant.** §7.10 records each study's cell and line on the run
  precisely so a filter keeps working after the plant is re-organised, and the run's studies are by
  definition the ones that have a simulation. The filter bar reads neither `studiesProvider` nor
  `plantLinesProvider` any more, and is no longer a `ConsumerWidget`. It also means the study names in
  the menu are the ones the run recorded rather than the ones the project has today.
- **Before a run exists every menu is empty**, which is honest: the pane below says nothing has been
  run, and a menu of things that cannot narrow it would be describing the plant.
- **Each picker ignores its own selection and honours every other.** That is what keeps a
  multi-select usable — ticking `MANIFOLD` must not make `Global 23` vanish from the menu it was
  ticked in — while still letting a study narrow the parts beside it. The standard faceted-search
  rule; narrowing by *all* filters instead leaves every menu holding exactly what is already ticked.
- **One pass over the orders, not one `filterRun` per picker.** This runs on every keystroke of the
  filter bar and `filterRun` re-summarises the whole run; §14's target is 2000 orders.
- The order-number field's *"repeats in every study"* warning counts the studies the **other** filters
  leave in view, so it says how many orders a number would actually match.

**A slice fixes its signature when it is taken.** `FilteredRun.signature` was a getter reading back
through its `RunFilter` — and the filter bar keeps one long-lived `Set` per control and mutates it in
place, so a slice taken *before* an edit saw the edit through its own filter and recomputed to the
identity of the slice that replaced it. Any cache comparing old against new then found them equal and
kept its old answer: the Gantt drew the slice before last while every table beside it moved. Only the
study segment escaped, because `studyIds` is built fresh by `filterRun` rather than read through —
which is why the three §7.5 filters appeared to work *only* when a study filter was also touched. A
snapshot's identity has to be fixed at the moment the snapshot is taken; anything else is not a
snapshot. The bar copies its sets as well, so a filter never shares its caller's mutable state.

**The results view is not keyed on the slice.** It was, so that a new slice would discard the zoom
the Gantt holds — but it discarded the *view choice* with it, and a reader filtering while reading
the Gantt was dropped back onto the tables at every keystroke. The key was also unnecessary:
`GanttView.didUpdateWidget` already compares `slice.signature` and refits its zoom and drops its hover
and selection. The state that must not survive a new slice is discarded by the widget that owns it,
which is where that decision belongs.

**The Gantt's rows can be narrowed to the stations alone.** The lane bands are what make the chart
read as a queue; without them it reads as a flow, which is the other thing a reader comes to it for.
A parameter to `buildGanttChart`, so `barAt`, the hover card and the floored-bar count all follow —
nothing in the view decides a position, which is the third time §8.6's pure-geometry split has paid
off. It is view state like the zoom, not a stored preference: a setting that silently hid rows would
be a chart lying to whoever opened the app next.

**A run has two views of it, switched by a segmented control**: Results and Gantt (§8.6). What sits
*above* the control is what describes the run rather than a view of it — the timestamp and dispatch
line, the abort banner and the headline — so those stay put across the switch and only the body
beneath them changes. The Gantt then takes the full body height, which is what removes the height
cap, the second vertical scrollbar and the nested scroll it would have needed as one more section
under the production plan.

Held in an `IndexedStack`, so switching to the results and back returns the zoom the reader left
rather than refitting the chart under them. Both views read the same `StoredRun`, so opening an
earlier run from the history menu opens its Gantt with it — §8.5's rule for the plan, applied again.

This is why the tab's body stopped being one scrolling `ListView`: a child of a list cannot take the
viewport's height. The readiness panel stays above the switch, because it is about the *next* run
rather than the one being read.

**Where round-one's settings live, as built.**

- **A lane's rule and capacity** are on the inventory node's editor, below its figure and above its
  label, separated by a rule. The figure is an observation of today and these two are decisions about
  the future — the same distinction the schema makes by giving capacity its own column (§16.16).
- **A station's parallel capacity** is on the workcenter editor, beside its type. That dialog gained
  a scroll view with it, for the reason the step and inventory dialogs already had one.
- **A study's start buffer and pacemaker** are a `Run settings` item on the study's menu in the
  sidebar, beside Rename and Duplicate. A dialog rather than a panel: neither is read while working,
  both are set once and left, and the Flow tab already carries everything that *is* read while
  working. `wipCap` and `priority` are still stored-but-unreachable there (§17.5) — they belong in
  the same dialog and were left for the round that needs them.
- **Blocked time** is a column in the Queue table, beside utilization rather than folded into it: a
  station at 40 % and blocked half the run is a different plant from one at 40 % and idle, and only
  the first is fixed downstream (§8.3).

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

All durations stored as **integer seconds**, except the three that cannot be: takt, a step's Process
Specific Takt and its setup and teardown are a **value plus a unit**, because `days` means a
station's productive day and there is no station to ask until one is named (§6.1, §7.6). Process
time, changeover and takt carry a display unit
(d/h/min/s) — a 3-day takt reads `3 d`, a 30-hour process time reads `30:00:00`. Inputs accept
`1.5h`, `90m`, `30:00`, `2d` and normalise on commit. Dates are stored as local dates — a shift
calendar is inherently local.

**Dates follow the user's setting, defaulting to the locale.** Day/month/year, month/day/year or
ISO, chosen on the Settings screen and kept in `app_settings`. It was *dates follow the locale*
until a planner on an en-US machine read `8/10/2026` and had to work out which month that was.

- **Independent of the interface language, deliberately.** English UI with Brazilian dates is a real
  combination and is not reachable through a language picker.
- **It reaches the parser in the same change, because the two are one contract.** `date_input.dart`
  formats and parses through a single `DateStyle`; a display format moved on its own would make
  every date field reject what it had just shown. **ISO is accepted on input whatever the setting**,
  since it is what exports and half the spreadsheets in circulation produce and it cannot be read
  two ways — and a pinned format also still accepts what the locale would have written, because that
  is a string the app itself produced a moment earlier.
- **And it reaches the Excel export**, as a number format on the date columns (§13.1). The pattern is
  *derived* from the same `DateStyle` the screen renders with rather than listed per setting, so the
  file and the app cannot disagree — including under the default, where the pattern is whatever
  `intl` chose for that locale and no table in this repo could have known it.
- **Clock readings do not follow it.** They are 24-hour everywhere, which is this section's standing
  split, and the Gantt's axis keeps its month names (`Jan 14`): a tick is not a numeric date field,
  and `14/01/2026` under every tick is worse.
- **Reached through a scope, not a provider read per site.** Almost nothing that renders a date is a
  consumer — the hover card, the run header and the plan table are plain widgets deep inside painted
  or scrolled trees — so one `Consumer` at the root installs `DateStyleScope` and everything below
  reads it the way it reads `Theme`.

Localised en / es / pt, mirroring Chronus.

### 12.5 The read-only tables are centred

Header and cells sit in the middle of their column in the result tables — the production plan, the
queue and share-of-flow rankings, the per-part table and the occupation table. `numeric: true` is
gone from them.

**Two of the original seven are no longer result tables at all.** The takt and workcenter schedules
became editable grids (§12.6), which put them back under `DataGridColumn.numeric`'s rule rather than
this one: a column you *type* into wants its ragged left edge, because scanning for the value that
is wrong is what that edge is for. The takt table was also the one deliberately left stretching to
fill its card, and that exception goes with it.

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
parts grid, or fourteen columns on the production plan, the table simply read as cut off.

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
  into a fourteen-column plan.
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

### 12.7 How a field explains itself

Field feedback: *"dial back with the explaining text for each feature. It's too much, when needed
add a mouse hover tooltip instead."* The app had **two** conventions and this unifies them — the
flow footer's metrics were already help-on-hover with no affordance at all, while every form field
carried a permanent `helperText` two or three lines deep, so a dialog of six fields was mostly prose.

**The rule is about what the text does, not about where it goes.**

- **Help that restates its own label is deleted, not moved.** Moving it to a tooltip only hides the
  fact that it was never earning the space. `Shown instead of the workcenter code` under a field
  labelled *Label*, and `Free text, on this node` under one labelled *Notes*, are the shape of it.
- **Help that carries a definition a wrong answer depends on keeps an affordance** — a tappable `ⓘ`
  in the field's `suffixIcon`, from `common/help_icon.dart`. What `days` means on a step (§6.1.1),
  that a project's plant cannot be changed later, that availability is applied once and to process
  time only (§4.4), that a pool exception is saved per member.

Fourteen fields kept one, four lost theirs, and **no `helperText` remains in the tree** — the point
is a consistent amount of noise, so it was swept in one commit rather than a dialog at a time. A
half-swept app is louder than either end state.

`TooltipTriggerMode.tap` as well as hover: it costs nothing on a desktop mouse and is the difference
between discoverable and not for anyone driving this on a touchscreen at the line side, which is
where a current-state walk actually happens.

_Rejected: every `helperText` to a bare `Tooltip` on the field, matching the footer's metrics._ One
convention everywhere and maximum quiet — but with no affordance nobody hovers, so the definitions
would be gone rather than moved, and the `days` ambiguity §17.4 exists to prevent would be
discoverable only by accident.
_Rejected: deleting all of it._ It forces every label to stand alone, which is a real discipline.
But no label can make `days` unambiguous.

**Settings picks the same side of it.** The date format was four `RadioListTile`s and an explanatory
paragraph — most of a screen for one setting with four values. It is a dropdown with the sample
carried **inside each item** (`Day/month/year · 15/08/2026`), so the preview that made the list worth
reading survives the collapse and still describes the current choice when closed; the paragraph is an
`ⓘ` beside the heading, because it defines what `Locale` means and the label does not.

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

### 13.1 The production plan, in Excel — as built

`.xlsx`, one sheet per study, a header row, §8.5's fourteen columns, built from the same `StoredRun`
the table renders — so the file and the screen cannot disagree about what the run did (§7.10). A
planner merges it into their own system, which no PDF allows.

- **Dates as dates and durations as durations**, never the strings the screen shows. A column of
  `9.1 d` sorts `1.2 d` after `10.4 d` and pivots into nothing, and being able to do arithmetic on
  the other side is the whole reason this is a spreadsheet rather than a printout. Need date and
  material date are dates with no time of day, because none was ever entered for them; Order Start
  and Order End carry the instant, which is *more* than the table shows — fourteen columns leave no
  room for a clock and a file has no such constraint, so the two agree about the moment and the file
  says more of it.
- **And each of them carries a number format**, taken from §12.4's `DateStyle`. A typed cell with no
  format is rendered by whatever the *viewer's* Excel defaults to, which is how a column of genuine
  dates reaches a planner reading `45 872` — so being typed correctly was necessary and not
  sufficient. The pattern is derived from the same object the screen renders with, so the file says
  the date the way the app that produced it does; the two Order columns append `hh:mm`, 24-hour.
  A blank cell is left unformatted, since giving it a date format would claim it holds a date.
- **A duration is a number of days, not a clock reading.** Excel's own duration is a fraction of a
  day, and `excel`'s `TimeCellValue.fromDuration` maps onto it by taking the hour, minute and second
  of `DateTime.utc(0) + duration` — so a thirty-hour lead time would land in the file as `06:00:00`,
  silently a day short, in a column meant to be averaged. Every figure in these three columns runs
  to days. A day is 24 hours, which is what §17.4 calls a day for a headline figure, and the unit is
  in the heading because a column has one where `formatAdaptiveDuration` picks one per value. Not
  rounded: the value is the stored seconds ÷ 86 400, and how many decimals to show is the
  spreadsheet's business.
- **A value the run did not record is a blank cell, not the dash the table shows.** A dash says
  "this run predates the column" (§16.13) to someone reading; in a column about to be pivoted it is
  text, and text in a number column is what turns the pivot into a mess. Blank is the same statement
  in the file's own language. An empty string goes the same way, so the two ways of saying nothing
  do not both appear in one column.
- **The stamp is its own sheet**, carrying the build label, the generation timestamp, the project
  name, the run label and any dispatch overrides (§7.4). Above the header it would put the header in
  row 2 and break exactly the pivot the export exists for. It also maps each study to the sheet it
  went to, which is not decoration: a sheet name is capped at 31 characters and cannot carry
  `: \ / ? * [ ]`, so two long study names can reach the workbook shortened and near-identical, and
  the stamp is the only place the full name survives. Duplicates are suffixed rather than dropped.
- **The button sits beside the plan**, not on the tab's chrome: the plan is one of several tables on
  that view, and a project-level export button would not say which one it takes.

_Rejected: a PDF of the plan._ §13 reserves PDF for the full simulation *report*, and a standalone
plan PDF pre-empts a document that does not exist yet. Thirteen columns landscape is tight in any
case.

_The Gantt does not export._ A chart spanning months has to be paged across sheets or scaled to
illegibility, and it is the hardest of the three to print well.

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
- **The first order of a run never pays a changeover** — _true when this was written, reversed in
  v17._ Cold start meant no previous order and §7.6 charged only for a *different* part number. It
  now charges unless the part **repeated**, so an empty station pays in full: it is set up for
  nothing. Kept here rather than deleted because the reversal is the point — the old rule was a
  special case, and removing it is what let §7.6 become one sentence.
- **The engine's occupancy and the Summary's occupation are the same arithmetic.** Inflating a
  step's time by `(1 + rework) ÷ availability` and spending open time equals `required ÷ (open ×
  availability)`. Neither availability nor rework touches the setup since v17, matching §8.4 and
  §6.1 — a setup typed in productive days has the loss in it already.

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

### 16.16 Schema v15, from field feedback

The inventories take over the governance of the flow (§5.5, §7.4), a station may run more than one
order at once (§3.1), and a study may add a margin ahead of its derived cold start (§7.8).

**Purely additive**: six columns and two tables, no rebuild anywhere. That is deliberate rather than
lucky — the database this runs against first is the one that already survived a half-finished
upgrade (§16.11), and a step that rebuilds nothing cannot leave anything half-rebuilt.

| Change | Why |
|---|---|
| `flow_nodes.lane_rule` — nullable `DispatchRule` | The queue discipline, moved off the station. Null follows the run's rule. |
| `flow_nodes.lane_capacity` — nullable int, **in orders** | How many the lane holds; null is unlimited, which is what every lane was. **Its own column, not `inventory_quantity`** — that figure is an observation of today's WIP, and §5.5's correction is that an observation must not be read as a rule. |
| `workcenters.parallel_capacity` — int, default 1 | How many orders the station runs at once (§3.1). |
| `studies.start_buffer_days` — int, default 0 | Calendar days of margin ahead of §7.8's cold start. |
| `studies.pace_setter_target_id` — nullable text | The chosen pacemaker; null derives it as before (§18.8). |
| `simulation_run_studies.start_buffer_days`, `simulation_run_steps.blocked_seconds`, `simulation_run_workcenters.blocked_seconds` + `units` | §7.10's copy-in rule: a run says what it was run with. |
| New `simulation_run_lanes`, `simulation_run_lane_visits` | Lanes leave a trace in the run, so §8.6 can place and populate a lane row without joining back to a flow that may have been edited. |

**The carry-over is the only interesting part.** Every stored `workcenter_dispatch` rule moves onto
the lane feeding its target — the inventory node at `position - 1` of the step pointing at that
workcenter or pool, which §5.1's dense ordered spine makes exact. A target with no lane in front of
it loses its rule, which is the honest outcome rather than a loss: it described a queue the model no
longer holds anywhere, and §7.4's fallback to the run's rule is what it becomes. `workcenter_dispatch`
is **not dropped by this step** — the code reading it goes first, because dropping a table ahead of
its readers is how an upgrade strands a build.

**Two older steps had to change, for the third time.** `workcenters` is rebuilt by both the v3 step
(dropping `code`) and the v7 step (dropping `home_line_id`), and `TableMigration` copies from the
*current* Dart definition — so both now need a constant for `parallel_capacity`, a column twelve
versions in their future. This is §16.13's rule and §16.15's restatement of it arriving a third
time, now on a second table: **every column added to `workcenters` or `demand_orders` needs a line
in the old steps that rebuild them.**

**`_ensureColumn` now asks whether the table exists**, not only whether the column does. A step adds
columns to tables an earlier step creates, and `from` says only where the counter stopped — a
database whose upgrade died between the two has the version of the second and the tables of neither.
`_ensureTable` had always asked; this is the same rule applied to the other half, and it is what the
note at the top of `onUpgrade` requires. Skipping is safe rather than quiet: whatever creates the
table later builds it from the current definition, which already carries the column.

---

### 16.17 Schema v16, the tail warning

One nullable column, `simulation_runs.schedule_horizon`: the last date every schedule a run used was
actually defined for (§11.1). Purely additive — `addColumn` on a live table, no `TableMigration`,
and nothing rebuilt — so it cannot leave a database half-copied, which matters on one that has
already survived a half-finished upgrade (§16.11).

**Why it needed storing at all.** §11.1's warning was specified in M2 and never built, because there
was nowhere to put the one fact it needs. The count of orders past the horizon is derivable from
`simulation_run_orders`; the horizon itself is not derivable from anything the run holds, and §7.10
forbids reading it back off the plant — the periods may have been extended since, which would make
an old run quietly stop warning.

Null on every run made before this version, which reads as *no warning* rather than as *everything
is past it*. The v14 → v15 fixture asserts exactly that, since it is the same shape of run.

### 16.18 Schema v17, a changeover in two halves

Nine nullable columns across three tables, and **nothing rebuilt** — the third migration running
where every step is an `addColumn` on a live table, which is the only shape that cannot leave a
database half-copied (§16.11).

| Table | Columns | For |
|---|---|---|
| `flow_nodes` | `setup_value` + `setup_unit`, `teardown_value` + `teardown_unit`, `same_part_percent` | §7.6's changeover, in two halves with a repeat percentage |
| `simulation_run_steps` | `changeover_seconds` | what the changeover actually cost (§7.10) |
| `simulation_run_studies` | `production_cell_id` + `_name`, `production_line_id` + `_name` | filtering a stored run by cell and line (§12.1) |

**Setup is a value plus a unit, not canonical seconds**, and that is the whole reason it could not
reuse the column it replaces. `flow_nodes.changeover_seconds` was seconds, which is exact and says
nothing; a setup of `1 day` cannot be reduced to a duration without saying whose working day is
meant, and the answer differs per station — the same argument §6.1 makes for takt and §6.1.1 makes
for the Process Specific Takt sitting two fields above it in the same dialog. `days` means that
station's **productive** day in all three, so the dialog has one kind of day (§17.4).

**The carry is selective, and the source column stays.** Every non-zero `changeover_seconds` was
copied to `setup_value` with unit `seconds` — literal, and identical at every station, so the typed
figure survives exactly. A zero carries as **null**, because zero and nothing charged were always the
same thing and null is what an untouched node reads as. `changeover_seconds` itself is **kept and no
longer read**: dropping a column means a `TableMigration` rebuilding from the current Dart
definition, which is the trap this file has hit three times (§16.13, §16.15, §16.16), and it is also
the only place a pre-v17 setup can be recovered by hand.

**What the migration preserves is the figure, not the charge.** §7.6 stops derating setup by
availability in the same round, so a 90-minute setup at a 74 % station occupies 90 minutes rather
than 121.6. That is the point of the change rather than a side effect of it, and it is why every
stored run is invalidated by v17 — the third time, after §5.5's buffers and §7.4's lanes.

**A null percentage is 0 %**, which is exactly the rule v16 followed: a repeat of the same part paid
nothing. So an upgraded database behaves identically until a number is typed into it.

`simulation_run_steps.changeover_incurred` survives beside its replacement rather than being derived
away, because a run made before v17 can still answer the bool and can never answer the seconds. Null
there means *made before this column existed* — deliberately not zero, which would claim a changeover
was free when the run simply was not asked.

The v16 → v17 fixture carries a **populated** changeover for §16.14's reason: a fixture full of
nulls passes whether or not the carry ran. Removing the `UPDATE` fails it on `5400` against `null`,
which is the check that the test is about the migration rather than about the schema.

### 16.19 Schema v18, the pool a station ran in

Two nullable columns on `simulation_run_workcenters` — `pool_id` and `pool_name` — for §3.1's
complaint that a pool's members read as loose machines. The shape §16.18 used for the studies' cell
and line, and **no table is rebuilt for the fourth migration running**: every column is nullable and
lands on a table that already exists, so no step can leave one half-copied on a database that has
already survived an interrupted upgrade (§16.11).

**Nothing is backfilled, and that is the whole point of the step.** Membership lives in the plant and
`workcenter_pool_members` may say something different today from what the run dispatched through; a
backfill would make every stored run claim a grouping it never observed. So the 35 runs already on
the real database group nothing, which is §7.10's blank-is-not-a-wildcard rule rather than a gap.
The v17 → v18 fixture puts the station **in** a pool in the plant and asserts the run's columns are
still null, which is what makes the test about the decision rather than about the DDL.

**No stored run is invalidated**, and after §16.18 that is worth stating. No figure moves, no charge
changes and the arithmetic is untouched — `HISTORY.md`'s numbers stay comparable across v18, which
was not true of v15, v17 or §5.5's buffers.

The v17 fixture is **built from the v16 one** rather than copied from it: eighty lines of DDL
duplicated to add five columns is how two fixtures come to disagree about the version they both claim
to be. The v16 → v17 test's version assertion now reads `db.schemaVersion` rather than a literal —
what it was ever asserting is that the upgrade ran to completion, and pinning the number made the
arrival of a later version read as that step failing.

### 16.20 Schema v19, a queue belongs to a station

**The first migration in this repo that moves data between concepts**, and after four consecutive
migrations that only added nullable columns it is worth saying which parts of §16.11's rule still
apply and which do not.

| Table | What | For |
|---|---|---|
| `project_queues` | new, keyed `{project_id, target_id}` — name, rule, capacity, and the stock standing there as mode + quantity/seconds + unit | §7.3's queue, one per thing a step targets |
| `studies` | `inbound_stock`, `outbound_stock` | the flow's two ends (§7.3) — **added ahead of their surface; nothing reads or writes them yet** |
| `simulation_run_workcenters` | `queue_type`, `queue_capacity` | what each station of a run dispatched by, copied in per §7.10 |

**The key is `{project, target}`, which is the seam the workcenter schedule already uses.** A target
is a workcenter or a pool as a whole, so `CAL Pool` has one queue and its three machines pull from
it. Project-scoped rather than study-scoped, so capping a lane stays the per-project experiment §0
actually ran on `FIFO CEU27`.

**The two `studies` columns are the honest exception on this table.** They landed with the migration
because a schema step is cheaper taken once, and the surface that fills them was not built. A reader
finding them populated by nothing is reading the truth, not a bug.

#### The fold

Each `inventory` node becomes part of the queue in front of the step **after** it on its own spine —
that step's target is what the node was really describing. Several nodes therefore land on one row:
on the database this was written against, **15 nodes fold onto 10 targets**, because the two studies
share five stations and disagree about two of the names. That count *is* the field's complaint seen
as data — there is one floor space in front of BAN11 and the map was carrying `FIFO BAN` and
`FIFO BAN11` for it.

**First study wins, by study then position.** The first node to reach a target sets the name; a later
node's non-null rule, capacity or stock fills a **blank** rather than being lost, so nothing that was
actually configured is dropped in favour of something unset. `study_id` is a uuid, so the order is
arbitrary — but it is stable, which is all determinism needs.

**Every value not taken is named in the diagnostics log**, as `v19.discarded` against its target, and
`v19.fold` states the two counts. So `FIFO BAN11` is recoverable by reading the log — and, better, by
reading the row it came from.

**An inventory node with no step after it is dropped and said out loud** (`v19.orphan`). It describes
a queue in front of nothing, and a queue belongs to a target. Guessing one is the rule §8.6 already
refuses for a lane no step ever named. This is the case to know about when a v19 database disagrees
with a v18 backup: a trailing buffer, or two buffers in a row, has silently lost its figure.

**The fold is guarded on `project_queues` being empty, not on `from`.** An upgrade interrupted after
the insert would otherwise fold a second time and overwrite a queue the user has since edited —
§16.11's half-upgraded database arriving where a data move, rather than a table rebuild, is what it
would corrupt.

#### What is kept rather than cleaned up

- **The `inventory` rows stay, and stop being read.** The same call §16.18 made for
  `changeover_seconds`, and stronger here: the row is a better recovery path for a discarded name
  than a log line is, and deleting it would make the upgrade irreversible against a v18 backup for no
  gain but tidiness. `FlowNodeKind.inventory` therefore stays in the enum so a stored value remains
  parseable; nothing constructs one.
- **`simulation_runs.dispatch` is written empty rather than made nullable.** The column is `NOT NULL`
  and widening it means a `TableMigration` rebuilding the largest header table in the app — the trap
  §16.11, §16.13, §16.15 and §16.16 are each a record of. Empty parses to no rule, so it contributes
  nothing and every station of a v19 run speaks for itself; the 35 runs made before v19 keep the
  single rule they really were made with, and it fills in for them per station.
- **`SimLane.study_id` and `SimLane.position` are kept and no longer read.** v19 made a queue belong
  to a target, so a lane's study is whichever one was written last — on the newest stored run, eight
  of ten lanes carry one study's id and two carry the other's. Two surfaces went on asking it and
  both were wrong (§7.5). They are **recovery-only**: they say which node a lane was and where it sat
  on that study's spine at the time, which is the only way back to a pre-v19 run's shape. Nothing may
  read either for behaviour.

**Stored runs are invalidated where two studies shared a target, or a lane carried a capacity.** Two
floor spaces became one, so contention that the engine used to split is now shared — the fifth time
after §5.5's buffers, §7.4's lanes, v15 and v17. A run against a single-study flow with uncapped
queues is unaffected.

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

### 17.2 Running days in the footer — a conversion, after all

The footer states the lead time twice: **`Lead time (working days)`**, which is
the ladder's own figure summed in each station's productive day, and
**`Lead time (running days)`**, which is that **× 1.4**.

**This reverses what this section used to say, and the reversal is the point.**
The original text read: *"It is a walk, not a conversion (`_walkCalendar`) … the
gap between the two figures is the closed time, which no ratio could produce."*
That argument is still correct and it lost anyway.

What happened is worth recording, because the reasoning was sound at every step
and still produced the wrong feature. The field reported both figures as wrong
and asked for `running = 1.4 × working`. An interview established that 1.4 is
7 ÷ 5, that the real defect was that `Lead time` summed *productive* days while
running days walked the calendar — two different questions under one label — and
that taking both figures from one walk would make the ratio **fall out** rather
than be imposed: 1.0 on a seven-day plant, wider across a shutdown. That was
built, driven, and rejected on sight, with the two walk figures called out by
name as making no sense on the bar.

**So the map states the convention and the run states the measurement**, and the
split is cleaner than the compromise was:

- **The map is a planning document.** A planner reading `12 working days` expects
  `17 running days` beside it, and expects that to be the same arithmetic on
  every map they have ever read. It is a restatement, the two cannot disagree,
  and that is what makes it legible.
- **The simulation is the measurement.** §7.2 walks each station's real calendar
  and charges the weekends and shutdowns this plant actually has. When the two
  differ, the run is what happened.

**`_walkCalendar` is deleted, and the second time it took the footer is why.**
Kept-but-unreachable did not hold. §7.9 later ruled that the map and the plan
should report one walk, and the walk's end date was wired into the footer's
`Lead time (working days)` slot — where it stayed, mislabelled, because the label
was written for this section's figure and never revisited. What was on screen was
an **elapsed calendar span, weekends included, under a label reading "working
days"**, sitting next to `running days` holding `working × 1.4` — the two the
wrong way round, and near enough in value to be hard to catch.

Two further casualties of that arrangement, both of which had a comment in the
tree claiming otherwise: the ×1.4 stopped being checkable on screen, because the
figure it is 1.4 of was no longer displayed; and PCE's denominator left the footer
while PCE stayed on it.

So the split this section describes is restored and the walk goes with it,
`endDate`, `runningDays` and `workingDays` included — the last two computed on
every rebuild and displayed nowhere from the day they were written. §13's report
can walk the calendar itself if it ever wants a calendar-true span; keeping a
tested, unreachable function against that day is what put it back on screen in
the wrong slot.

_The lesson, and it is not about calendars:_ an interview can settle what a
figure *should* mean and still be answering a question the field was not asking.
Both figures were correct; neither was wanted. The cost of finding out was one
round trip to a running build, which is exactly what §2.0's rule buys and the
reason it is worth its context switches.

_The second lesson, and it cost more than the first:_ a decision recorded in one
section can be overturned by another that never names it. §7.9 did not argue
against this section — it did not know it was there. **A figure's label and its
contents were owned by two sections that never referenced each other**, which is
how a map ended up counting weekends under a heading that says working days. The
cross-references in both directions are the fix, and they are load-bearing.

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
| ~~`_walkCalendar` and `FlowView.endDate` / `runningDays` / `workingDays`~~ | **deleted** — this row's own reasoning is what went wrong. Kept as a tested answer to a question that would be asked again, it was reached again: §7.9 wired the end date into the footer's `working days` slot, where it sat mislabelled as an elapsed span counting weekends, and `runningDays` / `workingDays` were never displayed at all. §13's report can walk the calendar when it needs one. **The lesson for this table**: unreachable code with a plausible future consumer is not inert, it is a loaded slot | — |
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
