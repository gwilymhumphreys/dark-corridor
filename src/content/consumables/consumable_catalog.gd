class_name ConsumableCatalog
## The potion definitions (decision #23), keyed by string id: one file each under
## content/consumables/. Built on first access.

const FOLDER := 'res://content/consumables'

static var _defs: Dictionary = {}


static func get_def(id: String) -> ConsumableDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('ConsumableCatalog: unknown consumable id "%s"' % id)
    return null   # caller guards (a misspelt id logs, never crashes)
  return _defs[id]


static func _build() -> void:
  _defs = ContentFolder.load_defs(FOLDER)
