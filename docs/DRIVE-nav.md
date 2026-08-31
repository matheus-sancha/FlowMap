# Phase 3 — the drive sheet, 2026-08-30

The evidence phase 3 owes. Nothing in the suite renders a pixel, and this phase changes what is
drawn and where it lives — so the 1,007 tests say nothing about it beyond the arithmetic in
`workspace_tabs_test.dart`.

`docs/TODO.md` phase 3 is the source. Fold the result back into it and delete this file.

## Session header

```
build label   0.1.0-2026-08-30c
db.open line  22:07:56 db.open schema 28 from 28
session start 2026-08-30 22:07:56
host          Desktop / windows 10.0 build 26200 / locale en_US
```

| | |
|---|---|
| branch / HEAD | `v2.0` @ `bcdd238`, tree clean |
| `flutter analyze` | **clean** |
| tests | **1,007 passing** |
| schema, live database | **v28** |

## What was reported, and what the log says

**Reported correct for the group.** One answer for the whole sheet, not five — which §5.3 is the
standing warning about, and which phase 1's own sheet recorded a fortnight's worth of the same.

**But this phase leaves a trace that a group answer cannot blur.** §15's route breadcrumbs write
every location to `log.txt`, and *the whole phase is about locations* — so for once the record of
what was actually reached is objective, and it is this:

```
22:07:56  /projects
22:08:33  /projects/<p>
22:08:39  /projects/<p>/simulation/overview
22:08:42  /projects/<p>/studies/<s>/flow
22:08:43  /projects/<p>/simulation/overview
22:08:53  /projects/<p>/simulation/plan
22:08:54  /projects/<p>/simulation/overview
22:08:55  /projects/<p>/simulation/plan
22:08:55  /projects/<p>/simulation/gantt
22:08:57  /projects/<p>/simulation/plan
22:08:57  /projects/<p>/simulation/gantt
22:09:01  /projects/<p>/simulation/plan
22:09:02  /projects/<p>/simulation/occupation
22:09:02  /projects/<p>/simulation/float
```

> **Corrected 2026-08-30, after the field reported "the tabs of study and simulation are not
> working".** Everything below this line about what the log *establishes* was wrong, and the way it
> was wrong is worth more than the entry it replaces.
>
> **The tabs were dead.** `/studies/:s` and `/simulation` each carried a redirect so a bare location
> resolves to its first tab — and **a route-level redirect fires for the route's own sub-routes as
> well as for itself**, so both of them caught every child on the way past. `/studies/:s/settings`
> was sent back to `/flow`; all five results tabs back to `/overview`. Every tab in the app changed
> the URL and snapped back within the frame.
>
> **And this sheet read that as success.** §15's breadcrumbs log
> `routeInformationProvider.value` — the location that was *asked for*, not the one that resolved —
> so a trace showing five results tabs was recording five requests and one arrival. The lesson is
> narrow and worth keeping: *a log of intentions is not a log of outcomes*, and this file leaned its
> whole conclusion on one without noticing which it was.
>
> Fixed by guarding both redirects on the bare path (`state.uri.path != bare` returns null).
> `test/app/router_redirect_test.dart` holds it down, and asserts the unguarded shape fails so the
> reason for the guard is on the record. It checks the **body**, not just the location — checking
> the location alone is exactly what this sheet did.

That the log reads like this **is itself the phase's headline claim passing.** Before phase 3 the
five results views shared one location and the five study tabs shared another, so a session spent
entirely inside the run wrote `route /projects/<p>/simulation` once and said nothing further. Every
line above is a screen that had no URL yesterday.

### Established

- **All five results locations, requested** — `overview`, `plan`, `gantt`, `occupation`, `float`.
  *Requested, not reached*: see the correction above. What this line originally claimed — "and
  rendered", "each tab draws" — the log could never have said, and was false when it was written.
  The strip's taps do fire and each does write its own location, which is the half that was real.
- **The mode switch, both ways.** `simulation/overview` → `studies/<s>/flow` → `simulation/overview`
  at 22:08:42–43 is the switch being used in one direction and back.
- **A study location resolves to a tab.** `studies/<s>/flow` is what the log holds, and Flow is
  where the reader ended — which is the behaviour `_StudyTabs.didUpdateWidget` used to arrange by
  hand. *The reasoning originally given for this was itself the mistake*: it said go_router "reports
  the location after redirect", which is exactly backwards and is why the four lines above it were
  misread. The conclusion survives its argument here only because Flow is where an unguarded
  redirect sent everything anyway.

### Not established, and named rather than assumed

- **Four of the five study tabs were never opened.** `settings`, `capacity`, `demand` and `summary`
  have no line in the log. They are the same one-line `switch` arm as Flow and the same
  round-tripped slug, so there is little reason to expect trouble — but *little reason to expect
  trouble is not evidence*, and the **period control being hidden rather than greyed** is only
  observable on them. That check did not happen.
- **`?study=` surviving a tab change is not in the log**, because §15 records `uri.path` and drops
  the query — deliberately, per the ids-only rule. So the one thing phase 3 had to be careful about
  on the way in is the one thing its own breadcrumbs cannot confirm. It is asserted nowhere else
  either.
- **Light mode.** Pinned to this phase because it is where the most screens change at once, and
  unverified since the tokens drive. A group *"looks right"* does not say a theme was toggled, and
  nothing in the log would show it.

## What a follow-up sitting owes

Small, and worth doing before phase 4 builds on this:

1. The four unopened study tabs, looking at the **period control** — present on Flow and Summary,
   **absent** on Settings, Capacity and Demand.
2. `?study=` on the way in and across a tab change: arrive from a study, move Overview → Plan →
   Gantt, and confirm the filter is still that one study rather than the whole run.
3. Light mode, on the results' five tabs and the readiness strip — the strip paints
   `errorContainer` over `onErrorContainer`, which is the pairing most likely to be wrong in the
   theme that has not been looked at.
