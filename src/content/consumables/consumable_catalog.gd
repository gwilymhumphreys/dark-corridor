class_name ConsumableCatalog
## The consumable definitions (decision #23 — GDScript, keyed by Id). Phase 3 pool:
## one heal potion (Healing Draught → heal the thrower; a travel-0 self-target
## effect). Lazily built once.

const HEALING_DRAUGHT := 'healing_draught'

static var _defs: Dictionary = {}


static func get_def(id: String) -> ConsumableDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('ConsumableCatalog: unknown consumable id "%s"' % id)
  return _defs[id]


## Copy the colours of freshly built definitions onto the cached ones, so potions that already hold
## a definition show the current `Colours` (docs/systems/interface_palette.md).
static func refresh_colours() -> void:
  if _defs.is_empty():
    return
  var cached: Dictionary = _defs
  _defs = {}
  _build()
  for id: String in cached:
    var old_def: ConsumableDef = cached[id]
    var new_def: ConsumableDef = _defs[id]
    for i in old_def.effects.size():
      (old_def.effects[i] as ItemEffect).color = (new_def.effects[i] as ItemEffect).color
  _defs = cached


static func _build() -> void:
  _defs[HEALING_DRAUGHT] = _healing_draught()


static func _healing_draught() -> ConsumableDef:
  var d := ConsumableDef.new()
  d.id = HEALING_DRAUGHT
  d.name_key = 'Healing Draught'
  d.icon = 'res://assets/icons/potions/alchemy_31_bigheal_flask.png'
  var heal := ItemEffect.new()
  heal.mechanic = HealMechanic.ID
  heal.value = Balance.POTION_HEAL
  heal.shape = ItemEffect.Shape.SELF
  heal.travel = 0.0
  d.effects = [heal]
  return d
