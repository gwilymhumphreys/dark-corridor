class_name ItemCatalog
## The item definitions (decision #23 — authored in GDScript, keyed by Id).
## Phase 1 pool: a weapon (single-target damage, travels), an armor (self block),
## a poison dagger (applies poison), an avenger (ticks self-block AND triggers on
## poison-applied), plus an enemy claw (the enemy pool stays separate by design —
## one catalog here for Phase 1). HEX_BOLT is the example item-targeting item (silences
## a RANDOM enemy item; #14/#20) — catalog-only, not pooled by default. Lazily built once.

enum Id { WEAPON, ARMOR, POISON_DAGGER, AVENGER, ENEMY_CLAW, HEX_BOLT, SUNDER }

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
  _defs[Id.HEX_BOLT] = _hex_bolt()
  _defs[Id.SUNDER] = _sunder()


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


## The example item-targeting item (#14/#20): a bolt that applies SILENCE to a RANDOM
## enemy item, chosen on the seeded per-fight RNG. Demonstrates OPPONENT_ITEM_RANDOM end
## to end. Not in DraftPool by default — the owner can pool it once enemies carry several
## items (against the single-item grunt a silence is a guaranteed disable).
static func _hex_bolt() -> ItemDef:
  var d := ItemDef.new()
  d.id = Id.HEX_BOLT
  d.name_key = 'Hex Bolt'
  d.cooldown = Balance.HEX_BOLT_COOLDOWN
  var hex := ItemEffect.new()
  hex.kind = Delivery.Kind.APPLY_STATUS
  hex.status_type = StatusDef.Type.SILENCE
  hex.value = 1.0
  hex.shape = ItemEffect.Shape.OPPONENT_ITEM_RANDOM
  hex.travel = Balance.WEAPON_TRAVEL
  hex.color = Color(0.5, 0.2, 0.7)
  d.effects = [hex]
  d.panel_color = hex.color
  return d


## The example stat-status applier (#6): a bolt that makes the leftmost enemy Vulnerable
## (its incoming damage amplified). Demonstrates the incoming damage seam end to end.
## Catalog-only, not pooled by default — the owner authors the real stat-status content.
static func _sunder() -> ItemDef:
  var d := ItemDef.new()
  d.id = Id.SUNDER
  d.name_key = 'Sundering Bolt'
  d.cooldown = Balance.SUNDER_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.APPLY_STATUS
  hit.status_type = StatusDef.Type.VULNERABLE
  hit.value = 1.0
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Color(0.85, 0.5, 0.2)
  d.effects = [hit]
  d.panel_color = hit.color
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
