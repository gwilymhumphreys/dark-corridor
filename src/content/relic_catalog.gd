class_name RelicCatalog
## The relic definitions (decision #23 — authored in GDScript, keyed by Id). Phase 3
## pool: one combat-start relic (Stone Ward → start each fight with block). Lazily
## built once, like the item / enemy / status catalogs.

enum Id { STONE_WARD }

static var _defs: Dictionary = {}


static func get_def(id: int) -> RelicDef:
  if _defs.is_empty():
    _build()
  return _defs[id]


static func _build() -> void:
  _defs[Id.STONE_WARD] = _stone_ward()


static func _stone_ward() -> RelicDef:
  var d := RelicDef.new()
  d.id = Id.STONE_WARD
  d.name_key = 'Stone Ward'
  d.kind = RelicDef.Kind.COMBAT_START_STATUS
  d.status_type = StatusDef.Type.BLOCK
  d.status_count = Balance.RELIC_STONE_WARD_BLOCK
  d.panel_color = Color(0.4, 0.5, 0.6)
  return d
