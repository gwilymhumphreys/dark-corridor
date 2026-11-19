class_name SlowStatus
extends TimedStatus
## Slow (decision #66): while it sits on an actor, that actor's item cooldown bars fill at
## `Balance.SLOW_RATE` times the normal rate. It has no stacks: a new application adds its seconds
## to the time left (TimedStatus). While the actor is also hasted, neither has an effect.

const ID := 'slow'


func _init() -> void:
  id = ID
  # The text is written once, on the mechanic.
  var mechanic: Mechanic = MechanicRegistry.get_mechanic(SlowMechanic.ID)
  name_key = mechanic.name_key
  desc_key = mechanic.desc_key
  icon = mechanic.icon
  color = Colours.DECHARGE


## No stacks: a reapplication only adds its seconds to the time left.
func reapply(_add_count: float, add_duration: float, src, new_flags: int) -> void:
  super(0.0, add_duration, src, new_flags)


func cooldown_rate(target) -> float:
  if StatusManager.has_status(target, HasteStatus.ID):
    return 1.0
  return Balance.SLOW_RATE
