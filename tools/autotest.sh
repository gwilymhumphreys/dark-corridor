#!/usr/bin/env bash
# Drive a headless run through AutoTest mode. Full output goes to
# _temp/autotest.log; only errors and the closing summary are printed.
# --nosave and --notutorial are always passed. Extra arguments go to AutoTest,
# for example: tools/autotest.sh --seed 42 --encounters 6 --speed 20
# Flags are listed in docs/systems/autotest.md.
set -uo pipefail

. "$(dirname "$0")/godot_env.sh"

LOG="$LOG_DIR/autotest.log"

"$GODOT" --headless --path . res://src/autotest/autotest.tscn -- \
  --autotest --nosave --notutorial "$@" > "$LOG" 2>&1
STATUS=$?

grep -nE 'SCRIPT ERROR|ERROR:|stuck|timed out' "$LOG" | head -20
echo '--- summary'
tail -30 "$LOG"
echo "--- exit $STATUS (0 = resolved, 1 = stuck or timed out), full output in $LOG"
exit $STATUS
