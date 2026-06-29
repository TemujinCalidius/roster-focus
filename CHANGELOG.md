# Changelog

All notable changes to RosterFocus are documented here.

## [0.2.1] — 2026-06-30

### Added
- Prebuilt, signed **Work Focus On/Off** shortcuts under `shortcuts/`, so you can
  import the pair instead of hand-building them. Includes editable XML sources, a
  `build.sh` to re-sign, and a README covering the Focus-identifier caveat.
  Verified on a Mac mini: both import bound to the built-in Work Focus and toggle
  it on/off.

## [0.2.0] — 2026-06-30

First version verified end-to-end on a real always-on Mac mini (calendar → Focus
decision → Shortcut → iPhone via Share Across Devices, including unattended
operation under launchd).

### Added
- `--doctor`: one-shot health check — Calendar authorization status (with the
  reason and fix), that each configured calendar exists, and that each Shortcut
  name resolves.
- `--validate`: config-only check that needs neither Calendar nor Shortcuts, so
  rules can be debugged on any machine.
- `--list-calendars`, `--dry-run`, `--verbose`, `--version`.
- `install.sh`: creates the venv + EventKit bindings, scaffolds the config, and
  writes the launchd agent with the real interpreter + script paths filled in.

### Fixed
- **Silent shortcut failure.** `run_shortcut` now verifies the name against
  `shortcuts list` and treats error output as failure, and the poller no longer
  records state when a toggle fails — so a mistyped Shortcut name can't become a
  permanent silent no-op. It retries on the next poll and self-heals.
- EventKit is imported lazily, so `--help`/`--version` work without the bindings.

### Documented
- The headless/launchd Calendar-permission reality: the one-time interactive
  grant must come from a GUI session, the Privacy pane has no "add" button, and
  the grant is per-interpreter. Confirmed that the launchd agent inherits the
  grant once given.

### Confirmed by testing
- launchd inherits the Calendar grant; unattended 24/7 operation works.
- Focus set on the Mac propagates to iPhone; turning a Focus off is effectively
  instant across devices.

## [0.1.0] — 2026-06-30

Initial release.

- Poll one or more named calendars via EventKit; pick a Focus by priority-ordered
  rules in `config.json`; run the matching macOS Shortcut; Focus syncs to iPhone
  via Share Across Devices.
- Keyword matching, lead/trail padding, manual-override tolerance (acts only on a
  state change).
- launchd template, README, and SETUP guide.
