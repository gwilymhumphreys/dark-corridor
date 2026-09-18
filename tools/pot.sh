#!/usr/bin/env bash
# Regenerate locale/messages.pot and merge the .po files, then reimport so the
# .translation resources rebuild. Run after adding or changing any translatable
# string. Full output goes to _temp/pot.log; only errors are printed.
set -uo pipefail

. "$(dirname "$0")/godot_env.sh"

LOG="$LOG_DIR/pot.log"

"$GODOT" --headless --path . --script res://tools/extract_pot.gd > "$LOG" 2>&1
STATUS=$?

grep -nE 'SCRIPT ERROR|ERROR:|Parse Error' "$LOG" | head -20
echo "--- extract exit $STATUS, full output in $LOG"
[ $STATUS -ne 0 ] && exit $STATUS

"$(dirname "$0")/import.sh"
