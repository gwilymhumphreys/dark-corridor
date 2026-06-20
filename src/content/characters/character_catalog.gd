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


## The roster ids in display order — the character-select screen enumerates this. DEFAULT
## leads (the first card / the autostart character). SPORE_DRUID is authored (in _defs) but
## intentionally NOT listed yet — its pool is too thin for a non-degenerate 1-of-3 draft;
## add it here once the Spore Druid pool is deep enough to play. FLESHMANCER is held out the
## same way (its pool is the three chunk-creating attacks — degenerate until it's deepened).
static func ids() -> Array:
  if _defs.is_empty():
    _build()
  return [DEFAULT, DUELIST]


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


## PLACEHOLDER second character — proves the select screen + per-character start kit with a
## visibly distinct loadout (blade-forward, no relic / potion). Reuses the prototype item pool;
## the owner replaces this with a real character (its own pool, signature relic, identity).
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
## — holds the first three chunk-creating attack commons (the pool below is the authority) + the chunk
## they spawn; numbers + names are PLACEHOLDERS to tune / rename (a Vermis display-name later). Still
## the owner's to fill: the HP-spend cost line (the real item economy), block commons, the signature
## relic, the real select-screen blurb, a deeper pool, and flipping it into ids() once it's
## non-degenerate to draft. Starts with the mid Cleaver (cf. the Druid starting with Druid Staff).
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
  ]
  d.starting_item_ids = [ItemCatalog.FLESH_CLEAVER]
  d.starting_relic_id = ''                          # no signature relic yet (the owner's to design)
  d.starting_potion_ids = []
  d.starting_enchants = []
  return d
