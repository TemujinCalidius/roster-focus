# RosterFocus

**Turn iOS/macOS Focus modes on and off automatically from your shift calendar — no fixed schedule required.**

If you work shifts that move around (different days, different hours, different
locations), Apple's built-in time- and location-based Focus automations don't
fit. RosterFocus instead reads your **shift events from a calendar** and flips
the right Focus on while you're on shift, then off when the shift ends — wherever
you are.

```
Mac (always on) ──reads your shift calendar(s) via EventKit──▶ which Focus, if any?
        │                                                          │
        └── runs the matching Shortcut ("Work Focus On/Off") ◀─────┘
                        │
        Focus syncs to your iPhone via "Share Across Devices"
```

## Why it works this way

iOS exposes **no public API** to set a Focus directly — Apple's only sanctioned
mechanism is the **Shortcuts** app. So RosterFocus doesn't replace Shortcuts, it
*orchestrates* them:

- A small Python script runs on an **always-on Mac**, scheduled every 60s by `launchd`.
- It reads one or more named calendars via **EventKit** and decides which Focus
  should be active right now.
- It runs the macOS **Shortcut** that actually toggles the Focus.
- The Focus then **propagates to your iPhone** through
  *Settings → Focus → Share Across Devices*.

Running the poll on the Mac sidesteps the background-execution limits that make a
pure iPhone/Shortcuts automation unreliable, and keying off calendar *events*
(not clock times) is what makes it work for irregular shift work.

## Features

- **Shift-aware.** Triggers on calendar *events*, so it handles variable days,
  hours, and overnight/multi-day shifts — not fixed times.
- **Multiple Focus modes.** Map several calendars (and optional title keywords)
  to different Focus modes — e.g. `On-Call → Do Not Disturb`, `Work → Work`,
  `Gym → Fitness`.
- **Priority ordering.** iOS allows one Focus at a time; rules are evaluated
  top-to-bottom and the first active one wins.
- **Lead / trail padding.** Start a Focus a few minutes before a shift, or hold
  it for a while after.
- **Respects manual overrides.** Only acts on a *state change*, so if you turn a
  Focus off mid-shift it stays off until the next calendar boundary.
- **Config in JSON.** Set everything up by editing `config.json` — never the code.

## Contents

| File | Purpose |
|------|---------|
| `rosterfocus.py` | Core poller: reads calendars, decides the Focus, runs the Shortcut |
| `config.example.json` | Annotated config template (calendars → Focus mappings) |
| `install.sh` | One-shot installer: venv + bindings, config scaffold, launchd agent |
| `com.rosterfocus.agent.plist` | `launchd` template (runs the poller every 60s) |
| `shortcuts/` | Prebuilt, signed **Work Focus On/Off** shortcuts (import instead of hand-building) |
| `SETUP.md` | Full setup: Shortcuts, install, permissions, troubleshooting |

## Quick start

1. On your iPhone: **Settings → Focus → Share Across Devices = ON**.
2. On the Mac, build a pair of **Shortcuts** per Focus (e.g. *Work Focus On* /
   *Work Focus Off*) — these are the only thing that can actually flip a Focus.
3. Run `./install.sh` (creates the venv + bindings, scaffolds config and the
   launchd agent with real paths). Then edit `~/.config/roster-focus/config.json`.
4. `python3 rosterfocus.py --list-calendars` — grants Calendar access, confirms names.
5. `python3 rosterfocus.py --doctor` — checks access, calendars, and Shortcuts.
6. `python3 rosterfocus.py --dry-run -v` — shows what it *would* do (no toggling).
7. `python3 rosterfocus.py`, then `launchctl load` the agent to run it every 60s.

> On a **headless Mac mini**, Screen Share in for the one-time Calendar grant and
> Shortcut building — macOS won't show those prompts over plain SSH. See SETUP.md.

### Diagnostics

| Command | What it does |
|---|---|
| `--doctor` | One-shot health check: permission, calendars, Shortcut names |
| `--validate` | Check the config only (no Calendar/Shortcuts needed) |
| `--list-calendars` | Print every calendar it can see (and trigger the access prompt) |
| `--dry-run [-v]` | Decide against the real calendar without toggling anything |

Full step-by-step instructions, including the exact Shortcut actions and
troubleshooting, are in **[SETUP.md](SETUP.md)**.

## Requirements

- An always-on Mac (macOS 12+; macOS 14+ uses the newer Calendar permission API).
- Python 3 with `pyobjc-framework-EventKit`.
- An iPhone signed into the same Apple Account with *Share Across Devices* on.

## How it differs from similar tools

There are a couple of good projects that activate macOS Focus from calendar
events ([calendar-focus-sync](https://github.com/a11rew/calendar-focus-sync),
[focus-time-app](https://github.com/focus-time/focus-time-app)), but they target
*desktop* focus for meeting/“focus time” blocks. RosterFocus is built around
**shift work** and treats the **iPhone as the target** (via Share Across
Devices), with multiple calendars mapping to multiple Focus modes.

## License

[MIT](LICENSE) © 2026 Samuel Lison
