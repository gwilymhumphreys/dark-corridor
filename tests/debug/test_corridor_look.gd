extends GutTest
## The corridor look: the look shader's defaults, the look panel built from its uniform groups,
## saving and loading looks, and corridor settings applied to live corridors
## (docs/systems/corridor_look.md).

const CORRIDOR_SCENE: PackedScene = preload('res://src/scenes/corridors/corridor_3d.tscn')
const LOOK_PATH: String = 'user://test_looks/look.cfg'

var _nodes: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for node: Node in _nodes:
    if is_instance_valid(node):
      node.free()
  _nodes.clear()
  DirAccess.remove_absolute(LOOK_PATH)
  DirAccess.remove_absolute(LOOK_PATH.get_base_dir())
  TestCleanup.reset_all_managers()


func _corridor() -> Corridor3D:
  var corridor: Corridor3D = CORRIDOR_SCENE.instantiate() as Corridor3D
  add_child(corridor)
  _nodes.append(corridor)
  return corridor


func _panel() -> LookPanel:
  return DebugPanels.get_node('LookLayer/LookPanel') as LookPanel


func test_defaults_are_read_from_the_shader_code() -> void:
  var defaults: Dictionary = DebugPanels.look_defaults()
  assert_eq(defaults['warp_on'], false, 'a switch')
  assert_almost_eq(defaults['warp_amount'], 0.08, 0.0001, 'a number')
  assert_eq(defaults['grade_tint'], Color(1.0, 1.0, 1.0), 'a colour')
  assert_eq(defaults['dither_pattern'], 0, 'a choice, read from the palette clamp include')
  assert_false(defaults.has('colour_count'), 'the palette uniforms set from the F1 panel are not look settings')
  assert_false(defaults.has('dithering'), 'the shared dithering switch is not a look setting')


func _section(title: String) -> LookSection:
  for section: Node in _panel().get_node('Rows/Scroll/Sections').get_children():
    if (section.get_node('Header/Title') as Button).text == title:
      return section as LookSection
  return null


func test_dithering_section_switch_and_pattern_dropdown() -> void:
  _panel().rebuild()
  var dithering: LookSection = _section('Dithering')
  assert_not_null(dithering, 'the palette clamp has its own section')
  (dithering.get_node('Header/Switch') as CheckButton).button_pressed = true
  assert_true(DebugPanels.is_dithering(), 'the header switch turns dithering on for both clamps')
  var pattern: LookRow = dithering.get_node('Rows').get_child(0) as LookRow
  var option: OptionButton = pattern.get_node('Option') as OptionButton
  assert_eq(option.item_count, 4, 'every dither pattern is listed')
  option.select(2)
  option.item_selected.emit(2)
  assert_eq(DebugPanels.world_material.get_shader_parameter('dither_pattern'), 2, 'the dropdown sets the pattern')
  assert_not_null(DebugPanels.world_material.get_shader_parameter('dither_noise'), 'the blue noise texture is set')


func test_panel_has_a_section_per_effect_plus_light_and_environment() -> void:
  var panel: LookPanel = _panel()
  panel.rebuild()
  var groups: int = 0
  for entry: Dictionary in DebugPanels.world_material.shader.get_shader_uniform_list(true):
    if entry['usage'] & PROPERTY_USAGE_GROUP:
      groups += 1
  var sections: Node = panel.get_node('Rows/Scroll/Sections')
  assert_gt(groups, 0, 'the shader has effect groups')
  assert_eq(sections.get_child_count(), groups + 2, 'one section per effect, then Light and Environment')


func test_a_slider_changes_the_shader_setting() -> void:
  var panel: LookPanel = _panel()
  panel.rebuild()
  var warp: LookSection = _section('Warp')
  (warp.get_node('Header/Switch') as CheckButton).button_pressed = true
  assert_eq(DebugPanels.world_material.get_shader_parameter('warp_on'), true, 'the header switch turns the effect on')
  var row: LookRow = warp.get_node('Rows').get_child(0) as LookRow
  (row.get_node('Slider') as HSlider).value = 0.2
  assert_almost_eq(DebugPanels.world_material.get_shader_parameter('warp_amount'), 0.2, 0.001, 'the slider sets the uniform')


func test_corridor_settings_apply_to_its_own_environment() -> void:
  var first: Corridor3D = _corridor()
  var second: Corridor3D = _corridor()
  first.apply_settings({'light_energy': 1.5}, {'glow_enabled': true})
  assert_almost_eq(first.light_energy, 1.5, 0.001, 'a corridor export is set')
  assert_true(first.environment().glow_enabled, 'an environment property is set')
  assert_false(second.environment().glow_enabled, 'other corridors keep their own environment')
  assert_true(first.is_in_group(Corridor3D.GROUP), 'corridors join the group the panel changes')


func test_save_then_load_restores_the_look() -> void:
  DebugPanels.world_material.set_shader_parameter('grade_on', true)
  DebugPanels.world_material.set_shader_parameter('grade_contrast', 1.7)
  DebugPanels.world_material.set_shader_parameter('grade_tint', Color(0.5, 0.25, 0.1))
  DebugPanels.corridor_settings['light_range'] = 12.0
  DebugPanels.environment_settings['fog_enabled'] = true
  assert_eq(DebugPanels.save_look(LOOK_PATH), OK, 'the look is saved')
  DebugPanels.reset_settings()
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_on'), false, 'reset turns the effect off')
  assert_true(DebugPanels.corridor_settings.is_empty(), 'reset clears the corridor settings')
  assert_true(DebugPanels.load_look(LOOK_PATH), 'the look is loaded')
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_on'), true, 'switch restored')
  assert_almost_eq(DebugPanels.world_material.get_shader_parameter('grade_contrast'), 1.7, 0.001, 'number restored')
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_tint'), Color(0.5, 0.25, 0.1), 'colour restored')
  assert_eq(DebugPanels.corridor_settings.get('light_range'), 12.0, 'corridor setting restored')
  assert_eq(DebugPanels.environment_settings.get('fog_enabled'), true, 'environment setting restored')


func test_loading_applies_to_corridors_on_screen() -> void:
  var corridor: Corridor3D = _corridor()
  DebugPanels.corridor_settings['light_energy'] = 2.0
  DebugPanels.save_look(LOOK_PATH)
  DebugPanels.reset_settings()
  var scene_energy: float = LookPanel.scene_values()[0]['light_energy']
  assert_almost_eq(corridor.light_energy, scene_energy, 0.001, 'reset returns the corridor to its scene value')
  DebugPanels.load_look(LOOK_PATH)
  assert_almost_eq(corridor.light_energy, 2.0, 0.001, 'the loaded look reaches the live corridor')
