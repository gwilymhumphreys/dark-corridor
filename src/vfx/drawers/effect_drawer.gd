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


## A number from 0 to 1 fixed for one delivery and `salt`, so each hit keeps the same angle, flip
## and particle paths for as long as it shows.
static func fixed_random(delivery: Delivery, salt: int) -> float:
  return float(hash(delivery.get_instance_id() * 97 + salt) % 1000) / 1000.0


## Draw `texture` centred on the canvas's current origin, `size` pixels wide, keeping its shape.
static func draw_centred(canvas: CanvasItem, texture: Texture2D, size: float, modulate: Color) -> void:
  if size <= 0.0 or modulate.a <= 0.0:
    return
  var height: float = size * float(texture.get_height()) / float(texture.get_width())
  canvas.draw_texture_rect(texture, Rect2(-size * 0.5, -height * 0.5, size, height), false, modulate)


static func faded(colour: Color, alpha: float) -> Color:
  return Color(colour, colour.a * clampf(alpha, 0.0, 1.0))


func duration() -> float:
  return 0.0


func progress(age: float) -> float:
  if age < 0.0 or age >= duration():
    return -1.0
  return age / duration()


func draw_effect(_canvas: CanvasItem, _delivery: Delivery, _point: Vector2, _age: float) -> void:
  pass
