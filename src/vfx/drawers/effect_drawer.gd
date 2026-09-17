class_name EffectDrawer
extends RefCounted
## The base class every effect drawer extends. It holds no state, because everything the wall
## draws is a pure function of render time.


const SCATTER_RADIUS: float = 44.0   # how far a landing point can be nudged from the target centre


## A small fixed nudge for one delivery's landing point, so several hits on the same target do not
## stack their rings and numbers in one spot. It is derived from the delivery's own identity rather
## than drawn each frame, so the effect stays where it landed instead of jittering, and it touches
## no game state — the autotest draws nothing, so seeded runs are unchanged.
static func scatter_offset(delivery: Delivery) -> Vector2:
  var id: int = delivery.get_instance_id()
  var angle: float = float(hash(id) % 3600) / 3600.0 * TAU
  var distance: float = float(hash(id * 31 + 7) % 1000) / 1000.0 * SCATTER_RADIUS
  return Vector2(cos(angle), sin(angle)) * distance


func duration() -> float:
  return 0.0


func progress(age: float) -> float:
  if age < 0.0 or age >= duration():
    return -1.0
  return age / duration()


func draw_effect(_canvas: CanvasItem, _delivery: Delivery, _point: Vector2, _age: float) -> void:
  pass
