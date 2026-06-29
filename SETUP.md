# RosterFocus — Setup

Drive your iOS Focus modes from your shift calendar(s), using an always-on Mac
as the orchestrator. The Mac sets the Focus; your iPhone inherits it.

This guide walks through it end-to-end. It looks long because it's thorough —
the actual work is about ten minutes.

---

## 1. Prerequisites (one-time, on iPhone)

- **Settings → Focus → Share Across Devices = ON.** This is what lets a Focus set
  on the Mac propagate to the phone. Without it, nothing reaches your iPhone.
- One or more calendars containing your shift events. The calendar *names* must
  match what you put in `config.json` (e.g. `Work`, `On-Call`). Any calendar that
  syncs to your Mac works — iCloud, Google, Exchange, etc.

> Tip: a dedicated `Work` calendar you drop shifts into is cleanest, but you can
> also point a rule at an existing calendar and use a `keyword` to match only
> certain events (see step 4).

## 2. Build your Shortcuts (on the Mac)

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

## 3. Install the script

```bash
mkdir -p ~/Scripts
cp rosterfocus.py ~/Scripts/

# Use a Python that has the pyobjc EventKit bindings:
pip3 install pyobjc-framework-EventKit
#   On newer macOS you may need:  pip3 install --break-system-packages pyobjc-framework-EventKit
#   (or install into a venv and point launchd at that interpreter)
```

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

## 5. Grant Calendar access

Run it once from Terminal so macOS shows the **Calendar access** prompt — grant it:

```bash
python3 ~/Scripts/rosterfocus.py
```

If a shift is on your calendar right now you'll see `focus -> Work` (or whichever
Focus); otherwise `focus -> none`. Run it again and it will print nothing — that's
correct, it only acts on a *change*.

## 6. Schedule it with launchd (every 60s)

Copy the template, then edit `USERNAME` and the python path to match yours:

```bash
cp com.rosterfocus.agent.plist ~/Library/LaunchAgents/
# edit ~/Library/LaunchAgents/com.rosterfocus.agent.plist:
#   - the python3 path (run `which python3`, or your venv's bin/python3)
#   - /Users/USERNAME/Scripts/rosterfocus.py
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

- **Calendar permission under launchd.** The interpreter launchd runs may need
  Calendar access granted explicitly in **System Settings → Privacy & Security →
  Calendars**. Running it once manually first (step 5) usually seeds this. If the
  log shows `calendar access denied`, add your `python3` there manually.
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
