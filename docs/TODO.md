# FlowMap — what is next

**Fresh start, 2026-08-30.** Everything that stood here before — every phase, every numbered
section from §0 to §9, every unstarted item carried forward since 2026-08-15 — has been scrapped
by decision. It is not lost: the last version is at the **`v1.0`** tag
(`git show v1.0:docs/TODO.md`), and `docs/HISTORY.md` still holds what actually happened while
`docs/DESIGN.md` still holds why. Both remain authoritative.

What was scrapped was the *forward* plan only. The shipped app is **Version 1.0**, tagged at
`0d32838`, and is not touched again.

## Version 2.1

Work happens on branch **`v2.1`**.

The plan below is the output of the wayfinder map
**[FlowMap v2.1 — a build the plant installs, and a study that travels](https://github.com/matheus-sancha/FlowMap/issues/21)**,
whose last ticket was
[What are v2.1's phases, and in what order?](https://github.com/matheus-sancha/FlowMap/issues/36).
Every phase below is the *summary*; the ticket linked beside it holds the reasoning, the rejected
alternatives and the live-database evidence, and is what a session building that phase should read
first. Nothing here restates a decision — it points at the one place each lives.

**Version 2.0 is complete and closed.** Its section below stays as the record. Its map closed with
sections 5–7 of `docs/DRIVE-2026-09-07.md` **abandoned rather than deferred**, including one defect
confirmed by reading; nothing from that sheet is inherited here.

### How a phase works

Unchanged from v2.0, and worth restating because the audience changed:

- **Shippable and drivable on its own.** A phase ends with the suite green, `flutter analyze` clean,
  and the evidence that phase owes recorded.
- **Its strings land in all three locales.** `app_en.arb`, `app_es.arb`, `app_pt.arb` and a
  `flutter gen-l10n`, in the same commit as the code. `l10n_test.dart` asserts
  `lib/src/l10n/untranslated.json` is empty, so a phase cannot ship English-only without failing the
  build.
- **Migrations are one per phase and never combined.** v2.1 has **two** — v31 in phase 1, v32 in
  phase 2 — and they are one apiece, which is why the stamp sits alone in phase 1.
- **One word: `workcenter`.** *Station* is retired (`DESIGN.md` §3.0). A study is written
  `name (cell · line)` wherever it stands beside a cell or a line.

### The phases

| # | Phase | Schema | Tickets | |
|---|---|---|---|---|
| 1 | Safety and the stamp | **v31** | [#28](https://github.com/matheus-sancha/FlowMap/issues/28), [#24](https://github.com/matheus-sancha/FlowMap/issues/24) | **built** |
| 2 | The document | **v32** | [#37](https://github.com/matheus-sancha/FlowMap/issues/37), [#24](https://github.com/matheus-sancha/FlowMap/issues/24) | **built**, drive abandoned |
| 3 | Templates and Save As | — | [#25](https://github.com/matheus-sancha/FlowMap/issues/25), [#23](https://github.com/matheus-sancha/FlowMap/issues/23), [#30](https://github.com/matheus-sancha/FlowMap/issues/30) | **built** |
| 4 | Compare | — | [#26](https://github.com/matheus-sancha/FlowMap/issues/26) | **built** |
| 5 | Small surface | — | [#31](https://github.com/matheus-sancha/FlowMap/issues/31), [#32](https://github.com/matheus-sancha/FlowMap/issues/32) | **built** |
| 6 | The mark and the PDF | — | [#33](https://github.com/matheus-sancha/FlowMap/issues/33), [#27](https://github.com/matheus-sancha/FlowMap/issues/27) | **built** |
| 7 | The drop | — | [#28](https://github.com/matheus-sancha/FlowMap/issues/28) | **built**, cold install owed |

**Grouped by what one sitting can build and drive.** A phase too big to drive in one sitting is a
phase that will not be driven, which is v2.0's own lesson: five phases were built between
2026-08-30 and 08-31 and three were never looked at by the person who asked for them.

**The order is fixed by four dependencies and nothing else:** the backup ships before the migration
it protects; `.flowmap` before templates and before the drop that carries the example; the v31 stamp
before compare has anything to compare; and `flowmap_mark.dart` before the PDF header can carry the
mark.


**Two migrations, not one.** v31 stamps a run with its build (phase 1); **v32 unreferences it from
its project** (phase 2), because a document switch empties the working tables and the cascade from
`projects` would have taken every stored run with it. They are one per phase, as the rule requires.

**Nothing in v2.1 reaches the engine.** The last engine change was v2.0's phase 10. This is the
first plan since v2.0 opened for which **no stored run is at risk**, and the 165 stored runs are
untouched by every phase below.

### Phase 1 — Safety and the stamp · schema v31

The migration backup from [#28](https://github.com/matheus-sancha/FlowMap/issues/28), then
`simulation_runs.app_version` from [#24](https://github.com/matheus-sancha/FlowMap/issues/24).

**In this order and in this phase, deliberately.** `onUpgrade`'s own preamble records that a
migration cannot run inside a transaction — `alterTable` needs foreign keys off — so a step that
throws leaves the database part-upgraded with its version counter unchanged, and *"a machine here
reached exactly that… and could not be opened again at all."* v31 is the first migration to run
since that was written down, so the backup goes in ahead of it.

**What the backup protects is not the drop.** A fresh install **creates** the schema at v31 rather
than migrating to it, so the twenty employees run no migration at all on their first launch. The
backup protects the developer's own 170 MB database and **every upgrade after this one** — which is
where field migration risk actually begins, and which #28 ruled out of scope as the second-build
question.

**Evidence owed: a query.** A live-database check in the shape of `live_db_check_test.dart`, run by
hand against a copy of the real database, asserting that the backup file exists before the migration
runs and that all **165** stored runs survive with `app_version` null.

### Phase 2 — The document

A project becomes a file you open and save
([#37](https://github.com/matheus-sancha/FlowMap/issues/37)), in the format
[#24](https://github.com/matheus-sancha/FlowMap/issues/24) defined — a zip holding `manifest.json`
plus JSON payloads, the manifest readable alone so a file from a newer build is refused with a
sentence rather than a crash.

**The document carries the plant.** Resources travel inside it — 135 rows against 630 of project
data — so a document opened anywhere shows the same workcenters and produces the same numbers, which
is the whole of what makes sharing mean anything. **It carries no runs**: those are 488,849 rows
against 630, so they stay on the machine that made them, keyed to the document, and a colleague
**re-runs** rather than receives (§4.4 guarantees the same inputs give the same run). A document is
**~765 rows**.

**There is no Save button.** The local Drift database is the working copy, every edit commits there
exactly as today, and the file is written through automatically — debounced, with a *saved / saving…*
state. All nine repositories are untouched. **Every write is whole, to a temporary name, then an
atomic rename**: a zipped document is only safe on a synced folder if it is never observed
half-written, and that is a property of the save path rather than of the format.

**The lock is a heartbeat** — user, machine, and a timestamp refreshed about every minute — **and
staleness heals itself**, so a crash or a dropped VPN frees the file in minutes and nobody has to
understand locks or decide to break one.

Also here: **the existing project migrates** to a document on first launch, which affects exactly one
machine, because every employee installs fresh.

**The migration is v32, and it was found by building rather than by reading.** Opening a document
empties and refills the working tables, and `simulation_runs.project_id` referenced `projects` with
`onDelete: cascade` — so the first document switch would have deleted every stored run. It becomes
`document_id` with no foreign key at all: a run's document may not be open, may live on a drive this
machine cannot see, or may have been deleted by someone else.

**Read #37 before starting.** It rejects the two options that look cheapest — a live SQLite the app
opens directly, and an explicit Save — and the reasons are not obvious from the code.

**Evidence: abandoned, 2026-09-13.** A sheet of 27 checks was written and then scrapped by
decision, with three of its questions answered first — Resources is document-scoped (11), an empty
plant names both ways out (13), and Save As exists (15). The other 24 were never walked, including
the one-way conversion of real data, which runs once and cannot be watched twice, and the crash that
must leave a lock healing itself rather than blocking a shared file.

**So phase 2 ships unverified.** Nothing in the suite renders a pixel, and 68 of its tests do not:
the start screen, the save indicator, both pickers, the document menu, the lock a colleague hits and
the conversion have never been seen. This is the third drive this map's lineage has abandoned; the
previous two came back as field findings. Recorded rather than argued.

**Decided during phase 2 and owed after the drive: the app reopens the last document on launch**
when it still exists and nobody holds the lock, falling back to the start screen otherwise. Not
built, deliberately — it changes what four of the drive's restart checks show, and the mechanism is
worth seeing before a convenience is laid over it. *The cost was stated and accepted*: launching the
app then takes a lock on a shared document without anyone asking for it.

### Phase 3 — Templates and Save As

Templates from [#25](https://github.com/matheus-sancha/FlowMap/issues/25) — a folder of `.flowmap`
files at `%APPDATA%\com.sancha\flowmap\templates\`, listed from disk, with every fact on the row read
from the manifest — and **Save As**, which is what duplicating a project becomes once a project is a
file ([#30](https://github.com/matheus-sancha/FlowMap/issues/30)).

**Binding lives here now, not in phase 2.** A document brings its own plant, so opening one binds
nothing — but a **template** is still a flow landing on a plant that is not its own, which is exactly
what [#23](https://github.com/matheus-sancha/FlowMap/issues/23) answered: a **dispatch target**
matched by name, types → workcenters → pools created in that order when missing, pool members
resolved before the pool. Applying a template also binds three references on the study's own row —
`productionCellId`, `productionLineId` and `paceSetterTargetId`.

**Queue settings never travel with a template**, because they are project-scoped and **6 of 15 are
shared between studies**.

**No schema.** Save As is a file write, and its guard is still #30's: **enumerate the columns rather
than list them**, because §2.6b caught `duplicateStudy` silently dropping a column twice, once for
`batch_number` *"since the column arrived"* — and loading and writing a document is the same
field-by-field hazard in a new place.

**Built 2026-09-13.** Templates live in `Documents\FlowMap\Templates`, beside the documents rather
than hidden in `%APPDATA%` — §10.2 put them in the app directory when a template *was* a document,
and a template is a file you hand to someone. The shelf lists a folder rather than a table, reading
only manifests. **Save As landed early, in phase 2**, because a new project starts empty and copying
a reference is how it gets a plant. `router.dart:168` is filled and `PlaceholderScreen` is deleted —
**the last placeholder in the app is gone.**

*Two things the tests found rather than the design*: `studies` is unique on (project, name), so
applying a template twice failed outright and the app now picks a free name; and an applied study is
never flagged for a run, because two flagged studies on one line is the state
`setIncludedInSimulation` forbids.

**Evidence owed: a drive sheet.**

### Phase 4 — Compare

The third mode from [#26](https://github.com/matheus-sancha/FlowMap/issues/26):
`Study | Simulation | Compare`, a verdict on **OTD**, the inputs that differed, then a metric table.

**This amends [#7](https://github.com/matheus-sancha/FlowMap/issues/7)**, which settled on two modes
after four driven rounds of a prototype. The reopening was deliberate; #7 is annotated.

**Two studies of one cell and line, each at its latest run** — #26 as written. It was inverted to
*two runs* on the morning of 2026-09-13 (165 runs had matched zero pairs) and **restored the same
afternoon by the developer after driving it**. The price is known: the live plant has no line with
two studies, so Compare opens on its empty state until a study is duplicated, the copy flagged and
simulated. A run is now named `studies · date time` everywhere it is picked.

**Every stored run is unstamped**, so the both-unstamped branch of the provenance rule is what makes
the 165 usable at all.

**And #37 narrowed its reach:** runs stay on the machine that made them, so comparison **never
crosses the shared drive** — it compares what was run here, on documents opened here.

**Evidence owed: a drive sheet.** It will open empty: no two live studies share a cell and line.

### Phase 5 — Small surface

The slicer's opening range from [#31](https://github.com/matheus-sancha/FlowMap/issues/31) — stops
unchanged, the range opening on first release → last delivery — and About from
[#32](https://github.com/matheus-sancha/FlowMap/issues/32), filling §12's reserved rail slot with
the build label, the data folder and the diagnostics log.

Also the guard: **a release build whose `BUILD_LABEL` is unset fails to build.** There is no
packaging script to enforce it in, which is phase 7's problem; the assertion is this phase's.

**Evidence owed: a drive sheet.**

### Phase 6 — The mark and the PDF

`flowmap_mark.dart` traced from `docs/brand/flowmap-mark-reference.png`
([#33](https://github.com/matheus-sancha/FlowMap/issues/33)) — themed bars, seed-blue arrow, a
compact variant, and `app_icon.ico` generated from the same geometry — then the PDF work from
[#27](https://github.com/matheus-sancha/FlowMap/issues/27): `vsm_symbols.dart` replayed into the
document, an embedded font, and the simulation report with the occupation chart.

**One phase because the mark blocks the PDF header**, and splitting them would mean building the
header twice. Also here: the **first-load and failure state**, which is where a migration that goes
wrong has to be readable by someone who cannot read a stack trace.

**Three defects this phase fixes, all found by generating the document and decompressing it:** the
material-flow arrow is the ASCII character `>`; the inventory triangles `▽`/`▲` do not draw at all;
the em dash is dropped silently.

**Evidence owed: a drive sheet *and* a test.** `flow_pdf_test.dart` claims PDF content *"cannot be
read back out"* — it can, and a test asserting every `FlowPdfStrings` value reaches the content
stream would have caught the dropped em dash.

### Phase 7 — The drop

The packaging script — **which does not exist**; `build_info.dart` credits one and the repo has only
a README line — plus `READ ME FIRST.txt`, the trilingual `manual.html`, and `example.flowmap`.

**One drop, at the end, to all twenty.** No pilot: each phase is driven by the developer instead,
and the first drop carries no migration risk because a fresh install creates rather than migrates.
The install-time risks it does carry — SmartScreen, and opening the example — arrive on twenty
machines at once, which was the stated cost of choosing one drop.

**The example is a document to open, not a file to import** (#37), and it does a second job: opening
it exercises phase 2's document path on **every single install**, which is twenty independent tests
of the newest code in the build. It **opens with empty results**, because a document carries no
runs — pressing Simulate is the first thing anyone does with it, and §4.4 means they get the same
numbers the developer did.

**Evidence owed: a document, and a cold install.** The manual is the first artefact in this repo
that is neither a query nor a drive sheet. The cold install is one machine that is not the
developer's, unpacking the zip with no dev tooling and no existing data folder.

**Built 2026-09-13.** `tool/package_windows.ps1` takes `-Label`, refuses a dirty tree or an existing
tag, builds with the label, adds the Visual C++ runtime, `READ ME FIRST.txt`, `manual.html` and
`example.flowmap` from `tool/drop/`, zips to `dist/`, and prints the tag command rather than running
it. **The example rehearsed the upgrade on the way**: `test/tools/make_example.dart` copies the live
database, migrates the copy v30 → v32 with no dangling rows, runs the one-time document conversion,
reopens the 30 KB result in a fresh database and simulates it (250 orders, 200 on time). The app
offers it by name while there are no recent documents, and opens it as the reader's own copy in
`Documents\FlowMap`; About links the manual. **Still owed: the cold install**, on a machine that is
not the developer's.

### Standing constraints

- **Nothing in the suite renders a pixel.** 1,146 tests say nothing about a screen, a PDF page, or a
  16 px icon. Four of the seven phases owe a drive sheet for that reason.
- **The audience changed the stakes.** Twenty machines, people who cannot read a stack trace,
  machines nobody can inspect, data nobody else has a copy of.
- **`simulation_runs` holds 165 stored runs at schema v30, none of them stamped.** Phase 1 adds the
  stamp going forward; it does not backfill, because those runs span three engine generations and a
  backfill would make the app lie about its own records.
- **Three phases have unusually good oracles and should use them:** the PDF content stream can be
  decompressed and asserted (phase 6), the project copier can be guarded by enumerating columns
  (phase 3), and the example import self-tests on every install (phase 7).
- `docs/DESIGN.md` is why, `docs/HISTORY.md` is what happened. §10.2 is **wrong in two places** until
  phase 3 rewrites it — its contents list and its binding rule.

---
## Version 2.0

Work happens on branch **`v2.0`**.

The plan below is the output of the wayfinder map
**[FlowMap v2.0 — re-designed surface, simpler plant model](https://github.com/matheus-sancha/FlowMap/issues/4)**,
whose last ticket was
[What are v2.0's phases, and in what order?](https://github.com/matheus-sancha/FlowMap/issues/11).
Every phase below is the *summary*; the ticket linked beside it holds the reasoning, the rejected
alternatives and the live-database evidence, and is what a session building that phase should read
first. Nothing here restates a decision — it points at the one place each lives.

### How a phase works

- **Shippable and drivable on its own.** A phase ends with the suite green, `flutter analyze`
  clean, and the evidence that phase owes (below) recorded.
- **Its strings land in all three locales.** `app_en.arb`, `app_es.arb`, `app_pt.arb` and a
  `flutter gen-l10n`, in the same commit as the code. This is no longer a habit: `l10n_test.dart`
  asserts `lib/src/l10n/untranslated.json` is empty, so a phase cannot ship English-only without
  failing the build. 567 keys, three locales, currently clean.
- **Migrations are one per phase and never combined.** The live database is opened daily, and one
  merged migration would make *"don't open the app between phases"* an unwritten precondition
  ([#6](https://github.com/matheus-sancha/FlowMap/issues/6)).

### The phases

| # | Phase | Schema | Ticket |
|---|---|---|---|
| 1 | Queue as an aspect | **v27** | [#5](https://github.com/matheus-sancha/FlowMap/issues/5) — **done, driven** |
| 2 | Priority goes | **v28** | [#6](https://github.com/matheus-sancha/FlowMap/issues/6) — **done** |
| 3 | Navigation | — | [#7](https://github.com/matheus-sancha/FlowMap/issues/7) — **built, driven in part** — light mode driven 2026-09-08, two defects fixed; the four study tabs still unopened |
| 4 | Grids | — | [#10](https://github.com/matheus-sancha/FlowMap/issues/10) — **built, drive still owed** — unwalked across three sittings |
| 5 | Occupation | **v29** | [#9](https://github.com/matheus-sancha/FlowMap/issues/9) — **built and driven, 2026-09-08** — all nine Occupation checks and all three slicer/granularity checks pass |
| — | ~~Part identity~~ | — | [#12](https://github.com/matheus-sancha/FlowMap/issues/12) — **executed, not phased** |
| 6 | Occupation, round two | — | [#13](https://github.com/matheus-sancha/FlowMap/issues/13), [#16](https://github.com/matheus-sancha/FlowMap/issues/16) — **executed and driven** |
| — | ~~Text clean-up~~ | — | [#15](https://github.com/matheus-sancha/FlowMap/issues/15) — **executed, not phased** |
| 8 | Matrix edges | — | [#14](https://github.com/matheus-sancha/FlowMap/issues/14) — **executed and driven** |
| — | ~~The period filter~~ | — | [#17](https://github.com/matheus-sancha/FlowMap/issues/17) — **executed, not phased** |
| — | ~~Pane state~~ | — | [#18](https://github.com/matheus-sancha/FlowMap/issues/18) — **executed, not phased** |
| 9 | Capacity follows the schedule | — | [#19](https://github.com/matheus-sancha/FlowMap/issues/19) — **built, query answered** |
| 10 | Operators scale labour-paced work | **v30** | [#20](https://github.com/matheus-sancha/FlowMap/issues/20) — **built, query answered** |

**The plant model first, then the surface.** The two tracks barely touch, and this order means the
two migrations land while the presentation layer is still the one the tests were written against,
and the large surface work then runs on a settled model. It is also the order the tickets already
recorded their migration numbers in, so no resolution has to be corrected.

Schema is at **v30** (`database.dart:78`). **164 runs are stored** — 163 with step rows, 20 of them
with the monthly capacity the Occupation view needs. (`DRIVE-2026-08-29.md` says 104; that was true
at schema v22 on 29 August.)

**The 2026-09-08 sitting is the first drive here to return confirmations rather than adjustments.**
`DRIVE-2026-09-07.md` sections 1–3 are answered; **4, 5, 6 and 7 are not**, and 4 and 5 have been
owed since 2026-08-31.

---

#### Phase 1 — Queue as an aspect · schema v27

A queue was only ever keyed by its target, so it does not need a name of its own.

- `project_queues.name` is dropped; the caption is **derived** as `<queue type> - <target>` —
  `FIFO - CLAD07`, and `Queue - CEU27` for an untyped lane, renamed from *Push*. The striped VSM
  arrow keeps the word *Push*.
- The step's `label` goes with it, so a box is its workcenter everywhere.
- The invariant: **one queue per dispatch target, not per workcenter.** A machine reached both
  directly and through a pool genuinely has two lines.
- **Short queue-type names, in three languages.** The derived caption needs them —
  `Earliest need date - CLAD07` does not fit a 140 pt process box. Left to this phase by #5 as too
  small to ticket.

*The live database decided three of these*: all 15 queue names are `FIFO ` plus a mangled target
name, only 2 of 25 steps carry a label and both spell one pool differently, and no spine revisits a
target. **Stored runs survive untouched.**

**Evidence — the live-database check is done** (`19813d6`). The migration ran against a copy of
the real 149 MB database: it upgraded to v27, `PRAGMA integrity_check` returned `ok`, both columns
are gone, and **all 15 queues and all 25 steps survived** with 250 orders, 147 runs and 189,623
step rows untouched. Seven of the fifteen are untyped, exactly the seven #5 predicted, and every
caption derives — including `FIFO · CLAD Pool - Célula 11B/C`, the pool whose own name contains a
hyphen and is why the separator is a middot. `live_db_check_test.dart` carries the assertions.

**The drive is done** — `docs/DRIVE-queue.md`, 2026-08-30 under `0.1.0-2026-08-30a`, session
21:20:45, `db.open schema 27 from 27`. Reported correct for the group; recorded there as a group
result and not itemised, which §5.3 is the standing warning about.

**What the drive settled that nothing else could.** The Gantt read against a *stored* run shows the
caption unchanged — `gantt_view.dart:355` draws `lane.name` when the run carries one, and all 147
runs stored before this phase do. That is §7.10 working, and it means those runs' Gantts keep saying
`FIFO BAN` and `FIFO CLAD` permanently while the map says `Queue · BAN11` and
`FIFO · CLAD Pool - Célula 11B/C`. Left standing; nobody decided otherwise. A simulation was then
run — `e0d93a45`, 21:26, **148 runs** — and stores **`name` NULL on all 15 lanes**, so the derive
path is live. That is the first evidence for `19813d6`'s one deliberate deviation from #5, which
asked for the caption to be written in and got null instead so it re-derives in the reader's
language.

**One finding, recorded and not actioned — phase 2 carries it.** That run stores `rule = fifo` on
all 15 lanes, including the seven `project_queues` holds as null.
`simulation_repository.dart:129` loads a queue as `rule: row.rule ?? DispatchRule.fifo`, erasing the
null at the boundary into the sim model — correct for the engine, and harmless while `SimLane.rule`
was write-only. **This phase made it load-bearing**, so those seven derive `FIFO · CEU27` on the
Gantt while the map draws `Queue · CEU27`: §5.5's *null is not FIFO* holds on the map and is lost on
the run. The fix is a nullable `SimQueue.rule` with the FIFO default applied where the engine sorts
rather than where the project loads — **which is phase 2's own comparator**, so it goes there rather
than reopening this phase.

---

#### Phase 2 — Priority goes · schema v28

Study Priority is **a lever nobody has ever pulled, wired below arrival so it could not expedite
anything even if they had**. One read site, `engine.dart:955`.

- Study priority is deleted, and `simulation_run_studies.priority` with it — that column is
  **write-only**, read by no surface in the app.
- The vacated comparator slot is refilled with the **need date**, because 27 of the 78 real
  cross-study ties in 189,623 step rows were settled by comparing two **UUIDs**. *"Why did this
  order go first?"* was unanswerable a third of the time.

- **Inherited from phase 1's drive: `SimQueue.rule` becomes nullable**, and the FIFO default moves
  to where the engine sorts rather than `simulation_repository.dart:129`, which currently loads
  `rule: row.rule ?? DispatchRule.fifo` and erases the null before the run's copy-in can see it.
  Run `e0d93a45` stores `fifo` on all 15 lanes while the project holds 8 and 7. Harmless while the
  column was write-only; phase 1 made it the Gantt caption, so seven untyped lanes now derive
  `FIFO · CEU27` there while the map draws `Queue · CEU27`. This phase is already rewriting the
  comparator that applies the default, which is why it lands here.

*The live database proves it never fired*: all 3 studies and all 324 stored study rows across 147
runs sit at the default 100, so deleting it is a provable no-op on every run ever stored.

**A re-run after this phase will not match a run stored before it.** Nothing is stamped on the run
to say so — a run already carries `created_at` and the history picker already orders by it.
**`docs/HISTORY.md` gets the line** instead: the date this phase landed, and that runs before it
break cross-study ties by UUID while runs after it break them by need date.

**Evidence — the live-database check is done.** The migration ran against a copy of the real 150 MB
database: upgraded to v28, `integrity_check` ok, both priority columns gone, and **3 studies, 327
stored study rows, 148 runs, 191,494 run steps, 250 orders and 15 queues** intact. All 3 studies and
all 327 stored study rows sat at the default 100, so the drop is a provable no-op on every run ever
stored. `live_db_check_test.dart` carries the assertions; `HISTORY.md` §6.2 carries the figures and
the tie-break line.

**The re-run diff is done too, and it corrects this phase's own prediction.**
`live_tiebreak_check_test.dart` re-runs Célula 11B/C/D on today's input and diffs against
`e0d93a45` — the newest stored run, and the last made under the old fall-through, so it is the least
drifted baseline available. Result: **1,871 steps on both sides, zero input drift, and not one step
starting at a different second.**

#6 expected a re-run not to match. Both figures are true and they answer different questions: *27 of
78 ties settled by a UUID* is about how a run was **explained**, which is why the slot was refilled;
*how many orders move* is smaller. Across all 148 stored runs there are **80 cross-study arrival
ties, 61 still resolvable** — the other 19 name deleted orders — **and the need date reorders 4.**
`e0d93a45` has two, and the need date agrees with the old key on both. **The comparability worry is
much smaller than this phase assumed.** `HISTORY.md` §6.2 has the figures.

*The check had a defect worth knowing about*: comparing the moments directly reported 1,862 of 1,871
steps moved, all by a fraction of a second — `simulation_run_steps` stores whole seconds and the
in-memory result does not. It compares at the stored resolution now.

**No drive: nothing visual changed.** The one caption that did is covered by a query and by
`run_storage_test.dart`.

*One assertion was written for the live check and removed after it failed correctly* — see
`HISTORY.md` §6.2. Null in `simulation_run_lanes.rule` means both *unset* and *never recorded*
across generations, so it cannot prove the fix; `run_storage_test.dart` does that instead.

---

#### Phase 3 — Navigation

**Two modes of one project, and every tab is a route.** The largest phase, and the one that closes
the gap between §12.1's *"all routes deep-linkable"* and six screens that had no URL.

- A `Study | Simulation` switch above the tab strip. Flow stays a study tab.
- The run is the *Simulation results* destination, with five tabs: **Simulation Overview,
  Production Plan, Production Gantt, Occupation, Delivery Float**.
- **Ten `go_router` locations** replace a `TabController` and a `setState` switcher.
- Readiness becomes a red strip under the app bar; the period control is hidden rather than greyed.
- The filter bar governs all five tabs, with §12.1's whole-run caveat kept inline.
- `simWorkspace` — unused in `lib/` since the pre-map renames — is either used as this
  destination's title or deleted.

**Left to this phase deliberately:** whether the results filter rides in the URL. `?study=` already
does; §12.1 argued the other six should not. Nothing has decided otherwise, so keep §12.1's answer
unless this phase finds a reason.

Settled by four driven rounds of a prototype on the real database, which also rejected *"Define vs
Read"* and a flat nine-tab strip. The prototype is deleted, so **#7's write-up is what this phase
lifts from.**

**Built** — `flutter analyze` clean, **1,007 tests** (up from 998), three locales, `DESIGN.md` §12.1
rewritten around the ten locations. `workspace_tabs.dart` holds the two enums; `workspace_tabs_test`
holds the round-trip, the fallback and the period-control predicate, which are the parts of "every
tab is a location" that can be asserted without drawing anything.

Two things went further than the ticket asked, both small: the app bar reads **Simulate then the
gear** (it was the other way round, putting the control nobody presses between the reader and the
one they press every time), and the plan tab's help text is **capped at two lines** — unbounded it
wrapped far enough on a 768 pt pane to push the table out of its column, which a test caught as
`RenderFlex overflowed by 5.0 pixels`.

**Driven 2026-08-30** under `0.1.0-2026-08-30c`, session 22:07:56 — `docs/DRIVE-nav.md`. Reported
correct for the group, which §5.3 is the standing warning about; **but this is the one phase whose
group answer a log can sharpen.** §15's route breadcrumbs record every location, and the whole phase
is about locations, so what was actually reached is objective for once.

**Corrected after the field reported the tabs dead.** Both redirects were catching their own
sub-routes — a route-level redirect fires for children as well as for itself — so every study tab
bounced to `/flow` and all five results tabs to `/overview`. **The drive read that as success**,
because §15 logs the location *asked for* rather than the one resolved: five requests, one arrival.
Fixed by guarding on the bare path; `test/app/router_redirect_test.dart` asserts the body changed,
not just the location, and asserts the unguarded shape fails so the guard's reason is recorded.

**What the drive did establish:** every tab's tap fires and writes its own location, and the mode
switch was used in both directions. What it did not, and could not: that anything rendered.

**Not established, and named rather than assumed:** four of the five study tabs were never opened,
so **the period control being hidden rather than greyed was not seen** — it is only observable on
them. **`?study=` surviving a tab change** is not in the log either, because §15 records `uri.path`
and drops the query per the ids-only rule, and it is asserted nowhere else. And **light mode**, which
this phase was the pinned home for, was not shown to have been toggled.

**Still owed — a short sitting, worth taking before phase 4 builds on this:** the four unopened
study tabs with the period control in view; `?study=` carried in and across a tab change; and light
mode on the five results tabs and the readiness strip, whose `errorContainer` over
`onErrorContainer` is the pairing most likely to be wrong in the theme nobody has looked at.

---

#### Phase 4 — Grids

Three interaction adjustments turned out to be three local behaviours, not one shared one.

- **`onReorder(int from, int to)` on `DataGrid`, and exactly one caller passes it.**
  `demand_orders` is the only table with a `sequence` column; `demand_parts` has none and its row
  number is a display index. Drag by the **row-header number** — already a frozen 44 px slot — so
  nothing inside a cell is draggable and text selection is untouched.
  `moveOrder(studyId, from, to)` already does an arbitrary insert, so **the data layer needs
  nothing**. The studies hold 60, 60 and 130 orders; expect edge auto-scroll to be the hard part.
- **Sorting, wired to the surfaces the rule names.** The rule: *a surface sorts unless its row
  order is itself data.* Queue ranking, share of flow, the parts table and the summary table sort.
  The production plan does not — its order is the release sequence — and neither does the float
  matrix, whose row *r* means rank *r* in that column. No editable grid sorts.
  `resultTable`'s `sortColumn` / `sortAscending` / `onSort` have had no caller since #7; this is
  what gives them one.
- **The paired-layout rule into `docs/DESIGN.md` §12.5**: *two tables pair when they are one
  question read two ways*, collapsing to stacked under 1100 px. Already implemented on the
  Overview by #7; recorded here as the rule, honestly noted as inferred from its single instance.

**Built** — `flutter analyze` clean, **1,018 tests** (up from 1,007), `DESIGN.md` §12.5b written with
all three rules. Sorting is one widget, `SortableResultTable`, rather than five copies of the same
toggle; reordering is `DataGrid.onReorder` with the one caller #10 predicted.

**One thing #10 did not price, found while wiring it.** The parts table's swatch *is* the Gantt's
legend (§8.6) and is keyed on a part's position in `metrics.parts` — so sorting it while handing
`_PartSwatch` the displayed row would recolour every part on first press, and the legend would
disagree with the chart it is the legend for. The rows carry the index they arrived with. Recorded in
§12.5b because any future sortable table holding a positional value has the same trap.

**And one apparent contradiction, resolved rather than papered over.** #7's combined production plan
sorts; #10 says the production plan does not. Both are right: *by study* the rows are one study's
release sequence and that order is the record, while *combined* spans three independent sequences, so
there is no single order to destroy and Start Date ascending is a presentation choice like any other.
The rule stands unchanged.

**Still owed: `docs/DRIVE-grids.md`** — drag a row across all 130, sort each of the four surfaces and
confirm the two that must not offer it do not. What the suite already covers, so the drive need not:
the drag arithmetic and its clamps (`data_grid_reorder_test`), and the sort toggle, the
ascending-on-a-new-column rule and the unsortable column (`sortable_result_table_test`). What is left
is genuinely feel — how the edge-jump reads at 130 rows, which #10 named as the one thing reasoning
could not settle.

---

#### Phase 5 — Occupation · schema v29

**A workcenter × month grid, not a chart.** Across all three runs that can draw this view — 3 of 147;
the rest predate v25's monthly capacity — the aggregate bar has **never once broken its capacity
line** (peak 87 %) while single workcenters hit **149 %**.

- **`period_matrix.dart` extracted here rather than in phase 4**, so it has both its callers from
  the start: the float matrix and this grid.
- `occupation_graph.dart` → rows × months, two groupings (per workcenter, per line), three units
  (`%`, `733/499` hours, `-234` gap).
- `occupation_view.dart` → the grid, a PLANT row shown only when nothing has narrowed the workcenter
  set, two switches. **The stacked-bar painter and its legend are deleted.**
- `run_filter.dart` gains `typeIds` and `workcenterIds`; `OccupationWorkcenters` is absorbed and
  deleted. **Structural filters** (studies, cells, lines, type, workcenter) choose the workcenter set
  so demand and capacity move together; **order-level filters** (projects, parts, order numbers)
  leave capacity fixed and dim the remainder.
- `simulation_workspace.dart` — the two workcenter pickers are **promoted** into the shared filter
  bar, not deleted. `gantt_view.dart` and `simulation_tab.dart` obey them, because their rows are
  workcenters too.
- **Schema v29**: `occupationAmberPct` and `occupationRedPct` on the project, defaulting to 85 and
  100, plus the settings surface beside the float thresholds.
- `tokens.dart` — **`OccupationRamp` is retired.** It coloured a stack that no longer exists;
  `FlowStatus` good/warning/critical is what the bands use.
- The grid is built sortable, per phase 4's rule.

**No stored run is invalidated.** The 3 graphable runs already carry everything the grid reads, and
the 144 that cannot draw it could not draw the chart either.

**Built** — `flutter analyze` clean, **1,023 tests**, three locales.
`occupation_graph.dart` is deleted and `occupation_grid.dart` replaces it; `period_matrix.dart` is
extracted with both its callers, the float matrix and this grid, exactly as #10 asked. The grid is
sortable by any month per §12.5b, and the float matrix declines that offer because its row *r* means
rank *r*.

**Evidence — the live-database check is done.** v28 → v29 against a copy of the real database:
`integrity_check` ok, the project holding **85 / 100** with its float thresholds untouched beside it,
and 3 studies / 150 runs / 195,236 steps / 250 orders / 15 queues intact.

**One of #9's own figures has moved.** It said **3 of 147** stored runs can draw this view; it is now
**6 of 150**, because every run made since v25 can and three were made while v2.0 was being built.
The argument is unchanged — 144 still cannot, and a run that cannot draw the grid could not draw the
chart either — but the number is in `HISTORY.md` §6.3 rather than left to be re-derived.

**Driven, and it came back with three findings — two of them mine.**

1. **The chart was deleted and should not have been.** #9 said to remove it and I did; the field
   wants it *adjusted*. Both surfaces now sit behind a `Chart | Grid` switch, the grid default.
   `OccupationRamp` is restored with the stack it colours, and `_SegmentColours` reads it rather
   than the generated Material roles it read in v1.0.
2. **The grid ignored study, cell and line filters entirely.** It applied only `typeIds` and
   `workcenterIds`, under a comment claiming the other three were handled elsewhere — they were
   handled nowhere. Both surfaces now share one `workcentersInView` in `run_filter.dart`, because two
   callers computing it separately is how it came to be applied in neither.
3. **The rows were too narrow** for a two-line workcenter header. 34 pt → 48 pt.

**Still owed: `docs/DRIVE-occupation.md`** — the grid on the real run, both groupings, all three
units, and a project whose thresholds have been changed from the defaults. What the suite already
covers, so the drive need not: that a structural filter never shrinks what a machine was asked for,
that an order-level filter moves the share and not the band, that the PLANT row disappears the moment
the workcenter set is narrowed, and that an aggregate can never be worse than its worst member — which
is the property that killed the chart, stated as arithmetic.

---

#### Phase 6 — Part identity · **there isn't one**

It was named here as a slot [#12](https://github.com/matheus-sancha/FlowMap/issues/12) would fill
in. #12 resolved by **disproving its own premise** — eight mutually-distinguishable colours do
exist under FlowMap's constraints, so no encoding had to change — and the whole of it was small
enough to execute inside the ticket (`2cb0126`). Nothing is left to phase.

The one thing a later phase inherits is a *rule*, not a task: **a hue changed in
`part_palette.dart` is re-validated, never eyeballed.** Headroom over the floors is 0.7 and 1.6 ΔE,
and `part_palette_test` now measures all pairs — which is what would have caught both of the
palettes it has replaced.

---

#### Phases 6 and 7 — what the field sent back, 2026-08-31

**The map was declared finished on 30 August and reopened on the 31st.** A sitting was prepared as
`docs/DRIVE-2026-08-31.md` — 23 checks covering everything phases 3, 4 and 5 still owed — and came
back with **four adjustments instead of 23 answers**, all inside one screen. Three tickets carry
them, and they are still *deciding*, not built.

- **Phase 6 — Occupation, round two.** [#13](https://github.com/matheus-sancha/FlowMap/issues/13) is
  **done and executed** (`6c310e0`, 1,034 tests, analyze clean, no new ARB keys) — **it did not need
  to be a phase.** The field's own sentence settled it: *the chart is demand vs capacity of what is
  filtered*, which makes it a **drill-down rather than a plant average**, so #9's arithmetic stops
  being an objection to the chart leading. The chart opens first, the % label counts the grey
  segment, all three coloured segments survive, and there is now an **hours axis pinned outside the
  horizontal scroll** with **dotted** gridlines. One named cost: the workcenters-over badge is gone, so
  an unnarrowed chart no longer hints that April's 87 % holds seven overloaded machines.
  **`docs/DRIVE-occupation.md` is still owed** and now owes the new chart too.
  [#14](https://github.com/matheus-sancha/FlowMap/issues/14) is still open — the **PLANT row into a
  TOTAL row at the bottom**, and because `PeriodMatrix.pinned` is shared with the float matrix, it
  has to answer for both.

  **`occupation_chart_scale.dart` is the reusable lesson.** The scale and its tick arithmetic were
  pulled out of the `CustomPainter` into a public, pure file *so they could be asserted*, and the
  test found a defect inside the hour: a 12,345 h peak collapsed the axis to three ticks because the
  nice-number ladder skipped 2.5. That is the standing constraint below working exactly as written —
  reach for the property before reaching for a drive.

  **Then it was driven, twice, and produced eight findings.** The first (`789ca14`): the neutral
  segment appeared under *every* structural filter, because `occupationGraph` passed the whole
  `RunFilter` into its kept-orders set — so narrowing to one of two studies painted **half** the
  demand grey. `occupation_grid.dart` had stripped the structural filters out of that since #9; the
  chart never did. **It survived because the chart's tests were deleted with the chart in #9 and did
  not come back with it in `795ac6e`** — four are now restored to
  `occupation_grid_test.dart`, three of which fail on the pre-fix code. The second look produced
  seven more, now [#14](https://github.com/matheus-sancha/FlowMap/issues/14),
  [#16](https://github.com/matheus-sancha/FlowMap/issues/16),
  [#17](https://github.com/matheus-sancha/FlowMap/issues/17) and
  [#18](https://github.com/matheus-sancha/FlowMap/issues/18).

- **Phase 8 — the second drive's other findings.** [#14](https://github.com/matheus-sancha/FlowMap/issues/14)
  widened from *"PLANT becomes TOTAL at the bottom"* to **what aggregates a period matrix carries on
  its edges**: a total row *and column* on the Occupation grid, an **average** row and column on the
  float matrix, and the awkward part — Occupation cells are ratios, which do not sum, so the column
  is `total asked ÷ total capacity` and changes arithmetic with the unit switch.
  [#17](https://github.com/matheus-sancha/FlowMap/issues/17) **is answered and executed** — it did
  re-column the matrices, and that turned out *not* to reach the shape of a stored run: folding
  monthly capacity rows into quarters is a read-side aggregation. §12.8.
  [#18](https://github.com/matheus-sancha/FlowMap/issues/18) **is answered and executed** — and was
  small and sharp only until its own sweep ran: the pane turned out not to belong in Simulation mode
  at all, the mode switch was returning to the wrong study, and the two tab strips disagreed about
  whether view state survives. §12.9.

- **Phase 9 — capacity follows the schedule.** *"The capacity lines and values must follow the
  workcenter periods, even without demand."* [#19](https://github.com/matheus-sancha/FlowMap/issues/19)
  is **the only thing in this map since phase 2 that changes what a simulation writes down**, which
  is why it is a phase and not another execution inside its ticket.

  **What changes.** `engine.dart:1211` loops `for (var month = start; month.isBefore(_now); ...)` —
  the run's own start and end. It loops each workcenter's **schedule periods** instead, and it writes a
  row for every workcenter that *has* a period rather than only those the run gave work to. Both
  clippings are one loop and one workcenter set.

  - **Bounded per workcenter, by its own periods** — so the grid goes ragged and a workcenter whose
    schedule stops earlier is *blank* there rather than zero. §10.2's distinction: nobody has said is
    not the same claim as said zero.
  - **`scheduleHorizon` is computed over the workcenters the run USES, not the ones it can draw.** It is
    the *minimum* of each schedule's last end date, and on the live database the one idle workcenter
    (`CLAD09`) ends **2026-12-31** while all seventeen busy ones end **2027-12-31** — so writing its
    capacity without this separation would drag the horizon back a year and start firing the
    schedule-tail warning on runs that have nothing wrong with them. **This is the trap in the
    phase.**
  - **No marker on the run.** The 150 stored runs keep what they have (§7.10), so their charts stop
    where their orders did. #11 refused an `engine_generation` column for a larger behavioural break
    and the same argument holds: `created_at` dates the run and `HISTORY.md` carries the line.

  **Built 2026-09-07**, 1,085 tests, analyze clean. The evidence it owed is a query rather than a
  drive, and it is committed as `test/simulation/live_capacity_check_test.dart` — run with
  `--tags live` and `FLOWMAP_LIVE_DB` pointing at a copy. Against the live plant it prints:

  ```
  resource model=17  scheduled=18  horizon=2027-12-31
  scheduled but unrouted: [CLAD09]
  capacity rows=636 across 18 workcenters
  CLAD09: 24 months, 2025-01 → 2026-12, steps=false
  the run spans 15 months, its workcenters 36
  ```

  **636 rows, not the 648 the ticket predicted.** 648 was 18 × 36 — the unragged arithmetic — and
  `CLAD09` is scheduled for 24 months rather than 36. The ticket's own two figures could not both
  be true, and *"its columns must stop at 2026-12"* is the one that held. Everything else landed as
  written, the horizon included.

  **Three things the ticket did not price, found while building it.**

  - **The set is a union, not a replacement.** A workcenter can be routed to with no schedule of its
    own, and swapping the sets would have deleted its rows. It keeps them, bounded by the run as
    before.
  - **The idle workcenter needed an identity, not just capacity.** `workcentersInView` iterates
    `openByWorkcenterMonth.keys` — which the ticket read as *filterable with no change* — but the
    name and the type it filters and labels by come from `simulation_run_workcenters`, and that
    table was written from the resource model. `CLAD09` would have drawn as a **uuid** and vanished
    under any type filter. Its whole-run open time is written too, so it appears in the utilization
    table at 0 % — which is that table's own stated purpose: *a workcenter that sat idle all run is
    evidence too*.
  - **The months no longer sum to the whole-run open time.** That invariant had a test and a
    comment claiming the two were one walk cut up. They are two walks over two spans now, by
    design, and the test says so instead.

  **What it gets for free**, because three readers already derive from this one table:
  `workcentersInView` iterates `openByWorkcenterMonth.keys`, so the idle workcenter becomes filterable
  with no change; and #17's `runMonths` unions the capacity months, so the period slicer grows from
  15 stops to 36 and its Year granularity goes from two columns to three — **no code in #17 moves**.

  **What it costs, decided and accepted**: the TOTAL column falls from **68.4 % to 28.5 %**, because
  21 months of real capacity join the denominator at zero demand. Per-month figures are untouched —
  2026-11 still reads 74 % — and #14 defined that column as a ratio of sums over *what is shown*,
  changing with the filter by design. One drag of #17's slicer back to the run's own span restores
  68.4 %.

- **Phase 10 — operators scale labour-paced work · schema v30.** *"I added more operators per shift
  to coating. But it didn't increase the capacity."*
  [#20](https://github.com/matheus-sancha/FlowMap/issues/20) is the second thing in this map to
  change what a simulation writes down, and the first to be found by someone using the app rather
  than by reading it.

  **The model states something false about the plant.** §7.5 says *"any count ≥ 1 runs
  identically"* and rejects operators as capacity because *"two operators on one CNC do not double
  its output"* — true of a CNC, false of a spray booth, a bench or an inspection table. Some
  workcenters are **machine-paced** and some are **labour-paced**, and the docs assert the first for
  all of them. That is why this is in scope at all: the map rules out new capability, and makes an
  exception for the field showing the existing model wrong.

  **What changes.** One more divisor in an arithmetic that already has two
  (`effective_time.dart`):

  ```
  effective = perPiece × batch × (1 + rework) ÷ availability ÷ operators
  ```

  - **A process time is one operator's labour content**, and the crew divides it. *Rejected: a
    baseline crew stored beside it*, and *rejected: migrating existing times so nothing moves.*
  - **The crew on the shift where work starts costs the whole job** — availability already resolves
    this way at `engine.dart:1059`, so this follows the precedent rather than inventing a rule.
    Needs a way to ask the calendar which shift covers an instant; `ShiftWindow.position` is
    already the index into the operators list.
  - **The flag lives on `workcenter_types`, defaulting to machine-paced**, so nothing moves until a
    type is marked. The run already copies the type in (§7.10), so a stored run can say how it was
    paced.
  - **No marker on the run.** The 150 stored keep what they have, as #11 and #19 both decided.
  - **Capacity stays open hours and demand falls** — the grid measures workcenter occupancy, and
    reading it as labour-hours over crew × open gives the identical ratio.

  **Built 2026-09-07**, 1,123 tests, analyze clean — and **corrected the same evening**. It first
  shipped dividing the *demand*, which reads as the work getting smaller; the field's answer was
  *"I don't want the demand to drop, I want the capacity to increase."* The room is what grows.

  A **Machine Pace / Operator Pace** dropdown on the type, defaulting to Machine Pace. At an
  operator-paced workcenter the monthly capacity is **operator-hours** — each shift's open time
  weighted by the crew standing in it — and the step stores the work's **labour content**, which
  the crew does not change. The workcenter is still held for less time, so dates and queueing move.
  *Utilization keeps workcenter-hours on both sides* (§8.3): its numerator is how long the machine was
  held, so its denominator has to be the machine's clock too.

  The owed query is `test/simulation/live_pacing_check_test.dart` — the same plant against itself
  with every workcenter forced machine-paced, so the diff is the pacing and nothing else:

  ```
  operator-paced on this plant: [Coating]
  workcenters whose grid moved: [Coating]
    Coating  demand 6335h -> 6335h, capacity 17742h -> 48992h
  ```

  **Only Coating moved, its capacity rose and its demand did not**, which is the assertion and not
  the print. The factor is **2.76, not 3**: the crew is `3/3/2` and the shifts are 8:48, 8:34 and
  5:25, so the smallest shift carries the smallest crew.

  **The explanation the field is owed now lands with the feature**: the labour-paced switch carries
  its own `ⓘ`, which is where the definition belongs — §12.7b's case, held back deliberately
  because the definition changed here and writing it twice would have been writing it wrong once.

  **One thing found next door.** `createWorkcenterType` took an `icon` and never wrote it, so a new
  type arrived with the default glyph and kept the chosen one only after a second edit. Fixed with
  the column added beside it.

**The 23 checks are still owed, and the sheet asking them has been rewritten.**
`docs/DRIVE-2026-09-07.md` is the live sitting: sections A, B, C and E of the 2026-08-31 sheet
re-pointed at the app as it stands, plus what the six tickets closed since have never had looked at
— the rebuilt Occupation surface, the period slicer and its granularity dropdown, and the four `ⓘ`
left on a five-tab strip. `docs/DRIVE-2026-08-31.md` stays for its **Findings**, which are the
field's own words and the origin of three tickets; its unanswered checks have moved.

**Two changes of method, both paid for.** The new sheet leads with **light mode** — four sittings
have now missed it, every one of them because it sat last — and it names two preconditions the last
sheet did not: **run a fresh simulation first** (the newest stored run is from 2026-08-30 and
predates every surface change since), and **do not report `CLAD09` or the 68 % TOTAL column**, which
are phase 9 decided and not yet built.

> **The standing lesson, since this is the second time it has cost something.** A phase built is not
> a phase seen. Five phases were built in two days; three had never been looked at by the person who
> asked for them, and the first look produced four findings in a single screen. Build less before
> showing more.

---

### Already executed, and so not a phase

Each was unambiguous enough to land inside its own ticket, per the map's rule that a ticket whose
answer is unambiguous is executed rather than planned.

| Commit | What |
|---|---|
| `1d4cb0d` | Four renames, before the map opened: the duplicate **Simulation** button under *New study* gone; *View results* → **Simulation results**; *In simulation* → **Simulation settings**; *Include in runs* → **Include in simulation**. |
| _next_ | [#17](https://github.com/matheus-sancha/FlowMap/issues/17) — **§12.8**: the period filter becomes a month-stepped slicer over the run's own months, and the Occupation grid and its chart re-column by `PeriodGranularity`. Not a phase: folding monthly capacity rows is a **read-side aggregation**, so it reaches no schema, no engine and no stored run — the one thing the ticket flagged as possibly making it one. The float matrix does not follow, because it aggregates nothing. **A drive is owed.** |
| _next_ | [#18](https://github.com/matheus-sancha/FlowMap/issues/18) — **§12.9**: the studies pane is Study-mode chrome and its collapse lives in `window.json` beside `maximized`. Two defects found under the reported one: the mode switch came back to the *first* study rather than the one `?study=` named, and the study tabs were a `switch` where the results tabs are an `IndexedStack`, so one strip remembered its view state and the other forgot. |
| `f30b4ab` | [#15](https://github.com/matheus-sancha/FlowMap/issues/15) — **§12.7b**, the surface half of a rule the app already had: prose that restates its heading is deleted, a definition a wrong *conclusion* depends on goes behind an `ⓘ` beside the name of the thing it explains. Fifteen standing captions swept, 41 dead ARB keys gone in three locales. Not a phase, because it reaches no schema, no engine and no stored run. **A drive is owed.** |
| `8daf2a8` | [#8](https://github.com/matheus-sancha/FlowMap/issues/8) — the seed off green to blueprint blue `#1F5C8B`, status colours and the occupation ramp chosen explicitly, space/radius/motion scales named. Two palette defects fixed that two tests had agreed were fine. |
| `3d82715` | [#7](https://github.com/matheus-sancha/FlowMap/issues/7) — the Delivery Float was painting the band named *green* in the brand's blue; a real legend in three locales; `fill:` on the overview tables; optional sorting on `resultTable`. |
| `9264a90` | [#10](https://github.com/matheus-sancha/FlowMap/issues/10) — the arrows leave a cell only once the caret cannot; the Gantt pans on middle-drag or space+drag; `centred_table.dart` deleted, having had zero callers. |
| `2cb0126` | [#12](https://github.com/matheus-sancha/FlowMap/issues/12) — eight all-pairs part colours, which the ticket had recorded as infeasible; `part_palette_test` switched from adjacent to all pairs, and checked against the palette it replaces. |

### Standing constraints

- **Nothing in the suite renders a pixel.** v1.0's drives repeatedly found defects the tests had
  nothing to say about, and this map's own record is the same — the tokens palette and the float
  matrix colour were both corrected by driving, within the hour, against a green suite. **A visual
  phase is not finished by a green suite.**
- **But more is testable than it looks.** `part_palette_test` catches a genuinely visual defect
  while rendering nothing, by asserting the *property*. Phase 4's own work went in the same way:
  which cell holds focus, where the caret sits, and the scroll offset before and after a drag.
  Reach for that before reaching for a drive; what is left over is genuinely only *feel*.
- `docs/DESIGN.md` is why, `docs/HISTORY.md` is what happened. Both survive from v1.0 and are
  still authoritative.
- §7.10's copy-in rule is the precedent for what a stored run must carry to stay readable.
