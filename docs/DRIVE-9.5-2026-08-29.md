# §9.5 — the drive sheet, 2026-08-29

Three checks left on round nine. `docs/TODO.md` §9.5 is the source; four of its items are already
closed against the stored run and are not repeated here. **Tick here, fold the result back into
`TODO.md`, delete this file.**

Everything below is *prepared* — the figures each check should read are computed from the live
database ahead of time, so a check is a comparison rather than an investigation. Where a figure
depends on plant settings the formula is given beside it, because the settings moved twice while
this sheet was being written.

---

## Before anything: the build label

**The two builds made earlier today went out without one and log `build dev`.** §5.3's rule, quoted
on the §0 sheet, is the reason this matters: *a drive with no label recorded is not a weaker record
of a drive; it is not a record that a drive happened.*

```
flutter build windows --release --dart-define=BUILD_LABEL=0.1.0-2026-08-29e
```

**Already done** — `flowmap.exe` and `data/app.so` at 2026-08-29, built from `c3cad3d`. The running
instance is still the unlabelled one, so **restart the app before driving** and confirm the header
reads `build 0.1.0-2026-08-29e`.

_This also qualifies something already written into `TODO.md` §9.5._ The four items closed there were
closed by arithmetic on run `93994701`, which is sound as arithmetic — the numbers are what they are
— but that run was made under `dev`. **They are verified, not driven.** The re-run below carries a
label and supersedes it.

## Baseline

| | |
|---|---|
| `flutter analyze` | clean |
| tests | **948 passing**, one `live`-tagged skip |
| schema, live database | **v24**, met at 16:00:57 under `0.1.0-2026-08-29c` |
| HEAD | `c3cad3d`; last commit touching `lib/` is `bbc0e14` |
| backup to take first | `flowmap.sqlite.backup-v24-<date>-<time>`, beside the live file |

## What the database says, so nothing is contrived twice

Three studies on one project, each on its own line takt, each naming its pacemaker explicitly — so
`_chosenPaceSetter` wins and §9.9's fix to the derivation does not show here.

| study | takt | pacemaker | parts | orders | steps |
|---|---|---|---|---|---|
| Célula 11B | 4 days | CEU27 | 8 | 60 | 7 |
| Célula 11C | 2 days | CEU21 | 10 | 130 | 8 |
| Célula 11D | 4 days | TCN20 | 15 | 60 | 11 |

**11D holds both balance groups worth driving**: `CLAD06 → CLAD25 → CLAD17` (three adjacent
*Cladding* stations) and `CEU30 → CEU32` (two adjacent *Machining - HBM*). Its extra CEU30 at
position 4 is dealt with in check 2.

> **The plant moved twice while this was written.** CLAD06, CLAD17 and CLAD25 were edited between
> 19:25 and 19:29, and **CEU32's availability was set to 1.000 at 20:09:10** — every other station on
> the plant is 0.832 or 0.840. All figures below are computed *after* those edits. **If a caption
> disagrees, check `workcenter_schedule_periods.updated_at` before suspecting the code**; that is the
> cheaper of the two explanations and it has already been the right one once today.
>
> **CEU32 at 1.000 is a deliberate experiment, confirmed by the field, and may go back to 0.832.**
> Only its *capacity* moves with it — `open × availability × takt`, so **90.7 h at 1.000 and 75.4 h
> at 0.832**. The `filled` figure is unchanged either way, because CEU32 is the last member of its
> group and takes the remainder rather than a fill: what it holds is set by CEU30's cap, and CEU30
> was not edited. Both values are given at the row that needs them.
>
> _It is also the station the experiment is about._ CEU32 carried the largest queue in run
> `93994701` — a median wait of 1,855 h against CLAD06's 667 — at 94.4 % utilisation over the whole
> run, and it is the one station whose availability was the obvious lever.

---

## Check 1 — the balance caption on a station with rework, in three languages

`stepRebalanceOnWithRework`, four placeholders, present in `app_en.arb`, `app_es.arb` and
`app_pt.arb`. It is reached from the step dialog's rebalance switch, and **only under a real data
source** — under the flow equivalent nothing is balanced (§7.4's fixed point), so the plain
`stepRebalanceOn` shows instead.

**Where:** 11D → Flow tab → *Showing* = a part number → open a process box → the rebalance switch's
caption.

`filled` is the box's own *Process time* row and `capacity` is its *Takt C/T* row, so **the caption
is checkable against the two figures directly above it** without leaving the screen.

| part | station | the caption should read |
|---|---|---|
| P1000216567-13P01 | CLAD06 | Filled to **73.5 h** of **76.2 h** — **3.7 %** rework |
| | CLAD25 | Filled to **73.5 h** of **76.2 h** — 3.7 % |
| | CLAD17 | Filled to **57.1 h** of **76.2 h** — 3.7 % |
| | CEU30 | Filled to **72.8 h** of **75.4 h** — 3.7 % |
| | CEU32 | Filled to **165.2 h** of **90.7 h** at availability 1.000, or **of 75.4 h** at 0.832 — see the check below |
| P1000220321-06P01 | CLAD17 | Filled to **60.1 h** of **76.2 h** — 3.7 % |
| P1000228848-02P01 | CLAD17 | Filled to **76.1 h** of **76.2 h** — 3.7 % |

CEU30 differs from the cladding stations because its availability is 0.832 against their 0.840 —
`capacity = open × availability × takt`, `open = 22:40`.

**The check that makes the sentence true:** `filled × 1.037 ≈ capacity` on every row above. That is
the whole claim §9.8 makes, said in words.

- [ ] **en** — one station, sentence correct, figures match the two rows above it.
- [ ] **es** — *"Llenada hasta 73,5 h de 76,2 h: con un 3,7 % de retrabajo…"*. **Watch the decimal
      separator**: the figures are formatted by `_hours`, which writes a point in every locale.
- [ ] **pt** — *"Preenchida até 73,5 h de 76,2 h: com 3,7 % de retrabalho…"*, same caveat.
- [ ] **The last member of a group, which is the one this sentence was not written for.** On
      P1000216567-13P01 CEU32 is predicted to read **"Filled to 165.2 h of 90.7 h"** (or *of 75.4 h*
      if its availability has gone back to 0.832) — the remainder,
      not a fill. The sentence then claims that 165.2 h *"uses one whole takt"*, which is false: it is
      two takts and a bit, and it is the group being over capacity rather than a station being full.
      **Read it on screen and decide what it should say instead** — §7.4 is explicit that the last
      station is *"the one allowed to be under or over"*, so the standing is right and only the words
      are wrong. Likely a fourth caption beside `balanced`, not a change to the split.

## Check 2 — a station visited twice, and check 3 — a duplicated study

**These are one sitting, because the cheapest way to get a safe revisit is to make the copy first.**

11D carries an extra **CEU30 at position 4** with **no process times and no visits in any run**. It
is inert under §9.7 — a step no part is costed at is a step every part skips — but it is also the
only revisit on the plant, and `CEU30 → TCN20 → CEU30` is the whole subject of §9.6. So it is at once
the leftover to remove and the only fixture to test with.

**The order that gets both:**

1. **Duplicate Célula 11D.** Name the copy something disposable — *11D revisit test*.
2. **On the copy**, label both CEU30 steps distinctly — *CEU30 rough* at position 4 and *CEU30
   finish* at position 6. `flowStepTitle` prefers a step's own label, so this is also what makes the
   two demand columns tell each other apart.
3. **On the copy**, type two different times at the two CEU30 columns for two or three parts — say
   **20 h** at *rough* and the part's existing figure at *finish*.
4. **On the original 11D**, delete the extra CEU30 at position 4. §9.5 has asked for this since the
   round landed and it must happen before any real run of 11D.
5. **Run.**

- [ ] **The copy's process times point at the copy's own nodes.** This is check 3, and its failure is
      silent — the copy would read uncosted on every box and every part. §9.3 named it *"the piece
      that made this a round"*: `studies_repository` inserts nodes with fresh ids and had to build an
      old→new map to carry the times across.
      **Read it on the Flow tab of the copy**: pick a part, and every box must show the same figures
      the original shows for that part. A dash anywhere means the map was not built.
- [ ] **The copy's demand grid has two CEU30 columns with different headings**, and typing in one
      does not change the other. That is the original field report — *"the demand for each just
      copied the value for that CEU30 node, and it's linked"* — checked on the shape that produced it.
- [ ] **The run charges each pass its own time.** With 20 h at *rough* the two CEU30 rows on the Gantt
      must differ, and the Summary's CEU30 row must **sum** the two visits rather than doubling one
      (§9.4's `summary_view` fix, which no test named until a fixture failed by reading zero).
- [ ] **The row order stays settled** (§9.6). `CEU30 → TCN20 → CEU30` is genuinely cyclic; the walk
      drops the closing edge and everything downstream of the loop keeps its order. **END, BAN11 and
      Coating must sit below TCN20**, not at the pass cap where the cyclic version put them.
- [ ] **11D itself is clean afterwards** — ten steps, no CEU30 at position 4, and its figures moved
      by nothing at all, because the step it lost was one no part was costed at.
- [ ] **An import into the copy is expected to fill only one of the two CEU30 columns** if they are
      *not* labelled — `guessMapping` marks a source column taken and leaves the second unmapped and
      listed. Worth seeing once, since it is the one surface §9 left unable to express a revisit
      (§9.11). With the labels from step 2 it should map both.

---

## What to record

The session header, verbatim, before anything is ticked:

```
build label   0.1.0-2026-08-29e
db.open line  <hh:mm:ss> db.open schema 24 from 24
session start 2026-08-29 <hh:mm:ss>
host          Desktop / windows 10.0 build 26200 / locale <locale>
```

And the run id of the labelled re-run, which supersedes `93994701` as §9.5's evidence.

_Afterwards_, these are answerable from the database rather than the screen and will be checked
against it: that the copy's `part_process_times` rows all resolve to the copy's own `flow_nodes`
and none to 11D's; that 11D has ten steps; that the two CEU30 nodes on the copy hold different
values for the parts edited; and that every balance-filled station is still charged exactly one takt
of open time — `326,400 s` on a 4-day takt at CLAD06's calendar, `163,200 s` on 11C's two-day one.
