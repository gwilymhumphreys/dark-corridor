class_name EnemyCatalog
## The enemy definitions (decision #23), keyed by string id: one file each under content/enemies/.
## Allies and summons are enemy definitions too. Built on first access.

const FOLDER := 'res://content/enemies'

static var _defs: Dictionary = {}


static func get_def(id: String) -> EnemyDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('EnemyCatalog: unknown enemy id "%s"' % id)
    return null   # caller guards (a misspelt id logs, never crashes)
  return _defs[id]


## Whether the id resolves, for a caller checking authored or command-line input without tripping
## get_def's error on a misspelt id.
static func has(id: String) -> bool:
  if _defs.is_empty():
    _build()
  return _defs.has(id)


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
