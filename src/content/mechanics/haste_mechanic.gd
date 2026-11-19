class_name HasteMechanic
extends Mechanic
## Haste (decision #66): an on-or-off state on an actor for a number of seconds, during which its
## item cooldown bars fill faster (`HasteStatus`). An effect's value is its seconds, like charge.

const ID := 'haste'


func _init() -> void:
  id = ID
  name_key = 'Haste'
  desc_key = 'Your items charge faster for a time.'   # PLACEHOLDER desc — owner writes
  icon = IconSlots.icon_for(ID)
  status_id = HasteStatus.ID


func color() -> Color:
  return Colours.CHARGE


func status_count(_delivery: Delivery) -> float:
  return 1.0


func status_duration(delivery: Delivery) -> float:
  return delivery.value
