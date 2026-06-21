class_name PeriodicStatus
extends StatusEffect
## Intermediate base for ticking damage-over-time statuses (Poison) — the old
## StatusDef.Shape.PERIODIC. Ticks on a fixed cadence, deals `count × damage_per_tick` to the
## holder, then decays one stack; expires when the stacks are spent. A stacked DoT is Mass fuel.
## Concrete DoTs set `tick_interval` + `damage_per_tick` in _init.

var tick_interval: float = 0.0
var damage_per_tick: float = 0.0


func setup(amount: float, dur: float, src, applied_flags: int) -> void:
  super(amount, dur, src, applied_flags)
  ticker = Ticker.from_seconds(tick_interval)


## Per tick: damage the holder (actors only — items have no HP, so a DoT authored onto an item
## ticks down harmlessly), decay a stack, expire when drained. Carries the applying flags so an
## unblockable DoT bypasses block per tick (#5).
func on_step(target, ctx) -> bool:
  if ticker.step():
    if target is Actor:
      target.take_damage(count * damage_per_tick, flags)
    count -= 1.0
    ticker.reset()
    return count <= 0.0
  return false


func is_fuel() -> bool:
  return true
