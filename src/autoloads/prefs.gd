class_name PrefsAutoload
extends Node
## Session preferences persisted to disk (autoload `Prefs`) — SEPARATE from the run Save
## (that stores run-state only, and is cleared on death/win). A thin ConfigFile wrapper at
## user://: audio bus volumes (Master / Music / Effects, each a 0..1 linear level) + mute-when-
## unfocused, the UI font style (vector vs pixel), and the display mode (fullscreen vs windowed).
## set_*() applies the change AND writes through immediately; load + apply happen at boot.
## `disabled` skips the disk write — TestCleanup sets it so tests never touch user://. The owner
## extends this with further video / accessibility keys as settings grow.

const PATH: String = 'user://dark_corridor_prefs.cfg'
const SECTION_AUDIO: String = 'audio'
const SECTION_DISPLAY: String = 'display'

# UI font style (docs/systems/ui_theme.md). VECTOR = smooth antialiased text (the default); PIXEL =
# a crisp pixel font for the chunky look. The toggle swaps the project theme's default font at
# runtime; every Control re-renders via NOTIFICATION_THEME_CHANGED (no manual walk).
enum FontStyle { VECTOR, PIXEL }

# The project UI theme (project.godot gui/theme/custom). Mutating the cached resource propagates
# to every Control using it.
const THEME_PATH: String = 'res://assets/themes/black_white_ui.tres'

# Font resource per style. '' = the engine built-in font (a smooth vector font — fine for VECTOR
# until a custom one is chosen). The PIXEL asset doesn't exist yet: add a pixel font there (with
# FontFile.oversampling = 1.0 + antialiasing/subpixel Disabled, see ui_theme.md) to enable the
# option — until then PIXEL falls back to the built-in font with a warning, so the wiring is inert
# but harmless.
const FONT_PATHS: Dictionary = {
  FontStyle.VECTOR: '',
  FontStyle.PIXEL: 'res://assets/fonts/ui_pixel.ttf',
}

# Locales whose script the PIXEL font covers (it's Latin-only — docs/systems/ui_theme.md). The
# pixel option only applies for a locale listed here (matched on the language prefix, e.g. `en` in
# `en_US`); any other locale renders fully in the VECTOR font even when PIXEL is selected — so an
# Eastern / non-Latin locale is never tofu or pixel/vector-mixed. Default-deny: add a language code
# only once the pixel font is confirmed to cover it. The stored preference is kept either way, so
# returning to a covered locale restores pixel.
const PIXEL_FONT_LOCALES: PackedStringArray = ['en']

# Each audio key → its AudioServer bus (from default_bus_layout.tres) and default 0..1 level.
const AUDIO_BUSES: Dictionary = {
  'master': 'Master',
  'music': 'Music',
  'effects': 'Effects',
}
const AUDIO_DEFAULTS: Dictionary = {
  'master': 0.8,
  'music': 0.7,
  'effects': 0.9,
}

# When true the disk write is skipped. The game leaves it false; TestCleanup sets it so tests
# stay hermetic (in-memory + bus only, never writing user://). Like Save.disabled in spirit.
var disabled: bool = false

var _config: ConfigFile = ConfigFile.new()


func _ready() -> void:
  load_prefs()
  apply_audio()
  apply_font_style()
  apply_display()


## Autoloads are in the tree, so they receive these notifications:
## - TRANSLATION_CHANGED: re-apply the font (a future settings-menu language switch must drop a
##   non-Latin locale back to the vector font). Idempotent, so the known double-fire (engine issue
##   #89804) is harmless.
## - APPLICATION_FOCUS_OUT / _IN: mute / unmute the Master bus when `mute_on_focus_lost` is on.
func _notification(what: int) -> void:
  if what == NOTIFICATION_TRANSLATION_CHANGED:
    apply_font_style()
  elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and mute_on_focus_lost():
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


## The stored UI font style (its default — VECTOR — if unset). See FontStyle.
func font_style() -> int:
  return int(_config.get_value(SECTION_DISPLAY, 'font_style', FontStyle.VECTOR))


## Set the UI font style: store it, apply it to the live theme, persist (unless disabled).
func set_font_style(style: int) -> void:
  _config.set_value(SECTION_DISPLAY, 'font_style', style)
  apply_font_style()
  save_prefs()


## Apply the EFFECTIVE font style to the project theme's default font (called at boot, on change,
## and on locale change). Swapping the cached theme's default font re-renders every Control via
## NOTIFICATION_THEME_CHANGED.
func apply_font_style() -> void:
  var theme: Theme = load(THEME_PATH) as Theme
  if theme == null:
    return
  theme.set_default_font(_font_for_style(_effective_style()))


## The style actually used right now: PIXEL only when it's both selected AND the active locale's
## script is covered by the pixel font; otherwise VECTOR (the safe, broad-coverage default).
func _effective_style() -> int:
  if font_style() != FontStyle.PIXEL:
    return FontStyle.VECTOR
  var lang: String = TranslationServer.get_locale().split('_')[0]
  return FontStyle.PIXEL if lang in PIXEL_FONT_LOCALES else FontStyle.VECTOR


## The Font for a style: null = the engine built-in (smooth vector). A configured-but-absent asset
## (the not-yet-added pixel font) warns and falls back to built-in rather than failing.
func _font_for_style(style: int) -> Font:
  var path: String = FONT_PATHS.get(style, '')
  if path == '':
    return null
  if not ResourceLoader.exists(path):
    push_warning('Prefs: the font for the selected style is not in the project yet (%s); using the built-in font.' % path)
    return null
  return load(path) as Font


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


func load_prefs() -> void:
  _config = ConfigFile.new()
  _config.load(PATH)   # absent / unreadable → empty config → defaults via the get_value fallback


func save_prefs() -> void:
  if disabled:
    return
  _config.save(PATH)
