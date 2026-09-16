class_name EffectDrawer
extends RefCounted
## The base class every effect drawer extends. It holds no state, because everything the wall
## draws is a pure function of render time.


func duration() -> float:
  return 0.0


func progress(age: float) -> float:
  if age < 0.0 or age >= duration():
    return -1.0
  return age / duration()


func draw_effect(_canvas: CanvasItem, _delivery: Delivery, _point: Vector2, _age: float) -> void:
  pass
