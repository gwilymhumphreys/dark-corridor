class_name ChargeMechanic
extends Mechanic
## Charge — adds seconds of progress to the target item's cooldown bar, so it fires sooner
## (docs/systems/mechanics.md). It acts on an ITEM, not an actor.

const ID := 'charge'


func _init() -> void:
  id = ID
  name_key = 'Charge'
  desc_key = 'Fills that many seconds of an item\'s cooldown bar.'   # PLACEHOLDER desc — owner writes
  icon = IconSlots.icon_for(ID)


func color() -> Color:
  return Colours.CHARGE


## Shift `item`'s cooldown progress by `seconds` (negative pushes it back) and return the
## seconds actually applied. Clamped to the bar: never below empty, never past full, so a
## charge can never bank more than one fire (decision #30's no-banked-bursts rule).
static func shift_cooldown(item: Item, seconds: float) -> float:
  var before: float = item.cooldown.accum
  item.cooldown.accum = clampf(before + seconds / Balance.STEP, 0.0, item.cooldown.threshold)
  return (item.cooldown.accum - before) * Balance.STEP


func land(delivery: Delivery, combat: CombatManager) -> void:
  if not (delivery.target is Item):
    push_error('[ChargeMechanic] land: charge needs an Item target.')
    return
  var item: Item = delivery.target
  if item.is_gated():   # a gated item's bar is frozen — charge banks nothing
    return
  var applied: float = shift_cooldown(item, delivery.value)
  if is_zero_approx(applied):   # a full bar absorbs nothing — no event, no log entry
    return
  combat.bus.publish(EventBus.Event.APPLIED, id, delivery.source_actor,
      combat._source_item_of(delivery))
  if combat.combat_log != null:
    combat.combat_log.on_charge(combat._delivery_source_name(delivery),
        combat._delivery_source_side(delivery), combat._target_name(delivery.target),
        combat._target_side(delivery.target), applied, combat.timekeeper.sim_time)
