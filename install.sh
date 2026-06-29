#!/usr/bin/env bash
#
# RosterFocus installer.
#
# Creates a Python venv with the EventKit bindings, scaffolds your config, and
# writes a launchd agent with the REAL interpreter + script paths filled in
# (the two things people most often get wrong by hand). It does not load the
# agent or grant any permission — it prints exactly what to do next.
#
# Usage:  ./install.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$HERE/.venv"
PY="$VENV/bin/python"
SCRIPT="$HERE/rosterfocus.py"
CONFIG_DIR="$HOME/.config/roster-focus"
CONFIG="$CONFIG_DIR/config.json"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_DIR/com.rosterfocus.agent.plist"

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

cat <<NEXT

==> Done. Next steps (run these in a GUI login session, e.g. via Screen Sharing
    on a headless Mac mini — Calendar access and Shortcuts can't be set up over
    a plain SSH/headless context):

  1. Edit your config:
       \$EDITOR $CONFIG

  2. Grant Calendar access and confirm the calendar names:
       $PY $SCRIPT --list-calendars

  3. Build a "<Focus> On" / "<Focus> Off" pair of Shortcuts in Shortcuts.app
     for each Focus you use (see SETUP.md for the exact actions).

  4. Check everything is wired up:
       $PY $SCRIPT --doctor

  5. Dry-run, then go live:
       $PY $SCRIPT --dry-run -v
       launchctl load $PLIST
       tail -f /tmp/rosterfocus.out.log /tmp/rosterfocus.err.log

  To stop later:  launchctl unload $PLIST
NEXT
