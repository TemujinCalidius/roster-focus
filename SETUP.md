# RosterFocus — Setup

Drive your iOS Focus modes from your shift calendar(s), using an always-on Mac
as the orchestrator. The Mac sets the Focus; your iPhone inherits it.

This guide walks through it end-to-end. It looks long because it's thorough —
the actual work is about ten minutes.

> **Headless Mac mini? Read this first.** Granting Calendar access and building
> Shortcuts both require a **logged-in graphical session** — macOS will not show
> the permission prompt to a plain SSH/headless process, and there's no
> command-line way to author the Shortcuts. On a headless mini, **Screen Share
> in once** to do the one-time setup (steps 2 and 5). After that the launchd
> agent runs fine unattended. Run `rosterfocus.py --doctor` any time to see what
> still needs doing.

---

## 0. Easiest path: the installer

From the cloned repo:

```bash
./install.sh
```

It does two things:

1. **File setup** — creates a Python venv with the EventKit bindings, copies the
   example config to `~/.config/roster-focus/config.json`, and writes a launchd
   agent (`~/Library/LaunchAgents/com.rosterfocus.agent.plist`) **with the real
   interpreter and script paths already filled in**.
2. **Guided setup** (when run in a terminal) — then walks you through the manual
   macOS steps no script can do: creating the **Work** Focus, adding the
   Shortcuts, and granting Calendar access, opening the right places for you and
   verifying each with `--doctor`. It asks before loading the launchd agent.

Run `./install.sh --no-guide` to do only the file setup and get a printed
checklist instead. The numbered sections below are the fully manual path and
explain exactly what the guided installer is doing.

> **Do this on the Mac itself or over Screen Sharing — not plain SSH.** macOS only
> shows the Calendar permission prompt, and only lets you create a Focus / build
> Shortcuts, in a graphical login session.

## 1. Prerequisites

**On the iPhone (and the Mac):**

- **Settings → Focus → Share Across Devices = ON** on *both* devices. This is what
  lets a Focus set on the Mac propagate to the phone. Without it, nothing reaches
  your iPhone.

**Create the Focus you want to drive (on the Mac):**

- RosterFocus toggles a Focus *mode* — **it cannot create one** (Apple exposes no
  API, Shortcut, or AppleScript to define a Focus). Create it yourself, once:
  **System Settings → Focus → `+` → Work**. Apple's built-in **Work** suggestion is
  ideal — it gets the `com.apple.focus.work` identifier the prebuilt Shortcuts
  target. The Focus *name* must match the `focus` you reference in your config.
- Repeat for any other Focus you plan to use (Do Not Disturb already exists).

**Have a shift calendar:**

- One or more calendars containing your shift events. The calendar *names* must
  match what you put in `config.json` (e.g. `Work`, `On-Call`). Any calendar that
  syncs to your Mac works — iCloud, Google, Exchange, etc.

> Tip: a dedicated `Work` calendar you drop shifts into is cleanest, but you can
> also point a rule at an existing calendar and use a `keyword` to match only
> certain events (see step 4).

## 2. Build your Shortcuts (on the Mac)

> **Shortcut for the Work Focus:** if you use the built-in **Work** Focus, you can
> skip the manual build — import the prebuilt pair in [`shortcuts/`](shortcuts/)
> (`open "shortcuts/Work Focus On.shortcut"` → *Add Shortcut*). See
> [shortcuts/README.md](shortcuts/README.md). For any other Focus, build it by hand below.

Open **Shortcuts.app**. For **each Focus** you want to automate, create a matching
pair of shortcuts. These are the only thing that can actually flip a Focus — the
script just calls them by name.

**"Work Focus On"**
- Add action **Set Focus** → choose **Work** → **Turn On** → *Until Turned Off*.

**"Work Focus Off"**
- Add action **Set Focus** → choose **Work** → **Turn Off**
  (or use the **Turn Off Focus** action).

Repeat for any other Focus (e.g. *DND On* / *DND Off*, *Fitness Focus On/Off*).
The shortcut names must exactly match the `on_shortcut` / `off_shortcut` values
in your config.

Test each by running it manually — confirm your iPhone's Focus follows within a
few seconds.

## 3. Install the script (skip if you ran install.sh)

The EventKit bindings won't install into the system `python3` on modern macOS, so
use a venv and point everything at that interpreter:

```bash
cd /path/to/roster-focus
python3 -m venv .venv
.venv/bin/pip install pyobjc-framework-EventKit
```

From here on, `python3` below means **`.venv/bin/python`** — that's the
interpreter that has the bindings, and the one launchd must run. (You can also
`pip3 install --break-system-packages pyobjc-framework-EventKit` against the
system Python, but the venv is cleaner.)

## 4. Create your config

```bash
mkdir -p ~/.config/roster-focus
cp config.example.json ~/.config/roster-focus/config.json
```

Edit `~/.config/roster-focus/config.json`. Each entry in `rules` maps a calendar
to a Focus:

| Key | Meaning |
|-----|---------|
| `calendar` | Exact name of the calendar to watch |
| `keyword` | Optional. Case-insensitive substring of the event *title*; `""` matches any event |
| `focus` | A label for this Focus (used to track state and pick the off-shortcut) |
| `on_shortcut` / `off_shortcut` | The Shortcut names from step 2 |
| `lead_minutes` | Start the Focus N minutes *before* the event |
| `trail_minutes` | Hold the Focus N minutes *after* the event ends |

**Rules are evaluated top to bottom** — the first rule with an event active right
now wins (iOS allows only one Focus at a time). Put higher-priority Focuses first.
If no rule is active, all Focuses are turned off.

> The example config uses `_comment` keys for inline notes — they're ignored by
> the script, so you can leave them in or delete them.

## 5. Grant Calendar access and test (no Shortcuts required yet)

Run it once from Terminal so macOS shows the **Calendar access** prompt — grant it.
The `--list-calendars` flag is the easiest first check: it verifies access and
prints the exact calendar names to put in your config.

```bash
python3 ~/Scripts/rosterfocus.py --list-calendars
```

Then do a **dry run** — this evaluates your rules against the real calendar and
prints what it *would* do, without running any Shortcut or changing any Focus.
Add `-v` to see which events matched:

```bash
python3 ~/Scripts/rosterfocus.py --dry-run -v
```

If a shift is on your calendar right now you'll see `desired='Work'` (or whichever
Focus); otherwise `desired='none'`.

Once you've also built your Shortcuts (step 2), `--doctor` checks the whole setup
in one shot — calendar permission, that each configured calendar exists, and that
each Shortcut name resolves:

```bash
python3 rosterfocus.py --doctor
```

When that's all `[OK ]`, a normal run does the real toggle:

```bash
python3 rosterfocus.py
```

It prints `focus -> Work` (or `none`). Run it again and it prints nothing — that's
correct, it only acts on a *change*.

> `--validate` checks just your config (no Calendar/Shortcuts needed), so you can
> debug rules on any machine.

## 6. Schedule it with launchd (every 60s)

If you ran `install.sh`, the agent is already written with the right paths —
just `launchctl load` it (below). Otherwise copy the template and edit the two
`<string>` paths:

```bash
cp com.rosterfocus.agent.plist ~/Library/LaunchAgents/
# edit ~/Library/LaunchAgents/com.rosterfocus.agent.plist, both <string> entries:
#   - the interpreter: your VENV python  (e.g. /path/to/roster-focus/.venv/bin/python)
#     — NOT `/usr/bin/python3`; the system Python lacks the EventKit bindings.
#   - the script:      /path/to/roster-focus/rosterfocus.py
```

Load it:

```bash
launchctl load ~/Library/LaunchAgents/com.rosterfocus.agent.plist
tail -f /tmp/rosterfocus.out.log   # watch it work
```

To stop it later:

```bash
launchctl unload ~/Library/LaunchAgents/com.rosterfocus.agent.plist
```

---

## Caveats / troubleshooting

- **Calendar permission (the #1 first-run gotcha).** macOS only shows the Calendar
  prompt to a process attached to a **logged-in graphical session** — so you must
  run `--list-calendars` once from **Terminal.app in a real login session** (or
  over Screen Sharing on a headless mini) and click **Allow Full Access**. A plain
  SSH/headless run, or a launchd job, can't raise the prompt and will report
  `calendar access denied` instantly. Note the **Privacy & Security → Calendars**
  pane has no "add" button — it only lists apps that have already prompted, so you
  can't pre-authorize an interpreter there; you must let it prompt once.
  Run `--doctor` to see the exact authorization state (`NotDetermined`, `Denied`,
  `Authorized`, …) and what to do about it.
  **Good news:** this interactive grant is needed only **once**. After it, the
  launchd agent running the *same* venv python inherits the access and runs
  unattended — confirmed on a headless Mac mini, toggling both ways on the 60s
  timer with no further prompts.
- **launchd says `calendar access denied` after granting?** The grant is tied to
  the interpreter binary, so the agent must run the **exact same** venv python you
  ran `--list-calendars` with — not `/usr/bin/python3` or a different venv. Point
  the plist at that interpreter (install.sh does this for you) and reload the agent.
- **"none of the configured calendars were found".** The `calendar` name in your
  config must match the calendar title exactly (case-sensitive). RosterFocus
  fails safe here — if it can't read any configured calendar it does nothing
  rather than turning every Focus off.
- **Sync lag.** Focus changes set on the Mac typically reach the iPhone in
  seconds, occasionally up to ~a minute. Fine for shift boundaries.
- **Manual overrides.** The script only acts on a *state change*, so if you kill
  the Focus mid-shift it stays off until the next shift starts/ends. To make it
  re-assert on every poll instead, remove the `if current == desired: return`
  early-return in `rosterfocus.py`.
- **Switching Focuses.** When one shift ends and a higher/lower-priority one is
  active, RosterFocus turns the old Focus off and the new one on in the same run.
- **Overnight / multi-day shifts.** Handled — the poller looks ±24h around now,
  so a shift that crosses midnight still registers as active.
- **Config / state location.** Override with `ROSTERFOCUS_CONFIG` and
  `ROSTERFOCUS_STATE` environment variables if you want them elsewhere. State is
  stored at `~/.config/roster-focus/state.json`.
