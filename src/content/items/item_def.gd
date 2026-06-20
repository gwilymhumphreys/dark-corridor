class_name ItemDef
extends RefCounted
## The item definition (docs/systems/item.md) — authored in GDScript (#23), collected in
## ItemCatalog. Configures one Item class; rarity is a complexity tier, not a
## power multiplier. Numbers point to Balance.

enum Rarity { COMMON, UNCOMMON, RARE }

var id: String = ''
var name_key: String = ''         # source English; displayed via tr()
# Optional authored flavor line (docs/systems/tooltips.md) — appended below the generated
# mechanical lines in the tooltip; tr()'d. Empty = generated lines only.
var description_key: String = ''
var rarity: int = Rarity.COMMON
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
var panel_color: Color = Color.WHITE
