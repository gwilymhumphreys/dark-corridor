class_name KeywordCatalog
## The tooltip keyword catalog (docs/systems/tooltips.md): maps a keyword id to its card data
## `{name_key, desc_key, color, icon}`. Two kinds of id:
##
##   - a STATUS id ('poison', 'block', …) → pulls its presentation straight from the StatusEffect
##     subclass (name_key / desc_key / color / icon), so a status is documented in exactly one place.
##   - a MECHANIC id ('kw:fuel', 'kw:summon', …) → authored here. A mechanic keyword appears in a
##     tooltip ONLY if it has an entry below — that absence is how the owner gates a mechanic card
##     (author the entry → the card shows; remove it → it silently disappears).
##
## Owner's domain: the mechanic desc_key copy (and which mechanics exist). Scaffolded as marked
## placeholders. Lazily built once, like the other catalogs.

const FUEL := 'kw:fuel'
const SUMMON := 'kw:summon'
const AOE := 'kw:aoe'
const ITEM_TARGET := 'kw:item_target'
const UNBLOCKABLE := 'kw:unblockable'
const TRIGGER := 'kw:trigger'
const ENCHANT := 'kw:enchant'

# The fixed display order for mechanic keywords in the column (statuses come first, in effect order).
const MECHANIC_ORDER: Array[String] = [FUEL, SUMMON, AOE, ITEM_TARGET, UNBLOCKABLE, TRIGGER, ENCHANT]

static var _mechanics: Dictionary = {}


static func _build() -> void:
  # PLACEHOLDER desc copy — owner writes. name_key is the displayed term (tr()'d).
  _mechanics[FUEL] = {
    'name_key': 'Fuel',
    'desc_key': 'Spends stacks of a status to power up the effect.',
    'color': Colours.STATUS_SPORES,
    'icon': '',
  }
  _mechanics[SUMMON] = {
    'name_key': 'Summon',
    'desc_key': 'Brings an ally onto your side of the board.',
    'color': Colours.HEAL,
    'icon': '',
  }
  _mechanics[AOE] = {
    'name_key': 'All Enemies',
    'desc_key': 'Hits every enemy at once.',
    'color': Colours.DAMAGE,
    'icon': '',
  }
  _mechanics[ITEM_TARGET] = {
    'name_key': 'Item Target',
    'desc_key': 'Targets an enemy item rather than the enemy.',
    'color': Colours.ARCANE,
    'icon': '',
  }
  _mechanics[UNBLOCKABLE] = {
    'name_key': 'Unblockable',
    'desc_key': 'Cannot be soaked by Block.',
    'color': Colours.DAMAGE,
    'icon': '',
  }
  _mechanics[TRIGGER] = {
    'name_key': 'Trigger',
    'desc_key': 'Charges faster when its condition happens.',
    'color': Colours.STATUS_VULNERABLE,
    'icon': '',
  }
  _mechanics[ENCHANT] = {
    'name_key': 'Enchant',
    'desc_key': 'A permanent modifier attached to this item.',
    'color': Colours.BEAT_RELIC,
    'icon': '',
  }


## True if `id` resolves to a card. Statuses defer to the registry; mechanic ids must be authored
## above. An unknown id (catalog-gated out) returns false — no chip card, silently.
static func has(id: String) -> bool:
  if id.begins_with('kw:'):
    if _mechanics.is_empty():
      _build()
    return _mechanics.has(id)
  return StatusRegistry.has(id)


## The card data for `id`: `{name_key, desc_key, color, icon}`, or an empty Dictionary if unknown
## (the chip then renders its bare name and shows no card — never crash; tooltips.md).
static func get_entry(id: String) -> Dictionary:
  if id.begins_with('kw:'):
    if _mechanics.is_empty():
      _build()
    return _mechanics.get(id, {})
  if StatusRegistry.has(id):
    var s: StatusEffect = StatusRegistry.create(id)
    return {
      'name_key': s.name_key,
      'desc_key': s.desc_key,
      'color': s.color,
      'icon': s.icon,
    }
  return {}
