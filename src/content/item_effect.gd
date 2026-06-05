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
