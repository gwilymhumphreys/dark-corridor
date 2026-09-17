class_name PoisonStatus
extends PeriodicStatus
## Poison — the stacked damage-over-time DoT. Ticks every interval for its stack count, decays a
## stack each tick, and is Mass fuel (PeriodicStatus). Stacks additively on reapply (base default).

const ID := 'poison'


func _init() -> void:
  id = ID
  # Presentation is written once, in the mechanic (docs/plans/mechanics.md) — copy it here so the
  # combat log, status icons and combat summary keep reading the status's own fields.
  var mechanic: Mechanic = MechanicRegistry.get_mechanic(ID)
  name_key = mechanic.name_key
  desc_key = mechanic.desc_key
  icon = mechanic.icon
  color = Colours.POISON
  tick_interval = Balance.POISON_TICK_INTERVAL
  damage_per_tick = Balance.POISON_DAMAGE_PER_TICK
