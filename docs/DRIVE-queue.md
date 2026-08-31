# Phase 1 — the drive sheet, 2026-08-30

The one thing phase 1 still owed. The migration was already provable from the live database
(`19813d6`, `live_db_check_test.dart`); this is the half that is not — what the process boxes
actually draw, which the suite renders no pixel of.

`docs/TODO.md` phase 1 is the source. Fold the result back into it and delete this file.

## Session header

```
build label   0.1.0-2026-08-30a
db.open line  21:20:45 db.open schema 27 from 27
session start 2026-08-30 21:20:45
host          Desktop / windows 10.0 build 26200 / locale en_US
```

| | |
|---|---|
| branch / HEAD | `v2.0` @ `d6edfbe`, tree clean |
| `flutter analyze` | **clean** |
| tests | **997 passing** |
| schema, live database | **v27** |
| backup | `flowmap.sqlite.backup-v26-20260830-171232` (149 MB), taken before the migration |

**`schema 27 from 27` — no migration ran this session.** It landed at 17:14 in an earlier session,
whose route log shows settings, a study and the simulation twice and **never the Flow tab**. So the
process boxes had genuinely not been looked at before this sitting.

Rebuilt deliberately for a labelled header, per §5.3's rule: a drive with no label recorded is not
a weaker record of a drive, it is not a record that a drive happened.

## What the fifteen queues should caption

Read off `project_queues` before driving, so the screen was checked against something written down
rather than against memory. **8 typed, 7 untyped — exactly the split #5 predicted.**

```
FIFO · CEU26     FIFO · CLAD06    Queue · BAN11    Queue · CEU27
FIFO · CEU30     FIFO · CLAD17    Queue · CEU21    Queue · Coating
FIFO · CEU32     FIFO · CLAD25    Queue · CEU22    Queue · END
FIFO · TTAT      FIFO · CLAD Pool - Célula 11B/C   Queue · TCN20
```

## The checks

1. **The seven `Queue ·` lanes over their push arrows.** BAN11, CEU21, CEU22, CEU27, Coating, END,
   TCN20 — the ones that printed `FIFO CEU27` over a striped arrow, the map contradicting itself.
   The arrow must not have changed; only the word.
2. **`FIFO · CLAD Pool - Célula 11B/C` in a 140 pt box.** The longest caption in the set. It must
   ellipsise on one line, not wrap, and the middot has to be findable as the app's separator
   against the hyphen inside the pool's own name. This is the call `19813d6` made against #5's
   hyphen; if it does not read, that call was wrong.
3. **The step dialog's single queue section**, headed by the caption the box draws — so choosing a
   type visibly renames the queue and the dialog cannot disagree with the map. *Push* is *Queue* in
   the dropdown, and the shared-queue line names the target.
4. **The Gantt's lane rows, stored run against fresh.** Not in the owed list, added here because it
   is the §7.10 claim nothing else can show.

## Driven 2026-08-30 under `0.1.0-2026-08-30a`, session 21:20:45, `db.open schema 27 from 27`

**Reported correct for the group after a simulation was run.** Recorded as a group result and not
itemised, which §5.3 is the standing warning about — the four checks above were not each confirmed
aloud one at a time. What follows is what the database independently confirms, which is the part
of this sheet that does not rest on that.

### 4 — the Gantt, and what the database says about it

**Read first against a stored run, and the captions had not changed.** That is `gantt_view.dart:355`
working as written: it draws `lane.name` when the stored run carries one and derives only when it is
null, and **all 147 runs then in the database carried one** — the newest from 09:48, before phase 1
landed at 17:08. §7.10, doing exactly what it says.

So the frozen strings are the mangled ones. Those runs' Gantts say `FIFO BAN`, `FIFO CEU 21`,
`FIFO CLAD` where the map now says `Queue · BAN11`, `Queue · CEU21`,
`FIFO · CLAD Pool - Célula 11B/C`. **The disagreement phase 1 removed from the map is still on all
147 stored runs' Gantts and will be permanently.** Left standing: §7.10 is the reason, and nobody
decided otherwise here.

**A simulation was then run, and it is what settles the check.** Run `e0d93a45`, 21:26, 148 runs
now stored: **`name` is NULL on all 15 lanes**, so the derive path is live and the caption a new run
draws is re-derived in the reader's language rather than frozen at save time. That is `19813d6`'s
one deliberate deviation from #5 — #5 asked for the caption to be written in — and this run is the
first evidence it works.

### The finding: an untyped lane is stored as FIFO

**Recorded, not actioned.** Run `e0d93a45` stores `rule = fifo` on **all 15** lanes, including the
seven `project_queues` holds as null — BAN11, CEU21, CEU22, CEU27, Coating, END, TCN20.

`simulation_repository.dart:129` loads a queue as `rule: row.rule ?? DispatchRule.fifo`. The null is
erased there, at the boundary into the sim model, and `SimQueue.rule` is non-nullable and documents
itself as defaulting to FIFO because that is what a shop floor does — **correct for the engine.**
`simulation_runs_repository.dart:440` then copies that value into the run. So a stored run cannot
tell *someone chose FIFO* from *nobody chose anything*, and the live database showed this before
phase 1 existed: the 09:48 run stores fifo on all 15 while the project holds 8 and 7.

It was harmless while `SimLane.rule` was write-only. **Phase 1 made it load-bearing** — the caption
is now derived from it — so those seven lanes derive `FIFO · CEU27` on the Gantt while the map draws
`Queue · CEU27`. §5.5's *null is not FIFO* holds on the map and is lost on the run.

The fix is to make `SimQueue.rule` nullable and apply the FIFO default where the engine sorts rather
than where the project loads, which is what §5.5 already says. **Phase 2 rewrites that comparator**,
so it is the phase that should carry this.
