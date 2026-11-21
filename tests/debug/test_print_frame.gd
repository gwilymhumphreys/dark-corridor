extends GutTest
## The print frame: the tabs that show its settings, the print settings in presets, and `PrintFrame` showing the
## border and overlay (docs/systems/print_frame.md).

const COMBAT_VIEW_SCENE: PackedScene = preload('res://src/scenes/combat/combat_view_framed.tscn')

var _nodes: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for node: Node in _nodes:
    if is_instance_valid(node):
      node.free()
  _nodes.clear()
  TestCleanup.reset_all_managers()


func _panel(tab_name: String) -> LookPanel:
  var panel: LookPanel = DebugPanels.get_node('PanelLayer/Panel/Rows/Tabs/' + tab_name) as LookPanel
  panel.rebuild()
  return panel


func _section_titles(panel: LookPanel) -> Array[String]:
  var titles: Array[String] = []
  for section: Node in panel.get_node('Scroll/Sections').get_children():
    titles.append((section.get_node('Header/Title') as Button).text)
  return titles


func _view() -> Control:
  var view: Control = COMBAT_VIEW_SCENE.instantiate() as Control
  add_child(view)
  _nodes.append(view)
  return view


func test_defaults_match_the_owners_saved_look() -> void:
  var defaults: Dictionary = PrintLook.print_defaults()
  assert_eq(defaults['print_border_on'], false, 'the border is off')
  assert_eq(defaults['corridor_wear_on'], true, 'wear over the corridor is on')
  assert_eq(defaults['corridor_worn_edge_on'], true, 'the worn corridor edge is on')
  assert_false(defaults.has('rect_size'), 'sizes set by PrintFrame are not look settings')
  assert_false(defaults.has('background_specks_on'), 'the overlay copy of the background wear is not listed twice')
  assert_eq(PrintLook.background_defaults()['background_folds_on'], true, 'folds are on')


func test_wear_tab_has_every_kind_of_wear() -> void:
  var titles: Array[String] = _section_titles(_panel('Wear'))
  assert_true(titles.has('Background Specks'), 'background wear')
  assert_true(titles.has('Background Folds'), 'the folds')
  assert_true(titles.has('Panel Specks (item borders and other panels)'), 'panel wear')
  assert_true(titles.has('Picture Specks (icons, portraits, bars)'), 'picture wear')
  assert_true(titles.has('Print Border'), 'the border')
  assert_true(titles.has('Corridor Wear'), 'wear over the corridor')
  assert_true(titles.has('Corridor Worn Edge'), 'the worn corridor edge')
  assert_true(titles.has('Board Grid'), 'the pencil grid')
  assert_false(titles.has('Highlight Border (hover and press)'), 'the hover border is on the Motion tab')


func test_layout_tab_has_the_spacing_and_token_sections() -> void:
  assert_eq(_section_titles(_panel('Layout')), ['Spacing', 'Token placement', 'Token shadow', 'Token fill', 'Portraits', 'Character panels', 'Item levels', 'Map'] as Array[String])


func test_effects_and_motion_tabs_hold_the_effects_and_animations() -> void:
  assert_eq(_section_titles(_panel('Effects')), ['Combat effects (projectiles, impacts, damage numbers)', 'Hit effect trials', 'Hit lights', 'Paper burn'] as Array[String])
  var motion: Array[String] = _section_titles(_panel('Motion'))
  for title: String in ['Hover and press timing', 'Encounter cards', 'Character photos', 'Page turn', 'Reward spin', 'Reward reel']:
    assert_true(motion.has(title), 'the Motion tab has %s' % title)


func test_every_print_setting_on_a_tab_is_saved_by_presets() -> void:
  for sections: Dictionary in [LayoutPanel.SECTIONS, EffectsPanel.PAPER_BURN_SETTINGS, MotionPanel.ANIMATION_SECTIONS, MotionPanel.REWARD_SPIN_SECTIONS]:
    for title: String in sections:
      for setting: String in sections[title]:
        assert_true(PrintLookAutoload.PRINT_SETTING_DEFAULTS.has(setting), '%s is a print setting, so presets save it' % setting)


func test_instance_uniforms_are_not_print_settings() -> void:
  assert_false(PrintLook.print_defaults().has('underline'), 'the grid underline is set per node')


func test_save_then_load_restores_the_print_look() -> void:
  PrintLook.set_print_value('print_border_on', true)
  PrintLook.set_print_value('corridor_worn_edge_width', 50.0)
  PrintLook.set_print_value('padding', 70.0)
  var file: ConfigFile = ConfigFile.new()
  PrintLook.write_print_look(file)
  DebugPanels.reset_settings()
  assert_eq(PrintLook.border_material.get_shader_parameter('print_border_on'), false, 'reset turns the border off')
  assert_eq(PrintLook.print_setting('padding'), PrintLookAutoload.PRINT_SETTING_DEFAULTS['padding'],
    'reset returns the padding to its default')
  PrintLook.read_print_look(file)
  assert_eq(PrintLook.border_material.get_shader_parameter('print_border_on'), true, 'border switch restored')
  assert_almost_eq(PrintLook.overlay_material.get_shader_parameter('corridor_worn_edge_width'), 50.0, 0.001,
    'overlay number restored')
  assert_eq(PrintLook.print_setting('padding'), 70.0, 'layout setting restored')


func test_print_and_corridor_looks_are_separate() -> void:
  DebugPanels.world_material.set_shader_parameter('grade_on', true)
  PrintLook.set_print_value('print_border_on', true)
  var file: ConfigFile = ConfigFile.new()
  PrintLook.write_print_look(file)
  PrintLook.reset_print_look()
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_on'), true, 'resetting the print look keeps the corridor look')
  DebugPanels.world_material.set_shader_parameter('grade_on', false)
  PrintLook.read_print_look(file)
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_on'), false, 'the print part does not hold the corridor look')
  DebugPanels.reset_look()
  assert_eq(PrintLook.border_material.get_shader_parameter('print_border_on'), true, 'resetting the corridor look keeps the print look')


func test_the_corridor_sits_evenly_either_side_of_the_left_half() -> void:
  # The fold is drawn down the middle of the screen, so the corridor has the same margin from the
  # screen's edge and from the fold.
  PrintLook.print_settings['padding'] = 30.0
  var view: Control = _view()
  var corridor: Rect2 = view.get_node('Corridor/CorridorPanel').get_global_rect()
  assert_eq(corridor.position.x, 30.0, 'the corridor starts the padding in from the screen edge')
  assert_eq(corridor.position.x * 2.0 + corridor.size.x, view.size.x * 0.5, 'and ends the padding short of the fold')


func test_frame_shows_the_border_and_overlay_only_when_on() -> void:
  var view: Control = _view()
  var frame: PrintFrame = view.get_node('Corridor/PrintFrame') as PrintFrame
  var border: ColorRect = view.get_node('Corridor/PrintFrame/Border')
  var overlay: ColorRect = view.get_node('Corridor/CorridorOverlay')
  PrintLook.set_print_value('corridor_wear_on', false)
  PrintLook.set_print_value('corridor_worn_edge_on', false)
  frame._process(0.0)
  assert_false(border.visible, 'no border while it is off')
  assert_false(overlay.visible, 'no overlay while its effects are off')
  PrintLook.set_print_value('print_border_on', true)
  PrintLook.set_print_value('corridor_worn_edge_on', true)
  frame._process(0.0)
  assert_true(border.visible, 'the border shows')
  assert_true(overlay.visible, 'the overlay shows')
  var corridor: Control = view.get_node('Corridor/CorridorPanel')
  assert_true(border.get_rect().encloses(corridor.get_rect()), 'the border surrounds the corridor')
  assert_eq(overlay.get_rect(), corridor.get_rect(), 'the overlay covers the corridor')


