class_name EncounterCatalog
## The encounter definitions (decision #23), keyed by string id: one file each under
## content/encounters/. Fights, rests and events; the run map names which ones it uses. Built on
## first access.

const FOLDER := 'res://content/encounters'

static var _defs: Dictionary = {}


static func get_def(id: String) -> EncounterDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('EncounterCatalog: unknown encounter id "%s"' % id)
    return null   # caller guards (a misspelt id logs, never crashes)
  return _defs[id]


static func _build() -> void:
  _defs = ContentFolder.load_defs(FOLDER)
