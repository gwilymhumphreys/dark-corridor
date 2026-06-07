class_name ItemEffect
extends RefCounted
## One authored effect of an item (item_prd). An item fires one payload per
## effect. Carries a relative target-SHAPE (not a resolved target — the Combat
## manager resolves it) + the payload kind/value + travel + presentation.

enum Shape { SELF, OPPONENT_LEFTMOST, ALL_OPPONENTS, OPPONENT_ITEM_RANDOM, ALL_OPPONENT_ITEMS }

var kind: int = Delivery.Kind.DAMAGE
var value: float = 0.0
var shape: int = Shape.OPPONENT_LEFTMOST
var travel: float = 0.0          # seconds (0 = instant; combat_prd's zero case)
var status_type: int = -1        # for kind == APPLY_STATUS
var flags: int = 0               # Delivery.Flag bits (e.g. unblockable)
var color: Color = Color.WHITE

# Status-stack consumption (spore_engine_prd Cap 1) — spend a stacked status as fuel,
# scaling this effect's value by `consume_scale` per stack removed. `consume_from_target`
# false = self-fuel (the owner's stacks, resolved at fire — Item._resolve_effect); true =
# opponent-fuel (the resolved target's stacks — Mass, resolved by the Combat manager at
# Delivery spawn). Numbers are content (ItemDef).
var consume_type: int = -1       # StatusDef.Type to spend (-1 = none)
var consume_amount: float = 0.0  # up to this many stacks
var consume_from_target: bool = false
var consume_scale: float = 0.0   # value added to the payload per stack consumed

# Summon (spore_engine_prd Cap 3): a kind == SUMMON effect spawns a token Actor from an
# EnemyCatalog def onto the summoner's OWN side (shape SELF). `summon_in_front` puts it
# leftmost (body-block / adds-in-front). The token def + the trigger are content.
var summon_def_id: String = ''
var summon_in_front: bool = true
