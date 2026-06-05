class_name ConsumableCatalog
## The consumable definitions (decision #23 — GDScript, keyed by Id). Phase 3 pool:
## one heal potion (Healing Draught → heal the thrower; a travel-0 self-target
## effect). Lazily built once.

enum Id { HEALING_DRAUGHT }

static var _defs: Dictionary = {}


static func get_def(id: int) -> ConsumableDef:
  if _defs.is_empty():
    _build()
  return _defs[id]


static func _build() -> void:
  _defs[Id.HEALING_DRAUGHT] = _healing_draught()


static func _healing_draught() -> ConsumableDef:
  var d := ConsumableDef.new()
  d.id = Id.HEALING_DRAUGHT
  d.name_key = 'Healing Draught'
  var heal := ItemEffect.new()
  heal.kind = Delivery.Kind.HEAL
  heal.value = Balance.POTION_HEAL
  heal.shape = ItemEffect.Shape.SELF
  heal.travel = 0.0
  heal.color = Color(0.3, 0.9, 0.4)
  d.effects = [heal]
  return d
