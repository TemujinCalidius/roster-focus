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
  `Gym → Fitness`. (Adding one is three steps — see
  [Adding more Focus modes](SETUP.md#adding-more-focus-modes).)
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

## What you need first

A few things only **you** can do — macOS provides no API to script them, so the
installer guides you through them rather than doing them silently:

- **A Mac that's always on**, signed into your iCloud/Apple Account (macOS 12+).
- **An iPhone** on the same Apple Account.
- **A Focus named `Work`** on the Mac. ⚠️ **Software cannot create a Focus** —
  there's no API, Shortcut, or AppleScript for it. You create it once in
  **System Settings → Focus → `+` → Work** (Apple's built-in "Work" suggestion is
  ideal — the prebuilt Shortcuts target it). The Focus *name* must match your config.
- **A pair of Shortcuts per Focus** (e.g. *Work Focus On* / *Work Focus Off*) —
  the only sanctioned way to flip a Focus. For the built-in Work Focus you can
  **import the prebuilt ones** in [`shortcuts/`](shortcuts/) instead of building them.
- **Settings → Focus → Share Across Devices = ON** on *both* devices — this is
  what carries the Focus from the Mac to your iPhone.

## Quick start

```bash
git clone https://github.com/TemujinCalidius/roster-focus.git
cd roster-focus
./install.sh        # sets up the venv/config/agent, then guides you through the rest
```

`./install.sh` creates the Python venv + EventKit bindings, scaffolds your config,
writes the launchd agent **with the right paths filled in**, and then — when run
in a terminal — **walks you through the manual macOS steps above**, opening the
Focus settings and Shortcuts for you and verifying each step with `--doctor`.
Use `./install.sh --no-guide` to just set up files and get a printed checklist.

> On a **headless Mac mini**, run the installer over **Screen Sharing**, not plain
> SSH — macOS only shows the Calendar prompt and lets you build Shortcuts in a
> graphical login session. After that one-time setup, the launchd agent runs
> unattended (it inherits the Calendar grant). See [SETUP.md](SETUP.md) for the
> fully manual path and troubleshooting.

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

- An always-on Mac (macOS 12+; macOS 14+ uses the newer Calendar permission API),
  signed into your Apple Account with the Calendar app set up.
- Python 3 (the installer builds a venv with `pyobjc-framework-EventKit`).
- An iPhone on the same Apple Account with *Share Across Devices* on.
- A Focus mode and a matching Shortcut pair per Focus (see *What you need first*).

### Why can't it just create the Focus / set it directly?

Two deliberate Apple restrictions, and RosterFocus works within both:

1. **No app can create a Focus mode.** There's no public API, Shortcut action, or
   AppleScript to define one. The definitions live in an undocumented, sandbox-
   protected database. So you create the Focus yourself, once, in System Settings.
2. **No app can turn a Focus on/off directly** — only the **Shortcuts** app can.
   RosterFocus therefore runs a Shortcut to do the toggle, rather than setting the
   Focus itself.

Everything else (deciding *when* to toggle, from your calendar) is automated.

## How it differs from similar tools

There are a couple of good projects that activate macOS Focus from calendar
events ([calendar-focus-sync](https://github.com/a11rew/calendar-focus-sync),
[focus-time-app](https://github.com/focus-time/focus-time-app)), but they target
*desktop* focus for meeting/“focus time” blocks. RosterFocus is built around
**shift work** and treats the **iPhone as the target** (via Share Across
Devices), with multiple calendars mapping to multiple Focus modes.

## License

[MIT](LICENSE) © 2026 Samuel Lison
