# Contributing to RosterFocus

Thanks for your interest in contributing! RosterFocus drives macOS/iOS **Focus** modes from
your shift calendar. It ships in two forms that share one config file:

- **`rosterfocus.py`** — a Python CLI + `launchd` agent (best for headless Macs).
- **`app/`** — a native SwiftUI **menu-bar app** (best for everyone else).

Both read the same `~/.config/roster-focus/config.json` and make the same decisions.

## How it works (and what it can't do)

Apple gives apps **no API to create a Focus or to turn one on/off** — only the **Shortcuts**
app can toggle a Focus. So RosterFocus reads the calendar, decides which Focus should be on,
and runs a user-built Shortcut; the Focus then syncs to iPhone via *Share Across Devices*.
Keep that boundary in mind: we orchestrate Shortcuts, we don't replace them.

## Prerequisites

- **macOS 14+** and an Apple Account with the Calendar app set up.
- **Python 3** with `pyobjc-framework-EventKit` (for the CLI): `pip3 install pyobjc-framework-EventKit`.
- **Xcode 16+** and **[XcodeGen](https://github.com/yonyz/XcodeGen)** (`brew install xcodegen`)
  for the app. The committed `app/RosterFocus.xcodeproj` is generated from `app/project.yml`.
- **Git.**

## Local development

**CLI:**
```bash
python3 rosterfocus.py --validate          # config-only check, no system access
python3 rosterfocus.py --list-calendars    # grant Calendar access; list calendars
python3 rosterfocus.py --doctor            # health check
python3 rosterfocus.py --dry-run -v        # decide against the real calendar; no toggling
```

**App:**
```bash
cd app
xcodegen generate                          # refresh the .xcodeproj from project.yml
./scripts/build-local.sh                   # build + ad-hoc sign into app/build/
xcodebuild test -project RosterFocus.xcodeproj -scheme RosterFocus \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO   # run the unit tests
```

The app's decision logic lives in the `RosterFocusCore` framework and is unit-tested without a
GUI host (`RosterFocusTests`). If you change `Decider`, `Config`, `Rule`, `FocusStateFile`, or
the shortcut parsing, add/extend a test.

## Code style

- **Swift:** match the surrounding code; keep the pure logic in `RosterFocusCore` (testable,
  no UI) and the UI thin. Run subprocess/EventKit work off the main actor.
- **Python:** match `rosterfocus.py` — standard library only on the hot path, fail-loud on
  Shortcut errors, fail-safe when a calendar can't be read.
- **Keep the two in sync.** The Swift port must match the CLI's behavior (priority order,
  keyword matching, lead/trail, act-only-on-change). There are tests that assert this.

## Branching model

RosterFocus uses two long-lived branches:

- **`dev`** — the active development / integration branch. **All code changes land here.**
- **`main`** — the stable, released branch. It moves when maintainers cut a release (merging
  `dev` → `main`) or for **documentation-only** changes.

**In short: code → `dev`, docs → `main`.** Use branch prefixes: `feat/*`, `fix/*`, `docs/*`.

`main` is the default branch, so a fresh PR targets `main` — **retarget code PRs to `dev`.**

## Making a pull request

1. **Fork**, then branch from the right base — `dev` for code, `main` for docs-only:
   ```bash
   git checkout -b feat/my-feature dev      # code
   # git checkout -b docs/my-fix main        # documentation only
   ```
2. Make your change. For code, run the tests above and keep `--doctor` honest.
3. **Add a `CHANGELOG.md` entry** under `## Unreleased` (CI enforces this; apply the
   `skip-changelog` label for trivial/docs-only changes).
4. Open the PR against the right base. CI runs the Swift tests + Python checks.

## Cutting a release (maintainers)

1. Merge `dev` → `main` (a **merge commit**, so the branches stay in sync).
2. Promote `## Unreleased` in `CHANGELOG.md` to the new version.
3. Build the notarized installer locally (CI doesn't hold the Developer ID signing secrets):
   ```bash
   cd app && ./scripts/package-notarize.sh      # → app/build-release/RosterFocus.dmg
   ```
4. Tag and publish, attaching the DMG (the `release.yml` workflow auto-posts the
   announcement to Discussions, so you don't pass `--discussion-category`):
   ```bash
   gh release create vX.Y.Z app/build-release/RosterFocus.dmg \
     --title "RosterFocus vX.Y.Z" --notes-file <notes> --latest
   # add --prerelease for an rc, e.g. vX.Y.Z-rc1
   ```

Thanks again — and welcome aboard. 🌙
