# FlowMap — what is next

Working state as of 2026-08-18. This file is **only unstarted work**, and each item should be
deleted from it as it lands. `docs/DESIGN.md` is the source of truth for *why*; `docs/HISTORY.md`
is the source of truth for *what already happened* — the finished rounds, the run identifiers, the
migration timestamps and the backup filenames.

Branch `m1-m2-foundation`, `flutter analyze` clean, **880 tests passing** (one of them `live`-tagged
and skipped without a database). Schema is at **v22**; the live database is at **v21** and v22 has
met a copy of it — `integrity_check` ok, 250 orders, 100 runs, 104,463 run steps, backed up first as
`flowmap.sqlite.backup-v21-20260827-215250`. v20 met the live file at 21:59 and v21 at 22:34 on
2026-08-18, both under `dev` builds, both confirmed from `log.txt` rather than from anything written
down at the time. **None of §7.3's tail, §7.4 or §7.6 needed a migration** — the flow's two ends
found their columns already there, and §7.4 turned out to store nothing at all. **§7 is
code-complete again, §7.9 included** — the takt had never once reached a run and now does.
**892 tests, and §7.9 has not been driven at all.** M4 is code-complete, and the initial plan has no code left in it —
§3.8 is deferred by decision and everything else in it has landed.

**Two entries in a row over-specified their own cost**, which is worth watching for: §7.3's flow-ends
stock called itself "a schema step (v20)" when the columns already existed, and §7.4 said "what is
stored is the group's measured total" when the sum of cells the demand table already holds *is* that
total. Both were written before the code around them was read.

**The one thing to know before starting anything: almost nothing here has been looked at.** §5, §6,
§7 and §7.6 are all code-complete and covered by tests, and **nothing in the suite renders a pixel**
(§2.7). The last drive — `0.1.0-2026-08-16d`, half an hour of one person clicking — found **three
defects that 765 tests had nothing to say about**, all of them §7.3's re-model reaching a surface
nobody re-read. That is the ratio to plan around: driving is not a formality after the work, it is
where the defects are. §5.3, §7.5 and §7.6 are the three open drive lists.

**And §7.6 is the sharper version of the same lesson**, because it was found by reading rather than
by clicking: Lead Time Efficiency had shipped **upside down**, and it survived because three sections
of `DESIGN.md` described the reciprocal and all agreed with each other. **A suite that agrees with a
wrong premise is not evidence.** §7.6 is the round that fixed it and the four things it reached.

**Latest build is `0.1.0-2026-08-16e`.** Every stored run predates the v19 engine change, so
replaying one from the history picker shows per-node lanes rather than one queue per target. **Only
a fresh run exercises what §7.3 built.**

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
| **§5** | The pool and the lane | two bugs from the field — **written, not driven** |
| **§6** | The workspace | five tabs, one simulation, less chrome — **not driven** |
| **§7** | The queue, the filter and the balance | from driving `0.1.0-2026-08-15g` |
| **§8** | Known gaps, deliberately left | |
| **§9** | Deferred by decision | §3.8, the map that never runs |
| **§10** | M5 | |

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

It is also the obvious home for §9's map-only flag when that lands.

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
| **§7.9** | The takt belongs to the order | the takt had never reached a run — **code-complete 2026-08-27, v22 met a copy of the real database, undriven** |

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

### 7.9 The takt belongs to the order — **code-complete 2026-08-27, not driven**

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
**guess about what the planner meant** — §9.2's rule is that forgiving is not guessing, which is why
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

#### Drive it — **nothing below has been looked at**

Both rounds are written, so the two lists below are one sitting. §2.0's rule was to drive between
them and it was not kept: round two followed round one the same evening. **What that costs is
stated rather than hidden** — a figure that comes out wrong on the Gantt cannot say whether the
engine placed it there or the card is reading the wrong column, and the first list is what tells
those apart.

#### The engine

- [ ] **11D across 1 April.** Two orders of one part, one released either side, must carry different
      work on the hover card. For `P1000216567-13P01`: **76.1 / 117.9** at CLAD06 / CLAD25 before,
      **95.2 / 98.8** after; **75.4 / 162.6** at CEU30 / CEU32 before, **94.3 / 143.7** after. The
      after-April figures must equal what the map draws with its viewed period in H2.
- [ ] **The cadence visibly changes** — releases every 75.4 h before, 94.3 h after, read off the
      Gantt. This is the half a work figure cannot show.
- [ ] **11B and 11C come out identical to `67f5d7f2`.** One takt period each, so nothing may move —
      the cheapest proof the change is confined to lines that actually have a takt change.
- [ ] **A part that empties a station.** `P7000109738P01` at 5 days gives CEU30 the pair's whole 87 h
      and CEU32 **zero**. That is §6.2.1 working as specified and it must read as a finding on
      screen, not as a bug.

#### The surfaces

- [ ] **The card's takt line against the plan's column**, on the same order, in all three languages.
- [ ] **The menu tells two runs apart** — one at 4 days, one spanning to 5, sitting in the picker as
      `4 days` and `4 → 5 days`.
- [ ] **A takt table cut short on purpose**, so releases stop: the run header must name the study,
      the date and how many orders never opened, and the Gantt must not merely look jammed.
- [ ] **The plan at fifteen columns**, on screen and in Excel — Float is the column most likely to
      have gone off the right edge (§12.6).
- [ ] **The card at 204 px**, on the bottom row and at the right-hand edge, which are the two places
      it has to be pushed back inside. It has grown twice in ten days and nobody has looked at it.
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

## 8. Known gaps, deliberately left

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

## 9. Deferred by decision — the map that never runs

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

## 10. M5

Reports (§13), run comparison, templates and binding (§10.2), the About screen, and the drop.

Run comparison has what it needs: two `StoredRun`s report through the same `summariseRun`, so the
figures on either side cannot have been computed two different ways. §1.3's stored dispatch
overrides are what lets a comparison say the dispatch is what differed — and §1.4's
`changeover_seconds` extends that to the setup rule.

The Production Plan already exports (§13.1). What is left is the *report* PDF §13 reserves — input
snapshot, metrics, bottleneck ranking, late-order list — which the plan's `.xlsx` was deliberately
kept from pre-empting.
