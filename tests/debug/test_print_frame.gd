extends GutTest
## The print frame: the print tab, the print settings in presets, and `PrintFrame` showing the
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


func _panel() -> PrintPanel:
  return DebugPanels.get_node('PanelLayer/Panel/Rows/Tabs/Print') as PrintPanel


func _background_panel() -> BackgroundPanel:
  return DebugPanels.get_node('PanelLayer/Panel/Rows/Tabs/Background') as BackgroundPanel


func _section_titles(panel: LookPanel = _panel()) -> Array[String]:
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


func test_print_panel_has_layout_border_and_overlay_sections() -> void:
  _panel().rebuild()
  var titles: Array[String] = _section_titles()
  assert_true(titles.has('Layout'), 'the padding and split point')
  assert_true(titles.has('Print Border'), 'the border')
  assert_true(titles.has('Corridor Wear'), 'wear over the corridor')
  assert_true(titles.has('Corridor Worn Edge'), 'the worn corridor edge')
  assert_false(titles.has('Background Specks'), 'background wear is in the Background tab')


func test_background_panel_has_the_background_wear_sections() -> void:
  _background_panel().rebuild()
  var titles: Array[String] = _section_titles(_background_panel())
  assert_true(titles.has('Background Specks'), 'background wear groups')
  assert_true(titles.has('Background Folds'), 'the folds group')
  assert_false(titles.has('Print Border'), 'the border is in the Print tab')


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


func test_corridor_padding_lines_the_folds_up_with_the_split() -> void:
  # The fold shader puts the last fold at twice the corridor's left edge plus its width, which is the
  # split point when the corridor has the same padding on both sides.
  PrintLook.print_settings['padding'] = 30.0
  var view: Control = _view()
  var corridor: Rect2 = view.get_node('Corridor/CorridorPanel').get_global_rect()
  var split: float = PrintLook.print_setting('split_across')
  assert_eq(corridor.position.x, 30.0, 'the corridor starts the padding in from the screen edge')
  assert_eq(corridor.position.x * 2.0 + corridor.size.x, split, 'the last fold lands on the split')


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


func test_frame_tells_the_background_where_the_corridor_is() -> void:
  var view: Control = _view()
  await get_tree().process_frame   # the view places the corridor in its section after the frame's first update
  var rect: Vector4 = PrintLook.background_material.get_shader_parameter('print_corridor_rect')
  assert_gt(rect.z, 0.0, 'the corridor rectangle is set while a fight view is on screen')
  _nodes.erase(view)
  view.free()
  assert_eq(PrintLook.background_material.get_shader_parameter('print_corridor_rect'), Vector4.ZERO,
    'cleared when the view leaves')
