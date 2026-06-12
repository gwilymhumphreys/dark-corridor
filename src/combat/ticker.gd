class_name Ticker
extends RefCounted
## The shared accrual primitive (docs/systems/combat_model.md). An accumulator that fills toward a
## threshold (measured in sim-steps) by time-accrual (one per step) and/or
## event-pushes (a fraction of the bar), firing when it crosses. Composition,
## not inheritance — items / statuses / Deliveries OWN a Ticker, they are not
## subclasses of one.

var threshold: float = 1.0   # sim-steps to cross
var accum: float = 0.0


func _init(threshold_steps: float = 1.0) -> void:
  threshold = maxf(threshold_steps, 0.0)


## Build a cooldown/travel Ticker from a duration in seconds (rounds up to whole
## sim-steps). Zero seconds -> threshold 0 = instant (already crossed).
static func from_seconds(seconds: float) -> Ticker:
  return Ticker.new(ceil(seconds / Balance.STEP))


## Advance one sim-step of time-accrual; returns true if it crossed this step.
func step() -> bool:
  accum += 1.0
  return crossed()


## Event-push (the charges model): add a fraction of the bar. ~1.0 fills it.
func push(fraction: float) -> void:
  accum += fraction * threshold


func crossed() -> bool:
  return accum >= threshold


## Reset after firing — subtract the threshold, carrying any overflow so a fast
## cadence stays steady over a long fight (never below zero).
func reset() -> void:
  accum = maxf(accum - threshold, 0.0)


## 0..1 fill ratio, for the cooldown ring.
func progress() -> float:
  if threshold <= 0.0:
    return 1.0
  return clampf(accum / threshold, 0.0, 1.0)
