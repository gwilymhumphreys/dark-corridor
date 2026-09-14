class_name MonsterImages
extends RefCounted
## Random painted monster images for testing (docs/systems/run_screen.md, "Enemy-in-corridor
## occupant"). Which image an enemy uses is not content: each sprite gets a random sample from
## `assets/monsters/`, or its cut-out copy. The pick uses its own RandomNumberGenerator, never the
## run RNG, so seeded autotest runs are unchanged.

const FOLDER: String = 'res://assets/monsters'
## Copies with the black background made transparent, written by tools/cut_out_monsters.gd.
const CUT_OUT_FOLDER: String = 'res://assets/monsters/cut_out'

static var _rng: RandomNumberGenerator = null
static var _paths: Dictionary = {}   # folder -> PackedStringArray, each scanned once


## Every image path in `folder` (not its subfolders), scanned once.
static func paths(folder: String = FOLDER) -> PackedStringArray:
  if not _paths.has(folder):
    var found: PackedStringArray = PackedStringArray()
    for file_name: String in ResourceLoader.list_directory(folder):
      if file_name.ends_with('/'):
        continue
      var path: String = folder.path_join(file_name)
      if ResourceLoader.exists(path, 'Texture2D'):
        found.append(path)
    found.sort()
    _paths[folder] = found
  return _paths[folder]


## A random image from `folder`, or null if it is empty.
static func random_texture(folder: String = FOLDER) -> Texture2D:
  var all: PackedStringArray = paths(folder)
  if all.is_empty():
    return null
  if _rng == null:
    _rng = RandomNumberGenerator.new()
    _rng.randomize()
  return load(all[_rng.randi_range(0, all.size() - 1)]) as Texture2D


## The folder for the debug panel's enemy image choice (the pixel sprite uses the originals'
## folder but never loads from it).
static func folder_for_choice() -> String:
  if DebugPanels.enemy_images == DebugPanelsAutoload.EnemyImages.CUT_OUT:
    return CUT_OUT_FOLDER
  return FOLDER
