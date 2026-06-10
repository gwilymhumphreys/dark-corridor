class_name PoisonStatus
extends PeriodicStatus
## Poison — the stacked damage-over-time DoT. Ticks every interval for its stack count, decays a
## stack each tick, and is Mass fuel (PeriodicStatus). Stacks additively on reapply (base default).

const ID := 'poison'


func _init() -> void:
  id = ID
  name_key = 'Poison'
  color = Colours.STATUS_POISON
  tick_interval = Balance.POISON_TICK_INTERVAL
  damage_per_tick = Balance.POISON_DAMAGE_PER_TICK
