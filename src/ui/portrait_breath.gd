class_name PortraitBreath
extends Node

## Drop-in slow zoom for a portrait image.
##
## Add this as a child of the portrait's TextureRect and the picture scales gently
## up and down forever, like slow breathing.
##
## The zoom happens inside the shader, not on the node: it sets the `picture_zoom`
## instance uniform on the parent's canvas item, which `interface_portrait.gdshader`
## applies to the image lookup, so the parent must use `InterfaceLook.portrait_material`. The node keeps its size on screen, so it never
## overflows its frame and the pixelate, halftone, hatching and grain patterns stay
## still while the picture moves through them. Each node picks a random starting
## point in the cycle, so several portraits on screen do not breathe in unison.

const UNIFORM: String = 'picture_zoom'

## How much the picture is magnified at the top of the breath. 0.02 is a 2% zoom.
@export_range(0.0, 0.2, 0.001) var amount: float = 0.02
## Seconds for one full breath, in and back out again.
@export_range(0.5, 30.0, 0.1) var period: float = 6.0

var _target: CanvasItem
var _phase: float = 0.0


func _ready() -> void:
  var parent: Node = get_parent()
  if not (parent is CanvasItem):
    push_warning('PortraitBreath: parent is not a CanvasItem; breathing disabled. Parent=%s' % str(parent))
    set_process(false)
    return
  _target = parent as CanvasItem
  _phase = randf() * TAU


func _process(delta: float) -> void:
  if not is_instance_valid(_target):
    return
  _phase = fposmod(_phase + TAU * delta / maxf(period, 0.001), TAU)
  # cos runs from 1 to -1 and back, so this rises from no zoom to `amount` above it
  # and returns, with no jump at the ends of the cycle.
  _set_zoom(1.0 + amount * 0.5 * (1.0 - cos(_phase)))


func _exit_tree() -> void:
  if is_instance_valid(_target):
    _set_zoom(1.0)


func _set_zoom(zoom: float) -> void:
  RenderingServer.canvas_item_set_instance_shader_parameter(_target.get_canvas_item(), UNIFORM, zoom)
