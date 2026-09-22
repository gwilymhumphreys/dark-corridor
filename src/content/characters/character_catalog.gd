class_name CharacterCatalog
## The character definitions (#23 — GDScript, keyed by String id). Each character has its OWN
## item pool (#27). The prototype Wanderer and Duelist were deleted once the Fleshmancer and the
## Spore Druid could carry a run. Lazily built once, like the other catalogs.

const SPORE_DRUID := 'spore_druid'
const FLESHMANCER := 'fleshmancer'
const SMITH := 'smith'

## The character a run opens on when none is chosen: the title-screen autostart, the save-resume
## fallback, and the autotest's baseline. The Smith holds it because it is the character being
## balanced first (owner, 2026-09-21); the other two are not yet on the points curve.
const DEFAULT := SMITH

static var _defs: Dictionary = {}


static func get_def(id: String) -> CharacterDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('CharacterCatalog: unknown character id "%s"' % id)
  return _defs[id]


## True if `id` is an AUTHORED character (rostered or not — the autotest's --character validates
## here so it can drive a not-yet-listed character for tuning). Lazily builds, like the catalogs.
static func has(id: String) -> bool:
  if _defs.is_empty():
    _build()
  return _defs.has(id)


## The roster ids in display order — the character-select screen enumerates this. The
## characters' numbers and names are still placeholders to /tune and rename. The Smith leads
## (owner, 2026-09-23), as the character being balanced first.
static func ids() -> Array:
  if _defs.is_empty():
    _build()
  return [SMITH, FLESHMANCER, SPORE_DRUID]


## The run-start board for a character: its fixed `starting_item_ids`, or — when it lists
## `starting_item_types` — one random item of each type, drawn from its own pool on `rng`. Each
## slot draws a DISTINCT item, so a repeated type asks for two different items of it. A type with
## nothing left in the pool is skipped with a warning rather than crashing, which keeps a
## half-authored character startable. Both the run and the autotest sandbox build boards through
## here, so there is one definition of what a character opens with.
static func starting_board(def: CharacterDef, rng: RandomNumberGenerator) -> Array:
  if def.starting_item_types.is_empty():
    return def.starting_item_ids.duplicate()
  var ids: Array = []
  for type: String in def.starting_item_types:
    var candidates: Array = []
    for item_id: String in def.item_pool:
      var item_def: ItemDef = ItemCatalog.get_def(item_id)
      if item_def != null and item_def.types.has(type) and not ids.has(item_id):
        candidates.append(item_id)
    if candidates.is_empty():
      push_warning('CharacterCatalog: %s has no unused "%s" item for its starting board' % [def.id, type])
      continue
    ids.append(candidates[rng.randi_range(0, candidates.size() - 1)])
  return ids


static func _build() -> void:
  _defs[SPORE_DRUID] = _spore_druid()
  _defs[FLESHMANCER] = _fleshmancer()
  _defs[SMITH] = _smith()


## Spore Druid — the first real character (spore_druid.md). Status-identity: its kit is built
## on the Spores counter (the Mass fuel) + spore appliers. SCAFFOLD — holds what's authored
## so far (the pool below is the authority; spore_druid.md tracks the running count); starts
## with Druid Staff. Still the owner's to fill: the signature starting relic (the most
## build-defining — design), skills + more cards, and flipping it into ids() once the pool is deep enough to draft.
static func _spore_druid() -> CharacterDef:
  var d := CharacterDef.new()
  d.id = SPORE_DRUID
  d.name_key = 'Maren'                 # PLACEHOLDER personal name — owner's to rename
  d.subtitle_key = 'Rot Shepherd'      # the owner's lead role name (spore_druid.md); 'Spore Druid' stays the internal label
  d.portrait = 'res://assets/portraits/characters/shaman.png'   # PLACEHOLDER portrait — owner's to swap
  d.item_pool = [
    ItemCatalog.DRUID_STAFF,
    ItemCatalog.SPORE_SPITTER,
    ItemCatalog.CAPPED_CUDGEL,
    ItemCatalog.BLOOMHAMMER,
    ItemCatalog.WILT_FROND,
    ItemCatalog.POCKET_SHROOMS,
  ]
  # Three weapons, drawn per run. FORCED BY THE POOL: every Spore Druid item is weapon-typed, so
  # there is no skill or armour to ask for. Revisit once its skills and armour are authored.
  d.starting_item_types = [ItemType.WEAPON, ItemType.WEAPON, ItemType.WEAPON]
  d.starting_relic_id = ''                          # no signature relic yet (the owner's to design)
  d.starting_potion_ids = []
  d.starting_enchants = []
  return d


## Fleshmancer (PLACEHOLDER name — owner's to rename; character_ideas.md → Flesh Golem / Meat) — an
## item-economy character: its attacks create Chunks of Flesh on the player's OWN board, which decay
## after a couple of activations (the CREATE_ITEM + Decay seams, item_creation_and_decay.md). SCAFFOLD
## — the pool below is the authority (chunk-creating attacks, the self-harm producer + consumer, the
## Reclaim payoff, a bleed applier, and the bone shield spread); numbers + names are PLACEHOLDERS to
## tune / rename (a Vermis display-name later). Still the owner's to fill: the signature relic, more pool depth, and flipping it into ids() once it's non-degenerate to
## draft. Starts with a 3-item kit that seeds the loop + a survival floor: Cleaver (producer),
## Femur (shield), Carving Knife (fast producer) — the other characters' 3-item start floor.
static func _fleshmancer() -> CharacterDef:
  var d := CharacterDef.new()
  d.id = FLESHMANCER
  d.name_key = 'Aldous'                # PLACEHOLDER personal name — owner's to rename
  d.subtitle_key = 'Disgraced Surgeon' # the owner's role name (2026-09-18); 'Fleshmancer' stays the internal label
  d.portrait = 'res://assets/portraits/characters/leper_nb.png'
  d.item_pool = [
    ItemCatalog.FLESH_CARVING_KNIFE,
    ItemCatalog.FLESH_CLEAVER,
    ItemCatalog.FLESH_BONE_SAW,
    ItemCatalog.FLESH_EXPLOSION,
    ItemCatalog.FLESH_FLENSING_HOOK,
    ItemCatalog.FLESH_SKIN_GRAFT,
    ItemCatalog.FLESH_BONE_SPEAR,
    ItemCatalog.FLESH_RIB,
    ItemCatalog.FLESH_FEMUR,
    ItemCatalog.FLESH_SKULL,
  ]
  # Two weapons and an armour item, drawn per run — the shape of the kit that was authored here
  # (two chunk producers plus a shield). PLACEHOLDER mix: swap a weapon for ItemType.SKILL or
  # ItemType.SPELL if the opening should carry one.
  d.starting_item_types = [ItemType.WEAPON, ItemType.WEAPON, ItemType.ARMOUR]
  d.starting_relic_id = ''                          # no signature relic yet (the owner's to design)
  d.starting_potion_ids = []
  d.starting_enchants = []
  return d


## Smith (PLACEHOLDER label — owner's to rename; smith.md) — the roster's on-ramp character,
## promoted 2026-09-21 and absorbing the former Armourer, whose authored items are its pool below.
## Its identity is that it manages no separate resource: its skills buff its own weapons and armour
## over a fight, so what accumulates sits on the items rather than in a counter beside them.
## SCAFFOLD — holds the empower engine authored so far (Mighty Blow + the three big weapons, whose
## per-hit ladder makes the slowest the best thing to double) and the armour ladder beside it.
## Still the owner's to fill: the go-wide / go-tall split, the signature relic, a portrait, and the
## real 3-item starting kit. First in ids() (owner, 2026-09-23).
static func _smith() -> CharacterDef:
  var d := CharacterDef.new()
  d.id = SMITH
  d.name_key = 'Orrin'                 # PLACEHOLDER personal name — owner's to rename
  d.subtitle_key = 'Smith'             # PLACEHOLDER role line — owner's to rename
  d.portrait = 'res://assets/portraits/characters/warrior_nb.png'   # PLACEHOLDER portrait — owner's to swap
  d.item_pool = [
    ItemCatalog.MIGHTY_BLOW,
    ItemCatalog.SMITH_BROADAXE,
    ItemCatalog.SMITH_WARHAMMER,
    ItemCatalog.SMITH_GREATSWORD,
    ItemCatalog.SMITH_VAMBRACES,
    ItemCatalog.SMITH_SALLET,
    ItemCatalog.SMITH_KITE_SHIELD,
    ItemCatalog.SMITH_BREAST_PLATE,
  ]
  # One weapon, one skill and one armour item, drawn per run (the owner's constraint).
  d.starting_item_types = [ItemType.WEAPON, ItemType.SKILL, ItemType.ARMOUR]
  d.starting_relic_id = ''                             # no signature relic yet (the owner's to design)
  d.starting_potion_ids = []
  d.starting_enchants = []
  return d
