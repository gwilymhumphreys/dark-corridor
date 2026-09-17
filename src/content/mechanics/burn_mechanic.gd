class_name BurnMechanic
extends Mechanic
## Burn — the mechanic for the burning damage-over-time DoT (docs/plans/mechanics.md). The same
## as poison with its own constants, except it does half damage to shield.

const ID := 'burn'


func _init() -> void:
  id = ID
  name_key = 'Burn'
  desc_key = 'Deals damage over time, losing a stack each tick.'   # PLACEHOLDER desc — owner writes
  icon = 'res://assets/icons/keywords/skill_absorbing_fire_nb.png'   # PLACEHOLDER icon
  status_id = 'burn'


func color() -> Color:
  return Colours.BURN


func shield_multiplier() -> float:
  return Balance.SHIELD_MULTIPLIER_BURN
