class_name Payload
extends RefCounted
## What an item fire hands up (item_prd step 4): a resolved (kind, value) plus
## its relative target-SHAPE, travel, flags, and presentation. The Combat manager
## turns each Payload into a Delivery — resolving the shape to a concrete target.
## (Distinct from ItemEffect: that is the authored template; this is the runtime
## output after value-modifiers / enchants are applied.)

var kind: int = Delivery.Kind.DAMAGE
var value: float = 0.0
var shape: int = ItemEffect.Shape.OPPONENT_LEFTMOST
var travel: float = 0.0
var status_type: int = -1
var flags: int = 0
var color: Color = Color.WHITE
var source = null              # the firing Item
