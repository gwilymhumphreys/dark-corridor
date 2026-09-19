class_name PoisonMechanic
extends Mechanic
## Poison — the mechanic for the stacked damage-over-time DoT (docs/systems/mechanics.md). Ticks
## every interval for its stack count, then loses a stack; does double damage to shield.

const ID := 'poison'


func _init() -> void:
  id = ID
  name_key = 'Poison'
  desc_key = 'Deals damage over time, losing a stack each tick.'   # PLACEHOLDER desc — owner writes
  icon = IconSlots.icon_for(ID)
  status_id = 'poison'


func color() -> Color:
  return Colours.POISON


func shield_multiplier() -> float:
  return Balance.SHIELD_MULTIPLIER_POISON
