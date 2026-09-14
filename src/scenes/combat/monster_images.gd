class_name MonsterImages
extends RefCounted
## Random painted monster images for testing (docs/systems/run_screen.md, "Enemies in the
## corridor"). Which image an enemy uses is not content: each sprite gets a random cut-out copy of
## a sample in `assets/monsters/`. The pick uses its own RandomNumberGenerator, never the run RNG,
## so seeded autotest runs are unchanged.

## The original samples, read by tools/cut_out_monsters.gd.
const FOLDER: String = 'res://assets/monsters'
## Copies with the black background made transparent, written by tools/cut_out_monsters.gd.
const CUT_OUT_FOLDER: String = 'res://assets/monsters/cut_out'

## When set, every painted enemy uses this image instead of a random one (the debug panel's
## `--monster-image=` argument, for comparing screenshots).
static var forced_path: String = ''

static var _rng: RandomNumberGenerator = null
static var _paths: Dictionary = {}   # folder -> PackedStringArray, each scanned once


## Every image path in `folder` (not its subfolders), scanned once.
static func paths(folder: String = CUT_OUT_FOLDER) -> PackedStringArray:
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
static func random_texture(folder: String = CUT_OUT_FOLDER) -> Texture2D:
  if forced_path != '':
    return load(forced_path) as Texture2D
  var all: PackedStringArray = paths(folder)
  if all.is_empty():
    return null
  if _rng == null:
    _rng = RandomNumberGenerator.new()
    _rng.randomize()
  return load(all[_rng.randi_range(0, all.size() - 1)]) as Texture2D
