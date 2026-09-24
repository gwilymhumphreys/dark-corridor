class_name LookPanel
extends VBoxContainer
## The corridor tab of the debug panel (docs/systems/corridor_look.md), opened with F2 by `DebugPanels`.
## One section per effect in corridor_look.gdshader, built from the shader's uniform groups, then
## sections for the corridor's light and its camera Environment. The background wear is in the print
## tab (`PrintPanel`, which extends this). Every change applies at once to what is on screen. The row
## at the top loads this part of the look from a preset (`PresetPartRow`).

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
  'tonemap_exposure': [0.0, 4.0, 0.01],
}
## Environment fog properties shown in the Fog section, in the same form. `fog_mode` is a choice, so
## its entry is the option names in order. The corridor scene's fog colour is nearly black, so
## turning fog on hides the far end of the corridor in darkness instead of grey.
const FOG_PROPERTIES: Dictionary = {
  'fog_enabled': [],
  'fog_mode': ['Exponential', 'Depth'],
  'fog_light_color': [],
  'fog_light_energy': [0.0, 4.0, 0.01],
  'fog_density': [0.0, 1.0, 0.001],
  'fog_aerial_perspective': [0.0, 1.0, 0.01],
  'fog_sky_affect': [0.0, 1.0, 0.01],
  'fog_height': [-8.0, 8.0, 0.1],
  'fog_height_density': [-8.0, 8.0, 0.01],
  'fog_depth_begin': [0.0, 40.0, 0.1],
  'fog_depth_end': [0.0, 40.0, 0.1],
  'fog_depth_curve': [0.0, 8.0, 0.01],
}

var _built: bool = false

@onready var _sections: VBoxContainer = $Scroll/Sections
## Null on a tab that is not a look preset part, so it has no "Take this part from" row (the Icons
## tab). `@onready` resolves before any `open()` override runs, so this must not assume the node.
@onready var _part_row: PresetPartRow = get_node_or_null('PartRow')


func _exit_tree() -> void:
  _clear_sections()


## Every Environment property the tab sets: the Environment section's and the Fog section's.
static func environment_properties() -> Dictionary:
  var properties: Dictionary = ENVIRONMENT_PROPERTIES.duplicate()
  properties.merge(FOG_PROPERTIES)
  return properties


## The corridor scene's own values for the Light and Environment properties, as
## [corridor property -> value, environment property -> value].
static func scene_values() -> Array[Dictionary]:
  var corridor: Corridor3D = (load(CORRIDOR_SCENE) as PackedScene).instantiate() as Corridor3D
  var environment: Environment = (corridor.get_node('SubViewport/Camera') as Camera3D).environment
  var corridor_values: Dictionary = {}
  var environment_values: Dictionary = {}
  for property: String in CORRIDOR_PROPERTIES:
    corridor_values[property] = corridor.get(property)
  for property: String in environment_properties():
    environment_values[property] = environment.get(property)
  corridor.free()
  return [corridor_values, environment_values]


## Build the controls the first time the tab opens; list the presets every time.
func open() -> void:
  if not _built:
    rebuild()
  if _part_row != null:
    _part_row.list_presets()


## After settings change outside the tab: rebuild now if the tab is showing, otherwise on the next
## open.
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
  _build_property_section('Fog', FOG_PROPERTIES, values[1], DebugPanels.environment_settings, 'fog_')


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
    # Each clamp's dithering switch is kept by `DebugPanels`, which Backspace and presets also set.
    # The corridor and the interface have one each.
    if uniform == 'dithering':
      if look_material == DebugPanels.world_material:
        section = section if section != null else _add_section(_section_title(group))
        section.set_switch(DebugPanels.is_dithering(), DebugPanels.set_dithering)
      elif look_material == InterfaceLook.material:
        section = section if section != null else _add_section(_section_title(group))
        section.set_switch(DebugPanels.is_interface_dithering(), DebugPanels.set_interface_dithering)
      continue
    if not defaults.has(uniform):
      continue
    section = section if section != null else _add_section(_section_title(group))
    var value: Variant = look_material.get_shader_parameter(uniform)
    if value == null:
      value = defaults[uniform]
    # The interface look has a second material for the interface elements that are not pictures, which
    # `InterfaceLook.set_setting` keeps in step.
    var set_value: Callable = func(new_value: Variant) -> void:
      if look_material == InterfaceLook.material:
        InterfaceLook.set_setting(uniform, new_value)
      else:
        look_material.set_shader_parameter(uniform, new_value)
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
    elif entry['type'] == TYPE_INT:
      # A whole-number range is a slider in steps of one (an int value would make a dropdown); the
      # shader still receives an int.
      var range_parts: PackedStringArray = (entry['hint_string'] as String).split(',')
      if range_parts.size() >= 2:
        limits = [range_parts[0].to_float(), range_parts[1].to_float(), 1.0]
      value = float(value)
      var set_float: Callable = set_value
      set_value = func(new_value: Variant) -> void: set_float.call(roundi(new_value))
    section.add_row(_make_row(label, value, limits, set_value))


# The heading for a uniform group's section. The print and interface tabs override this to say what their
# wear groups apply to.
func _section_title(group: String) -> String:
  return group.capitalize()


# `prefix` is dropped from each row's label, so the Fog section reads Density rather than Fog density.
func _build_property_section(title: String, properties: Dictionary, scene: Dictionary, settings: Dictionary,
    prefix: String = '') -> void:
  var section: LookSection = _add_section(title)
  for property: String in properties:
    var value: Variant = settings.get(property, scene[property])
    var set_value: Callable = func(new_value: Variant) -> void:
      settings[property] = new_value
      DebugPanels.apply_corridor_settings()
    section.add_row(_make_row(property.trim_prefix(prefix).capitalize(), value, properties[property], set_value))


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
