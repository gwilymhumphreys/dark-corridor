class_name BurnDrawer
extends EffectDrawer
## The effect drawn for burn (docs/systems/vfx_driver.md). When burn is applied, a burst of fire
## flares where it lands, flame tongues spring up around it, and embers rise. When burn deals damage
## (a tick's visual-only delivery), a few smaller flame tongues lick up from the holder, throwing off
## embers. A tongue flickers by switching between two flame images and changing its width over time,
## and has a paler, hotter core. The images are still images from Kenney's Particle Pack
## (assets/vfx/status/), placed as a pure function of age, with each tongue and ember fixed per
## delivery.
##
## TRIAL: one of the looks being tried for burn. `VfxDriver.status_sprites` switches between this
## and the placeholder ring.

const FLAMES: Array[Texture2D] = [
  preload('res://assets/vfx/status/flame_thin.png'),
  preload('res://assets/vfx/status/flame_curl.png'),
  preload('res://assets/vfx/status/flame_tall.png'),
  preload('res://assets/vfx/status/flame_wide.png'),
]
const BURST: Texture2D = preload('res://assets/vfx/status/fire_burst.png')
const BLOB: Texture2D = preload('res://assets/vfx/status/blob.png')

const APPLY_DURATION: float = 0.75    # render-time seconds the flare shows
const TICK_DURATION: float = 0.7      # render-time seconds the flames of a damage tick show
const BURST_SIZE_START: float = 70.0
const BURST_SIZE_END: float = 230.0
const BURST_FADE: float = 0.55        # fraction of the duration the burst takes to fade out
const APPLY_TONGUES: int = 5
const TICK_TONGUES_MIN: int = 2
const TICK_TONGUES_MAX: int = 4
const TONGUE_HEIGHT_MIN: float = 90.0 # pixels tall a flame tongue is at its highest
const TONGUE_HEIGHT_MAX: float = 170.0
const TONGUE_SPREAD: float = 60.0     # pixels from the landing point a tongue's base can be
const TONGUE_LIFT: float = 30.0       # pixels a tongue rises as it dies down
const TONGUE_LEAN: float = 12.0       # degrees a tongue may lean to either side
const TONGUE_PEAK: float = 0.25       # fraction of a tongue's life it takes to reach full height
const FLICKER_RATE: float = 14.0      # times a second a tongue switches flame image
const CORE_SIZE: float = 0.55         # the hot core's size as a fraction of its tongue
const CORE_LIFT: float = 0.55         # how much paler than the burn colour the hot core is
const APPLY_EMBERS: int = 8
const TICK_EMBERS: int = 4
const EMBER_SIZE_MIN: float = 7.0
const EMBER_SIZE_MAX: float = 14.0
const EMBER_SPEED_MIN: float = 120.0  # pixels a second an ember rises
const EMBER_SPEED_MAX: float = 280.0
const EMBER_DRIFT: float = 50.0       # pixels an ember may drift sideways by the end


func duration() -> float:
  return APPLY_DURATION


func draw_effect(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float) -> void:
  if age < 0.0:
    return
  var tick: bool = delivery.visual_only
  var length: float = TICK_DURATION if tick else APPLY_DURATION
  if age >= length:
    return
  if not tick:
    _draw_burst(canvas, delivery, point, age / length)
  var count: int = tick_tongues(delivery) if tick else APPLY_TONGUES
  var scale: float = 0.75 if tick else 1.0
  for i in count:
    var start: float = lerpf(0.0, 0.25, float(i) / float(count)) * length
    _draw_tongue(canvas, delivery, point, age, 700 + i * 8, start, length, scale)
  for i in (TICK_EMBERS if tick else APPLY_EMBERS):
    _draw_ember(canvas, delivery, point, age, 800 + i * 8, length)
  canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## How many flame tongues a damage tick raises: more for bigger ticks, on a logarithmic curve.
static func tick_tongues(delivery: Delivery) -> int:
  var extra: int = int(log(maxf(delivery.value, 1.0)) / log(6.0))
  return clampi(TICK_TONGUES_MIN + extra, TICK_TONGUES_MIN, TICK_TONGUES_MAX)


func _draw_burst(canvas: CanvasItem, delivery: Delivery, point: Vector2, through: float) -> void:
  var spread: float = 1.0 - pow(1.0 - clampf(through / BURST_FADE, 0.0, 1.0), 3.0)
  var alpha: float = 1.0 - clampf(through / BURST_FADE, 0.0, 1.0)
  canvas.draw_set_transform(point, fixed_random(delivery, 7) * TAU, Vector2.ONE)
  var size: float = lerpf(BURST_SIZE_START, BURST_SIZE_END, spread)
  # Drawn twice over itself: the image is mostly thin speckle, which reads as brown smoke when drawn once.
  draw_centred(canvas, BURST, size, faded(delivery.color.lightened(0.15), alpha))
  draw_centred(canvas, BURST, size * 0.9, faded(delivery.color.lightened(0.15), alpha))
  draw_centred(canvas, BURST, size * CORE_SIZE, faded(delivery.color.lightened(CORE_LIFT), alpha))


# One tongue of flame standing on a base near the landing point. It shoots up to full height
# quickly, then dies down while lifting off its base, leaning and flickering all the while.
func _draw_tongue(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float, salt: int, start: float, end: float, scale: float) -> void:
  var life: float = (age - start) / (end - start)
  if life < 0.0 or life >= 1.0:
    return
  var rising: float = 1.0 - pow(1.0 - clampf(life / TONGUE_PEAK, 0.0, 1.0), 2.0)
  var dying: float = 1.0 - pow(clampf((life - TONGUE_PEAK) / (1.0 - TONGUE_PEAK), 0.0, 1.0), 1.5)
  var height: float = lerpf(TONGUE_HEIGHT_MIN, TONGUE_HEIGHT_MAX, fixed_random(delivery, salt)) * scale * rising * dying
  var phase: float = fixed_random(delivery, salt + 1)
  var flicker: float = 1.0 + 0.15 * sin((age + phase) * 37.0) + 0.08 * sin((age + phase) * 61.0)
  var first: int = int(fixed_random(delivery, salt + 2) * FLAMES.size())
  var frame: int = int((age + phase) * FLICKER_RATE) % 2
  var texture: Texture2D = FLAMES[(first + frame) % FLAMES.size()]
  var offset: Vector2 = Vector2(lerpf(-1.0, 1.0, fixed_random(delivery, salt + 3)), lerpf(-0.2, 0.6, fixed_random(delivery, salt + 4))) * TONGUE_SPREAD
  var base: Vector2 = point + offset + Vector2.UP * TONGUE_LIFT * life
  var lean: float = deg_to_rad(lerpf(-TONGUE_LEAN, TONGUE_LEAN, fixed_random(delivery, salt + 5)) + 4.0 * sin((age + phase) * 23.0))
  canvas.draw_set_transform(base, lean, Vector2.ONE)
  _draw_standing(canvas, texture, height, flicker, delivery.color)
  _draw_standing(canvas, texture, height * CORE_SIZE, flicker, delivery.color.lightened(CORE_LIFT))


# One ember: a small glowing speck that rises from near the landing point, drifting sideways and
# fading as it goes.
func _draw_ember(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float, salt: int, length: float) -> void:
  var start: float = fixed_random(delivery, salt) * length * 0.4
  var life: float = (age - start) / (length - start)
  if life < 0.0 or life >= 1.0:
    return
  var t: float = age - start
  var speed: float = lerpf(EMBER_SPEED_MIN, EMBER_SPEED_MAX, fixed_random(delivery, salt + 1))
  var drift: float = lerpf(-EMBER_DRIFT, EMBER_DRIFT, fixed_random(delivery, salt + 2)) * life
  var wobble: float = sin((t + fixed_random(delivery, salt + 3)) * 19.0) * 6.0
  var from: Vector2 = Vector2(lerpf(-1.0, 1.0, fixed_random(delivery, salt + 4)) * TONGUE_SPREAD, 0.0)
  var place: Vector2 = point + from + Vector2(drift + wobble, -speed * t)
  var size: float = lerpf(EMBER_SIZE_MIN, EMBER_SIZE_MAX, fixed_random(delivery, salt + 5)) * lerpf(1.0, 0.4, life)
  var alpha: float = 1.0 - pow(life, 2.0)
  canvas.draw_set_transform(place, 0.0, Vector2.ONE)
  draw_centred(canvas, BLOB, size, faded(delivery.color.lightened(0.2), alpha))
  draw_centred(canvas, BLOB, size * 0.5, faded(delivery.color.lightened(CORE_LIFT + 0.2), alpha))


# Draw `texture` standing on the canvas's current origin: its bottom edge centred there, `height`
# pixels tall, and its width scaled by `widen`.
static func _draw_standing(canvas: CanvasItem, texture: Texture2D, height: float, widen: float, modulate: Color) -> void:
  if height <= 0.0 or modulate.a <= 0.0:
    return
  var width: float = height * float(texture.get_width()) / float(texture.get_height()) * widen
  canvas.draw_texture_rect(texture, Rect2(-width * 0.5, -height, width, height), false, modulate)
