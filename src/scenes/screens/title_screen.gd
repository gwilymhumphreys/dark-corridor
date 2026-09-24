class_name TitleScreen
extends Control
## Title screen (docs/systems/game_manager.md, phase TITLE). Start a fresh seeded run (via the
## character-select screen) or resume the saved one — the two run-lifecycle intents.
## Static text auto-translates from the .tscn (CLAUDE.md localization); this wires the
## buttons to the select overlay + Game.

const CHARACTER_SELECT: PackedScene = preload('res://src/scenes/screens/character_select.tscn')
const SETTINGS_SCREEN: PackedScene = preload('res://src/scenes/screens/settings_screen.tscn')

# Fixed for prototype dev so each launch replays the same run (easy to debug the UI against
# a known fight). A random/chosen seed is post-prototype; the character is now player-chosen.
const DEFAULT_SEED: int = 1

var _select: CharacterSelect = null
var _settings: SettingsScreen = null


func _ready() -> void:
  var start_button: Button = $Menu/StartButton
  var resume_button: Button = $Menu/ResumeButton
  var settings_button: Button = $Menu/SettingsButton
  var exit_button: Button = $Menu/ExitButton
  start_button.pressed.connect(open_select)
  resume_button.pressed.connect(_on_resume)
  settings_button.pressed.connect(open_settings)
  exit_button.pressed.connect(_exit_game)
  resume_button.disabled = not Save.has_save()


# Start → the character-select screen; its pick supplies the character to Game.start_run.
func open_select() -> void:
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


# Settings → the audio-volume screen (Prefs-backed); Close frees it back to the title.
func open_settings() -> void:
  if _settings != null:
    return
  _settings = SETTINGS_SCREEN.instantiate()
  add_child(_settings)
  _settings.closed.connect(_close_settings)


func _close_settings() -> void:
  if _settings != null:
    _settings.queue_free()
    _settings = null


func _on_resume() -> void:
  Game.resume_run()


func _exit_game() -> void:
  get_tree().quit()
