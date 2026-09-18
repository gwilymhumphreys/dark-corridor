# Shared by the tools/*.sh wrappers. Override the executable with GODOT=... .
GODOT="${GODOT:-C:/projects/godot/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe}"
LOG_DIR='_temp'

mkdir -p "$LOG_DIR"

if [ ! -f "$GODOT" ]; then
  echo "Godot executable not found: $GODOT" >&2
  echo 'Set GODOT=<path> or update tools/godot_env.sh.' >&2
  exit 127
fi
