# FlowMap — what is next

Working state as of 2026-08-04. `docs/DESIGN.md` remains the source of truth for *why*; this file
is only a plan, and each item should be deleted from it as it lands.

Branch `m1-m2-foundation`, clean, `flutter analyze` clean, 448 tests passing, not pushed.
Schema is at **v10**.

---

## 1. Verify in the running app

None of this has been driven by hand — it is covered by unit and mounting tests only.

- [ ] **Upgrade a real database.** It will migrate v8 → v10 in one go. Check the demand tables
      survive: parts keep their numbers, orders keep their sequence and batch sizes.
- [ ] **The pool fix, against célula 11B.** A pool's occupation should now be roughly `1/N` of what
      it read before, where N is the number of members. The flow equivalent should be unchanged.
- [ ] **MM3's two columns** — `Equivalent` (per part, does not move between orders) and `Slot load`
      (= equivalent × batch, what MM3 averages).
- [ ] The canvas: push arrows meeting the inventory triangle, the triangle centred on the spine, the
      `#N` chip on a pool box, the `Takt C/T` row, the sidebar toggle on the left.

---

## 2. Finish M4

The engine, its metrics and the assembler are all built and tested. What is missing is somewhere to
put a run and somewhere to press the button.

- [ ] **Run storage (§7.10).** Schema v11: a `simulation_runs` header, one row per order-step, the
      per-order outcomes, and the frozen input snapshot. `SimRunResult` already has exactly these
      shapes — `SimOrderStep`, `SimOrderOutcome`, `SimEmptySlot` — so this is mostly a repository.
      The snapshot is what keeps a finished run explainable after the resources beneath it change
      (§3).
- [ ] **A simulation repository.** Load a project's flagged studies (§10.1 already enforces at most
      one per line), build `SimWorkcenter`s from `SchedulesRepository.loadWorkcenterCalendar`, and
      call `assembleSimStudy`. Everything it needs already exists; nothing calls it yet.
- [ ] **The Simulation tab (§12.1).** Project-level, not per study, because a run spans studies
      (§7.7). Needs: which studies are in, the dispatch rule (§7.4), a Run button, and then the
      §8 metrics — OTD, float, lead-time efficiency, empty slots, and both bottleneck rankings.
      Run it on a background isolate; `SimStudy` carries no database handle precisely so it can be.
- [ ] **Readiness before a run (§11).** The assembler already returns `SimAssemblyProblem`s; the
      panel has to show them and disable Simulate.

---

## 3. Known gaps, deliberately left

- [ ] **§14's performance target is not met.** A 2000-order, 10-step run takes ~2.8 s against "well
      under a second". §16.9 has the measurements: the cost is local `DateTime` arithmetic on
      Windows (~13 µs per construction, versus 0.03 µs for the UTC equivalent). Closing it means
      working in epoch integers inside `WorkingCalendar` and converting only at its edges — a real
      refactor of the most heavily tested code in the app. Worth doing deliberately.
- [ ] **§18.3 is still open**: takt changes mid-flight. A run currently keeps one release cadence
      throughout, resolved at its start. M4's engine is the thing that depends on it.
- [ ] **§18.5 is still open**: empty slots as a reported metric. They are counted and dated
      already; what is missing is a decision about whether anything more should happen.
- [ ] **The decorative layer (§5.2)** and **`DiagnosticsLog.compose`** are still built-but-unreachable,
      both wanted by M5. Listed in §17.5.

---

## 4. M5, when M4 is done

Reports (§13), run comparison, templates and binding (§10.2), the About screen, and the drop.
