class_name Payload
extends RefCounted
## What an item fire hands up (docs/systems/item.md step 4): a resolved (kind, value) plus
## its relative target-SHAPE, travel, flags, and presentation. The Combat manager
## turns each Payload into a Delivery — resolving the shape to a concrete target.
## (Distinct from ItemEffect: that is the authored template; this is the runtime
## output after value-modifiers / enchants are applied.)

var kind: int = Delivery.Kind.DAMAGE
var value: float = 0.0
var shape: int = ItemEffect.Shape.OPPONENT_LEFTMOST
var travel: float = 0.0
var status_id: String = ''
var duration: float = 0.0     # per-application duration for an APPLY_STATUS payload (timed statuses)
var flags: int = 0
var color: Color = Color.WHITE
var source = null              # the firing Item
# Opponent-fuel consume declaration (docs/systems/spore_engine.md Cap 1 — Mass): the Combat manager
# consumes `consume_id` from the resolved target at spawn and scales the Delivery value.
# Self-fuel is already applied into `value` at fire (Item._resolve_effect).
var consume_id: String = ''
var consume_amount: float = 0.0
var consume_from_target: bool = false
var consume_scale: float = 0.0
# Summon (docs/systems/spore_engine.md Cap 3): the token def + position, resolved by the Combat manager.
var summon_def_id: String = ''
var summon_in_front: bool = true
