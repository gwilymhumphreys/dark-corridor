class_name ItemCatalog
## The item definitions (decision #23 — authored in GDScript, keyed by Id).
## Phase 1 pool: a weapon (single-target damage, travels), an armor (self block),
## a poison dagger (applies poison), an avenger (ticks self-block AND triggers on
## poison-applied), plus an enemy claw (the enemy pool stays separate by design —
## one catalog here for Phase 1). HEX_BOLT is the example item-targeting item (silences
## a RANDOM enemy item; #14/#20) — catalog-only, not pooled by default. Lazily built once.

const WEAPON := 'weapon'
const ARMOR := 'armor'
const POISON_DAGGER := 'poison_dagger'
const AVENGER := 'avenger'
const ENEMY_CLAW := 'enemy_claw'
const HEX_BOLT := 'hex_bolt'
const SUNDER := 'sunder'
const POCKET_SHROOMS := 'pocket_shrooms'
const DRUID_STAFF := 'druid_staff'
const SPORE_SPITTER := 'spore_spitter'
const CAPPED_CUDGEL := 'capped_cudgel'
const BLOOMHAMMER := 'bloomhammer'
const WILT_FROND := 'wilt_frond'
const LEATHER_GLOVES := 'leather_gloves'
const LEATHER_TREWS := 'leather_trews'
const LEATHER_BREASTPLATE := 'leather_breastplate'

static var _defs: Dictionary = {}


static func get_def(id: String) -> ItemDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('ItemCatalog: unknown item id "%s"' % id)
  return _defs[id]


static func _build() -> void:
  _defs[WEAPON] = _weapon()
  _defs[ARMOR] = _armor()
  _defs[POISON_DAGGER] = _poison_dagger()
  _defs[AVENGER] = _avenger()
  _defs[ENEMY_CLAW] = _enemy_claw()
  _defs[HEX_BOLT] = _hex_bolt()
  _defs[SUNDER] = _sunder()
  _defs[POCKET_SHROOMS] = _pocket_shrooms()
  _defs[DRUID_STAFF] = _druid_staff()
  _defs[SPORE_SPITTER] = _spore_spitter()
  _defs[CAPPED_CUDGEL] = _capped_cudgel()
  _defs[BLOOMHAMMER] = _bloomhammer()
  _defs[WILT_FROND] = _wilt_frond()
  _defs[LEATHER_GLOVES] = _leather_gloves()
  _defs[LEATHER_TREWS] = _leather_trews()
  _defs[LEATHER_BREASTPLATE] = _leather_breastplate()


static func _weapon() -> ItemDef:
  var d := ItemDef.new()
  d.id = WEAPON
  d.name_key = 'Rusted Blade'
  d.cooldown = Balance.WEAPON_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.WEAPON_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.DAMAGE
  d.effects = [hit]
  d.panel_color = hit.color
  return d


static func _armor() -> ItemDef:
  var d := ItemDef.new()
  d.id = ARMOR
  d.name_key = 'Iron Guard'
  d.cooldown = Balance.ARMOR_COOLDOWN
  var blk := ItemEffect.new()
  blk.kind = Delivery.Kind.APPLY_STATUS
  blk.status_id = 'block'
  blk.value = Balance.ARMOR_BLOCK
  blk.shape = ItemEffect.Shape.SELF
  blk.color = Colours.STATUS_BLOCK
  d.effects = [blk]
  d.panel_color = blk.color
  return d


static func _poison_dagger() -> ItemDef:
  var d := ItemDef.new()
  d.id = POISON_DAGGER
  d.name_key = 'Venom Fang'
  d.cooldown = Balance.POISON_APPLIER_COOLDOWN
  var pois := ItemEffect.new()
  pois.kind = Delivery.Kind.APPLY_STATUS
  pois.status_id = 'poison'
  pois.value = Balance.POISON_APPLIER_STACKS
  pois.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  pois.travel = Balance.WEAPON_TRAVEL
  pois.color = Colours.STATUS_POISON
  d.effects = [pois]
  d.panel_color = pois.color
  return d


static func _avenger() -> ItemDef:
  var d := ItemDef.new()
  d.id = AVENGER
  d.name_key = 'Spite Ward'
  d.cooldown = Balance.ARMOR_COOLDOWN
  var blk := ItemEffect.new()
  blk.kind = Delivery.Kind.APPLY_STATUS
  blk.status_id = 'block'
  blk.value = Balance.ARMOR_BLOCK
  blk.shape = ItemEffect.Shape.SELF
  blk.color = Colours.STATUS_BLOCK
  d.effects = [blk]
  # ticks normally AND pushes its cooldown when poison is applied (charges model)
  d.trigger_subs = [{
    'event': EventBus.Event.STATUS_APPLIED,
    'amount': Balance.TRIGGER_PUSH_FULL,
    'filter': 'poison',
  }]
  d.panel_color = blk.color
  return d


## The example item-targeting item (#14/#20): a bolt that applies SILENCE to a RANDOM
## enemy item, chosen on the seeded per-fight RNG. Demonstrates OPPONENT_ITEM_RANDOM end
## to end. Not in DraftPool by default — the owner can pool it once enemies carry several
## items (against the single-item grunt a silence is a guaranteed disable).
static func _hex_bolt() -> ItemDef:
  var d := ItemDef.new()
  d.id = HEX_BOLT
  d.name_key = 'Hex Bolt'
  d.cooldown = Balance.HEX_BOLT_COOLDOWN
  var hex := ItemEffect.new()
  hex.kind = Delivery.Kind.APPLY_STATUS
  hex.status_id = 'silence'
  hex.value = 1.0
  hex.shape = ItemEffect.Shape.OPPONENT_ITEM_RANDOM
  hex.travel = Balance.WEAPON_TRAVEL
  hex.color = Colours.ARCANE
  d.effects = [hex]
  d.panel_color = hex.color
  return d


## The example stat-status applier (#6): a bolt that makes the leftmost enemy Vulnerable
## (its incoming damage amplified). Demonstrates the incoming damage seam end to end.
## Catalog-only, not pooled by default — the owner authors the real stat-status content.
static func _sunder() -> ItemDef:
  var d := ItemDef.new()
  d.id = SUNDER
  d.name_key = 'Sundering Bolt'
  d.cooldown = Balance.SUNDER_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.APPLY_STATUS
  hit.status_id = 'vulnerable'
  hit.duration = Balance.STATUS_VULNERABLE_DURATION
  hit.value = 1.0
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.STATUS_VULNERABLE
  d.effects = [hit]
  d.panel_color = hit.color
  return d


## Pocket Shrooms — the first authored Spore Druid card + the first multi-effect RARE: a
## single-target attack that deals damage AND applies the blinding spore. Blind is a timed
## evasion status, so the struck enemy's attacks WHIFF for its duration (its non-damage
## payloads still land). Rare for the ACCESS to blinding, not bigger numbers (rarity =
## complexity; design.md). Catalog-only for now — its home is the Spore Druid's item pool
## (#27), not yet authored, so it isn't drafted until that pool exists.
static func _pocket_shrooms() -> ItemDef:
  var d := ItemDef.new()
  d.id = POCKET_SHROOMS
  d.name_key = 'Pocket Shrooms'
  d.rarity = ItemDef.Rarity.RARE
  d.cooldown = Balance.POCKET_SHROOMS_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.POCKET_SHROOMS_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.DAMAGE
  var blind := ItemEffect.new()
  blind.kind = Delivery.Kind.APPLY_STATUS
  blind.status_id = 'blind'
  blind.duration = Balance.STATUS_BLIND_DURATION
  blind.value = Balance.POCKET_SHROOMS_BLIND_STACKS
  blind.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  blind.travel = Balance.WEAPON_TRAVEL
  blind.color = Colours.STATUS_BLIND         # applier shares the status colour
  d.effects = [hit, blind]
  d.panel_color = hit.color                  # primary payload is damage (single-panel model)
  return d


## Druid Staff — the Spore Druid's first Spores applier + its starting card: a single-target
## attack that deals damage AND stacks 1 Spore on the struck enemy. A COMMON applier (the
## appliers are commons; the Mass payoff lives a tier up — spore_druid.md). Single-target on
## purpose — Spores pile on ONE enemy, the shape a Mass payoff wants to consume. Lives in the
## Spore Druid's item pool (#27).
static func _druid_staff() -> ItemDef:
  var d := ItemDef.new()
  d.id = DRUID_STAFF
  d.name_key = 'Druid Staff'
  d.cooldown = Balance.DRUID_STAFF_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.DRUID_STAFF_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.DAMAGE
  var spore := ItemEffect.new()
  spore.kind = Delivery.Kind.APPLY_STATUS
  spore.status_id = 'spores'
  spore.value = Balance.DRUID_STAFF_SPORE_STACKS
  spore.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  spore.travel = Balance.WEAPON_TRAVEL
  spore.color = Colours.STATUS_SPORES        # applier shares the status colour
  d.effects = [hit, spore]
  d.panel_color = hit.color                  # primary payload is damage (single-panel model)
  return d


## Spore Spitter — the fast pole of the Spore Druid weapon spread (spore_druid.md): a quick
## single-target jab that deals low damage AND stacks 1 Spore. Its 1s cooldown makes it the
## kit's fastest Spore-fuel engine (~1 Spore/sec) — it pays the heaviest DPS tax for that
## rate. COMMON applier. Single-target so Spores pile on one enemy (the Mass shape).
static func _spore_spitter() -> ItemDef:
  var d := ItemDef.new()
  d.id = SPORE_SPITTER
  d.name_key = 'Spore Spitter'         # PLACEHOLDER name — owner's to rename
  d.cooldown = Balance.SPORE_SPITTER_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.SPORE_SPITTER_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.DAMAGE
  var spore := ItemEffect.new()
  spore.kind = Delivery.Kind.APPLY_STATUS
  spore.status_id = 'spores'
  spore.value = Balance.SPORE_SPITTER_SPORE_STACKS
  spore.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  spore.travel = Balance.WEAPON_TRAVEL
  spore.color = Colours.STATUS_SPORES        # applier shares the status colour
  d.effects = [hit, spore]
  d.panel_color = hit.color                  # primary payload is damage (single-panel model)
  return d


## Capped Cudgel — the middle pole: a clean tempo weapon that deals medium damage and NO
## Spore (spore_druid.md). Earns full baseline DPS precisely because it gives no fuel — the
## pure-damage draft option against the spore-carriers' tax. COMMON.
static func _capped_cudgel() -> ItemDef:
  var d := ItemDef.new()
  d.id = CAPPED_CUDGEL
  d.name_key = 'Capped Cudgel'         # PLACEHOLDER name — owner's to rename
  d.cooldown = Balance.CAPPED_CUDGEL_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.CAPPED_CUDGEL_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.DAMAGE
  d.effects = [hit]
  d.panel_color = hit.color
  return d


## Bloomhammer — the slow pole: a heavy single-target hit that deals high damage AND dumps 2
## Spores in one strike (spore_druid.md). Slow Spore-accrual rate but a sudden fuel spike — the
## weapon a Mass payoff wants when it needs a burst of fuel at once. COMMON applier.
static func _bloomhammer() -> ItemDef:
  var d := ItemDef.new()
  d.id = BLOOMHAMMER
  d.name_key = 'Bloomhammer'           # PLACEHOLDER name — owner's to rename
  d.cooldown = Balance.BLOOMHAMMER_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.BLOOMHAMMER_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.DAMAGE
  var spore := ItemEffect.new()
  spore.kind = Delivery.Kind.APPLY_STATUS
  spore.status_id = 'spores'
  spore.value = Balance.BLOOMHAMMER_SPORE_STACKS
  spore.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  spore.travel = Balance.WEAPON_TRAVEL
  spore.color = Colours.STATUS_SPORES        # applier shares the status colour
  d.effects = [hit, spore]
  d.panel_color = hit.color                  # primary payload is damage (single-panel model)
  return d


## Wilt Frond (PLACEHOLDER name — owner's to rename) — a Weak-applier attack: deals damage AND
## applies Weak (the reused baseline debuff, #28; the holder deals less damage for 2s). Damage
## sits 2 DPS under the curve to pay for the Weakness rider (item_heuristics.md). Weak isn't
## Mass fuel (timed, not stacked) — it feeds distinct-status variety (the Spread mechanism), so
## archetype x. COMMON.
static func _wilt_frond() -> ItemDef:
  var d := ItemDef.new()
  d.id = WILT_FROND
  d.name_key = 'Wilt Frond'             # PLACEHOLDER name — owner's to rename
  d.cooldown = Balance.WILT_FROND_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.WILT_FROND_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.DAMAGE
  var weak := ItemEffect.new()
  weak.kind = Delivery.Kind.APPLY_STATUS
  weak.status_id = 'weak'
  weak.duration = Balance.STATUS_WEAK_DURATION
  weak.value = Balance.WILT_FROND_WEAK_STACKS
  weak.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  weak.travel = Balance.WEAPON_TRAVEL
  weak.color = Colours.STATUS_WEAK           # applier shares the status colour
  d.effects = [hit, weak]
  d.panel_color = hit.color                  # primary payload is damage (single-panel model)
  return d


## Leather block spread — three plain self-block items on a cooldown curve (Gloves fast/taxed,
## Trews baseline, Breastplate slow/rewarded), mirroring the weapon DPS tax. No Spore consume yet
## (the consume source is an open design question — Spores land on enemies, not the wearer). COMMON.
static func _leather_gloves() -> ItemDef:
  var d := ItemDef.new()
  d.id = LEATHER_GLOVES
  d.name_key = 'Leather Gloves'
  d.cooldown = Balance.LEATHER_GLOVES_COOLDOWN
  var blk := ItemEffect.new()
  blk.kind = Delivery.Kind.APPLY_STATUS
  blk.status_id = 'block'
  blk.value = Balance.LEATHER_GLOVES_BLOCK
  blk.shape = ItemEffect.Shape.SELF
  blk.color = Colours.STATUS_BLOCK
  d.effects = [blk]
  d.panel_color = blk.color
  return d


static func _leather_trews() -> ItemDef:
  var d := ItemDef.new()
  d.id = LEATHER_TREWS
  d.name_key = 'Leather Trews'
  d.cooldown = Balance.LEATHER_TREWS_COOLDOWN
  var blk := ItemEffect.new()
  blk.kind = Delivery.Kind.APPLY_STATUS
  blk.status_id = 'block'
  blk.value = Balance.LEATHER_TREWS_BLOCK
  blk.shape = ItemEffect.Shape.SELF
  blk.color = Colours.STATUS_BLOCK
  d.effects = [blk]
  d.panel_color = blk.color
  return d


static func _leather_breastplate() -> ItemDef:
  var d := ItemDef.new()
  d.id = LEATHER_BREASTPLATE
  d.name_key = 'Leather Breastplate'
  d.cooldown = Balance.LEATHER_BREASTPLATE_COOLDOWN
  var blk := ItemEffect.new()
  blk.kind = Delivery.Kind.APPLY_STATUS
  blk.status_id = 'block'
  blk.value = Balance.LEATHER_BREASTPLATE_BLOCK
  blk.shape = ItemEffect.Shape.SELF
  blk.color = Colours.STATUS_BLOCK
  d.effects = [blk]
  d.panel_color = blk.color
  return d


static func _enemy_claw() -> ItemDef:
  var d := ItemDef.new()
  d.id = ENEMY_CLAW
  d.name_key = 'Claw'
  d.cooldown = Balance.WEAPON_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.WEAPON_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.ENEMY_CLAW
  d.effects = [hit]
  d.panel_color = hit.color
  return d
