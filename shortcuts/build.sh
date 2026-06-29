#!/usr/bin/env bash
#
# Sign the unsigned shortcut sources in src/ into importable .shortcut files.
#
# Run on a Mac (needs the `shortcuts` CLI). Signing mode "anyone" so the result
# imports on any device without a matching Apple Account.
#
#   ./build.sh
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

sign() {
  local src="$1" out="$2"
  echo "==> signing $out"
  shortcuts sign -m anyone -i "src/$src" -o "$out"
}

sign WorkFocusOn.unsigned.shortcut  "Work Focus On.shortcut"
sign WorkFocusOff.unsigned.shortcut "Work Focus Off.shortcut"

echo "Done. Double-click a .shortcut (or \`open\`) to add it to Shortcuts.app."
