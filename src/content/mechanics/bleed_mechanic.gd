class_name BleedMechanic
extends Mechanic
## Bleed — the mechanic for the wound that cashes out when its holder is hit by an attack
## (docs/systems/mechanics.md). Each time the holder is hit by an attack, it takes damage equal
## to its stacks and loses a stack; does half damage to shield.

const ID := 'bleed'


func _init() -> void:
  id = ID
  name_key = 'Bleed'
  desc_key = 'Each time the holder is hit by an attack, it takes damage and loses a stack.'   # PLACEHOLDER desc — owner writes
  icon = IconSlots.icon_for(ID)
  status_id = 'bleed'


func color() -> Color:
  return Colours.BLEED


func shield_multiplier() -> float:
  return Balance.SHIELD_MULTIPLIER_BLEED
