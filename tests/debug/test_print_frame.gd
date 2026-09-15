extends GutTest
## The print frame: the F3 print panel, the print settings in look files, and `PrintFrame` moving the
## corridor and showing the border and overlay (docs/systems/print_frame.md).

const COMBAT_VIEW_SCENE: PackedScene = preload('res://src/scenes/combat/combat_view_framed.tscn')
const LOOK_PATH: String = 'user://test_looks/print.cfg'

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


func _panel() -> PrintPanel:
  return DebugPanels.get_node('PrintLayer/PrintPanel') as PrintPanel


func _section_titles() -> Array[String]:
  var titles: Array[String] = []
  for section: Node in _panel().get_node('Rows/Scroll/Sections').get_children():
    titles.append((section.get_node('Header/Title') as Button).text)
  return titles


func _view() -> Control:
  var view: Control = COMBAT_VIEW_SCENE.instantiate() as Control
  add_child(view)
  _nodes.append(view)
  return view


func test_defaults_match_the_owners_saved_look() -> void:
  var defaults: Dictionary = DebugPanels.print_defaults()
  assert_eq(defaults['print_border_on'], false, 'the border is off')
  assert_eq(defaults['corridor_wear_on'], true, 'wear over the corridor is on')
  assert_eq(defaults['corridor_worn_edge_on'], true, 'the worn corridor edge is on')
  assert_false(defaults.has('rect_size'), 'sizes set by PrintFrame are not look settings')
  assert_false(defaults.has('background_specks_on'), 'the overlay copy of the background wear is not listed twice')
  assert_eq(DebugPanels.background_defaults()['background_folds_on'], true, 'folds are on')


func test_panel_has_background_layout_border_and_overlay_sections() -> void:
  _panel().rebuild()
  var titles: Array[String] = _section_titles()
  assert_true(titles.has('Background Specks'), 'background wear groups')
  assert_true(titles.has('Background Folds'), 'the folds group')
  assert_true(titles.has('Layout'), 'the corridor margin')
  assert_true(titles.has('Print Border'), 'the border')
  assert_true(titles.has('Corridor Wear'), 'wear over the corridor')
  assert_true(titles.has('Corridor Worn Edge'), 'the worn corridor edge')
  assert_eq(titles.count('Background Specks'), 1, 'the overlay does not repeat the background sections')


func test_save_then_load_restores_the_print_look() -> void:
  DebugPanels.set_print_value('print_border_on', true)
  DebugPanels.set_print_value('corridor_worn_edge_width', 50.0)
  DebugPanels.set_print_value('corridor_margin', 70.0)
  DebugPanels.background_material.set_shader_parameter('background_folds_on', false)
  assert_eq(DebugPanels.save_print_look(LOOK_PATH), OK, 'the print look is saved')
  DebugPanels.reset_settings()
  assert_eq(DebugPanels.border_material.get_shader_parameter('print_border_on'), false, 'reset turns the border off')
  assert_eq(DebugPanels.print_setting('corridor_margin'), DebugPanelsAutoload.PRINT_SETTING_DEFAULTS['corridor_margin'],
    'reset returns the margin to its default')
  assert_true(DebugPanels.load_print_look(LOOK_PATH), 'the print look is loaded')
  assert_eq(DebugPanels.border_material.get_shader_parameter('print_border_on'), true, 'border switch restored')
  assert_almost_eq(DebugPanels.overlay_material.get_shader_parameter('corridor_worn_edge_width'), 50.0, 0.001,
    'overlay number restored')
  assert_eq(DebugPanels.print_setting('corridor_margin'), 70.0, 'layout setting restored')
  assert_eq(DebugPanels.background_material.get_shader_parameter('background_folds_on'), false, 'background wear restored')


func test_print_and_corridor_looks_are_separate() -> void:
  DebugPanels.world_material.set_shader_parameter('grade_on', true)
  DebugPanels.set_print_value('print_border_on', true)
  DebugPanels.save_print_look(LOOK_PATH)
  DebugPanels.reset_print_look()
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_on'), true, 'resetting the print look keeps the corridor look')
  DebugPanels.world_material.set_shader_parameter('grade_on', false)
  DebugPanels.load_print_look(LOOK_PATH)
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_on'), false, 'a print look does not hold the corridor look')
  DebugPanels.reset_look()
  assert_eq(DebugPanels.border_material.get_shader_parameter('print_border_on'), true, 'resetting the corridor look keeps the print look')


func test_frame_moves_the_corridor_by_the_margin() -> void:
  var view: Control = _view()
  var corridor: Control = view.get_node('CorridorPanel')
  var frame: PrintFrame = view.get_node('PrintFrame') as PrintFrame
  var margin: float = DebugPanels.print_setting('corridor_margin')
  var scene_position: Vector2 = corridor.position - Vector2(margin, margin)
  var scene_size: Vector2 = corridor.size + Vector2(margin, margin) * 2.0
  DebugPanels.print_settings['corridor_margin'] = 60.0
  frame._process(0.0)
  assert_eq(corridor.position, scene_position + Vector2(60.0, 60.0), 'moved in by the margin')
  assert_eq(corridor.size, scene_size - Vector2(120.0, 120.0), 'shrunk on every side')


func test_frame_shows_the_border_and_overlay_only_when_on() -> void:
  var view: Control = _view()
  var frame: PrintFrame = view.get_node('PrintFrame') as PrintFrame
  var border: ColorRect = view.get_node('PrintFrame/Border')
  var overlay: ColorRect = view.get_node('CorridorOverlay')
  DebugPanels.set_print_value('corridor_wear_on', false)
  DebugPanels.set_print_value('corridor_worn_edge_on', false)
  frame._process(0.0)
  assert_false(border.visible, 'no border while it is off')
  assert_false(overlay.visible, 'no overlay while its effects are off')
  DebugPanels.set_print_value('print_border_on', true)
  DebugPanels.set_print_value('corridor_worn_edge_on', true)
  frame._process(0.0)
  assert_true(border.visible, 'the border shows')
  assert_true(overlay.visible, 'the overlay shows')
  var corridor: Control = view.get_node('CorridorPanel')
  assert_true(border.get_rect().encloses(corridor.get_rect()), 'the border surrounds the corridor')
  assert_eq(overlay.get_rect(), corridor.get_rect(), 'the overlay covers the corridor')


func test_frame_tells_the_background_where_the_corridor_is() -> void:
  var view: Control = _view()
  var rect: Vector4 = DebugPanels.background_material.get_shader_parameter('print_corridor_rect')
  assert_gt(rect.z, 0.0, 'the corridor rectangle is set while a fight view is on screen')
  _nodes.erase(view)
  view.free()
  assert_eq(DebugPanels.background_material.get_shader_parameter('print_corridor_rect'), Vector4.ZERO,
    'cleared when the view leaves')
