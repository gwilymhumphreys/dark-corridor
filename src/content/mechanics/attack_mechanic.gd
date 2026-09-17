class_name AttackMechanic
extends Mechanic
## Attack — the mechanic for a direct hit from an item or potion (docs/plans/mechanics.md).
## Deals damage to the target.

const ID := 'attack'


func _init() -> void:
  id = ID
  name_key = 'Attack'
  desc_key = 'Deals damage to the target.'   # PLACEHOLDER desc — owner writes
  icon = 'res://assets/icons/items/skill_strong_attack_nb.png'   # PLACEHOLDER icon
  status_id = ''


func color() -> Color:
  return Colours.ATTACK


func land(delivery: Delivery, combat: CombatManager) -> void:
  if delivery.target is Actor:   # damage/heal are actor-targeted; item shapes carry statuses
    var dealt: float = delivery.target.take_damage(delivery.value, delivery.flags, AttackMechanic.ID)
    combat.bus.publish(EventBus.Event.APPLIED, AttackMechanic.ID, delivery.source_actor,
        combat._source_item_of(delivery))
    if combat.combat_log != null:
      # `delivery.value` is the GROSS hit (pre-shield); `dealt` is the NET HP lost — log both
      # (gross = the threat metric, survives a full shield; net = what HP actually did).
      combat.combat_log.on_damage(combat._delivery_source_name(delivery),
          combat._delivery_source_side(delivery), delivery.target.display_name,
          combat._side_of(delivery.target), dealt, combat.timekeeper.sim_time, delivery.value)
    # Bleed (and any other attack-triggered status) cashes out on the hit — after the damage
    # resolves, and only if the target survived it (docs/plans/mechanics.md → Bleed).
    if delivery.target.is_alive():
      combat._on_holder_attacked(delivery.target)
