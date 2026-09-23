class_name CharacterCatalog
## The character definitions (#23), keyed by string id: one file each under content/characters/.
## Each character has its own item pool (#27). Built on first access.

const FOLDER := 'res://content/characters'

## The character a run opens on when none is chosen: the title-screen autostart, the save-resume
## fallback, and the autotest's baseline. The Smith holds it because it is the character being
## balanced first (owner, 2026-09-21); the other two are not yet on the points curve.
const DEFAULT := 'smith'

static var _defs: Dictionary = {}


static func get_def(id: String) -> CharacterDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('CharacterCatalog: unknown character id "%s"' % id)
    return null
  return _defs[id]


## True if `id` is an AUTHORED character (rostered or not — the autotest's --character validates
## here so it can drive a not-yet-listed character for tuning). Lazily builds, like the catalogs.
static func has(id: String) -> bool:
  if _defs.is_empty():
    _build()
  return _defs.has(id)


## The roster ids in display order — the character-select screen enumerates this. The
## characters' numbers and names are still placeholders to /tune and rename. The Smith leads
## (owner, 2026-09-23), as the character being balanced first.
static func ids() -> Array:
  if _defs.is_empty():
    _build()
  return ['smith', 'fleshmancer', 'spore_druid']


## The run-start board for a character: its fixed `starting_item_ids`, or — when it lists
## `starting_item_types` — one random item of each type, drawn from its own pool on `rng`. Each
## slot draws a DISTINCT item, so a repeated type asks for two different items of it. A type with
## nothing left in the pool is skipped with a warning rather than crashing, which keeps a
## half-authored character startable. Both the run and the autotest sandbox build boards through
## here, so there is one definition of what a character opens with.
static func starting_board(def: CharacterDef, rng: RandomNumberGenerator) -> Array:
  if def.starting_item_types.is_empty():
    return def.starting_item_ids.duplicate()
  var ids: Array = []
  for type: String in def.starting_item_types:
    var candidates: Array = []
    for item_id: String in def.item_pool:
      var item_def: ItemDef = ItemCatalog.get_def(item_id)
      if item_def != null and item_def.types.has(type) and not ids.has(item_id):
        candidates.append(item_id)
    if candidates.is_empty():
      push_warning('CharacterCatalog: %s has no unused "%s" item for its starting board' % [def.id, type])
      continue
    ids.append(candidates[rng.randi_range(0, candidates.size() - 1)])
  return ids


static func _build() -> void:
  _defs = ContentFolder.load_defs(FOLDER)
