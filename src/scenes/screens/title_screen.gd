extends Control
## Title screen (game_manager_prd, phase TITLE). Start a fresh seeded run (via the
## character-select screen) or resume the saved one — the two run-lifecycle intents.
## Static text auto-translates from the .tscn (CLAUDE.md localization); this wires the
## buttons to the select overlay + Game.

const CHARACTER_SELECT: PackedScene = preload('res://src/scenes/screens/character_select.tscn')

# Fixed for prototype dev so each launch replays the same run (easy to debug the UI against
# a known fight). A random/chosen seed is post-prototype; the character is now player-chosen.
const DEFAULT_SEED: int = 1

var _select: CharacterSelect = null


func _ready() -> void:
  var start_button: Button = $Menu/StartButton
  var resume_button: Button = $Menu/ResumeButton
  start_button.pressed.connect(_open_select)
  resume_button.pressed.connect(_on_resume)
  resume_button.disabled = not Save.has_save()
  # Dev hook: skip the menu + select and drop straight into a default-character run (pairs
  # with `--shot`). `--select` instead opens the character-select screen (to inspect it).
  if '--autostart' in OS.get_cmdline_args() or '--autostart' in OS.get_cmdline_user_args():
    _start_run.bind(CharacterCatalog.DEFAULT).call_deferred()
  elif '--select' in OS.get_cmdline_args() or '--select' in OS.get_cmdline_user_args():
    _open_select.call_deferred()


# Start Run → the character-select screen; its pick supplies the character to Game.start_run.
func _open_select() -> void:
  if _select != null:
    return
  _select = CHARACTER_SELECT.instantiate()
  add_child(_select)
  _select.picked.connect(_start_run)
  _select.cancelled.connect(_close_select)


func _close_select() -> void:
  if _select != null:
    _select.queue_free()
    _select = null


func _start_run(character_id: String) -> void:
  Game.start_run(DEFAULT_SEED, character_id)


func _on_resume() -> void:
  Game.resume_run()
