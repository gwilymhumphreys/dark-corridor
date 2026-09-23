class_name RelicCatalog
## The relic definitions (decision #23), keyed by string id: one file each under content/relics/.
## Built on first access.

const FOLDER := 'res://content/relics'

# What a relic reward draws from (the run manager's grant). Stone Ward is a starting relic, not a
# reward. The owner curates this pool with the real relics.
const REWARD_POOL: Array = ['vital_charm', 'iron_idol']

static var _defs: Dictionary = {}


static func get_def(id: String) -> RelicDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('RelicCatalog: unknown relic id "%s"' % id)
    return null   # caller guards (a misspelt id logs, never crashes)
  return _defs[id]


static func _build() -> void:
  _defs = ContentFolder.load_defs(FOLDER)
