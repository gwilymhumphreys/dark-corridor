extends GutTest
## The screen sections (docs/systems/ui_layout.md#screen-sections): the halves either side of the fold
## follow the padding and the information section fits its children, and the combat view places its
## parts in them and fits the portraits and item columns.

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


func test_section_rects_split_the_screen_at_the_fold_and_take_off_the_padding() -> void:
  var rects: Dictionary = ScreenSections.section_rects(Vector2(2560, 1440), 20.0, 70.0)
  assert_eq(rects['Corridor'], Rect2(20, 20, 1240, 1400), 'the corridor takes the left half')
  assert_eq(rects['Items'], Rect2(1300, 20, 1240, 1290), 'the player column takes the right half above the information')
  assert_eq(rects['Info'], Rect2(1300, 1350, 1240, 70), 'the information along the bottom, as tall as asked')


func test_the_information_section_is_as_tall_as_its_tallest_child() -> void:
  var sections: ScreenSections = _host(SECTIONS_SCENE.instantiate())
  var button: Control = Control.new()
  button.size = Vector2(100, 64)
  sections.section('Info').add_child(button)
  sections._process(0.0)
  assert_eq(sections.section('Info').size.y, 64.0, 'fits the child')
  assert_eq(sections.section('Items').get_rect().end.y + PrintLook.print_setting('padding') * 2.0,
    sections.section('Info').position.y, 'the player column ends the padding above it')


func test_view_stacks_the_portraits_above_the_items() -> void:
  var view: CombatViewFramed = COMBAT_VIEW_SCENE.instantiate()
  _host(view)
  view.sections._process(0.0)
  var portraits: BoxContainer = view.get_node('Portraits')
  var items: Rect2 = view.get_node('Items').get_global_rect()
  var section: Rect2 = view.sections.section('Items').get_global_rect()
  assert_eq(portraits.get_child(0), view.get_node('Portraits/PlayerPanel'), 'the player comes first')
  assert_eq(portraits.get_global_rect().position, section.position, 'the portraits sit at the top of the section')
  assert_gt(items.position.y, portraits.get_global_rect().end.y, 'the items start below the portraits')
  assert_eq(items.end, section.end, 'the items take the rest of the section')


func test_stacked_allies_sit_in_the_allies_box() -> void:
  var view: CombatViewFramed = COMBAT_VIEW_SCENE.instantiate()
  _host(view)
  var ally_left: Control = view._ally_left
  var group: Control = view.get_node('Portraits/Allies')
  var rows: Control = view.get_node('Portraits/Allies/Box/Rows')
  view.sections._process(0.0)
  assert_true(group.visible, 'the allies box shows, even with no allies')
  assert_eq(ally_left.get_parent(), rows, 'the ally rows are in the box')
  PrintLook.print_settings['allies_box'] = false
  view._place_ally_rows()
  assert_false(group.visible, 'no box with the setting off')
  assert_eq(ally_left.get_parent(), view.get_node('Portraits'), 'the rows are back under the player')
  assert_eq(view.get_node('Portraits').get_child(0), view.get_node('Portraits/PlayerPanel'), 'the player stays first')
  PrintLook.print_settings['allies_box'] = true


func test_sections_follow_the_print_settings() -> void:
  var sections: ScreenSections = _host(SECTIONS_SCENE.instantiate())
  watch_signals(sections)
  PrintLook.print_settings['padding'] = 10.0
  sections._process(0.0)
  assert_signal_emitted(sections, 'sections_changed')
  var half: float = sections.size.x * 0.5
  assert_eq(sections.section('Items').position.x, half + 10.0, 'the player column starts the padding past the fold')
  assert_eq(sections.section('Corridor').size.x, half - 20.0, 'the corridor loses the padding on both sides')


func test_view_places_its_parts_in_the_sections() -> void:
  var view: CombatViewFramed = COMBAT_VIEW_SCENE.instantiate()
  _host(view)
  PrintLook.print_settings['padding'] = 50.0
  view.sections._process(0.0)
  var column: Rect2 = view.sections.section('Items').get_global_rect()
  assert_eq(view.get_node('Corridor').get_global_rect(), view.sections.section('Corridor').get_global_rect(), 'corridor placed')
  assert_eq(view.get_node('Portraits').get_global_rect().position, column.position, 'portraits at the top of the column')
  assert_eq(view.get_node('Items').get_global_rect().end, column.end, 'items to the bottom of the column')
  assert_eq(view.corridor_area().get_global_rect(), view.sections.section('Corridor').get_global_rect(),
    'reward and event panels go in the corridor section')


func test_view_uses_the_sections_it_is_given() -> void:
  var sections: ScreenSections = _host(SECTIONS_SCENE.instantiate())
  var view: CombatViewFramed = COMBAT_VIEW_SCENE.instantiate()
  view.sections = sections
  _host(view)
  assert_eq(view.sections, sections, 'no second set of sections is made')
  assert_eq(view.get_node('Items').get_global_rect().end, sections.section('Items').get_global_rect().end, 'items placed')


func test_player_portrait_matches_the_column_beside_it() -> void:
  var view: CombatViewFramed = COMBAT_VIEW_SCENE.instantiate()
  _host(view)
  await get_tree().process_frame
  var portrait: Control = view.get_node('Portraits/PlayerPanel/Row/Portrait')
  var readout: Control = view.get_node('Portraits/PlayerPanel/Row/Readout')
  var height: float = ceilf(readout.get_combined_minimum_size().y)
  assert_eq(portrait.custom_minimum_size, Vector2(height, height),
      'the portrait is square and as tall as the column beside it')


func test_item_columns_fit_the_items_section_width() -> void:
  var view: CombatViewFramed = COMBAT_VIEW_SCENE.instantiate()
  _host(view)
  var grid: GridContainer = view.get_node('Items/ItemsSection/Board/PlayerItems')
  PrintLook.print_settings['padding'] = 20.0
  view.sections._process(0.0)
  var wide: int = grid.columns
  PrintLook.print_settings['padding'] = 220.0
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


func test_player_portrait_fits_inside_the_portrait_panel() -> void:
  PrintLook.set_print_value('panel_background', CharacterPanel.PanelBackground.PLAYER_AND_ALLIES)
  var view: CombatViewFramed = COMBAT_VIEW_SCENE.instantiate()
  _host(view)
  for frame: int in 3:
    await get_tree().process_frame
  var panel: PanelContainer = view.get_node('Portraits/PlayerPanel')
  assert_eq(panel.theme_type_variation, &'PanelTokenWide', 'the panel is a token')
  var height: float = view.get_node('Portraits').size.y
  assert_true(panel.size.y <= height, 'the panel fits in %d pixels' % height)
  PrintLook.set_print_value('panel_background', CharacterPanel.PanelBackground.ENEMIES)
  view._process(0.0)
  assert_eq(panel.theme_type_variation, &'PanelBare', 'no player panel when only the enemies have one')


func test_player_portrait_is_always_a_token() -> void:
  var view: CombatViewFramed = COMBAT_VIEW_SCENE.instantiate()
  _host(view)
  var portrait: Control = view.get_node('Portraits/PlayerPanel/Row/Portrait')
  view._process(0.0)
  assert_eq(portrait.theme_type_variation, &'PanelToken', 'a token with token_portraits off')
