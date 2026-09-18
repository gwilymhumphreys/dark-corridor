class_name RegenStatus
extends StatusEffect
## Regen — the regenerating status (docs/systems/mechanics.md). Every interval, heals the holder
## for its stack count; never loses a stack, so it lasts the whole fight (on_step always returns
## false). Not Mass fuel (the base is_fuel). Stacks additively on reapply (base default).

const ID := 'regen'


func _init() -> void:
  id = ID
  # Presentation is written once, in the mechanic (docs/systems/mechanics.md) — copy it here so the
  # combat log, status icons and combat summary keep reading the status's own fields.
  var mechanic: Mechanic = MechanicRegistry.get_mechanic(ID)
  name_key = mechanic.name_key
  desc_key = mechanic.desc_key
  icon = mechanic.icon
  color = Colours.REGEN


func setup(amount: float, dur: float, src, applied_flags: int) -> void:
  super(amount, dur, src, applied_flags)
  ticker = Ticker.from_seconds(Balance.REGEN_TICK_INTERVAL)


## Per tick: heal the holder (actors only — items have no HP, so a regen authored onto an item
## ticks down harmlessly) and reset the ticker. Never loses stacks, never expires.
func on_step(target, ctx) -> bool:
  if ticker.step():
    if target is Actor:
      target.heal(count * Balance.REGEN_HEAL_PER_TICK)
    ticker.reset()
  return false
