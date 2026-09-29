#!/usr/bin/env bash
# Report GDScript analyzer warnings and errors (unused parameters, shadowed names, ...), which
# neither the command-line import nor --check-only prints. Starts a headless editor with its own
# language server (so a full server in the open editor does not matter), asks it about each file,
# then stops it. With no arguments it checks every .gd file under src/, tests/ and tools/.
# Full editor output goes to _temp/lsp_editor.log; the report is printed and saved to _temp/lsp_check.log.
set -uo pipefail

. "$(dirname "$0")/godot_env.sh"

PORT="${LSP_PORT:-6015}"
EDITOR_LOG="$LOG_DIR/lsp_editor.log"
LOG="$LOG_DIR/lsp_check.log"

if [ $# -gt 0 ]; then
  FILES=("$@")
else
  mapfile -t FILES < <(find src tests tools -name '*.gd' | sort)
fi

"$GODOT" --headless --editor --path . --lsp-port "$PORT" > "$EDITOR_LOG" 2>&1 &
EDITOR_PID=$!
trap 'kill "$EDITOR_PID" 2>/dev/null' EXIT

# Wait until the editor has finished loading the project, or give up after two minutes.
for _ in $(seq 1 120); do
  if grep -q 'loading_editor_layout' "$EDITOR_LOG" 2>/dev/null && grep -q 'DONE' "$EDITOR_LOG"; then
    break
  fi
  sleep 1
done

python "$(dirname "$0")/lsp_check.py" "$PORT" "${FILES[@]}" > "$LOG" 2>&1
STATUS=$?
cat "$LOG"
exit $STATUS
