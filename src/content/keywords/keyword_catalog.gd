class_name KeywordCatalog
## The tooltip keyword catalog (docs/systems/tooltips.md): maps a keyword id to its card data
## `{name_key, desc_key, color, icon}`. Three kinds of id:
##
##   - a MECHANIC id ('attack', 'shield', 'poison', …) → pulls its presentation straight from the
##     Mechanic class (name_key / desc_key / color / icon), so a mechanic is documented in exactly
##     one place.
##   - a STATUS id ('weak', 'vulnerable', …) → pulls its presentation straight from the StatusEffect
##     subclass, so a status is documented in exactly one place.
##   - a MECHANIC KEYWORD id ('kw:fuel', 'kw:summon', …) → authored here. A mechanic keyword appears
##     in a tooltip ONLY if it has an entry below — that absence is how the owner gates a mechanic
##     card (author the entry → the card shows; remove it → it silently disappears).
##
## Owner's domain: the mechanic desc_key copy (and which mechanics exist). Scaffolded as marked
## placeholders. Lazily built once, like the other catalogs.

const FUEL := 'kw:fuel'
const SUMMON := 'kw:summon'
const AOE := 'kw:aoe'
const ITEM_TARGET := 'kw:item_target'
const UNBLOCKABLE := 'kw:unblockable'
const TRIGGER := 'kw:trigger'
const RECLAIM := 'kw:reclaim'
const ENCHANT := 'kw:enchant'

# The fixed display order for mechanic keywords in the column (statuses come first, in effect order).
const MECHANIC_ORDER: Array[String] = [FUEL, SUMMON, AOE, ITEM_TARGET, UNBLOCKABLE, TRIGGER, RECLAIM, ENCHANT]

static var _mechanics: Dictionary = {}


static func _build() -> void:
  # PLACEHOLDER desc copy — owner writes. name_key is the displayed term (tr()'d).
  _mechanics[FUEL] = {
    'name_key': 'Fuel',
    'desc_key': 'Spends stacks of a status to power up the effect.',
    'color': Colours.STATUS_SPORES,
    'icon': 'res://assets/icons/keywords/skill_absorbing_fire_nb.png',
  }
  _mechanics[SUMMON] = {
    'name_key': 'Summon',
    'desc_key': 'Brings an ally onto your side of the board.',
    'color': Colours.HEAL,
    'icon': 'res://assets/icons/keywords/skill_summon_skeletons_nb.png',
  }
  _mechanics[AOE] = {
    'name_key': 'All Enemies',
    'desc_key': 'Hits every enemy at once.',
    'color': Colours.ATTACK,
    'icon': 'res://assets/icons/keywords/skill_sword_splash_nb.png',
  }
  _mechanics[ITEM_TARGET] = {
    'name_key': 'Item Target',
    'desc_key': 'Targets an enemy item rather than the enemy.',
    'color': Colours.ARCANE,
    'icon': 'res://assets/icons/keywords/skill_mark_nb.png',
  }
  _mechanics[UNBLOCKABLE] = {
    'name_key': 'Unblockable',
    'desc_key': 'Cannot be soaked by Shield.',
    'color': Colours.ATTACK,
    'icon': 'res://assets/icons/keywords/skill_piercing_attack_nb.png',
  }
  _mechanics[TRIGGER] = {
    'name_key': 'Trigger',
    'desc_key': 'Charges faster when its condition happens.',
    'color': Colours.STATUS_VULNERABLE,
    'icon': 'res://assets/icons/keywords/skill_lightning_charge_nb.png',
  }
  # Reclaim — the destroy-payoff keyword (the Fleshmancer's; character_ideas.md). The labelled
  # trigger that replaces "when one of your items is destroyed". Pairs with the Decay status as
  # cause -> payoff. PLACEHOLDER copy — owner's to refine/rename.
  _mechanics[RECLAIM] = {
    'name_key': 'Reclaim',
    'desc_key': 'Charges as your own items are destroyed.',
    'color': Colours.STATUS_DECAY,
    'icon': 'res://assets/icons/keywords/skill_graveyard_souls_nb.png',
  }
  _mechanics[ENCHANT] = {
    'name_key': 'Enchant',
    'desc_key': 'A permanent modifier attached to this item.',
    'color': Colours.BEAT_RELIC,
    'icon': 'res://assets/icons/keywords/skill_runic_weapon_nb.png',
  }


## Rebuild the mechanic cards on next use, so they take the current `Colours`
## (docs/systems/interface_palette.md). Status cards read the status class each time.
static func refresh_colours() -> void:
  _mechanics.clear()


## True if `id` resolves to a card. Mechanics defer to the MechanicRegistry; statuses to the
## StatusRegistry; `kw:` mechanic ids must be authored above. An unknown id (catalog-gated out)
## returns false — no chip card, silently.
static func has(id: String) -> bool:
  if MechanicRegistry.has(id):
    return true
  if id.begins_with('kw:'):
    if _mechanics.is_empty():
      _build()
    return _mechanics.has(id)
  return StatusRegistry.has(id)


## The card data for `id`: `{name_key, desc_key, color, icon}`, or an empty Dictionary if unknown
## (the chip then renders its bare name and shows no card — never crash; tooltips.md).
static func get_entry(id: String) -> Dictionary:
  if MechanicRegistry.has(id):
    var m: Mechanic = MechanicRegistry.get_mechanic(id)
    return {
      'name_key': m.name_key,
      'desc_key': m.desc_key,
      'color': m.color(),
      'icon': m.icon,
    }
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
