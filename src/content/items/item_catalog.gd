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
const FLESH_CHUNK := 'flesh_chunk'
const FLESH_CARVING_KNIFE := 'flesh_carving_knife'
const FLESH_CLEAVER := 'flesh_cleaver'
const FLESH_BONE_SAW := 'flesh_bone_maul'
const FLESH_EXPLOSION := 'flesh_explosion'
const FLESH_FLENSING_HOOK := 'flesh_flensing_hook'
const FLESH_SKIN_GRAFT := 'flesh_skin_graft'

static var _defs: Dictionary = {}


static func get_def(id: String) -> ItemDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('ItemCatalog: unknown item id "%s"' % id)
    return null   # caller guards (a typo'd id no-ops + logs, never crashes)
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
  _defs[FLESH_CHUNK] = _flesh_chunk()
  _defs[FLESH_CARVING_KNIFE] = _flesh_carving_knife()
  _defs[FLESH_CLEAVER] = _flesh_cleaver()
  _defs[FLESH_BONE_SAW] = _flesh_bone_saw()
  _defs[FLESH_EXPLOSION] = _flesh_explosion()
  _defs[FLESH_FLENSING_HOOK] = _flesh_flensing_hook()
  _defs[FLESH_SKIN_GRAFT] = _flesh_skin_graft()


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


## Chunk of Flesh — the created token-item the Fleshmancer's attacks spawn on the player's OWN board
## (docs/systems/item_creation_and_decay.md). A weak auto-attacker: deals 1 damage every 2s and
## DECAYS after 2 activations (starting_uses → the Decay use-status) — "very low power, but does
## something" (owner). NOT drafted directly (it isn't in any item_pool); it only appears via a
## CREATE_ITEM rider. Numbers -> Balance (placeholders).
static func _flesh_chunk() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_CHUNK
  d.name_key = 'Chunk of Flesh'        # owner's term — rename if desired
  d.cooldown = Balance.FLESH_CHUNK_COOLDOWN
  d.starting_uses = Balance.FLESH_CHUNK_USES   # decays after this many fires (the Decay use-status seed)
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.FLESH_CHUNK_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.DAMAGE
  d.effects = [hit]
  d.panel_color = hit.color
  return d


## Carving Knife — the FAST pole of the Fleshmancer attack
## spread (character_ideas.md → Flesh Golem / Meat): a quick jab that deals LOW damage AND creates a
## Chunk of Flesh on the player's OWN board (shape SELF → the firer). At the **3s chunk-creator
## minimum** — a chunk lives ~4s, so faster creation would stack chunks up too quickly. COMMON.
## (Producer = carving/butchery; consumers will be surgery/sewing — see character_ideas.md.)
static func _flesh_carving_knife() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_CARVING_KNIFE
  d.name_key = 'Carving Knife'
  d.cooldown = Balance.FLESH_CARVING_KNIFE_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.FLESH_CARVING_KNIFE_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.DAMAGE
  var make := ItemEffect.new()
  make.kind = Delivery.Kind.CREATE_ITEM
  make.create_item_def_id = FLESH_CHUNK
  make.shape = ItemEffect.Shape.SELF         # the chunk lands on the firer's OWN board
  make.color = Colours.STATUS_DECAY          # the created chunk decays
  d.effects = [hit, make]
  d.panel_color = hit.color                  # primary payload is damage (single-panel model)
  return d


## Cleaver (PLACEHOLDER name — owner's to rename) — the MID pole + the Fleshmancer's starting card: a
## tempo attack that creates a Chunk of Flesh (shape SELF) and hits HARDER than the faster Carving Knife
## (6 vs 3 dmg) — slower chunk-rate, bigger hit, so neither pole dominates. COMMON.
static func _flesh_cleaver() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_CLEAVER
  d.name_key = 'Cleaver'               # PLACEHOLDER name — owner's to rename
  d.cooldown = Balance.FLESH_CLEAVER_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.FLESH_CLEAVER_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.DAMAGE
  var make := ItemEffect.new()
  make.kind = Delivery.Kind.CREATE_ITEM
  make.create_item_def_id = FLESH_CHUNK
  make.shape = ItemEffect.Shape.SELF
  make.color = Colours.STATUS_DECAY
  d.effects = [hit, make]
  d.panel_color = hit.color
  return d


## Bone Saw (PLACEHOLDER name — owner's to rename) — the SLOW pole: a heavy two-handed blow that
## deals LOW damage AND creates TWO Chunks of Flesh in one swing (two CREATE_ITEM effects, shape
## SELF). The bursty creator — ~2 chunks / 6s, same chunk-rate as the 3s Carving Knife but lumpier.
## COMMON.
static func _flesh_bone_saw() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_BONE_SAW
  d.name_key = 'Bone Saw'             # PLACEHOLDER name — owner's to rename
  d.cooldown = Balance.FLESH_BONE_SAW_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.FLESH_BONE_SAW_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.DAMAGE
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
  d.panel_color = hit.color
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
  d.name_key = 'Flesh Explosion'       # owner's name
  d.rarity = ItemDef.Rarity.UNCOMMON
  d.cooldown = Balance.FLESH_EXPLOSION_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.DAMAGE
  hit.value = Balance.FLESH_EXPLOSION_DAMAGE
  hit.shape = ItemEffect.Shape.ALL_OPPONENTS
  hit.travel = Balance.WEAPON_TRAVEL
  hit.color = Colours.DAMAGE
  d.effects = [hit]
  # Charges as your OWN items die — each ITEM_DESTROYED pushes the cooldown ~1s (OWN_SIDE is the
  # wired default; no data filter = any own item, per "whenever one of your items is destroyed").
  d.trigger_subs = [{
    'event': EventBus.Event.ITEM_DESTROYED,
    'amount': Balance.FLESH_EXPLOSION_CHARGE_PER_DESTROY,
  }]
  d.panel_color = hit.color
  return d


## Flensing Hook (PLACEHOLDER name — owner's to rename) — the self-harm PRODUCER (carving theme;
## character_ideas.md → Flesh Golem / Meat): deals UNBLOCKABLE damage to YOURSELF (shape SELF) and
## creates 2 Chunks of Flesh — the HP-spend identity made literal. Self-damage is UNBLOCKABLE so the
## player's own block can't absorb the cost (a Fleshmancer runs block to survive, so a blockable cost
## would silently no-op). No enemy damage — pure produce-by-bleeding. COMMON. Numbers -> Balance.
static func _flesh_flensing_hook() -> ItemDef:
  var d := ItemDef.new()
  d.id = FLESH_FLENSING_HOOK
  d.name_key = 'Flensing Hook'         # PLACEHOLDER name — owner's to rename
  d.cooldown = Balance.FLESH_FLENSING_HOOK_COOLDOWN
  var hurt := ItemEffect.new()
  hurt.kind = Delivery.Kind.DAMAGE
  hurt.value = Balance.FLESH_FLENSING_HOOK_SELF_DAMAGE
  hurt.shape = ItemEffect.Shape.SELF          # the firer takes the hit — self-harm
  hurt.flags = Delivery.Flag.UNBLOCKABLE      # own block must NOT absorb the cost (else the HP-spend no-ops)
  hurt.color = Colours.DAMAGE                 # travel 0 (self, instant)
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
  d.name_key = 'Skin Graft'            # PLACEHOLDER name — owner's to rename
  d.cooldown = Balance.FLESH_SKIN_GRAFT_COOLDOWN
  var heal := ItemEffect.new()
  heal.kind = Delivery.Kind.HEAL
  heal.value = 0.0                            # all healing comes from the consumed flesh
  heal.shape = ItemEffect.Shape.SELF
  heal.consume_item_def_id = FLESH_CHUNK      # eat a chunk off the OWN board
  heal.consume_item_amount = Balance.FLESH_SKIN_GRAFT_CONSUME
  heal.consume_item_scale = Balance.FLESH_SKIN_GRAFT_HEAL_PER_CHUNK  # heal per chunk consumed
  heal.color = Colours.HEAL
  d.effects = [heal]
  d.panel_color = heal.color
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
