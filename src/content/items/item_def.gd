class_name ItemDef
extends RefCounted
## The item definition (docs/systems/item.md) — authored in GDScript (#23), collected in
## ItemCatalog. Configures one Item class; rarity is a complexity tier, not a
## power multiplier. Each authored item is its own file under content/items/.

enum Rarity { COMMON, UNCOMMON, RARE }

var id: String = ''
var name_key: String = ''         # source English; displayed via tr()
var icon: String = ''             # res:// path of the item's picture (assets/icons/items/); empty = none
# Optional authored flavor line (docs/systems/tooltips.md) — appended below the generated
# mechanical lines in the tooltip; tr()'d. Empty = generated lines only.
var description_key: String = ''
var rarity: int = Rarity.COMMON
# The item's tags (decision #70, docs/systems/item.md → Tags): its type tags (ItemType), every
# mechanic it counts as (MechanicRegistry ids) and other names content refers to (ItemTags). Target
# filters, shops, the tooltip, sounds and the item pools (ItemPools) read this one list. Authored, not derived
# from the effects (the author's judgment about what the item is). Written in alphabetical order of
# the ids; tests/content/test_pool_integrity.gd checks the order, that every tag is known, and that
# every mechanic an effect deals or applies is listed.
var tags: Array[String] = []
# Whether drafts, shops and starting boards can offer the item to a character whose pools cover it
# (ItemPools). False keeps it out of every character's pool: an item made only during a fight, an
# enemy's item, an example.
var draftable: bool = true
# The folder under mechanics/attack/ whose recordings this item's attacks play
# (docs/systems/audio.md) — 'blade' and 'blunt' to start with, and any other name works by
# making the folder. Presentation only: the sound layer reads it, and AttackHitDrawer draws a slash
# for 'blade' and an impact otherwise. That is what separates it from `tags` above, whose values
# are labels content may key off. Empty = the plain mechanics/attack folder.
var attack_sound: String = ''
# The folder under combat/travel/ this item's projectiles play in flight (docs/systems/audio.md),
# ahead of the folders for its type tags and mechanic. Sound only, like attack_sound. Empty = the
# usual lookup: type tags, then mechanic, then the shared default.
var travel_sound: String = ''
var cooldown: float = 1.0          # seconds -> Ticker threshold
var effects: Array[ItemEffect] = []   # one usually; rares combine
# Array[{ event:int (EventBus.Event), amount:float, filter:Variant (a status string id),
#         source_filter:int (EventBus.SourceFilter; omitted = OWN_SIDE — decision #30) }]
var trigger_subs: Array[Dictionary] = []
# A starting seed for the decay use-status (docs/systems/item_creation_and_decay.md Cap 2): >0 means
# the engine applies Decay with this many activations at item birth (fight start, or add_item for a
# created chunk), so the item is destroyed after that many fires. 0 = unlimited (never decays). Just a
# seed — the live thing is the status, which content can then top up / re-target. Numbers -> Balance.
var starting_uses: int = 0
# Crit chance (docs/systems/mechanics.md → Crit): 0 to 1. On a fire, the Combat manager rolls
# once; on a crit, the values of that fire's mechanic deliveries are multiplied by
# Balance.CRIT_MULTIPLIER. 0 = never crits (the default; draws nothing from the per-fight RNG).
var crit_chance: float = 0.0
# The item's panel colour, worked out on each read so a palette change shows at once: the `Colours`
# variable named by `panel_colour_name` when set ('STATUS_DECAY'), else the first effect's colour.
var panel_colour_name: String = ''
var panel_color: Color:
  get = _get_panel_color


func _get_panel_color() -> Color:
  if panel_colour_name != '':
    return Colours.named(panel_colour_name)
  if effects.is_empty():
    return Color.WHITE
  return effects[0].color
