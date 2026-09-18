extends GutTest
## The corridor look: the look shader's defaults, the Corridor tab built from its uniform groups,
## writing and reading the corridor look part of a preset, and corridor settings applied to live
## corridors (docs/systems/corridor_look.md).

const CORRIDOR_SCENE: PackedScene = preload('res://src/scenes/corridors/corridor_3d.tscn')

var _nodes: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for node: Node in _nodes:
    if is_instance_valid(node):
      node.free()
  _nodes.clear()
  TestCleanup.reset_all_managers()


func _corridor() -> Corridor3D:
  var corridor: Corridor3D = CORRIDOR_SCENE.instantiate() as Corridor3D
  add_child(corridor)
  _nodes.append(corridor)
  return corridor


func _panel() -> LookPanel:
  return DebugPanels.get_node('PanelLayer/Panel/Rows/Tabs/Corridor') as LookPanel


func test_defaults_are_read_from_the_shader_code() -> void:
  var defaults: Dictionary = DebugPanels.look_defaults()
  assert_eq(defaults['warp_on'], false, 'a switch')
  assert_almost_eq(defaults['warp_amount'], 0.08, 0.0001, 'a number')
  assert_eq(defaults['grade_tint'], Color(1.0, 1.0, 1.0), 'a colour')
  assert_eq(defaults['dither_pattern'], 0, 'a choice, read from the palette clamp include')
  assert_false(defaults.has('colour_count'), 'the palette uniforms set from the Palettes tab are not look settings')
  assert_false(defaults.has('dithering'), 'the shared dithering switch is not a look setting')


func _section(title: String) -> LookSection:
  for section: Node in _panel().get_node('Scroll/Sections').get_children():
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


func _group_count(shader: Shader) -> int:
  var groups: int = 0
  for entry: Dictionary in shader.get_shader_uniform_list(true):
    if entry['usage'] & PROPERTY_USAGE_GROUP:
      groups += 1
  return groups


func test_panel_has_a_section_per_effect_plus_light_and_environment() -> void:
  var panel: LookPanel = _panel()
  panel.rebuild()
  var groups: int = _group_count(DebugPanels.world_material.shader)
  var sections: Node = panel.get_node('Scroll/Sections')
  assert_gt(groups, 0, 'the look shader has effect groups')
  assert_eq(sections.get_child_count(), groups + 2, 'one section per effect, then Light and Environment')
  assert_null(_section('Background Specks'), 'the background wear is in the Print tab')


func test_background_defaults_leave_out_the_mark_colours() -> void:
  var defaults: Dictionary = PrintLook.background_defaults()
  assert_eq(defaults['background_faded_areas_on'], true, 'the wear the owner kept is on by default')
  assert_false(defaults.has('background_scratches_on'), 'scratches were removed')
  assert_eq(defaults['background_specks_colour'], 2, 'a choice')
  assert_false(defaults.has('wear_dark_colour'), 'the mark colours come from Colours, not presets')


func test_screen_background_draws_through_the_background_material() -> void:
  var background: ScreenBackground = ScreenBackground.new()
  background.colour_name = 'UI_BACKGROUND'
  add_child(background)
  _nodes.append(background)
  assert_eq(background.material, PrintLook.background_material, 'uses the shared material')
  assert_eq(PrintLook.background_material.get_shader_parameter('wear_light_colour'), Colours.UI_BACKGROUND_WEAR_LIGHT,
    'the light mark colour comes from Colours')


func test_folds_are_shown_only_while_a_run_screen_background_is_in_the_tree() -> void:
  var menu: ScreenBackground = ScreenBackground.new()
  menu.colour_name = 'UI_BACKGROUND'
  add_child(menu)
  _nodes.append(menu)
  assert_eq(PrintLook.background_material.get_shader_parameter('folds_shown'), false, 'no folds on a menu')
  var run: ScreenBackground = ScreenBackground.new()
  run.colour_name = 'UI_BACKGROUND'
  run.folds_shown = true
  add_child(run)
  assert_eq(PrintLook.background_material.get_shader_parameter('folds_shown'), true, 'folds during a run')
  remove_child(run)
  run.free()
  assert_eq(PrintLook.background_material.get_shader_parameter('folds_shown'), false, 'none after the run screen leaves')
  assert_false(PrintLook.background_defaults().has('folds_shown'), 'not a look setting')


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
  PrintLook.background_material.set_shader_parameter('background_creases_on', false)
  var file: ConfigFile = ConfigFile.new()
  DebugPanels.write_corridor_look(file)
  PrintLook.background_material.set_shader_parameter('background_creases_on', true)
  DebugPanels.reset_settings()
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_on'), false, 'reset turns the effect off')
  assert_true(DebugPanels.corridor_settings.is_empty(), 'reset clears the corridor settings')
  DebugPanels.read_corridor_look(file)
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_on'), true, 'switch restored')
  assert_almost_eq(DebugPanels.world_material.get_shader_parameter('grade_contrast'), 1.7, 0.001, 'number restored')
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_tint'), Color(0.5, 0.25, 0.1), 'colour restored')
  assert_eq(DebugPanels.corridor_settings.get('light_range'), 12.0, 'corridor setting restored')
  assert_eq(DebugPanels.environment_settings.get('fog_enabled'), true, 'environment setting restored')
  assert_eq(PrintLook.background_material.get_shader_parameter('background_creases_on'), true,
    'the corridor look part does not hold the background wear, which belongs to the print part')


func test_loading_applies_to_corridors_on_screen() -> void:
  var corridor: Corridor3D = _corridor()
  DebugPanels.corridor_settings['light_energy'] = 2.0
  var file: ConfigFile = ConfigFile.new()
  DebugPanels.write_corridor_look(file)
  DebugPanels.reset_settings()
  var scene_energy: float = LookPanel.scene_values()[0]['light_energy']
  assert_almost_eq(corridor.light_energy, scene_energy, 0.001, 'reset returns the corridor to its scene value')
  DebugPanels.read_corridor_look(file)
  assert_almost_eq(corridor.light_energy, 2.0, 0.001, 'the loaded look reaches the live corridor')
