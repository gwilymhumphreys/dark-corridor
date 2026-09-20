class_name CursorAutoload
extends CanvasLayer
## Custom mouse cursor (docs/systems/cursor.md): the operating system's cursor is hidden and a
## pointing hand is drawn in its place, on a CanvasLayer above everything else. Drawing it rather
## than registering it with the display server means it is sized in canvas pixels, so it grows and
## shrinks with the window like the rest of the interface, and it is drawn through the same
## material as the item and status icons, so the interface look's effects and the palette clamp
## apply to it.
##
## The hand art is also recoloured onto the interface palette, a copy with an outline drawn round
## its edge shows over anything the player can click, and a second piece of art, the hand with its
## finger curled, shows while the left mouse button is held. Which one is drawn comes from
## `Input.get_current_cursor_shape()`, so clickable controls still say when to show the hover hand
## through `mouse_default_cursor_shape`, exactly as they did with a display-server cursor.
## Registered as the `Cursor` autoload (`src/scenes/ui/mouse_cursor.tscn`).

## The pointing hand art. The fingertip is at (7, 0) of the 32×32 art, so that is the hotspot.
const TEXTURE_PATH: String = 'res://assets/ui/cursors/hand_pointer.png'
const HOTSPOT: Vector2 = Vector2(7, 0)
## The same hand with its finger curled, shown while the left mouse button is held. It uses the
## same hotspot, which is above the curled finger rather than on it, so that the hand itself does
## not jump when the button goes down.
const PRESSED_TEXTURE_PATH: String = 'res://assets/ui/cursors/hand_pointer_pressed.png'
## The art's width in pixels. The drawn hand's size is set in the scene, in canvas pixels, and the
## hotspot is scaled by the ratio between the two.
const ART_SIZE: float = 32.0
## The `Colours` variables the hand's pixels are placed on by brightness, darkest to lightest.
## The text colours, not the panel colours, so the hand reads against the dark screens.
const BODY_COLOURS: Array[String] = [
  'UI_TEXT_DISABLED',
  'UI_TEXT_PRESSED',
  'UI_TEXT_DIM',
  'UI_TEXT_BUTTON',
  'UI_TEXT',
]
## The `Colours` variable the hover outline is drawn in. Dark, because the hand itself is light.
const OUTLINE_COLOUR: String = 'UI_PANEL_SHADOW'
## How opaque a pixel must be to count as inside the hand when finding its edge.
const EDGE_ALPHA: float = 0.5

@onready var _hand: TextureRect = $Hand

var _arrow: ImageTexture = null            # the plain hand pointer
var _hover: ImageTexture = null            # the outlined copy shown over clickable controls
var _pressed_arrow: ImageTexture = null    # the curled hand, while the button is held
var _pressed_hover: ImageTexture = null    # the curled hand outlined, over clickable controls
var _pressed: bool = false                 # whether the left mouse button is currently held


func _ready() -> void:
  apply()
  _hide_system_cursor(true)


## Build the cursor textures. Safe to call again, and called again by `DebugPanels` after an
## interface palette is applied or reset.
func apply() -> void:
  var body: Image = _recoloured(_art(TEXTURE_PATH))
  var pressed_body: Image = _recoloured(_art(PRESSED_TEXTURE_PATH))
  _arrow = ImageTexture.create_from_image(body)
  _hover = ImageTexture.create_from_image(_outlined(body))
  _pressed_arrow = ImageTexture.create_from_image(pressed_body)
  _pressed_hover = ImageTexture.create_from_image(_outlined(pressed_body))
  _draw_hand()


## Follow the mouse and pick the hand to draw. Both are done every frame: the position because the
## drawn hand can only be as fresh as the last frame, and the hand because the shape a control asks
## for through `mouse_default_cursor_shape` changes without an event of its own.
func _process(_delta: float) -> void:
  if _hand == null:
    return
  var scale_factor: float = _hand.size.x / ART_SIZE
  _hand.position = get_viewport().get_mouse_position() - HOTSPOT * scale_factor
  _draw_hand()


## Watch the left mouse button so the curled hand shows while it is held. This runs before the
## controls see the click, so a button that handles the press still gets the curled hand.
func _input(event: InputEvent) -> void:
  var click: InputEventMouseButton = event as InputEventMouseButton
  if click != null and click.button_index == MOUSE_BUTTON_LEFT:
    _set_pressed(click.pressed)


## Give the operating system's cursor back while the window is not focused, and let go of the press
## so a button released somewhere else does not leave the curled hand on screen.
func _notification(what: int) -> void:
  if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
    _set_pressed(false)
    _hide_system_cursor(false)
  elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
    _hide_system_cursor(true)


func _set_pressed(held: bool) -> void:
  if held == _pressed:
    return
  _pressed = held
  _draw_hand()


# Put the hand for the current shape and press state on the drawn node. `CURSOR_POINTING_HAND` is
# the shape clickable controls ask for; every other shape gets the plain hand.
func _draw_hand() -> void:
  if _hand == null or _arrow == null:
    return
  var hovering: bool = Input.get_current_cursor_shape() == Input.CURSOR_POINTING_HAND
  if _pressed:
    _hand.texture = _pressed_hover if hovering else _pressed_arrow
  else:
    _hand.texture = _hover if hovering else _arrow


# Hide or show the operating system's cursor, and the drawn hand with it. A run with no mouse, such
# as the headless test and autotest runs, is left alone.
func _hide_system_cursor(hidden: bool) -> void:
  if not DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
    return
  Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if hidden else Input.MOUSE_MODE_VISIBLE
  visible = hidden
  set_process(hidden)


# The art at `path` as an editable image.
func _art(path: String) -> Image:
  var texture: Texture2D = load(path)
  var image: Image = texture.get_image()
  image.decompress()
  image.convert(Image.FORMAT_RGBA8)
  return image


## A copy of `image` with every visible pixel replaced by the `BODY_COLOURS` colour its brightness
## falls on, blending between the two nearest, so the art's shading is kept but its hues are the
## interface's. The colours are read from `Colours` each time, so an interface palette applied at
## runtime is picked up (docs/systems/interface_palette.md). Alpha is left alone, so the shape and
## its soft edge do not change.
func _recoloured(image: Image) -> Image:
  var colours_script: Script = Colours
  var palette: Array[Color] = []
  for variable: String in BODY_COLOURS:
    palette.append(colours_script.get(variable))
  var steps: int = palette.size() - 1
  var copy: Image = image.duplicate() as Image
  for y: int in copy.get_height():
    for x: int in copy.get_width():
      var colour: Color = copy.get_pixel(x, y)
      if colour.a <= 0.0:
        continue
      var place: float = clampf(colour.get_luminance(), 0.0, 1.0) * steps
      var step: int = mini(int(place), steps - 1)
      var lit: Color = palette[step].lerp(palette[step + 1], place - step)
      lit.a = colour.a
      copy.set_pixel(x, y, lit)
  return copy


## A copy of `image` with its outer edge drawn in the `OUTLINE_COLOUR` colour: every visible pixel
## that touches a pixel outside the hand, which is both the outermost solid ring and the soft edge
## around it. The outline is drawn inside the shape, so the hand keeps its size and its hotspot.
func _outlined(image: Image) -> Image:
  var colour: Color = (Colours as Script).get(OUTLINE_COLOUR)
  var copy: Image = image.duplicate() as Image
  for y: int in image.get_height():
    for x: int in image.get_width():
      var alpha: float = image.get_pixel(x, y).a
      if alpha <= 0.0:
        continue
      if _inside(image, x - 1, y) and _inside(image, x + 1, y) \
          and _inside(image, x, y - 1) and _inside(image, x, y + 1):
        continue
      copy.set_pixel(x, y, Color(colour.r, colour.g, colour.b, alpha))
  return copy


# Whether (x, y) is a pixel inside the hand. Off the image counts as outside, so a shape that runs
# to the edge of the art is outlined there too.
func _inside(image: Image, x: int, y: int) -> bool:
  if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
    return false
  return image.get_pixel(x, y).a >= EDGE_ALPHA


## Give the operating system's cursor back before the game closes, so it is not left hidden if the
## window outlives the game.
func _exit_tree() -> void:
  _hide_system_cursor(false)
