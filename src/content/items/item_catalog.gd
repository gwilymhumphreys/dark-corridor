class_name ItemCatalog
## The item definitions (decision #23), keyed by string id. Each item is one file under
## content/items/ (docs/design/authoring.md); the subfolders group them by character and mean
## nothing to the catalog. A definition in no pool is authored but never drafted — pool membership
## is the switch (#27). Built on first access.

const FOLDER := 'res://content/items'

static var _defs: Dictionary = {}


static func get_def(id: String) -> ItemDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('ItemCatalog: unknown item id "%s"' % id)
    return null   # caller guards (a misspelt id logs, never crashes)
  return _defs[id]


## Every authored id, for content checks and tools that list the whole catalog.
static func all_ids() -> Array[String]:
  if _defs.is_empty():
    _build()
  var ids: Array[String] = []
  for id: String in _defs:
    ids.append(id)
  return ids


static func _build() -> void:
  _defs = ContentFolder.load_defs(FOLDER)
