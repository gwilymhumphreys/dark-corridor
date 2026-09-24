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
# Item-type tags (docs/systems/item.md) — synergy labels only, NO inherent gameplay effect: a future
# synergy reads tag membership (e.g. "your next weapon attack"), nothing keys off them today. An array
# (Bazaar-style tag set); most items carry exactly one. Values are ItemType consts. Items only —
# relics / consumables / enchants are separate Draftable categories and stay untagged.
var types: Array[String] = []
# The mechanic ids (MechanicRegistry) this item counts as (docs/systems/item.md) — used by targeting
# filters and by the tooltip keyword column. Authored, not derived from the effects (the author's
# judgment about what the item is). Written in alphabetical order; tests/content/test_pool_integrity.gd
# checks both the order and the floor (every mechanic an effect deals or applies is listed).
var mechanics: Array[String] = []
# The folder under mechanics/attack/ whose recordings this item's attacks play
# (docs/systems/audio.md) — 'blade' and 'blunt' to start with, and any other name works by
# making the folder. Sound only: nothing but the sound layer reads it, which is what separates
# it from `types` above, whose values are synergy labels content may key off. Empty = the plain
# mechanics/attack folder.
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
