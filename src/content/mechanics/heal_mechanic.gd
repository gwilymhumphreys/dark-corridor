class_name HealMechanic
extends Mechanic
## Heal — the mechanic for restoring health (docs/systems/mechanics.md). Restores health up to
## maximum, then removes some poison, burn and bleed from the healed actor.

const ID := 'heal'


func _init() -> void:
  id = ID
  name_key = 'Heal'
  desc_key = 'Restores health.'   # PLACEHOLDER desc — owner writes
  icon = 'res://assets/icons/potions/alchemy_31_bigheal_flask.png'   # PLACEHOLDER icon
  status_id = ''


func color() -> Color:
  return Colours.HEAL


func land(delivery: Delivery, combat: CombatManager) -> void:
  if delivery.target is Actor:
    var healed: float = delivery.target.heal(delivery.value)
    combat.bus.publish(EventBus.Event.APPLIED, HealMechanic.ID, delivery.source_actor,
        combat._source_item_of(delivery))
    if combat.combat_log != null:
      combat.combat_log.on_heal(combat._delivery_source_name(delivery),
          combat._delivery_source_side(delivery), delivery.target.display_name,
          combat._side_of(delivery.target), healed, combat.timekeeper.sim_time)
    # A heal scrubs a fraction of the target's poison, burn and bleed (docs/systems/mechanics.md →
    # Heal). `delivery.value` is the FULL heal (including overheal), not the amount healed.
    var removed: float = floor(delivery.value * Balance.HEAL_CLEANSE_FRACTION)
    if removed > 0.0:
      StatusManager.reduce(delivery.target, PoisonMechanic.ID, removed)
      StatusManager.reduce(delivery.target, BurnMechanic.ID, removed)
      StatusManager.reduce(delivery.target, BleedMechanic.ID, removed)
