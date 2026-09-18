class_name SfxManagerAutoload
extends Node

## Lightweight one-shot sound effect player.
##
## A single polyphonic stream player handles many overlapping sounds cheaply.
## A short per-key cooldown stops the same sound machine-gunning on rapid
## triggers (e.g. hover), and each play gets a small random pitch jitter so
## repeats don't sound robotic.
##
## Every play_* helper no-ops gracefully when its stream is missing, so callers
## (such as the UI juice node) work fine before any audio assets exist. Drop
## files in the UI_*_DIR folders and they join that sound's pool automatically;
## each play picks one of the pool at random so a repeated action doesn't
## repeat the same recording. A sound kept as both .wav and .mp3 counts once.

const BUS_EFFECTS: String = 'Effects'
const POLYPHONY: int = 32
const COOLDOWN_TIME: float = 0.08
const PITCH_JITTER_MIN: float = 0.92
const PITCH_JITTER_MAX: float = 1.08

# Shared default UI sound bank. Every audio file in the folder is a variant of
# that sound. An empty or missing folder leaves the helper a silent no-op.
const UI_HOVER_DIR: String = 'res://assets/sound-effects/ui/hover/'
const UI_CLICK_DIR: String = 'res://assets/sound-effects/ui/click/'
## Audio file extensions, most preferred first. A sound is kept in the repository as both the
## original .wav and a much smaller .mp3; the same name with two extensions is one sound, not two
## variants. The web build prefers the mp3 so the player downloads less, everything else prefers
## the original.
const EXTENSIONS_BY_QUALITY: Array[String] = ['.wav', '.ogg', '.mp3']
const EXTENSIONS_BY_SIZE: Array[String] = ['.mp3', '.ogg', '.wav']
## Audio driver name used when there is no real output device (headless runs).
const DUMMY_DRIVER: String = 'Dummy'
## Command-line flags for runs that play no sound — the autotest harness and a --shot screenshot
## capture. Prefs mutes the Master bus for these; here they also skip loading the sound files.
const SILENT_ARGS: Array[String] = ['--autotest', '--shot']
# Combat. No file is in the project yet, so play_impact() is silent until one is dropped here.
const COMBAT_IMPACT_PATH: String = 'res://assets/sound-effects/combat/impact.mp3'

var _poly_player: AudioStreamPlayer
var _poly_playback: AudioStreamPlaybackPolyphonic
var _cooldowns: Dictionary = {}

var _ui_hover_streams: Array[AudioStream] = []
var _ui_click_streams: Array[AudioStream] = []
var _impact_stream: AudioStream


func _ready() -> void:
  _create_player()
  _load_ui_bank()
  # Only process while cooldowns are pending; re-enabled in play_guarded().
  set_process(false)


func _process(delta: float) -> void:
  _update_cooldowns(delta)


func _create_player() -> void:
  var poly: AudioStreamPolyphonic = AudioStreamPolyphonic.new()
  poly.polyphony = POLYPHONY
  _poly_player = AudioStreamPlayer.new()
  _poly_player.stream = poly
  if AudioServer.get_bus_index(BUS_EFFECTS) != -1:
    _poly_player.bus = BUS_EFFECTS
  # Not autoplayed: the first play() starts it (_ensure_poly_playing). A playback started with
  # nothing to play is never released under the headless dummy audio driver and leaks at exit.
  add_child(_poly_player)


func _load_ui_bank() -> void:
  # Headless runs get the dummy driver, which never releases a playback, so a
  # sound played during a test is reported as leaked at exit. Autotest and
  # screenshot runs are silent too, so neither needs the files decoded.
  if AudioServer.get_driver_name() == DUMMY_DRIVER:
    return
  var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
  for flag: String in SILENT_ARGS:
    if flag in args:
      return
  _ui_hover_streams = _load_folder(UI_HOVER_DIR)
  _ui_click_streams = _load_folder(UI_CLICK_DIR)
  _impact_stream = _try_load(COMBAT_IMPACT_PATH)


func _try_load(path: String) -> AudioStream:
  if ResourceLoader.exists(path):
    return load(path) as AudioStream
  return null


## One stream per sound in `dir`, in no particular order. Files sharing a name before the
## extension are the same sound in different formats, so only the preferred one is loaded.
## A missing folder gives [].
func _load_folder(dir_path: String) -> Array[AudioStream]:
  var streams: Array[AudioStream] = []
  var dir: DirAccess = DirAccess.open(dir_path)
  if dir == null:
    return streams
  var order: Array[String] = EXTENSIONS_BY_SIZE if OS.has_feature('web') else EXTENSIONS_BY_QUALITY
  # Each name before the extension maps to the extensions found for it.
  var by_name: Dictionary = {}
  dir.list_dir_begin()
  var file_name: String = dir.get_next()
  while file_name != '':
    if not dir.current_is_dir():
      var extension: String = '.' + file_name.get_extension().to_lower()
      if extension in order:
        var base: String = file_name.get_basename()
        if not by_name.has(base):
          by_name[base] = [] as Array[String]
        by_name[base].append(extension)
    file_name = dir.get_next()
  dir.list_dir_end()
  for base: String in by_name:
    for extension: String in order:
      if extension in by_name[base]:
        var stream: AudioStream = _try_load(dir_path + base + extension)
        if stream:
          streams.append(stream)
        break
  return streams


func _pick(streams: Array[AudioStream]) -> AudioStream:
  if streams.is_empty():
    return null
  return streams[randi() % streams.size()]


## Play a one-shot. A negative pitch picks a random jitter; pass a value to
## override. Returns the polyphonic stream id, or -1 if nothing played.
func play(stream: AudioStream, pitch: float = -1.0, volume_db: float = 0.0) -> int:
  if stream == null:
    return -1
  _ensure_poly_playing()
  if _poly_playback == null:
    return -1
  if pitch < 0.0:
    pitch = randf_range(PITCH_JITTER_MIN, PITCH_JITTER_MAX)
  return _poly_playback.play_stream(stream, 0.0, volume_db, pitch)


## Cooldown-guarded one-shot keyed by `key`. Repeated calls within
## COOLDOWN_TIME are dropped. Use for rapid triggers like hover.
func play_guarded(key: String, stream: AudioStream, pitch: float = -1.0, volume_db: float = 0.0) -> void:
  if stream == null:
    return
  if _cooldowns.has(key):
    return
  _cooldowns[key] = COOLDOWN_TIME
  set_process(true)
  play(stream, pitch, volume_db)


func play_ui_hover() -> void:
  play_guarded('ui_hover', _pick(_ui_hover_streams))


func play_ui_click() -> void:
  play_guarded('ui_click', _pick(_ui_click_streams))


## A hit landing in combat. Guarded, so a burst of hits in the same moment makes one sound
## instead of a pile.
func play_impact() -> void:
  play_guarded('combat_impact', _impact_stream)


func _ensure_poly_playing() -> void:
  if _poly_player == null:
    return
  # Each play() makes a new playback, so fetch the handle every time the player starts; a handle
  # kept from before a stop would play nothing. Also fetch it if it is still missing.
  if not _poly_player.playing:
    _poly_player.play()
    _poly_playback = null
  if _poly_playback == null:
    _poly_playback = _poly_player.get_stream_playback() as AudioStreamPlaybackPolyphonic


func _notification(what: int) -> void:
  if what == NOTIFICATION_APPLICATION_FOCUS_IN:
    _ensure_poly_playing()


func _update_cooldowns(delta: float) -> void:
  var to_remove: Array[String] = []
  for key: String in _cooldowns:
    _cooldowns[key] -= delta
    if _cooldowns[key] <= 0.0:
      to_remove.append(key)
  for key: String in to_remove:
    _cooldowns.erase(key)
  if _cooldowns.is_empty():
    set_process(false)


func _exit_tree() -> void:
  _poly_playback = null
  if _poly_player:
    _poly_player.stop()
    _poly_player.stream = null
  _ui_hover_streams.clear()
  _ui_click_streams.clear()
  _impact_stream = null
  _cooldowns.clear()
