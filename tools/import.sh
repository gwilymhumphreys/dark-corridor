#!/usr/bin/env bash
# Reimport assets. Required after adding any file or a new class_name script,
# or GUT will not see the new global. Full output goes to _temp/import.log;
# only errors are printed.
set -uo pipefail

. "$(dirname "$0")/godot_env.sh"

LOG="$LOG_DIR/import.log"

"$GODOT" --headless --path . --import --exit > "$LOG" 2>&1
STATUS=$?

grep -nE 'SCRIPT ERROR|ERROR:|Failed to load|Parse Error' "$LOG" | head -30
echo "--- import exit $STATUS, full output in $LOG"
exit $STATUS
