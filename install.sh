#!/usr/bin/env bash
#
# RosterFocus installer + guided setup.
#
# Part 1 (always): creates a Python venv with the EventKit bindings, scaffolds
# your config, and writes a launchd agent with the REAL interpreter + script
# paths filled in (the two things people most often get wrong by hand).
#
# Part 2 (interactive, when run in a terminal): walks you through the manual
# macOS steps that no script can do for you — creating the "Work" Focus,
# importing the Focus Shortcuts, and granting Calendar access — verifying each
# with `--doctor`.
#
# Usage:
#   ./install.sh              # set up, then guide you through the manual steps
#   ./install.sh --no-guide   # just set up files; print next steps and exit
#
set -euo pipefail

GUIDE=1
for arg in "$@"; do
  case "$arg" in
    --no-guide|--non-interactive) GUIDE=0 ;;
    -h|--help)
      cat <<'USAGE'
RosterFocus installer + guided setup.

Usage:
  ./install.sh              Set up files (venv, config, launchd agent), then
                            walk you through the manual macOS steps: creating
                            the "Work" Focus, importing the Focus Shortcuts,
                            and granting Calendar access — verified with --doctor.
  ./install.sh --no-guide   Just set up files; print the manual next steps and exit.
USAGE
      exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done
# No point guiding if there's no terminal to prompt on (e.g. piped/headless cron).
[ -t 0 ] || GUIDE=0

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$HERE/.venv"
PY="$VENV/bin/python"
SCRIPT="$HERE/rosterfocus.py"
CONFIG_DIR="$HOME/.config/roster-focus"
CONFIG="$CONFIG_DIR/config.json"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_DIR/com.rosterfocus.agent.plist"

# ----- small prompt helpers -----------------------------------------------
pause()  { printf '\n%s\n' "$1"; read -r -p "Press Return when done… " _ || true; }
ask_yn() { # ask_yn "question" -> returns 0 for yes, 1 for no (default yes)
  local a; read -r -p "$1 [Y/n] " a || true
  case "${a:-y}" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
rule()   { printf '\n────────────────────────────────────────────────────────\n'; }

# ==========================================================================
# Part 1 — file setup (always)
# ==========================================================================
echo "==> Creating virtualenv: $VENV"
python3 -m venv "$VENV"

echo "==> Installing pyobjc-framework-EventKit (this can take a minute)"
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet pyobjc-framework-EventKit

echo "==> Scaffolding config"
mkdir -p "$CONFIG_DIR"
if [ -f "$CONFIG" ]; then
  echo "    config already exists, leaving it untouched: $CONFIG"
else
  cp "$HERE/config.example.json" "$CONFIG"
  echo "    wrote starter config: $CONFIG  (EDIT THIS to match your calendars/Focuses)"
fi

echo "==> Writing launchd agent with real paths: $PLIST"
mkdir -p "$LAUNCH_DIR"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.rosterfocus.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PY</string>
        <string>$SCRIPT</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/rosterfocus.out.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/rosterfocus.err.log</string>
</dict>
</plist>
PLIST

if [ "$GUIDE" -eq 0 ]; then
  cat <<NEXT

==> Files are set up. Finish in a GUI login session (Screen Sharing on a headless
    Mac mini) — Calendar access and Shortcuts can't be set up over plain SSH:

  1. Create a Focus named "Work":  System Settings > Focus > + > Work
  2. Import the Focus Shortcuts:    open "$HERE/shortcuts/Work Focus On.shortcut"
                                    open "$HERE/shortcuts/Work Focus Off.shortcut"
     (or build your own — see SETUP.md). For a non-Work Focus, build by hand.
  3. Edit your config:              \$EDITOR $CONFIG
  4. Grant Calendar access:         $PY $SCRIPT --list-calendars
  5. Verify everything:             $PY $SCRIPT --doctor
  6. Dry-run, then go live:         $PY $SCRIPT --dry-run -v
                                    launchctl load $PLIST

  Stop later:  launchctl unload $PLIST
NEXT
  exit 0
fi

# ==========================================================================
# Part 2 — guided setup (interactive)
# ==========================================================================
rule
cat <<INTRO
Now the manual macOS steps. A script CAN'T create a Focus or build Shortcuts for
you (Apple provides no API for either), so I'll open the right places and check
each step. Do this on the Mac itself or over Screen Sharing — not plain SSH.
INTRO

# --- Step 1: the "Work" Focus -------------------------------------------------
rule
echo "STEP 1 of 5 — Create the \"Work\" Focus"
cat <<MSG
RosterFocus toggles a Focus *mode*; it can't invent one. You need a Focus named
"Work". Using Apple's built-in "Work" suggestion is best — the prebuilt Shortcuts
target it directly.

In System Settings > Focus: if "Work" isn't listed, click + (top right), choose
"Work", and add it. (You don't need to configure schedules/allowed people — this
project drives it.)
MSG
open "x-apple.systempreferences:com.apple.Focus-Settings.extension" 2>/dev/null \
  || echo "(Open System Settings > Focus manually.)"
pause "Add/confirm the \"Work\" Focus, then come back."

# --- Step 2: the Shortcuts ----------------------------------------------------
rule
echo "STEP 2 of 5 — Add the Focus Shortcuts"
if [ -f "$HERE/shortcuts/Work Focus On.shortcut" ] && ask_yn \
     "Import the prebuilt \"Work Focus On/Off\" Shortcuts now?"; then
  open "$HERE/shortcuts/Work Focus On.shortcut" 2>/dev/null || true
  open "$HERE/shortcuts/Work Focus Off.shortcut" 2>/dev/null || true
  cat <<MSG
Click "Add Shortcut" in each dialog. Then open each in Shortcuts.app and confirm
the "Set Focus" action shows YOUR Work Focus (re-pick it if it's blank — that
happens with a custom Focus). If you use a Focus other than Work, build the pair
by hand instead (SETUP.md step 2) and name them to match your config.
MSG
else
  cat <<MSG
Build them by hand in Shortcuts.app (one pair per Focus):
  "Work Focus On"  = Set Focus > Work > Turn On > Until Turned Off
  "Work Focus Off" = Set Focus > Work > Turn Off
The names must exactly match on_shortcut/off_shortcut in your config.
MSG
fi
pause "Add the Shortcuts, then come back."

# --- Step 3: the config -------------------------------------------------------
rule
echo "STEP 3 of 5 — Point the config at your calendar(s)"
echo "Config file: $CONFIG"
echo "The example has a few sample rules (On-Call, Work, Gym). Delete the ones you"
echo "don't need, and for the rest set 'calendar' to your calendar's exact name and"
echo "'focus'/'on_shortcut'/'off_shortcut' to match the Focus + Shortcuts you made."
if ask_yn "Open the config in your editor now?"; then
  if [ -n "${EDITOR:-}" ]; then "$EDITOR" "$CONFIG" || true; else open -t "$CONFIG" || true; fi
fi
pause "Save your config, then come back."

# --- Step 4: Calendar permission ---------------------------------------------
rule
echo "STEP 4 of 5 — Grant Calendar access"
echo "This triggers the macOS Calendar prompt — click \"Allow Full Access\"."
"$PY" "$SCRIPT" --list-calendars || true
pause "If a permission dialog appeared, approve it."

# --- Step 5: verify with --doctor (loop) -------------------------------------
rule
echo "STEP 5 of 5 — Verify the whole setup"
while true; do
  echo
  if "$PY" "$SCRIPT" --doctor; then
    echo
    echo "✅ All checks passed."
    break
  fi
  echo
  echo "Some checks failed above (look for [!! ])."
  ask_yn "Re-run --doctor after fixing?" || { echo "You can re-run later: $PY $SCRIPT --doctor"; break; }
done

# --- Offer to go live ---------------------------------------------------------
rule
echo "Dry-run (shows what it WOULD do; toggles nothing):"
"$PY" "$SCRIPT" --dry-run -v || true
rule
if ask_yn "Load the launchd agent now so it runs every 60s?"; then
  launchctl unload "$PLIST" 2>/dev/null || true
  launchctl load "$PLIST"
  echo "Loaded. Watch it:  tail -f /tmp/rosterfocus.out.log /tmp/rosterfocus.err.log"
  echo "Stop later:        launchctl unload $PLIST"
else
  echo "Not loaded. When ready:  launchctl load $PLIST"
fi
echo
echo "Done. 🎉"
