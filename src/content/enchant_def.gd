class_name EnchantDef
extends RefCounted
## An enchantment definition (content_prd, decision #23) — a one-per-item modifier,
## a Draftable. A PERMANENT item modifier (saved on the board), NOT a status
## (decision #26: statuses are combat-scoped; durable item power is an enchant).
## Phase 3 builds the simplest hook only: scale-a-value (multiply the host item's
## payload values). The richer hooks (a secondary payload, a target-shape change,
## an on-resolve trigger) come later.

enum Rarity { COMMON, UNCOMMON, RARE }

var id: int = -1
var name_key: String = ''        # source English; displayed via tr() — localizable
var rarity: int = Rarity.COMMON
var value_mult: float = 1.0      # scales every payload value the host item fires
