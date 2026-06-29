#!/usr/bin/env python3
"""
RosterFocus — drive iOS/macOS Focus modes from your shift calendar(s).

iOS exposes no public API to turn a Focus on or off; the only sanctioned
mechanism is the Shortcuts app. RosterFocus therefore *orchestrates* Shortcuts
rather than replacing them:

    1. An always-on Mac polls one or more named calendars via EventKit.
    2. It decides which Focus (if any) should be active right now, using a
       priority-ordered list of rules you define in config.json.
    3. It runs the matching macOS Shortcut to flip the Focus.
    4. The Focus propagates to your iPhone via
       Settings > Focus > Share Across Devices.

Because the decision is made from calendar *events* — not fixed clock times —
this works for shift work with no set routine, regardless of location.

Run every 60s via launchd on an always-on Mac. See SETUP.md.
"""

import argparse
import json
import os
import sys
import threading
import subprocess
from datetime import datetime

__version__ = "0.2.0"

# EventKit is imported lazily (see ensure_eventkit) so that --help and other
# argument parsing work even on a machine without the pyobjc bindings installed.
EKEventStore = EKEntityTypeEvent = NSDate = None


def ensure_eventkit():
    """Import the pyobjc EventKit bindings, or exit with install guidance."""
    global EKEventStore, EKEntityTypeEvent, NSDate
    if EKEventStore is not None:
        return
    try:
        from EventKit import EKEventStore as _Store, EKEntityTypeEvent as _Type
        from Foundation import NSDate as _NSDate
    except ImportError:
        sys.stderr.write(
            "[rosterfocus] Missing pyobjc EventKit bindings.\n"
            "  Install with: pip3 install pyobjc-framework-EventKit\n"
        )
        sys.exit(1)
    EKEventStore, EKEntityTypeEvent, NSDate = _Store, _Type, _NSDate


# --------------------------------------------------------------------------
# Config loading
# --------------------------------------------------------------------------
# Config lives in JSON so you never have to edit this script. Search order:
#   1. $ROSTERFOCUS_CONFIG, if set
#   2. ~/.config/roster-focus/config.json
#   3. ./config.json (next to this script)
# See config.example.json for the schema and a worked example.

DEFAULT_CONFIG_PATHS = [
    os.environ.get("ROSTERFOCUS_CONFIG"),
    os.path.expanduser("~/.config/roster-focus/config.json"),
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json"),
]

STATE_FILE = os.path.expanduser(
    os.environ.get("ROSTERFOCUS_STATE", "~/.config/roster-focus/state.json")
)


def load_config_quiet():
    """Load the first config file that exists; raise FileNotFoundError if none."""
    for path in DEFAULT_CONFIG_PATHS:
        if path and os.path.isfile(path):
            with open(path) as f:
                return json.load(f), path
    raise FileNotFoundError("no rosterfocus config found")


def load_config():
    """Load the first config file that exists; exit with guidance if none."""
    try:
        return load_config_quiet()
    except FileNotFoundError:
        pass
    sys.stderr.write(
        "[rosterfocus] No config found. Looked in:\n"
        + "".join(f"    {p}\n" for p in DEFAULT_CONFIG_PATHS if p)
        + "  Copy config.example.json to ~/.config/roster-focus/config.json "
        "and edit it.\n"
    )
    sys.exit(1)


def normalize_rules(cfg):
    """Validate and fill defaults for each rule. Rules are in priority order:
    the first rule with an active event wins."""
    rules = cfg.get("rules", [])
    if not rules:
        sys.stderr.write("[rosterfocus] config has no 'rules'.\n")
        sys.exit(1)
    out = []
    for i, r in enumerate(rules):
        for required in ("calendar", "focus", "on_shortcut", "off_shortcut"):
            if required not in r:
                sys.stderr.write(
                    f"[rosterfocus] rule #{i} missing required key '{required}'.\n"
                )
                sys.exit(1)
        out.append(
            {
                "calendar": r["calendar"],
                "keyword": (r.get("keyword") or "").lower(),  # "" = match any event
                "focus": r["focus"],
                "on_shortcut": r["on_shortcut"],
                "off_shortcut": r["off_shortcut"],
                "lead_minutes": int(r.get("lead_minutes", 0)),
                "trail_minutes": int(r.get("trail_minutes", 0)),
            }
        )
    return out


# --------------------------------------------------------------------------
# Calendar access (EventKit)
# --------------------------------------------------------------------------
def request_access(store):
    """Block until the Calendar access prompt resolves (handler runs off-thread)."""
    done = threading.Event()
    result = {"ok": False}

    def handler(ok, err):
        result["ok"] = bool(ok)
        done.set()

    if hasattr(store, "requestFullAccessToEventsWithCompletion_"):  # macOS 14+
        store.requestFullAccessToEventsWithCompletion_(handler)
    else:
        store.requestAccessToEntityType_completion_(EKEntityTypeEvent, handler)

    done.wait(timeout=15)
    return result["ok"]


def all_calendar_titles(store):
    """Return the titles of every calendar EventKit can see, sorted, de-duped."""
    cals = store.calendarsForEntityType_(EKEntityTypeEvent) or []
    return sorted({c.title() for c in cals})


def active_events_by_calendar(store, calendar_names):
    """Return {calendar_name: [events active now]} for the given calendars.

    Returns None if *none* of the named calendars exist (likely a config typo
    or missing permission) so the caller can fail safe instead of turning
    everything off.
    """
    wanted = set(calendar_names)
    cals = [
        c
        for c in store.calendarsForEntityType_(EKEntityTypeEvent)
        if c.title() in wanted
    ]
    if not cals:
        sys.stderr.write(
            "[rosterfocus] none of the configured calendars were found: "
            f"{sorted(wanted)}\n"
        )
        return None

    found_titles = {c.title() for c in cals}
    for missing in wanted - found_titles:
        sys.stderr.write(f"[rosterfocus] warning: calendar '{missing}' not found\n")

    # Window generously around 'now' so multi-day / overnight shifts are caught.
    start = NSDate.dateWithTimeIntervalSinceNow_(-24 * 3600)
    end = NSDate.dateWithTimeIntervalSinceNow_(24 * 3600)
    pred = store.predicateForEventsWithStartDate_endDate_calendars_(start, end, cals)
    events = store.eventsMatchingPredicate_(pred) or []

    by_cal = {name: [] for name in found_titles}
    for ev in events:
        cal_title = ev.calendar().title()
        if cal_title in by_cal:
            by_cal[cal_title].append(ev)
    return by_cal


def rule_active(rule, events_by_cal, now_ts):
    """True if any event in this rule's calendar matches keyword and overlaps now."""
    events = events_by_cal.get(rule["calendar"], [])
    for ev in events:
        if rule["keyword"]:
            title = (ev.title() or "").lower()
            if rule["keyword"] not in title:
                continue
        s = ev.startDate().timeIntervalSince1970() - rule["lead_minutes"] * 60
        e = ev.endDate().timeIntervalSince1970() + rule["trail_minutes"] * 60
        if s <= now_ts <= e:
            return True
    return False


# --------------------------------------------------------------------------
# State (which Focus we last set)
# --------------------------------------------------------------------------
def read_state():
    """Return the focus name we last activated, or '' for none."""
    try:
        with open(STATE_FILE) as f:
            return (json.load(f) or {}).get("focus", "")
    except (FileNotFoundError, json.JSONDecodeError):
        return ""


def write_state(focus):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump({"focus": focus}, f)


def list_shortcuts():
    """Return the set of Shortcut names known to the Shortcuts app ('' if the
    CLI is unavailable)."""
    try:
        proc = subprocess.run(
            ["shortcuts", "list"], capture_output=True, text=True, timeout=15
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    return {line.strip() for line in proc.stdout.splitlines() if line.strip()}


def run_shortcut(name):
    """Run a Shortcut by name. Returns True on success, False on failure.

    The `shortcuts` CLI exits 0 even when the named shortcut doesn't exist (it
    just prints an error), so we verify the name exists first and also treat any
    error output as failure. This stops a typo'd shortcut name from silently
    recording state as if the Focus had been toggled.
    """
    known = list_shortcuts()
    if known is not None and name not in known:
        sys.stderr.write(
            f"[rosterfocus] shortcut '{name}' not found in Shortcuts.app — "
            "check the name in your config matches exactly.\n"
        )
        return False
    proc = subprocess.run(
        ["shortcuts", "run", name], capture_output=True, text=True
    )
    err = (proc.stderr or "").strip()
    if proc.returncode != 0 or "Error" in err or "Couldn't find" in err:
        sys.stderr.write(
            f"[rosterfocus] shortcut '{name}' failed: "
            f"{err or ('exit ' + str(proc.returncode))}\n"
        )
        return False
    return True


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
def parse_args(argv=None):
    p = argparse.ArgumentParser(
        prog="rosterfocus",
        description="Drive iOS/macOS Focus modes from your shift calendar(s).",
    )
    p.add_argument("--version", action="version", version=f"rosterfocus {__version__}")
    p.add_argument(
        "--doctor",
        action="store_true",
        help="Diagnose the setup: calendar permission, that each configured calendar "
        "exists, and that each Shortcut exists. Fixes nothing; just reports.",
    )
    p.add_argument(
        "--validate",
        action="store_true",
        help="Check that the config file parses and every rule is well-formed, "
        "without touching Calendar or Shortcuts. Works on any machine.",
    )
    p.add_argument(
        "--list-calendars",
        action="store_true",
        help="Print every calendar RosterFocus can see (verifies access), then exit. "
        "Does not need a config file.",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Evaluate the rules against the real calendar and print what would "
        "happen, but run no Shortcut and change no state.",
    )
    p.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Show which events matched while deciding.",
    )
    return p.parse_args(argv)


def open_store_or_exit():
    """Create an EventKit store and block on the access prompt; exit on denial."""
    ensure_eventkit()
    store = EKEventStore.alloc().init()
    if not request_access(store):
        sys.stderr.write(
            "[rosterfocus] calendar access denied. Grant it in System Settings > "
            "Privacy & Security > Calendars.\n"
        )
        sys.exit(1)
    return store


def decide(rules, events_by_cal, now_ts, verbose=False):
    """Return (desired_focus, desired_rule): the first rule with an active event."""
    for rule in rules:
        active = rule_active(rule, events_by_cal, now_ts)
        if verbose:
            n = len(events_by_cal.get(rule["calendar"], []))
            kw = f" keyword='{rule['keyword']}'" if rule["keyword"] else ""
            print(
                f"  rule focus='{rule['focus']}' calendar='{rule['calendar']}'{kw}: "
                f"{n} event(s) in window, active={active}"
            )
        if active:
            return rule["focus"], rule
    return "", None


AUTH_STATUS = {
    0: "NotDetermined (never prompted — run --list-calendars once from a GUI session)",
    1: "Restricted (blocked by a profile/parental controls)",
    2: "Denied (enable it in System Settings > Privacy & Security > Calendars)",
    3: "Authorized (full access)",
    4: "WriteOnly (insufficient — RosterFocus needs read access)",
}


def cmd_validate():
    """Config-only check: parse + normalize the rules. No Calendar/Shortcuts."""
    cfg, cfg_path = load_config()
    rules = normalize_rules(cfg)  # exits with a message if malformed
    print(f"[rosterfocus] config OK: {cfg_path}")
    print(f"  {len(rules)} rule(s), evaluated in this priority order:")
    for i, r in enumerate(rules, 1):
        kw = f" keyword='{r['keyword']}'" if r["keyword"] else ""
        pad = []
        if r["lead_minutes"]:
            pad.append(f"lead {r['lead_minutes']}m")
        if r["trail_minutes"]:
            pad.append(f"trail {r['trail_minutes']}m")
        padtxt = f"  [{', '.join(pad)}]" if pad else ""
        print(
            f"   {i}. calendar='{r['calendar']}'{kw} -> focus '{r['focus']}' "
            f"(on='{r['on_shortcut']}', off='{r['off_shortcut']}'){padtxt}"
        )


def cmd_doctor():
    """Report on everything first-run setup depends on, fixing nothing."""
    ok = True
    print(f"RosterFocus {__version__} — doctor\n")

    # 1. Calendar permission (class method; does NOT trigger a prompt).
    ensure_eventkit()
    status = EKEventStore.authorizationStatusForEntityType_(EKEntityTypeEvent)
    authorized = status == 3
    mark = "OK " if authorized else "!! "
    print(f"[{mark}] Calendar access: {AUTH_STATUS.get(status, f'unknown ({status})')}")
    if not authorized:
        ok = False

    # 2. Config.
    try:
        cfg, cfg_path = load_config_quiet()
    except FileNotFoundError:
        print("[!! ] Config: not found (copy config.example.json to "
              "~/.config/roster-focus/config.json)")
        print("\nFix the items marked !! above, then re-run --doctor.")
        sys.exit(1)
    print(f"[OK ] Config: {cfg_path}")
    rules = normalize_rules(cfg)

    # 3. Calendars exist (only checkable if authorized).
    visible = set(all_calendar_titles(EKEventStore.alloc().init())) if authorized else None
    # 4. Shortcuts exist.
    shortcuts = list_shortcuts()
    if shortcuts is None:
        print("[!! ] Shortcuts: could not run the `shortcuts` CLI")
        ok = False

    print("\nPer-rule checks:")
    for i, r in enumerate(rules, 1):
        print(f"  rule {i}: calendar '{r['calendar']}' -> focus '{r['focus']}'")
        if visible is not None:
            cal_ok = r["calendar"] in visible
            print(f"    [{'OK ' if cal_ok else '!! '}] calendar '{r['calendar']}'"
                  + ("" if cal_ok else " not found"))
            ok = ok and cal_ok
        else:
            print(f"    [?? ] calendar '{r['calendar']}' (can't check — no access)")
        if shortcuts is not None:
            for kind in ("on_shortcut", "off_shortcut"):
                s = r[kind]
                s_ok = s in shortcuts
                print(f"    [{'OK ' if s_ok else '!! '}] shortcut '{s}'"
                      + ("" if s_ok else " not found in Shortcuts.app"))
                ok = ok and s_ok

    print("\nNote: 'Share Across Devices' (what propagates Focus to your iPhone) can't "
          "be read here — confirm it's ON manually in Settings > Focus on both devices.")
    print("\n" + ("All checks passed." if ok else "Some checks failed (see !! above)."))
    sys.exit(0 if ok else 1)


def main(argv=None):
    args = parse_args(argv)

    if args.validate:
        cmd_validate()
        return
    if args.doctor:
        cmd_doctor()
        return

    # --list-calendars works without a config so it can be the very first check.
    if args.list_calendars:
        store = open_store_or_exit()
        titles = all_calendar_titles(store)
        if not titles:
            print("[rosterfocus] no calendars visible. Is Calendar.app set up on this Mac?")
        else:
            print("Calendars RosterFocus can see (use these exact names in config.json):")
            for t in titles:
                print(f"  - {t}")
        return

    cfg, cfg_path = load_config()
    rules = normalize_rules(cfg)
    if args.verbose:
        print(f"[rosterfocus] config: {cfg_path}  ({len(rules)} rule(s))")

    store = open_store_or_exit()

    calendars = {r["calendar"] for r in rules}
    events_by_cal = active_events_by_calendar(store, calendars)
    if events_by_cal is None:
        sys.exit(1)  # fail safe: don't toggle anything if we can't read calendars

    now_ts = datetime.now().timestamp()
    desired, desired_rule = decide(rules, events_by_cal, now_ts, verbose=args.verbose)
    current = read_state()

    if args.dry_run:
        print(
            f"[rosterfocus] dry-run: current='{current or 'none'}' "
            f"desired='{desired or 'none'}'"
        )
        if current != desired:
            if current:
                prev = next((r for r in rules if r["focus"] == current), None)
                if prev:
                    print(f"  would run OFF shortcut: '{prev['off_shortcut']}'")
            if desired_rule:
                print(f"  would run ON  shortcut: '{desired_rule['on_shortcut']}'")
        else:
            print("  no change; nothing would run.")
        return

    # Only act on a *change*. If you manually override a Focus mid-shift, we
    # won't keep fighting you until the next calendar boundary.
    if current == desired:
        return

    prev_rule = next((r for r in rules if r["focus"] == current), None) if current else None

    if desired_rule:
        # Switching to a Focus. Turning a Focus on replaces any active one, so
        # turning off the previous one is best-effort; the ON is what must work.
        if prev_rule:
            run_shortcut(prev_rule["off_shortcut"])
        ok = run_shortcut(desired_rule["on_shortcut"])
    else:
        # Switching to no Focus: the OFF of the current Focus is what must work.
        ok = run_shortcut(prev_rule["off_shortcut"]) if prev_rule else True

    if not ok:
        # Don't record the change, so the next poll retries instead of silently
        # believing the Focus was set.
        sys.stderr.write(
            "[rosterfocus] focus change failed; not recording state (will retry).\n"
        )
        sys.exit(1)

    write_state(desired)
    label = desired or "none"
    print(f"[rosterfocus] {datetime.now():%Y-%m-%d %H:%M}  focus -> {label}")


if __name__ == "__main__":
    main()
