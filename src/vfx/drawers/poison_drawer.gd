class_name PoisonDrawer
extends EffectDrawer
## The effect drawn for poison (docs/systems/vfx_driver.md). When poison is applied, a splash of
## green goo: a puff, blobs thrown outward that sag as they slow, and bubbles that rise and pop.
## When poison deals damage (a tick's visual-only delivery), a few small bubbles rise from the
## holder and pop. Every blob and bubble is a still image from Kenney's Particle Pack
## (assets/vfx/status/) placed as a pure function of age, with its path fixed per delivery.
##
## TRIAL: one of the looks being tried for poison.

const BUBBLE: Texture2D = preload('res://assets/vfx/status/bubble.png')
const BLOB: Texture2D = preload('res://assets/vfx/status/blob.png')
const PUFF: Texture2D = preload('res://assets/vfx/status/puff.png')

const APPLY_DURATION: float = 0.8     # render-time seconds the splash shows
const TICK_DURATION: float = 0.9      # render-time seconds the bubbles of a damage tick show
const POP_DURATION: float = 0.07      # render-time seconds a bubble takes to pop

const PUFF_SIZE_START: float = 70.0
const PUFF_SIZE_END: float = 210.0
const SPLASH_BLOBS: int = 7
const BLOB_SIZE_MIN: float = 30.0
const BLOB_SIZE_MAX: float = 56.0
const BLOB_REACH_MIN: float = 60.0    # pixels a thrown blob travels outward
const BLOB_REACH_MAX: float = 130.0
const BLOB_SAG: float = 40.0          # pixels a thrown blob drops by the end
const SPLASH_BUBBLES: int = 5
const TICK_BUBBLES_MIN: int = 3
const TICK_BUBBLES_MAX: int = 6
const BUBBLE_SIZE_MIN: float = 26.0
const BUBBLE_SIZE_MAX: float = 50.0
const BUBBLE_SPREAD: float = 70.0     # pixels from the landing point a bubble can start
const BUBBLE_RISE_MIN: float = 40.0   # pixels a bubble rises before it pops
const BUBBLE_RISE_MAX: float = 90.0
const BUBBLE_WOBBLE: float = 8.0      # pixels a rising bubble sways from side to side
const HIGHLIGHT_STRENGTH: float = 0.6 # how strongly the off-white glint shows on a blob or bubble
const LIFT: float = 0.2               # how much lighter than the poison colour goo is drawn, to show on dark ground


func duration() -> float:
  return TICK_DURATION


func draw_effect(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float) -> void:
  if age < 0.0:
    return
  if delivery.visual_only:
    _draw_tick(canvas, delivery, point, age)
  else:
    _draw_splash(canvas, delivery, point, age)
  canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## How many bubbles a damage tick raises: more for bigger ticks, on a logarithmic curve.
static func tick_bubbles(delivery: Delivery) -> int:
  var extra: int = int(log(maxf(delivery.value, 1.0)) / log(4.0))
  return clampi(TICK_BUBBLES_MIN + extra, TICK_BUBBLES_MIN, TICK_BUBBLES_MAX)


# A puff swells and fades, blobs are thrown outward and sag as they slow, and bubbles rise from
# around the landing point and pop one after another.
func _draw_splash(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float) -> void:
  if age >= APPLY_DURATION:
    return
  var through: float = age / APPLY_DURATION
  var spread: float = 1.0 - pow(1.0 - through, 3.0)
  var colour: Color = delivery.color.lightened(LIFT)
  canvas.draw_set_transform(point, fixed_random(delivery, 5) * TAU, Vector2.ONE)
  draw_centred(canvas, PUFF, lerpf(PUFF_SIZE_START, PUFF_SIZE_END, spread), faded(colour, 0.8 * pow(1.0 - through, 2.0)))
  var blob_through: float = clampf(age / (APPLY_DURATION * 0.7), 0.0, 1.0)
  var thrown: float = 1.0 - pow(1.0 - blob_through, 3.0)
  for i in SPLASH_BLOBS:
    var salt: int = 100 + i * 8
    var angle: float = (float(i) + fixed_random(delivery, salt)) / float(SPLASH_BLOBS) * TAU
    var reach: float = lerpf(BLOB_REACH_MIN, BLOB_REACH_MAX, fixed_random(delivery, salt + 1))
    var place: Vector2 = point + Vector2.from_angle(angle) * reach * thrown + Vector2.DOWN * BLOB_SAG * blob_through * blob_through
    var size: float = lerpf(BLOB_SIZE_MIN, BLOB_SIZE_MAX, fixed_random(delivery, salt + 2)) * lerpf(1.0, 0.6, blob_through)
    _draw_blob(canvas, place, size, colour, 1.0 - pow(blob_through, 2.0))
  for i in SPLASH_BUBBLES:
    _draw_rising_bubble(canvas, delivery, point, age, 200 + i * 8, lerpf(0.0, 0.3, float(i) / float(SPLASH_BUBBLES)), APPLY_DURATION)


func _draw_tick(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float) -> void:
  if age >= TICK_DURATION:
    return
  var count: int = tick_bubbles(delivery)
  for i in count:
    _draw_rising_bubble(canvas, delivery, point, age, 300 + i * 8, lerpf(0.0, 0.35, float(i) / float(count)), TICK_DURATION)


# One bubble: it appears at `start` seconds somewhere near the landing point, grows as it rises
# with a sway, and pops (swells and vanishes) at a fixed random moment before `end`.
func _draw_rising_bubble(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float, salt: int, start: float, end: float) -> void:
  var pop_time: float = lerpf(lerpf(start, end, 0.55), end - POP_DURATION, fixed_random(delivery, salt))
  if age < start or age >= pop_time + POP_DURATION:
    return
  var offset: Vector2 = Vector2(lerpf(-1.0, 1.0, fixed_random(delivery, salt + 1)), lerpf(-0.5, 0.7, fixed_random(delivery, salt + 2))) * BUBBLE_SPREAD
  var rise: float = lerpf(BUBBLE_RISE_MIN, BUBBLE_RISE_MAX, fixed_random(delivery, salt + 3))
  var size: float = lerpf(BUBBLE_SIZE_MIN, BUBBLE_SIZE_MAX, fixed_random(delivery, salt + 4))
  var life: float = clampf((age - start) / (pop_time - start), 0.0, 1.0)
  var sway: float = sin((age - start) * 14.0 + fixed_random(delivery, salt + 5) * TAU) * BUBBLE_WOBBLE
  var place: Vector2 = point + offset + Vector2(sway, -rise * (1.0 - pow(1.0 - life, 2.0)))
  var grow: float = lerpf(0.4, 1.0, 1.0 - pow(1.0 - clampf(life * 3.0, 0.0, 1.0), 2.0))
  var alpha: float = 1.0
  if age > pop_time:
    var popping: float = (age - pop_time) / POP_DURATION
    grow *= lerpf(1.0, 1.6, popping)
    alpha = 1.0 - popping
  size *= grow
  var colour: Color = delivery.color.lightened(LIFT)
  canvas.draw_set_transform(place, 0.0, Vector2.ONE)
  draw_centred(canvas, BLOB, size * 0.95, faded(colour, 0.75 * alpha))
  draw_centred(canvas, BUBBLE, size, faded(colour.lightened(0.3), alpha))
  canvas.draw_set_transform(place + Vector2(-0.22, -0.22) * size, 0.0, Vector2.ONE)
  draw_centred(canvas, BLOB, size * 0.22, faded(Colours.UI_TEXT, HIGHLIGHT_STRENGTH * alpha))


# A solid drop of goo with a small off-white glint up and to the left.
func _draw_blob(canvas: CanvasItem, place: Vector2, size: float, colour: Color, alpha: float) -> void:
  canvas.draw_set_transform(place, 0.0, Vector2.ONE)
  draw_centred(canvas, BLOB, size, faded(colour, alpha))
  canvas.draw_set_transform(place + Vector2(-0.18, -0.18) * size, 0.0, Vector2.ONE)
  draw_centred(canvas, BLOB, size * 0.35, faded(Colours.UI_TEXT, HIGHLIGHT_STRENGTH * 0.8 * alpha))
