class_name ItemCatalog
## The item definitions (decision #23 — authored in GDScript, keyed by Id).
## Phase 1 pool: a weapon (single-target damage, travels), an armor (self block),
## a poison dagger (applies poison), an avenger (ticks self-block AND triggers on
## poison-applied), plus an enemy claw (the enemy pool stays separate by design —
## one catalog here for Phase 1). Lazily built once.

enum Id { WEAPON, ARMOR, POISON_DAGGER, AVENGER, ENEMY_CLAW }

static var _defs: Dictionary = {}


static func get_def(id: int) -> ItemDef:
  if _defs.is_empty():
    _build()
  return _defs[id]


static func _build() -> void:
  _defs[Id.WEAPON] = _weapon()
  _defs[Id.ARMOR] = _armor()
  _defs[Id.POISON_DAGGER] = _poison_dagger()
  _defs[Id.AVENGER] = _avenger()
  _defs[Id.ENEMY_CLAW] = _enemy_claw()


static func _weapon() -> ItemDef:
  var d := ItemDef.new()
  d.id = Id.WEAPON
  d.name_key = 'Rusted Blade'
  d.cooldown = Balance.WEAPON_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.WEAPON_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Color(0.9, 0.2, 0.2)
  d.effects = [hit]
  d.panel_color = hit.color
  return d


static func _armor() -> ItemDef:
  var d := ItemDef.new()
  d.id = Id.ARMOR
  d.name_key = 'Iron Guard'
  d.cooldown = Balance.ARMOR_COOLDOWN
  var blk := ItemEffect.new()
  blk.kind = Delivery.Kind.APPLY_STATUS
  blk.status_type = StatusDef.Type.BLOCK
  blk.value = Balance.ARMOR_BLOCK
  blk.shape = ItemEffect.Shape.SELF
  blk.color = Color(0.3, 0.6, 1.0)
  d.effects = [blk]
  d.panel_color = blk.color
  return d


static func _poison_dagger() -> ItemDef:
  var d := ItemDef.new()
  d.id = Id.POISON_DAGGER
  d.name_key = 'Venom Fang'
  d.cooldown = Balance.POISON_APPLIER_COOLDOWN
  var pois := ItemEffect.new()
  pois.kind = Delivery.Kind.APPLY_STATUS
  pois.status_type = StatusDef.Type.POISON
  pois.value = Balance.POISON_APPLIER_STACKS
  pois.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  pois.travel = Balance.WEAPON_TRAVEL
  pois.color = Color(0.4, 0.8, 0.2)
  d.effects = [pois]
  d.panel_color = pois.color
  return d


static func _avenger() -> ItemDef:
  var d := ItemDef.new()
  d.id = Id.AVENGER
  d.name_key = 'Spite Ward'
  d.cooldown = Balance.ARMOR_COOLDOWN
  var blk := ItemEffect.new()
  blk.kind = Delivery.Kind.APPLY_STATUS
  blk.status_type = StatusDef.Type.BLOCK
  blk.value = Balance.ARMOR_BLOCK
  blk.shape = ItemEffect.Shape.SELF
  blk.color = Color(0.3, 0.6, 1.0)
  d.effects = [blk]
  # ticks normally AND pushes its cooldown when poison is applied (charges model)
  d.trigger_subs = [{
    'event': EventBus.Event.STATUS_APPLIED,
    'amount': Balance.TRIGGER_PUSH_FULL,
    'filter': StatusDef.Type.POISON,
  }]
  d.panel_color = blk.color
  return d


static func _enemy_claw() -> ItemDef:
  var d := ItemDef.new()
  d.id = Id.ENEMY_CLAW
  d.name_key = 'Claw'
  d.cooldown = Balance.WEAPON_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.WEAPON_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Color(0.8, 0.4, 0.1)
  d.effects = [hit]
  d.panel_color = hit.color
  return d
