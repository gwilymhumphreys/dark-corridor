class_name PrefsAutoload
extends Node
## Session preferences persisted to disk (autoload `Prefs`) — SEPARATE from the run Save
## (that stores run-state only, and is cleared on death/win). A thin ConfigFile wrapper at
## user://: audio bus volumes (Master / Music / Interface / Game, each a 0..1 linear level) + mute-when-
## unfocused, the display mode (fullscreen vs windowed), and the interface text scale.
## set_*() applies the change AND writes through immediately; load + apply happen at boot.
## `disabled` skips the disk write — TestCleanup sets it so tests never touch user://. The owner
## extends this with further video / accessibility keys as settings grow.

const PATH: String = 'user://dark_corridor_prefs.cfg'
const SECTION_AUDIO: String = 'audio'
const SECTION_DISPLAY: String = 'display'
const SECTION_INTERFACE: String = 'interface'

# The project UI theme (project.godot gui/theme/custom). It names the UI font as its default font
# and holds the text ladder's sizes (docs/systems/ui_theme.md). Mutating the cached resource
# propagates to every Control using it, which is how the text scale reaches the whole interface.
const THEME_PATH: String = 'res://assets/themes/dark_corridor.tres'

# Each audio key → its AudioServer bus (from default_bus_layout.tres) and default 0..1 level.
const AUDIO_BUSES: Dictionary = {
  'master': 'Master',
  'music': 'Music',
  'interface': 'Interface',
  'game': 'Game',
}
const AUDIO_DEFAULTS: Dictionary = {
  'master': 0.5,
  'music': 0.5,
  'interface': 0.5,
  'game': 0.5,
}

# Command-line flags that mean nobody is listening: the autotest harness and a --shot screenshot
# capture. Any of these mutes the Master bus for the whole process.
const SILENT_ARGS: Array[String] = ['--autotest', '--shot']

# When true the disk write is skipped. The game leaves it false; TestCleanup sets it so tests
# stay hermetic (in-memory + bus only, never writing user://). Like Save.disabled in spirit.
var disabled: bool = false

var _config: ConfigFile = ConfigFile.new()


func _ready() -> void:
  load_prefs()
  apply_audio()
  apply_display()
  apply_text_scale()
  if is_silent_run():
    _set_master_muted(true)


## Whether this process was launched by the autotest harness or a screenshot capture. Those runs
## play no sound at all: the Master bus is muted at boot and the stored volumes are left alone, so
## the player's own settings are untouched.
func is_silent_run() -> bool:
  var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
  for flag: String in SILENT_ARGS:
    if flag in args:
      return true
  return false


## Autoloads are in the tree, so they receive APPLICATION_FOCUS_OUT / _IN: mute / unmute the
## Master bus when `mute_on_focus_lost` is on.
func _notification(what: int) -> void:
  if is_silent_run():
    return
  if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mute_on_focus_lost():
    _set_master_muted(true)
  elif what == NOTIFICATION_APPLICATION_FOCUS_IN and mute_on_focus_lost():
    _set_master_muted(false)


## The stored 0..1 level for an audio key (its default if unset).
func volume(key: String) -> float:
  return float(_config.get_value(SECTION_AUDIO, key, AUDIO_DEFAULTS.get(key, 1.0)))


## Set an audio key's 0..1 level: store it, apply it to the bus, persist (unless disabled).
func set_volume(key: String, value: float) -> void:
  _config.set_value(SECTION_AUDIO, key, clampf(value, 0.0, 1.0))
  _apply_bus(key)
  save_prefs()


## (Re)apply every stored audio level to its AudioServer bus (called at boot + on resume).
func apply_audio() -> void:
  for key in AUDIO_BUSES:
    _apply_bus(key)


func _apply_bus(key: String) -> void:
  var bus: int = AudioServer.get_bus_index(AUDIO_BUSES[key])
  if bus < 0:
    return
  var v: float = volume(key)
  AudioServer.set_bus_volume_db(bus, -80.0 if v <= 0.0 else linear_to_db(v))


## Whether to silence the game while the window is unfocused (default off). Applied live by the
## focus notifications above — there's no boot-time apply (the window is focused at launch).
func mute_on_focus_lost() -> bool:
  return bool(_config.get_value(SECTION_AUDIO, 'mute_on_focus_lost', false))


## Toggle mute-when-unfocused: store + persist. Turning it OFF unmutes immediately in case we're
## currently unfocused (so the player isn't left silenced); the next focus-out re-arms it.
func set_mute_on_focus_lost(on: bool) -> void:
  _config.set_value(SECTION_AUDIO, 'mute_on_focus_lost', on)
  if not on:
    _set_master_muted(false)
  save_prefs()


func _set_master_muted(muted: bool) -> void:
  var bus: int = AudioServer.get_bus_index(AUDIO_BUSES['master'])
  if bus >= 0:
    AudioServer.set_bus_mute(bus, muted)


## The stored display mode (default windowed). One bool — fullscreen vs windowed — is all the
## canvas_items/Nearest setup needs (docs/systems/ui_theme.md: the canvas is a true 1440p surface,
## so there's no resolution/integer-scale picker to expose like a viewport-stretch project would).
func is_fullscreen() -> bool:
  return bool(_config.get_value(SECTION_DISPLAY, 'fullscreen', false))


## Set the display mode: store it, apply it to the window, persist (unless disabled).
func set_fullscreen(on: bool) -> void:
  _config.set_value(SECTION_DISPLAY, 'fullscreen', on)
  apply_display()
  save_prefs()


## Apply the stored display mode to the live window (called at boot + on change). Headless-safe:
## window_set_mode is a no-op under the headless display driver (tests).
func apply_display() -> void:
  var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen() else DisplayServer.WINDOW_MODE_WINDOWED
  DisplayServer.window_set_mode(mode)


## The stored interface text scale: a multiple of the `TextSize` ladder, 1.0 being the authored
## sizes. Out-of-range stored values are clamped by `TextSize.apply`.
func text_scale() -> float:
  return float(_config.get_value(SECTION_INTERFACE, 'text_scale', TextSize.DEFAULT_SCALE))


## Set the interface text scale: store it, apply it to the theme, persist (unless disabled).
func set_text_scale(value: float) -> void:
  _config.set_value(SECTION_INTERFACE, 'text_scale', clampf(value, TextSize.MIN_SCALE, TextSize.MAX_SCALE))
  apply_text_scale()
  save_prefs()


## Write the stored text scale into the theme resource (called at boot + on change). Every Control
## reads that resource, so the whole interface resizes at once.
func apply_text_scale() -> void:
  TextSize.apply(load(THEME_PATH) as Theme, text_scale())


func load_prefs() -> void:
  _config = ConfigFile.new()
  _config.load(PATH)   # absent / unreadable → empty config → defaults via the get_value fallback


func save_prefs() -> void:
  if disabled:
    return
  _config.save(PATH)
