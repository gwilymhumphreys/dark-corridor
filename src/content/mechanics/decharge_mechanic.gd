class_name DechargeMechanic
extends Mechanic
## Decharge — takes seconds of progress away from the target item's cooldown bar, so it fires
## later (docs/systems/mechanics.md). It acts on an ITEM, not an actor.

const ID := 'decharge'


func _init() -> void:
  id = ID
  name_key = 'Decharge'
  desc_key = 'Empties that many seconds of an item\'s cooldown bar.'   # PLACEHOLDER desc — owner writes
  icon = 'res://assets/icons/statuses/skill_shackle_nb.png'   # PLACEHOLDER icon


func color() -> Color:
  return Colours.DECHARGE


func land(delivery: Delivery, combat: CombatManager) -> void:
  if not (delivery.target is Item):
    push_error('[DechargeMechanic] land: decharge needs an Item target.')
    return
  var item: Item = delivery.target
  if item.is_gated():   # a gated item's bar is frozen — decharge banks nothing
    return
  var applied: float = ChargeMechanic.shift_cooldown(item, -delivery.value)
  if is_zero_approx(applied):   # an empty bar absorbs nothing — no event, no log entry
    return
  combat.bus.publish(EventBus.Event.APPLIED, id, delivery.source_actor,
      combat._source_item_of(delivery))
  if combat.combat_log != null:
    combat.combat_log.on_charge(combat._delivery_source_name(delivery),
        combat._delivery_source_side(delivery), combat._target_name(delivery.target),
        combat._target_side(delivery.target), applied, combat.timekeeper.sim_time)
