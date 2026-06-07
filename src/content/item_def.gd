class_name ItemDef
extends RefCounted
## The item definition (item_prd) — authored in GDScript (#23), collected in
## ItemCatalog. Configures one Item class; rarity is a complexity tier, not a
## power multiplier. Numbers point to Balance.

enum Rarity { COMMON, UNCOMMON, RARE }

var id: String = ''
var name_key: String = ''         # source English; displayed via tr()
var rarity: int = Rarity.COMMON
var cooldown: float = 1.0          # seconds -> Ticker threshold
var effects: Array = []            # Array[ItemEffect] (one usually; rares combine)
var trigger_subs: Array = []       # Array[{ event:int, amount:float, filter:int }]
var panel_color: Color = Color.WHITE
