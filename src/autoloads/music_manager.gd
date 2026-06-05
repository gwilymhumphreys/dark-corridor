class_name MusicManagerAutoload
extends Node

## Shuffled background music with crossfade between tracks.
##
## Loads every .ogg in MUSIC_DIR and plays them in a reshuffled order, blending
## from one track to the next via two players. No-ops cleanly when the directory
## is empty or missing, so it's safe to run before any music assets exist.

const MUSIC_DIR: String = 'res://assets/music/'
const BUS_MUSIC: String = 'Music'
const CROSSFADE_TIME: float = 2.0

var _tracks: Array[AudioStream] = []
var _shuffle_order: Array[int] = []
var _shuffle_index: int = -1

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _inactive_player: AudioStreamPlayer

var _crossfading: bool = false
var _crossfade_timer: float = 0.0
var _started: bool = false


func _ready() -> void:
  process_mode = Node.PROCESS_MODE_ALWAYS
  _load_tracks()
  _create_players()
  _reshuffle()
  if _tracks.is_empty():
    set_process(false)
    return
  if OS.has_feature('web'):
    # Web gates the AudioContext until the first user gesture; wait for input.
    set_process(false)
  else:
    _started = true
    _play_next()


# On web, start playback on the first input so music isn't silently blocked by
# the browser's autoplay policy.
func _input(event: InputEvent) -> void:
  if _started or _tracks.is_empty():
    return
  if event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch:
    _started = true
    set_process(true)
    _play_next()


func _load_tracks() -> void:
  var dir: DirAccess = DirAccess.open(MUSIC_DIR)
  if dir == null:
    return
  dir.list_dir_begin()
  var file_name: String = dir.get_next()
  while file_name != '':
    if not dir.current_is_dir() and file_name.ends_with('.ogg'):
      var stream: AudioStream = load(MUSIC_DIR + file_name)
      if stream:
        _tracks.append(stream)
    file_name = dir.get_next()
  dir.list_dir_end()


func _create_players() -> void:
  _player_a = AudioStreamPlayer.new()
  _player_b = AudioStreamPlayer.new()
  if AudioServer.get_bus_index(BUS_MUSIC) != -1:
    _player_a.bus = BUS_MUSIC
    _player_b.bus = BUS_MUSIC
  _player_b.volume_db = -80.0
  add_child(_player_a)
  add_child(_player_b)
  _active_player = _player_a
  _inactive_player = _player_b


func _reshuffle() -> void:
  _shuffle_order.clear()
  for i: int in range(_tracks.size()):
    _shuffle_order.append(i)
  for i: int in range(_shuffle_order.size() - 1, 0, -1):
    var j: int = randi() % (i + 1)
    var tmp: int = _shuffle_order[i]
    _shuffle_order[i] = _shuffle_order[j]
    _shuffle_order[j] = tmp
  _shuffle_index = -1


## Advance the shuffle cursor to the next track index, reshuffling when the
## playlist is exhausted. Shared by _play_next and _start_crossfade.
func _advance_index() -> int:
  _shuffle_index += 1
  if _shuffle_index >= _shuffle_order.size():
    _reshuffle()
    _shuffle_index = 0
  return _shuffle_order[_shuffle_index]


func _play_next() -> void:
  if _tracks.is_empty():
    return
  var idx: int = _advance_index()
  _active_player.stream = _tracks[idx]
  _active_player.volume_db = 0.0
  _active_player.play()


func _start_crossfade() -> void:
  if _tracks.is_empty() or _crossfading:
    return
  var idx: int = _advance_index()

  var tmp: AudioStreamPlayer = _active_player
  _active_player = _inactive_player
  _inactive_player = tmp

  _active_player.stream = _tracks[idx]
  _active_player.volume_db = -80.0
  _active_player.play()

  _crossfading = true
  _crossfade_timer = 0.0


func _notification(what: int) -> void:
  if what == NOTIFICATION_APPLICATION_FOCUS_IN:
    if _active_player and _active_player.stream and not _active_player.playing:
      _active_player.play()


func _process(delta: float) -> void:
  if not _crossfading:
    if _active_player.playing and _active_player.stream:
      var position: float = _active_player.get_playback_position()
      var remaining: float = _active_player.stream.get_length() - position
      # Only crossfade once we're actually near the end — guarding on `position`
      # stops tracks shorter than CROSSFADE_TIME from crossfading on frame one.
      if position >= CROSSFADE_TIME and remaining <= CROSSFADE_TIME:
        _start_crossfade()
    elif not _active_player.playing:
      _play_next()
    return

  _crossfade_timer += delta
  var t: float = clampf(_crossfade_timer / CROSSFADE_TIME, 0.0, 1.0)

  _active_player.volume_db = linear_to_db(t)
  _inactive_player.volume_db = linear_to_db(1.0 - t)

  if t >= 1.0:
    _crossfading = false
    _inactive_player.stop()
    _inactive_player.volume_db = -80.0


func _exit_tree() -> void:
  if _player_a:
    _player_a.stop()
    _player_a.stream = null
  if _player_b:
    _player_b.stop()
    _player_b.stream = null
  _tracks.clear()
  _shuffle_order.clear()
