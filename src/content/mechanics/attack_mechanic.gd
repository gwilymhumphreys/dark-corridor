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
  # The next step of docs/plans/mechanics.md fills this in; nothing calls it yet.
  pass
