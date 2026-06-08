class_name PrefsAutoload
extends Node
## Session preferences persisted to disk (autoload `Prefs`) — SEPARATE from the run Save
## (that stores run-state only, and is cleared on death/win). A thin ConfigFile wrapper at
## user://: audio bus volumes today (Master / Music / Effects), each a 0..1 linear level.
## set_volume() applies to the AudioServer bus AND writes through immediately; load + apply
## happen at boot. `disabled` skips the disk write — TestCleanup sets it so tests never touch
## user://. The owner extends this with video / accessibility keys as settings grow.

const PATH: String = 'user://dark_corridor_prefs.cfg'
const SECTION_AUDIO: String = 'audio'

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


func load_prefs() -> void:
  _config = ConfigFile.new()
  _config.load(PATH)   # absent / unreadable → empty config → defaults via the get_value fallback


func save_prefs() -> void:
  if disabled:
    return
  _config.save(PATH)
