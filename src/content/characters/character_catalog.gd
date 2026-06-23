class_name CharacterCatalog
## The character definitions (#23 — GDScript, keyed by String id). One placeholder default
## ('wanderer') ports the prototype seed — its board, the Stone Ward relic, a Whetstone'd
## weapon, a Healing Draught, and the prototype draft pool — now character-scoped (#27).
## The owner authors the real characters (the Spore Druid, …), each with its OWN item
## pool. Lazily built once, like the other catalogs.

const DEFAULT := 'wanderer'
const DUELIST := 'duelist'
const SPORE_DRUID := 'spore_druid'
const FLESHMANCER := 'fleshmancer'

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


## The roster ids in display order — the character-select screen enumerates this. DEFAULT leads
## (the first card / the autostart character + the autotest baseline — keep it). FLESHMANCER is now
## LIVE: its pool is deep enough (10 items) for a non-degenerate 1-of-3 draft, replacing the Duelist
## placeholder (numbers are still placeholders to /tune). SPORE_DRUID + DUELIST stay authored (in
## _defs) but unlisted — the Spore Druid pool is still too thin to draft; the Duelist is the dormant
## placeholder. Add an id here once its pool is deep enough to play.
static func ids() -> Array:
  if _defs.is_empty():
    _build()
  return [DEFAULT, FLESHMANCER]


static func _build() -> void:
  _defs[DEFAULT] = _wanderer()
  _defs[DUELIST] = _duelist()
  _defs[SPORE_DRUID] = _spore_druid()
  _defs[FLESHMANCER] = _fleshmancer()


## Placeholder default character — the prototype seed, now character-scoped. The owner
## replaces / joins this with real characters (each its own pool, relic, starting kit).
static func _wanderer() -> CharacterDef:
  var d := CharacterDef.new()
  d.id = DEFAULT
  d.name_key = 'Wanderer'
  d.blurb_key = 'A balanced kit — blade, plate, and a creeping poison.'
  d.item_pool = DraftPool.ITEMS                  # this character's draftable pool (#27)
  d.starting_item_ids = [ItemCatalog.WEAPON, ItemCatalog.ARMOR, ItemCatalog.POISON_DAGGER]
  d.starting_relic_id = RelicCatalog.STONE_WARD
  d.starting_potion_ids = [ConsumableCatalog.HEALING_DRAUGHT]
  d.starting_enchants = [{ 'item_index': 0, 'enchant_id': EnchantCatalog.WHETSTONE }]
  return d


## Spore Druid — the first real character (spore_druid.md). Status-identity: its kit is built
## on the Spores counter (the Mass fuel) + spore appliers. SCAFFOLD — holds what's authored
## so far (the pool below is the authority; spore_druid.md tracks the running count); starts
## with Druid Staff. Still the owner's to fill: the signature starting relic (the most
## build-defining — design), skills + more cards, the real select-screen blurb, and flipping
## it into ids() once the pool is deep enough to draft.
static func _spore_druid() -> CharacterDef:
  var d := CharacterDef.new()
  d.id = SPORE_DRUID
  d.name_key = 'Spore Druid'
  d.blurb_key = 'Stack Spores, then spend them.'   # PLACEHOLDER hook — owner writes the real one
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


## DORMANT placeholder — the Fleshmancer replaced it on the live roster (ids()), so it no longer
## shows in character select. Kept in _defs: it still proves the per-character start kit (a distinct
## blade-forward loadout sharing the prototype pool) and is a run-manager test fixture (a non-default
## character start). Delete once a second real character lands and nothing references it.
static func _duelist() -> CharacterDef:
  var d := CharacterDef.new()
  d.id = DUELIST
  d.name_key = 'Duelist'
  d.blurb_key = 'Twin blades, no safety net — all pressure, no plate.'
  d.item_pool = DraftPool.ITEMS                  # placeholder: shares the prototype pool for now
  d.starting_item_ids = [ItemCatalog.WEAPON, ItemCatalog.WEAPON, ItemCatalog.POISON_DAGGER]
  d.starting_relic_id = ''                        # no signature relic (a distinct, riskier start)
  d.starting_potion_ids = []
  d.starting_enchants = [{ 'item_index': 0, 'enchant_id': EnchantCatalog.WHETSTONE }]
  return d


## Fleshmancer (PLACEHOLDER name — owner's to rename; character_ideas.md → Flesh Golem / Meat) — an
## item-economy character: its attacks create Chunks of Flesh on the player's OWN board, which decay
## after a couple of activations (the CREATE_ITEM + Decay seams, item_creation_and_decay.md). SCAFFOLD
## — the pool below is the authority (chunk-creating attacks, the self-harm producer + consumer, the
## Reclaim payoff, a bleed applier, and the bone block spread); numbers + names are PLACEHOLDERS to
## tune / rename (a Vermis display-name later). Still the owner's to fill: the signature relic, the
## real select-screen blurb, more pool depth, and flipping it into ids() once it's non-degenerate to
## draft. Starts with the mid Cleaver (cf. the Druid starting with Druid Staff).
static func _fleshmancer() -> CharacterDef:
  var d := CharacterDef.new()
  d.id = FLESHMANCER
  d.name_key = 'Fleshmancer'           # PLACEHOLDER name — owner's to rename
  d.blurb_key = 'Carve yourself into a churning board of flesh.'   # PLACEHOLDER hook — owner writes the real one
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
  d.starting_item_ids = [ItemCatalog.FLESH_CLEAVER]
  d.starting_relic_id = ''                          # no signature relic yet (the owner's to design)
  d.starting_potion_ids = []
  d.starting_enchants = []
  return d
