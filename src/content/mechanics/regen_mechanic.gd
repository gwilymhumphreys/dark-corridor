class_name RegenMechanic
extends Mechanic
## Regen — the mechanic for the regenerating status (docs/plans/mechanics.md). Heals the holder
## every interval; never loses stacks, so it lasts the whole fight.

const ID := 'regen'


func _init() -> void:
  id = ID
  name_key = 'Regen'
  desc_key = 'Restores health over time, keeping its stacks for the whole fight.'   # PLACEHOLDER desc — owner writes
  icon = 'res://assets/icons/potions/alchemy_31_bigheal_flask.png'   # PLACEHOLDER icon
  status_id = 'regen'


func color() -> Color:
  return Colours.REGEN
