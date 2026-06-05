class_name EnchantCatalog
## The enchantment definitions (decision #23 — authored in GDScript, keyed by Id).
## Phase 3 pool: one scale-a-value enchant (Whetstone → +50% to the host item's
## payload values). Lazily built once, like the other catalogs.

enum Id { WHETSTONE }

static var _defs: Dictionary = {}


static func get_def(id: int) -> EnchantDef:
  if _defs.is_empty():
    _build()
  return _defs[id]


static func _build() -> void:
  _defs[Id.WHETSTONE] = _whetstone()


static func _whetstone() -> EnchantDef:
  var d := EnchantDef.new()
  d.id = Id.WHETSTONE
  d.name_key = 'Whetstone'
  d.value_mult = Balance.ENCHANT_WHETSTONE_MULT
  return d
