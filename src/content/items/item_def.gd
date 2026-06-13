class_name ItemDef
extends RefCounted
## The item definition (docs/systems/item.md) — authored in GDScript (#23), collected in
## ItemCatalog. Configures one Item class; rarity is a complexity tier, not a
## power multiplier. Numbers point to Balance.

enum Rarity { COMMON, UNCOMMON, RARE }

var id: String = ''
var name_key: String = ''         # source English; displayed via tr()
var rarity: int = Rarity.COMMON
var cooldown: float = 1.0          # seconds -> Ticker threshold
var effects: Array[ItemEffect] = []   # one usually; rares combine
# Array[{ event:int (EventBus.Event), amount:float, filter:Variant (a status string id),
#         source_filter:int (EventBus.SourceFilter; omitted = OWN_SIDE — decision #30) }]
var trigger_subs: Array[Dictionary] = []
var panel_color: Color = Color.WHITE
