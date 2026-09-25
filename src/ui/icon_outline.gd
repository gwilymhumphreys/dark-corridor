class_name IconOutline
extends Control
## A dark outline around its parent TextureRect's icon, so a coloured icon reads on any fill, like
## the outline on the `LabelOnBar` text. Add it as a child of the icon: it draws the icon's texture
## in `colour`, shifted `width` pixels in eight directions, behind the icon. It follows the
## parent's texture and size; the parent's modulate tints it too, which leaves black unchanged.

const DIRECTIONS: Array[Vector2] = [
  Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
  Vector2(-1, 0), Vector2(1, 0),
  Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1),
]

@export var width: float = 2.0
@export var colour: Color = Color(0, 0, 0, 0.9)


func _ready() -> void:
  show_behind_parent = true
  mouse_filter = Control.MOUSE_FILTER_IGNORE
  set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  get_parent().resized.connect(queue_redraw)


func _draw() -> void:
  var icon: TextureRect = get_parent() as TextureRect
  if icon == null or icon.texture == null:
    return
  var rect: Rect2 = _icon_rect(icon)
  for direction in DIRECTIONS:
    draw_texture_rect(icon.texture, Rect2(rect.position + direction * width, rect.size), false, colour)


## Where the parent draws its texture: scaled to fit and centred, as `STRETCH_KEEP_ASPECT_CENTERED`.
func _icon_rect(icon: TextureRect) -> Rect2:
  var texture_size: Vector2 = icon.texture.get_size()
  var scale_factor: float = minf(size.x / texture_size.x, size.y / texture_size.y)
  var drawn: Vector2 = texture_size * scale_factor
  return Rect2((size - drawn) / 2.0, drawn)
