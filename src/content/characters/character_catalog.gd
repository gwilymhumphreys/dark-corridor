class_name CharacterCatalog
## The character definitions (#23 — GDScript, keyed by String id). One placeholder default
## ('wanderer') ports the prototype seed — its board, the Stone Ward relic, a Whetstone'd
## weapon, a Healing Draught, and the prototype draft pool — now character-scoped (#27).
## The owner authors the real characters (the Spore Druid, …), each with its OWN item
## pool. Lazily built once, like the other catalogs.

const DEFAULT := 'wanderer'
const DUELIST := 'duelist'

static var _defs: Dictionary = {}


static func get_def(id: String) -> CharacterDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('CharacterCatalog: unknown character id "%s"' % id)
  return _defs[id]


## The roster ids in display order — the character-select screen enumerates this. DEFAULT
## leads (the first card / the autostart character).
static func ids() -> Array:
  if _defs.is_empty():
    _build()
  return [DEFAULT, DUELIST]


static func _build() -> void:
  _defs[DEFAULT] = _wanderer()
  _defs[DUELIST] = _duelist()


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
