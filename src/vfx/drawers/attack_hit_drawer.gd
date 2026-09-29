class_name AttackHitDrawer
extends EffectDrawer
## The effect drawn where an attack lands (docs/systems/vfx_driver.md): a slash for a blade and an
## impact for anything else, chosen by the firing item's `attack_sound` ('blade' draws the slash).
## Both are still images from Kenney's Particle Pack (assets/vfx/attack/), moved, grown and faded
## here as a pure function of age. Each image has a white base, tinted with the delivery's colour,
## and a white core holding its brightest part, tinted with the off-white text colour.
##
## TRIAL: one of the looks being tried for attacks. `VfxDriver.attack_sprites` switches between this
## and the placeholder ring.

const SLASH: Texture2D = preload('res://assets/vfx/attack/slash_03.png')
const SLASH_CORE: Texture2D = preload('res://assets/vfx/attack/slash_03_core.png')
const STAR: Texture2D = preload('res://assets/vfx/attack/star_07.png')
const STAR_CORE: Texture2D = preload('res://assets/vfx/attack/star_07_core.png')
const RING: Texture2D = preload('res://assets/vfx/attack/circle_02.png')
const RING_CORE: Texture2D = preload('res://assets/vfx/attack/circle_02_core.png')
const DEBRIS: Texture2D = preload('res://assets/vfx/attack/dirt_01.png')

const SLASH_DURATION: float = 0.26    # render-time seconds a slash shows
const SLASH_LENGTH: float = 300.0     # pixels from one end of the slash to the other
const SLASH_THICKEN: float = 1.8      # how much wider than the image's own shape the slash is drawn
const SLASH_SWEEP: float = 0.35       # fraction of the duration the slash takes to draw across
const SLASH_TILT: float = 20.0        # degrees a slash may turn away from the direction of travel
const SLASH_CORE_STRENGTH: float = 0.45   # how strongly the off-white centre shows over the attack colour
const SLASH_PUSH: float = 20.0        # pixels the slash moves along the direction of travel

const IMPACT_DURATION: float = 0.3    # render-time seconds an impact shows
const STAR_SIZE: float = 210.0        # pixels across the flash at its largest
const STAR_GROW: float = 0.2          # fraction of the duration the flash takes to reach full size
const RING_SIZE_START: float = 40.0
const RING_SIZE_END: float = 240.0
const DEBRIS_SIZE_START: float = 90.0
const DEBRIS_SIZE_END: float = 190.0


func duration() -> float:
  return IMPACT_DURATION


## Draw the hit with the direction the projectile was travelling as it landed. `draw_effect` without
## a direction treats the hit as travelling to the right.
func draw_hit(canvas: CanvasItem, delivery: Delivery, point: Vector2, direction: Vector2, age: float) -> void:
  if is_blade(delivery):
    _draw_slash(canvas, delivery, point, direction, age)
  else:
    _draw_impact(canvas, delivery, point, age)
  canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


func draw_effect(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float) -> void:
  draw_hit(canvas, delivery, point, Vector2.RIGHT, age)


static func is_blade(delivery: Delivery) -> bool:
  return delivery.source is Item and delivery.source.def != null and delivery.source.def.attack_sound == 'blade'


## A number from 0 to 1 fixed for one delivery and `salt`, so each hit keeps the same angle and flip
## for as long as it shows.
static func fixed_random(delivery: Delivery, salt: int) -> float:
  return float(hash(delivery.get_instance_id() * 97 + salt) % 1000) / 1000.0


# The crescent draws across from one end to the other, pushing a little along the direction of
# travel, then fades. The image's curve bulges towards +x, so +x is turned to face the direction of
# travel; half the slashes are mirrored so they sweep the other way.
func _draw_slash(canvas: CanvasItem, delivery: Delivery, point: Vector2, direction: Vector2, age: float) -> void:
  if age < 0.0 or age >= SLASH_DURATION:
    return
  var through: float = age / SLASH_DURATION
  var sweep: float = 1.0 - pow(1.0 - clampf(through / SLASH_SWEEP, 0.0, 1.0), 3.0)
  var fade: float = 1.0 if through < SLASH_SWEEP else pow(1.0 - (through - SLASH_SWEEP) / (1.0 - SLASH_SWEEP), 1.5)
  var tilt: float = deg_to_rad(lerpf(-SLASH_TILT, SLASH_TILT, fixed_random(delivery, 1)))
  var mirror: float = 1.0 if fixed_random(delivery, 2) < 0.5 else -1.0
  var heading: Vector2 = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
  var centre: Vector2 = point + heading * lerpf(-SLASH_PUSH * 0.5, SLASH_PUSH * 0.5, through)
  var grow: float = lerpf(0.9, 1.1, through)
  canvas.draw_set_transform(centre, heading.angle() + tilt, Vector2(grow, grow * mirror))
  var height: float = SLASH_LENGTH
  var width: float = height * float(SLASH.get_width()) / float(SLASH.get_height()) * SLASH_THICKEN
  var shown: Rect2 = Rect2(-width * 0.5, -height * 0.5, width, height * sweep)
  var source: Rect2 = Rect2(0.0, 0.0, SLASH.get_width(), SLASH.get_height() * sweep)
  canvas.draw_texture_rect_region(SLASH, shown, source, _faded(delivery.color, fade))
  canvas.draw_texture_rect_region(SLASH_CORE, shown, source, _faded(Colours.UI_TEXT, fade * SLASH_CORE_STRENGTH))


# A ring spreads out behind a burst of debris, and a sharp flash grows fast on top of both, then
# everything fades. The flash and debris are turned by a fixed random angle per hit.
func _draw_impact(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float) -> void:
  var through: float = progress(age)
  if through < 0.0:
    return
  var spread: float = 1.0 - pow(1.0 - through, 3.0)
  var colour: Color = delivery.color
  canvas.draw_set_transform(point, 0.0, Vector2.ONE)
  _draw_centred(canvas, RING, lerpf(RING_SIZE_START, RING_SIZE_END, spread), _faded(colour, 0.8 * pow(1.0 - through, 2.0)))
  _draw_centred(canvas, RING_CORE, lerpf(RING_SIZE_START, RING_SIZE_END, spread), _faded(Colours.UI_TEXT, 0.6 * pow(1.0 - through, 2.0)))
  canvas.draw_set_transform(point, fixed_random(delivery, 3) * TAU, Vector2.ONE)
  _draw_centred(canvas, DEBRIS, lerpf(DEBRIS_SIZE_START, DEBRIS_SIZE_END, spread), _faded(colour, 0.7 * pow(1.0 - through, 3.0)))
  var star_size: float
  if through < STAR_GROW:
    star_size = STAR_SIZE * (1.0 - pow(1.0 - through / STAR_GROW, 2.0))
  else:
    star_size = STAR_SIZE * lerpf(1.0, 0.7, (through - STAR_GROW) / (1.0 - STAR_GROW))
  var star_fade: float = clampf(1.0 - (through - STAR_GROW) / (0.6 - STAR_GROW), 0.0, 1.0)
  canvas.draw_set_transform(point, deg_to_rad(lerpf(-20.0, 20.0, fixed_random(delivery, 4))), Vector2.ONE)
  _draw_centred(canvas, STAR, star_size, _faded(colour, star_fade))
  _draw_centred(canvas, STAR_CORE, star_size, _faded(Colours.UI_TEXT, star_fade))


static func _draw_centred(canvas: CanvasItem, texture: Texture2D, size: float, modulate: Color) -> void:
  if size <= 0.0 or modulate.a <= 0.0:
    return
  var height: float = size * float(texture.get_height()) / float(texture.get_width())
  canvas.draw_texture_rect(texture, Rect2(-size * 0.5, -height * 0.5, size, height), false, modulate)


static func _faded(colour: Color, alpha: float) -> Color:
  return Color(colour, colour.a * clampf(alpha, 0.0, 1.0))
