# FlowMap — what is next

Working state as of 2026-08-15. This file is **only unstarted work**, and each item should be
deleted from it as it lands. `docs/DESIGN.md` is the source of truth for *why*; `docs/HISTORY.md`
is the source of truth for *what already happened* — the finished rounds, the run identifiers, the
migration timestamps and the backup filenames.

Branch `m1-m2-foundation`, `flutter analyze` clean, **729 tests passing** (one of them `live`-tagged
and skipped without a database). Schema is at **v18**. M4 is code-complete, and the initial plan has
no code left in it — §3.8 is deferred by decision and everything else in it has landed.

**§5 is written and not yet driven**, which is the one thing this file's working state does not
usually describe. The tree is not clean: v18 and the Gantt's lane bands are in it, covered by tests
and unseen by a human. §5.3 is what closes that, and §6 does not start until it has.

**§1–§4 have landed and are kept here rather than deleted**, against this file's own rule, because
`HISTORY.md` stops at the 2026-08-11 feedback round and has not absorbed them yet. They are the only
record of rounds one to four; moving them across is owed and is listed in §0.

**§1–§4 came out of driving the build and were about the map, not the engine.** The pull is
towards using FlowMap as a thing you draw a value stream in and read numbers off — so the work is
the process box's fields, the figures under the map, how fast the input tables can be typed into,
and where the simulation lives now that it is no longer the point of every screen. Settled by
interview on 2026-08-15 before any of it was written.

**They were four rounds with a hand-driven pass between them**, and a pass before the first one.
That is §2.0's rule; `HISTORY.md`'s §16.11 is the record of what ignoring it costs, and **§5 and §6
keep it**: the interview settled them as one round driven at the end, and they were split again once
§5 was written, so the bug fix can be checked against the screens that reported it before §6 moves
those screens.

**Round one invalidates every stored run.** Availability comes off setup and cold start starts
paying one, so no figure recorded in `HISTORY.md` is comparable with anything measured after it.
This is the third time — §2.12 and §3.1 were the others — and it is why §0 comes first: those checks
are only worth making while the engine still agrees with the numbers that raised them.

| | | |
|---|---|---|
| **§0** | Clear the debt | no code — drive what is owed |
| **§1** | Schema v17 and the engine | setup, teardown, what a run records |
| **§2** | The flow surface | the step dialog, three lead times, `Part`, less text |
| **§3** | The input tables | takt and workcenter schedules become grids |
| **§4** | The tabs, and where simulation lives | seven tabs, a simulation workspace |
| **§5** | The pool and the lane | two bugs from the field — **written, awaiting a drive** |
| **§6** | The workspace | five tabs, one simulation, less chrome |
| **§7** | Known gaps, deliberately left | |
| **§8** | Deferred by decision | §3.8, the map that never runs |
| **§9** | M5 | |

---

## 0. Clear the debt first — no code

Everything here is a check on something already shipped, and everything here is cheaper now than
after §1, because after §1 the engine no longer produces the figures that raised the question.
Hours, not days.

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
- [ ] **The date format, set on Settings.** Check the demand grid re-parses what it renders after
      the format changes — that is the pair §3.6 exists to keep together — and that the Gantt's axis
      still reads `Jan 14` rather than a numeric date. §3 makes both those tables grids too, so a
      parser that is wrong here is wrong in three more places afterwards.
- [ ] **The plan in Excel, opened in Excel.** §13.1 is asserted by decoding the file back, which
      proves the cells are typed but says nothing about how Excel *renders* them: a date column
      whose default format is `45 872` and a duration reading `1.2500000000` are both technically
      correct and both unusable. Export the célula 11B plan, open it, check the dates read as the
      chosen format, that Order Start shows its time, and that sorting Float puts the late orders
      where a planner expects. In es and pt as well — a locale decides how Excel itself formats a
      date cell.
- [ ] **The results banner.** That it pushes the tabs down rather than covering the Gantt's last
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
- [ ] **The readiness panel against a real gap.** It has only ever been seen clean. Unbind a step or
      clear a takt period and check it names the study and disables Simulate. What is covered
      underneath it is `SimRunInput.canRun`, eight ways in `simulation_repository_test.dart`; what
      has never been seen is the wiring — a real edit, through the providers, to a non-empty problem
      list on screen.
- [ ] **The Gantt's round-two geometry, in `0.1.0-2026-08-11c`.** The overlap fix changed every
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
- [ ] **es and pt**, across the four round-one dialogs, which carry the longest help text in the
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
- [ ] **Rounds one to four go to `HISTORY.md`.** That file's last entry is the 2026-08-11 feedback
      round; §1–§4 landed on 2026-08-15 and are recorded nowhere else, which is why they are still
      in this file in defiance of its own contract. Until they move, `TODO.md` is carrying two jobs
      and neither file can be trusted to answer *what already happened*.

_Parked, not owed: **the pool fix against célula 11B.** The CLAD Pool of three reads 63 %
occupation and a flow equivalent of 0.99, which is the right shape; comparing it against what it
read before the fix needs a build that no longer exists. Recorded rather than chased._

---

## 1. Schema v17, and what a changeover is — round one

The schema lands once and the rest sits on top of it (§2.0). One migration carries all of it.

**Every stored run is invalidated by §1.2 and §1.3.** Re-run célula 11B before reading any figure
against anything, and do it after §0 rather than before.

### 1.1 Setup and teardown replace changeover

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

### 1.2 `days` means a productive day, and availability comes off setup

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

### 1.3 Cold start pays a setup

`engine.dart:796` returns zero when `lastPartId` is null, on the reading that the plant is handed
over already set for what it is about to run. An empty station at the start of a run is set up for
nothing, so **the first order pays in full** — and the rule collapses to one sentence with no
special case: *no previous order counts as not the same part.*

One extra setup per station per run, so runs get marginally longer. On the same commit as §1.2, so
it is one re-run rather than two.

### 1.4 The run records the changeover it charged

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

### 1.5 The run carries its studies' cell and line

§4.4's combined view filters by cell and production line, and **the run cannot answer that today**.
`Studies` carries `productionCellId` and `productionLineId`; `SimulationRunStudies` copies neither,
and §7.10 forbids joining to the live study.

**Four nullable columns on `simulation_run_studies`** — cell id and name, line id and name — copied
in at save time, exactly as v12 copied `customer_project` and v13 `part_description`. Blank on all
35 existing runs. Purely additive with no `TableMigration` trap: nothing rebuilds that table.

**Worth knowing before it is built: a cell or line filter is a *study* filter one level up.**
Workcenters belong to a **plant**, not to a cell or a line, so stations cannot be filtered that way
at all. The filter narrows which studies are in view, and the stations follow from them.

### 1.6 The migration, and what it needs

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

### 1.7 Drive it — **done 2026-08-15**

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

### 1.7b Drive it — the original list

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

## 2. The flow surface — round two

Nothing here touches the engine or the schema. It is what is under the map and what is typed into a
box.

### 2.1 The step dialog

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

### 2.2 Working days and running days

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

### 2.3 The summary bar carries seven figures

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

### 2.4 `Timeline` becomes `Part`

`app_en.arb:411` has `"flowDataSource": "Timeline"`, which labels the picker choosing between the
flow equivalent, one part, and all variants weighted by the demand mix. It is simply the wrong word
and always has been.

**`Part` is the accurate one, not a convenient approximation.** §6.1 defines the flow equivalent as
*"a **dummy part** whose process time at each step equals one takt of that workcenter's own
capacity"* — so all three options are parts: one real, one synthetic, one weighted blend. Three
languages, one key.

### 2.5 The help text comes down

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

### 2.6 The date format becomes a dropdown

Field feedback, same session. `settings_screen.dart:79` renders four `RadioListTile`s, each with the
format as its title and today's date in that format as its subtitle — which is most of the screen for
one setting with four values.

**A `DropdownButtonFormField`, with the sample carried into each item** — `DD/MM/YYYY —
15/08/2026` — so the preview that made the radio list worth reading survives the collapse, including
in the closed state where it describes the current choice. `settingsDateFormatHelp` becomes an
info-icon tooltip under §2.5's rule: it defines what `Locale` means, which the label does not.

### 2.7 Drive it

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

## 3. The input tables — round three

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

### 3.1 Both tables become grids, and both dialogs go

- A new period is **a blank row appended at the bottom**, the way the sequence grid works. Delete
  stays a row action.
- **The edit dialogs are removed entirely.** Keeping one would leave two write paths into one
  table, which is how the two halves of a rule drift apart.
- **Overlaps and gaps stay non-blocking.** `ScheduleIssuesBanner`, fed by `findSchedulePeriodIssues`,
  is **already on both tabs** — the guard exists and the dialog was duplicating it. §11's readiness
  already blocks Simulate on a real gap, which is the check that matters.
- The `Shifts` column on the workcenter table is derived by counting (§4.2) and stays `readOnly`,
  which `DataGridColumn` already supports.

### 3.2 What a cell accepts

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

### 3.3 Drive it

Paste a block of takt periods out of Excel. Type a date in the wrong format and check the error is
on the cell rather than silent. Create a gap and check the banner says so without blocking. In es
and pt, since the unit parser is the one thing here that is language-shaped.

**DESIGN.md this round:** **§9.1** (the grid is no longer only the demand tables), **§12.5** (two
fewer read-only tables — and the takt table was the one deliberately stretching to fill, so that
paragraph needs revisiting rather than deleting), **§12.6**, and the schedules sections that
currently describe a dialog.

---

## 4. The tabs, and where simulation lives — round four

### 4.1 Seven study tabs

`Flow · Study Settings · Flow Takt · Workcenters · Demand · Summary · Simulation`

`Takt` becomes `Flow Takt`, `Study Settings` is new (§4.2), and `Simulation` stops being the
project-level tab and becomes this study's slice (§4.3).

### 4.2 Study Settings

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

It is also the obvious home for §8's map-only flag when that lands.

### 4.3 The Simulation tab becomes the study's slice

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

### 4.4 The simulation workspace

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

### 4.5 The Gantt filters its rows

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

### 4.6 Drive it

The workspace screen **has no test coverage at all** (§3.7), and this round rebuilds it — so
everything here is only covered by pressing it. Specifically: that the study tab's figures equal the
combined view's for the same study; that a period filter changes the order counts and leaves
utilisation labelled and whole; that a cell filter on a pre-v17 run shows blanks rather than
dropping every study; that Simulate works from both places and reports the same disabled reason.

**DESIGN.md this round:** **§8.6** (the Gantt's row filter), **§12.1** (rewritten — seven tabs, the sidebar destination, two triggers
for one run), **§7.3** and **§7.7** (the cap and the priority are reachable, and what a study's
slice is), **§7.10** (the cell and line the run carries), **§10.1**, **§17.5** (two entries closed).

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
- [ ] **The heading reads as a heading**, not as a fourth machine — 18 px against the stations' 30,
      the primary colour in the frozen label column, no band fill, and nothing hovers on it.
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
picker on the blank append row that §9.1's "type into the row past the end" rule needs.

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

## 7. Known gaps, deliberately left

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
- [ ] **§18.3 is still open**: takt changes mid-flight. A run keeps one release cadence throughout,
      resolved at its start by the second assembly pass (§16.10).
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

## 8. Deferred by decision — the map that never runs

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

## 9. M5

Reports (§13), run comparison, templates and binding (§10.2), the About screen, and the drop.

Run comparison has what it needs: two `StoredRun`s report through the same `summariseRun`, so the
figures on either side cannot have been computed two different ways. §1.3's stored dispatch
overrides are what lets a comparison say the dispatch is what differed — and §1.4's
`changeover_seconds` extends that to the setup rule.

The Production Plan already exports (§13.1). What is left is the *report* PDF §13 reserves — input
snapshot, metrics, bottleneck ranking, late-order list — which the plan's `.xlsx` was deliberately
kept from pre-empting.
