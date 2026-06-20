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
var source = null              # the firing Item (the VFX origin; null for a thrown consumable)
var source_actor: Actor = null # the acting Actor — event source identity (decision #30)
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
# Create-item (docs/systems/item_creation_and_decay.md Cap 1): the def of the item to create, resolved
# by the Combat manager at the CREATE_ITEM Delivery's land (shape SELF → the firing actor's board).
var create_item_def_id: String = ''
# Own-board item-consume (docs/systems/item_creation_and_decay.md — the Mass-twin on board items): the
# Combat manager counts + removes the owner's matching board items at fire (via remove_item, so each
# publishes ITEM_DESTROYED) and scales this payload's value by the count. amount <= 0 = all present.
var consume_item_def_id: String = ''
var consume_item_amount: int = 0
var consume_item_scale: float = 0.0


## Copy an ItemEffect template's fields into a fresh Payload — the ONE place the
## field-by-field copy lives. The item fire pipeline and the consumable throw both
## build on this, then add their own stages: enchant/outgoing modifiers are the
## item's (a throw is exempt — decision #30); source identity is the caller's.
static func from_effect(effect: ItemEffect) -> Payload:
  var payload := Payload.new()
  payload.kind = effect.kind
  payload.value = effect.value
  payload.shape = effect.shape
  payload.travel = effect.travel
  payload.status_id = effect.status_id
  payload.duration = effect.duration
  payload.summon_def_id = effect.summon_def_id
  payload.summon_in_front = effect.summon_in_front
  payload.create_item_def_id = effect.create_item_def_id
  payload.consume_item_def_id = effect.consume_item_def_id
  payload.consume_item_amount = effect.consume_item_amount
  payload.consume_item_scale = effect.consume_item_scale
  payload.consume_id = effect.consume_id
  payload.consume_amount = effect.consume_amount
  payload.consume_from_target = effect.consume_from_target
  payload.consume_scale = effect.consume_scale
  payload.flags = effect.flags
  payload.color = effect.color
  return payload
