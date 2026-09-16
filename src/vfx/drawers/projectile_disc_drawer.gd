class_name ProjectileDiscDrawer
extends EffectDrawer
## The disc drawn for a delivery in flight.


const PROJ_RADIUS := 14.0


## The driver computes the position along the path, so the disc does not use its age.
func draw_effect(canvas: CanvasItem, delivery: Delivery, point: Vector2, _age: float) -> void:
  canvas.draw_circle(point, PROJ_RADIUS, delivery.color)
