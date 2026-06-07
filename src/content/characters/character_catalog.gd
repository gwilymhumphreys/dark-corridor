class_name CharacterCatalog
## The character definitions (#23 — GDScript, keyed by String id). One placeholder default
## ('wanderer') ports the prototype seed — its board, the Stone Ward relic, a Whetstone'd
## weapon, a Healing Draught, and the prototype draft pool — now character-scoped (#27).
## The owner authors the real characters (the Mushroom Druid, …), each with its OWN item
## pool. Lazily built once, like the other catalogs.

const DEFAULT := 'wanderer'

static var _defs: Dictionary = {}


static func get_def(id: String) -> CharacterDef:
  if _defs.is_empty():
    _build()
  if not _defs.has(id):
    push_error('CharacterCatalog: unknown character id "%s"' % id)
  return _defs[id]


static func _build() -> void:
  _defs[DEFAULT] = _wanderer()


## Placeholder default character — the prototype seed, now character-scoped. The owner
## replaces / joins this with real characters (each its own pool, relic, starting kit).
static func _wanderer() -> CharacterDef:
  var d := CharacterDef.new()
  d.id = DEFAULT
  d.name_key = 'Wanderer'
  d.item_pool = DraftPool.ITEMS                  # this character's draftable pool (#27)
  d.starting_item_ids = [ItemCatalog.WEAPON, ItemCatalog.ARMOR, ItemCatalog.POISON_DAGGER]
  d.starting_relic_id = RelicCatalog.STONE_WARD
  d.starting_potion_ids = [ConsumableCatalog.HEALING_DRAUGHT]
  d.starting_enchants = [{ 'item_index': 0, 'enchant_id': EnchantCatalog.WHETSTONE }]
  return d
