class_name ColoursPanel
extends LookPanel
## The Colours tab of the debug panel (docs/systems/interface_palette.md), opened with F1 by
## `DebugPanels`. At the top, rows from its scene that `DebugPanels` runs: the main palette list with
## a strip of its colours, the colour matching and the mechanic palette list. Below, sections built
## here: the darkest colour setting and the snap switches, one section per group of interface colours
## (`MainPalette.SECTIONS`), each row a brightness slider with a square showing the colour it landed
## on, and the mechanic colours, each a colour picker that writes the custom mechanic palette.

const BRIGHTNESS_ROW_SCENE: PackedScene = preload('res://src/debug/look_brightness_row.tscn')
## The darkest colour setting's choices, in `MainPalette.Darkest` order.
const DARKEST_NAMES: Array = ['Off', 'Add a darker colour', 'Replace the darkest colour']
## The size of each colour in the strip under the main palette list.
const STRIP_COLOUR_SIZE: Vector2 = Vector2(36, 36)

var _brightness_rows: Dictionary = {}   # interface colour -> its LookRow
var _mechanic_rows: Dictionary = {}     # mechanic colour -> its LookRow

@onready var _strip: HFlowContainer = $PaletteRows/Strip


func _ready() -> void:
  DebugPanels.colours_changed.connect(_on_colours_changed)


func _exit_tree() -> void:
  DebugPanels.colours_changed.disconnect(_on_colours_changed)
  super()


func rebuild() -> void:
  _built = true
  _clear_sections()
  _brightness_rows.clear()
  _mechanic_rows.clear()
  _build_main_section()
  for title: String in MainPalette.SECTIONS:
    var section: LookSection = _add_section(title)
    for variable: String in MainPalette.SECTIONS[title]:
      var row: LookRow = BRIGHTNESS_ROW_SCENE.instantiate() as LookRow
      row.setup(_label(variable), MainPalette.brightness(variable), [0.0, 1.0, 0.01])
      row.value_changed.connect(func(level: float) -> void: DebugPanels.set_palette_setting(variable.to_lower(), level))
      section.add_row(row)
      _brightness_rows[variable] = row
  var mechanics: LookSection = _add_section('Mechanic colours')
  for variable: String in MechanicPalette.NAMES:
    var row: LookRow = _make_row(_label(variable), Colours.named(variable), [],
      func(colour: Color) -> void: MechanicPalette.write_custom(variable, colour))
    mechanics.add_row(row)
    _mechanic_rows[variable] = row
  _on_colours_changed()


# The darkest colour setting and the snap switches, open, since they are the main palette's own.
func _build_main_section() -> void:
  var section: LookSection = _add_section('Main palette')
  section.set_open(true)
  section.add_row(_make_row('Darkest colour', DebugPanels.darkest, DARKEST_NAMES,
    func(choice: int) -> void: DebugPanels.set_palette_setting('darkest', choice)))
  section.add_row(_make_row('Darker colour', DebugPanels.darkest_colour, [],
    func(colour: Color) -> void: DebugPanels.set_palette_setting('darkest_colour', colour)))
  section.add_row(_make_row('Snap corridor', DebugPanels.snap_corridor, [],
    func(on: bool) -> void: DebugPanels.set_palette_setting('snap_corridor', on)))
  section.add_row(_make_row('Snap pictures', DebugPanels.snap_pictures, [],
    func(on: bool) -> void: DebugPanels.set_palette_setting('snap_pictures', on)))
  section.add_row(_make_row('Snap effects', DebugPanels.snap_effects, [],
    func(on: bool) -> void: DebugPanels.set_palette_setting('snap_effects', on)))


# 'UI_TEXT_DIM' -> 'Text Dim', 'HP_BAR_FILL' -> 'Hp Bar Fill'.
func _label(variable: String) -> String:
  return variable.trim_prefix('UI_').to_lower().capitalize()


# Show the colours now in use: the main palette strip, the colour each brightness landed on and the
# live mechanic colours.
func _on_colours_changed() -> void:
  if not _built:
    return
  _show_strip()
  for variable: String in _brightness_rows:
    (_brightness_rows[variable] as LookRow).show_swatch(Colours.named(variable))
  for variable: String in _mechanic_rows:
    (_mechanic_rows[variable] as LookRow).show_colour(Colours.named(variable))


# One square per main palette colour, dark to light. Freed at once, as the sections are.
func _show_strip() -> void:
  for child: Node in _strip.get_children():
    _strip.remove_child(child)
    child.free()
  var colours: Array[Color] = []
  colours.assign(DebugPanels.main_colours())
  colours.sort_custom(func(a: Color, b: Color) -> bool: return PaletteLoader.to_oklab(a).x < PaletteLoader.to_oklab(b).x)
  for colour: Color in colours:
    var square: ColorRect = ColorRect.new()
    square.color = colour
    square.custom_minimum_size = STRIP_COLOUR_SIZE
    square.mouse_filter = Control.MOUSE_FILTER_PASS
    square.tooltip_text = '#' + colour.to_html(false)
    _strip.add_child(square)
