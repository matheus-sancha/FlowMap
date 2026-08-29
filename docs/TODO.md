# FlowMap — what is next

Working state as of 2026-08-29. This file is **only unstarted work**, and each item should be
deleted from it as it lands. `docs/DESIGN.md` is the source of truth for *why*; `docs/HISTORY.md`
is the source of truth for *what already happened* — the finished rounds, the run identifiers, the
migration timestamps and the backup filenames.

Branch `m1-m2-foundation`, `flutter analyze` clean, **948 tests passing** (one of them `live`-tagged
and skipped without a database). Schema is at **v24 and so is the live database** —
`db.open schema 24 from 23` at 16:00:57 on 2026-08-29 under **`0.1.0-2026-08-29c`**, with
`flowmap.sqlite.backup-v23-20260829-160002` taken 55 seconds before. _v22 was the state this header
was written at: `db.open schema 22 from 21` at 21:57:36 on 2026-08-27 under `0.1.0-2026-08-27a`,
against a copy first and with `flowmap.sqlite.backup-v21-20260827-215250` beside the live file._ v20 and v21 met it
on 2026-08-18 under `dev` builds, recorded late from `log.txt` because nothing was written down at
the time. **None of §7.3's tail, §7.4 or §7.6 needed a migration** — the flow's two ends found their
columns already there, and §7.4 turned out to store nothing at all. **§7 is code-complete, §7.9
included**: the takt had never once reached a run and now belongs to the order that opens under it.
M4 is code-complete, and the initial plan has no code left in it — §3.8 is deferred by decision and
everything else in it has landed.

**Two entries in a row over-specified their own cost**, which is worth watching for: §7.3's flow-ends
stock called itself "a schema step (v20)" when the columns already existed, and §7.4 said "what is
stored is the group's measured total" when the sum of cells the demand table already holds *is* that
total. Both were written before the code around them was read.

**The one thing to know before starting anything: almost nothing here has been looked at.** §5, §6,
§7.5 and §7.6 are code-complete and covered by tests, and **nothing in the suite renders a pixel**
(§2.7). The drive of `0.1.0-2026-08-16d` — half an hour of one person clicking — found **three
defects that 765 tests had nothing to say about**, all of them §7.3's re-model reaching a surface
nobody re-read. That is the ratio to plan around: driving is not a formality after the work, it is
where the defects are. §5.3, §7.5, §7.6 and §7.9's surfaces are the open drive lists.

**§7.9 is the exception and it is worth knowing why.** Its engine half was checked against the
**stored run** rather than against the screen — the takts each order opened under, the work charged
either side of the change, and which rows moved in the studies that share stations with it. That is
a kind of evidence this repo had not used before, it is repeatable by anyone reading §7.9, and it
caught one of my own drive-list expectations being wrong. **It says nothing about the four surfaces**
(§7.9's second list), which remain reported-working and unitemised.

**And §7.6 is the sharper version of the same lesson**, because it was found by reading rather than
by clicking: Lead Time Efficiency had shipped **upside down**, and it survived because three sections
of `DESIGN.md` described the reciprocal and all agreed with each other. **A suite that agrees with a
wrong premise is not evidence.** §7.6 is the round that fixed it and the four things it reached.

**Latest build is `0.1.0-2026-08-27a`.** The history picker holds **104 runs**, and they are now
three generations rather than one: ninety-odd made before v19 draw per-node lanes rather than one
queue per target; those from 2026-08-18 carry a step's work but one takt for the whole run; and only
`7669856d` and the three after it were made under §7.9, where the takt belongs to the order. **A
stored run is read with the build that made it in mind**, which is what §7.10's copy-in rule is for.

**And the plant itself changed during the last drive**: 11D's line no longer has a 5-day takt period
— it was deleted after `7669856d`, which is why the three runs following it leave 23 orders unopened.
**Anyone re-driving §7.9 has to put it back**: 4 days to 2026-03-31, 5 days from 2026-04-01.

**Seven new items came out of the 2026-08-29 drive, and they are §8 and §9.** They are features
rather than defects — with one exception, §8.1, which was reported as a surface complaint and
turned out to be the engine letting an order queue at a station its part never visits. **The
provenance is on record this time**: `log.txt`'s last session is 07:59:57 under
`0.1.0-2026-08-27a` at `db.open schema 22 from 22`, and this file was written at 08:25, one
minute after that session's last route. §5.3 is the entry that had to be un-ticked for lacking
exactly that pair.

**§0 was driven on 2026-08-29 and is all but closed** — 31 of 37 checks under
`0.1.0-2026-08-27a`, session 10:09:31, recorded in `docs/DRIVE-2026-08-29.md`. **It found four
defects**, three of which are now §8.5, §8.6 and §8.7 and none of which 892 tests had anything to
say about; the fourth turned out to be §8.1 wearing a visible face. What is left is three es/pt
checks **blocked** by §8.7, the Equivalent chip, and *"write down what grated"* — which is still the
only item in this file that nobody but the field can close.

**§0 gates §8, and the interview settled it that way deliberately.** §8.1 invalidates every
stored run — the fourth time, after §2.12, §3.1 and §1 — and §0's own argument is that its
checks are *"cheaper now than after §1, because after §1 the engine no longer produces the
figures that raised the question"*. The same is true here. So the order is: clear §0, §5.3,
§6.7 and §7.9's surfaces with no code at all, then §8, drive it, then §9, drive it.

**Rounds one to four are gone from this file**, moved to `HISTORY.md` §5 on 2026-08-29. They landed
on 2026-08-15 and had been sitting here in defiance of this file's own rule that it holds only
unstarted work — the last open item in §0, and the reason neither file could be trusted to answer
*what already happened*. **Their numbering travelled with them**, so every §1–§4 this file still
names — §2.7's *"nothing in the suite renders a pixel"*, §3.6's date format, §4.2's two write paths,
§4.6's slice check, §1.7's node notes — resolves in `HISTORY.md` §5 rather than here. Where a §1–§4
appears against a `DESIGN.md` claim it means `DESIGN.md`, as it always did; that ambiguity is older
than this move and is not made worse by it.

**A round gets a hand-driven pass after it, and one before the first.** That is §2.0's rule;
`HISTORY.md`'s §16.11 is the record of what ignoring it costs. **§5 and §6 keep it** — the interview
settled them as one round driven at the end, and they were split again once §5 was written, so the
bug fix can be checked against the screens that reported it before §6 moves those screens. **§8 and
§9 keep it too**, and §0 keeps it for both.

| | | |
|---|---|---|
| **§0** | Clear the debt | no code — drive what is owed |
| **§5** | The pool and the lane | two bugs from the field — **written, not driven** |
| **§6** | The workspace | five tabs, one simulation, less chrome — **not driven** |
| **§7** | The queue, the filter and the balance | from driving `0.1.0-2026-08-15g` |
| **§8** | Round eight | the phantom visit, five surfaces, and a save that fails |
| **§9** | Round nine | a process time belongs to a step — **found by driving §8** |
| **§10** | Round ten | Project Settings, occupation over time, the float matrix |
| **§11** | Known gaps, deliberately left | |
| **§12** | Deferred by decision | §3.8, the map that never runs |
| **§13** | M5 | |

---

## 0. Clear the debt first — no code

Everything here is a check on something already shipped, and everything here is cheaper now than
after §8, because after §8 the engine no longer produces the figures that raised the question.
Hours, not days.

_This sentence originally named §1, which has since landed and moved to `HISTORY.md` §5. The
argument did not change — a fourth engine change is in front of it now instead of the third._

**Set up 2026-08-15.** Baseline re-confirmed before anything was touched: `flutter analyze` clean,
**669 tests passing** and one `live`-tagged skip. Release rebuilt and launched under label
**`0.1.0-2026-08-15b`**; the session header at 11:10:27 reads that label and `db.open schema 16 from
16` — a no-op open, so Release found the database already migrated and did not touch it. A v16
backup was taken first, as **`flowmap.sqlite.backup-v16-20260815-110857`**. `live_db_check_test.dart`
was run against a copy and confirms the stored configuration is still `2f4c8db4`'s: `FIFO CEU27`
capped at 2, TTAT at two units, Célula 11B on a 30-day buffer with a named pacemaker, 60 orders, 35
runs, **0 of 35 carrying a horizon**.

**The Aug-3 exe rule held this time**, which is worth one line since `HISTORY.md` records it
breaking earlier the same day: `app.so` moved to 11:09 and `flowmap.exe` stayed at 10:03. That is
the useful half of the rule working as stated — `app.so`'s timestamp says the Dart code was rebuilt,
and the exe's says nothing either way. Read the session header's build label, which is the only
claim a stale link cannot produce.

- [x] ~~**One confounder run.**~~ **Done 2026-08-15 in `0.1.0-2026-08-15b`, and it overturns round
      one's conclusion.** The capacity was taken off `FIFO CEU27` with the pacemaker left on CEU27,
      isolating the takt change from the lane gate. Run `ab587589` (re-run identically as
      `32fdd07a`, same figures to the decimal, which is §4.4's determinism observed rather than
      asserted):

      | run | takt | cap | pacemaker | avg LT | blocked | empty slots |
      |---|---|---|---|---|---|---|
      | `5bf76ac1` | 2.42 d | — | derived | 47.2 d | 0.0 d | 6 material |
      | `676fb0e3` | 2.42 d | **2** | derived | 47.2 d | **216.4 d** | 6 material |
      | `ab587589` | **3.14 d** | — | **CEU27** | **34.1 d** | 0.0 d | 13 material |
      | `2f4c8db4` | 3.14 d | **2** | **CEU27** | 31.1 d | 4.6 d | 8 + **7 laneFull** |

      **The confounder was most of the effect.** `HISTORY.md` records round one concluding that
      *"with the gate on the capped lane, the average order lost 16 days"*. It did — but **13.1 of
      those 16 days are the takt** (47.2 → 34.1, from naming CEU27 the pacemaker and inheriting its
      productive day per §7.2), and only **3.0 d** are the lane cap and gate (34.1 → 31.1). The
      round attributed to its own mechanism an improvement that mostly belonged to a side effect of
      configuring it.

      **What round one got right, and is now sharper: capping alone is actively harmful.** It moved
      lead time 47.2 → 47.2 — not at all — while manufacturing **216.4 d of blocking** at TTAT. The
      gate is what makes a cap *safe*, not what makes it useful. A capacity without a gate on the
      same lane converts queue into blocking and buys nothing.

      **And the plain finding underneath all of it: célula 11B is over-released.** Releasing 30 %
      slower took 13 days out of the average order and cost nothing measurable — all 60 orders
      delivered, 60 of 60 on time, in every one of the four runs. That is a statement about the
      plant rather than about the app, and it is the most useful thing any run has said so far.

      _Left standing:_ on-time is 60/60 in all four runs because the 30-day start buffer swamps the
      differences, so **on-time cannot currently discriminate between these configurations** and
      lead time is doing all the work. A run at a smaller buffer would say more.
- [x] ~~**The date format, set on Settings.**~~ **Correct.** **Driven 2026-08-29** under `0.1.0-2026-08-27a`, session 10:09:31, `db.open schema 22 from 22`. Check the demand grid re-parses what it renders after
      the format changes — that is the pair §3.6 exists to keep together — and that the Gantt's axis
      still reads `Jan 14` rather than a numeric date. §3 makes both those tables grids too, so a
      parser that is wrong here is wrong in three more places afterwards.
- [x] ~~**The plan in Excel, opened in Excel.**~~ **Good, reported as part of a group of five.** **Driven 2026-08-29** under `0.1.0-2026-08-27a`, session 10:09:31, `db.open schema 22 from 22`. _Original text:_ §13.1 is asserted by decoding the file back, which
      proves the cells are typed but says nothing about how Excel *renders* them: a date column
      whose default format is `45 872` and a duration reading `1.2500000000` are both technically
      correct and both unusable. Export the célula 11B plan, open it, check the dates read as the
      chosen format, that Order Start shows its time, and that sorting Float puts the late orders
      where a planner expects. In es and pt as well — a locale decides how Excel itself formats a
      date cell.
- [~] **The results banner — driven, and it found §8.5.** **Driven 2026-08-29** under `0.1.0-2026-08-27a`, session 10:09:31, `db.open schema 22 from 22`. The banner pushes the tabs down and `View results` navigates, dismisses and lands with the right study filtered. **But pressing Simulate does not always run**, and the banner reports the last stored run's figure when it does not — §8.5. _Original text:_ That it pushes the tabs down rather than covering the Gantt's last
      row, that `View results` both navigates and dismisses, and that a failed run offers no
      `View results` but can still be closed. **The workspace screen has no test coverage at all**,
      so the wiring from Simulate to banner to tab switch is only covered by pressing it. §4 rebuilt
      that screen and §6 rebuilds it again — and §6.1 changes what `View results` *means*, since
      there is no longer a tab to switch to. Check it against whatever §6 leaves standing, not
      against this description.
- [x] ~~**The schedule horizon gets written.**~~ Done 2026-08-15, and it fell out of the confounder
      run rather than needing one of its own. All 35 earlier runs carry a null horizon because every
      one predates v16; `ab587589` and `32fdd07a` both carry **2026-12-31**, which is exactly the
      date every takt and workcenter period runs to. So the v16 column is written as well as stored,
      and the failure this repo has had twice (§1.5, §2.3) has not happened a third time. **§11.1's
      warning correctly stays silent** — the run ends two months inside the horizon. Making it fire
      on purpose, by shortening a takt period to before the run's end, has still not been done and
      is the only part of §11.1 never exercised against real data.
- [x] ~~**The readiness panel against a real gap.**~~ **Works.** **Driven 2026-08-29** under `0.1.0-2026-08-27a`, session 10:09:31, `db.open schema 22 from 22`. A step on Célula 11D set to **"None"** in the **"Workcenter or pool"** field greyed Simulate, the tooltip named the study, and the popover listed 11D. The oldest unexercised path in the app. _Original text:_ It has only ever been seen clean. Unbind a step or
      clear a takt period and check it names the study and disables Simulate. What is covered
      underneath it is `SimRunInput.canRun`, eight ways in `simulation_repository_test.dart`; what
      has never been seen is the wiring — a real edit, through the providers, to a non-empty problem
      list on screen.
- [x] ~~**The Gantt's round-two geometry.**~~ **All of it, on `2f4c8db4` and `7669856d`.** **Driven 2026-08-29** under `0.1.0-2026-08-27a`, session 10:09:31, `db.open schema 22 from 22`. Axis, zoom to the dead stop, changeover stroke, frozen labels, hover card at both edges, the capped lane, the pool rows and both themes — the four needing a deliberate action were confirmed one at a time. **And it found the row-order defect** now written up in §8.1. _Original text:_ The overlap fix changed every
      band's height, so what was already looked at is worth a second glance rather than being taken
      as still true. Open `2f4c8db4`: `FIFO CEU27` is capped at 2 and the band should be visibly
      full while TTAT's 4.6 d of blocking sits in the row above it. **Nothing in the suite renders a
      pixel** — the lane bands, the wash-out fill and the two rails have never been looked at.
      Still never looked at from §2.7's own list: the axis at the opening fit (a ~2-year run should
      tick in quarters, each label standing alone as a date); ten zoom presses reaching one hour
      across the pane and going dead there, with the instant under the middle of the pane staying
      under it; the changeover stroke on a bar wide enough to carry it and its absence on one that
      is not; the frozen labels against a long station name; and the hover card at the right-hand
      edge and on the bottom row, the two places it has to be pushed back inside. Both themes.
- [!] **es and pt — BLOCKED, and now understood.** Not skipped: **the app has no language picker at all** (§8.7), so this was never performable. It has been carried as an open check since 2026-08-15. _Original text:_ across the four round-one dialogs, which carry the longest help text in the
      app. `El carril admite 2 pedidos` is the longest of §3.4's three strings.
- [ ] **Confirm the Equivalent chip is already right.** `flow_view.dart:554` returns null unless the
      data source is a demand part — *"Null under `FlowDataSource.flowEquivalent`, where it is 1.0
      by construction"* — and the footer only draws the chip when it is non-null. So "not shown when
      Flow Equivalent is selected" appears to be **built already**. If it is on screen under Flow
      equivalent, that is a defect to reproduce, and §2 is where it would be fixed.
- [ ] **Write down what grated.** Layout polish was noted at the GUI on 2026-08-11 and explicitly
      deferred, and **the specifics were not captured**. This is a placeholder rather than an item,
      and it stays one until somebody writes the sentences. §2, §4 and now §6 all move layout, so
      anything not written down now will be guessed at or lost.
- [x] ~~**Rounds one to four go to `HISTORY.md`.**~~ **Done 2026-08-29.** They are `HISTORY.md` §5,
      verbatim and demoted one heading level so their own numbering still resolves. That file's last
      entry had been the 2026-08-11 feedback round; §1–§4 landed on 2026-08-15 and were recorded
      nowhere else. `TODO.md` stops carrying two jobs.

_Parked, not owed: **the pool fix against célula 11B.** The CLAD Pool of three reads 63 %
occupation and a flow equivalent of 0.99, which is the right shape; comparing it against what it
read before the fix needs a build that no longer exists. Recorded rather than chased._

---

## 5. The pool and the lane — round five, **written, and not yet driven**

Settled by interview on 2026-08-15, after driving `0.1.0-2026-08-15b` with **two studies in one
run** — the first time the build has been asked the question §7.7 exists to answer. Two things came
back from it, and reading the code for them found a third nobody had reported.

**The code is written and none of it has been seen**: `flutter analyze` clean, **736 tests passing**
after §6, schema at **v18** in the tree. The live database is still at **v17** — the last session in
`log.txt` is 15:27 on 2026-08-15 under `0.1.0-2026-08-15f`, which predates every line of this round.
§5.3 was briefly ticked on a verbal report and is unticked; the entry there records why.

**Split from §6 deliberately.** The interview settled these two bugs and the workspace restructure as
one round driven at the end; they are separated again because this half is *finished and checkable*
against célula 11B, and §6 rebuilds the screens that display it. Driving a bug fix before the
surfaces around it move is §2.0's rule arriving by the front door rather than being waived — and
§16.11 is what waiving it cost last time.

**No stored run is invalidated.** §5.1's columns are additive and nullable and no figure moves, so
`HISTORY.md`'s numbers stay comparable across it — which is not true of §1 and is worth stating
because it is the exception.

| | |
|---|---|
| **§5.1** | Schema v18 — the pool a station ran in |
| **§5.2** | The Gantt's lane bands, which were losing one |
| **§5.3** | Drive it |

### 5.1 Schema v18 — the pool a station ran in

*Field, 2026-08-15: "CLAD07 appearing out of the CAL pool with two FIFOs."*

**A run's stations are machines, and nothing says which pool they came from.** §3.1 is emphatic that
a pool is real workcenters with their own schedules — `sim_assembly.dart` expands a pool step into
one candidate per member, so `CAL` is never a row and never was. That is right. What is wrong is
that the three members then sit wherever the Queue table's ranking puts them, unlabelled, with
nothing on screen saying they are one pool. A reader who typed `CAL Pool` into the map is owed the
word back.

`SimulationRunWorkcenters` gains **`pool_id` and `pool_name`, both nullable**, exactly the shape
§1.5 used for the studies' cell and line. Additive, so no stored run is invalidated and no figure
moves.

**Resolved at write time, not at read time.** Joining `poolMembershipProvider` when a run is opened
would regroup every historical run the day a machine moves between pools — the drift §7.10 snapshots
names to avoid, and which §12.1 already wrote an explicit rule against for the pre-v17 cell.

**A workcenter can be in several pools**, since `WorkcenterPoolMembers`' primary key is
`{poolId, workcenterId}` — and with two studies in one run, line A can reach CLAD07 through `CAL`
while line B reaches it through some `All Lathes`. So the write resolves the pools the station was
actually dispatched through in *this* run: **exactly one → store it; zero or more than one → store
null**, and the station sits ungrouped, labelled with the pool names it served. The rare case
degrades where a reader can see it rather than picking a pool arbitrarily.

**A pre-v18 run groups nothing**, which is §12.1's rule that a blank is not a wildcard, arriving for
the third time.

_Rejected: the pool on `SimulationRunSteps`._ Unambiguous per step, and it would answer "which pool
sent this order here" — but it is a column on the largest table in a run (~4k rows for 500 orders)
to serve a grouping that the station row can carry. Worth revisiting if the per-order question is
ever asked.

_Rejected: one aggregate row per pool._ Closest to how a planner speaks, and it loses the per-machine
yardstick §3.1 spends four paragraphs protecting.

**The Gantt groups; the Queue and Share tables label.** Settled while writing it, and it is a real
departure from what the interview said. §8.1's two tables *are* rankings — the first row is the
station that queued most, and that is the whole question they answer — so clustering a pool's members
would mean the top row was no longer the answer. The Gantt has no such ordering to lose: it runs down
the page in flow order, where a pool's machines already sit together, so a heading there costs
nothing. The tables get the pool name beside the station instead, on one line because a `DataTable`
row is a fixed height.

### 5.2 The Gantt's lane bands, which were losing one

**`_laneRows` returns a map keyed by `workcenterId`, so a second lane feeding one station silently
overwrote the first.** Two studies both stepping on the CAL pool is exactly how that arises, and it
is why the field saw two FIFOs where the chart could only ever have drawn one of them. A band that
disappears is worse than a band in the wrong place: nothing on screen says a lane is missing.

**And the placement was never what the doc claimed.** `gantt_layout.dart`'s comment says a lane
feeding a pool is drawn above the first of that pool's machines, *"which is where the ordering above
has already put the busiest of them"* — but `feeds` is built by walking `result.steps` and taking
`putIfAbsent`, so the lane lands on whichever member happened to pull an order out of it first. That
is the member that looked detached from its siblings.

Both are one fix:

- **A lane band attaches to the step's target, not to a machine.** A lane feeds a pool step, so it
  draws above the whole pool's group header — which §5.1 has just made available, since station →
  pool is already resolved for the grouping.
- **A target carries a list of bands rather than one.** Two studies' FIFOs both draw, in a stable
  order, and neither is lost.

`buildGanttChart` keeps its pure-geometry split (§2.7), so `barAt`, the hover card and the
floored-bar count follow for free. That is the fourth time that split has paid off and the first time
it has paid for a bug rather than a feature.

_Rejected: merging lanes that feed one station into a single band._ No overwrite and no extra rows,
and a reader can no longer tell which lane an order stood in — §5.5 makes a lane's rule and capacity
per-lane decisions, so the bands are not interchangeable.

### 5.3 Drive it

Both fixes are covered by tests — five in `gantt_layout_test.dart` reproducing exactly what the field
reported, three in `sim_assembly_test.dart` for the resolution rule, one migration test for v18 — and
**nothing in the suite renders a pixel** (§2.7), so the heading, the band order and the label column
are only covered by pressing it.

- [ ] **The run that raised it.** Two studies stepping on the CAL pool: the pool heading over its
      members and **both** FIFO bands above it, neither missing. That is the whole of what the field
      reported, and it is one screen.

      _The build exists and the schema is live now:_ v18 migrated at **21:55 on 2026-08-15 under
      `0.1.0-2026-08-15g`** (`db.open schema 18 from 17`), against the backup
      `flowmap.sqlite.backup-v17-20260815-211047` taken minutes before. Sessions have run under `g`,
      `h`, `i` and `j` since. So this check now has a database to be made against — what is missing
      is somebody looking at the chart.

      **This was ticked on 2026-08-15 and is unticked, because the tick was wrong.** It was recorded
      as confirmed on a verbal report and written up as *"the migration ran to get there, so v18 has
      now opened the real database as well as a fixture"*. None of that happened. The evidence,
      gathered afterwards rather than before:

      | | |
      |---|---|
      | `PRAGMA user_version` on the live database | **17** |
      | `pool_id` / `pool_name` on `simulation_run_workcenters` | **absent** |
      | last session in `log.txt` | **15:27:15, `0.1.0-2026-08-15f`, `db.open schema 17 from 17`** |

      There is no session of any kind after 15:27, and every line of §5 landed after it. So whatever
      was looked at, it was not this build against this database — and the entry claimed a migration
      that the schema says never ran.

      _The lesson is §0's own, arriving from a new direction._ That section already says the session
      header's build label is the only claim a stale link cannot produce, and this entry was written
      **without one** — it noted the omission and ticked the box anyway. A drive with no label
      recorded is not a weaker record of a drive; it is not a record that a drive happened. The box
      does not get ticked again until an entry can cite a label and a `db.open` line.
- [ ] **The pool reads on the rows, and the machine name is not cut.** ~~The heading reads as a
      heading, not as a fourth machine — 18 px against the stations' 30, the primary colour in the
      frozen label column, no band fill, and nothing hovers on it.~~ **There is no heading.** Driven
      on the first v19 chart, it read as a fourth machine anyway — *"it looks like there is a pool
      lane, then a fifo, then the clads"* — because a band carrying nothing looks like a band with
      nothing in it. The pool travels on the rows instead (§8.6).

      What replaces the check: every row of the pool reads `CLAD Pool - Célula 11B/C · CLAD07` with
      the **machine name whole**, the pool dimmer and a size smaller, italic over a `FIFO` row and
      upright over a station. The first attempt at this cut the machine name off — a 24-character
      pool name filled a fixed 168 px column by itself — so the column is measured now and clamps at
      260 px. **The real plant is the case to look at**, because the test font is fixed-width and
      cannot tell whether Roboto fits inside the clamp: if the pool prefix is ellipsised on screen
      the clamp is too tight, and if the column looks wider than the chart deserves it is too loose.
- [ ] **The Queue and Share tables keep their ranking** and carry `CLAD07  CAL Pool` in the first
      column. The top row must still be the station that queued most (§8.1). **The column went from
      160 px to 210** to fit the pool, which is the change most likely to look wrong rather than be
      wrong — a long station name beside a long pool name is where it ellipsises.
- [ ] **A pre-v18 run opened from the history picker** shows its stations ungrouped and its lanes
      where they always were, rather than grouped by whatever the pools happen to be today. There are
      35 of them stored and every one is a fixture for this. **The one check whose failure would be
      silent**: a wrongly grouped old run looks exactly like a rightly grouped new one.
- [ ] **A station reachable through two pools in one run** sits ungrouped and names both. Célula 11B
      may not have one; contrive it by putting CLAD07 in a second pool and pointing a second study's
      step at it. The lowest-value check here — it is covered by a unit test and the case is rare —
      and the one most worth skipping if the rest reads clean.
- [ ] **§0's four remaining debt items**, which this round does not close and which are cheaper to
      check in the same sitting.

**DESIGN.md this round — written, 2026-08-15**, ahead of the drive rather than after it, because
§8.6 was carrying a claim about lane placement that the code had just made false and a design file
that disagrees with the tree is worse than one that is behind it. **§3.1** (a run records the pool it
dispatched through; the Gantt groups and the tables label), **§7.10** (the two new columns, why a
station can have no single pool, and why nothing is backfilled), **§8.1.1** (why the rankings do not
group), **§8.6** (rewritten — lane bands attach to the step's target and stack; how a group sorts;
the heading band), **§16.19** (schema v18).

_If the drive changes any of it, the section changes with it_ — that is the usual order restored, not
an exception to it.

---

## 6. The workspace — round six

**The UI restructure, settled in the same 2026-08-15 interview as §5** and separated from it so the
bug fix can be driven against the screens that reported it before those screens move (§5's head).
Nothing here is written.

**The scope is the project workspace.** The left rail, Projects, Resources and Settings are not in
this round.

**The complaint is that it is cluttered**, and the count of things on screen is only half of it. The
other half is that the tab strip mixes scopes: Flow Takt is scoped to the *production line* and
Workcenters to the *project*, so two of the six tabs inside a study are editing things that are not
the study's — and nothing says so.

| | |
|---|---|
| **§6.1** | One home for the run |
| **§6.2** | Five tabs |
| **§6.3** | The Schedules tab |
| **§6.4** | The Flow toolbar, and where the period lives |
| **§6.5** | The study tile's menu |
| **§6.6** | What is deliberately not touched |
| **§6.7** | Drive it |

### 6.1 One home for the run

**The run had three homes and one of them was a duplicate of another.** The project app bar carries
Simulate; the simulation workspace carries a second Run button in its filter bar; the study's
Simulation tab and the workspace both render `RunResults`, each wrapped in its own chrome. Opening
the workspace from the sidebar showed **two Simulate buttons about 200 px apart** — §12.1's *"Simulate
is in both places"*, which read as a principle on paper and as a bug on screen.

**The sidebar workspace becomes the only place a run is read.** The study's Simulation tab goes.

- **`/projects/:id/simulation?study=:studyId`.** One optional query param, so arriving from a study
  pre-selects that study's filter and the one-click path from a study to its own numbers survives.
  Linkable, per §12.1 — a filtered view is worth sending someone. Only the study goes in the
  location; the other three filters stay view state, which is a smaller change than moving a date
  range into a URL and is the one filter you navigate *from*.
- **The workspace's Run button goes. The app bar's stays.** §12.1's rule that starting a run must not
  require navigating somewhere first is the reason the button went to the app bar in the first place,
  and the app bar is the position that does not move.

**The chrome the study tab was carrying splits by role**, rather than being stacked into a filter bar
that already scrolls sideways at 1100 px:

| what it is about | where it goes |
|---|---|
| dispatch rule, readiness | a popover on the Simulate button — it already names the first blocker in its tooltip |
| which run you are reading | the run header's timestamp becomes a picker; it already states the run |
| which slice you are looking at | the workspace's filter bar, unchanged |

**The readiness panel and the tooltip stop being two statements of one thing.** §11's panel is the
list and the tooltip is the sentence; putting the list under the button that the list disables makes
the button the single answer to *why can I not press this*.

**`View results` on the run banner now navigates to a route rather than switching a tab index.** The
workspace's `_tabs.index = _simulation` has nothing to point at once the tab is gone, and
`_StudyTabs`' rule about not resetting to Flow when the reader is on Simulation goes with it.

### 6.2 Five tabs

`Flow · Study Settings · Schedules · Demand · Summary`

Seven becomes five: Simulation leaves for §6.1, and Flow Takt and Workcenters merge into
**Schedules** (§6.3).

**The strip was mixing scopes, which is more of what "cluttered" meant than the count was.** Flow
Takt reads `taktPeriodsProvider` keyed on `productionLineId` — two studies of one line share it, so
editing it inside a study changes another study's numbers. Workcenters is project-scoped data
filtered to this study's flow, and it already carries the project-wide Calendar Exceptions. Only
Flow, Demand, Summary and Study Settings are the study's own. The merge does not fix that, but §6.3
puts the two shared tables where a heading can say so.

_Rejected: one `Inputs` tab holding Demand, Takt and Workcenters._ Four tabs, and it draws the honest
line between what is typed in and what is read off — but `demand_tab.dart` is already two grids that
each want the full height, so `Inputs` would need sub-navigation, and nested tabs are their own
clutter.

_Rejected: moving Takt and Workcenters out to a project-level destination._ It fixes the scope
mixing outright, and the Workcenters view then shows all fifty of the plant's stations instead of
this study's ten — which §4.2 rejected as noise in the round that built it.

### 6.3 The Schedules tab

Three tables of very different sizes, so they are not stacked in one scroll: the big one would get a
capped height inside a page scroll, which is the shape §8.6 moved the Gantt out of.

```
┌─ Flow Takt ────────────────┐ ┌─ Calendar exceptions ──────┐
│  shared by every study on  │ │  the whole project          │
│  Line B                    │ │                             │
└────────────────────────────┘ └─────────────────────────────┘
┌─ Stations ──────────────────────────────────────────────────┐
│ Workcenter │ Start │ End │ Shifts │ Operators │ Avail │ Rew │
│ CLAD07     │ …     │     │        │           │       │     │
│ CLAD08     │ …     │     │        │           │       │     │
└─────────────────────────────────────────── takes the height ┘
```

**Takt and Exceptions share a fixed band across the top.** Both are small, both describe the line's
calendar rather than one station's, and both are the shared-scope tables §6.2 wants labelled — so
they sit together under headings that say whose they are.

**The station grid becomes one grid with Workcenter as a column.** Today `workcenters_tab.dart`
renders a `Card` per station, each with its own issues banner and its own 320 px-capped grid: célula
11B's seven stations are seven nested scroll regions. One grid is one scroll region, it compares
staffing across stations by reading down a column, and **a year of periods for the whole line pastes
out of Excel in one block** — which §12.6 says is how they actually arrive.

Costs a combined provider, since `workcenterScheduleProvider` is keyed per station, and a workcenter
picker on the blank append row that §10.1's "type into the row past the end" rule needs.

_Rejected: master/detail with a station list._ One scroll at a time and it scales to §14's forty
stations — a third level of navigation inside a tab inside a workspace.

_Rejected: cards collapsed by default._ Compact at rest, and it hides what the reader came to
compare.

### 6.4 The Flow toolbar, and where the period lives

**The period stepper is copy-pasted between two tabs.** `flow_tab.dart` and `summary_tab.dart` hold
the same four widgets over the same `viewedPeriodProvider(study.id)`. The state is shared so they
cannot disagree — but the viewed period is a property of the study workspace rather than of either
tab, and a control that moves position when the reader switches tabs is a control they have to find
twice.

**It hoists to the trailing edge of the tab strip.** One stepper, above whichever tab is open, with
the granularity dropdown folded onto the period label — a control that is permanently visible for
something set once. Where the period does not govern the tab it **greys rather than vanishing**, so
nothing jumps.

**The Flow toolbar then folds from eight controls to two.** `Data source` and `Part` are one choice
split across two dropdowns — `Part` only exists under `FlowDataSource.singlePart` — so they become
one `showing` dropdown:

```
showing ▾   Flow equivalent
            Weighted mix
            ──────────────
            ABC-1043
            ABC-1044
```

plus a PDF icon. The two text labels go with them; a dropdown reading `Weighted mix` does not need
the word `Data source` in front of it.

_Rejected: a lens popover holding period, granularity, source and part._ Two controls on the
toolbar, and it hides what the map is showing behind a click when every figure on the map depends on
it.

_Rejected: floating the lens over the canvas like the zoom cluster._ §12.2's argument for floating
zoom is that it acts on what is under it; the lens changes the numbers rather than the view.

### 6.5 The study tile's menu

**Round four left two fields with two write paths each.** §4.2 removed the `Run settings` dialog on
the principle that *"two ways to set one field is how the two come to disagree"* — and then the new
tab re-created two ways for `includeInSimulation` and for the study's name, which are still on the
sidebar tile's popup menu. They call the same repository method, so unlike the dialog they cannot
actually disagree; the rule is worth following anyway, because the next pair might not.

**The menu keeps Duplicate and Delete.** Both act on the study as an object rather than setting one
of its values, and neither belongs on a page that would disappear underneath the reader. `Include`
and `Rename` come off; Study Settings owns them. The tile's play icon stays as the read-only badge it
already is — §12.1 gave it the leading slot because the flag is the study's most consequential
property, and that argument is about showing it, not about setting it.

### 6.6 What is deliberately not touched

- **The Flow footer's six figures.** §17.2 records the field rejecting a compressed lead time *"on
  sight"*, and asking for `running = 1.4 × working` beside the working figure. The band stays exactly
  as it is, including the horizontal scroll.
- **The Summary tab's contents.** Only its period bar moves, per §6.4.
- **The process box's fields.** §2 rebuilt them a round ago and nothing has come back about them.
- **The left rail, Projects, Resources, Settings.** Out of scope by decision, not by omission.

### 6.7 Drive it

The workspace screen still has **no test coverage at all** (§3.7), and this round rebuilds it for the
second time in two rounds — so everything below is only covered by pressing it. §5's own drive is
separate and comes first; if any of it is still outstanding when this round starts, it does not get
folded in here, because a bug fix checked through a rebuilt screen cannot say which of the two moved
the figure.

- **Simulate from the app bar while on each of the five tabs**, and the banner's `View results`
  landing on the workspace with the right study filtered. This is the wiring §0 has an open item
  against and which §6.1 changes the meaning of.
- **A study's slice equals the combined view's** for that study — the check §4.6 asked for and
  which the single surface makes cheaper rather than removing the need for.
- **The Schedules grid pasted into from Excel**, across two stations in one block, and the append row
  with no workcenter chosen. Then the same paste in es and pt, since §0's date-format item is
  unresolved and this grid triples the number of places a wrong parser shows up.
- **The period stepper greyed** on Study Settings and Schedules, and live on Flow, Demand and
  Summary — and the same period surviving a tab switch, which is what the shared provider already
  guaranteed and what the move must not break.
- **The readiness popover against a real gap.** §0 has never seen the panel anything but clean;
  §6.1 moves it under the button, so the check moves with it. Unbind a step and confirm the button's
  popover names the study.
- **Both themes, and both narrow and wide.** §6.4 cuts eight controls to two on the strength of a
  1100 px window; §6.3's combined grid is the widest table in the app after the plan.

**DESIGN.md this round:** **§12.1** (rewritten again — five tabs, one home for the run, the chrome
split by role, the period on the strip), **§12.6** (one grid for every station's schedule),
**§10.1**, **§17.5**.

---

## 7. The queue, the filter and the balance — round seven

**From driving `0.1.0-2026-08-15g`**, the first build of §5 and §6 anyone has actually used. Four
things came back. One is a plain bug, one is a revert, one says the flow model is wrong, and one is a
feature the app has never had.

**§7.3 supersedes work committed in §5.2.** That round made two lanes over one station both draw,
having found one silently overwriting the other. The overwrite was real; the fix was aimed at the
wrong model. There is only ever one queue in front of a station, so the doubling disappears by
construction here and `GanttPoolGroup`'s list-of-bands becomes machinery with nothing to hold. It is
recorded rather than quietly undone, because the *reason* that fix looked right is the reason to
distrust the next one that does.

| | | |
|---|---|---|
| **§7.1** | The filter filters | small, and it makes every later drive trustworthy |
| **§7.2** | Capacity, not Schedules | rename, cards back, exceptions leave the study |
| **§7.3** | A queue belongs to a station | the deep one — schema, engine, symbols |
| **§7.4** | Takt rebalances a group | derived process times — **written, not driven** |
| **§7.5** | Following one order | three filters, a followed order — **written, not driven** |
| **§7.6** | The standard, the ratio, the warm-up | an inverted metric and what it reached — **written, not driven** |
| **§7.7** | The takt a run ran at, and pinning a station | defect fixed, **v20 landed and met the real database**, the pin is built — **§7.7.2/§7.7.3 code-complete 2026-08-18, undriven** |
| **§7.8** | Reading a rebalance off a run | a stale input, and **schema v21** — **code-complete, v21 has met the real database, undriven** |
| **§7.9** | The takt belongs to the order | the takt had never reached a run — **code-complete, v22 live, engine driven 2026-08-29 and confirmed against the database** |

**Driven between each**, and §7.1 first on purpose: a filter that does not filter makes every other
observation suspect, and there are two undriven rounds stacked behind it already.

### 7.1 The filter filters — **done, and driven**

**Confirmed working on `0.1.0-2026-08-15j`**, session 07:09 on 2026-08-16. It took three defects
rather than one, and the first two fixes each shipped believing they were the whole thing:

1. **The plan and the parts table read the whole run.** `FilteredRun.plan` had been computed
   correctly and never read.
2. **The picker never wrote to the filter at all.** Each checkbox was wrapped in a `StatefulBuilder`;
   `CheckboxMenuButton` closes the menu when activated, disposing it, and `State.setState` asserts it
   is mounted *before* running the callback — so the line adding the study to the set never ran, and
   the `onChanged()` after it never ran either. The filter had never fired in any build.
3. **The Queue table was spliced back from the unfiltered run**, on an argument true of utilisation
   and applied to five other columns.

_The lesson, and it is about testing rather than about filters:_ the test written for (1) set the
filter from the route and passed while the app stayed broken, because the route is not the control
the user touches. A test that reaches the state a different way from the user is not a test of what
the user does.

### 7.1 The filter filters — as designed

*Field: "The simulation results filter does not filter anything. It should filter the results and
Gantt graphs."*

**`FilteredRun` already computes the right answer and the view throws it away.** `filterRun` has its
own tests and is correct; `FilteredRun.plan` is the filtered plan and **nothing reads it**.
`_ProductionPlan(run: run)` reads `run.plan` and `_PartsTable(run: run)` reads `run.metrics` — both
the whole run — while the headline, the metrics card and the Queue and Share tables read
`slice.metrics`, and the Gantt reads `slice.result`. So the two largest tables on the page ignored
the filter and the rest did not, which is worse than either: the page disagreed with itself.

- Every table reads the slice. `_ResultTables` stops reaching through `slice.run` for anything except
  what genuinely describes the run — the header, the abort banner, the horizon warning.
- **The Excel export takes the slice too.** The button sits under the filtered plan, and handing back
  a different table from the one above it is how a planner sends the wrong list.
- **Station utilisation stays whole and stays labelled.** Its denominator is `openSeconds`, a stored
  run total, and rebuilding it for a window needs each station's calendar — which §7.10 deliberately
  does not store, and which is the cost that got §3.5 dropped. Unchanged, label included.

_Left open, and the day it is wanted is the day §3.5 comes back:_ snapshotting each station's shift
pattern into the run would let utilisation follow the filter honestly.

**This is also the first thing the workspace has ever been tested for** (§3.7). The test written
while diagnosing it mounts `SimulationWorkspace` with a two-study run and a study filter — the first
end-to-end coverage that screen has had.

### 7.2 Capacity, not Schedules

*Field: "Hated the Schedules section. First let's call it Capacity, then the workcenter input looks
horrible, preferred the previous one. And the exceptions are for the whole project or the study. If
they are for the project, why do we call it inside a study."*

**`Schedules` becomes `Capacity`**, which is what the tab is for and what §8.3's glossary already
calls the thing.

**The combined station grid reverts to one card per workcenter.** §6.3 replaced seven cards with one
grid to end seven nested scroll regions and to let a year of periods paste in one block. Both
arguments still stand and both lost: the build was driven, the cards read better, and §2.0's rule is
that driving beats reasoning. Cross-station paste goes with the grid — **nobody asked for it**; it
was inferred from the shape of the change rather than from anything the field said.

`station_grid.dart` and its tests are **deleted with the grid** rather than left as
built-but-unreachable. §17.5 is long enough, and a row model for a grid that no longer exists is not
something a later round would find and use.

**Calendar exceptions leave the study.** They are stored per project and applied to a plant, line or
workcenter scope; nothing about one is the study's, which is exactly what the field asked. They
become **a project-level destination in the studies sidebar**, beside Simulation — the place §12.1
already established for what spans studies.

§4.3's argument for putting exceptions beside the schedules they override is answered rather than
overruled: the two do answer one question, and the answer is a *station's* open time, which is read
on Capacity and set in two places that are each honestly scoped.

### 7.3 A queue belongs to a station, not to a flow

*Field: "The Gantt is doubling the inventories. The inventories of a workcenter used in multiple
flows must be the same, they are not. And I'm afraid the flow logic is incorrect. We need to re-think
the architecture of inventories, because a node will always have some type of inventory. What changes
is the queue logic of it."*

**The model was wrong, not the drawing.** §5.5 makes an inventory a node on one study's spine, with
its own name, discipline and capacity. Two studies through CLAD07 therefore have two floor spaces in
front of one machine — and the engine simulated them as two, so the numbers were wrong in the same
way the picture was.

**A queue belongs to what a step targets** — a workcenter, or a pool as a whole. The pool, because
§3.1 dispatches to whichever member frees first, and that only means anything if the orders wait in
one line. So `CAL Pool` has one queue and its three machines pull from it, which is the shape the
Gantt heading already draws.

**The inventory node kind goes away.** Every step has a queue in front of it; what differs is the
rule. The **connector carries the queue type and the symbol follows from it**:

| type | symbol |
|---|---|
| push | striped arrow with the inventory triangle beneath |
| FIFO | the FIFO channel |
| LIFO | the LIFO channel |
| SPT | the SPT channel |
| EDD | the EDD channel |

**Supermarket is named and not selectable.** It is the type the field asked for and the one the
engine cannot honour: it decouples — downstream withdraws from stock rather than waiting for a
specific order — and it needs stock levels, a replenishment trigger and stockout metrics (§9). A
supermarket symbol over FIFO behaviour would be a map that lies about the plant, which is precisely
the correction §5.5 already made once when fixed-wait buffers reported a delay the run never charged.
It stays parked until its mechanism exists.

**LIFO is new.** `DispatchRule` has `fifo`, `earliestDueDate` and `shortestProcessing`; LIFO is a
fourth and is cheap.

**The queue type replaces the run's dispatch rule outright.** One place a dispatch decision is made,
and the map shows every one of them — which is what a value stream map is for. What it retires:
`SimulationRuns.dispatch`, the dispatch dropdown §6.1 moved into the Simulate popover, §7.4's
per-lane overrides, and the `dispatchOverrides` line on the run header.

_The costs, and they are real._ §0's confounder run compared a whole plant under one rule against
another; that becomes an edit per station. And §10's run comparison loses "the dispatch is what
differed" as a one-line explanation — it gains "which queues differed", which says more and takes
more saying.

**Where the numbers live: one row per `{projectId, targetId}`** — the seam the workcenter schedule
already uses. Discipline, capacity in orders, and the observed stock (§5.5's quantity or duration)
sit together, project-scoped, so capping a lane stays the per-project experiment §0 actually ran on
`FIFO CEU27`.

**The run records each station's queue type and capacity**, on
`simulation_run_workcenters` beside §5.1's pool columns. §7.10's rule: a run joins to nothing, so a
run opened next month still says what each station dispatched by after the queues have been retuned
— and it is what lets §10's comparison say *which* queues differed rather than only that something
did. `SimulationRuns.dispatch` stays for pre-v19 runs and stops being written.

_Rejected: reading the queues back from the project._ No duplication and no migration — and retuning
a queue would silently rewrite what every past run claims to have done, which is the drift §7.10
exists to prevent and which §5.1 has just added two columns to avoid.

**The flow's two ends carry stock, and it is not a queue.** A study gains an inbound and an outbound
figure, drawn as triangles against the supplier and customer endpoints (§5.3). They feed the
lead-time ladder and the days-of-stock a current-state VSM exists to state — and nothing dispatches
out of them, because §7.2 releases on a takt rather than pulling from a rack.

_Left open, and it is a real mechanism when it is wanted:_ making the inbound stock gate releases, so
a run can report starvation from supply. §8.5 already carries a material date per order, so the input
exists; what does not exist is the engine behaviour, and it is not being invented inside a re-model.

**One channel shape, labelled with the rule.** The FIFO symbol already *is* a channel with `FIFO`
written in it, so `LIFO`, `SPT` and `EDD` in the same channel extend the convention rather than
inventing three glyphs — and nothing can be misread as a standard symbol meaning something else. Push
keeps its striped arrow and triangle.

_Rejected: colour per rule._ Cheap and legible on screen, and §13's PDF on a shop-floor wall is often
greyscale, where colour carrying meaning alone does not survive.

**The runs-history label** becomes the date plus the queue type when every station shares one, and
`mixed` otherwise. It reads `2026-08-15 · FIFO` today and keeps doing so on a uniform plant; a full
breakdown does not fit a menu row, and the per-station record is what a comparison reads anyway.

#### The migration, and what it costs

**The fold is the first migration in this repo that moves data between concepts** rather than adding
nullable columns. Every inventory node becomes part of a queue row keyed `{projectId, targetId}` —
and the real database shows why that is not a rename: **15 inventory nodes fold onto 10 targets**,
because the two studies share five stations and their nodes disagree about them.

| target | Célula 11B | the other study |
|---|---|---|
| CLAD Pool | `FIFO CLAD`, fifo | `FIFO CLAD`, fifo |
| `0a602188` | `FIFO TTAT`, rule unset | `FIFO TTAT`, fifo |
| `12f4b95c` | `FIFO BAN` | **`FIFO BAN11`** |
| `41a557b2` | `FIFO END` | `FIFO END` |
| `8983ca52` | `FIFO COATING` | **`FIFO Coating`** |

That table *is* the bug the field reported, seen as data: there is one floor space in front of BAN11
and the map has been carrying two names for it.

**First study wins, by study then position.** The first node to reach a target sets its name; a
non-null rule or capacity from a later node fills a blank rather than being lost, so nothing that was
actually configured is dropped in favour of an unset field. Deterministic, and it never silently
prefers one name without a record.

**Every discarded value goes to the diagnostics log**, named against its target, so `FIFO BAN11` is
recoverable by reading it.

**And the `inventory` rows stay.** They are not deleted and not read — the same call §16.18 made for
`changeover_seconds`, and stronger here: the rows themselves are the recovery path for a name the
fold discarded, which beats a log line. `FlowNodeKind.inventory` therefore stays in the enum, because
a stored value has to remain parseable; nothing constructs one.

_Rejected: deleting them._ It makes the upgrade irreversible against a v18 backup for no gain but
tidiness, and §17.5 already tracks what is built and unreachable.

_Rejected: leaving conflicts unset and making the user resolve them._ Nothing guessed — and §11 would
block runs on a plant that ran perfectly well the day before, on five targets at once.

#### Where a queue is edited

**On the map, from the connector.** Click the channel between two boxes and set its type, its capacity
in orders and the stock standing there. It is where the queue is drawn and where it is read, and a
planner setting a FIFO capacity is looking at the map when they think of it.

**The editor names the target and says the queue is shared** by every step that feeds it — the same
sentence §7.2's Capacity tab now carries for the takt, and the answer to the complaint that started
this round.

_Rejected: editing it on Capacity beside the station schedules._ Same key, same scope, same tab, and
it would put everything about a station in one place — but reading a rule on one surface and setting
it on another is the split §6.4 has just finished undoing on the Flow toolbar.

_Rejected: both, with a bulk table on Capacity._ Better for retuning ten lanes at once, and two write
paths into one row is how the two come to disagree (§12.6).

#### What §7.3 still owes

**All four items landed on 2026-08-16, and none of it has been driven.** The run-level dispatch rule
is out of the UI — the popover's dropdown, the run header, the runs-history label and the Excel stamp
all read the per-station queue type and say `mixed` where the stations differ. The map draws the
queue on the connector, one channel shape per rule, and sets it from there.

~~What is left of §7.3 is one thing it settled and nothing has built:~~ **§7.3 is code-complete as of
2026-08-17.**

- [x] ~~**The flow's two ends carry stock.**~~ **Built 2026-08-17, and it needed no migration.**
      `studies.inbound_stock` and `outbound_stock` were added by the v19 migration ahead of the
      surface that would fill them, so this was a surface, a ladder and a PDF. This entry said "a
      schema step (v20)" and was wrong about the only part of it that would have set the sequence.

      A study's two ends draw as triangles under the supplier and customer symbols, convert to days
      as a quantity queue does, and feed the lead-time ladder and the footer's lead time. Both are
      set from the endpoint's own dialog, beside the name of that end. **Nothing dispatches out of
      them**, which is §7.2's release rule left alone rather than a limitation — see §5.5.1.

      _Worth knowing, and it is the one thing to check on screen:_ **the map's lead time now exceeds
      the plan's `Theoretical LT` by whatever is standing at the two ends.** That is a sixth
      difference between the two figures and it is deliberate — §7.9 lists the five that were closed
      and the one accepted, and §5.5.1 argues this one. It is also exactly the shape of drift §7.6
      was written to stop, so it is written down in both places rather than left to be rediscovered
      as a defect.

      _Also settled while building it:_ `updateStudy` writes every field it is given
      unconditionally, so its six callers each read the whole study back and pass it through — and
      `flow_tab.dart` carried a comment about the bug that caused when an endpoint rename nulled the
      opposite endpoint. The end stock got its own `setFlowEnd` instead of a seventh argument, and
      the endpoint writer no longer passes anything through. **The six other callers are still in
      that shape** and are worth the same treatment the day one of them is touched.

      **Drive it** — nothing in the suite renders a pixel, and this puts two new symbols on the map:

      - [ ] **The triangles sit under their factories and clear of the names**, at both ends, on a
            real flow. The geometry is asserted against `endpointLabelHeight`, which the canvas and
            the layout now share — but only a screen can say whether a long supplier name and a
            triangle under it read as one thing or as a collision.
      - [ ] **A counted zero looks like a finding, not like a bug.** It draws a triangle with `0` in
            it where an uncounted end draws nothing at all, and that distinction is the whole design.
            If a zero reads as an error on screen, the rule is right and the drawing is wrong.
      - [ ] **The footer still equals the rungs**, with both ends counted. Asserted in a test, and
            §17.4 is the invariant most worth seeing hold with two more rungs in the comb.
      - [ ] **The printed map**, where the ends are a `▽` and a figure rather than a drawn triangle,
            and where the comb is bracketed by two more rungs than it used to be.
      - [ ] **es and pt**, on the endpoint dialog — `flowEndStockHelp` is the longest string added
            this round and it sits in a dialog that was one field wide until now.

**Two field findings from `0.1.0-2026-08-16`'s map landed on 2026-08-16**: the lead-time ladder's
rungs overlapped and are now one equal, aligned slot each, which widened every link that carries a
queue to a process box's width; and the queue type moved out of the connector into the process step
dialog, where the workcenter is chosen. The connector still opens it.

**Drive the map before anything else in §7.** Nothing in the suite renders a pixel and this round
replaced the whole inventory surface: the triangle moved off the spine and under the link, the
lead-time ladder grew a rung per queue instead of per buffer node, the insert menu lost a choice, and
the inventory dialog became a queue dialog. The one defect found while writing it was a mount-time
crash — two dropdown entries sharing `null` — which is exactly the class §16.4 and the node-editor
tests exist for, and it was found by a test that opened the dialog rather than by reasoning.

_Two things to look at first, because they are where a stored v19 database will disagree with a fresh
one:_ every project whose queues came out of the fold now draws its old inventory names on the
connectors, and any flow whose buffers were **not** in front of a step — a trailing buffer, two in a
row — has silently lost that figure, because a queue belongs to a target and those had none.

~~_Swept for others on 2026-08-16 and found none:_ `lane.studyId` is no longer read anywhere for
behaviour. **But it is still written and never read**, along with `SimLane.position`.~~ **Settled
2026-08-17: documented as recovery-only**, which is the call §16.18 made for `changeover_seconds`,
rather than deleted — both are `NOT NULL` columns on a stored table and dropping one rebuilds it
(§16.11), and they are the only way back to what a pre-v19 run's flow looked like. `SimLane`'s doc
comment now says *do not read this for behaviour* against each, with the reason; the class comment's
claim that `position` *"is what makes a lane placeable"* is deleted, since §8.6 has placed lanes by
the steps that name them since v19 and that sentence is the trap itself — a field that looks
authoritative and answers a question nobody should be asking it.

~~_Owed, and not code:_ `project_tables.dart` points at **§16.20** for what the v19 fold discarded, and
`DESIGN.md` stops at §16.19. The schema note for v19 was never written.~~ **Written 2026-08-17.**
§16.20 covers the new table and its key, the four columns, the fold and its 15-onto-10, first-study-
wins and the `v19.discarded` log, the orphan case, why the fold is guarded on emptiness rather than
on `from`, and what is kept rather than cleaned up. Two things it records that were not written down
anywhere before: **`studies.inbound_stock` and `outbound_stock` landed in v19 and nothing fills
them**, and **stored runs are invalidated only where two studies shared a target or a lane carried a
capacity** — a single-study flow with uncapped queues is comparable across v19, which the blanket
claim elsewhere would have had a reader assume otherwise.

### 7.4 Takt rebalances a group of like machines

*Field: "If I change the takt time I need to rebalance the operations of the workcenters, otherwise
it will be unbalanced. The app should identify workcenters of the same type, then rebalance the
process time according to the takt time, topping the first workcenter at the takt time and leaving
the rest, under or over, to the last workcenter of the same type in the sequence."*

**Consecutive steps sharing a workcenter type are one balance group.** A run of adjacent cladding
operations shares the work; cladding again after heat treat is a different operation and a new group.
Adjacency is what makes it physical — work cannot move across an intervening furnace.

**The type is the identity.** Types are user-defined and free to create, so a plant needing model
precision makes `CNC Lathe — Mazak` and `CNC Lathe — Haas` two types, rather than the schema gaining
a second identity axis whose blank default would balance everything together.

**The split is derived, never written.** What is stored is the group's **measured total work content
per part**; the split is computed against the takt in force — the viewed period's on the map, the
run's in the engine — filling each station to takt and leaving the remainder on the last. Change the
takt and the balance follows with no action, which is the whole ask.

**And it never overwrites an observation with a rule**, which is §5.5's correction applied a third
time. A written split would be stale the moment takt moved, and a later takt change would leave the
old one in place silently — the unbalanced line this exists to prevent.

_The cost, stated plainly:_ a station's process time inside a group stops being hand-editable. The
formula owns it, and a planner who wants CLAD07 at forty minutes because that is what fits has
nowhere to say so. The day that is wanted is the day a per-station override arrives, and it will need
the "measured beside chosen" pair this section rejected.

~~_Left open:_ what the process-time grid shows for a station in a group — the derived figure, the
measured total, or both.~~ **Settled when it was built: the grid shows the measurement.** It is where
the number is typed, and a cell that shows a figure other than the one entered into it argues with
its user. The map shows the derived split and marks the box so a reader knows the two answer
different questions.

#### Built 2026-08-17 — **written, not driven**

**And it needed no schema step, which this section assumed it would.** The per-station cells the
demand table already holds *are* the measurement, and their sum *is* the group's work content — so
"what is stored is the group's measured total" was already true and nothing new is stored. That is
the second entry in §7 to have over-specified its own cost; §7.3's flow-ends stock was the first.

- `takt_balance.dart` is the rule, **pure and shared by the map and the engine**. They balance
  against different takts — the viewed period's and the run's (§18.3) — so they can differ by their
  takt and never by their arithmetic. The file exists because §7.6 is the record of what two copies
  of one rule cost.
- `FlowStepView.processTime` is the derived share and `measuredProcessTime` the observation. The
  derived figure went into the field every consumer already reads — box, ladder, footer, PCE, printed
  map — because a rule that put it anywhere else needs each of those to remember to ask.
- In the engine the share rides on `SimStep.balancedProcessTimes`, keyed by **part**. Two parts of
  one flow legitimately balance differently, and keying by target would collide on a flow that visits
  one machine twice in a row. `SimStep.processTimeFor` is the single place the choice between the two
  figures is made, so the engine and the theoretical walk cannot disagree about what a step is worth.
- **A rebalanced box is marked**, on screen with a tooltip naming the type and stating what was
  measured there, on paper with the mark alone — a map on a wall cannot be hovered.
- Readiness generalises from the step to the group: what blocks is a group holding nothing, not a
  member holding nothing.

29 tests. `flutter analyze` clean, **858 tests passing**.

#### Drive it

- [ ] **A real célula 11B flow with two adjacent stations of one type.** The plant may not have one
      — if it does not, contrive it by giving two consecutive workcenters the same type, because the
      whole rule is invisible until a group exists.
- [ ] **Change the takt and watch the split move with no other edit.** That is the ask, and it is the
      one check that cannot pass by accident.
- [ ] **The mark and its tooltip**, in all three languages. `stepBalancedHelp` is the longest string
      on the canvas and it sits in a `Tooltip` on a box that is 168 px wide.
- [ ] **The demand grid still shows what was typed** while the box beside it shows something else.
      This is the pair most likely to be read as a bug, and the mark is the only thing that explains
      it.
- [ ] **A run against a balanced flow**, checked against the map: both should place the same work on
      the same stations when the run's takt and the viewed period's takt agree. If they disagree,
      that is the takt differing and not the rule — worth confirming rather than assuming.
- [ ] **The printed map**, where the mark is all there is.

### 7.5 Following one order through the plant

**From a later drive than the rest of §7** — `0.1.0-2026-08-16c`, the build that put the pool on the
rows — so it is filed here rather than opened as a round of its own, and its provenance is stated
because §0's whole lesson is that a check is only as good as the build it can cite.

*Field: three more filters — Project, Part Number and Order Number — and "when the user selects a bar
in the graph, it highlights the other bars of that order", and the bar tooltip should carry the
project and the part description.*

**Nothing here needs a schema change**, which is the first thing that was checked and the reason this
is smaller than it sounds. `simulation_run_orders` has carried `customer_project` since **v12** and
`part_description` since **v13**, copied in rather than joined for §7.10's reason. Against the live
database: 5330 order rows, 18 distinct customer projects, 22 part numbers, descriptions on 97 % of
orders. What is missing is not the data but a path from it to the chart.

**"Project" is the customer project on the order, not the app's `Projects` row.** A run belongs to
exactly one of the latter, so filtering a run by it is either everything or nothing. The former is
§16.15's own distinction, arrived at from the field the first time: *a part is a part, and the
project is what a given batch of it is for* — which is why it moved off `demand_parts` and onto
`DemandOrders.customerProject`. 11 % of orders have none, and null is a value the filter has to be
able to name rather than a row it may quietly drop.

**The three filters go on `RunFilter`, beside `studyIds`, `cellIds` and `lineIds`** — so they narrow
the whole slice and every table, metric and plan row moves together. §12.1's rule is that one
`StoredRun` is read through one filter and no two surfaces may disagree about a number, and a chart
filtered to a part beside a Queue table that is not would be exactly that disagreement. Station-level
figures keep describing the whole run, which `stationsAreWholeRun` already says and already explains.

_Rejected: a view control on the Gantt, like the lane toggle._ Cheaper and isolated, and it would put
the chart and the tables beside it on two different sets of orders.

**An order number matches in every study, and the filter says so.** `orderNumber` is `sequence + 1`
and the sequence is dense *per study*, so on a two-study run "Order 5" is two different orders —
confirmed against the database, where every 190-order run has each sequence twice. Combining with the
study filter is what narrows it to one, and the chip has to read `Order 5 (2 studies)` rather than
implying it found one thing.

_Rejected: disabling the field until one study is selected._ It can never be ambiguous, and it leaves
a dead control whose deadness is explained by the state of a different control.

**The hover card already handles this, and the claim above that it does not was wrong.** It was
written up here as a defect — *"it reads `Order 1 · PN1` for two different orders on every
multi-study run stored"* — and then the code was read: `_HoverCard` resolves
`studies.length > 1 ? studies[studyId] : null` and puts it on the station line, so the card's second
line is `CEU27 · Célula 11B` on exactly the runs in question. The rule §8.1.2 applies to the Parts
table and the legend is already applied here too.

_What is actually left is a presentation nit, and it is worth doing while the card is open:_ the
**title** line is the ambiguous one. It reads `Order 1 · PN1`, and a reader taking the card's
headline at face value on a two-study run is reading something that names two orders — the answer is
one line below. Moving the study into the title, or dropping it there, is a judgement about the
card's shape rather than a correctness fix, and it does not sequence anything.

_Recorded rather than quietly amended_, because the mistake is instructive: the defect was asserted
from the schema — order numbers collide across studies, therefore the card must be ambiguous — and
the card had solved it. §0's rule about citing a build is the same rule one level down. **A claim
about what the app shows is worth what the reading of the code behind it is worth.**

**Selecting a bar dims every bar that is not that order's, and outlines the ones that are.** Keyed on
`orderId` rather than on the order number, which is what makes it correct on the runs the paragraph
above is about. The painter already picks a colour per bar and already outlines the hovered one, so
this is an alpha decision inside a loop that exists — no new geometry, and the visible-range culling
is untouched.

_Rejected: outlining without dimming._ On a 231-step run an outline is findable; §14's target is 2000
orders, and there an outline is a needle. _Rejected: a thread joining the bars in time order._ It
draws the path most literally and it is the only one of the three that needs new geometry in
`gantt_layout.dart`, routing around bands and surviving four orders of magnitude of zoom. The day the
dimmed version is not enough is the day to price it.

~~_Left open:_ what clears a selection.~~ **Settled when it was built:** tapping the order again and
tapping no bar both clear it, a zoom or a lane toggle keeps it because the order is still there, and
a different run clears it because it may not be. **`Esc` was not done** — it needs the chart to hold
focus, and taking focus for a chart that is one pane of a tabbed page risks a keystroke going
somewhere the reader did not aim it. Worth adding the day the chart has a reason to be focused
anyway.

#### What it costs, and the one thing that is not free

**The filter bar's new controls cannot be built from the project.** `_FilterBar` takes a `Project`
and derives its studies, cells and lines from the plant structure — but customer project, part number
and order number are values *inside the stored run*, so the bar needs the run as a second input and
the three controls have nothing to offer until a run exists. That is the only structural change in
the round; everything else is a field on a class that already exists.

_And it is the right dependency rather than an awkward one:_ offering a part number the run never
made would be a filter that returns nothing and looks broken, which is the same argument §7.10 makes
for a run joining to nothing.

**Three commits, in this order**, because each is separately drivable:

1. ~~**The project and the description reach the Gantt**~~, on the bar's hover card. **Done** — the
   only one of the three a reader can check without a filter or a click, which is why it was first;
   not, as this list said, because it closes a defect. There is no defect; see above.
2. ~~**Select a bar, follow the order.**~~ **Done.**
3. ~~**The three filters**~~, which is the one that touches `RunFilter`, `filterRun`, `signature`, the
   filter bar and three `.arb` files. **Done.**

**None of the three has been driven.** All are asserted by tests that never paint a pixel (§2.7), so
what is untested is every visual question they raise, and they go in the same sitting as the label
column's clamp:

- [ ] **Whether the dimmed plant is still readable** behind the followed order, at 0.16 for a bar and
      0.08 for a stay. Too low and the context the selection exists to give is gone; too high and the
      followed order does not stand out. Look at the 231-step run, where the bars are dense.
- [ ] **Whether the card is too tall** now that it can carry a description and a project — it grew by
      two lines and `_cardHeight` went 132 → 168.
- [ ] **Whether the filter bar still fits.** It has seven controls now and scrolls horizontally; the
      widget tests had to start calling `ensureVisible` to reach the later ones, which is the test
      suite noticing a thing a reader will notice too. If the bar needs to wrap or the pickers need
      to be narrower, this is where it shows.
- [ ] **The order field against the real 190-order run**, which is the only place the ambiguity is
      real: order 1 exists in both studies, so typing `1` must light two rows and say why.

**Driven on 2026-08-16 under `0.1.0-2026-08-16d`, and it found two defects** — the value of driving
it, stated plainly, since both were invisible to a suite of 765 tests:

- [x] ~~**Filtering dropped the reader back onto the tables.**~~ *"When I'm in the gantt view and
      filter something it goes back to the results."* `RunResults` was keyed on the slice signature,
      so every filter change rebuilt it from scratch and took the view choice with it. Fixed by
      removing the key — the zoom it existed to reset is reset by `GanttView` itself.
- [x] ~~**Filtering by study took most of the queues away.**~~ *"When filtering one study, I can't
      see the CLAD pool queue."* Not the pool's problem and not the Gantt's: v19 made a queue belong
      to a target and `filterRun` was still keeping lanes by `lane.studyId`, which is now whichever
      study was written last. **On the newest stored run, eight of ten lanes carry one study's id and
      two carry the other's**, so either study lost most of its bands. Lanes are kept by the steps
      that name them now.

      _And a third, found while fixing it and never reported:_ a stay took its study from the lane,
      so a shared queue labelled every order the other line put in it with the wrong study on the
      hover card.

      **The lesson for the list above:** all three are §7.3's re-model reaching a surface nobody
      re-read when it landed. The queue stopped being a study's in v19 and two places went on asking
      it which study it belonged to. Worth a sweep for others.

### 7.6 The standard, the ratio and the warm-up — **written, not driven**

**From reading §7.5's own lesson back.** The sweep it asked for found a metric that had been upside
down since it was built, and pulling on it reached the theoretical walk, the cold start and the flow
footer. `flutter analyze` clean, **815 tests passing**, no schema change and no migration — every
figure here moves because the arithmetic was wrong, not because the model changed.

**Nothing here has been seen.** Nothing in the suite renders a pixel (§2.7), and this round changes
what four numbers on two screens *mean*.

**Why it is one round and not four commits of unrelated tidying:** every item below is the same
mistake. §7.9's theoretical lead time was described as a **floor** under what a run observes, and
three sections of `DESIGN.md` said so in agreement with each other and in disagreement with the code.
Once it is a floor, an efficiency above 1.0 is impossible, so a ratio reading 0.73 looks like the
formula and not like the premise — and everything downstream is built to keep a claim that was never
true.

- **Theoretical LT is a standard, not a floor.** It is what an order takes flowing through the plant
  as it stands: the work, the stock really standing in front of each machine, and a full cold
  changeover at every step. A run charges **neither** the stock (§5.5) nor the full changeover
  (§7.6's repeat discount), so **an actual lead time shorter than the theoretical one is a normal
  result**. Célula 11B's 35.1 theoretical against 25.8 actual, written up in three places as proof of
  a defect, reads **137 %** the right way round — that cell beat a standard which charged it for a
  queue it did not have to stand in.
- **Lead Time Efficiency was inverted.** The code computed `actual ÷ theoretical` and rendered
  `0.73×`, so a flow running *well* displayed a *low* number, with no unit on screen to give it away.
  It is `theoretical ÷ actual` now and shown as a percentage, which is the direction the field states
  it in and the direction a reader can check without a tooltip.
- **The two halves of the ratio came from different populations.** Actual was averaged over the
  delivered orders and theoretical over the walkable ones, so an order that delivered but could not
  be walked — a step bound to a workcenter since removed — landed in one average and not the other.
  Only orders carrying both count toward either now.
- **The headline excludes the warm-up.** The plant starts empty, so the head of the sequence meets a
  flow nothing has queued in yet and scores far above 100 %. Left in, the headline moves with how
  many orders are in the run — a ten-order run is mostly warm-up — which is exactly what a headline
  metric must not do. Warm-up is every order released before **its own study's** first delivery, and
  a run that never fills its pipeline reports a dash rather than a number computed over warm-up
  alone. The per-order column carries every row, so the ramp is visible rather than averaged away.
- **The cold start was one per run and should be one per study.** The per-study figure was computed
  correctly and discarded a line later by a `min()` across the studies. The damage was not cosmetic:
  a study released three months early delivers three months early, so its float reads as slack that
  does not exist — and its orders occupy **shared stations** for three months they would never have
  been there, which is contention a multi-study run reported and could not happen. Measuring real
  contention is the whole purpose of §7.7.
- **The two walks charged stock at opposite ends of the flow.** Forward, stock is charged at the
  first step in flow order to reach a target; `coldStartDate` walks backwards and was charging it at
  the first step it *met*, which is the last in flow order. Stock is spent on the wall clock and work
  on the calendar, so moving a two-day jump from the front of a flow to the back changes which
  weekends the work after it crosses: for `A → B → A`, 5 Jun → 10 Jun forwards against 10 Jun → 4 Jun
  backwards. **The invariant now under test: walking forward from `coldStartDate(need)` lands exactly
  on `need`.** It is the only thing that would have caught this, and it is worth more than the fix.
- **`_walkCalendar` is deleted, and the second time it took the footer is why.** §17.5 listed it as
  built-but-unreachable and kept; it then got wired into the footer's `Lead time` slot, where an
  elapsed calendar span sat under a label reading **working days** beside a `running days` holding
  `working × 1.4` — the two the wrong way round and near enough in value to be hard to catch. The
  footer is the sum of the rungs again (§17.4), in working days, so the ×1.4 and PCE's denominator
  are both back on screen and both checkable.
- **The production plan gains an `Efficiency` column**, fourteen now. It is where §8.7's warm-up is
  made visible instead of hidden.

**DESIGN.md this round — written:** **§7.9** (rewritten — a standard rather than a floor, stock
charged at the same step in both directions, the map and the plan answering different questions),
**§7.9.1** (kept as history, with what is no longer true stated first), **§7.8** (one cold start per
study), **§8** and **§8.1.1** (the ratio's direction), **§8.5.1** (the column, and why Theoretical LT
legitimately varies row to row), **§8.7** (new — the formula, the same-population rule, the warm-up
and what it under-corrects), **§5.5**, **§12.6** and **§13.1** (thirteen columns became fourteen),
**§17.2** (`_walkCalendar` deleted and why).

#### Drive it

The whole round is numbers on screens, and every one of them is asserted by a test that paints
nothing. **Do this against a fresh run** — every stored run predates it.

- [ ] **The efficiency reads the right way round and carries a unit.** A well-running cell should
      show **above 100 %**. If it still reads `0.73×` anywhere, a surface was missed rather than the
      formula being wrong.
- [ ] **The headline against the plan's column.** The card excludes the warm-up and the column does
      not, so the column's first rows should be visibly higher and should settle. If they do not
      settle, the heuristic is under-correcting more than §8.7 admits and that is worth knowing.
- [ ] **A short run reports a dash rather than a number.** Cut the demand to a handful of orders so
      nothing delivers before the last release. That is the rule working; it will look like a bug.
- [ ] **Row 1 of the plan reconciles.** `Order Start + Theoretical LT = Need Date` on the first row
      of each study — the invariant the backward walk was breaking, seen where a planner would see
      it.
- [ ] **A two-study run where the studies start months apart.** Each releases at its own cold start,
      not both at the earlier one; the later study's float stops reading as slack it does not have.
      This is the item most worth contriving, because it is the one whose failure flatters the
      numbers rather than breaking them.
- [ ] **The flow footer's three figures.** `Running days` = 1.4 × `Lead time (working days)` on a
      five-day plant, PCE divides the working figure that is on screen beside it, and neither is an
      elapsed span. Both themes.
- [ ] **The plan at fourteen columns**, on screen and in Excel — `Efficiency` is the column most
      likely to have pushed Float off the right edge (§12.6).

### 7.7 The takt a run ran at, and pinning a station — settled by interview 2026-08-17

**From driving §7.4 against célula 11D**, which has a takt change on **1 April 2026** — 4 days before,
5 after. The rebalance could not be found on screen, and finding out why turned up one live defect,
two invisible captions and a feature the app has never had. Settled question by question; every
answer below is the field's, not a default.

**§18.3 is closed by decision, not deferred again.** *"Changing a takt mid-run is impractical in
reality"* — a line does not re-cadence halfway through a batch of work. So **a run is a single-takt
experiment**, and the way to see what a takt change costs is to run it twice and read the Gantt, the
occupation and the queue indicators against each other. That is a stronger position than "not settled
yet" and it should replace §18.3's entry in §8 rather than sit beside it.

| | |
|---|---|
| **§7.7.1** | The zero-time defect — **live in `aa3e87e`, fix first** |
| **§7.7.2** | A run records the takt it ran at |
| **§7.7.3** | The two captions nobody can read |
| **§7.7.4** | Pinning a station out of its balance group |

#### 7.7.1 The defect: §7.4 invents a routing

*Field: "if a part has 0 h for CEU30 and 100 h for CEU32 it should keep 0 h at CEU30, because that
indicates the part does not run in CEU30."*

**A zero is how this plant says a part does not route through a station**, and every 11D part carries
an explicit row for every station in its flow — some of them zero. §7.4 read those zeroes as
unmeasured members of the group and gave them a share. Against the real database:

| | stored | §7.4 shows |
|---|---|---|
| `P1000247599` CEU30 | **0 h** | **94.3 h** |
| `P1000247599` CEU32 | 146 h | 57.1 h |

**94.3 hours placed on a machine the part never visits, and 89 taken off the one that does it.** Not
a rounding difference — an invented routing, on a figure the map, the ladder, the footer, PCE, the
printed map and the engine all read.

**And the test written for it asserted the wrong belief.** *"A station never measured still takes a
share of its group"* was written as a feature, with a comment explaining that inside a group the work
belongs to the group. That reasoning is right for a blank and wrong for a zero, and nothing
distinguished them.

The rule, corrected:

- **Zero means the part does not route here.** Excluded from the group's pot, keeps its zero, and —
  per §7.7.4's transparency rule — does not wall off its neighbours.
- **Blank still blocks.** `StepProblem.noProcessTime` goes back to what it was before §7.4 weakened
  it. A blank is an unanswered question and §6.2 is right that it must stop a run; a zero is an
  answer. The two are different statements and the app already distinguished them.
- **A group needs two or more members with a positive time** to exist at all. `CEU30=0, CEU32=146`
  is therefore not a group, and CEU32 keeps 146 h.

_Known and deliberately out of scope:_ the **engine** does not treat a zero as a skip. `_admit` still
queues the order at that station and it still pays setup and teardown for a zero-length operation, so
the map and the run disagree about what a zero means. That predates §7.4 and wants its own decision.

#### 7.7.2 A run records the takt it ran at

**A stored run does not say what takt it used.** `SimulationRuns` carries `dispatch`, `runStart`,
`runEnd`, `guard`, `abortReason` and `scheduleHorizon` — and not the one parameter the whole
experiment turns on. §7.10 forbids joining back to the live schedule, so it cannot be recovered:
edit the takt table and every stored run silently misreports what it did.

That is one level below the confusion that started this round. The Gantt could not be read because
**the run never said which takt drew it**, and under §7.7's decision that a run is a single-takt
experiment, the takt is the run's identity.

**Three columns on `simulation_run_studies`** — the shape §16.18 used for cell and line, and per
study because takt is keyed by *production line*, so a two-line run has two takts:

| column | for |
|---|---|
| takt value + unit | what a human reads. `2026-08-17 · 11D · 4 d · FIFO` in the history picker, so two runs can be told apart in the menu at all |
| resolved release interval, seconds | what the engine *used* — `takt.equivalentAt(pacemaker's productive day)`. Depends on a schedule that may be edited afterwards, which is precisely what §7.10 freezes |

_Rejected: one takt on `simulation_runs`._ Cheapest, and wrong the moment a run carries two lines.

#### 7.7.3 The two captions nobody can read

Neither of these is a wrong number. Both are a correct number with an invisible caveat, and §2.5
already litigated the shape: *"with no affordance nobody hovers."*

- **The map's period.** `flow_tab.dart:116` draws an 18 px ⓘ when the viewed span crosses a change,
  and `app_en.arb:422` already says the right thing — *"Takt or staffing changes inside this period.
  The map shows the state on its first day."* It was on screen the whole evening and never read,
  and it does not say **which** of the two changed, **when**, or **what the other value is**. It
  becomes **visible text**: `Takt 4 d → 5 d on 1 Apr — showing 4 d`. On **Summary as well as Flow**:
  same provider, same trap.

  _Measured, so the size of it is on the record:_ at **year** granularity the span starts 1 January
  and 11D reads the 4-day takt for the whole of 2026 — CEU30 75.4 h, CEU32 171.4 h. At month,
  quarter or semester in H2 it reads 5 days — 94.3 h and 152.5 h. Same map, same day, same part.

  _Rejected: snapping the period navigator to takt boundaries._ It makes the wrong view unreachable
  rather than merely captioned, which is stronger — and `viewedPeriodProvider` is shared with Demand
  and Summary, where takt governs nothing. Distorting a control two tabs depend on to fix a problem
  one of them has.

  _Rejected: refusing the takt-derived figures, or showing a range._ Everything on that year view is
  a truthful statement about 1 January; blanking six unrelated figures to caveat one is worse. A
  `4–5 d` range in the footer over point values in every box below it is worse still.

- **The run's span.** A fourth nullable column beside §7.7.2's three: the date of the next takt
  change inside the run's span, or null. Shown as a **line in the run header**, not an icon —
  `Ran at 4 d. The takt changes to 5 d on 1 Apr, inside this run's span.` Stored rather than derived,
  for §11.1's stated reason: *"a run that could not say this would drop its own caveat the moment the
  reader came back to it, which is exactly when they are most likely to quote the figures."*

  _Rejected: blocking the run._ Readiness could refuse a demand span that crosses a change — and it
  would forbid the one experiment the field asked for, which is to run 2026 at each takt and compare.
  It would also block 11D outright until somebody edited the schedule.

#### 7.7.4 Pinning a station out of its balance group

*Field: "I would like to add an option to the user to disable the rebalancing for a workcenter."*

**Today the only escape hatch is to clear the workcenter's type**, which is what CLAD06 is
accidentally doing — the one untyped workcenter in a plant where every other CLAD is `Cladding`. That
also blanks the box's type line and loses the icon, so it is a side effect standing in for an intent.

- **Stored per flow step**, a nullable flag on `flow_nodes`, **on by default** so nothing already in
  the tree changes. Not per workcenter, and the argument is §1.1's own: *"it is this line's use of
  the station, and a duplicated study must be re-tunable without disturbing the original."* 11B, 11C
  and 11D **share four stations** — BAN11, TTAT, END and Coating — so a per-workcenter flag on any of
  them changes three studies from a screen showing one, which is §1.3's lesson verbatim. And group
  membership is a *flow* fact: whether CEU30's work can move depends on what is beside it, and that
  differs per study by construction.

  _Rejected: a flag on the workcenter type._ `Machining - HBM is never balanced` is one switch for a
  whole class, and it cannot express "these two, but not those two".

- **A pinned station is transparent, not a wall.** With `A B C D` all one type and C pinned, A, B and
  D still balance across it. Pinning C must not silently stop D balancing — a consequence nobody
  asked for and which shows as D quietly reverting to its measured figure with nothing on screen.
  **"Untyped" and "pinned" are different statements and behave differently:** untyped means *I do not
  know what this machine is*, which has to be a wall; pinned means *I know exactly what it is and its
  content is fixed*, which is the same operation and so is not.

  _Academic on this plant today, and worth saying:_ every group in the database is exactly two
  stations — CEU30+CEU32, CEU27+CEU26, CEU21+CEU22 — and at two members both rules give the same
  answer. This is a decision about what the rule *means*.

- **The toggle is always visible, greyed with a reason when it cannot apply.** In the step dialog
  beside Process Specific Takt, which is where §7.3 put the queue type — *"where the workcenter is
  chosen"*. Positive wording, `Rebalance with adjacent like machines`, checked; the column is a
  *disable* flag so null reads as on and no study needs a backfill.

  **This is the item that fixes the bug that started the round.** The three reasons a station is not
  in a group are all things the app knows, and the greyed caption says which: *the workcenter has no
  type*, *no adjacent step shares its type*, *this part's time here is zero*. Opening CLAD06's dialog
  would have answered the question in one click instead of an evening.

  _Rejected: hiding it when it cannot apply_ (§2.1's rule for the same-part percentage). It protects
  the height of a dialog that already scrolls at 700 px — and it makes all three reasons silent,
  which is exactly where this round started.

- **A station that is not participating gets no mark.** Marking every non-participant would put a
  glyph on seven of 11D's nine boxes and say nothing; marking only the pinned ones inside a live
  group was considered and dropped. **The user has told the app to leave the station alone and the
  map obeys quietly.** If a still station inside a moving group turns out to read as a defect on
  screen, a mark is a one-line addition later.

#### What this costs, and the order

**One v20 migration** carrying all five columns — `flow_nodes.balance_disabled`, and
`simulation_run_studies`' takt value, unit, release interval and next-change date. All nullable, all
landing on tables that predate them, so it is the shape §16.19 called *"no table is rebuilt"*.

1. ~~**§7.7.1 first and on its own, with no schema.**~~ **Done 2026-08-17 in `92afe19`**, with the
   test that asserted the wrong belief.
2. ~~**The v20 migration**, then §7.7.4's flag and dialog.~~ **Done 2026-08-17.** Four columns, not
   five — `simulation_run_studies.release_seconds` already held the resolved interval, which makes
   this the **third** entry in a week to over-specify its own cost. **v20 has met the real database**
   on a copy: `user_version` 20, `integrity_check` ok, 250 orders, 91 runs and 86,463 run steps
   intact, 0 of 39 nodes pinned, 0 of 156 run studies claiming a takt. Written up as §16.21.

   _And it found a stale assertion rather than a defect._ `live_db_check_test.dart` asserted that
   every zero-changeover node still had a null setup — true at the moment v17 ran, false the first
   time anybody used the feature v17 shipped. Two nodes now carry hand-typed setups (`1 min`, and
   `12 h` with a 24 h teardown). That file's own header records it being broken once by a later
   *migration*; this is the same failure through ordinary *use*. The carry is asserted by the unit it
   writes now.
3. **§7.7.2 and §7.7.3** — the run's takt, the run header line, the map caption on Flow and Summary.
   **Half done 2026-08-17.** A run now records the takt it ran at and when that stops being true, and
   the run header states both — `Ran at 4 days · The takt changes on 1 Apr, inside this run's span`,
   in the tertiary colour where the change falls inside the span. `taktLabel` is shared so the three
   surfaces that write a takt cannot disagree about its format.

   _Trimmed while building:_ the caveat names the **date** and not the new figure. Saying "changes to
   5 days" would need the next takt's value and unit stored as two more columns, and the new figure is
   one click away on Capacity. Worth revisiting if the date alone reads as incomplete.

   ~~**Still owed, and it is the half that would have prevented the original confusion:**~~
   **Both landed 2026-08-18 — written, not driven. `flutter analyze` clean, 877 tests.**
   - ~~the **map caption** on Flow and Summary~~ **Done.** `flow_tab.dart`'s bare ⓘ is visible text on
     both tabs: `Takt 4 days → 5 days on 1 Apr — showing 4 days`, in the tertiary colour. `FlowView`
     carries a `taktChange` (the first change strictly after the span's first day that also lands on
     or before its last, via `TaktScheduleSpec.changeAfter`); `SummaryView` copies it, so the two
     tabs that share the viewed period cannot disagree about the caveat. A staffing-only change keeps
     the icon — `scheduleVariesInPeriod` is the broader flag and staffing has no single figure to
     name. One shared widget, `common/period_varies_caption.dart`. **The string `flowTaktChanges` was
     already staged in all three `.arb` files** — added ahead of the drive with a separate `shown`
     placeholder — so this was wiring, not new copy; the near-duplicate `flowTaktChange` I first added
     was removed once the staged key surfaced.
   - ~~the **runs-history picker** label~~ **Done.** The menu row reads `2026-08-15 · FIFO · 4 days`.
     `watchRuns` gained a second join on `simulation_run_studies` (deduped past the station cartesian
     by `workcenterId` and `studyId`), and `RunListing` carries the raw `(value, unit)` pairs;
     `taktLabelForValues` — the fold `runTaktLabel` already used, now public — turns them into one
     label or `mixed`, so the menu and the run header it opens name a run's takt the same way.

   _Still owed here: nothing in code — this closes §7.7.3's build. The drive below is what remains._

**DESIGN.md this round:** **§6.2.1** (rewritten — the zero rule, the pin, transparency), **§7.8** or
wherever §18.3 is answered (a run is a single-takt experiment, by decision), **§7.10** (what a run
records about its takt), **§11.1**'s neighbour (the span caveat), **§12.1** (the run header line),
**§16.20**'s successor **§16.21** (schema v20), and **§8**'s §18.3 entry retired.

#### Drive it

- [ ] **`P1000247599` on the map**, which is the defect: CEU30 must read 0 h and CEU32 146 h.
- [ ] **The greyed toggle on CLAD06**, saying the workcenter has no type — the sentence that would
      have saved this round.
- [ ] **Pin CEU30 and watch CEU32 keep its measurement**, then unpin and watch it move.
- [ ] **The map caption at year granularity on 11D**, naming 4 d → 5 d on 1 Apr.
- [ ] **Two runs of 11D, one at each takt**, told apart in the history picker by their takt, each
      carrying the change caveat — and the Gantt, occupation and queue indicators read against each
      other. That is the whole of how a takt change is studied under this round's decision.

### 7.8 Reading a rebalance off a run — **written 2026-08-18, live at v21, not driven**

**Two commits after §7.7 closed**, both about the same thing from opposite ends: §7.4's balance was
visible on the map and invisible everywhere else. `flutter analyze` clean, **880 tests**.

- **The run was balancing against a stale plant.** `simRunInputProvider` watched the schedules, the
  flow and the demand and **nothing of the workcenters, the pools, the membership or the types** — so
  typing a type onto a station left the assembled input cached and Simulate re-ran the plant as it
  stood before the edit. Harmless while a type was an icon on a box; load-bearing the moment a
  balance group is formed on one. The map was right the whole time, because `flowViewProvider` has
  always watched those four, so what this produced was **two surfaces reading one plant and
  disagreeing about it**.

  ~~_Owed:_ **there is no test on it.**~~ **Written 2026-08-27**, and it is the first
  `ProviderContainer` in the suite: `sim_run_input_test.dart` puts a real in-memory database under
  the real providers, types two adjacent stations `Cladding` through the resources repository, and
  asserts the assembled run picks up the group without a restart — then untypes one and asserts the
  split goes away again. **Checked red against the bug**: with the four watch lines removed both
  tests fail. A watch list is exactly the kind of thing that is correct the day it is written and
  silently short a year later, which is what this defect was.

  _Two things it had to learn that the next container test will not have to:_ the provider's **first
  value is `SimRunInput.empty()`**, because the flagged studies arrive on a stream and readiness is
  not blocked behind it — so a starting state has to be settled for exactly as the state under test
  is. And an **unlistened provider is never recomputed**, so without a `container.listen` the test
  would be asking a cache nobody reads whether it refreshed, and would pass either way.

- **Schema v21: what the work at a step cost.** One nullable column,
  `simulation_run_steps.process_seconds`, and the hover card states it beside the committed span. A
  step's rows bracket the work on the *calendar*, so 76 hours of work reads 148 hours wide across a
  normal week — a station given a bigger share of its group's work and one that merely ran over a
  weekend draw the same bar. That left §7.4's balance readable on the map and unreadable in the run
  of it, which is the one place a planner looks to find out what a change did. Written up as
  **§16.22**; the engine already had the figure and was folding it into occupancy before it could be
  stored.

  **Nothing is backfilled and null is not zero here.** A step whose part does not route through its
  station records zero work on purpose (§7.7.1), so a pre-v21 run omits the card line rather than
  showing a nought.

#### What it owes

- [x] ~~**v21 against the real database, on a copy first.**~~ **Closed 2026-08-27, and the order was
      wrong.** v21 met the live file on **2026-08-18 at 22:33:56** — `db.open schema 21 from 20`,
      `dev` build — with a run of 3 studies, 250 orders and 2000 steps completing at 22:34:03. So the
      column was written against real demand the evening it existed, and **no backup was taken**;
      none had been since v18, which means v19, v20 and v21 all met the live file with the v18 copy
      as the only way back.

      Made good with the app closed: **`flowmap.sqlite.backup-v21-20260827-202158`** (74.5 MB) beside
      the live file, and `live_db_check_test.dart` run with `--tags live` against a copy of it.
      `user_version` 21, `integrity_check` ok, 39 flow nodes, 250 orders, **98 runs and 100,463 run
      steps**, 0 of 39 nodes pinned, 1 of 98 runs carrying the work and 3 of 98 carrying v20's takt.

      **The check failed the first time, on v20's assertion rather than v21's**, and that is the
      finding worth keeping. *"No stored run claims a takt"* was true the moment v20 ran and false
      the moment somebody pressed Simulate afterwards — the third time this file has asserted a fact
      about an instant and had ordinary use falsify it (§16.21 records the first). Both are rewritten
      against the **ordering** instead: every run that answers a new column is newer than every run
      that does not, which a backfill breaks and use cannot. §15 carries the rule now so the next
      migration does not rediscover it.
- [x] ~~**A regression test on the watch list**~~ — done, per the entry above.

#### Drive it

- [ ] **The rebalance, seen in a run.** Célula 11D at each takt: the card's work figure on CEU30 and
      CEU32 must show the split the map shows, and the committed span must be the longer of the two.
      That is the whole point of the column and it is the one check that cannot pass by accident.
- [ ] **A pre-v21 run from the history picker omits the line** rather than reading zero. There are 91
      stored runs and every one is a fixture for this; it is the check whose failure would be silent,
      because a zero looks like a measurement.
- [ ] **Whether the card is too tall.** `_cardHeight` went 168 → 186 and the card is anchored to the
      bar, so the bottom row and the right-hand edge are where it gets pushed back inside (§0's own
      standing item on the hover card).
- [ ] **Edit a workcenter's type and press Simulate without restarting.** The run must balance on the
      type just typed. That is the defect above, seen from the user's side, and until the test exists
      it is the only thing that checks it.
- [ ] **es and pt** on the card's new label.

### 7.9 The takt belongs to the order — **code-complete 2026-08-27, engine driven 2026-08-29**

*Field: "the gantt chart shows the same process time for a part number on different takt times."*

**It does, and it always has.** Every run 11D has ever recorded ran at **4.0 days** — `53c99a93`,
`6c022b76`, `d0f3c77f` on 2026-08-18 and `67f5d7f2` at 20:27 on 2026-08-27 — while the line's takt
table has held **two** periods since 21:30 on 2026-08-16: `4 days` to 2026-03-31 and `5 days` from
2026-04-01. **The second period has never been consulted by anything.**

`sim_assembly.dart:176` reads `taktSchedule.taktOn(asOf)` once, where `asOf` is the **cold start** —
a date §7.8 derives by walking a theoretical lead time back from the first need date, which for 11D
lands on **2025-10-10**, three months before any order is due and squarely inside the 4-day period.
The split is computed there and frozen onto `SimStep.balancedProcessTimes` for the whole run.

**The map has been right the whole time**, because it balances against the viewed period's takt —
which is exactly why the two surfaces disagree, and why this reads as "the rebalancing is broken"
rather than as "the run is reading one date".

```
takt      4 days ─────────────────────┤ 1 Apr ├────────── 5 days ──────────►
demand                2026-01-02 ████████████████████████████████ 2026-11-30
releases            2025-10-10 ██████████████████████ 2026-07-14
run reads the takt here ↑   nobody chose this date and nothing shows it
```

**Eight of eleven demand months sit under a takt no run can reach.** Moving the sample point to
something sensible does not fix it either: the first need date is 2026-01-02, still inside the 4-day
period, so the figures would not move at all.

#### What a takt period actually says

*Field: "the takt period defines the takt time of every order that will open on that period and the
takt of the order start for the pacemaker."*

**A takt belongs to the order, not to the run.** An order opened while 4 days is in force runs at 4
days — its release slot and its work split alike — and **keeps them the whole way down the plant**,
even if it is still in the shop in June. Orders opened from 1 April take 5 days. Successive orders
differ; one order is never re-cadenced in flight.

**§18.3 is not retired by this — it was misread.** *"Changing a takt mid-run is impractical"* is a
statement about work **already in flight**, which stays true and is what this design honours. It was
read as *"a run has one takt"*, which is a different claim and was never the field's. §8's entry is
corrected rather than reopened.

| | |
|---|---|
| **§7.9.1** | Which instant fixes an order's takt |
| **§7.9.2** | What happens where no takt covers an instant |
| **§7.9.3** | What a run stores, and what says it |
| **§7.9.4** | The order, and what it invalidates |

#### 7.9.1 The release instant, and the one circularity

**An order's takt is the one in force at the instant it is released.** The two candidates put the
boundary in very different places over the same 60 orders of 11D:

| fixed by | before 1 Apr (4 d) | from 1 Apr (5 d) |
|---|---|---|
| **its release** — when it opens | **37** | **23** |
| its need date — when it is due | 16 | 44 |

Three reasons, in order of weight. It is what *"every order that will open on that period"* says — a
takt is about how often you **start** work, not about when it is due. It is self-consistent with the
slot walk, which must already read the takt at each slot instant to know when the next one comes, so
the order released at that slot takes the same takt from the same read: **one rule, one instant, no
second concept to keep aligned.** And need-date-based would build an order opened on 10 February to a
5-day split while every order around it on the floor opens every 4 days — the cadence and the work
content disagreeing about which plant the order is in.

**The pacemaker keeps both its jobs, and the transition is not coded.** It still times the slot on
its own calendar and gates the release on its lane (§7.2). From 1 April the slots simply come at the
new interval; the pacemaker is still chewing through 4-day work for about one lead time, and that
shows up because it is *queueing*, not because a rule moved. *Rejected: moving the clock to the first
workcenter for the transition window.* It would make the interval jump twice for one takt change —
once on 1 April and once on a date nobody could name in advance — and make `days` mean two different
stations' days inside one run, which is §17.4's scar.

**One circularity, broken where the repo already breaks it.** An order's release comes from the slot
walk; the *first* order's release comes from `coldStartDate`, which walks back through
`processTimeFor` — the balanced time — which needs a takt, which is read at the release. §16.10
already assembles a run twice for exactly this shape: pass one walks from the need date, pass two
re-reads the takt at the start it produced. **No third pass**, which is that section's own rule, and
every order after the first is walked forward with no circularity at all.

#### 7.9.2 No takt, no releases

The takt was read once, so a gap or a cliff in the takt calendar could never reach a run. Read at
every slot, it can now come back null.

**A study with no takt in force does not open orders.** The next slot is scheduled at the **start of
the next takt period**; where there is none, that study stops releasing and its remaining orders
surface as §7.8's *"N orders never completed"*.

**The precedent is already in the tree and it decided this against instinct.**
`WorkcenterScheduleSpec.operatorsOn` returns `const []` for a date no period covers — a station whose
schedule has run out is **closed**, and the `availability ?? 1` beside it says outright that it
exists *"to keep this function total rather than to be relied on"*. A takt table that outlived its
last row and went on opening orders every 4 days would be the one schedule in this app that does.

_Rejected: holding the last takt forward._ It keeps every run that works today working, and it is a
**guess about what the planner meant** — §10.2's rule is that forgiving is not guessing, which is why
a bare `batch` column is refused rather than assumed to be a size.
_Rejected: aborting the run._ §11 has consistently chosen warn-and-continue over block, and an abort
throws away the part of the run that was perfectly well cadenced.

**The cost is a behaviour change that will look like a bug**: a plant whose takt table stops at year
end goes from *"all 60 orders released"* to *"12 orders never opened"*. That is revealing rather than
regressing — those orders are being released today at a cadence with no schedule behind it — and it
needs a release-note line.

**So the run records why releases stopped.** One nullable field beside `abortReason`, stated in the
run header: *"Célula 11D's takt schedule ends 2026-12-31; 12 orders were never opened."* §11.1's
warning cannot cover this — it compares the run's **end** against `scheduleHorizon`, and a run that
stops releasing early may well end *before* the horizon with the warning silent. And §11.1's own
argument applies verbatim: a run that could not say this would drop its own caveat the moment the
reader came back to it, which is exactly when they quote the figures.

_Rejected: leaving it to "N orders never completed"._ That names the symptom and hides the cause, and
the two it collapses — a jammed plant and a missing schedule row — want opposite responses. §7.7 is
the record of what an unreadable caveat costs.

**No empty slots are recorded during a gap**, and that follows from the rule rather than qualifying
it: §18.5 counts empty slots against the cadence, and in a gap there is no cadence to count them at.
The gap is a run-level fact instead.

#### 7.9.3 What a run stores, and what says it

**Schema v22: the takt value and unit an order opened under**, two nullable columns on
`simulation_run_orders` — 5,330 rows across all 98 stored runs, ~250 per run, no table rebuilt, the
shape §16.19 called safe.

**v21 is the argument for it.** That column exists because a run could not say what the work at a
step cost and §7.10 forbade deriving it, so it was copied in. The takt is now precisely **the reason**
two orders of one part carry different work. Recording the effect and leaving the cause to be
re-derived from a schedule that may have moved is the same defect one level up.

_Rejected: a first-and-last pair on the study row._ Cheap, and it answers the header — and it cannot
answer the question a planner actually asks when two bars of one part are different widths, which is
*which takt built this one*, and that question is the whole point of the round.
_Rejected: storing nothing and inferring from the change date._ §7.10's rule outright.

**`release_seconds` on the study row is redefined, not duplicated.** It becomes *the interval at that
study's first release*; the per-order value and unit are what a human reads, and the resolved seconds
only ever mattered for reproducing the cadence, which the per-order takt now does. The study's
`takt_value` / `takt_unit` mean the same thing — the takt at its first release — and
`next_takt_change` stops being a caveat and becomes the boundary the run actually crossed.

**Where it is read:**

- **The hover card names the order's takt**, beside v21's work figure — `Work 95.2 h · Takt 5 days`.
  It is the surface the question is asked on, and the card already carries the study, the project and
  the description for that reason.
- **The production plan gains a fifteenth column**, exported with the rest, so the boundary can be
  sorted and sent. §12.6 records the plan pushing Float off the right edge at fourteen; this is the
  column that has to earn its width.
- **The runs-history menu folds a `DISTINCT` over the per-order takts** — `4 days`, `4 → 5 days`, and
  `mixed` for anything that is not an ordered pair, so a run that went 4 → 5 → 4 says `mixed` rather
  than lying about where it ended. `watchRuns` gains a second aggregate. _Rejected: denormalising
  first/last/count onto the study row_ — `taktLabelForValues` exists **because** the menu and the run
  header must not name a run two different ways, and a copy can only agree by being written
  correctly where a query agrees by construction.
- **The run header states the fact rather than hedging**: `Ran at 4 days to 1 Apr, then 5 days`.

**A pre-v22 run says nothing per order**, which means *made before a run said this* — the meaning a
blank has had on these tables since v12.

#### 7.9.4 What it costs, the order, and what it invalidates

**In the engine:** `SimStudy.releaseInterval` becomes a schedule rather than a `Duration`;
`_nextSlot` reads the takt at `_now`; `SimStep` carries its split **keyed by `(value, unit)`** rather
than one map, precomputed at assembly over the distinct takts the run can reach — two, for 11D.

**Keyed by the figure, not by the period**, so two adjacent periods both stating `4 days` are one key
and not a change — the same rule `TaktScheduleSpec.changeAfter` already applies to the map's caption.
_Settled by recommendation and untested against the floor:_ if a planner ever means two periods of
one figure to be genuinely different regimes, that key is wrong.

**Not changed, and each for a stated reason:**

- **The map.** It already balances per viewed period. It was right throughout.
- **The queue stock.** `_stockAt` turns `pieces × takt` into days at the **run-start** takt and stays
  there. The pile is an observation of the plant at the start, not a property of any order, and §5.5's
  rule is never to overwrite an observation with a rule — one physical pile reporting three
  durations because three orders passed it is worse than the small inconsistency of leaving it fixed.
- **The theoretical lead time** uses the order's own takt — same figures, one source — but **barely
  moves**, and that is worth knowing before somebody reads a flat efficiency as a bug. The balance
  *conserves* a group's work content (76.1 + 117.9 = 194 = 95.2 + 98.8); it only moves it between
  stations, and 11D's grouped stations share what converts work into elapsed time — CLAD06 and
  CLAD25 both 84 % on one pattern, CEU30 and CEU32 both 83.2 %. What shifts is weekend alignment.

**Every stored 11D run stops being comparable with new ones.** Releases after 1 April move to a 5-day
cadence, so lead times, occupation and queue depths all shift. **The fourth time** — §2.12, §3.1 and
§1 were the others — and it wants a release-note line rather than a silent discovery.

**Two rounds, driven between**, and the seam is natural rather than invented to obey §2.0:

1. ~~**The engine and assembly alone, with no schema.**~~ **Written 2026-08-27.** `flutter analyze`
   clean, **890 tests**, no schema touched. What landed:

   - `SimTakt` — a takt as a **figure**, `(value, unit)`, structural equality and the balance's key.
     `SimTaktPeriod` — one stretch of the cadence with its interval already resolved against the pace
     setter's productive day, so the engine is still handed durations and never a schedule to
     interpret.
   - `SimStep.balancedProcessTimes` is keyed `takt → part → duration`, filled at assembly for every
     figure the line's schedule states. `processTimeFor` takes the takt; **asked without one it
     answers the measurement**, which is what every caller with no order in hand is asking for.
   - `SimStudy.taktPeriods`, with `taktAt`, `intervalAt`, `taktKeyAt` and `cadenceResumesAfter`.
     **Empty means one unbounded period at `releaseInterval`** — exactly the old behaviour — so every
     existing test still says what it said, and a caller that hands over no schedule gets what it
     always got.
   - The engine remembers the takt each order **opened** under and costs every one of its steps at
     it. The slot walk reads the takt at each slot; a slot landing where no period covers opens
     nothing and reschedules at the next period's start, or ends the study's cadence.
   - The cold start resolves its own takt in **two passes** — walk from the need date, and re-walk
     once if the start that produces sits under a different takt. No third, for §16.10's reason.
   - The theoretical walk takes the order's takt, so its standard is built from the same split the
     run charged it.

   _One defect found while writing it, and it is the useful kind:_ the coverage check was first put
   only where the **next** slot is booked, and an interval measured inside a period can carry a slot
   past its end — so a slot still fired in a gap and released an order the line had no cadence for.
   It is asked when the slot **fires** now. Three of the four new engine tests failed on it, which is
   what they were for.

   _And the repository test caught a fact rather than a bug:_ its fixture's demand is needed in late
   August, so the study's first release lands in the **second** takt period. That is the shape of the
   whole round — before it, the first period was unreachable by any run of that study.

2. ~~**v22 and the four surfaces.**~~ **Written 2026-08-27.** `flutter analyze` clean, **892 tests**.
   Schema **v22**: `simulation_run_orders.takt_value` and `takt_unit`, and
   `simulation_run_studies.cadence_ended_at`. Three nullable columns, no table rebuilt, written up as
   **§16.23**. What landed:

   - **The hover card names the order's takt under the work it explains.** `_cardHeight` 186 → 204.
     Read off the plan by order id, like the project and the description — and held as the raw
     `(value, unit)` rather than the words, because the facts are gathered in `initState` where no
     `AppLocalizations` exists yet. That cost a round of red: formatting there threw
     *"dependOnInheritedWidgetOfExactType was called before initState completed"* across 52 tests.
   - **The plan takes a fifteenth column**, between Order end and Theoretical LT, and exports it as
     the same words the screen shows. Float moves one column further right, which §12.6 already
     names as this table's nearest cliff.
   - **The menu folds what a run actually opened under** — `4 days`, `4 → 5 days`, or `mixed`.
     `taktSequences` orders each study's takts by first release and collapses only *consecutive*
     duplicates, so a run that went 4 → 5 → 4 reads `mixed` rather than claiming a change it never
     made. A **second query rather than a third join**: the takt is on the orders now, and a run has
     hundreds of those against a handful of stations.
   - **A study that stopped opening orders says so by name**, with the date and how many never
     opened, in the tertiary colour beside the takt line.

   _Where the seam actually was:_ the fold lives in `simulation_runs_repository.dart` rather than in
   `unit_labels.dart`, because `unit_labels` already imports the repository for `RunQueues` and the
   reverse would be a cycle. The label itself stays in `unit_labels`, which is what has to be shared.

   **v22 met a copy of the real database** the same evening: `user_version` 22, `integrity_check` ok,
   250 orders, 100 runs, 104,463 run steps, **0 of 100 runs answering the new column** — correct,
   since none has been made under it — and 0 studies recording a stopped cadence. Backed up first as
   `flowmap.sqlite.backup-v21-20260827-215250`. The live file itself is still at v21.

_Rejected: one round._ It moves the engine's core loop **and** rebuilds four surfaces, and a defect
found at the end could not say which half moved the figure — §16.11 is the record of what that costs.
_Rejected: four commits driven apart._ The plan column, the menu label and the warning are
independent of each other and nothing is learned by separating them.

#### Drive it — **the engine is driven and confirmed; the surfaces are reported, not itemised**

Both rounds were written before either was driven. §2.0's rule was to drive between them and it was
not kept — round two followed round one the same evening — so **what tells the two halves apart is
that the engine list below was checked against the stored run rather than against the screen.**

**Driven 2026-08-29 under `0.1.0-2026-08-27a`**, session 07:59:57, `db.open schema 22 from 22`. The
run that answers this list is **`7669856d`**, made at 08:00:03 — *"3 studies, 250 orders, 2000 steps
in 1225 ms"*.

#### The engine — **confirmed against the stored run**

- [x] ~~**11D across 1 April.**~~ **Confirmed.** The run splits 11D's 60 orders **37 at 4 days and
      23 at 5** — the exact split §7.9.1 predicted from the release dates. `P1000216567-13P01`, in
      clock hours as the run charges them:

      | | CLAD06 → CLAD25 | CEU30 → CEU32 |
      |---|---|---|
      | opened before 1 Apr | **94.0 → 145.5** | **94.0 → 202.6** |
      | opened after | **117.5 → 122.0** | **117.5 → 179.1** |

      Those are the predicted work figures derated by each station's own availability and rework
      (76.1/117.9 and 95.2/98.8 at CLAD ×1.2345; 75.4/162.6 and 94.3/143.7 at CEU ×1.2464) — every
      one of the eight to the decimal. **And it is a rebalance rather than a shuffle**: the cladding
      pair goes from 94.0/145.5 at 4 days to 117.5/122.0 at 5, which is a line that was 1.55× out of
      balance coming out level.
- [x] ~~**The cadence visibly changes.**~~ **Confirmed.** Median wall-clock gap between releases
      **127.4 h before the change and 147.6 h after**, over 37 and 22 gaps. Wall clock rather than
      the 75.4 → 94.3 h of pace-setter time, because the gaps carry whatever weekends they crossed.
- [x] ~~**11B and 11C come out identical to `67f5d7f2`.**~~ **This expectation was wrong, and the
      drive is what showed it.** Their **work** is untouched — 0 of 420 and 0 of 1040 step rows
      differ, and the totals are byte-identical — but their **timing moves**, and it has to: §7.7
      builds one resource model of the plant and 11B, 11C and 11D share TTAT, BAN11, END and
      Coating. Changing 11D's release cadence changes what those stations are contending with, which
      is the whole thing a combined run exists to show.

      _What the check should have said, and now does:_ **no work row outside the line with the takt
      change may move.** That is the confined-blast-radius claim; "nothing may move" was a claim
      about a plant with no shared stations, which this is not.
- [x] ~~**A part that empties a station.**~~ **Confirmed in the run:** `P7000109738P01` at 5 days
      gives CEU30 **108.4 h** and CEU32 **0.0** — §6.2.1's "the split can empty a station out of a
      part's routing", on real data for the first time. **Whether it reads as a finding rather than
      a bug on screen is still open** and is the one part of this item a database cannot answer.
- [x] ~~**§7.9.2, exercised by accident and recorded.**~~ Not on the original list. The 5-day period
      was **deleted** from the takt table after `7669856d`, so the three runs at 08:02, 08:03 and
      08:04 met a line with no cadence from 1 April: each released **37 orders and left 23 unopened**,
      `1793 steps` against `2000`, and `simulation_run_studies.cadence_ended_at` reads
      **2026-04-01 19:07** for 11D and null for 11B and 11C. That is the whole of §7.9.2 — no takt,
      no releases, and the run saying so — met on the real database rather than in a fixture.

      **Still owed: whether the header's sentence is on screen and reads right.** The column is
      right; nobody has confirmed the line above it.

#### The surfaces — **reported working, not itemised**

*Field, 2026-08-29: "now it works properly."* That covers the round, and §5.3 is the record of what
ticking individual boxes on a verbal report costs — so what is ticked below is what a stored run can
corroborate, and the rest stays open until somebody says which of them they looked at.

- [x] ~~**The card's takt line against the plan's column**, on the same order, in all three
      languages.~~ **Done 2026-08-29** under `0.1.0-2026-08-27a`. Reported good as part of a group of
      five rather than itemised — see `DRIVE-2026-08-29.md` §5.
- [x] ~~**The menu tells two runs apart.**~~ **The data is there and it is a sharper case than the
      one asked for**: the picker now holds `7669856d` spanning **4 → 5 days** beside three runs at
      **4 days** and ninety-odd pre-v22 runs, all made against one plant within four minutes.
      **Confirmed on screen 2026-08-29** under `0.1.0-2026-08-27a`, session 10:09:31 — the picker
      shows `7669856d` as 4 → 5 days and the other three as 4 days. The fold was unit-tested; the
      query was what nobody had looked at, and now somebody has.
- [x] ~~**A takt table cut short on purpose**, so releases stop: the run header must name the study,
      the date and how many orders never opened.~~ **Done 2026-08-29** under `0.1.0-2026-08-27a`,
      session 10:09:31. `4c29fcc2` opened from the picker and **the header names the 23 orders that
      never opened**. That closes the sentence §7.9's engine half explicitly could not answer —
      *"the column is right; nobody has confirmed the line above it"* — and it needed no contriving,
      because the run already existed.
- [x] ~~**The plan at fifteen columns**, on screen and in Excel — Float is the column most likely
      to have gone off the right edge (§12.6).~~ **Done 2026-08-29**, in the same group of five.
- [x] ~~**The card at 204 px**, on the bottom row and at the right-hand edge.~~ **Done
      2026-08-29**, in the same group of five. It had grown twice in ten days unlooked-at.
- [x] ~~**v22 against the live file itself.**~~ **Done 2026-08-27 at 21:57:36** under
      **`0.1.0-2026-08-27a`**: `db.open schema 22 from 21`, with the build label and the line both in
      `log.txt` — which is the pair §0 says a stale link cannot produce. The Aug-3 exe rule held
      again: `app.so` moved to 21:57:20 and `flowmap.exe` stayed at 16 August, so the label is what
      says the Dart code is this one. Backed up first as
      `flowmap.sqlite.backup-v21-20260827-215250`.

**DESIGN.md — written, both rounds**, ahead of the drive rather than after it, on §5's rule that a
design file disagreeing with the tree is worse than one behind it.

_Round one:_ **§6.2.1** (which takt each side balances against, and what the split is keyed on),
**§7.2** (rewritten — a takt period says how often orders open in it; no takt, no releases; why that
is not an empty slot), **§7.10** (the study row's takt is its first release's), **§16.10** (what the
second assembly pass still settles), and **§8**'s constraint 3 corrected — the decision stands, the
reading of it did not.

_Round two:_ **§7.3**'s label passage (a run is labelled with its takt *sequence*, and why the menu
reads the orders rather than a summary), **§8.5.1** (fifteen columns, and why Takt introduces the
three it explains), **§8.6** (the card names the takt under the work), **§11.1** (the takt is the one
schedule that does **not** carry forward, and `cadence_ended_at` is why that needs its own record),
**§12.6** and **§13.1** (fourteen became fifteen), and **§16.23** (schema v22).

---

## 8. Round eight — the phantom visit, five surfaces, and a save that fails

**From driving `0.1.0-2026-08-27a` on 2026-08-29**, session 07:59:57, `db.open schema 22 from 22` —
the same session that produced §7.9's engine confirmation and the field's *"now it works properly."*
`log.txt` carries the build label and the `db.open` line, which is the pair §0 says a stale link
cannot produce, and `TODO.md` was written at 08:25, one minute after the log's last route. **So this
round has the provenance §5.3 was un-ticked for lacking.** What the log bounds is the *drive*, not
the *items*: routes are logged and tabs are not, so `/studies/:id` being open four times says
somebody was inside a study and says nothing about which tab.

Settled by interview 2026-08-29, and **§8.5 was added by the drive on the same day** — it is the
only item here nobody asked for. §2.0's rule holds: the engine change and the four surfaces are one
round because none of the surfaces reads a run.

### 8.1 A zero-process step is not a visit — **code-complete 2026-08-29, not driven**

`engine.dart:757` treats a **null** process time as the blocking readiness error `DESIGN.md`
§11 defines — the order is never admitted and the guard reports it. An explicit **zero** takes
the other branch and is admitted normally: the order queues in the lane, holds a slot against
`_queued(queue.targetId) < capacity`, is dispatched, occupies the station for zero seconds, and
stores a step row.

**That is a correctness defect and not a drawing one.** `SimulationRunSteps.processSeconds`' own
doc says zero *"is what a step the part does not route through legitimately records"* — so a part
that skips a station is currently made to stand in that station's queue. On a capped lane it holds a
slot a real order needs, and §0's confounder run is the measurement of what a cap does when it
binds: `676fb0e3` manufactured **216.4 d of blocking** and bought nothing. Phantom orders feed that.

A zero-time step advances past the station instead. No lane visit, no step row, nothing to draw —
and the Gantt's `if (bars == null) continue` at `gantt_layout.dart:544` then drops the row without
being touched.

**This invalidates every stored run**, which is the fourth time (§2.12, §3.1 and §1 were the others)
and is why §0 comes first — those checks are only worth making while the engine still agrees with
the numbers that raised them.

**Landed 2026-08-29.** The skip lives in `_nextStep`, which is the one place that decides what an
order visits next, so all three movement paths inherit it — the release's entry step, an arrival, and
an unload. **`_nextStep` took the order and the takt to do it**, because zero-ness is not a property
of a step: `processTimeFor` prefers `balancedProcessTimes[takt]` over the part's own figure, and
§7.4's rebalance is free to empty a station out of a routing at one takt and fill it at another.
§7.9 measured exactly that on the real plant. **The gate moved with it** — `_gateIsFull` now asks
about the lane the order will actually enter rather than about node 0.

**A step with no time at all is still returned rather than skipped.** Null is §11's blocking
readiness error and `_admit` is where it is reported; skipping it would turn a fault the guard names
into a silently shorter flow that delivers and looks fine.

**Four tests, in `engine_test.dart` under its own group.** Three of them fail against the old
engine — the missing step row, the phantom slot on a capped lane, and the routing following the
takt. The fourth passes either way **on purpose**: it pins the null case as a readiness error, which
is the behaviour this change must not alter. `flutter analyze` clean, **896 passing** where there
were 892.

**And the drive of 2026-08-29 found the symptom that had been missing.** This round was argued from
lane-slot contamination, which nothing on screen shows. It also draws the plant in the wrong order:
*"in Célula 11D the gantt y axis CEU32 is in front of CEU30, but this is not the flow order."*

`routingRanks` (`gantt_layout.dart:842`) ranks a station by the earliest **index** it occupies in an
order's step list, sorted by `queueStart` — and a zero-process step occupies an index while doing
nothing, pushing everything behind it one place later. Replayed against `7669856d`: **CEU30 and
CEU32 both rank 4** as built and tie, so the Queue table's busiest-first order breaks it and CEU32
is drawn on top; with the zero-time steps gone **CEU30 ranks 3 and CEU32 ranks 4**, which is the
flow. The run carries **160 zero-process steps in 2000**, and **71 orders have two steps sharing one
`queueStart`** — a step that ends where it starts hands its successor the same instant.

**A second thing the replay exposed, and this round does _not_ close it.** Even with the phantoms
gone, two stations genuinely at one routing position still fall to the Queue table's busiest-first
ranking, which is a statement about load rather than about flow. That is right for a pool's like
machines — they *are* interchangeable — and wrong for two stations in sequence that happen to tie.
§8.1 removes the tie in this case; it leaves the tie-break as it is. Listed in §10.

_The case is real and already measured._ §7.9 found `P7000109738P01` at 5 days giving CEU30
**108.4 h** and CEU32 **0.0** — §6.2.1's "the split can empty a station out of a part's routing", on
the live database. §7.9 left open *"whether it reads as a finding rather than a bug on screen"*.
**It reads as a bug, and this is the answer**: the finding stays in the run's figures, and the
phantom visit stops happening.

### 8.2 The workcenter card is as tall as its schedule — **code-complete 2026-08-29, not driven**

`station_cards.dart:145` pins each card to `maxHeight: 320` and `data_grid.dart:302` puts the grid's
body in `Expanded(ListView.builder)`, so two periods claim all 268 px under the 52 px header. The
red bracket on the reported screenshot is that gap.

The card grows to its content and **keeps the 320 px ceiling**. The cap's stated reason — a page
carries one card per workcenter and *"a station's schedule is as long as the plant decides"* — only
bites at eight rows or more, and above the cap the grid scrolls exactly as it does today.

_Not taken:_ removing the cap. §6.3 already tried to end the nested scroll regions by replacing the
cards with one grid, and lost when driven — but the scrolling was never the half that lost.

**Landed 2026-08-29, and the policy went to whoever owns the ceiling.** `DataGrid` gained
`heightFor(rowCount)` — the heading, the rule, the rows at their declared `itemExtent`, and the
scrollbar's gutter — and the card sizes itself to `min(heightFor(periods + 1), 320)`. The grid's own
`Expanded` is untouched, so above the ceiling it scrolls exactly as before. **One past the end**,
because the blank row a period is typed into is a row the box has to be tall enough to show.

**The grid could not have decided this for itself**, which is why the arithmetic is public and the
policy is not: a grid is handed a height and fills it, and only the caller that bound it can tell
whether the bound is doing anything.

**Four tests, and one of them earns its place.** *"At the height it asks for, nothing is left to
scroll"* is asserted against the mounted widget's scroll extent rather than against the formula, so
it fails the day a row stops being a fixed extent — which is the only thing that could make
`heightFor` a lie.

### 8.3 The grid's headers centre — **code-complete 2026-08-29, not driven**

`data_grid.dart:342` offers `end` for a numeric column and `start` for everything else, and never
centre. Headers centre in all three grids — Demand, the workcenter schedules and Takt, 21 columns
between them — and **cell values keep their own alignment**: `data_grid.dart:29`'s *"right-aligns
the cell — times, quantities, dates read better that way"* is what lets a column of percentages be
scanned, and centring the data would cost that.

Reported against the workcenter screen only. Changed everywhere on the argument that three grids
aligning their headers three ways is worse than three moving at once.

**Landed 2026-08-29**, one line, with a test that fails against the old alignment on both a numeric
column and a plain one. **`data_grid.dart:29`'s rule stands untouched**: the cells keep `end` and
`start`, because a right edge is what lets a column of percentages be scanned and centring the data
would have cost that. Only the headings moved.

### 8.4 Nodes drag along the spine — **code-complete 2026-08-29, not driven**

Reordering is a relative `±1` move inside the step dialog today (`flow_node_editor.dart:152` →
`studies_repository.dart:429`). A node becomes draggable: pick it up, an insertion caret opens
between its neighbours, and the drop calls the same `moveNode(from, to)`.

**The geometry stays derived.** `flow_layout.dart:3` — *"Derived from the node sequence, never
stored… there is only one ordering, and this reads it"* — is what makes it impossible for the
drawing, the lead-time ladder and the routing to disagree, and dropping a box does not buy it a
coordinate. The box animates back onto the spine rather than jumping, so the snap reads as
deliberate.

_Not taken:_ free placement. That is the map that never runs, deferred by decision below
(§11) — *"just for visual but in a more free"* — it is M5-sized, and it needs the second layout
path that section costs out. A drag that reorders is not a down payment on it.

**Landed 2026-08-29.** A `Draggable` on the step box, and the `+` at each gap became a `DragTarget`.

**No drag handle, and none needed.** A `Draggable` claims the gesture where it starts, so the
`InteractiveViewer` only ever sees drags that begin on empty canvas — dragging a box reorders it and
dragging the canvas still pans, which is the split a reader expects without being told.

**The `+` is the drop target, and deliberately not a wider band.** The gap already carries §7.3's
queue, whose *whole channel* is a click target — a drop zone spread along the link would have taken
those clicks, which is the kind of quiet regression §7.5's drive spent a round on. The affordance
that already means *"something goes here"* is the one that accepts a step. It grows and fills while
a step is over it, and dims on the two gaps the dragged step already sits between, so a target that
would do nothing does not look live.

**The box stays where it was while it is in the air.** A spine that closed up under the cursor would
move every gap the reader is aiming at, including the one they set out for.

**The arithmetic is the whole risk, so it is a pure function in the widget-free layout file.**
`dropTarget(from:, gap:)` — an `InsertionPoint.position` is a gap in the list *as drawn* and
`moveNode`'s `to` is an index in the list *after the step has been lifted out*, so every gap right of
the dragged step is one place further left than it looks, and the two gaps either side of it are
no-ops that must not write a reorder at all.

**Thirteen tests, asserted against the order a reader is left with rather than against an index** —
including an exhaustive pass over every step and every gap that checks the step lands between
whatever the gap was between. Mutating the mapping to never subtract fails six of them. `flutter
analyze` clean, **926 passing**.

### 8.5 The banner reports the press, not the provider

**Found by driving, 2026-08-29 under `0.1.0-2026-08-27a`, session 10:09:31.** Simulate was pressed
from each of the five study tabs. **One run happened; four did nothing — and all five showed a green
banner naming an on-time percentage.** The reporter had no way to know four of them were the
previous run's figure.

The evidence, gathered before the cause was looked for:

| | |
|---|---|
| `sim.run` lines in the session | **1** — `10:11:38`, and the route before it is `/simulation`, not a study tab |
| rows added to `simulation_runs` | **1** — `38f0f2d0`; the database went 104 → 105 |
| route trail after it | `/studies/…` → `/simulation`, five times over, **no `sim.run` between any of them** |
| could a run go unlogged? | **No.** One emit site, inside the one `run()`; `Diag` flushes every line (`flush: true`) |

**The reporting defect is unconditional and does not depend on why the run was skipped.**
`SimulationRunner` is `@riverpod` — auto-dispose — and its `build()` deliberately returns the last
stored run, *"so opening the tab shows the run that was last made rather than an empty screen"*,
which is most of what storing a run buys (§7.10). `_run()` then does this
(`project_workspace_screen.dart:357`):

```dart
await ref.read(simulationRunnerProvider(project.id).notifier).run();
final run = ref.read(simulationRunnerProvider(project.id));
final metrics = run.value?.metrics;                 // the LAST STORED run
final failed = run.hasError || metrics == null;     // false — metrics exist
onFinished(( message: '…: ${(metrics.onTimeDelivery * 100).round()}%', failed: failed ));
```

**Nothing in that ties the metrics to the press.** `run()` returns silently when the run is not ready
— `if (!assembled.canRun) return;` — leaving `state` exactly as it was, and the banner then reports
that unchanged state as a success. "Ran and succeeded" and "did not run at all" are the same green
banner with the same number in it.

**The fix is that `_run` must compare identities, not read state.** `run()` returns `void`; it should
return the id of the run it stored, or null when it stored nothing, and the banner should be built
from that. A percentage with no run id behind it is a figure that cannot say which run it came from
— the same class of defect as §7.6's Lead Time Efficiency, which agreed with three sections of
`DESIGN.md` and was upside down.

**Why four presses did nothing is still open, and the drive has already ruled out the obvious
answer.** The first candidate was the silent guard — `if (!assembled.canRun) return;` — but the
readiness check made later the same sitting shows **the button greys correctly when `canRun` is
false**: a step set to "None" on 11D disabled Simulate, named the study in the tooltip and listed it
in the popover. A grey button cannot be pressed, so the guard is not what four presses met.

What remains: the family notifier being disposed across the study-tab → app-bar → navigation
sequence, which is exactly when an auto-dispose provider goes; or `state` being overwritten by
`build()` re-running on `projectRunsProvider` emitting, between the `await` and the `ref.read` two
lines later. **Reproduce before fixing** — the route trail above is a recipe, and `log.txt` is the
oracle, because the screen is what lied.

**The reporting defect does not depend on any of that and should be fixed regardless.** Whatever
stopped the run, `_run` could not tell — and would not have been able to tell if the run had failed
for a reason nobody has thought of yet.

_This is why §0 ran before §8 rather than after._ The item it closes has been open since 2026-08-15,
worded *"the wiring from Simulate to banner to tab switch is only covered by pressing it."* Somebody
pressed it.

### 8.6 A flow that visits one station twice cannot be saved — **code-complete 2026-08-29, schema v23, not driven**

**Found by driving, 2026-08-29, and found by accident** — a step was re-bound to the wrong station
while putting §8.5's readiness check back, which left Célula 11D pointing at **CEU32 at both
position 4 and position 5**. That is a mis-configuration, and the app's response to it is the defect:

```
10:44:47 sim.run 3 studies, 250 orders, 1775 steps in 1110 ms
10:44:47 ERROR provider simulationRunnerProvider: SqliteException(1555):
         UNIQUE constraint failed: simulation_run_lane_visits.run_id,
         .order_id, .node_id
         INSERT INTO simulation_run_lane_visits VALUES
           (e731efc0…, 1fc42625, 6db57ad3…, b96fc7c7…, 1762265827, 1762265827)
```

**The run computed and then could not be stored.** 1110 ms of work discarded, and all the screen said
was that it could not be completed.

**Reproduced three times in four minutes** — 10:43:26, 10:43:37 and 10:44:47 — always the same
constraint, always after a successful compute. It is deterministic, and putting position 4 back to
CEU30 cleared it immediately: 10:47:32 ran 1793 steps and stored with no error. **So the fixture for
this is one dropdown change**, which is as cheap as a reproduction gets.

The mechanism, off the schema rather than guessed: `project_queues` is keyed by **`target_id`** —
§7.3's *"a queue belongs to a station, not to a flow"* — and the failing `node_id` **is not a flow
node**, it is the lane's own id derived from the target. So two steps aimed at one station share one
queue, the same order enters that queue twice, and the key `(run_id, study_id, order_id, node_id)`
refuses the second visit. `entered_at == left_at == 1762265827` on the row that failed, which is
§8.1's zero-duration visit turning up in a third place.

**Revisiting a station is a real routing, not only a typo.** A part going back to the same machine
for a second operation is ordinary manufacturing, and the engine already models it correctly — it is
only persistence that cannot express it. So this is not closed by refusing the configuration.

**And it is the pattern §7.5's drive predicted.** That entry ended *"all three are §7.3's re-model
reaching a surface nobody re-read when it landed. The queue stopped being a study's in v19 and two
places went on asking it which study it belonged to. Worth a sweep for others."* This is one of the
others, found sixteen days later by driving rather than by sweeping.

**Settled by interview 2026-08-29 and landed as schema v23: a visit is keyed by the step it fed.**

The column called `node_id` never held a node. `engine.dart` writes `waiting.lane.targetId` into it
and has done since §7.3 moved the queue onto the station — `b96fc7c7`, the id in the failing insert,
is **CEU32**. So the key read as *"one order queues once per step"* and meant *"one order queues once
per station"*, and the name is most of why it stayed invisible for six rounds.

**The tell was the table next door.** `SimulationRunSteps` carries the identical key shape and
survives, because it is keyed by *where in the flow*. Lane visits were the odd one out, and v23
brings them into line: `node_id` becomes `target_id` (which is what it holds, and the Gantt still
groups bands by it), a `step_node_id` arrives, and the key becomes
`{run_id, order_id, step_node_id}`.

**The writer needed nothing new.** A visit is derived from a step row, and a step already carries
both ids. Only `SimOpenLaneVisit` — a stay the guard caught mid-flight, which produces no step —
gained a field, filled from `waiting.step.id`.

**The first table rebuild since v15.** Every migration since has been able to say *"no rebuild, the
shape §16.19 called safe"*; a primary key cannot be changed that way. It creates, copies, drops and
renames inside one transaction, so a failure leaves v22's table where it was. **Rows are backfilled
from the steps** on `(run, order, lane)` — the pair the writer derived them from — and a stay with no
step keeps the target as its surrogate, which collides with nothing because v22's own key already
guaranteed one such row per order per station. It means a pre-v23 run cannot say which step a stay
belonged to, which is true.

**Guarded on the columns the copy reads, not on the version.** A database from v19 or earlier had
this table created by that step's `_ensureTable`, which builds from the *current* definition — so it
arrives at v23 already in the new shape with nothing to migrate. `from` says where the counter
stopped, not what the file contains; the same lesson `_ensureColumn` was written for.

**Driven against the live database 2026-08-29 at 14:18:44** under **`0.1.0-2026-08-29a`**:
`db.open schema 23 from 22`, with the build label and the line both in `log.txt` — the pair §0 says
a stale link cannot produce. Backed up first as `flowmap.sqlite.backup-v22-20260829-141742`. The Aug-3
exe rule held again: `app.so` moved to 14:18 and `flowmap.exe` did not.

**The rebuild carried everything.** 117 866 lane-visit rows before and after, **112 runs unchanged**,
**zero duplicate keys**. 117 806 rows were backfilled from the step they were derived from and **60
fell back to the target** — stays the guard caught mid-wait, which produced no step to name, exactly
the case the column's doc describes.

**And it turned up something the interview did not predict: 31 480 rows whose `target_id` is a flow
node**, across **37 runs, all made 2026-08-15 and 16**. Those are pre-v19, from before §7.3 moved the
queue off the flow — back then a lane *was* a node and `node_id` was the right name for it. Nothing
was rewritten and nothing is wrong with the data; the rename is right from v19 on and those 37 runs
now carry a node id under a column called `target_id`. Recorded on the column rather than fixed,
because §7.10 forbids joining a finished run back to a plant, and it is the same shape as
`step_node_id`'s own caveat. **Every run since has zero.**

**Seven tests.** Three in `run_storage_test.dart` — the run stores at all, both stays survive named
by their steps, and the second stay begins no earlier than the first ended, which is what rules out
folding them into one row. **All three fail against v22's key**, with the same UNIQUE constraint the
drive hit. Four in `migration_test.dart` cover the backfill, the surrogate, a mixed table losing
nothing, and the upgraded table accepting the second stay v22 refused. `flutter analyze` clean,
**933 passing**.

### 8.7 The app has no language picker — **code-complete 2026-08-29, not driven**

**Found by driving, 2026-08-29**, when the es and pt checks were reached and could not be started:
*"i can't change the language."*

`MaterialApp.router` (`app.dart:14`) sets `localizationsDelegates` and `supportedLocales` and **no
`locale:`**, so the language is the platform's answer resolved against the supported list. The
Settings screen offers the **date format** and nothing else. **es and pt are shipped, translated, and
unreachable from inside the app** — reaching them means changing the Windows display language and
restarting.

**This is the reason every es/pt line in §0 has stayed open since 2026-08-15.** They were written as
checks and they are not performable; §0's *"es and pt, across the four round-one dialogs"*, §6.7's
*"the same paste in es and pt"*, §7.9's *"in all three languages"* and §12's Excel-locale item are
all blocked by one missing control. Recorded as blocked rather than skipped, because nobody chose to
skip them.

**A picker on the Settings screen, beside the date format**, and the choice stored the way
`dateFormatSettingProvider` stores its own. `DateStyleProvider` is already built *inside*
`MaterialApp` for exactly this reason — its own comment says the scope needs the locale and the
locale is only decided once `MaterialApp` has resolved it — so the seam this needs already exists.

_Not a translation job._ The three ARB files are complete and generated; this is the control that
selects between them.

**Landed 2026-08-29.** `AppLanguage` in `lib/src/common/app_language.dart`, stored under
`display.language` beside the date format, streamed by `languageSettingProvider`, and handed to
`MaterialApp` as `locale:`. **`AppLanguage.system` is the default and its `locale` is null**, which
is not a fallback but the thing the app did before: `MaterialApp` already knows how to match the
platform against `supportedLocales`, including the regions it does not carry, and a second answer
computed here could only disagree with the first.

**A language names itself.** `Español`, not `Spanish`, in every list and whatever the app is
currently drawn in — the reader who needs this control is the one who cannot read the screen it is
on. The three endonyms are identical in all three ARBs. `Follow the system` is a sentence rather
than a name, so it *is* translated.

**Twelve tests, and the seam is tested from both sides rather than through.** A live drift stream
inside a widget tree does not come apart when the test ends — `tearDown`'s `db.close()` waits on a
subscription the tree still holds, and every widget test after the first reports only that it "did
not complete". That is why `simulation_tab_test.dart` overrides providers rather than driving a
database, and this follows it: the repository group proves a choice is stored and streamed back, the
widget group proves a streamed choice moves every string in the tree.

**One gap, stated in the test file rather than papered over.** The widget group copies
`FlowMapApp`'s two lines instead of mounting it, because mounting the app needs the router and the
router needs the database. **Delete `locale:` from `app.dart` and those tests still pass.** Checked
by driving instead, in §8.8.

### 8.9 The Gantt reads the flow, not the load — **code-complete 2026-08-29, not driven**

**Found by driving §8.1's own fix**, the same afternoon it landed: *"now CEU30 is above TCN20 which
is incorrect."* 11D runs TCN20 at position 3 and CEU30 at 4.

**This is §10's predicted gap arriving, and it took one drive.** §8.1 removed the tie between CEU30
and CEU32 by deleting the phantom steps that caused it, and §10 recorded that the *tie-break*
survived — *"the next plant that ties will read wrong for the same reason."* It did, twice: replaying
the new run showed **CEU30 tied with TCN20 at rank 3, and BAN11 tied with CEU32 at 4**. The field
spotted one; the data had both.

**The cause was `min` over an index.** `routingRanks` took the earliest *position* a station reached
in any order's step list, which only works while every routing is the same length. A part that skips
two steps reaches its fourth station at index 1, so a station deep in one flow ties with a station
early in another — and the tie fell through to the Queue table's busiest-first order, which is a
statement about load standing in for a statement about sequence.

_Measured against the three studies' own flows on the live database:_ **`min` broke two of them,
`max` broke three, and a depth breaks none.**

**What it is now: a longest-path depth over the precedence the run observed.** Within one order the
steps are a sequence, so every consecutive pair says one station came before another — the only
statement about the flow a stored run actually contains. A station sits one below the deepest thing
that feeds it.

**A depth rather than a sequence, and that distinction is the whole design.** A topological
*sequence* numbers every station distinctly and would have silently taken the ordering of unrelated
stations away from the Queue table. A depth leaves them tied and says so, and
`buildGanttChart`'s existing clause hands a tie to the ranking exactly as it always did — which is
why the test pinning that behaviour passes untouched. On the live plant the surviving ties are
precisely the four cladding machines of one pool and the two CEU pairs that sit in parallel across
studies.

**Cyclic by design since §8.6.** A revisit makes W2 precede W3 and W3 precede W2; nothing can satisfy
both. The relaxation is capped at the station count, so a cycle settles at the depth of its longest
acyclic approach rather than climbing for ever.

**One existing test changed its expectation, and that needs saying plainly.** *"A station shared by
two studies takes its earliest position"* asserted `W1 W3 W2 W4` and its comment claimed the earliest
position *"keeps both routings readable downwards"*. It does not — study 1 runs W1 → W2 → W3, and
putting W3 above W2 makes that routing unreadable to buy nothing for study 2. **The expectation moved
on the field report and the flow-violation count, not to agree with the code**; §7.6 is the record of
what a suite that agrees with a wrong premise is worth. Two tests were added beside it: the deep/
shallow tie in the shape the drive found it, and a revisited station not stalling the ordering.

### 8.8 Drive it — **begun 2026-08-29 under `0.1.0-2026-08-29a` and `-29b`**

**Two builds, because the drive changed the code.** `-29a` at 14:18:44 carried §8.1–§8.7 and
`db.open schema 23 from 22` — the v23 migration meeting 112 real runs, recorded in §8.6. The drive of
it found §8.9, which `-29b` fixes; session 14:48:41, `db.open schema 23 from 23`, two runs at 1645
steps against the 1793 of the morning. **148 phantom steps gone** is §8.1 on the real plant.

_And an incidental reading on §8.5:_ **two presses of Simulate produced two `sim.run` lines** in the
14:48 session. It did not reproduce. Recorded because a defect that comes and goes is worth knowing
is intermittent rather than fixed — nothing in §8 touched it.

- [x] ~~**A part that skips a station.**~~ **Confirmed on the real plant 2026-08-29** under
      `0.1.0-2026-08-29b`, run `770ca007`, once the five-day takt was put back:

      | | CEU30 | CEU32 | steps |
      |---|---|---|---|
      | opened at 4 days | 94.0 h | 14.4 h | 9 |
      | opened at 5 days | **108.4 h** | **absent** | **8** |

      **108.4 h matches §7.9 to the decimal, and CEU32 is gone rather than zero.** §7.9 measured it
      at 0.0 — a stored phantom step; it is now not queued, not dispatched and not stored, and the
      order has eight steps where it had nine. The takt split came back with it: **37 orders at four
      days, 23 at five, none unopened.**

      _Original text:_ `P7000109738P01` is the case §7.9 found — **but only under
      the five-day takt**, and that period was deleted from 11D on 26 August and never put back. At
      four days it does 94.0 h at CEU30 and **14.4 h at CEU32**, so it visits both and correctly has
      both rows. _Driven 2026-08-29 and read as a defect on those figures, which was the check's
      fault rather than the app's._ **Restore the five-day period first** — 4 days to 2026-03-31,
      5 days from 2026-04-01 — or this check cannot pass.
- [x] ~~**CEU30 above CEU32 on Célula 11D's chart.**~~ **Confirmed 2026-08-29 under
      `0.1.0-2026-08-29b`**, on a fresh run — and it took two goes. §8.1 alone put CEU30 above
      **TCN20**, which the field reported; §8.9 is the fix, and the ordering on the newest stored run
      is now `TCN20 5 → CEU30 6 → CEU32 7 → BAN11 8` with **zero flow violations** against all three
      studies' own flows. **Two orderings were wrong and one was reported** — BAN11 sat above CEU32
      as well, and only replaying the run found it.
- [ ] **A capped lane with a skipping part in it.** `FIFO CEU27` at 2, which is the configuration
      §0's confounder ran. Blocking must fall or stay; if it rises, the skip is advancing an order
      somewhere it should not.
- [ ] **A fresh reference run, recorded with its label.** Every figure in `HISTORY.md` is now
      incomparable with anything measured after this round, for the fourth time.
- [ ] **The workcenter card at two periods and at twelve.** Short at two, 320 px and scrolling at
      twelve, and the append row reachable in both.
- [x] ~~**The headers *and the values*.**~~ **Confirmed 2026-08-29 under `0.1.0-2026-08-29b`.**
      §8.3 first centred only the headings, on the argument that a right edge is what lets a column
      of percentages be scanned; driven, the split read as a misalignment and the field asked for
      both. _Not separately reported: Demand and Takt, or the second theme_ — the grids that were
      never complained about and moved anyway.
- [x] ~~**TCN20 above CEU30, and CEU32 above BAN11**, on a fresh run of Célula 11D.~~ **Confirmed
      2026-08-29**, and corroborated against the stored run rather than only on screen.
- [ ] **Simulate pressed from each of the five study tabs**, and **`sim.run` counted in `log.txt`
      afterwards** — five presses, five lines, five new rows in `simulation_runs`. §8.5's defect was
      invisible on screen and obvious in the log, so the log is the check.
- [ ] **A run that cannot start** — unbind a step — pressed anyway if the button allows it. The
      banner must say so rather than repeating the last run's percentage.
- [ ] **A flow that visits one station twice**, which §8.6 is about. Point two steps of one study at
      the same workcenter and run it: it must store, and **the Gantt must draw both visits** — the
      half no test covers, since the chart groups lane bands by target and nobody has looked at what
      two stays of one order in one band do to the stack. The case is one edit away and was reached
      by accident once already.
- [ ] **v23 against the live database itself**, with the build label and the `db.open schema 23 from
      22` line both in `log.txt` — the pair §0 says a stale link cannot produce. **Back up first**:
      this is the first migration since v15 that rebuilds a table rather than adding a column, and
      the 105 stored runs go through it.
- [ ] **The language switched in the app**, which §8.7 makes possible for the first time. **And it
      is the check that stands in for a test**: §8.7's widget tests copy `app.dart`'s wiring rather
      than mounting it, so nothing in the suite would notice `locale:` going missing. Then
      **every es/pt check §0 could not perform**: the four round-one dialogs, the Schedules paste,
      the takt line on card and plan, and the Excel export's date cells. That is a block of work
      §0 has been carrying since 2026-08-15 without being able to start it.
- [x] ~~**A node dragged to the front, to the back, and dropped on itself.**~~ **Working, reported
      2026-08-29 under `0.1.0-2026-08-29b` — and reported as "a bit weird" before that, which was
      not pursued.** The likely cause is on record so nobody has to rediscover it:
      `pointerDragAnchorStrategy` with a centring offset makes the box jump to sit centred under the
      cursor at pickup, so grabbing it near an edge teleports it before it starts following. The
      default `childDragAnchorStrategy` would keep the grab point; the centring bought visibility of
      the gap being aimed at, which the caret and the `+` highlight already give. **One line if it
      grates again.**
- [ ] **The arrows, the lead-time ladder and the PDF agreeing with a dragged order**, which is the
      claim a derived layout makes and the half of §8.4 nobody has looked at.
- [ ] _(original)_ **A node dragged to the front, to the back, and dropped on itself.** And the arrows, the
      lead-time ladder and the PDF all agreeing with the new order afterwards, which is the claim a
      derived layout makes.
- [ ] **The snap reads as deliberate rather than as a jump.** The box does not stay where it is
      dropped — it cannot, since §5.3 derives every position from the sequence — so what has to be
      judged by eye is whether returning to the spine looks like the map settling or like the drag
      being rejected. **The one part of §8.4 a test cannot answer.**
- [ ] **A drag begun on a box reorders and a drag begun on canvas pans**, including a drag that
      starts on a box and travels across empty canvas.

---

## 9. Round nine — a process time belongs to a step — **code-complete 2026-08-29, not driven**

**Promoted out of §8 on 2026-08-29, before it was built.** It was found by driving §8.6 and started
as §8.10; writing the schema showed it reaching the demand repository, study duplication, the MM3
model, the summary and the assembler. **That is a round, and bolting it onto the tail of one already
driven is what §6.7 warns against** — a fix checked through a screen that moved for another reason
cannot say which of the two moved the figure. §8 stands as driven; this starts clean.

**Found by driving §8.6**, which is the point of driving it: *"I tried adding a CEU30 before TCN20
and the demand for each just copied the value for that CEU30 node, and it's linked. When I deleted
the process time, it deleted from both nodes."*

`demand_table.dart:43` keys a part's process time by the **target**:

```dart
String? demandTargetOf(FlowNode step) => step.poolId ?? step.workcenterId;
```

so two steps on one station are two columns over one stored value. Editing either edits both, and
the engine reads the same figure for both visits — **a revisit is charged identical work on each
pass**.

**This is a stated decision rather than an oversight**, and the entry that states it is worth
quoting because it is the thing to disagree with:

> *"Two nodes may share a `targetId` — a part that visits the same station twice — and then they
> are two columns over one stored value, which is right: the station takes the same time per piece
> on both passes, and a total that counts it twice is counting two real visits."*

**It is defensible and it is probably wrong.** It holds for a machine with one cycle time per part.
It does not hold for the usual reason a routing goes back to a station — the second pass is a
*different operation*: rough then finish, tack then final weld, first side then second. Those are
the cases a planner draws a revisit to model, and the model cannot currently tell them apart.

**§8.6's write-up was half right and this corrects it.** It said *"the engine already models it
correctly and only the save could not express it."* True of dispatch and queueing, which is where I
looked; false of the work, which is charged from a table keyed by station. **§8.6 made a revisit
storable and left it unable to say what the second visit costs.**

**And this is the third time one pattern has bitten.** §7.3 keyed the queue by station; §8.6's lane
visit was keyed by station; the demand column is keyed by station. Every one was right while a flow
was a spine of distinct stations, and every one breaks the first time a routing revisits one.
**Worth a sweep for the fourth** — §7.5's drive asked for that sweep sixteen days before §8.6 found
one by accident, and this is the next.

_The fork was whether a process time belongs to a **station** or to a **step** — a statement about
the plant rather than about the code, and the field's to make. It was made:_

### 9.1 Settled by interview, 2026-08-29

**A process time belongs to the step.** `part_process_times` is keyed by the flow node rather than by
the target, so two steps aiming at one station are two independent cells and a revisit can say what
its second pass costs.

**A pool still shares**, and the rule §3.1 cared about is untouched: a step targeting a pool is one
step, so its members go on drawing one time — *"a part has one process time at `CNC Lathes`, not
four."*

**Every step inherits its target's current time**, so today's numbers are the starting state and a
study that never revisits a station cannot tell the change happened.

### 9.2 Schema v24 — measured before it was written

Written, driven against the live database's *counts*, and then reverted with the round. The figures
below are from `flowmap.sqlite` on 2026-08-29 and are what the migration has to carry:

| | |
|---|---|
| `part_process_times` rows | **279** |
| reachable by a step | **271** |
| **orphaned — target has no step in that part's study** | **8** |
| rows after keying by node | **286** |

**The 8 orphans are dropped, and that has to be said out loud**: a time keyed by a node needs a node,
and these have none — left behind when a step was deleted or repointed after somebody typed a time.
They are already unreachable, drawn by no column and read by no run, but this is the only migration
in the file that removes anything.

**The extra 15 rows are the fix working**: 271 → 286 because a target used twice splits into two
cells, both starting at today's value.

**The join must be through the part's own study and restricted to `kind = 'step'`.** `demand_parts`
is study-scoped, so a time can only reach the steps of the flow it was typed against — which is what
makes keying by node lose no sharing at all. A queue or inventory node targets nothing and would
otherwise match on two nulls.

### 9.3 What it reaches, which is why it is a round

- **`demand_repository`** — `_toTimes`, `setProcessTime`, and `copyDemandInto`.
- **`studies_repository`** — **the piece that made this a round.** Duplicating a study inserts its
  nodes with `id: newId()` and keeps no old→new map, so copied process times would point at the
  *source* study's nodes. The map has to be built there and threaded into `copyDemandInto`.
- **`PartTimeWrite`**, and its two producers, `demand_import` and `demand_paste`.
- **`DemandTable`** — four lookup sites. `totalFor` already sums over columns rather than stored
  rows, so *"a station visited twice is paid for twice"* survives untouched.
- **`Mm3Step`** — carries a `targetId` and no node id, so the MM3 model gains a field.
- **`summary_view`** and **`sim_assembly`** — one site each; the assembler's `demandKey` becomes the
  node id.

**The compiler will not find most of these.** `DemandTable.times` is a `Map<String, Map<String,
Duration>>`, so a lookup by the wrong id compiles and returns null — a part silently uncosted rather
than a build failure. **Every site has to be visited deliberately**, and the readiness panel is the
check that would notice: a part with no time at a step it must visit is a blocking error (§11).

### 9.4 What landed

**Code-complete 2026-08-29. `flutter analyze` clean, 940 passing** where there were 935.

Everything §9.3 predicted it would reach, it reached — and **one thing it did not**, which is the
entry worth reading:

**`summary_view` was multiplying, not summing.** A target's work was `one stored time × the number
of steps that point at it`, which is exactly right while the two visits share a value and exactly
wrong the moment they can differ. It sums the visits now. **Nothing in the analyzer could have found
it** and no test named it either — the fixture that caught it was a summary test whose two passes
happened to be over one station, and it failed by reading zero rather than by reading wrong.

**A part is reported uncosted if *any* of its visits has no time**, not only when all of them do. A
second pass nobody has typed a figure for is §11's blocking error just as much as a first, and the
hours are an understatement until it is filled in.

**`Mm3Step` carries both ids and uses each for its own question**: the time is read by the node, the
work is summed by the station. Two visits to one machine add up on its MM3 column rather than
competing for it.

**The compiler found seven files and missed four.** `demand_repository`, `studies_repository`,
`PartTimeWrite`, `ProcessTimeEdit`, `demand_import`, `demand_paste` and `Mm3Step` all failed to
build. `DemandTable`'s four call sites, `demand_tab`'s cell reader, `summary_view`'s aggregation and
`mm3`'s two lookups did not — they take untyped map keys, so they compiled and returned null. **Every
one of those four was found by a test failing, not by the analyzer**, which is what §9.3 warned and
is the reason to keep that warning where it is.

_Tests:_ four for the migration — the backfill, a station used twice becoming two cells at one value,
the 8-row drop, and the new key holding two different figures. Plus `demand_repository_test` now
builds real steps for its times to belong to, and the study-duplication test asserts the copy's times
key by the **copy's** nodes rather than by two literals.

### 9.6 A revisit made the row order cyclic — **fixed 2026-08-29**

**Found by driving §9**, and it is §8.9's own fix meeting the case §8.6 created. A revisit makes the
precedence graph genuinely cyclic — 11D runs `CEU30 → TCN20 → CEU30`, so each comes before the
other — and relaxing a longest path over a cycle does not settle. It climbed to the pass cap and took
everything the loop reached with it: **`END:36  TCN20:36  BAN11:37`**, with five routings out of
order where the acyclic version had none.

§8.9's doc claimed *"a cycle settles at the depth of its longest acyclic approach"*. It did not; the
code never removed the cycle. **A depth-first walk drops the edges that close one**, and the levels
are computed on what is left — one edge dropped on the live plant, and 11B and 11C came out exactly
right.

**Which visit a revisited station is drawn at is a choice, not a fact.** It gets one row, and
`CEU30 → TCN20 → CEU30` says it belongs both above and below. The walk settles it deterministically
and stably, but no position honours both visits — **listed in §11 so the field can say which it would
rather read.**

_A test pins the part that is not a matter of taste:_ everything downstream of the loop keeps its
order. It fails against the cyclic version.

### 9.7 A blank process time is a zero — **settled by the field 2026-08-29**

**Friction §9 caused, and the field's answer to it.** Giving 11D a second visit to CEU30 left fifteen
parts with an empty cell there, and an empty cell stopped the order dead — so each had to be told, one
at a time, that it cost `00:00:00`. *"In the demand process time it requires the workcenters with no
time to be filled with 00:00:00. Correct that — if it is empty consider 0."*

**What the two used to mean, and why it was drawn that way:**

| | before | now |
|---|---|---|
| blank | `engine.dart:757` never admitted the order — it never completed, and the guard reported it | the part skips that station |
| zero | §8.1 skips the station | unchanged |

`demand_table.dart` stated the rule outright — *"a blank means 'not routed here' and costs nothing, a
zero means 'takes no time' and is almost always a typo"* — and §11 called a part with no time at a
step it must visit **the one intolerable bug**. That is what has been traded away, and it was put to
the field in those terms before it was changed.

**The cost, written down rather than discovered later: a forgotten cell is now indistinguishable from
a deliberate skip.** The run completes, the station never sees the part, and every figure downstream
is short by whatever should have been there. Nothing reports it. `TargetOccupation.partsWithoutTimes`
is the only figure that would show it and it is now information rather than a fault — **it is worth
knowing that it is the last thing standing between a mistyped flow and a plausible wrong answer.**

_Narrower than it looked:_ `isFullyCosted` and `missingCells` are defined and used nowhere in `lib`,
so the readiness panel never blocked on this. The engine's null branch was the whole of the
enforcement, and one condition carried it.

_The test that pinned the old rule is kept rather than deleted_, rewritten to pin the new one and to
say in its own words what it costs.

### 9.8 The balance cap allows for rework — **code-complete 2026-08-29, not driven**

**Found by the field reading a Gantt**, while asking why an order sat four days in a station:
*"the balancing should consider the rework and other times, otherwise the balancing will always be
over the takt time."* It does, and it was.

**The balance filled each station to one takt of its capacity using _measured_ work**, and the engine
then charged `measured × (1 + rework) ÷ availability` in the station's open clock:

    cap     = O·a·T                    what the balance filled to
    charged = (O·a·T) × (1+r) ÷ a  =  O·T·(1+r)
    open in one takt               =  O·T

**Availability cancels; rework does not.** Every balanced station was over its takt by exactly
`(1 + rework)` — not sometimes, always, on every station with any rework at all. Measured on the live
plant at two availabilities, **CLAD06 at 1.00 and CEU27 at 0.83**, and the overshoot was 1.037 in
both, which is the rework and nothing else.

_On order #1 of 11D:_ the cap was 91.1 h, the derived share 90.6 h, and the run charged **94.0 h**
against 91.1 h of open time in one four-day takt. The field's original ask was *"topping the first
workcenter at the takt time"* — it was topped at the takt divided by 1.037.

**The fix is one divisor at the two places the cap is built**, and `takt_balance.dart` itself is
unchanged: callers pass `productive × takt ÷ (1 + rework)`, each member dividing by its own.

**The flow equivalent is untouched, deliberately.** It is MM3's yardstick — `mm3.dart` divides
*measured* part times by it — and the ladder's divisor, and `FlowStepView.rework` already says in its
own doc that rework *"is a loss on the work a part requires, so it is applied to that part's process
time and never to the yardstick."* Folding rework into it would shift every equivalence figure for a
reason that has nothing to do with MM3. **Two figures 3.7 % apart that look alike**, and both docs now
say why.

**Changeover is deliberately not reserved.** Whether an order pays one is sequence-dependent and the
split is computed per part, per takt, with no sequence in view. Reserving the full setup
over-reserves every repeat; reserving none is exact whenever the part does not change. On this plant
the only balanced member carrying a setup carries **one minute** — CEU26. Recorded so the omission is
a decision rather than the next thing somebody finds.

**What a reader sees:** the step dialog's balance caption, which already explains why a station is
*not* rebalanced, now says what a balanced one filled to — *"Filled to 87.9 h of 91.1 h — 3.7 %
rework means that much content uses one whole takt."* The process box is unchanged; §2.5 and §6.4
each spent a round taking rows off it.

**It moves work onto the last member of each group.** CLAD06 fills to 87.9 instead of 90.6, so CLAD25
gains 2.7 h. That is correct — the overflow is real work and the last station is where §7.4 puts it —
but it is worth knowing the fix loads the last machine rather than relieving it.

**Every stored run is invalidated**, the fifth time. Landed inside §9 rather than as a round of its
own because §9 has not been driven either, so there is no measured baseline to protect and the two
cost one invalidation between them.

_Five tests_, including the two that carry the claim: a station filled to the cap is charged exactly
one takt, at availability 1.00 **and** at 0.83. Plus one pinning that a station with no rework
balances byte for byte as before.

### 9.9 The map read its times by station — **fixed 2026-08-29**

**Found by driving §9, and it is §9.3's own warning coming true in the one file §9.3 did not list.**
*"When I select a part number in the flow view or anything other than the equivalent it says there
is no process time for that part even if there is."* Every process box under **Single part** and
**Weighted variants** showed a dash and raised `StepProblem.noProcessTime`, on studies whose demand
grid was plainly showing the times.

`flow_view.dart` looked its cells up by `node.poolId ?? node.workcenterId`. **§9.3 predicted exactly
this failure** — *"a lookup by the wrong id compiles and returns null"* — listed the sites it would
reach, and the flow map was not among them. Only `FlowDataSource.flowEquivalent` looked healthy, and
only because it reads no demand at all.

**`sim_assembly._paceSetter` had it too**, and silently: it summed each step's work by target id,
found zero everywhere, and handed every study its first candidate step as pacemaker. No error, no
dash — a cadence taken from the wrong place. It matters less than it looks on this plant because all
three studies name their pacemaker, so `_chosenPaceSetter` wins and the derivation never runs; a
study that leaves it unset was getting position order rather than work content.

**The engine itself was correct throughout** — `demandKey: node.id` since the round landed — so no
run ever charged the wrong figure. This was the map and the choice of pacemaker, not the work.

_Why the suite said nothing:_ the flow fixtures keyed their `FlowDemandInput` by `'CLAD04'`,
`'CEU30'`, `'SHORT'` — they encoded the old key, so they matched the old lookup and passed. Rekeyed
to node ids; the pool test now asserts the step's own cell beats both the pool's key and a member's;
and one new test covers the shape a station-keyed lookup cannot express at all — **one workcenter
visited twice, 40 h on the first pass and 15 h on the second**.

**That is the fourth time this pattern has bitten**, which is the count §9's own header asked to be
watched for: §7.3's queue, §8.6's lane visit, §9's demand column, and now the map. The sweep it
asked for is still owed.

### 9.10 The release slot opened on the wrong clock — **§7.2 defect, fixed 2026-08-29**

**Not §9's, but found by explaining a queue §9 made legible**, and the more expensive of the two.
*"Why is CLAD06 forming a queue, because I'm not understanding why."*

`releaseInterval` was resolved against the pace setter's **productive** day and then spent with
`WorkingCalendar.advance`, which consumes **open** time. The two differ by exactly the availability,
so every takt came round early by that factor:

| | |
|---|---|
| release interval, 11D | 4 × TCN20's productive day = **271,564 s** → 3.33 working days |
| CLAD06 filled to one takt | **326,399 s** of open clock → 4.00 working days |
| deficit, every order | **54,835 s = 15 h 13 min** = `271,564 × (1/0.832 − 1)` |

**Nothing absorbs it, because §7.4 fills the first station of a like-machine group to exactly one
takt.** CLAD06 is critically loaded by construction, so the deficit had nowhere to go: 59 orders
stacked it into a **55-day queue**, with CLAD06 at 100 % across its whole active window and CLAD17,
last in its own group, at 22 %. The field found the same number from the other end — the 15 h
between the first order's start and the second order's arrival — before the ratio was worked out.

**§7.2 has always said a 3-day takt is three *working* days apart.** The open day is the figure that
makes it so, and it is carried separately on `SimResourceContext` now rather than derived, because
dividing by an availability the context does not hold is how the two came to be confused. Work
content still reads the productive day: §6.1's equivalent, §9.8's balance cap, a setup given in days,
and the pace setter derivation — a station's *busyness* is a question about work and not about the
clock, and a new test pins that half.

_The test that held the old behaviour was named_ **"a takt in days is that many productive days of
the pace-setter"** _and passed a fixture whose open and productive days were equal_ — so the
distinction it existed to pin could not be seen. It states both now.

**Every stored run is invalidated, the sixth time**, and this one moves every delivery date rather
than only the figures: releases come 20 % further apart. **Confirmed against the live plant** — the
re-run matches.

**Two things it does not fix**, and they are the reason CLAD06 is still worth a look:

- **CLAD06 now sits at exactly ρ = 1.0**, not below it. The interval equals its per-order occupancy
  to the second, so the queue stops growing and has no slack at all — one calendar exception or one
  staffing change and it accumulates again.
- **§7.4 concentrates the load on the *first* member of a group.** 11D needs 163 h of cladding per
  order against 228.5 h across the three stations — the work fits comfortably; the fill order is what
  pins CLAD06 at 100 % while CLAD17 idles. **Put to the field on 2026-08-29 with the numbers and
  declined** — see §11's last entry. The 100 % is the plant, not a defect.

### 9.11 The sweep for the fifth — **done 2026-08-29, nothing found**

§9's header asked for it, §7.5's drive asked for it sixteen days earlier, and §9.9 was the fourth
instance — so it was owed. **Every remaining place a value is keyed by target was read, and every one
of them is asking a station-level question.** No fifth.

| site | keyed by target because |
|---|---|
| `engine._queued`, `_hasRoom`, `SimQueue` | a floor space belongs to the station (§7.3, §5.5) |
| `summary_view.occupationByTarget` | both visits load one machine; summed since §9.4 |
| `gantt_layout.groupOf`, the row ranks | one row per station — §9.6 settled which visit it sits at |
| `Mm3Step.targetId` | read by node, summed by station (§9.4) |
| `theoreticalLeadTime`'s `counted` set | one stock charge per target however many steps feed it |
| `_demandTakt`'s `firstWhere` | reads capacity and the working day, both station-level |

**The write paths are all on node ids** — `demand_import`, `demand_paste`, `demand_tab`'s cell
reader, and `studies_repository`, which builds the old→new node map §9.3 predicted it would need.

_Two things the sweep turned up that are not defects and are worth knowing:_

- **An import cannot fill both visits of a revisited station.** `guessMapping` matches by heading and
  marks a source column taken, so a file carrying one `CEU30` column maps the first visit and leaves
  the second **unmapped and listed for the user** — safe, nothing silently duplicated, but a revisit
  is un-importable until its steps carry distinct labels. `flowStepTitle` prefers the step's own
  label, so naming them *CEU30 rough* and *CEU30 finish* is the whole fix. **§9 made revisits
  first-class and the import is the one surface that cannot yet express one**, which the field will
  meet the first time it pastes a routing with a second pass.
- **`TargetOccupation.title` takes the first visit's title**, so a Summary row for a station reached
  by two differently-labelled steps is named after whichever comes first. Cosmetic, listed rather
  than fixed.

_And one figure that now answers a different question than its name suggests:_ the Summary's
**configured takt** is resolved in productive hours, consistent with the `raw` and `adjusted` figures
beside it, which are productive too. Since §9.10 that is no longer the interval the engine releases
at — the two differ by the availability, and someone will compare them. The panel is a load
comparison and is right as it stands; **the name is what will mislead**, and §10.1 is where a
sentence about it would go.

### 9.5 Drive it

**Four of these were closed against the stored run rather than the screen**, on 2026-08-29 — the kind
of evidence §7.9 used and this file asked to see more of. Run `93994701`, made at 19:32 under the
build carrying §9.9's fix. What is left needs a person and a screen.

- [x] **A balanced station charged exactly one takt** (§9.8) — **verified to the second, on four
      stations.** Every station the balance fills reads `326,399 s` against a four-day takt of open
      time of `326,400 s`: CEU27 in 11B, CLAD06 and CEU30 in 11D. 11C is on a two-day takt and CEU21
      reads `163,199 s` against `163,200 s`. **The overshoot §9.8 was written to remove is gone and
      the residue is one second of rounding.**
- [x] **v24 against the live database** — met it at **16:00:57 on 2026-08-29** under
      **`0.1.0-2026-08-29c`**, `db.open schema 24 from 23`, with `flowmap.sqlite.backup-v23-20260829-160002`
      taken 55 seconds before. **No row is orphaned by node id now**, which is the migration's own
      postcondition and the thing worth checking rather than the drop count.
- [x] **The row count, which did not land where §9.2 predicted** — 267 rows, not 286, and that is
      not a defect. Every step's coverage accounts for it exactly: 11B 7 steps × 8 parts, 11C 8 × 10,
      11D 131 cells over eleven steps. The prediction was measured before the flow it counted had
      changed, and §9.7 then made a deleted cell a legitimate answer rather than a hole. **A
      prediction taken against a moving plant expires**, which is the lesson rather than the number.
- [x] **The readiness panel after the migration** — moot as written, and worth saying why. §9.7
      settled that a blank is a skip, so a missing cell is no longer a fault to report; and §9.4
      recorded that `isFullyCosted` and `missingCells` are used nowhere in `lib`. There is no panel
      state left for this to be clean *in*.
- [ ] **The balance caption on a station with rework**, in all three languages — the string is new
      and carries four placeholders. **Still owed; nothing in a stored run can answer it.**
- [ ] **A study with a station twice, two different times typed** — **still unexercised, and the
      leftover is still in place.** 11D carries an extra **CEU30 at position 4** with **zero stored
      times and zero visits in the run**. Under §9.7 it is inert rather than wrong, but it is the
      only thing making 11D's flow cyclic — `CEU30 → TCN20 → CEU30` is §9.6's whole subject — so it
      is both the leftover to remove *and* the only revisit the plant currently has to test with.
      **Decide which before deleting it**: take it out and §9.6's fix has nothing live to stand on;
      leave it and 11D's map carries a step no part visits.
- [ ] **A duplicated study**, whose process times point at its own nodes rather than at the
      original's. The failure would be silent. **No study on the live plant has been duplicated since
      the migration**, so there is nothing stored to read this off — it needs the app.
- [ ] **Nine of 11C's ten parts store `00:00:00` at TCN20**, and one of 11D's eight at TCN20 does
      too. Residue of §9.7's friction or a real routing — behaviourally identical since §8.1 skips a
      zero, so nothing is wrong today, but **only the field can say which they meant** and a zero
      that meant "I had to type something" is a trap for the next reader.

---

## 10. Round ten — Project Settings, and what a run says about load over time

Settled by interview 2026-08-29. §10.1 comes first because §10.4's thresholds have nowhere else to
live; §10.2 comes before §10.3 and §10.4 because neither can be built against a run that does not carry
what they read. **Runs made before §8.1 must not be graphed** — they contain the phantom visits that
round removes.

### 10.1 Project Settings becomes a destination

A project owns a name, a plant, a shift pattern, notes and its calendar exceptions — and after §10.4
it owns the float thresholds too. **Every one of those is edited in a dialog launched from the
Projects list** (`projects_screen.dart:235`), so there is no project-level surface inside the
workspace at all, and the exceptions button sits at the bottom of the studies sidebar
(`project_workspace_screen.dart:587`) because there was nowhere better to put it.

A gear in the workspace app bar opens **Project Settings**: a destination and not a dialog, holding
the fields, §10.4's thresholds, and Calendar Exceptions as a section. That mirrors §4.2's Study
Settings one level up, and it keeps §12.1's reason for exceptions being a destination in the first
place — a calendar is browsed, not filled in and dismissed.

`_ProjectDialog` stays for **create** and loses **edit**. Two write paths into one table is how the
two come to disagree, which is the argument `station_cards.dart:31` already makes about the dialog
§6.3 deleted.

### 10.2 Schema v25 — what a run must store to be graphed

**v25**, settled by interview 2026-08-29 and moved up once when §9 took v24: §8.6 needed a migration of its own and §8
is driven before §9 moves the ground under it. Carrying §9's columns in §8's migration would have
committed the live database to a design nothing had written yet — the shape this file already warns
about twice, where an entry over-specified its own cost before the code around it was read.

Three columns, one migration. Each is a copy-in, because §7.10 forbids joining a finished run back
to a plant that may have been retuned since — the rule `processSeconds` already states in its own
doc: *"Recomputing it on read is not open to us."*

| column | table | why |
|---|---|---|
| work **before** rework | `SimulationRunSteps` | `processSeconds` is `per-piece × batch × (1 + rework) ÷ availability` — already fused, so rework cannot be its own segment without it |
| open seconds **per month** | new, per run × station × month | only a whole-run `openSeconds` exists, so a monthly capacity line has no denominator |
| workcenter type id and name | `SimulationRunWorkcenters` | `Workcenters.typeId` is in the plant and is not copied in, so §10.3's type filter and its pivot columns cannot be read off a run |

The monthly open seconds also close, **for this metric only**, something `run_filter.dart:9` states
as a standing limitation: *"a station's busy, open and blocked time keep describing the whole run."*

Runs made before v25 graph nothing, the way pre-v18 runs group nothing.

### 10.3 The occupation graph — demand against capacity

Project-scoped, filtered by cell, line, workcenter type and workcenter, on top of the study and
customer-project filters `RunFilter` already carries.

- **x** — months, `Mmm/yyyy`. **y** — hours.
- **bar**, stacked: process, rework, changeover. The three sum to `required`, which is what the
  Summary's occupation is a ratio of — a bar omitting changeover would draw a station under its line
  while the Summary read 96 %, and §7.6 is the record of what a surface agreeing with itself and
  disagreeing with its own metric costs.
- **line** — capacity, from §10.2's stored monthly open seconds.
- **bucket** — `queueStart`, the month the work **arrived** at the step. Not `processStart`: work
  the engine scheduled can never much exceed capacity, because it would not have been scheduled
  otherwise, so bucketing by execution hides the overload that caused it. Five orders arriving with
  500 h against a 400 h month is **125 %**, and the bar is meant to break the line.
- `queueStart` is set when the order reaches the step, so an empty queue simply gives
  `queueStart == processStart` and `wait == 0`. No special case.

**A filter colours the bar; it never shrinks it.** BAN11 is shared by 11B, 11C and 11D. Filtered to
Célula 11B its own demand is 300 h against 400 h — 75 %, under the line — while the three lines
together ask 550 h. Demand outside the filter therefore stays in the stack as a fourth, neutral
segment, so the bar total is always the station's true load and **an overload cannot be filtered
away**. The capacity line does not move under a filter and is never pro-rated: a denominator
computed from another line's demand is not a number the plant has.

Unfiltered, the chart aggregates every matching station and carries a per-month count of how many
individual stations are over. The sum answers a real question about plant hours and headcount, and
the badge is what stops it being read as occupation — §8.1's ranking is where a bottleneck is found.

**Beneath it, a pivot**, over the visible span rather than per month:

```
  Cell        Line        Cladding  Mach-HBM  Mach-TCN  Deburring   Total
  ------------------------------------------------------------------------
              Fluxo 11B      75%       60%       48%        31%       71%
  Célula 11   Fluxo 11C      40%       28%       22%        19%       35%
              Fluxo 11D      22%        —        18%        14%       18%
  ------------------------------------------------------------------------
  TOTAL                     137%       88%       88%        64%      119%
```

Rows are Cell → Line with the cell merged; columns are workcenter **type**, which is defensible in a
way summing unlike stations is not — `takt_balance.dart` already treats *"workcenters of the same
type in the sequence"* as one balanceable group. A cell holds **that line's own demand** over the
type's full capacity, so with every line in view the column total is the sum of its cells.

**The TOTAL row counts every line touching those stations, filtered out or not**, which is the same
rule as the chart's neutral segment. Under a filter the column will therefore *not* equal the sum of
the cells above it — that is the point rather than a defect, because it is the only place the
contention still appears once a cell reads its own 75 %.

### 10.4 The float matrix

Float is one `Duration` per order today (`sim_result.dart:143`), slack against the need date,
positive is early. The matrix is orders down, months across:

```
  Order #   jan/27   fev/27   mar/27   abr/27   mai/27   jun/27
  -------------------------------------------------------------
     1        17       53       53       56      -20       54
     2        -1       26       29       -9       54       57
     3        60      -16       40       55       36       11
     4        40       13        8       51      -14       38
     5       -15       -2       43       37       58       46
     6        55       18                21       17        4
     7        38                          12                -8
```

- **column** — the month of the order's **need date**. Not the delivered date: an order due in March
  and shipped in April would change column between runs, and §12's run comparison is the one thing
  that cannot survive that.
- **row** — its rank among that month's orders by need date, earliest first. Not the demand
  `sequence`, which `gantt_layout.dart` and §8.5's plan already use for a global 1-based order
  number — the same `#3` would otherwise name two different orders.
- **cell** — float in days. Blank where a month has fewer orders.
- **colour** — red at or below the lower threshold, amber between, green at or above the upper.
  Defaults `0` and `30` days, **set per project** on §10.1's screen.

§0 is why this earns its place: on-time was **60/60 in all four** confounder runs because the 30-day
start buffer swamped the differences, so *"on-time cannot currently discriminate between these
configurations and lead time is doing all the work."* A month-by-month float matrix is that
statement made readable — the plant that is green in January and red in April.

### 10.5 Drive it

- [ ] **The graph against the Summary tab**, on one station, one month. The bar's three segments
      must total what the Summary calls `required`, and the ratio to the line must be the number the
      Summary's occupation column shows for the same span. **This is the §7.6 check**, made
      deliberately rather than discovered three sections later.
- [ ] **A shared station, filtered and unfiltered.** BAN11 under no filter and under Célula 11B: the
      capacity line in the same place both times, the neutral segment carrying the difference, and
      the pivot's TOTAL row unchanged by the filter while the cells above it change.
- [ ] **The pivot's column totals adding up** with every line in view, and deliberately **not**
      adding up under a filter. The one check here whose failure would be silent.
- [ ] **A pre-v25 run opened from the history picker** offering no graph rather than an empty one,
      and **a pre-§8.1 run not being graphed at all** — its phantom visits are in its lane visits.
- [ ] **The float matrix's thresholds edited on Project Settings** and the colours moving, in a
      month with orders on both sides of a boundary. And the matrix at 24 columns, which is where
      §12.6's right-edge problem shows up again.
- [ ] **Exceptions reached through the gear**, and the sidebar button gone. Plus every field
      `_ProjectDialog` used to edit, now edited here and only here.
- [ ] **es and pt**, on the pivot's headers and the graph's legend — four segment names and three
      threshold bands are the longest new strings since §3.4.

**DESIGN.md this round:** §8.1 (the pivot, and why a type groups where a sum would not), §8.3
(occupation gains a time axis and a stated bucket), §8.4, §11.1, §12.1 (Project Settings as a
destination), §12.6, §16.26 (schema v25).

---

## 11. Known gaps, deliberately left

- [ ] **§14's performance target is not met.** A 2000-order, 10-step run takes ~2.8 s against "well
      under a second". §16.9 has the measurements: the cost is local `DateTime` arithmetic on
      Windows (~13 µs per construction, versus 0.03 µs for the UTC equivalent). Closing it means
      working in epoch integers inside `WorkingCalendar` and converting only at its edges — a real
      refactor of the most heavily tested code in the app. Worth doing deliberately.
- [ ] **The result tables build every row.** A `DataTable` is not lazy, so §12.6's 360 px pane on a
      §14-scale 2000-order plan constructs 2000 rows to show seven. It sits behind the item above,
      because the run that would produce 2000 orders does not finish in time either. Closing it
      means the read-only twin of `DataGrid`: a heading row over a `ListView.builder`, which is the
      structure the grid already uses. **§3 makes two more tables grids**, which narrows this rather
      than closing it.
- [x] ~~**§7.4 fills the first member of a group and could level it instead.**~~ **Put to the field
      on 2026-08-29 and declined — fill-first stands.** Found while explaining §9.10's queue: CLAD06
      sits at exactly one takt on every order and so at 100 % occupation across its whole active
      window, while CLAD17 — last in the same group — runs at 33 %. Levelling was costed against the
      live plant and would have moved CLAD06 to 89 % and CLAD17 to 43 %, work conserved:

      | | fill-first | levelled |
      |---|---|---|
      | CLAD06 | 4,407 h — **100 %** | 3,938 h — 89 % |
      | CLAD25 | 3,926 h — 89 % | 3,938 h — 89 % |
      | CLAD17 | 1,445 h — 33 % | 1,902 h — 43 % |

      **The rule is a description of the plant, not a simplification of it**, and the field's original
      words stand: *"topping the first workcenter at the takt time and leaving the rest, under or
      over, to the last workcenter of the same type in the sequence."* Recorded here so the next
      reader who notices a station pinned at 100 % finds the answer rather than the question — **it
      is the model working, and CLAD17's 33 % is where the slack is meant to be.** The three
      levelling variants that were costed (proportional to each member's capacity, equal split, and
      keeping both behind a per-study setting) are not carried forward; if this is ever reopened they
      are cheap to re-derive and the numbers above are the baseline to beat.
- [x] ~~**§18.3 is still open**: takt changes mid-flight.~~ **Settled by decision 2026-08-17, not
      deferred again** (§7.7): *"changing a takt mid-run is impractical in reality"* — a line does not
      re-cadence halfway through a batch of work. **A run is a single-takt experiment**, resolved at
      its start by the second assembly pass (§16.10), and a takt change is studied by running it
      twice and reading the Gantt, the occupation and the queue indicators against each other. What
      §7.7 owes is not a mechanism but three captions: the run must **say** which takt it ran at, and
      both the run and the map must say when a change falls inside the span they are showing.

      **Corrected 2026-08-27 (§7.9): the decision stands and the sentence above misstates it.** *"A
      run is a single-takt experiment"* was read out of *"changing a takt mid-run is impractical"*,
      and the two are different claims. What is impractical is re-cadencing work **already in
      flight**; an order keeps the takt it opened under all the way down the plant. Successive orders
      take the takt in force when *they* open, which is what a takt period says and what the engine
      has never done.
- [x] ~~**A tie in `routingRanks` is broken by load, not by flow.**~~ **Closed by §8.9 on
      2026-08-29**, one drive after it was written. The prediction held exactly: *"the next plant
      that ties will read wrong for the same reason."* Original text: Two stations at one routing
      position fall through to the Queue table's busiest-first ranking (`gantt_layout.dart`'s
      `groupQueue` clause). For a pool's like machines that is right — they are interchangeable. For
      two stations that genuinely sit at one position it is a statement about load standing in for a
      statement about sequence. Found by replaying §8.1's fix against `7669856d` on 2026-08-29;
      **§8.1 removes the tie in the case that was reported and does not remove the tie-break**, so
      the next plant that ties will read wrong for the same reason. What it needs is the study's own
      node sequence, which the run stores per step as `node_id` and which `routingRanks` does not
      look at.
- [ ] **A forgotten process time is now invisible** (§9.7). A blank and a deliberate skip are one
      thing to the engine since 2026-08-29, so a cell nobody typed takes a station out of a part's
      routing and the run completes looking fine. The field weighed that against typing `00:00:00`
      into fifteen cells and chose; **what has no answer yet is how a mistyped flow would ever be
      caught.** `partsWithoutTimes` on the Summary is the only figure that shows it.
- [ ] **Which visit a revisited station is drawn at.** It gets one row, and a routing that runs
      `CEU30 → TCN20 → CEU30` puts it both above and below TCN20 — no single position honours both
      (§9.6). The walk settles it deterministically; nobody has said which reading a planner wants.
      **The first visit is where §8.9 assumed a reader looks**, and that assumption has never been
      put to anyone.
- [ ] **§18.5 is still open**: empty slots as a reported metric. They are counted, dated, stored and
      shown; what is missing is a decision about whether a list of *which* slots is wanted, and
      whether an empty slot should ever be a warning.
- [ ] **A genuine process delay has no home.** Cooling, curing and transport really do take their
      time whether or not the next station is free, and §2.12 removed the only mechanism that
      expressed it — a 24 h cooling rack is modelled as free. It needs a per-node switch saying
      which of the two kinds a buffer is. Recorded in §5.5; the day a plant has one is the day to
      add it.
- [ ] **The decorative layer (§5.2)** and **`DiagnosticsLog.compose`** are still built-but-unreachable,
      both wanted by M5. Listed in §17.5. §1.7's node notes deliberately do **not** use the
      decorative layer: a free-placed sticker near a box is not a note belonging to it.

---

## 12. Deferred by decision — the map that never runs

**§3.8, deferred 2026-08-11 and confirmed still deferred 2026-08-15.** Not dropped and not disagreed
with — sequenced. The argument below stands as written and nothing about it needs revisiting when it
is picked up.

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

**§4.2's Study Settings tab is where its flag will go**, which is one thing this round buys it for
free.

_Also parked with it: the supermarket._ Asked for alongside §3.1's four disciplines and not the same
mechanism — a supermarket **decouples**, downstream withdraws from stock rather than waiting for a
specific order, and the withdrawal authorises upstream to replace it. It needs stock levels, a
replenishment trigger and stockout metrics, and it changes what an order *is* through a buffer. Its
own round. §5.2 keeps it decorative until then.

---

## 13. M5

Reports (§13), run comparison, templates and binding (§10.2), the About screen, and the drop.

Run comparison has what it needs: two `StoredRun`s report through the same `summariseRun`, so the
figures on either side cannot have been computed two different ways. §1.3's stored dispatch
overrides are what lets a comparison say the dispatch is what differed — and §1.4's
`changeover_seconds` extends that to the setup rule.

The Production Plan already exports (§13.1). What is left is the *report* PDF §13 reserves — input
snapshot, metrics, bottleneck ranking, late-order list — which the plan's `.xlsx` was deliberately
kept from pre-empting.
