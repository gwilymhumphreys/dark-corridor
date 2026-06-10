class_name CharacterCatalog
## The character definitions (#23 — GDScript, keyed by String id). One placeholder default
## ('wanderer') ports the prototype seed — its board, the Stone Ward relic, a Whetstone'd
## weapon, a Healing Draught, and the prototype draft pool — now character-scoped (#27).
## The owner authors the real characters (the Spore Druid, …), each with its OWN item
## pool. Lazily built once, like the other catalogs.

const DEFAULT := 'wanderer'
const DUELIST := 'duelist'
const SPORE_DRUID := 'spore_druid'

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
## add it here once the Spore Druid pool is deep enough to play.
static func ids() -> Array:
  if _defs.is_empty():
    _build()
  return [DEFAULT, DUELIST]


static func _build() -> void:
  _defs[DEFAULT] = _wanderer()
  _defs[DUELIST] = _duelist()
  _defs[SPORE_DRUID] = _spore_druid()


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
## on the Spores counter (the Mass fuel) + spore appliers. SCAFFOLD — holds only what's
## authored so far: Druid Staff (the starter applier) + Pocket Shrooms (the blinding rare) in
## its OWN pool (#27); starts with Druid Staff. Still the owner's to fill: the signature
## starting relic (the most build-defining — design), more pool + starting cards, the real
## select-screen blurb, and flipping it into ids() once the pool is deep enough to draft.
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
