class_name RegenMechanic
extends Mechanic
## Regen — the mechanic for the regenerating status (docs/systems/mechanics.md). Heals the holder
## every interval; never loses stacks, so it lasts the whole fight.

const ID := 'regen'


func _init() -> void:
  id = ID
  name_key = 'Regen'
  desc_key = 'Restores health over time, keeping its stacks for the whole fight.'   # PLACEHOLDER desc — owner writes
  icon = IconSlots.icon_for(ID)
  status_id = 'regen'


func color() -> Color:
  return Colours.REGEN
