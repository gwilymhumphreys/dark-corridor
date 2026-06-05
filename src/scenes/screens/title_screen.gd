extends Control
## Title screen (game_manager_prd, phase TITLE). Start a fresh seeded run or resume
## the saved one — the two run-lifecycle intents. Static text auto-translates from
## the .tscn (CLAUDE.md localization); this only wires the buttons to Game.

# Fixed for prototype dev so each launch replays the same run (easy to debug the UI
# against a known fight). A real character-select + random seed is post-prototype.
const DEFAULT_SEED: int = 1


func _ready() -> void:
  var start_button: Button = $Menu/StartButton
  var resume_button: Button = $Menu/ResumeButton
  start_button.pressed.connect(_on_start)
  resume_button.pressed.connect(_on_resume)
  resume_button.disabled = not Save.has_save()
  # Dev hook: skip the menu and drop straight into a run (pairs with `--shot`).
  if '--autostart' in OS.get_cmdline_args() or '--autostart' in OS.get_cmdline_user_args():
    _on_start.call_deferred()


func _on_start() -> void:
  Game.start_run(DEFAULT_SEED)


func _on_resume() -> void:
  Game.resume_run()
