# FlowMap — what is next

Working state as of 2026-08-04. `docs/DESIGN.md` remains the source of truth for *why*; this file
is only a plan, and each item should be deleted from it as it lands.

Branch `m1-m2-foundation`, clean, `flutter analyze` clean, 473 tests passing, not pushed.
Schema is at **v11**. M4 is code-complete.

---

## 1. Verify in the running app

The rest of this has not been driven by hand — it is covered by unit, repository and mounting tests
only.

- [x] ~~**Upgrade a real database.**~~ Done 2026-08-05. It was at v6 with v8-shaped tables from an
      upgrade that had died part-way, and the app could not open it at all; §16.11 has the fix and
      the fixture. It now migrates v6 → v11 with everything intact. A backup of the pre-migration
      file is beside it as `flowmap.sqlite.backup-20260805-054746` — delete it once you are happy.
- [ ] **Flag a study.** `Célula 11B` has `include_in_simulation = 0`, so the Simulation tab
      correctly reports that nothing is selected. Nothing has run against real data yet.
- [ ] **The pool fix, against célula 11B.** A pool's occupation should now be roughly `1/N` of what
      it read before, where N is the number of members. The flow equivalent should be unchanged.
- [ ] **MM3's two columns** — `Equivalent` (per part, does not move between orders) and `Slot load`
      (= equivalent × batch, what MM3 averages).
- [ ] The canvas: push arrows meeting the inventory triangle, the triangle centred on the spine, the
      `#N` chip on a pool box, the `Takt C/T` row, the sidebar toggle on the left.
- [ ] **A real run.** Flag a study, press Simulate, and check the readiness panel names the right
      study when something is missing. Then check the run survives closing the app, and that
      `log.txt` carries its `sim.run` line with the elapsed time.

---

## 2. Known gaps, deliberately left

- [ ] **§14's performance target is not met.** A 2000-order, 10-step run takes ~2.8 s against "well
      under a second". §16.9 has the measurements: the cost is local `DateTime` arithmetic on
      Windows (~13 µs per construction, versus 0.03 µs for the UTC equivalent). Closing it means
      working in epoch integers inside `WorkingCalendar` and converting only at its edges — a real
      refactor of the most heavily tested code in the app. Worth doing deliberately.
- [ ] **§18.3 is still open**: takt changes mid-flight. A run keeps one release cadence throughout,
      resolved at its start by the second assembly pass (§16.10).
- [ ] **§18.5 is still open**: empty slots as a reported metric. They are counted, dated, stored and
      shown on the Simulation tab; what is missing is a decision about whether anything more should
      happen — a list of *which* slots, and whether an empty slot should ever be a warning.
- [ ] **§11.1's tail warning is not shown.** A run that completes past the last defined schedule
      period carries the last one forward, and the user is not told. The engine does the right
      thing; nothing reports it.
- [ ] **The decorative layer (§5.2)** and **`DiagnosticsLog.compose`** are still built-but-unreachable,
      both wanted by M5. Listed in §17.5.

---

## 3. M5

Reports (§13), run comparison, templates and binding (§10.2), the About screen, and the drop.

Run comparison has what it needs: two `StoredRun`s report through the same `summariseRun`, so the
figures on either side of a comparison cannot have been computed two different ways.
