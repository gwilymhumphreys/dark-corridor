class_name RewardReel
extends Control
## The reel a `RewardOption` shows while a `RewardSpin` spins it in the reel style
## (docs/systems/run_screen.md → Overlays): a strip of item icons seen through a window, as if printed
## round a turning drum. A face at the centre of the window is full height; towards the top and bottom
## edges faces get flatter, bunch together and darken, then pass over the edge. Each option has two:
## one inside the cell's frame, and one behind the cell, as tall as the `reward_spin_window` print
## setting, showing the faces above and below the frame. Drawn with `_draw`, clipped to its own
## rectangle. Reads the print settings; writes nothing.

## The gap between faces on the drum, as a share of a face's height.
const FACE_GAP: float = 0.12
## How many faces either side of the centre are drawn; more than a three-face-tall window can show.
const REACH: int = 6

var _strip: Array[Texture2D] = []
var _position: float = 0.0       # the strip index at the window's centre
var _face_height: float = 0.0    # 0 = this reel's own height


func _exit_tree() -> void:
  _strip.clear()


## Show `strip` with index `strip_position` (fractions are part way) at the centre of the window, the
## higher indices above it. `face_height` is the height a face has at the centre; 0 uses this reel's
## own height.
func show_strip(strip: Array[Texture2D], strip_position: float, face_height: float = 0.0) -> void:
  _strip = strip
  _position = strip_position
  _face_height = face_height
  visible = true
  queue_redraw()


## Hide the reel and let go of its strip.
func hide_strip() -> void:
  visible = false
  _strip = []


## The face nearest the centre of the window, or null when there is none.
func face_at_centre() -> Texture2D:
  var index: int = roundi(_position)
  if index < 0 or index >= _strip.size():
    return null
  return _strip[index]


## The drum's radius for a window `half_window` pixels from centre to edge: with `curve` 1 the window's
## edges are the drum's top and bottom, smaller values a wider drum, 0 a flat strip (radius 0).
static func drum_radius(half_window: float, curve: float) -> float:
  if curve <= 0.001:
    return 0.0
  return half_window / sin(clampf(curve, 0.0, 1.0) * PI * 0.5)


## The length along the drum of a face that shows `face_height` tall at the centre of the window. On a
## drum this is longer than its height, as the drum curves away under it.
static func face_arc(face_height: float, radius: float) -> float:
  if radius <= 0.0:
    return face_height
  return 2.0 * radius * asin(minf(face_height / (2.0 * radius), 1.0))


## Where a face shows in the window, as (top, bottom, brightness). `arc` is the distance along the drum
## from the window's centre to the face's centre (positive is below), `length` the face's length along
## the drum and `half_window` the window's half height. Top and bottom are pixels from the window's
## centre; a face past the drum's edge has no height. Brightness is 1 at the centre and
## 1 - `darkening` at the window's edge.
static func drum_place(arc: float, length: float, half_window: float, radius: float, darkening: float) -> Vector3:
  var top: float = _drum_y(arc - length * 0.5, radius)
  var bottom: float = _drum_y(arc + length * 0.5, radius)
  var edge_share: float = clampf(absf(_drum_y(arc, radius)) / maxf(half_window, 0.001), 0.0, 1.0)
  return Vector3(top, bottom, 1.0 - darkening * edge_share * edge_share)


# The height in the window of a point `arc` along the drum from the centre. Past the drum's top or
# bottom the point stays on that edge.
static func _drum_y(arc: float, radius: float) -> float:
  if radius <= 0.0:
    return arc
  return radius * sin(clampf(arc / radius, -PI * 0.5, PI * 0.5))


func _draw() -> void:
  var face_height: float = _face_height if _face_height > 0.0 else size.y
  if _strip.is_empty() or face_height <= 0.0:
    return
  var window: float = maxf(PrintLook.print_setting('reward_spin_window'), 1.0)
  var half_window: float = face_height * window * 0.5
  var radius: float = drum_radius(half_window, PrintLook.print_setting('reward_spin_curve'))
  var length: float = face_arc(face_height, radius)
  var pitch: float = length * (1.0 + FACE_GAP)
  var darkening: float = PrintLook.print_setting('reward_spin_darkening')
  var centre: int = roundi(_position)
  for index in range(maxi(centre - REACH, 0), mini(centre + REACH + 1, _strip.size())):
    var texture: Texture2D = _strip[index]
    if texture == null:
      continue
    var place: Vector3 = drum_place((_position - index) * pitch, length, half_window, radius, darkening)
    var height: float = place.y - place.x
    if height < 0.5:
      continue
    var width: float = minf(size.x, face_height * texture.get_width() / maxf(texture.get_height(), 1.0))
    var rect: Rect2 = Rect2((size.x - width) * 0.5, size.y * 0.5 + place.x, width, height)
    draw_texture_rect(texture, rect, false, Color(place.z, place.z, place.z))
