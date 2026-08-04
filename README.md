# FlowMap

FlowMap is a Value Stream Mapping builder and simulator used by manufacturing engineers and
planners during load vs. capacity studies. Local-first Flutter desktop app for Windows, shipped as
a zip a user unpacks anywhere and runs.

**[docs/DESIGN.md](docs/DESIGN.md) is the source of truth for intended behaviour.** Read it before
changing anything, and update it in the same commit that changes behaviour. Code cites it by
section (`DESIGN.md §7.6`).

## Status

| Milestone | Contents | |
|---|---|---|
| M1 | Resources, shift patterns, calendar engine | ✅ |
| M2 | Projects, studies, VSM flow canvas, takt & workcenter schedules, PDF map | ✅ |
| M3 | Demand grids, Excel import, flow equivalent, MM3, Summary | ✅ |
| M4 | Simulation engine, run storage, metrics, bottlenecks | |
| M5 | Reports, run comparison, templates, drop | |

## Working on it

```bash
flutter pub get
dart run build_runner build     # Drift + Riverpod codegen; output is committed
flutter gen-l10n                # ARB -> AppLocalizations; output is committed
flutter analyze
flutter test
flutter run -d windows
```

Packaging a drop:

```bash
flutter build windows --release --dart-define=BUILD_LABEL=0.1.0-m1
```

The build label is what the diagnostics log and the About screen report; it is supplied at compile
time rather than read from `pubspec.yaml`, so a field report can be placed against a specific zip.

## Layout

```
lib/src/
  app/         router, shell, theme, window geometry, build label
  common/      widgets and formatters more than one feature uses
  data/        the database, the schema, the one app directory
  features/<feature>/
    data/          repositories — the only code that touches Drift
    application/   providers and every calculation
    presentation/  screens and widgets
  l10n/        one .arb per language (en, es, pt) + generated output
```

Imports point `data → application → presentation`, never back. Reads are streams off the database,
so a write anywhere refreshes every screen showing that data.

The calendar engine (`features/calendar/application/`) is pure — no Drift, no widgets — because
every number in the app is computed by walking it.

## Where the data lives

`%APPDATA%\Roaming\com.sancha\flowmap\` holds `flowmap.sqlite`, `log.txt` and `window.json`.
Deliberately not Documents: OneDrive's Known Folder Move syncs that, and a sync client uploading a
live SQLite file mid-write can corrupt it.
