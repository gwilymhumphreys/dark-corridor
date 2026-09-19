class_name ControlFeedbackAutoload
extends Node
## Owns how an interactive control answers the pointer (docs/systems/control_feedback.md): the
## highlight material, the per-control canvas item it is drawn into, the four amounts pushed per
## control (hover, selected, press and the release pulse), and the timing settings. `UIJuice` drives
## buttons and cards; code that owns a selection or its own hover poll calls `set_selected` and
## `set_hover` itself. Registered as the `ControlFeedback` autoload, before `DebugPanels`, which keeps
## the Feedback tab and the `--feedback-set=` start-up argument.

const HIGHLIGHT_INCLUDE: ShaderInclude = preload('res://src/shaders/control_highlight.gdshaderinc')
## Highlight uniforms set from `Colours` or per control, so they are not look settings.
const COLOUR_UNIFORMS: Array[String] = [
  'highlight_colour',
  'fill_colour',
  'bloom_colour',
  'hover',
  'selected',
  'press',
  'bloom',
  'fill_shown',
]
## Feedback settings that are not shader uniforms (setting -> default), from the Feedback tab, presets
## and `--feedback-set=`. The press squash itself is a `UIJuice` preset (docs/systems/ui_juice.md).
const SETTING_DEFAULTS: Dictionary = {
  'hover_time': 0.12,     # seconds for the border and fill to come in, and to go back out
  'press_depth': 2.0,     # pixels a pressed control moves down, scaled by the juice preset
  'bloom_time': 0.16,     # seconds for the release pulse of extra ink to rise and fade
  'text_hover': 0.9,      # how far a button's text goes from its resting colour to the dark one on hover
  'text_press': 1.0,      # and while it is held
}

## Settings changed from their defaults (setting -> value); see `setting_value()`.
var settings: Dictionary = {}
## Holds every control at this much hover, for screenshots of the feedback (`--feedback-demo=`). 0 off.
var demo_amount: float = 0.0

var _defaults: Dictionary = {}       # highlight uniform -> default value, read from the include's code
var _highlighted: Dictionary = {}    # control canvas item RID -> true, for the controls given one


func _ready() -> void:
  _write_defaults()
  push_colours()
  get_tree().node_removed.connect(_on_node_removed)


## Give `control` a highlight, drawn behind its own content so its text and children stay on top.
## `fill` lights the whole body as well as drawing the border — true for a plain button, false for a
## control whose body is a picture. Calling it again on the same control only updates `fill`.
func attach(control: Control, fill: bool) -> void:
  _highlighted[control.get_canvas_item()] = true
  _set_amount(control, 'fill_shown', 1.0 if fill else 0.0)
  if demo_amount > 0.0:
    set_hover(control, demo_amount)


## Forget `control`'s highlight and put its amounts back to nothing. Called for you when the control
## leaves the tree; the canvas item itself belongs to `PrintLook`.
func detach(control: Control) -> void:
  if not _highlighted.has(control.get_canvas_item()):
    return
  for amount_name: String in ['hover', 'selected', 'press', 'bloom', 'fill_shown']:
    _set_amount(control, amount_name, 0.0)
  _highlighted.erase(control.get_canvas_item())


## Whether `control` has been given a highlight.
func has_highlight(control: Control) -> bool:
  return _highlighted.has(control.get_canvas_item())


## How many controls have one. Used by the tests.
func highlight_count() -> int:
  return _highlighted.size()


## How far the pointer feedback has come in, 0 to 1.
func set_hover(control: Control, amount: float) -> void:
  _set_amount(control, 'hover', amount)


## Whether `control` is the chosen one. Held whatever the pointer is doing, so a selected control
## stays marked while another is hovered.
func set_selected(control: Control, on: bool) -> void:
  _set_amount(control, 'selected', 1.0 if on else 0.0)


## How far the press has gone in, 0 to 1.
func set_press(control: Control, amount: float) -> void:
  _set_amount(control, 'press', amount)


## The release pulse of extra ink, 0 to 1.
func set_bloom(control: Control, amount: float) -> void:
  _set_amount(control, 'bloom', amount)


## Hold every control, and every control added later, at `amount` hover, for screenshots.
func set_demo(amount: float) -> void:
  demo_amount = amount
  for parent: RID in _highlighted:
    RenderingServer.canvas_item_set_instance_shader_parameter(PrintLook.panel_child(parent), 'hover', amount)


## Any feedback setting's current value: one of `SETTING_DEFAULTS`, changed or at its default, or a
## highlight uniform.
func setting_value(setting_name: String) -> Variant:
  if SETTING_DEFAULTS.has(setting_name):
    return settings.get(setting_name, SETTING_DEFAULTS[setting_name])
  return PrintLook.panel_material.get_shader_parameter(setting_name)


## The same, typed, for the times and amounts code reads.
func setting_float(setting_name: String) -> float:
  return float(setting_value(setting_name))


## Push `Colours.UI_HIGHLIGHT`, `UI_BUTTON_LIGHT` and `UI_PANEL_WEAR` into the material. Called at
## start, and by `DebugPanels` after an interface palette is applied or reset.
func push_colours() -> void:
  PrintLook.panel_material.set_shader_parameter('highlight_colour', Colours.UI_HIGHLIGHT)
  PrintLook.panel_material.set_shader_parameter('fill_colour', Colours.UI_BUTTON_LIGHT)
  PrintLook.panel_material.set_shader_parameter('bloom_colour', Colours.UI_PANEL_WEAR)


## Every highlight uniform with a default in its shader code (uniform name -> value), except
## `COLOUR_UNIFORMS`.
func defaults() -> Dictionary:
  if _defaults.is_empty():
    _defaults = PrintLookAutoload._uniform_defaults(HIGHLIGHT_INCLUDE.code, COLOUR_UNIFORMS)
  return _defaults


## Set a highlight uniform or a timing setting by name. Unknown names are ignored.
func set_setting(setting_name: String, value: Variant) -> void:
  if defaults().has(setting_name):
    PrintLook.panel_material.set_shader_parameter(setting_name, value)
  elif SETTING_DEFAULTS.has(setting_name):
    settings[setting_name] = value


## Every highlight effect back to its shader default, and every other setting too.
func reset() -> void:
  _write_defaults()
  settings.clear()


## Write the current feedback into a preset file: every highlight and every other setting.
func write_look(file: ConfigFile) -> void:
  for uniform: String in defaults():
    file.set_value('control_highlight', uniform, PrintLook.panel_material.get_shader_parameter(uniform))
  for setting_name: String in SETTING_DEFAULTS:
    file.set_value('control_settings', setting_name, setting_value(setting_name))


## Set the feedback from a preset file written by `write_look`, starting from the defaults. Settings
## the file leaves out keep their defaults.
func read_look(file: ConfigFile) -> void:
  reset()
  for section: String in ['control_highlight', 'control_settings']:
    if not file.has_section(section):
      continue
    for setting_name: String in file.get_section_keys(section):
      set_setting(setting_name, file.get_value(section, setting_name))


# The amounts ride on the canvas item the control's panel is drawn into, so the highlight is already
# behind the control's own text and children, and already knows the panel's rectangle.
func _set_amount(control: Control, amount_name: String, amount: float) -> void:
  RenderingServer.canvas_item_set_instance_shader_parameter(
    PrintLook.panel_child(control.get_canvas_item()), amount_name, amount)


# `PrintLook` frees the canvas item with the control; this only drops the record of it.
func _on_node_removed(node: Node) -> void:
  if node is CanvasItem:
    _highlighted.erase((node as CanvasItem).get_canvas_item())


# Every uniform is set explicitly, so a saved preset lists every one of them.
func _write_defaults() -> void:
  for uniform: String in defaults():
    PrintLook.panel_material.set_shader_parameter(uniform, defaults()[uniform])
