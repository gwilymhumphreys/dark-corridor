class_name SlowMechanic
extends Mechanic
## Slow (decision #66): the opposite of haste. An on-or-off state on an actor for a number of
## seconds, during which its item cooldown bars fill more slowly (`SlowStatus`). An effect's value
## is its seconds, like decharge.

const ID := 'slow'


func _init() -> void:
  id = ID
  name_key = 'Slow'
  desc_key = 'Items charge more slowly for a time.'   # PLACEHOLDER desc — owner writes
  icon = IconSlots.icon_for(ID)
  status_id = SlowStatus.ID


func color() -> Color:
  return Colours.DECHARGE


func status_count(_delivery: Delivery) -> float:
  return 1.0


func status_duration(delivery: Delivery) -> float:
  return delivery.value
