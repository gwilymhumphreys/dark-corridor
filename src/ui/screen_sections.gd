class_name ScreenSections
extends Control
## The four sections of the run screen, laid out to match the folds in the paper background
## (docs/systems/ui_layout.md#screen-sections): the corridor top left, the player's items top right, the
## portraits lower left and the run information lower right. The split point (where the folds cross),
## the padding and the layout are print frame settings from the Print tab. Each section is its part of
## the screen with the padding taken off every side. Emits `sections_changed` after moving the sections.

signal sections_changed

## Where the sections go (the `screen_layout` print setting). PORTRAITS_LOWER_LEFT: the four sections
## above. PORTRAITS_ABOVE_ITEMS: the corridor takes the whole left side, and the portraits and the items
## share the top right section, which the combat view splits with the portraits on top.
enum Layout { PORTRAITS_LOWER_LEFT, PORTRAITS_ABOVE_ITEMS }

const SECTIONS: Array[String] = ['Corridor', 'Items', 'Portraits', 'Info']

## The layout the sections were last placed in.
var layout: Layout = Layout.PORTRAITS_LOWER_LEFT

var _split: Vector2 = -Vector2.ONE
var _padding: float = -1.0
var _laid_out_size: Vector2 = -Vector2.ONE


func _ready() -> void:
  _process(0.0)


func _process(_delta: float) -> void:
  var split: Vector2 = Vector2(PrintLook.print_setting('split_across'), PrintLook.print_setting('split_down'))
  var padding: float = PrintLook.print_setting('padding')
  var new_layout: Layout = PrintLook.print_setting('screen_layout') as Layout
  if split == _split and padding == _padding and new_layout == layout and size == _laid_out_size:
    return
  layout = new_layout
  _split = split
  _padding = padding
  _laid_out_size = size
  var rects: Dictionary = section_rects(size, split, padding, layout)
  for section_name: String in SECTIONS:
    var node: Control = get_node(section_name)
    node.position = rects[section_name].position
    node.size = rects[section_name].size
  sections_changed.emit()


## A section's node: 'Corridor', 'Items', 'Portraits' or 'Info'.
func section(section_name: String) -> Control:
  return get_node(section_name)


## Each section's rectangle (section name -> Rect2) on a screen of `screen_size`, split at `split` and
## with `padding` taken off every side, in `section_layout`. Positions and sizes are whole pixels.
static func section_rects(screen_size: Vector2, split: Vector2, padding: float, section_layout: Layout = Layout.PORTRAITS_LOWER_LEFT) -> Dictionary:
  split = split.clamp(Vector2.ZERO, screen_size).round()
  var parts: Dictionary = {
    'Corridor': Rect2(Vector2.ZERO, split),
    'Items': Rect2(split.x, 0.0, screen_size.x - split.x, split.y),
    'Portraits': Rect2(0.0, split.y, split.x, screen_size.y - split.y),
    'Info': Rect2(split, screen_size - split),
  }
  if section_layout == Layout.PORTRAITS_ABOVE_ITEMS:
    parts['Corridor'] = Rect2(0.0, 0.0, split.x, screen_size.y)
    parts['Portraits'] = parts['Items']
  var rects: Dictionary = {}
  for section_name: String in parts:
    var part: Rect2 = parts[section_name]
    var inset: Rect2 = part.grow(-round(padding))
    inset.size = inset.size.max(Vector2.ZERO)
    rects[section_name] = inset
  return rects


## Where the last fold in each direction sits with follow layout on, in window pixels (the space
## shaders see as FRAGCOORD) of `viewport`: past the corridor section's right and bottom edges by its
## distance from the left and top of the screen, which on the default layout is the split point
## (docs/systems/background_wear.md). The same on every screen, so the menus' folds match the run's.
static func fold_point_on_screen(viewport: Viewport) -> Vector2:
  var canvas: Vector2 = viewport.get_visible_rect().size
  var split: Vector2 = Vector2(PrintLook.print_setting('split_across'), PrintLook.print_setting('split_down'))
  var rects: Dictionary = section_rects(canvas, split, PrintLook.print_setting('padding'), PrintLook.print_setting('screen_layout'))
  var corridor: Rect2 = rects['Corridor']
  return viewport.get_final_transform() * (corridor.position * 2.0 + corridor.size)
