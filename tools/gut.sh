#!/usr/bin/env bash
# Run the GUT suite headless. Full output goes to _temp/gut.log; only failures
# and the totals block are printed. Extra arguments are passed to GUT, so a
# single file is: tools/gut.sh -gdir=res://tests/combat -gselect=test_item.gd
set -uo pipefail

. "$(dirname "$0")/godot_env.sh"

LOG="$LOG_DIR/gut.log"

"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit "$@" > "$LOG" 2>&1
STATUS=$?

grep -nE '\[Failed\]|Failing|SCRIPT ERROR|ERROR:|Orphans' "$LOG" | head -40
echo '--- totals'
tail -25 "$LOG"
echo "--- exit $STATUS, full output in $LOG"
exit $STATUS
