class_name LookPanel
extends PanelContainer
## The look panel (docs/systems/corridor_look.md), toggled with F2 by `DebugPanels`. One section
## per effect in corridor_look.gdshader, built from the shader's uniform groups, then sections for
## the corridor's light and its camera Environment. The background wear is in the F3 print panel
## (`PrintPanel`, which extends this). Every change applies at once to what is on screen. Looks are
## saved to and loaded from `DebugPanelsAutoload.LOOK_DIR`.

const SECTION_SCENE: PackedScene = preload('res://src/debug/look_section.tscn')
const SLIDER_ROW_SCENE: PackedScene = preload('res://src/debug/look_slider_row.tscn')
const CHECK_ROW_SCENE: PackedScene = preload('res://src/debug/look_check_row.tscn')
const COLOUR_ROW_SCENE: PackedScene = preload('res://src/debug/look_colour_row.tscn')
const OPTION_ROW_SCENE: PackedScene = preload('res://src/debug/look_option_row.tscn')
const CORRIDOR_SCENE: String = 'res://src/scenes/corridors/corridor_3d.tscn'

## Corridor exports shown in the Light section: property -> [min, max, step] ([] for a switch).
const CORRIDOR_PROPERTIES: Dictionary = {
  'light_range': [2.0, 40.0, 0.1],
  'light_energy': [0.0, 4.0, 0.01],
  'light_attenuation': [0.0, 4.0, 0.01],
  'flicker_amount': [0.0, 1.0, 0.01],
  'flicker_speed': [0.0, 30.0, 0.1],
  'hit_lights_on': [],
  'hit_light_energy': [0.0, 16.0, 0.01],
  'hit_light_range': [0.5, 20.0, 0.1],
  'hit_light_duration': [0.05, Balance.DELIVERY_VISUAL_HOLD, 0.01],
  'hit_light_distance': [0.0, 3.0, 0.01],
  'fov': [30.0, 110.0, 1.0],
  'alpha_scissor_threshold': [0.0, 1.0, 0.01],
}
## Environment properties shown in the Environment section: property -> [min, max, step] ([] for a
## switch or a colour).
const ENVIRONMENT_PROPERTIES: Dictionary = {
  'glow_enabled': [],
  'glow_intensity': [0.0, 8.0, 0.01],
  'glow_strength': [0.0, 2.0, 0.01],
  'glow_bloom': [0.0, 1.0, 0.01],
  'glow_hdr_threshold': [0.0, 4.0, 0.01],
  'fog_enabled': [],
  'fog_light_color': [],
  'fog_density': [0.0, 0.5, 0.001],
  'tonemap_exposure': [0.0, 4.0, 0.01],
}

var _built: bool = false

@onready var _sections: VBoxContainer = $Rows/Scroll/Sections
@onready var _name_edit: LineEdit = $Rows/SaveRow/NameEdit
@onready var _save_button: Button = $Rows/SaveRow/SaveButton
@onready var _load_option: OptionButton = $Rows/LoadRow/LoadOption
@onready var _reset_button: Button = $Rows/LoadRow/ResetButton


func _ready() -> void:
  _save_button.pressed.connect(_on_save_pressed)
  _load_option.item_selected.connect(_on_look_selected)
  _reset_button.pressed.connect(_on_reset_pressed)


func _exit_tree() -> void:
  _clear_sections()


## The corridor scene's own values for the Light and Environment properties, as
## [corridor property -> value, environment property -> value].
static func scene_values() -> Array[Dictionary]:
  var corridor: Corridor3D = (load(CORRIDOR_SCENE) as PackedScene).instantiate() as Corridor3D
  var environment: Environment = (corridor.get_node('SubViewport/Camera') as Camera3D).environment
  var corridor_values: Dictionary = {}
  var environment_values: Dictionary = {}
  for property: String in CORRIDOR_PROPERTIES:
    corridor_values[property] = corridor.get(property)
  for property: String in ENVIRONMENT_PROPERTIES:
    environment_values[property] = environment.get(property)
  corridor.free()
  return [corridor_values, environment_values]


## Build the controls the first time the panel opens; list the saved looks every time.
func open() -> void:
  if not _built:
    rebuild()
  _list_looks()


## After settings change outside the panel: rebuild now if the panel is showing, otherwise on the
## next open.
func refresh() -> void:
  if is_visible_in_tree():
    rebuild()
  else:
    _built = false


## Rebuild every section from the current settings.
func rebuild() -> void:
  _built = true
  _clear_sections()
  _build_shader_sections(DebugPanels.world_material, DebugPanels.look_defaults())
  var values: Array[Dictionary] = scene_values()
  _build_property_section('Light', CORRIDOR_PROPERTIES, values[0], DebugPanels.corridor_settings)
  _build_property_section('Environment', ENVIRONMENT_PROPERTIES, values[1], DebugPanels.environment_settings)


# One section per uniform group that has a setting in `defaults`; uniforms before the first group, or
# missing from `defaults` (the palette clamp's, the mark colours, an included shader's settings shown
# elsewhere), are skipped, as other code sets them. A group with no settings gets no section.
func _build_shader_sections(look_material: ShaderMaterial, defaults: Dictionary) -> void:
  var section: LookSection = null
  var group: String = ''
  for entry: Dictionary in look_material.shader.get_shader_uniform_list(true):
    var uniform: String = entry['name']
    if entry['usage'] & PROPERTY_USAGE_GROUP:
      group = uniform
      section = null
      continue
    if group == '':
      continue
    # The palette clamp's switch is shared with the F1 panel.
    if uniform == 'dithering':
      section = section if section != null else _add_section(group.capitalize())
      section.set_switch(DebugPanels.is_dithering(), DebugPanels.set_dithering)
      continue
    if not defaults.has(uniform):
      continue
    section = section if section != null else _add_section(group.capitalize())
    var value: Variant = look_material.get_shader_parameter(uniform)
    if value == null:
      value = defaults[uniform]
    var set_value: Callable = func(new_value: Variant) -> void: look_material.set_shader_parameter(uniform, new_value)
    if uniform == group + '_on':
      section.set_switch(value, set_value)
      continue
    var label: String = uniform.trim_prefix(group + '_').capitalize()
    var limits: Array = []
    if entry['type'] == TYPE_FLOAT:
      for part: String in (entry['hint_string'] as String).split(','):
        limits.append(part.to_float())
    elif entry['type'] == TYPE_INT and entry['hint'] == PROPERTY_HINT_ENUM:
      limits = Array((entry['hint_string'] as String).split(','))
    section.add_row(_make_row(label, value, limits, set_value))


func _build_property_section(title: String, properties: Dictionary, scene: Dictionary, settings: Dictionary) -> void:
  var section: LookSection = _add_section(title)
  for property: String in properties:
    var value: Variant = settings.get(property, scene[property])
    var set_value: Callable = func(new_value: Variant) -> void:
      settings[property] = new_value
      DebugPanels.apply_corridor_settings()
    section.add_row(_make_row(property.capitalize(), value, properties[property], set_value))


func _add_section(title: String) -> LookSection:
  var section: LookSection = SECTION_SCENE.instantiate() as LookSection
  section.setup(title)
  _sections.add_child(section)
  return section


# A slider for a number, a dropdown for a choice (an int with option names in `limits`), a switch for
# a bool, a colour button for a colour.
func _make_row(label: String, value: Variant, limits: Array, changed: Callable) -> LookRow:
  var scene: PackedScene = SLIDER_ROW_SCENE
  if value is int:
    scene = OPTION_ROW_SCENE
  elif value is bool:
    scene = CHECK_ROW_SCENE
  elif value is Color:
    scene = COLOUR_ROW_SCENE
  var row: LookRow = scene.instantiate() as LookRow
  row.setup(label, value, limits)
  row.value_changed.connect(changed)
  return row


# Freed at once rather than queued, so a rebuild leaves no removed nodes waiting for the next frame.
# Safe because no control inside a section rebuilds the panel.
func _clear_sections() -> void:
  if _sections == null:
    return
  for section: Node in _sections.get_children():
    _sections.remove_child(section)
    section.free()


# The folder this panel's saved looks live in, and how it saves, loads and resets them. The print panel
# overrides these, so the two panels keep separate saved looks.
func _look_dir() -> String:
  return DebugPanelsAutoload.LOOK_DIR


func _save_look(path: String) -> void:
  DebugPanels.save_look(path)


func _load_look(path: String) -> bool:
  return DebugPanels.load_look(path)


func _reset_look() -> void:
  DebugPanels.reset_look()


func _list_looks() -> void:
  _load_option.clear()
  _load_option.add_item('Load a look...')
  var dir: DirAccess = DirAccess.open(_look_dir())
  if dir == null:
    return
  for file: String in dir.get_files():
    if file.get_extension() == 'cfg':
      _load_option.add_item(file.get_basename())
  _load_option.select(0)


func _on_save_pressed() -> void:
  var look_name: String = _name_edit.text.strip_edges().to_snake_case().validate_filename()
  if look_name == '':
    return
  _save_look(_look_dir().path_join(look_name + '.cfg'))
  _name_edit.release_focus()
  _list_looks()


func _on_look_selected(index: int) -> void:
  if index <= 0:
    return
  var look_name: String = _load_option.get_item_text(index)
  if _load_look(_look_dir().path_join(look_name + '.cfg')):
    _name_edit.text = look_name
    rebuild()


func _on_reset_pressed() -> void:
  _reset_look()
  rebuild()
