class_name DamageNumberDrawer
extends EffectDrawer
## The number shown where a hit or a heal lands. It floats up and slows while drifting to one side
## on a slightly wavy path, then quickly grows and shrinks away. Its size grows with the amount, from a fixed base
## size up to a maximum. Heals draw the same way with a '+' in front.


const FLOAT_DURATION: float = 0.6    # seconds the number floats up (render-time)
const EXIT_DURATION: float = 0.2     # seconds of the grow and shrink at the end
const START_HEIGHT: float = 150.0    # how far above the landing point the number starts
const FLOAT_DISTANCE: float = 70.0   # how far the number floats up
const DRIFT_DISTANCE: float = 50.0   # the sideways drift of a number that landed furthest off centre
const DRIFT_RANDOMNESS: float = 0.3  # the random part of the drift, as a share of DRIFT_DISTANCE
const WAVE_WIDTH: float = 4.0        # how far the path sways to each side of its line
const WAVE_CYCLES: float = 0.5       # full side-to-side sways while floating
const BASE_FONT_SIZE: float = 40.0   # the size of the smallest hit
const MAX_FONT_SIZE: float = 140.0   # the size of any hit at or above AMOUNT_FOR_MAX_SIZE
const AMOUNT_FOR_MAX_SIZE: float = 2000.0
# Shapes the size curve. With 25 the size is halfway between base and maximum at 200, since
# log(1 + 200/25) is half of log(1 + 2000/25).
const SIZE_CURVE_SOFTNESS: float = 25.0
const GROW_SCALE: float = 1.35       # how large the number grows before it shrinks away
const GROW_SHARE: float = 0.4        # the part of the exit spent growing; the rest is shrinking
const OUTLINE_SHARE: float = 0.18    # outline thickness as a share of the font size
const OUTLINE_COLOR: Color = Color.BLACK


func duration() -> float:
  return FLOAT_DURATION + EXIT_DURATION


## The font size for a hit or heal of this amount. It rises quickly for small amounts and slowly
## for large ones.
static func font_size_for(amount: float) -> int:
  var share: float = log(1.0 + maxf(amount, 0.0) / SIZE_CURVE_SOFTNESS) \
      / log(1.0 + AMOUNT_FOR_MAX_SIZE / SIZE_CURVE_SOFTNESS)
  return int(round(lerpf(BASE_FONT_SIZE, MAX_FONT_SIZE, minf(share, 1.0))))


## How far the number drifts sideways, in pixels. It drifts away from the target's centre on the
## side the landing point was nudged to, further the further off centre it landed, so numbers on
## one target spread apart. A random amount is added on top, taken from the delivery's identity
## like the landing nudge, so it stays the same every frame.
static func drift_for(delivery: Delivery) -> float:
  var off_centre: float = EffectDrawer.scatter_offset(delivery).x / EffectDrawer.SCATTER_RADIUS
  var id: int = delivery.get_instance_id()
  var random: float = float(hash(id * 53 + 11) % 2001) / 1000.0 - 1.0   # -1 to 1
  return (off_centre + random * DRIFT_RANDOMNESS) * DRIFT_DISTANCE


## The sideways sway of the path, in pixels, at this share of the float (0 to 1). It starts and
## ends on the drift line. Whether it sways left or right first is fixed per delivery, so numbers
## landing together do not sway in step.
static func wave_for(delivery: Delivery, rise: float) -> float:
  var first_side: float = -1.0 if hash(delivery.get_instance_id() * 97 + 5) % 2 == 0 else 1.0
  return sin(rise * TAU * WAVE_CYCLES) * WAVE_WIDTH * first_side


## The number's scale this many seconds after landing: 1 while floating, then up to GROW_SCALE and
## down to nothing.
static func scale_at(age: float) -> float:
  if age < FLOAT_DURATION:
    return 1.0
  var through: float = clampf((age - FLOAT_DURATION) / EXIT_DURATION, 0.0, 1.0)
  if through < GROW_SHARE:
    var grow: float = through / GROW_SHARE
    return lerpf(1.0, GROW_SCALE, 1.0 - pow(1.0 - grow, 2.0))
  var shrink: float = (through - GROW_SHARE) / (1.0 - GROW_SHARE)
  return lerpf(GROW_SCALE, 0.0, shrink * shrink)


func draw_effect(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float) -> void:
  if progress(age) < 0.0:
    return
  var scale: float = scale_at(age)
  if scale <= 0.0:
    return
  var font: Font = _font()
  var text: String = str(int(delivery.value))
  if delivery.kind == Delivery.Kind.HEAL:
    text = '+' + text
  var size: int = font_size_for(delivery.value)
  var rise: float = clampf(age / FLOAT_DURATION, 0.0, 1.0)
  var eased: float = 1.0 - pow(1.0 - rise, 3.0)   # fast, then slow
  var sideways: float = drift_for(delivery) * eased + wave_for(delivery, rise)
  var centre: Vector2 = point + Vector2(sideways, -START_HEIGHT - FLOAT_DISTANCE * eased)
  # Draw around the text's centre so the grow and shrink stay centred on it.
  var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
  var baseline: Vector2 = Vector2(-text_size.x * 0.5, font.get_ascent(size) - text_size.y * 0.5)
  var outline: int = maxi(int(round(size * OUTLINE_SHARE)), 2)
  canvas.draw_set_transform(centre, 0.0, Vector2(scale, scale))
  canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, OUTLINE_COLOR)
  canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, delivery.color)
  canvas.draw_set_transform(Vector2.ZERO)


## The project theme's font, so the numbers follow the font style.
func _font() -> Font:
  var theme: Theme = ThemeDB.get_project_theme()
  if theme != null and theme.default_font != null:
    return theme.default_font
  return ThemeDB.fallback_font
