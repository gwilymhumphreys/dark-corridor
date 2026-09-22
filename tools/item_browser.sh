#!/usr/bin/env bash
# Build the item browser page (docs/systems/item_browser.md): every item with its tooltip
# text and icons, filterable by character, type, rarity and keyword. Writes
# _temp/item_browser.html; open it in a browser. Full output goes to _temp/item_browser.log.
set -uo pipefail

. "$(dirname "$0")/godot_env.sh"

LOG="$LOG_DIR/item_browser.log"

"$GODOT" --headless --path . res://tools/item_browser.tscn > "$LOG" 2>&1
STATUS=$?

grep -nE 'SCRIPT ERROR|ERROR:|Parse Error|WARNING: item_browser' "$LOG" | head -20
grep 'item_browser: wrote' "$LOG"
echo "--- exit $STATUS, full output in $LOG"
exit $STATUS
