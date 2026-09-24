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
## A sound folder may hold this file, containing one number: how many decibels to adjust that
## sound by. It balances a sound against the others without re-encoding the recordings, which
## matters because peak level is a poor guide to how loud something sounds — a sharp hit and a
## spread-out rustle at the same peak are not heard as equally loud.
const VOLUME_FILE: String = 'volume.cfg'
## A folder volume is clamped to this range, so a mistyped value cannot silence a sound or deafen.
const VOLUME_MIN_DB: float = -40.0
const VOLUME_MAX_DB: float = 12.0
## Loaded at boot rather than on first play, because these answer an input directly and a
## load pause would read as lag.
const PRELOAD_FOLDERS: Array[String] = ['ui/hover', 'ui/click', 'world/footsteps/steps']
## Every folder under these categories starts loading on a background thread at boot. Combat
## sounds were loaded the first time each one played, on the frame the hit landed, and the
## load showed as a stutter on the first hits of a run.
const BACKGROUND_LOAD_CATEGORIES: Array[String] = ['mechanics', 'combat', 'statuses']
## Audio file extensions, most preferred first. A sound is kept in the repository as both the
## original .wav and a much smaller .mp3; the same name with two extensions is one sound, not two
## variants. The web build prefers the mp3 so the player downloads less, everything else prefers
## the original.
const EXTENSIONS_BY_QUALITY: Array[String] = ['.wav', '.ogg', '.mp3']
const EXTENSIONS_BY_SIZE: Array[String] = ['.mp3', '.ogg', '.wav']
## Audio driver name used when there is no real output device (headless runs).
const DUMMY_DRIVER: String = 'Dummy'

# Bus name -> its AudioStreamPlayer, and bus name -> its playback handle. Made on first use,
# so a bus nothing ever plays on gets no player. See _ensure_playing for why that matters.
var _players: Dictionary = {}
var _playbacks: Dictionary = {}
# Folder path (e.g. 'ui/hover') -> Array[AudioStream]. An empty array is cached too, so a
# folder that does not exist is not rescanned on every play.
var _banks: Dictionary = {}
# Folder path -> its volume adjustment in decibels. A folder with no VOLUME_FILE caches 0.0,
# so a folder without one is not rescanned on every play.
var _volumes: Dictionary = {}
# Folder paths already warned about, so a missing folder warns once rather than every play.
var _warned: Dictionary = {}
# File paths requested on a background thread and not yet collected. _try_load collects one,
# waiting for it only if it has not finished.
var _pending_loads: Dictionary = {}
# True when nothing is listening (headless dummy driver, --autotest or --shot). Set in _ready.
var _silent: bool = false

var _cooldowns: Dictionary = {}


func _ready() -> void:
  _silent = _is_silent_run()
  if not _silent:
    for category: String in BACKGROUND_LOAD_CATEGORIES:
      _request_background_loads(SOUND_ROOT + category + '/')
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
  return DevArgs.is_silent_run()


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
  if _pending_loads.has(path):
    _pending_loads.erase(path)
    return ResourceLoader.load_threaded_get(path) as AudioStream
  if ResourceLoader.exists(path):
    return load(path) as AudioStream
  return null


## Start loading every sound in `dir_path` and the folders below it on a background thread.
## _try_load collects each result when its folder is first played.
func _request_background_loads(dir_path: String) -> void:
  for file_path: String in _sound_files(dir_path):
    if ResourceLoader.load_threaded_request(file_path) == OK:
      _pending_loads[file_path] = true
  var dir: DirAccess = DirAccess.open(dir_path)
  if dir == null:
    return
  for sub: String in dir.get_directories():
    _request_background_loads(dir_path + sub + '/')


## One stream per sound in `dir`, in no particular order. A missing folder gives [].
func _load_folder(dir_path: String) -> Array[AudioStream]:
  var streams: Array[AudioStream] = []
  for file_path: String in _sound_files(dir_path):
    var stream: AudioStream = _try_load(file_path)
    if stream:
      streams.append(stream)
  return streams


## The path of each sound in `dir_path`, not looking in subfolders. Files sharing a name before
## the extension are the same sound in different formats, so only the preferred one is listed.
## A missing folder gives [].
func _sound_files(dir_path: String) -> Array[String]:
  var files: Array[String] = []
  var dir: DirAccess = DirAccess.open(dir_path)
  if dir == null:
    return files
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
        files.append(dir_path + base + extension)
        break
  return files


## The volume adjustment for the folder `path`, in decibels, read from its VOLUME_FILE and
## cached. A folder without the file, or with one that does not read as a number, adjusts by 0.
func _volume_for(path: String) -> float:
  if _volumes.has(path):
    return _volumes[path]
  var db: float = 0.0
  var file_path: String = SOUND_ROOT + path + '/' + VOLUME_FILE
  if FileAccess.file_exists(file_path):
    var text: String = FileAccess.get_file_as_string(file_path).strip_edges()
    if text.is_valid_float():
      db = clampf(text.to_float(), VOLUME_MIN_DB, VOLUME_MAX_DB)
      if db != text.to_float():
        _warn_once('volume:' + path,
            'SfxManager: %s in "%s" is outside %.0f to %.0f dB; clamped to %.1f' % [
              VOLUME_FILE, path, VOLUME_MIN_DB, VOLUME_MAX_DB, db])
    else:
      _warn_once('volume:' + path,
          'SfxManager: %s in "%s" is not a number; using 0 dB' % [VOLUME_FILE, path])
  _volumes[path] = db
  return db


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


## The folder whose recordings a request for `path` actually plays, or '' when nothing does.
## An empty folder falls back to its parent, then that parent's parent and so on, so a variant
## such as mechanics/attack/blade/shielded that has not been filled in yet plays the nearest
## folder above it that has. The category's FALLBACK_FOLDER is the last resort, so a newly
## authored mechanic or status is never silent.
##
## `fall_back` false means an empty folder plays nothing at all. An optional layer needs this, such
## as the travel layer, which picks its own folder and must not play a category's _default
## sound during a flight.
func _resolve_folder(path: String, fall_back: bool = true) -> String:
  if not fall_back:
    if _bank_for(path).is_empty():
      _warn_once('missing:' + path, 'SfxManager: no sounds found in folder "%s"' % path)
      return ''
    return path
  var candidate: String = path
  while true:
    if not _bank_for(candidate).is_empty():
      return candidate
    _warn_once('missing:' + candidate, 'SfxManager: no sounds found in folder "%s"' % candidate)
    if candidate.count('/') < 2:
      break
    candidate = candidate.left(candidate.rfind('/'))
  var slash: int = path.find('/')
  if slash < 0:
    return ''
  var fallback_path: String = path.left(slash) + '/' + FALLBACK_FOLDER
  if fallback_path == path or _bank_for(fallback_path).is_empty():
    _warn_once('missing:' + fallback_path,
        'SfxManager: no sounds found in fallback folder "%s"' % fallback_path)
    return ''
  return fallback_path


## Play one sound from the folder `path` under assets/sound-effects/, chosen at random from
## the recordings in it, with the usual random pitch jitter. An empty folder falls back up its
## parents and then to its category's `FALLBACK_FOLDER` (_resolve_folder). `volume_db` is added
## to the played folder's own adjustment (_volume_for) rather than replacing it. A negative
## pitch picks a random jitter; pass a value to override. `fall_back` false makes an empty
## folder silent instead. Returns the polyphonic stream id, or -1 if nothing played.
func play_sound(path: String, pitch: float = -1.0, volume_db: float = 0.0,
    fall_back: bool = true) -> int:
  if _silent or path == '':
    return -1
  var played_path: String = _resolve_folder(path, fall_back)
  if played_path == '':
    return -1
  var bank: Array[AudioStream] = _bank_for(played_path)
  var stream: AudioStream = _pick(bank)
  if stream == null:
    return -1
  volume_db += _volume_for(played_path)
  var bus_name: String = bus_for(path)
  var player: AudioStreamPlayer = _player_on(bus_name)
  _playbacks[bus_name] = _ensure_playing(player, _playbacks.get(bus_name, null))
  var playback: AudioStreamPlaybackPolyphonic = _playbacks[bus_name]
  if playback == null:
    return -1
  if pitch < 0.0:
    pitch = randf_range(PITCH_JITTER_MIN, PITCH_JITTER_MAX)
  return playback.play_stream(stream, 0.0, volume_db, pitch)


## Whether the folder `path` holds any sounds of its own, with no fallback. Lets a caller walk
## its own order of folders. Always false in a silent run, so nothing is loaded there.
func has_sounds(path: String) -> bool:
  if _silent or path == '':
    return false
  return not _bank_for(path).is_empty()


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
  # A threaded load that is never collected is reported as leaked at exit.
  for file_path: String in _pending_loads:
    ResourceLoader.load_threaded_get(file_path)
  _pending_loads.clear()
  _banks.clear()
  _volumes.clear()
  _cooldowns.clear()
