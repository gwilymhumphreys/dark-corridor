class_name MonsterImages
extends RefCounted
## Random painted monster images for testing (docs/systems/run_screen.md, "Enemy-in-corridor
## occupant"). Which image an enemy uses is not content: each sprite gets a random sample from
## `assets/monsters/`. The pick uses its own RandomNumberGenerator, never the run RNG, so seeded
## autotest runs are unchanged.

const FOLDER: String = 'res://assets/monsters'

static var _rng: RandomNumberGenerator = null
static var _paths: PackedStringArray = PackedStringArray()


## Every image path in the sample folder, scanned once.
static func paths() -> PackedStringArray:
  if _paths.is_empty():
    for file_name: String in ResourceLoader.list_directory(FOLDER):
      if file_name.ends_with('/'):
        continue
      var path: String = FOLDER.path_join(file_name)
      if ResourceLoader.exists(path, 'Texture2D'):
        _paths.append(path)
    _paths.sort()
  return _paths


## A random sample image, or null if the folder is empty.
static func random_texture() -> Texture2D:
  var all: PackedStringArray = paths()
  if all.is_empty():
    return null
  if _rng == null:
    _rng = RandomNumberGenerator.new()
    _rng.randomize()
  return load(all[_rng.randi_range(0, all.size() - 1)]) as Texture2D
