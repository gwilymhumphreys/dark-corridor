class_name ProjectilePixelDrawer
extends EffectDrawer
## A looping pixel-art animation drawn for a delivery in flight (docs/systems/vfx_driver.md). The
## animations come from the Beat 'em Up Combat Effects packs and the 500 Bullet pack. Each sheet in
## `assets/vfx/projectile/pixel/` (made by `tools/make_pixel_projectiles.py`) has one column per frame
## and one row per brightness band, darkest first; each band is drawn in a shade of the delivery's
## colour, so the art keeps its shading in any colour. It is scaled by a whole number so its pixels
## stay square, and must be drawn on a canvas item whose texture filter is nearest.
##
## TRIAL: one of the looks being tried for projectiles. `VfxDriver.pixel_projectile` picks the
## animation, or 0 for none.

## The animations, in the order the debug panel lists them after 'Off'. `turns`: the art points up
## and is turned to face the direction of travel; otherwise it is drawn upright.
const ANIMATIONS: Array[Dictionary] = [
  {'name': 'Crescent', 'sheet': preload('res://assets/vfx/projectile/pixel/crescent.png'), 'frames': 12, 'turns': false},
  {'name': 'Orb', 'sheet': preload('res://assets/vfx/projectile/pixel/orb.png'), 'frames': 8, 'turns': true},
  {'name': 'Crystal', 'sheet': preload('res://assets/vfx/projectile/pixel/crystal.png'), 'frames': 10, 'turns': true},
  {'name': 'Fire Swirl', 'sheet': preload('res://assets/vfx/projectile/pixel/fire_swirl.png'), 'frames': 4, 'turns': false},
  {'name': 'Blob', 'sheet': preload('res://assets/vfx/projectile/pixel/blob.png'), 'frames': 4, 'turns': false},
  {'name': 'Swirl', 'sheet': preload('res://assets/vfx/projectile/pixel/swirl.png'), 'frames': 8, 'turns': false},
  {'name': 'Twin Hooks', 'sheet': preload('res://assets/vfx/projectile/pixel/twin_hooks.png'), 'frames': 8, 'turns': false},
  {'name': 'Spinning Ring', 'sheet': preload('res://assets/vfx/projectile/pixel/spinning_ring.png'), 'frames': 8, 'turns': false},
]
const BANDS: int = 4
const FRAMES_PER_SECOND: float = 12.0   # in render-time seconds, so the animation slows with the fight
## How much each band, darkest first, is darkened (below 0) or lightened (above 0) from the delivery's colour.
const BAND_SHADES: Array[float] = [-0.45, 0.0, 0.25, 0.55]


## The names the debug panel lists: 'Off', then each animation.
static func option_names() -> Array[String]:
  var names: Array[String] = ['Off']
  for animation: Dictionary in ANIMATIONS:
    names.append(animation['name'])
  return names


## The `VfxDriver.pixel_projectile` value for an animation named in lower case with underscores
## for spaces, as `--pixel-projectile` gives it, or 0 (none) for any other name.
static func option_index(lower_name: String) -> int:
  for i in ANIMATIONS.size():
    if String(ANIMATIONS[i]['name']).to_lower().replace(' ', '_') == lower_name:
      return i + 1
  return 0


## Draw animation `index` (into ANIMATIONS) at `point`, `scale` times its pixel size, facing
## `direction` if it turns. `age` is render-time seconds since launch.
func draw_flight(canvas: CanvasItem, delivery: Delivery, index: int, point: Vector2, direction: Vector2, age: float, scale: float) -> void:
  var animation: Dictionary = ANIMATIONS[clampi(index, 0, ANIMATIONS.size() - 1)]
  var sheet: Texture2D = animation['sheet']
  var frames: int = animation['frames']
  var width: float = float(sheet.get_width()) / float(frames)
  var height: float = float(sheet.get_height()) / float(BANDS)
  var frame: int = int(maxf(age, 0.0) * FRAMES_PER_SECOND) % frames
  var angle: float = 0.0
  if animation['turns'] and direction != Vector2.ZERO:
    angle = direction.angle() + PI * 0.5
  canvas.draw_set_transform(point, angle, Vector2.ONE * scale)
  var target: Rect2 = Rect2(-width * 0.5, -height * 0.5, width, height)
  for band in BANDS:
    var source: Rect2 = Rect2(frame * width, band * height, width, height)
    canvas.draw_texture_rect_region(sheet, target, source, band_colour(delivery.color, band))
  canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


static func band_colour(colour: Color, band: int) -> Color:
  var shade: float = BAND_SHADES[band]
  return colour.darkened(-shade) if shade < 0.0 else colour.lightened(shade)
