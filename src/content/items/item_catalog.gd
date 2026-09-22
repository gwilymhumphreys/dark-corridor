class_name ItemCatalog
## The item definitions (decision #23 — authored in GDScript, keyed by Id). Lazily built once.
## Every character's cards live here (the Spore Druid's, the Fleshmancer's, the Smith's), plus
## the enemy claw (enemy boards only) and a few unpooled items kept as the working examples of a
## seam: POISON_DAGGER applies poison, AVENGER triggers on it, HEX_BOLT targets an enemy ITEM
## (#14/#20) and SUNDER applies Vulnerable (#6).
## A def in no character pool is authored but never drafted — pool membership is the toggle (#27).

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
const FLESH_CHUNK := 'flesh_chunk'
const FLESH_CARVING_KNIFE := 'flesh_carving_knife'
const FLESH_CLEAVER := 'flesh_cleaver'
const FLESH_BONE_SAW := 'flesh_bone_maul'
const FLESH_EXPLOSION := 'flesh_explosion'
const FLESH_FLENSING_HOOK := 'flesh_flensing_hook'
const FLESH_SKIN_GRAFT := 'flesh_skin_graft'
const FLESH_BONE_SPEAR := 'flesh_bone_spear'
const FLESH_RIB := 'flesh_rib'
const FLESH_FEMUR := 'flesh_femur'
const FLESH_SKULL := 'flesh_skull'
const MIGHTY_BLOW := 'mighty_blow'
const SMITH_BROADAXE := 'smith_broadaxe'
const SMITH_WARHAMMER := 'smith_warhammer'
const SMITH_GREATSWORD := 'smith_greatsword'
const SMITH_VAMBRACES := 'smith_vambraces'
const SMITH_SALLET := 'smith_sallet'
const SMITH_KITE_SHIELD := 'smith_kite_shield'
const SMITH_BREAST_PLATE := 'smith_breast_plate'

static var _defs: Dictionary = {}


static func get_def(id: String) -> ItemDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('ItemCatalog: unknown item id "%s"' % id)
    return null   # caller guards (a typo'd id no-ops + logs, never crashes)
  return _defs[id]


## Every authored item id. For the content sweeps in tests, which must cover the whole catalog
## rather than a hand-kept list that a new item would silently fall off.
static func all_ids() -> Array[String]:
  if _defs.is_empty():
    _build()
  var ids: Array[String] = []
  for id: String in _defs:
    ids.append(id)
  return ids


## Copy the colours of freshly built definitions onto the cached ones, so items and draft offers
## that already hold a definition show the current `Colours` (docs/systems/interface_palette.md).
static func refresh_colours() -> void:
  if _defs.is_empty():
    return
  var cached: Dictionary = _defs
  _defs = {}
  _build()
  for id: String in cached:
    if not _defs.has(id):
      continue   # added from outside the catalog (a test fixture)
    var old_def: ItemDef = cached[id]
    var new_def: ItemDef = _defs[id]
    old_def.panel_color = new_def.panel_color
    for i in old_def.effects.size():
      (old_def.effects[i] as ItemEffect).color = (new_def.effects[i] as ItemEffect).color
  _defs = cached


static func _build() -> void:
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
  _defs[FLESH_CHUNK] = _flesh_chunk()
  _defs[FLESH_CARVING_KNIFE] = _flesh_carving_knife()
  _defs[FLESH_CLEAVER] = _flesh_cleaver()
  _defs[FLESH_BONE_SAW] = _flesh_bone_saw()
  _defs[FLESH_EXPLOSION] = _flesh_explosion()
  _defs[FLESH_FLENSING_HOOK] = _flesh_flensing_hook()
  _defs[FLESH_SKIN_GRAFT] = _flesh_skin_graft()
  _defs[FLESH_BONE_SPEAR] = _flesh_bone_spear()
  _defs[FLESH_RIB] = _flesh_rib()
  _defs[FLESH_FEMUR] = _flesh_femur()
  _defs[FLESH_SKULL] = _flesh_skull()
  _defs[MIGHTY_BLOW] = _mighty_blow()
  _defs[SMITH_BROADAXE] = _smith_broadaxe()
  _defs[SMITH_WARHAMMER] = _smith_warhammer()
  _defs[SMITH_GREATSWORD] = _smith_greatsword()
  _defs[SMITH_VAMBRACES] = _smith_vambraces()
  _defs[SMITH_SALLET] = _smith_sallet()
  _defs[SMITH_KITE_SHIELD] = _smith_kite_shield()
  _defs[SMITH_BREAST_PLATE] = _smith_breast_plate()


static func _poison_dagger() -> ItemDef:
  var d := ItemDef.new()
  d.id = POISON_DAGGER
  d.types = [ItemType.WEAPON]   # dagger vessel; applies poison rather than direct damage (owner: confirm)
  d.mechanics = [PoisonMechanic.ID]
  d.name_key = 'Venom Fang'
  d.icon = 'res://assets/icons/items/loot_26_spiderteeth.png'
  d.cooldown = Balance.POISON_APPLIER_COOLDOWN
  var pois := ItemEffect.new()
  pois.mechanic = PoisonMechanic.ID
  pois.value = Balance.POISON_APPLIER_STACKS
  pois.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  pois.travel = Balance.WEAPON_TRAVEL
  d.effects = [pois]
  d.panel_color = Colours.POISON
  return d


static func _avenger() -> ItemDef:
  var d := ItemDef.new()
  d.id = AVENGER
  d.types = [ItemType.ARMOUR]
  d.mechanics = [PoisonMechanic.ID, ShieldMechanic.ID]   # poison: charges off it (owner, 2026-09-20)
  d.name_key = 'Spite Ward'
  d.icon = 'res://assets/icons/items/skull_shield.png'
  d.cooldown = Balance.SPITE_WARD_COOLDOWN
  var blk := ItemEffect.new()
  blk.mechanic = ShieldMechanic.ID
  blk.value = Balance.SPITE_WARD_SHIELD
  blk.shape = ItemEffect.Shape.SELF
  d.effects = [blk]
  # ticks normally AND pushes its cooldown when poison is applied (charges model)
  d.trigger_subs = [{
    'event': EventBus.Event.APPLIED,
    'amount': Balance.TRIGGER_PUSH_FULL,
    'filter': 'poison',
  }]
  d.panel_color = Colours.SHIELD
  return d


## The example item-targeting item (#14/#20): a bolt that applies SILENCE to a RANDOM
## enemy item, chosen on the seeded per-fight RNG. Demonstrates OPPONENT_ITEM_RANDOM end
## to end. In no character pool — the owner can pool it once enemies carry several items
## (against the single-item grunt a silence is a guaranteed disable).
static func _hex_bolt() -> ItemDef:
  var d := ItemDef.new()
  d.id = HEX_BOLT
  d.types = [ItemType.SPELL]   # arcane hex/silence (owner: confirm spell vs skill)
  d.mechanics = []
  d.name_key = 'Hex Bolt'
  d.icon = 'res://assets/icons/items/skill_shadow_curse_nb.png'
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
  d.types = [ItemType.SKILL]   # martial debuff (Vulnerable) — owner: confirm skill vs spell vs weapon
  d.mechanics = []
  d.name_key = 'Sundering Bolt'
  d.icon = 'res://assets/icons/items/skill_break_medium_armor_nb.png'
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
  d.types = [ItemType.WEAPON]   # damage-primary attack (also blinds); thematically shrooms (owner: confirm)
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Pocket Shrooms'
  d.icon = 'res://assets/icons/items/herbalism_24_stinkymushroom.png'
  d.rarity = ItemDef.Rarity.RARE
  d.cooldown = Balance.POCKET_SHROOMS_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.POCKET_SHROOMS_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  var blind := ItemEffect.new()
  blind.kind = Delivery.Kind.APPLY_STATUS
  blind.status_id = 'blind'
  blind.duration = Balance.STATUS_BLIND_DURATION
  blind.value = Balance.POCKET_SHROOMS_BLIND_STACKS
  blind.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  blind.travel = Balance.WEAPON_TRAVEL
  blind.color = Colours.STATUS_BLIND         # applier shares the status colour
  d.effects = [hit, blind]
  d.panel_color = Colours.ATTACK             # primary payload is damage (single-panel model)
  return d


## Druid Staff — the Spore Druid's first Spores applier + its starting card: a single-target
## attack that deals damage AND stacks 1 Spore on the struck enemy. A COMMON applier (the
## appliers are commons; the Mass payoff lives a tier up — spore_druid.md). Single-target on
## purpose — Spores pile on ONE enemy, the shape a Mass payoff wants to consume. Lives in the
## Spore Druid's item pool (#27).
static func _druid_staff() -> ItemDef:
  var d := ItemDef.new()
  d.id = DRUID_STAFF
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Druid Staff'
  d.icon = 'res://assets/icons/items/staff_v2_02.png'
  d.cooldown = Balance.DRUID_STAFF_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.DRUID_STAFF_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  var spore := ItemEffect.new()
  spore.kind = Delivery.Kind.APPLY_STATUS
  spore.status_id = 'spores'
  spore.value = Balance.DRUID_STAFF_SPORE_STACKS
  spore.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  spore.travel = Balance.WEAPON_TRAVEL
  spore.color = Colours.STATUS_SPORES        # applier shares the status colour
  d.effects = [hit, spore]
  d.panel_color = Colours.ATTACK             # primary payload is damage (single-panel model)
  return d


## Spore Spitter — the fast pole of the Spore Druid weapon spread (spore_druid.md): a quick
## single-target jab that deals low damage AND stacks 1 Spore. Its 1s cooldown makes it the
## kit's fastest Spore-fuel engine (~1 Spore/sec) — it pays the heaviest DPS tax for that
## rate. COMMON applier. Single-target so Spores pile on one enemy (the Mass shape).
static func _spore_spitter() -> ItemDef:
  var d := ItemDef.new()
  d.id = SPORE_SPITTER
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Spore Spitter'         # PLACEHOLDER name — owner's to rename
  d.icon = 'res://assets/icons/items/herbalism_28_stinkymushroom.png'
  d.cooldown = Balance.SPORE_SPITTER_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.SPORE_SPITTER_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  var spore := ItemEffect.new()
  spore.kind = Delivery.Kind.APPLY_STATUS
  spore.status_id = 'spores'
  spore.value = Balance.SPORE_SPITTER_SPORE_STACKS
  spore.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  spore.travel = Balance.WEAPON_TRAVEL
  spore.color = Colours.STATUS_SPORES        # applier shares the status colour
  d.effects = [hit, spore]
  d.panel_color = Colours.ATTACK             # primary payload is damage (single-panel model)
  return d


## Capped Cudgel — the middle pole: a clean tempo weapon that deals medium damage and NO
## Spore (spore_druid.md). Earns full baseline DPS precisely because it gives no fuel — the
## pure-damage draft option against the spore-carriers' tax. COMMON.
static func _capped_cudgel() -> ItemDef:
  var d := ItemDef.new()
  d.id = CAPPED_CUDGEL
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Capped Cudgel'         # PLACEHOLDER name — owner's to rename
  d.icon = 'res://assets/icons/items/club_v2_02.png'
  d.cooldown = Balance.CAPPED_CUDGEL_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.CAPPED_CUDGEL_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  d.effects = [hit]
  d.panel_color = Colours.ATTACK
  return d


## Bloomhammer — the slow pole: a heavy single-target hit that deals high damage AND dumps 2
## Spores in one strike (spore_druid.md). Slow Spore-accrual rate but a sudden fuel spike — the
## weapon a Mass payoff wants when it needs a burst of fuel at once. COMMON applier.
static func _bloomhammer() -> ItemDef:
  var d := ItemDef.new()
  d.id = BLOOMHAMMER
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Bloomhammer'           # PLACEHOLDER name — owner's to rename
  d.icon = 'res://assets/icons/items/wooden_hammer.png'
  d.cooldown = Balance.BLOOMHAMMER_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.BLOOMHAMMER_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  var spore := ItemEffect.new()
  spore.kind = Delivery.Kind.APPLY_STATUS
  spore.status_id = 'spores'
  spore.value = Balance.BLOOMHAMMER_SPORE_STACKS
  spore.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  spore.travel = Balance.WEAPON_TRAVEL
  spore.color = Colours.STATUS_SPORES        # applier shares the status colour
  d.effects = [hit, spore]
  d.panel_color = Colours.ATTACK             # primary payload is damage (single-panel model)
  return d


## Wilt Frond (PLACEHOLDER name — owner's to rename) — a Weak-applier attack: deals damage AND
## applies Weak (the reused baseline debuff, #28; the holder deals less damage for 2s). Damage
## sits 2 DPS under the curve to pay for the Weakness rider (item_heuristics.md). Weak isn't
## Mass fuel (timed, not stacked) — it feeds distinct-status variety (the Spread mechanism), so
## archetype x. COMMON.
static func _wilt_frond() -> ItemDef:
  var d := ItemDef.new()
  d.id = WILT_FROND
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Wilt Frond'             # PLACEHOLDER name — owner's to rename
  d.icon = 'res://assets/icons/items/herbalism_20_sickflower.png'
  d.cooldown = Balance.WILT_FROND_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.WILT_FROND_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  var weak := ItemEffect.new()
  weak.kind = Delivery.Kind.APPLY_STATUS
  weak.status_id = 'weak'
  weak.duration = Balance.STATUS_WEAK_DURATION
  weak.value = Balance.WILT_FROND_WEAK_STACKS
  weak.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  weak.travel = Balance.WEAPON_TRAVEL
  weak.color = Colours.STATUS_WEAK           # applier shares the status colour
  d.effects = [hit, weak]
  d.panel_color = Colours.ATTACK             # primary payload is damage (single-panel model)
  return d


## Chunk of Flesh — the created token-item the Fleshmancer's attacks spawn on the player's OWN board
## (docs/systems/item_creation_and_decay.md). A weak auto-attacker: deals 1 damage every 2s and
## DECAYS after 2 activations (starting_uses → the Decay use-status) — "very low power, but does
## something" (owner). NOT drafted directly (it isn't in any item_pool); it only appears via a
## CREATE_ITEM rider. Numbers -> Balance (placeholders).
static func _flesh_chunk() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_CHUNK
  d.types = [ItemType.WEAPON]   # created token that auto-attacks for damage (owner: confirm)
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Chunk of Flesh'        # owner's term — rename if desired
  d.icon = 'res://assets/icons/items/res_149_meet.png'
  d.cooldown = Balance.FLESH_CHUNK_COOLDOWN
  d.starting_uses = Balance.FLESH_CHUNK_USES   # decays after this many fires (the Decay use-status seed)
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.FLESH_CHUNK_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  d.effects = [hit]
  d.panel_color = Colours.ATTACK
  return d


## Carving Knife — the FAST pole of the Fleshmancer attack
## spread (character_ideas.md → Flesh Golem / Meat): a quick jab that deals LOW damage AND creates a
## Chunk of Flesh on the player's OWN board (shape SELF → the firer). At the **3s chunk-creator
## minimum** — a chunk lives ~4s, so faster creation would stack chunks up too quickly. COMMON.
## (Producer = carving/butchery; consumers will be surgery/sewing — see character_ideas.md.)
static func _flesh_carving_knife() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_CARVING_KNIFE
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Carving Knife'
  d.icon = 'res://assets/icons/items/dagger_01.png'
  d.cooldown = Balance.FLESH_CARVING_KNIFE_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.FLESH_CARVING_KNIFE_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  var make := ItemEffect.new()
  make.kind = Delivery.Kind.CREATE_ITEM
  make.create_item_def_id = FLESH_CHUNK
  make.shape = ItemEffect.Shape.SELF         # the chunk lands on the firer's OWN board
  make.color = Colours.STATUS_DECAY          # the created chunk decays
  d.effects = [hit, make]
  d.panel_color = Colours.ATTACK             # primary payload is damage (single-panel model)
  return d


## Cleaver (PLACEHOLDER name — owner's to rename) — the MID pole + the Fleshmancer's starting card: a
## tempo attack that creates a Chunk of Flesh (shape SELF) and hits HARDER than the faster Carving Knife
## (6 vs 3 dmg) — slower chunk-rate, bigger hit, so neither pole dominates. COMMON.
static func _flesh_cleaver() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_CLEAVER
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Cleaver'               # PLACEHOLDER name — owner's to rename
  d.icon = 'res://assets/icons/items/dagger_38.png'
  d.cooldown = Balance.FLESH_CLEAVER_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.FLESH_CLEAVER_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  var make := ItemEffect.new()
  make.kind = Delivery.Kind.CREATE_ITEM
  make.create_item_def_id = FLESH_CHUNK
  make.shape = ItemEffect.Shape.SELF
  make.color = Colours.STATUS_DECAY
  d.effects = [hit, make]
  d.panel_color = Colours.ATTACK
  return d


## Bone Saw (PLACEHOLDER name — owner's to rename) — the SLOW pole: a heavy two-handed blow that
## deals LOW damage AND creates TWO Chunks of Flesh in one swing (two CREATE_ITEM effects, shape
## SELF). The bursty creator — ~2 chunks / 6s, same chunk-rate as the 3s Carving Knife but lumpier.
## COMMON.
static func _flesh_bone_saw() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_BONE_SAW
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Bone Saw'             # PLACEHOLDER name — owner's to rename
  d.icon = 'res://assets/icons/items/loot_12_saw.png'
  d.cooldown = Balance.FLESH_BONE_SAW_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.FLESH_BONE_SAW_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  var make := ItemEffect.new()
  make.kind = Delivery.Kind.CREATE_ITEM
  make.create_item_def_id = FLESH_CHUNK
  make.shape = ItemEffect.Shape.SELF
  make.color = Colours.STATUS_DECAY
  var make2 := ItemEffect.new()
  make2.kind = Delivery.Kind.CREATE_ITEM
  make2.create_item_def_id = FLESH_CHUNK
  make2.shape = ItemEffect.Shape.SELF
  make2.color = Colours.STATUS_DECAY
  d.effects = [hit, make, make2]
  d.panel_color = Colours.ATTACK
  return d


## Flesh Explosion (owner) — the Fleshmancer's first flesh CONSUMER payoff (Mode A: charge-on-destroy;
## character_ideas.md → Flesh Golem / Meat): an AOE nuke that CHARGES as your items die — every own
## item destroyed (a chunk decaying, or consumed) pushes its cooldown ~1s via the ITEM_DESTROYED
## trigger (docs/systems/item_creation_and_decay.md). 20s base, but the churn drops the effective
## cooldown far lower in a chunk-heavy build. AOE (all opponents). UNCOMMON (rarity = complexity: a
## trigger-driven payoff, not bigger numbers). Numbers -> Balance (estimates, tune in /tune).
static func _flesh_explosion() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_EXPLOSION
  d.types = [ItemType.SPELL]   # AOE detonation payoff, not a hand weapon (owner: confirm spell vs weapon)
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Flesh Explosion'       # owner's name
  d.icon = 'res://assets/icons/items/skill_blood_boiling_nb.png'
  d.rarity = ItemDef.Rarity.UNCOMMON
  d.cooldown = Balance.FLESH_EXPLOSION_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.FLESH_EXPLOSION_DAMAGE
  hit.shape = ItemEffect.Shape.ALL_OPPONENTS
  hit.travel = Balance.WEAPON_TRAVEL
  d.effects = [hit]
  # Charges as your OWN items die — each ITEM_DESTROYED pushes the cooldown ~1s (OWN_SIDE is the
  # wired default; no data filter = any own item, per "whenever one of your items is destroyed").
  d.trigger_subs = [{
    'event': EventBus.Event.ITEM_DESTROYED,
    'amount': Balance.FLESH_EXPLOSION_CHARGE_PER_DESTROY,
  }]
  d.panel_color = Colours.ATTACK
  return d


## Flensing Hook (PLACEHOLDER name — owner's to rename) — the self-harm PRODUCER (carving theme;
## character_ideas.md → Flesh Golem / Meat): deals UNBLOCKABLE damage to YOURSELF (shape SELF) and
## creates 2 Chunks of Flesh — the HP-spend identity made literal. Self-damage is UNBLOCKABLE so the
## player's own shield can't absorb the cost (a Fleshmancer runs shield to survive, so a blockable cost
## would silently no-op). No enemy damage — pure produce-by-bleeding. COMMON. Numbers -> Balance.
static func _flesh_flensing_hook() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_FLENSING_HOOK
  d.types = [ItemType.SKILL]   # active self-harm flesh producer, no enemy attack (owner: confirm)
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Flensing Hook'         # PLACEHOLDER name — owner's to rename
  d.icon = 'res://assets/icons/items/hook.png'
  d.cooldown = Balance.FLESH_FLENSING_HOOK_COOLDOWN
  var hurt := ItemEffect.new()
  hurt.mechanic = AttackMechanic.ID
  hurt.value = Balance.FLESH_FLENSING_HOOK_SELF_DAMAGE
  hurt.shape = ItemEffect.Shape.SELF          # the firer takes the hit — self-harm
  hurt.flags = Delivery.Flag.UNBLOCKABLE      # own shield must NOT absorb the cost (else the HP-spend no-ops)
  var make := ItemEffect.new()
  make.kind = Delivery.Kind.CREATE_ITEM
  make.create_item_def_id = FLESH_CHUNK
  make.shape = ItemEffect.Shape.SELF
  make.color = Colours.STATUS_DECAY
  var make2 := ItemEffect.new()
  make2.kind = Delivery.Kind.CREATE_ITEM
  make2.create_item_def_id = FLESH_CHUNK
  make2.shape = ItemEffect.Shape.SELF
  make2.color = Colours.STATUS_DECAY
  d.effects = [hurt, make, make2]
  d.panel_color = Colours.STATUS_DECAY        # identity is flesh production, not an attack (self-damage)
  return d


## Skin Graft (PLACEHOLDER name — owner's to rename) — a flesh CONSUMER (surgery/sewing theme): every
## fire, consume 1 Chunk of Flesh to heal yourself (graft the flesh back on). HEAL value comes entirely
## from the consumed chunk (value 0 + consume_item_scale per chunk), so no chunk = heals 0 and resets
## (the consume "reset" behaviour — no fuel-gate). Removes the chunk VIA remove_item, so it ALSO
## charges Flesh Explosion (the destroy synergy: heal + charge in one). COMMON. Numbers -> Balance
## (HEAL_PER_CHUNK is a flagged tuning watch — see balance.gd).
static func _flesh_skin_graft() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_SKIN_GRAFT
  d.types = [ItemType.SKILL]   # active self-heal / flesh consumer (no heal tag exists) (owner: confirm)
  d.mechanics = [HealMechanic.ID]
  d.name_key = 'Skin Graft'            # PLACEHOLDER name — owner's to rename
  d.icon = 'res://assets/icons/items/loot_99_needle.png'
  d.cooldown = Balance.FLESH_SKIN_GRAFT_COOLDOWN
  var heal := ItemEffect.new()
  heal.mechanic = HealMechanic.ID
  heal.value = 0.0                            # all healing comes from the consumed flesh
  heal.shape = ItemEffect.Shape.SELF
  heal.consume_item_def_id = FLESH_CHUNK      # eat a chunk off the OWN board
  heal.consume_item_amount = Balance.FLESH_SKIN_GRAFT_CONSUME
  heal.consume_item_scale = Balance.FLESH_SKIN_GRAFT_HEAL_PER_CHUNK  # heal per chunk consumed
  d.effects = [heal]
  d.panel_color = Colours.HEAL
  return d


## Bone Spear (owner) — the Fleshmancer's first BLEED applier (docs/design/mechanic_ideas.md -> Bleed;
## the carve-as-bleed-applier fusion in character_ideas.md). A slow attack that deals damage AND applies
## bleed to the struck enemy. Bleed is UNBLOCKABLE so the enemy's own shield can't soak the self-damage
## the wound bites for when it is hit by an attack. Single-target (the bleed piles on one enemy).
## COMMON. Numbers -> Balance (placeholders).
static func _flesh_bone_spear() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_BONE_SPEAR
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID, BleedMechanic.ID]
  d.name_key = 'Bone Spear'            # owner's name
  d.icon = 'res://assets/icons/items/spear_27.png'
  d.cooldown = Balance.FLESH_BONE_SPEAR_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.FLESH_BONE_SPEAR_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  var bleed := ItemEffect.new()
  bleed.mechanic = BleedMechanic.ID
  bleed.value = Balance.FLESH_BONE_SPEAR_BLEED
  bleed.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  bleed.travel = Balance.WEAPON_TRAVEL
  bleed.flags = Delivery.Flag.UNBLOCKABLE    # the enemy's own shield must not soak the wound
  d.effects = [hit, bleed]
  d.panel_color = Colours.ATTACK             # primary payload is damage (single-panel model)
  return d


## Bone shield spread (owner) — the Fleshmancer's self-shield FLOOR: plain self-shield on a cooldown curve
## (Rib fast/taxed · Femur baseline · Skull slow/rewarded), the bone twin of the Leather spread. Shield
## protects the HP-spend engine while you bleed yourself (character_ideas.md). COMMON. Numbers -> Balance.
static func _flesh_rib() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_RIB
  d.types = [ItemType.ARMOUR]
  d.mechanics = [ShieldMechanic.ID]
  d.name_key = 'Rib'                   # owner's name
  d.icon = 'res://assets/icons/items/loot_22_remains.png'
  d.cooldown = Balance.FLESH_RIB_COOLDOWN
  var blk := ItemEffect.new()
  blk.mechanic = ShieldMechanic.ID
  blk.value = Balance.FLESH_RIB_SHIELD
  blk.shape = ItemEffect.Shape.SELF
  d.effects = [blk]
  d.panel_color = Colours.SHIELD
  return d


static func _flesh_femur() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_FEMUR
  d.types = [ItemType.ARMOUR]
  d.mechanics = [ShieldMechanic.ID]
  d.name_key = 'Femur'                 # owner's name
  d.icon = 'res://assets/icons/items/loot_23_bone.png'
  d.cooldown = Balance.FLESH_FEMUR_COOLDOWN
  var blk := ItemEffect.new()
  blk.mechanic = ShieldMechanic.ID
  blk.value = Balance.FLESH_FEMUR_SHIELD
  blk.shape = ItemEffect.Shape.SELF
  d.effects = [blk]
  d.panel_color = Colours.SHIELD
  return d


static func _flesh_skull() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_SKULL
  d.types = [ItemType.ARMOUR]
  d.mechanics = [ShieldMechanic.ID]
  d.name_key = 'Skull'                 # owner's name
  d.icon = 'res://assets/icons/items/quest_24_scull.png'
  d.cooldown = Balance.FLESH_SKULL_COOLDOWN
  var blk := ItemEffect.new()
  blk.mechanic = ShieldMechanic.ID
  blk.value = Balance.FLESH_SKULL_SHIELD
  blk.shape = ItemEffect.Shape.SELF
  d.effects = [blk]
  d.panel_color = Colours.SHIELD
  return d


## Mighty Blow (PLACEHOLDER name — owner's to rename) — the Smith's empower SKILL (docs/design/
## smith.md → The empower engine): a plain-cooldown metronome that on each fire applies the
## 'empowered' status to SELF (banks one charge — it stacks). Each charge doubles the next WEAPON
## attack (EmpoweredStatus consumes one charge per weapon fire). In the Smith's item_pool. COMMON.
static func _mighty_blow() -> ItemDef:
  var d := ItemDef.new()
  d.id = MIGHTY_BLOW
  d.types = [ItemType.SKILL]
  d.mechanics = []
  d.name_key = 'Mighty Blow'           # PLACEHOLDER name — owner's to rename
  d.icon = 'res://assets/icons/items/skill_strong_attack_nb.png'
  d.cooldown = Balance.MIGHTY_BLOW_COOLDOWN
  var buff := ItemEffect.new()
  buff.kind = Delivery.Kind.APPLY_STATUS
  buff.status_id = 'empowered'
  buff.value = Balance.MIGHTY_BLOW_CHARGES   # banks one empower charge per fire (reapply stacks)
  buff.shape = ItemEffect.Shape.SELF         # the buff lands on the firer
  buff.color = Colours.STATUS_EMPOWERED
  d.effects = [buff]
  d.panel_color = buff.color
  return d


## Smith big slow weapons (PLACEHOLDER names — owner's to rename) — the empower-payoff ladder
## (docs/design/smith.md): three heavy single-target attacks on 5s/6s/7s cooldowns with similar DPS
## but a rising PER-HIT, so the slowest is the prime target for Mighty Blow's double. The Warhammer
## also decharges a random enemy item; the other two are plain. In the Smith's item_pool.
## COMMON. Numbers -> Balance (placeholders for /tune).
static func _smith_broadaxe() -> ItemDef:
  var d := ItemDef.new()
  d.id = SMITH_BROADAXE
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Broadaxe'              # PLACEHOLDER name — owner's to rename
  d.icon = 'res://assets/icons/items/axe_hard_2.png'
  d.cooldown = Balance.SMITH_BROADAXE_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.SMITH_BROADAXE_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  d.effects = [hit]
  d.panel_color = Colours.ATTACK
  return d


static func _smith_warhammer() -> ItemDef:
  var d := ItemDef.new()
  d.id = SMITH_WARHAMMER
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID, DechargeMechanic.ID]
  d.name_key = 'Warhammer'            # PLACEHOLDER name — owner's to rename
  d.icon = 'res://assets/icons/items/war_hammer.png'
  d.attack_sound = 'blunt'
  d.cooldown = Balance.SMITH_WARHAMMER_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.SMITH_WARHAMMER_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  # The blow also knocks back one random enemy item's cooldown bar, landing with the hit.
  var stagger := ItemEffect.new()
  stagger.mechanic = DechargeMechanic.ID
  stagger.value = 1.0
  stagger.shape = ItemEffect.Shape.OPPONENT_ITEM_RANDOM
  stagger.travel = Balance.WEAPON_TRAVEL
  d.effects = [hit, stagger]
  d.panel_color = Colours.ATTACK
  return d


static func _smith_greatsword() -> ItemDef:
  var d := ItemDef.new()
  d.id = SMITH_GREATSWORD
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Greatsword'           # PLACEHOLDER name — owner's to rename
  d.icon = 'res://assets/icons/items/sword_twohanded_1.png'
  d.attack_sound = 'blade'
  d.cooldown = Balance.SMITH_GREATSWORD_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.SMITH_GREATSWORD_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  d.effects = [hit]
  d.panel_color = Colours.ATTACK
  return d


static func _enemy_claw() -> ItemDef:
  var d := ItemDef.new()
  d.id = ENEMY_CLAW
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Claw'
  d.icon = 'res://assets/icons/items/loot_183_claw.png'
  d.cooldown = Balance.ENEMY_CLAW_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = Balance.ENEMY_CLAW_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  d.effects = [hit]
  d.panel_color = Colours.ATTACK
  return d


## Smith armour (names pulled from docs/design/item_name_reference.md — the owner renames) — the
## armour line (docs/design/smith.md): four plain shield items on a rising cooldown and shield
## ladder, the defensive counterpart to the weapon ladder. No rider; the identity is the ladder.
## Each spends its full budget from the curve. In the Smith's item_pool. COMMON.
static func _smith_vambraces() -> ItemDef:
  var d := ItemDef.new()
  d.id = SMITH_VAMBRACES
  d.types = [ItemType.ARMOUR]
  d.mechanics = [ShieldMechanic.ID]
  d.name_key = 'Vambraces'
  d.icon = 'res://assets/icons/items/gloves_01.png'
  d.cooldown = Balance.SMITH_VAMBRACES_COOLDOWN
  var blk := ItemEffect.new()
  blk.mechanic = ShieldMechanic.ID
  blk.value = Balance.SMITH_VAMBRACES_SHIELD
  blk.shape = ItemEffect.Shape.SELF
  d.effects = [blk]
  d.panel_color = Colours.SHIELD
  return d


static func _smith_sallet() -> ItemDef:
  var d := ItemDef.new()
  d.id = SMITH_SALLET
  d.types = [ItemType.ARMOUR]
  d.mechanics = [ShieldMechanic.ID]
  d.name_key = 'Sallet'
  d.icon = 'res://assets/icons/items/helm_footman_1.png'
  d.cooldown = Balance.SMITH_SALLET_COOLDOWN
  var blk := ItemEffect.new()
  blk.mechanic = ShieldMechanic.ID
  blk.value = Balance.SMITH_SALLET_SHIELD
  blk.shape = ItemEffect.Shape.SELF
  d.effects = [blk]
  d.panel_color = Colours.SHIELD
  return d


static func _smith_kite_shield() -> ItemDef:
  var d := ItemDef.new()
  d.id = SMITH_KITE_SHIELD
  d.types = [ItemType.ARMOUR]
  d.mechanics = [ShieldMechanic.ID]
  d.name_key = 'Kite Shield'
  d.icon = 'res://assets/icons/items/metal_shield_1.png'
  d.cooldown = Balance.SMITH_KITE_SHIELD_COOLDOWN
  var blk := ItemEffect.new()
  blk.mechanic = ShieldMechanic.ID
  blk.value = Balance.SMITH_KITE_SHIELD_SHIELD
  blk.shape = ItemEffect.Shape.SELF
  d.effects = [blk]
  d.panel_color = Colours.SHIELD
  return d


static func _smith_breast_plate() -> ItemDef:
  var d := ItemDef.new()
  d.id = SMITH_BREAST_PLATE
  d.types = [ItemType.ARMOUR]
  d.mechanics = [ShieldMechanic.ID]
  d.name_key = 'Breast Plate'
  d.icon = 'res://assets/icons/items/leather_chest_1.png'
  d.cooldown = Balance.SMITH_BREAST_PLATE_COOLDOWN
  var blk := ItemEffect.new()
  blk.mechanic = ShieldMechanic.ID
  blk.value = Balance.SMITH_BREAST_PLATE_SHIELD
  blk.shape = ItemEffect.Shape.SELF
  d.effects = [blk]
  d.panel_color = Colours.SHIELD
  return d
