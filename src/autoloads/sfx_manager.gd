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
## files at the UI_*_PATH locations and they're picked up automatically.

const BUS_EFFECTS: String = 'Effects'
const POLYPHONY: int = 32
const COOLDOWN_TIME: float = 0.08
const PITCH_JITTER_MIN: float = 0.92
const PITCH_JITTER_MAX: float = 1.08

# Shared default UI sound bank. Missing files leave the helper a silent no-op.
const UI_HOVER_PATH: String = 'res://assets/sound-effects/ui/hover.wav'
const UI_CLICK_PATH: String = 'res://assets/sound-effects/ui/click.wav'
const UI_PRESS_PATH: String = 'res://assets/sound-effects/ui/press.wav'

var _poly_player: AudioStreamPlayer
var _poly_playback: AudioStreamPlaybackPolyphonic
var _cooldowns: Dictionary = {}

var _ui_hover_stream: AudioStream
var _ui_click_stream: AudioStream
var _ui_press_stream: AudioStream


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
  _poly_player.autoplay = true
  add_child(_poly_player)
  _poly_playback = _poly_player.get_stream_playback() as AudioStreamPlaybackPolyphonic


func _load_ui_bank() -> void:
  _ui_hover_stream = _try_load(UI_HOVER_PATH)
  _ui_click_stream = _try_load(UI_CLICK_PATH)
  _ui_press_stream = _try_load(UI_PRESS_PATH)


func _try_load(path: String) -> AudioStream:
  if ResourceLoader.exists(path):
    return load(path) as AudioStream
  return null


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
  play_guarded('ui_hover', _ui_hover_stream)


func play_ui_click() -> void:
  play_guarded('ui_click', _ui_click_stream)


func play_ui_press() -> void:
  play_guarded('ui_press', _ui_press_stream)


func _ensure_poly_playing() -> void:
  if _poly_player == null:
    return
  if not _poly_player.playing:
    _poly_player.play()
  # At boot get_stream_playback() can return null while autoplay is still
  # starting; re-fetch whenever the handle is missing so SFX aren't silenced.
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
  _ui_hover_stream = null
  _ui_click_stream = null
  _ui_press_stream = null
  _cooldowns.clear()
