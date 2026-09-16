class_name PrintFrame
extends Control
## The printed frame around the combat corridor (docs/systems/print_frame.md), set from the F5 print
## panel. It moves the corridor in from its place in the scene by the corridor margin, sizes the border
## behind the corridor and the overlay on top of it, and tells the background wear where the corridor
## is on screen so folds can line up with it. The border and the overlay are hidden while their effects
## are off.

## The corridor panel the frame surrounds; a sibling after this node, so the border draws behind it.
@export var corridor: Control
## The rectangle over the corridor that draws wear and a worn edge; a sibling after the corridor.
@export var overlay: ColorRect

var _scene_rect: Rect2   # the corridor's place in the scene, before the margin
var _margin: float = -1.0

@onready var _border: ColorRect = $Border


func _ready() -> void:
  _scene_rect = Rect2(corridor.position, corridor.size)
  _border.material = PrintLook.border_material
  overlay.material = PrintLook.overlay_material
  _process(0.0)


func _exit_tree() -> void:
  PrintLook.background_material.set_shader_parameter('print_corridor_rect', Vector4.ZERO)
  _border.material = null
  if is_instance_valid(overlay):
    overlay.material = null


func _process(_delta: float) -> void:
  var margin: float = PrintLook.print_setting('corridor_margin')
  if margin != _margin:
    _margin = margin
    corridor.position = _scene_rect.position + Vector2(margin, margin)
    corridor.size = _scene_rect.size - Vector2(margin, margin) * 2.0
  _place_border()
  _place_overlay()
  PrintLook.background_material.set_shader_parameter('print_corridor_rect', _screen_rect(corridor))


func _place_border() -> void:
  var border_material: ShaderMaterial = PrintLook.border_material
  _border.visible = border_material.get_shader_parameter('print_border_on')
  if not _border.visible:
    return
  var grow: float = float(border_material.get_shader_parameter('print_border_gap')) \
    + float(border_material.get_shader_parameter('print_border_width')) \
    + float(border_material.get_shader_parameter('print_border_roughness'))
  _border.position = corridor.position - Vector2(grow, grow)
  _border.size = corridor.size + Vector2(grow, grow) * 2.0
  border_material.set_shader_parameter('rect_size', _screen_size(_border))
  border_material.set_shader_parameter('border_colour', Colours.UI_BORDER)
  border_material.set_shader_parameter('border_wear_colour', Colours.UI_BACKGROUND_WEAR)


# The overlay takes the background wear's settings so its marks match the background's.
func _place_overlay() -> void:
  var overlay_material: ShaderMaterial = PrintLook.overlay_material
  overlay.visible = overlay_material.get_shader_parameter('corridor_wear_on') \
    or overlay_material.get_shader_parameter('corridor_worn_edge_on')
  if not overlay.visible:
    return
  overlay.position = corridor.position
  overlay.size = corridor.size
  var background_material: ShaderMaterial = PrintLook.background_material
  for uniform: String in PrintLook.background_defaults():
    overlay_material.set_shader_parameter(uniform, background_material.get_shader_parameter(uniform))
  overlay_material.set_shader_parameter('print_corridor_rect', _screen_rect(corridor))
  overlay_material.set_shader_parameter('rect_size', _screen_size(overlay))
  overlay_material.set_shader_parameter('paper_colour', Colours.UI_BACKGROUND)
  overlay_material.set_shader_parameter('wear_dark_colour', Colours.UI_BACKGROUND_WEAR)
  overlay_material.set_shader_parameter('wear_light_colour', Colours.UI_BACKGROUND_WEAR_LIGHT)


# A control's rectangle in window pixels (x, y, width, height), the space shaders see as FRAGCOORD.
func _screen_rect(control: Control) -> Vector4:
  var to_screen: Transform2D = get_viewport().get_final_transform() * control.get_global_transform_with_canvas()
  var top_left: Vector2 = to_screen * Vector2.ZERO
  var bottom_right: Vector2 = to_screen * control.size
  return Vector4(top_left.x, top_left.y, bottom_right.x - top_left.x, bottom_right.y - top_left.y)


func _screen_size(control: Control) -> Vector2:
  var rect: Vector4 = _screen_rect(control)
  return Vector2(rect.z, rect.w)
