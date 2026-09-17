class_name ScreenSections
extends Control
## The four sections of the run screen, laid out to match the folds in the paper background
## (docs/systems/ui_layout.md#screen-sections): the corridor top left, the player's items top right, the
## portraits lower left and the run information lower right. The split point (where the folds cross)
## and the padding are print frame settings from the F5 print panel. Each section is its part of the
## screen with the padding taken off every side. Emits `sections_changed` after moving the sections.

signal sections_changed

const SECTIONS: Array[String] = ['Corridor', 'Items', 'Portraits', 'Info']

var _split: Vector2 = -Vector2.ONE
var _padding: float = -1.0
var _laid_out_size: Vector2 = -Vector2.ONE


func _ready() -> void:
  _process(0.0)


func _process(_delta: float) -> void:
  var split: Vector2 = Vector2(PrintLook.print_setting('split_across'), PrintLook.print_setting('split_down'))
  var padding: float = PrintLook.print_setting('padding')
  if split == _split and padding == _padding and size == _laid_out_size:
    return
  _split = split
  _padding = padding
  _laid_out_size = size
  var rects: Dictionary = section_rects(size, split, padding)
  for section_name: String in SECTIONS:
    var node: Control = get_node(section_name)
    node.position = rects[section_name].position
    node.size = rects[section_name].size
  sections_changed.emit()


## A section's node: 'Corridor', 'Items', 'Portraits' or 'Info'.
func section(section_name: String) -> Control:
  return get_node(section_name)


## Each section's rectangle (section name -> Rect2) on a screen of `screen_size`, split at `split` and
## with `padding` taken off every side. Positions and sizes are whole pixels.
static func section_rects(screen_size: Vector2, split: Vector2, padding: float) -> Dictionary:
  split = split.clamp(Vector2.ZERO, screen_size).round()
  var parts: Dictionary = {
    'Corridor': Rect2(Vector2.ZERO, split),
    'Items': Rect2(split.x, 0.0, screen_size.x - split.x, split.y),
    'Portraits': Rect2(0.0, split.y, split.x, screen_size.y - split.y),
    'Info': Rect2(split, screen_size - split),
  }
  var rects: Dictionary = {}
  for section_name: String in parts:
    var part: Rect2 = parts[section_name]
    var inset: Rect2 = part.grow(-round(padding))
    inset.size = inset.size.max(Vector2.ZERO)
    rects[section_name] = inset
  return rects
