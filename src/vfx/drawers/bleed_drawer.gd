class_name BleedDrawer
extends EffectDrawer
## The effect drawn for bleed (docs/systems/vfx_driver.md). When bleed is applied, a splat of blood
## bursts where it lands and drops spray on in the direction the projectile was travelling. When
## bleed deals damage (a visual-only delivery, when its holder is hit by an attack), a smaller splat
## and a spurt of drops thrown upward that fall back down. The splat is a cluster of round drops
## around a larger one. Flying drops are stretched along the way they are moving. Every drop is the
## same soft round image from Kenney's Particle Pack (assets/vfx/status/blob.png), placed as a pure
## function of age, with its path fixed per delivery.
##
## TRIAL: one of the looks being tried for bleed.

const BLOB: Texture2D = preload('res://assets/vfx/status/blob.png')

const DURATION: float = 0.7           # render-time seconds both effects show
const SPLAT_GROW: float = 0.1         # fraction of the duration the splat takes to reach full size
const APPLY_SPLAT_RADIUS: float = 70.0   # pixels from the landing point the splat's drops reach
const TICK_SPLAT_RADIUS: float = 45.0
const SPLAT_CENTRE_SIZE: float = 1.3  # the splat's middle drop, as a multiple of its radius
const SPLAT_DROPS: int = 10
const APPLY_DROPS: int = 9
const TICK_DROPS: int = 7
const APPLY_SPRAY: float = 55.0       # degrees a drop may leave away from the direction of travel
const TICK_SPRAY: float = 60.0        # degrees a spurting drop may leave away from straight up
const DROP_SPEED_MIN: float = 220.0   # pixels a second a drop starts at
const DROP_SPEED_MAX: float = 460.0
const GRAVITY: float = 1500.0         # pixels a second, each second, a drop falls faster
const DROP_SIZE_MIN: float = 18.0
const DROP_SIZE_MAX: float = 34.0
const DROP_STRETCH: float = 0.0015    # how much longer a drop is drawn per pixel a second of speed
const HIGHLIGHT_STRENGTH: float = 0.25   # how strongly the off-white glint shows on a drop
const LIFT: float = 0.0               # how much lighter than the bleed colour blood is drawn


func duration() -> float:
  return DURATION


## Draw the bleed with the direction the projectile was travelling as it landed. A damage tick
## ignores the direction: its drops spurt upward.
func draw_hit(canvas: CanvasItem, delivery: Delivery, point: Vector2, direction: Vector2, age: float) -> void:
  var through: float = progress(age)
  if through < 0.0:
    return
  var tick: bool = delivery.visual_only
  var colour: Color = delivery.color.lightened(LIFT)
  _draw_splat(canvas, delivery, point, TICK_SPLAT_RADIUS if tick else APPLY_SPLAT_RADIUS, through, colour)
  var heading: Vector2 = Vector2.UP if tick else direction.normalized()
  if heading == Vector2.ZERO:
    heading = Vector2.RIGHT
  var spray: float = deg_to_rad(TICK_SPRAY if tick else APPLY_SPRAY)
  var count: int = TICK_DROPS if tick else APPLY_DROPS
  for i in count:
    _draw_drop(canvas, delivery, point, heading, spray, age, 400 + i * 8, colour)
  canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


func draw_effect(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float) -> void:
  draw_hit(canvas, delivery, point, Vector2.RIGHT, age)


# A large drop in the middle and smaller ones scattered around it, all bursting outward to full
# size quickly, then fading.
func _draw_splat(canvas: CanvasItem, delivery: Delivery, point: Vector2, radius: float, through: float, colour: Color) -> void:
  var grown: float = 1.0 - pow(1.0 - clampf(through / SPLAT_GROW, 0.0, 1.0), 2.0)
  var alpha: float = pow(1.0 - through, 1.5)
  canvas.draw_set_transform(point, 0.0, Vector2.ONE)
  draw_centred(canvas, BLOB, radius * SPLAT_CENTRE_SIZE * lerpf(0.5, 1.0, grown), faded(colour, alpha))
  for i in SPLAT_DROPS:
    var salt: int = 600 + i * 8
    var angle: float = (float(i) + fixed_random(delivery, salt)) / float(SPLAT_DROPS) * TAU
    var reach: float = radius * lerpf(0.4, 1.0, fixed_random(delivery, salt + 1)) * grown
    var size: float = radius * lerpf(0.2, 0.55, fixed_random(delivery, salt + 2))
    canvas.draw_set_transform(point + Vector2.from_angle(angle) * reach, 0.0, Vector2.ONE)
    draw_centred(canvas, BLOB, size, faded(colour, alpha))


# One drop leaves the landing point at a fixed random angle and speed, falls under gravity,
# stretches along the way it is moving, and shrinks and fades out.
func _draw_drop(canvas: CanvasItem, delivery: Delivery, point: Vector2, heading: Vector2, spray: float, age: float, salt: int, colour: Color) -> void:
  var start: float = fixed_random(delivery, salt) * DURATION * 0.15
  var life: float = (age - start) / (DURATION - start)
  if life < 0.0 or life >= 1.0:
    return
  var t: float = age - start
  var speed: float = lerpf(DROP_SPEED_MIN, DROP_SPEED_MAX, fixed_random(delivery, salt + 1))
  var velocity: Vector2 = heading.rotated(lerpf(-spray, spray, fixed_random(delivery, salt + 2))) * speed
  var place: Vector2 = point + velocity * t + Vector2.DOWN * 0.5 * GRAVITY * t * t
  var moving: Vector2 = velocity + Vector2.DOWN * GRAVITY * t
  var size: float = lerpf(DROP_SIZE_MIN, DROP_SIZE_MAX, fixed_random(delivery, salt + 3)) * lerpf(1.0, 0.5, life)
  var alpha: float = 1.0 - pow(life, 3.0)
  var stretch: float = 1.0 + moving.length() * DROP_STRETCH
  canvas.draw_set_transform(place, moving.angle(), Vector2(stretch, 1.0))
  draw_centred(canvas, BLOB, size, faded(colour, alpha))
  canvas.draw_set_transform(place + moving.normalized() * size * 0.2 + Vector2(-0.12, -0.12) * size, moving.angle(), Vector2(stretch, 1.0))
  draw_centred(canvas, BLOB, size * 0.3, faded(Colours.UI_TEXT, HIGHLIGHT_STRENGTH * alpha))
