class_name ImpactRingDrawer
extends EffectDrawer
## The ring drawn where a delivery lands.


const IMPACT_DURATION: float = 0.22   # seconds an impact burst shows (render-time)
const IMPACT_RADIUS_START: float = 12.0
const IMPACT_RADIUS_END: float = 72.0
const IMPACT_WIDTH: float = 12.0      # ring thickness at the moment of the hit
const IMPACT_POINTS: int = 24


func duration() -> float:
  return IMPACT_DURATION


## A ring that snaps outward from the landing point and thins as it goes, in the delivery's colour
## (the same colour the firing item flashes, so the eye joins the two).
##
## PLACEHOLDER: a drawn circle standing in for a real impact animation.
func draw_effect(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float) -> void:
  var through: float = progress(age)
  if through < 0.0:
    return
  var eased: float = 1.0 - pow(1.0 - through, 3.0)   # fast out, then slow
  var radius: float = lerpf(IMPACT_RADIUS_START, IMPACT_RADIUS_END, eased)
  var width: float = maxf(lerpf(IMPACT_WIDTH, 1.0, eased), 1.0)
  canvas.draw_arc(point, radius, 0.0, TAU, IMPACT_POINTS, delivery.color, width)
