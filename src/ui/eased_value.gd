class_name EasedValue
extends RefCounted
## A number on screen that moves to each new value over `duration` seconds, easing out, instead of
## jumping. A change that arrives mid-move starts from the value shown at that moment. The owner calls
## `step` every frame with the real value and shows what it returns (docs/systems/ui_layout.md →
## Changing numbers).

const DEFAULT_DURATION: float = 0.3

## Seconds a move takes. Read when a new target arrives, so a caller can set it per change.
var duration: float = DEFAULT_DURATION
var from: float = 0.0
var to: float = 0.0
var elapsed: float = 0.0


func _init(duration_value: float = DEFAULT_DURATION) -> void:
  duration = duration_value
  elapsed = duration


## Show `value` at once, with no move.
func snap(value: float) -> void:
  from = value
  to = value
  elapsed = duration


## Move on by `delta` seconds towards `target` and return the value to show.
func step(target: float, delta: float) -> float:
  if not is_equal_approx(target, to):
    from = shown()
    to = target
    elapsed = 0.0
  elapsed = minf(elapsed + delta, duration)
  return shown()


## The value to show now.
func shown() -> float:
  if duration <= 0.0:
    return to
  var through: float = elapsed / duration
  return lerpf(from, to, 1.0 - pow(1.0 - through, 2.0))
