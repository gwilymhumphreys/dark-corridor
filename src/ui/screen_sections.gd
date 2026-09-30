class_name ScreenSections
extends Control
## The sections of the run screen, either side of the fold down the middle of the paper background
## (docs/systems/ui_layout.md#screen-sections): the corridor fills the left half, the player's column
## (portraits, potions, items and the map) fills the right half, and the run information (the report and
## speed buttons) runs along the bottom of the right half, as tall as its tallest child. Each section is
## its part of the screen with the `padding` print setting taken off every side. Emits
## `sections_changed` after moving the sections.

signal sections_changed

const SECTIONS: Array[String] = ['Corridor', 'Items', 'Info']

var _padding: float = -1.0
var _info_height: float = -1.0
var _laid_out_size: Vector2 = -Vector2.ONE


func _ready() -> void:
  _process(0.0)


func _process(_delta: float) -> void:
  var padding: float = PrintLook.print_setting('padding')
  var info_height: float = _tallest_child(section('Info'))
  if padding == _padding and info_height == _info_height and size == _laid_out_size:
    return
  _padding = padding
  _info_height = info_height
  _laid_out_size = size
  var rects: Dictionary = section_rects(size, padding, info_height)
  for section_name: String in SECTIONS:
    var node: Control = section(section_name)
    node.position = rects[section_name].position
    node.size = rects[section_name].size
  sections_changed.emit()


## A section's node: 'Corridor', 'Items' or 'Info'.
func section(section_name: String) -> Control:
  return get_node(section_name)


## Each section's rectangle (section name -> Rect2) on a screen of `screen_size`, with `padding` taken
## off every side and the information section `info_height` tall. Positions and sizes are whole pixels.
static func section_rects(screen_size: Vector2, padding: float, info_height: float) -> Dictionary:
  var middle: float = roundf(screen_size.x * 0.5)
  var inset: float = roundf(padding)
  var info_part: float = ceilf(info_height) + inset * 2.0
  var parts: Dictionary = {
    'Corridor': Rect2(0.0, 0.0, middle, screen_size.y),
    'Items': Rect2(middle, 0.0, screen_size.x - middle, screen_size.y - info_part),
    'Info': Rect2(middle, screen_size.y - info_part, screen_size.x - middle, info_part),
  }
  var rects: Dictionary = {}
  for section_name: String in parts:
    var rect: Rect2 = (parts[section_name] as Rect2).grow(-inset)
    rect.size = rect.size.max(Vector2.ZERO)
    rects[section_name] = rect
  return rects


func _tallest_child(node: Control) -> float:
  var tallest: float = 0.0
  for child: Node in node.get_children():
    var control: Control = child as Control
    if control != null and control.visible:
      tallest = maxf(tallest, control.size.y)
  return tallest
