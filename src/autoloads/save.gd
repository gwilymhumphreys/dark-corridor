class_name SaveAutoload
extends Node
## The run-persistence service (docs/systems/save.md) — autoload registered `Save`. Push, not
## pull: the Run manager HANDS it a snapshot Dictionary (write on encounter entry);
## on load it returns that snapshot for the Game manager to hand back to a fresh
## Run manager. It holds no live state and reads no live system.
##
## JSON to `user://`, written atomically (temp file → rename) so a quit mid-write
## can't corrupt the slot. One run slot, overwritten each save; cleared on
## death / final-boss win. NO migration (CLAUDE.md): an absent, unreadable, or
## version-incompatible save returns {} (empty = none) → the caller starts fresh.

const PATH: String = 'user://dark_corridor_run.save'
const TMP_PATH: String = 'user://dark_corridor_run.save.tmp'
const VERSION: int = 0

## When true, write() is a no-op — the headless autotest sets this (its forced
## `nosave`) so a dev run can't clobber the real run slot. The game never sets it;
## TestCleanup resets it to false between tests.
var disabled: bool = false


## Persist a handed snapshot. Stamps the format version, serializes to JSON, and
## swaps it in atomically. Note: snapshot numbers that must stay exact past 2^53
## (the run RNG state) are the Run manager's job to encode as strings — JSON
## numbers are doubles. A no-op while `disabled` (the autotest's nosave).
func write(snapshot: Dictionary) -> void:
  if disabled:
    return
  var payload: Dictionary = snapshot.duplicate(true)
  payload['version'] = VERSION
  var tmp: FileAccess = FileAccess.open(TMP_PATH, FileAccess.WRITE)
  if tmp == null:
    push_warning('[Save] could not open %s (error %d)' % [TMP_PATH, FileAccess.get_open_error()])
    return
  tmp.store_string(JSON.stringify(payload))
  tmp.close()
  var dir: DirAccess = DirAccess.open('user://')
  if dir == null:
    push_warning('[Save] could not open user:// to commit the save')
    return
  if dir.file_exists(PATH):
    dir.remove(PATH)
  dir.rename(TMP_PATH, PATH)


## Return the saved run snapshot, or {} for "no usable save" (absent / unreadable /
## not a dict / wrong version — no migration, so an old format is discarded).
func read() -> Dictionary:
  if not FileAccess.file_exists(PATH):
    return {}
  var text: String = FileAccess.get_file_as_string(PATH)
  if text.is_empty():
    return {}
  var json: JSON = JSON.new()
  if json.parse(text) != OK:
    return {}   # unreadable / corrupt → discard (no migration)
  var data: Variant = json.data
  if not data is Dictionary:
    return {}
  if int(data.get('version', -1)) != VERSION:
    return {}
  return data


func has_save() -> bool:
  return FileAccess.file_exists(PATH)


## Drop the run save (death / win). Also clears any stray temp file.
func clear() -> void:
  var dir: DirAccess = DirAccess.open('user://')
  if dir == null:
    return
  if dir.file_exists(PATH):
    dir.remove(PATH)
  if dir.file_exists(TMP_PATH):
    dir.remove(TMP_PATH)
