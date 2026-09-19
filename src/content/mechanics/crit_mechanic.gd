class_name CritMechanic
extends Mechanic
## Crit — the mechanic for an item's crit chance (docs/systems/mechanics.md). It is never
## delivered: the Combat manager rolls it at fire time and multiplies that fire's mechanic
## deliveries by Balance.CRIT_MULTIPLIER. It has no `land` override (the base no-ops on an
## empty `status_id`).

const ID := 'crit'


func _init() -> void:
  id = ID
  name_key = 'Crit'
  desc_key = 'A chance to double the values of this item\'s effects when it fires.'   # PLACEHOLDER desc — owner writes
  icon = IconSlots.icon_for(ID)


func color() -> Color:
  return Colours.CRIT
