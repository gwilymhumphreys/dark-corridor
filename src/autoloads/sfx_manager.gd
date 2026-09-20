class_name SfxManagerAutoload
extends Node

## Lightweight one-shot sound effect player.
##
## A sound is named by its folder path under assets/sound-effects/ — play_sound('ui/hover') —
## and adding a sound is a folder of recordings with no code change. Each play picks one of
## the folder's recordings at random and applies a small pitch jitter so repeats don't sound
## robotic. A short per-key cooldown (play_sound_guarded) stops the same sound
## machine-gunning on rapid triggers such as hover.
##
## The folder's first path segment picks its audio bus: interface sounds are not in the room
## and stay dry on the Interface bus; everything else goes through World, which carries the
## corridor's reverb.
##
## Every play no-ops gracefully when its folder has no recordings, so callers (such as the
## UI juice node) work fine before any audio assets exist. A folder without recordings falls
## back to its category's _default folder, so a newly authored mechanic or status is never
## silent. A sound kept as both .wav and .mp3 counts once.

const BUS_INTERFACE: String = 'Interface'
const BUS_GAME: String = 'Game'
const BUS_WORLD: String = 'World'
const POLYPHONY: int = 32
const COOLDOWN_TIME: float = 0.08
const PITCH_JITTER_MIN: float = 0.92
const PITCH_JITTER_MAX: float = 1.08
const SOUND_ROOT: String = 'res://assets/sound-effects/'
## A sound's first path segment picks its bus. Interface sounds are not in the room and stay
## dry; everything else goes through World, which carries the corridor's reverb.
const BUS_BY_CATEGORY: Dictionary = {
  'ui': BUS_INTERFACE,
  'run': BUS_INTERFACE,
  'world': BUS_WORLD,
  'mechanics': BUS_WORLD,
  'statuses': BUS_WORLD,
  'combat': BUS_WORLD,
}
## Played when a folder does not exist, so a newly authored mechanic or status is never
## silent. Looked for as the category followed by this name, e.g. 'mechanics/_default'.
const FALLBACK_FOLDER: String = '_default'
## Loaded at boot rather than on first play, because these answer an input directly and a
## load pause would read as lag.
const PRELOAD_FOLDERS: Array[String] = ['ui/hover', 'ui/click', 'world/footsteps/steps']
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

# Bus name -> its AudioStreamPlayer, and bus name -> its playback handle. Made on first use,
# so a bus nothing ever plays on gets no player. See _ensure_playing for why that matters.
var _players: Dictionary = {}
var _playbacks: Dictionary = {}
# Folder path (e.g. 'ui/hover') -> Array[AudioStream]. An empty array is cached too, so a
# folder that does not exist is not rescanned on every play.
var _banks: Dictionary = {}
# Folder paths already warned about, so a missing folder warns once rather than every play.
var _warned: Dictionary = {}
# True when nothing is listening (headless dummy driver, --autotest or --shot). Set in _ready.
var _silent: bool = false

var _cooldowns: Dictionary = {}


func _ready() -> void:
  _silent = _is_silent_run()
  if not _silent:
    for path: String in PRELOAD_FOLDERS:
      _banks[path] = _load_folder(SOUND_ROOT + path + '/')
  # Only process while cooldowns are pending; re-enabled in play_guarded().
  set_process(false)


func _process(delta: float) -> void:
  _update_cooldowns(delta)


## True when no audio is ever heard in this run: the headless dummy driver, which never
## releases a playback (a sound played during a test would be reported as leaked at exit), or
## an autotest / screenshot run. Both skip decoding the sound files too.
func _is_silent_run() -> bool:
  if AudioServer.get_driver_name() == DUMMY_DRIVER:
    return true
  var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
  for flag: String in SILENT_ARGS:
    if flag in args:
      return true
  return false


## A configured polyphonic stream player for `bus_name`: not autoplayed, for the reason in
## _ensure_playing. Returns it without a parent so the caller can add it.
func _make_poly_player(bus_name: String) -> AudioStreamPlayer:
  var poly: AudioStreamPolyphonic = AudioStreamPolyphonic.new()
  poly.polyphony = POLYPHONY
  var player: AudioStreamPlayer = AudioStreamPlayer.new()
  player.stream = poly
  if AudioServer.get_bus_index(bus_name) != -1:
    player.bus = bus_name
  # Not autoplayed: the first play starts it (_ensure_playing). A playback started with
  # nothing to play is never released under the headless dummy audio driver and leaks at exit.
  return player


## The player on `bus_name`, made with _make_poly_player on first use and stored in _players.
func _player_on(bus_name: String) -> AudioStreamPlayer:
  if not _players.has(bus_name):
    var player: AudioStreamPlayer = _make_poly_player(bus_name)
    add_child(player)
    _players[bus_name] = player
  return _players[bus_name]


## The streams in the folder `path` under assets/sound-effects/, loaded on the first call and
## cached after, empty included, so a missing folder is not rescanned on every play.
func _bank_for(path: String) -> Array[AudioStream]:
  if not _banks.has(path):
    _banks[path] = _load_folder(SOUND_ROOT + path + '/')
  return _banks[path]


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


## Warn once per `key`, in debug builds only, so a typo is not silently inaudible without
## spamming a release log. A missing folder and an unknown category are separate keys for the
## same path, so reporting one does not silence the other.
func _warn_once(key: String, message: String) -> void:
  if _warned.has(key):
    return
  _warned[key] = true
  if OS.is_debug_build():
    push_warning(message)


## The bus a folder path plays on. The first path segment is the category; an unrecognised
## one uses the interface bus. Public so the mapping can be tested without an audio device.
func bus_for(path: String) -> String:
  var slash: int = path.find('/')
  var category: String = path if slash < 0 else path.left(slash)
  if not BUS_BY_CATEGORY.has(category):
    _warn_once('category:' + path,
        'SfxManager: unknown sound category "%s" in "%s"; using the interface bus' % [category, path])
    return BUS_INTERFACE
  return BUS_BY_CATEGORY[category]


## Play one sound from the folder `path` under assets/sound-effects/, chosen at random from
## the recordings in it, with the usual random pitch jitter. A folder with no sounds falls
## back to its category's `FALLBACK_FOLDER`. A negative pitch picks a random jitter; pass a
## value to override. Returns the polyphonic stream id, or -1 if nothing played.
func play_sound(path: String, pitch: float = -1.0, volume_db: float = 0.0) -> int:
  if _silent or path == '':
    return -1
  var bank: Array[AudioStream] = _bank_for(path)
  if bank.is_empty():
    _warn_once('missing:' + path, 'SfxManager: no sounds found in folder "%s"' % path)
    # A variant folder (two or more slashes) falls back to its parent before the category
    # fallback, so an empty variant such as mechanics/attack/shielded plays mechanics/attack.
    # A one-slash path's parent is the category folder itself, which holds only subfolders,
    # so it goes straight to the category fallback.
    if path.count('/') >= 2:
      var parent_path: String = path.left(path.rfind('/'))
      bank = _bank_for(parent_path)
      if bank.is_empty():
        _warn_once('missing:' + parent_path,
            'SfxManager: no sounds found in folder "%s"' % parent_path)
    if bank.is_empty():
      var fallback_path: String = path if path.find('/') < 0 else path.left(path.find('/')) + '/' + FALLBACK_FOLDER
      if fallback_path != path:
        bank = _bank_for(fallback_path)
        if bank.is_empty():
          _warn_once('missing:' + fallback_path,
              'SfxManager: no sounds found in fallback folder "%s"' % fallback_path)
  if bank.is_empty():
    return -1
  var stream: AudioStream = _pick(bank)
  if stream == null:
    return -1
  var bus_name: String = bus_for(path)
  var player: AudioStreamPlayer = _player_on(bus_name)
  _playbacks[bus_name] = _ensure_playing(player, _playbacks.get(bus_name, null))
  var playback: AudioStreamPlaybackPolyphonic = _playbacks[bus_name]
  if playback == null:
    return -1
  if pitch < 0.0:
    pitch = randf_range(PITCH_JITTER_MIN, PITCH_JITTER_MAX)
  return playback.play_stream(stream, 0.0, volume_db, pitch)


## Cooldown-guarded `play_sound`, keyed by `key`. Repeated calls within COOLDOWN_TIME are
## dropped. Use for rapid triggers like hover.
func play_sound_guarded(key: String, path: String, pitch: float = -1.0,
    volume_db: float = 0.0) -> void:
  if path == '':
    return
  if _cooldowns.has(key):
    return
  _cooldowns[key] = COOLDOWN_TIME
  set_process(true)
  play_sound(path, pitch, volume_db)


## Play a one-shot. A negative pitch picks a random jitter; pass a value to
## override. Returns the polyphonic stream id, or -1 if nothing played.
func play(stream: AudioStream, pitch: float = -1.0, volume_db: float = 0.0) -> int:
  if stream == null:
    return -1
  var player: AudioStreamPlayer = _player_on(BUS_INTERFACE)
  _playbacks[BUS_INTERFACE] = _ensure_playing(player, _playbacks.get(BUS_INTERFACE, null))
  if _playbacks[BUS_INTERFACE] == null:
    return -1
  if pitch < 0.0:
    pitch = randf_range(PITCH_JITTER_MIN, PITCH_JITTER_MAX)
  return _playbacks[BUS_INTERFACE].play_stream(stream, 0.0, volume_db, pitch)


## Play a one-shot through the world channel, which carries the corridor reverb. A negative
## pitch picks a random jitter, as `play()` does. Returns the stream id, or -1 if nothing played.
func play_world(stream: AudioStream, pitch: float = -1.0, volume_db: float = 0.0) -> int:
  if stream == null:
    return -1
  var player: AudioStreamPlayer = _player_on(BUS_WORLD)
  _playbacks[BUS_WORLD] = _ensure_playing(player, _playbacks.get(BUS_WORLD, null))
  if _playbacks[BUS_WORLD] == null:
    return -1
  if pitch < 0.0:
    pitch = randf_range(PITCH_JITTER_MIN, PITCH_JITTER_MAX)
  return _playbacks[BUS_WORLD].play_stream(stream, 0.0, volume_db, pitch)


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


## Cooldown-guarded one-shot through the world channel, keyed by `key`. Repeated calls within
## COOLDOWN_TIME are dropped.
func play_guarded_world(key: String, stream: AudioStream, pitch: float = -1.0, volume_db: float = 0.0) -> void:
  if stream == null:
    return
  if _cooldowns.has(key):
    return
  _cooldowns[key] = COOLDOWN_TIME
  set_process(true)
  play_world(stream, pitch, volume_db)


## A hover on a UI control. Guarded, so sweeping the pointer across a menu makes one sound.
func play_ui_hover() -> void:
  play_sound_guarded('ui_hover', 'ui/hover')


## A click on a UI control. Guarded, so a double click makes one sound.
func play_ui_click() -> void:
  play_sound_guarded('ui_click', 'ui/click')


## A footstep landing in the corridor. Guarded, so two footfalls in one frame make one sound.
func play_footstep() -> void:
  play_sound_guarded('footstep', 'world/footsteps/steps')


## Start `player` if it is not playing and return its playback. Each play() makes a new playback,
## so fetch the handle every time the player starts; a handle kept from before a stop would play
## nothing. Also fetch it if `playback` is still missing. Returns `playback` unchanged if the
## player is null.
func _ensure_playing(player: AudioStreamPlayer, playback: AudioStreamPlaybackPolyphonic) -> AudioStreamPlaybackPolyphonic:
  if player == null:
    return playback
  if not player.playing:
    player.play()
    playback = null
  if playback == null:
    playback = player.get_stream_playback() as AudioStreamPlaybackPolyphonic
  return playback


func _notification(what: int) -> void:
  if what == NOTIFICATION_APPLICATION_FOCUS_IN:
    for bus_name: String in _players:
      _playbacks[bus_name] = _ensure_playing(_players[bus_name], _playbacks.get(bus_name, null))


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
  for bus_name: String in _players:
    _playbacks[bus_name] = null
    var player: AudioStreamPlayer = _players[bus_name]
    if player:
      player.stop()
      player.stream = null
  _players.clear()
  _playbacks.clear()
  _banks.clear()
  _cooldowns.clear()
