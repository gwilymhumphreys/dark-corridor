class_name ConsumableDef
extends RefCounted
## A consumable (potion) definition (content_prd, decision #23) — a manually-fired
## reserve with NO Ticker (combat_prd: the one thing that doesn't accrue toward
## firing). Held in a potion slot, consumed on use. On throw the Combat manager
## builds its effect(s) into Deliveries — the same resolution surface as an item
## fire, minus the cooldown. Phase 3: one heal potion. Effects reuse `ItemEffect`
## (kind / value / shape / travel).

enum Rarity { COMMON, UNCOMMON, RARE }

var id: String = ''
var name_key: String = ''        # source English; displayed via tr() — localizable
var rarity: int = Rarity.COMMON
var effects: Array = []          # Array[ItemEffect]
