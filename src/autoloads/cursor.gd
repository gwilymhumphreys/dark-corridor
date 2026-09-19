class_name CursorAutoload
extends Node
## Custom mouse cursor (docs/systems/cursor.md): the stone pointer replaces the operating system's
## default cursor. The plain stone pointer shows everywhere, and a slightly brightened copy shows
## over anything the player can click, so hovering is visible. Godot switches the two on hover:
## this autoload registers the plain pointer for the arrow shape and the brightened one for the
## pointing-hand shape, and clickable controls set `mouse_default_cursor_shape` to the pointing
## hand. Registered as the `Cursor` autoload.

## The stone pointer art. Its point is the top-left pixel, so the hotspot is (0, 0).
const TEXTURE_PATH: String = 'res://assets/ui/cursors/stone_pointer.png'
const HOTSPOT: Vector2 = Vector2.ZERO
## How far the hover cursor is moved towards white, 0 for no change and 1 for white.
const HOVER_LIGHTEN: float = 0.35

var _arrow: ImageTexture = null    # the plain stone pointer
var _hover: ImageTexture = null    # the brightened copy shown over clickable controls


func _ready() -> void:
  apply()


## Build both cursor textures and hand them to the display server. Safe to call again.
func apply() -> void:
  if not DisplayServer.has_feature(DisplayServer.FEATURE_CUSTOM_CURSOR_SHAPE):
    return
  var texture: Texture2D = load(TEXTURE_PATH)
  var image: Image = texture.get_image()
  image.decompress()
  _arrow = ImageTexture.create_from_image(image)
  _hover = ImageTexture.create_from_image(_lighten(image, HOVER_LIGHTEN))
  Input.set_custom_mouse_cursor(_arrow, Input.CURSOR_ARROW, HOTSPOT)
  Input.set_custom_mouse_cursor(_hover, Input.CURSOR_POINTING_HAND, HOTSPOT)


## A copy of `image` with every visible pixel moved `amount` of the way towards white.
## Alpha is left alone, so the shape and its soft edge do not change.
func _lighten(image: Image, amount: float) -> Image:
  var copy: Image = image.duplicate() as Image
  for y: int in copy.get_height():
    for x: int in copy.get_width():
      var colour: Color = copy.get_pixel(x, y)
      if colour.a > 0.0:
        var lit: Color = Color(colour.r, colour.g, colour.b).lerp(Color.WHITE, amount)
        lit.a = colour.a
        copy.set_pixel(x, y, lit)
  return copy
