extends GutTest
## The screen sections (docs/systems/ui_layout.md#screen-sections): the four sections follow the split
## point and padding, and the combat view places its parts in them and fits the portraits and item
## columns.

const SECTIONS_SCENE: PackedScene = preload('res://src/ui/screen_sections.tscn')
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


func _host(node: Node) -> Node:
  add_child(node)
  _nodes.append(node)
  return node


func test_section_rects_split_the_screen_and_take_off_the_padding() -> void:
  var rects: Dictionary = ScreenSections.section_rects(Vector2(2560, 1440), Vector2(1700, 1150), 20.0)
  assert_eq(rects['Corridor'], Rect2(20, 20, 1660, 1110), 'corridor top left')
  assert_eq(rects['Items'], Rect2(1720, 20, 820, 1110), 'items top right')
  assert_eq(rects['Portraits'], Rect2(20, 1170, 1660, 250), 'portraits lower left')
  assert_eq(rects['Info'], Rect2(1720, 1170, 820, 250), 'information lower right')


func test_sections_follow_the_print_settings() -> void:
  var sections: ScreenSections = _host(SECTIONS_SCENE.instantiate())
  watch_signals(sections)
  PrintLook.print_settings['split_across'] = 1500.0
  PrintLook.print_settings['padding'] = 10.0
  sections._process(0.0)
  assert_signal_emitted(sections, 'sections_changed')
  assert_eq(sections.section('Items').position.x, 1510.0, 'the items section moves with the split')
  assert_eq(sections.section('Corridor').size.x, 1480.0, 'the corridor section shrinks with it')


func test_view_places_its_parts_in_the_sections() -> void:
  var view: CombatViewFramed = COMBAT_VIEW_SCENE.instantiate()
  _host(view)
  PrintLook.print_settings['split_across'] = 1400.0
  PrintLook.print_settings['split_down'] = 1000.0
  view.sections._process(0.0)
  assert_eq(view.get_node('Corridor').get_global_rect(), view.sections.section('Corridor').get_global_rect(), 'corridor placed')
  assert_eq(view.get_node('Items').get_global_rect(), view.sections.section('Items').get_global_rect(), 'items placed')
  assert_eq(view.get_node('Portraits').get_global_rect(), view.sections.section('Portraits').get_global_rect(), 'portraits placed')
  assert_eq(view.corridor_area().get_global_rect(), view.sections.section('Corridor').get_global_rect(),
    'reward and event panels go in the corridor section')


func test_view_uses_the_sections_it_is_given() -> void:
  var sections: ScreenSections = _host(SECTIONS_SCENE.instantiate())
  var view: CombatViewFramed = COMBAT_VIEW_SCENE.instantiate()
  view.sections = sections
  _host(view)
  assert_eq(view.sections, sections, 'no second set of sections is made')
  assert_eq(view.get_node('Items').get_global_rect(), sections.section('Items').get_global_rect(), 'items placed')


func test_player_portrait_fits_the_portrait_section_height() -> void:
  var view: CombatViewFramed = COMBAT_VIEW_SCENE.instantiate()
  _host(view)
  var portrait: Control = view.get_node('Portraits/PlayerPortrait/Portrait')
  var box: Control = view.get_node('Portraits/PlayerPortrait')
  for split_down: float in [1000.0, 1150.0, 1250.0]:
    PrintLook.print_settings['split_down'] = split_down
    view.sections._process(0.0)
    var height: float = view.sections.section('Portraits').size.y
    assert_eq(portrait.custom_minimum_size.x, portrait.custom_minimum_size.y, 'the portrait stays square')
    assert_true(box.get_combined_minimum_size().y <= height, 'the portrait row fits in %d pixels' % height)
  PrintLook.print_settings['split_down'] = 1000.0
  view.sections._process(0.0)
  var tall: float = portrait.custom_minimum_size.y
  PrintLook.print_settings['split_down'] = 1250.0
  view.sections._process(0.0)
  assert_lt(portrait.custom_minimum_size.y, tall, 'a shorter section gives a smaller portrait')


func test_item_columns_fit_the_items_section_width() -> void:
  var view: CombatViewFramed = COMBAT_VIEW_SCENE.instantiate()
  _host(view)
  var grid: GridContainer = view.get_node('Items/Board/PlayerItems')
  PrintLook.print_settings['split_across'] = 1700.0
  view.sections._process(0.0)
  var wide: int = grid.columns
  PrintLook.print_settings['split_across'] = 2100.0
  view.sections._process(0.0)
  assert_lt(grid.columns, wide, 'a narrower items section has fewer columns')
  var square: float = ItemCell.CELL_SIZE.x + grid.get_theme_constant('h_separation')
  assert_true(grid.columns * square <= view.sections.section('Items').size.x, 'the columns fit the section')


func test_item_cells_keep_full_size_until_the_board_is_full() -> void:
  var gap_ratio: float = 0.2
  assert_eq(CombatViewFramed.board_cell_size(820.0, 860.0, 0, gap_ratio), ItemCell.CELL_SIZE.x, 'an empty board')
  assert_eq(CombatViewFramed.board_cell_size(820.0, 860.0, 25, gap_ratio), ItemCell.CELL_SIZE.x, 'a board that fits')


func test_item_cells_shrink_so_a_full_board_fits() -> void:
  var gap_ratio: float = 0.2
  for count: int in [31, 41, 60]:
    var cell_size: float = CombatViewFramed.board_cell_size(820.0, 860.0, count, gap_ratio)
    assert_lt(cell_size, ItemCell.CELL_SIZE.x, '%d items shrink the cells' % count)
    var square: float = cell_size + int(cell_size * gap_ratio)
    var columns: int = int(820.0 / square)
    assert_true(ceili(float(count) / columns) * square <= 860.0, '%d items fit the board' % count)
  assert_eq(CombatViewFramed.board_cell_size(820.0, 860.0, 1000, gap_ratio), CombatViewFramed.MIN_CELL_SIZE,
    'the cells stop shrinking at the minimum')
