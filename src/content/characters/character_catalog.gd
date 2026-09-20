class_name CharacterCatalog
## The character definitions (#23 — GDScript, keyed by String id). Each character has its OWN
## item pool (#27). The prototype Wanderer and Duelist were deleted once the Fleshmancer and the
## Spore Druid could carry a run. Lazily built once, like the other catalogs.

const SPORE_DRUID := 'spore_druid'
const FLESHMANCER := 'fleshmancer'
const SMITH := 'smith'

## The character a run opens on when none is chosen: the title-screen autostart, the save-resume
## fallback, and the autotest's baseline. The Fleshmancer holds it because its pool is the deepest.
const DEFAULT := FLESHMANCER

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


## The roster ids in display order — the character-select screen enumerates this. The Fleshmancer
## leads: it is DEFAULT (the autostart and the autotest baseline) and has the deeper pool. Both
## characters' numbers and names are still placeholders to /tune and rename. Add an id here once
## its pool is deep enough to play. The Smith is authored but deliberately absent (owner,
## 2026-09-21): it goes FIRST in this list, and takes DEFAULT, once it has a playable pool.
static func ids() -> Array:
  if _defs.is_empty():
    _build()
  return [FLESHMANCER, SPORE_DRUID]


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
  d.starting_item_ids = [ItemCatalog.DRUID_STAFF]
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
  d.starting_item_ids = [ItemCatalog.FLESH_CLEAVER, ItemCatalog.FLESH_FEMUR, ItemCatalog.FLESH_CARVING_KNIFE]
  d.starting_relic_id = ''                          # no signature relic yet (the owner's to design)
  d.starting_potion_ids = []
  d.starting_enchants = []
  return d


## Smith (PLACEHOLDER label — owner's to rename; smith.md) — the roster's on-ramp character,
## promoted 2026-09-21 and absorbing the former Armourer, whose authored items are its pool below.
## Its identity is that it manages no separate resource: its skills buff its own weapons and armour
## over a fight, so what accumulates sits on the items rather than in a counter beside them.
## SCAFFOLD — holds the empower engine authored so far (Mighty Blow + the three big weapons, whose
## per-hit ladder makes the slowest the best thing to double). Still the owner's to fill: the
## shield-spend line, the go-wide / go-tall split, the signature relic, a portrait, and the real
## 3-item starting kit. NOT in ids() yet — see the note there.
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
  ]
  d.starting_item_ids = [ItemCatalog.SMITH_BROADAXE]   # PLACEHOLDER — the 3-item floor is unauthored
  d.starting_relic_id = ''                             # no signature relic yet (the owner's to design)
  d.starting_potion_ids = []
  d.starting_enchants = []
  return d
