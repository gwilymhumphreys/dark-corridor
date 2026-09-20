class_name IconSlots
## Owns the game's icon slots — a name that owns one icon — and the icon chosen for each
## (docs/plans/mechanic_icons.md). Static only, like `MechanicRegistry` beside it: nothing here
## is an autoload. The ten mechanic ids are slots, and so are two things that are not mechanics:
## `charge_time` (an item's `cooldown`) and `card` (an item referred to without naming it).
##
## Each slot has a folder of candidate icons at `res://assets/icons/mechanics/<slot>/` and a
## default inside it (`DEFAULTS`). A chosen icon is saved to `CHOSEN_PATH` on every `set_icon`
## and read back lazily on first use; a missing file is not an error, so every slot falls back
## to its default.


## The slot for an item's `cooldown` — the one slot the tooltip draws that is not a keyword.
const CHARGE_TIME: String = 'charge_time'


const SLOTS: Array[String] = [
  'attack', 'shield', 'heal', 'poison', 'burn', 'bleed',
  'regen', 'crit', 'charge', 'decharge', 'charge_time', 'card',
]


const DEFAULTS: Dictionary = {
  'attack': 'res://assets/icons/mechanics/attack/crossed-swords.png',
  'shield': 'res://assets/icons/mechanics/shield/shield.png',
  'heal': 'res://assets/icons/mechanics/heal/heart-plus.png',
  'poison': 'res://assets/icons/mechanics/poison/skull-crossed-bones.png',
  'burn': 'res://assets/icons/mechanics/burn/fire.png',
  'bleed': 'res://assets/icons/mechanics/bleed/droplets.png',
  'regen': 'res://assets/icons/mechanics/regen/cycle.png',
  'crit': 'res://assets/icons/mechanics/crit/round-star.png',
  'charge': 'res://assets/icons/mechanics/charge/fast-forward-button.png',
  'decharge': 'res://assets/icons/mechanics/decharge/fast-backward-button.png',
  'charge_time': 'res://assets/icons/mechanics/charge_time/hourglass.png',
  'card': 'res://assets/icons/mechanics/card/card-draw.png',
}


const CHOSEN_PATH: String = 'res://assets/icons/mechanics/chosen.cfg'


static var _chosen: Dictionary = {}
static var _built: bool = false


## The icon a slot shows: the chosen path if one is set, else the slot's default, else `''`
## for an unknown slot.
static func icon_for(slot: String) -> String:
  _load_chosen()
  if _chosen.has(slot):
    return _chosen[slot]
  if not DEFAULTS.has(slot):
    return ''
  return DEFAULTS[slot]


## Every `.png` in the slot's folder as full `res://` paths, sorted by file name. In an exported
## build the folder cannot be listed, so the slot's default alone is returned instead.
static func candidates(slot: String) -> Array[String]:
  if not DEFAULTS.has(slot):
    return []
  var paths: Array[String] = []
  var folder: String = 'res://assets/icons/mechanics/' + slot
  var dir: DirAccess = DirAccess.open(folder)
  if dir == null:   # exported build: the folder cannot be listed, fall back to the default
    return [DEFAULTS[slot]]
  var names: PackedStringArray = dir.get_files()
  names.sort()
  for file_name: String in names:
    if file_name.get_extension().to_lower() != 'png':
      continue   # skip the `.import` sidecar files
    paths.append(folder.path_join(file_name))
  return paths


## The slot's display name: `'charge_time'` gives `'Charge time'`, `'attack'` gives `'Attack'`.
## Only the first letter is upper-cased; the rest stays lower-case.
static func display_name(slot: String) -> String:
  if not DEFAULTS.has(slot):
    return ''
  var spaced: String = slot.replace('_', ' ')
  return spaced.left(1).to_upper() + spaced.right(-1).to_lower()


## Records the slot's chosen icon and saves `CHOSEN_PATH`. An unknown slot pushes an error and
## changes nothing.
static func set_icon(slot: String, path: String) -> void:
  if not DEFAULTS.has(slot):
    push_error('IconSlots: unknown slot "%s"' % slot)
    return
  _load_chosen()
  _chosen[slot] = path
  _save_chosen()


## Drops the in-memory choices and the load flag, so the next read re-reads `CHOSEN_PATH`.
## `CHOSEN_PATH` itself is untouched.
static func reset() -> void:
  _chosen = {}
  _built = false


## Reads `CHOSEN_PATH` into `_chosen` the first time a slot is asked for — the same lazy build
## `MechanicRegistry._build` uses. A missing file is not an error; `_chosen` stays empty.
static func _load_chosen() -> void:
  if _built:
    return
  _built = true
  if not FileAccess.file_exists(CHOSEN_PATH):
    return
  var file: ConfigFile = ConfigFile.new()
  if file.load(CHOSEN_PATH) != OK:
    return
  if not file.has_section('icons'):
    return   # get_section_keys pushes an error for a section that is not there
  for slot: String in file.get_section_keys('icons'):
    _chosen[slot] = file.get_value('icons', slot)


## Saves the whole `_chosen` dictionary back to `CHOSEN_PATH` under the `icons` section.
static func _save_chosen() -> void:
  var file: ConfigFile = ConfigFile.new()
  file.clear()
  for slot: String in _chosen:
    file.set_value('icons', slot, _chosen[slot])
  file.save(CHOSEN_PATH)
