# FlowMap

FlowMap is a Value Stream Mapping builder and simulator used by manufacturing engineers and
planners during load vs. capacity studies. Local-first Flutter desktop app for Windows, shipped as
a zip a user unpacks anywhere and runs.

**[docs/DESIGN.md](docs/DESIGN.md) is the source of truth for intended behaviour.** Read it before
changing anything, and update it in the same commit that changes behaviour. Code cites it by
section (`DESIGN.md §7.6`). What is next lives in [docs/TODO.md](docs/TODO.md), what happened in
[docs/HISTORY.md](docs/HISTORY.md).

## Download

**[Latest release](https://github.com/matheus-sancha/FlowMap/releases/latest)** — download the
`FlowMap-<version>.zip`, unzip it anywhere (or over the previous version), and run `flowmap.exe`.
No installer and no admin rights. `READ ME FIRST.txt` and `manual.html` are inside the zip.

Unzipping a new version over the old one is safe: projects, templates and settings never live in the
program folder.

**Unblock the zip before you unzip it** — right-click it, Properties, tick *Unblock*. Windows marks
everything it downloads and Explorer copies that mark onto every extracted file, and that mark is
what raises *"Windows protected your PC"*. The drop carries no publisher signature yet, so if the
prompt does appear, *More info → Run anyway* is the way past it. **[docs/SIGNING.md](docs/SIGNING.md)
is why, what it costs to stop it for good, and how the packaging script signs a drop once there is a
certificate.**

## Status

| Milestone | Contents | |
|---|---|---|
| M1 | Resources, shift patterns, calendar engine | ✅ |
| M2 | Projects, studies, VSM flow canvas, takt & workcenter schedules, PDF map | ✅ |
| M3 | Demand grids, Excel import, flow equivalent, MM3, Summary | ✅ |
| M4 | Simulation engine, run storage, metrics, bottlenecks | ✅ |
| M5 | Reports, run comparison, templates, project documents, drop | ✅ v2.1 |

| Drop | Date | |
|---|---|---|
| **2.1.2** | 2026-09-13 | Saved templates appear on the shelf; simpler Projects page |
| 2.1.1 | 2026-09-13 | Fixes two ways a project file could be emptied; plant name on New project; move a project to another plant; opening screen |
| ~~2.1.0~~ | 2026-09-13 | **Withdrawn** — switching or creating projects could empty the file being left |

## Working on it

```bash
flutter pub get
dart run build_runner build     # Drift + Riverpod codegen; output is committed
flutter gen-l10n                # ARB -> AppLocalizations; output is committed
flutter analyze
flutter test
flutter run -d windows
```

Every user-facing string lands in all three locales (`app_en.arb`, `app_es.arb`, `app_pt.arb`) in
the same commit; `l10n_test.dart` fails the build if `lib/src/l10n/untranslated.json` is not empty.

## Shipping a drop

From a clean tree, after `flutter analyze` and `flutter test`:

```powershell
powershell -ExecutionPolicy Bypass -File tool\package_windows.ps1 -Label 2.1.2-2026-09-13 -Tag v2.1.2
```

It refuses a dirty tree, an existing tag, or a `version:` in `pubspec.yaml` that disagrees with the
label — that version is what Windows reads off `flowmap.exe`. Then it builds release with the label,
adds the Visual C++ runtime and `tool/drop/` (readme, manual, example), **signs the staged folder if
a certificate was given**, zips to `dist/`, and prints the SHA-256 and the `git tag` command. It does
not tag or publish.

Add one of these to sign the drop, which is what stops Windows calling the publisher unknown
([docs/SIGNING.md](docs/SIGNING.md)); without one it still packages, and says what that costs:

```powershell
  -AzureSignDlib C:\ats\bin\x64\Azure.CodeSigning.Dlib.dll -AzureSignMetadata C:\ats\metadata.json
  -CertificateThumbprint A1B2C3D4E5F6...        # a token, or the current user's store
  -CertificatePath C:\certs\flowmap.pfx         # password from $env:FLOWMAP_CERT_PASSWORD
```

Then:

```bash
git tag -a v2.1.2 -m "FlowMap 2.1.2-2026-09-13" <commit>
git push origin v2.1.2
gh release create v2.1.2 dist/FlowMap-2.1.2-2026-09-13.zip --title "FlowMap 2.1.2" --notes-file notes.md --verify-tag
```

The link users get is
`https://github.com/matheus-sancha/FlowMap/releases/download/<tag>/FlowMap-<label>.zip`.
**The repository and its releases are public.**

### Building it without a Windows machine

`flutter build windows` is CMake and MSVC, so a zip can only be produced on Windows.
`.github/workflows/windows-drop.yml` is that machine for anyone who has not got one: it builds on
`windows-latest` and attaches `FlowMap-<label>.zip` as a workflow artifact.

- **Every push** produces a throwaway build labelled `<version>-<date>-<sha>`. `analyze` and `test`
  run and are reported, but do not gate the zip — the point of that run is to put a build in your
  hands. Download it from the run's **Artifacts**, and note that GitHub wraps an artifact in a zip
  of its own, so unblock the **inner** zip.
- **Run workflow → type a label** produces a real drop, and then every refusal in the packaging
  script applies and a red `analyze` or `test` stops it.
- **It does not tag and does not publish a release**, for the same reason the packaging script does
  not: a build machine should not create refs or put a zip in front of users.
- **The runner bills Windows minutes at a multiple of Linux ones.** If every-push is too much,
  narrow `on.push.branches` and lean on *Run workflow* instead.
- **Signing in CI** is two commented lines in the Package step, and Azure Trusted Signing is the
  route that works there because there is no token to plug in ([docs/SIGNING.md](docs/SIGNING.md)).

The build label is what the diagnostics log and the About screen report; it is supplied at compile
time rather than read from `pubspec.yaml`, so a field report can be placed against a specific zip.
`tool/drop/example.flowmap` is rebuilt from the live plant by
`flutter test test/tools/make_example.dart`.

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

**A project is a `.flowmap` file** (#37): a zip carrying one project and the plant it runs on, kept
wherever the user puts it — by default `Documents\FlowMap\`, often a OneDrive or network folder, and
handed to a colleague like any other file. There is no Save button: the open project is written
through to its file a couple of seconds after each change.

- **One writer at a time.** An open project holds `<name>.flowmap.lock` beside its file, refreshed
  every minute and stale after five, so a crash frees it on its own.
- **A file is only saved over while it is still the file FlowMap opened.** If it is renamed over,
  restored or synced in while open, FlowMap stops saving and, when the project is left, keeps the
  work beside it as `<name> (conflict <date> <time>).flowmap`.
- **Templates** are `.flowtemplate` files in `Documents\FlowMap\Templates\` — one study's flow, applied
  to any project by matching workcenters by name.

`%APPDATA%\Roaming\com.sancha\flowmap\` holds `flowmap.sqlite` (the working copy of whichever project
is open, plus stored simulation runs, which stay on the machine that made them), `log.txt` and
`window.json`. Deliberately not Documents: OneDrive's Known Folder Move syncs that, and a sync client
uploading a live SQLite file mid-write can corrupt it — which is why a project on OneDrive is a file
written whole and renamed into place, never the database itself.
