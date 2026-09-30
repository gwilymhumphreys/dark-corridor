class_name HealDrawer
extends EffectDrawer
## The effect drawn where healing lands on a health bar (docs/systems/vfx_driver.md): a few small
## heal icons start along the bar one after another, float up with a slight side-to-side wiggle
## and fade out. Bigger heals raise more icons. Each icon starts in its own section of the bar, so
## they do not bunch up. Each icon's place and wiggle are fixed per delivery. Regen uses the same
## effect with its own icon and colour: the drawer shows the icon of the mechanic it is made for.

const DURATION: float = 0.9          # render-time seconds from the first icon to the last one fading
const ICON_LIFE: float = 0.6         # render-time seconds one icon shows
const ICONS_MIN: int = 3
const ICONS_MAX: int = 6
const ICON_SIZE_MIN: float = 34.0    # an icon's width in pixels
const ICON_SIZE_MAX: float = 46.0
const SPREAD: float = 100.0          # pixels either side of the bar's centre an icon can start
const RISE_MIN: float = 80.0         # pixels an icon floats up over its life
const RISE_MAX: float = 130.0
const BRIGHTEN: float = 0.35         # how much lighter than the delivery's colour a tinted icon is drawn
const WIGGLE: float = 6.0            # pixels an icon sways to each side
const WIGGLE_SPEED: float = 16.0     # how fast an icon sways (radians per second)

var _mechanic_id: String   # the mechanic whose icon floats up
var _icon_path: String = ''
var _icon: Texture2D = null


func _init(mechanic_id: String = HealMechanic.ID) -> void:
  _mechanic_id = mechanic_id


func duration() -> float:
  return DURATION


## How many icons a heal or regen tick raises: more for bigger amounts, on a logarithmic curve.
static func icon_count(delivery: Delivery) -> int:
  var extra: int = int(log(maxf(delivery.value, 1.0)) / log(4.0))
  return clampi(ICONS_MIN + extra - 2, ICONS_MIN, ICONS_MAX)


func draw_effect(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float) -> void:
  if progress(age) < 0.0:
    return
  var icon: Texture2D = _mechanic_icon()
  if icon == null:
    return
  # A glyph is a white shape tinted with the delivery's colour; any other icon keeps its own colours.
  var colour: Color = delivery.color.lightened(BRIGHTEN) if _icon_path.begins_with(KeywordIcon.GLYPH_DIR) else Color.WHITE
  var count: int = icon_count(delivery)
  for i in count:
    var start: float = (DURATION - ICON_LIFE) * float(i) / float(maxi(count - 1, 1))
    # Stepping through the sections by 7 visits each once in a scattered order (7 shares no factor
    # with any count from ICONS_MIN to ICONS_MAX), so the icons do not rise left to right.
    var section: int = (i * 7) % count
    _draw_icon(canvas, delivery, icon, colour, point, age - start, section, count, 10 + i * 8)
  canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


# One icon, `life_age` seconds after it appeared: it pops in from small, floats up while swaying,
# and fades over the second half of its life.
func _draw_icon(canvas: CanvasItem, delivery: Delivery, icon: Texture2D, colour: Color, point: Vector2, life_age: float, section: int, count: int, salt: int) -> void:
  if life_age < 0.0 or life_age >= ICON_LIFE:
    return
  var through: float = life_age / ICON_LIFE
  var place_in_section: float = lerpf(0.2, 0.8, fixed_random(delivery, salt))
  var start_x: float = lerpf(-SPREAD, SPREAD, (float(section) + place_in_section) / float(count))
  var rise: float = lerpf(RISE_MIN, RISE_MAX, fixed_random(delivery, salt + 1)) * (1.0 - pow(1.0 - through, 2.0))
  var sway: float = sin(life_age * WIGGLE_SPEED + fixed_random(delivery, salt + 2) * TAU) * WIGGLE
  var size: float = lerpf(ICON_SIZE_MIN, ICON_SIZE_MAX, fixed_random(delivery, salt + 3))
  size *= lerpf(0.4, 1.0, 1.0 - pow(1.0 - clampf(through * 4.0, 0.0, 1.0), 2.0))
  var alpha: float = 1.0 - clampf((through - 0.5) * 2.0, 0.0, 1.0)
  canvas.draw_set_transform(point + Vector2(start_x + sway, -rise), 0.0, Vector2.ONE)
  draw_centred(canvas, icon, size, faded(colour, alpha))


# The mechanic's current icon. Looked up each time so a change in the icon slots panel (F6) shows
# at once; the texture is only loaded again when the path changes.
func _mechanic_icon() -> Texture2D:
  var path: String = MechanicRegistry.get_mechanic(_mechanic_id).icon
  if path != _icon_path:
    _icon_path = path
    _icon = load(path) as Texture2D if path != '' else null
  return _icon
