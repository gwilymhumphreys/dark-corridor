extends GutTest
## `Cursor`: the stone pointer replaces the operating system's cursor, a brightened copy shows
## over clickable controls, and every clickable control sets the pointing-hand shape
## (docs/systems/cursor.md).

const CLICKABLE_NODES: Array[Array] = [
  ['res://src/scenes/combat/potion_slot.tscn', '.'],
  ['res://src/scenes/screens/character_card.tscn', '.'],
  ['res://src/scenes/screens/character_select.tscn', 'Panel/BackButton'],
  ['res://src/scenes/screens/choice_card.tscn', '.'],
  ['res://src/scenes/screens/combat_summary.tscn', 'Panel/Margin/Body/Footer/CloseButton'],
  ['res://src/scenes/screens/draft_overlay.tscn', 'Panel/SkipButton'],
  ['res://src/scenes/screens/outcome_screen.tscn', 'Menu/NewRunButton'],
  ['res://src/scenes/screens/outcome_screen.tscn', 'Menu/TitleButton'],
  ['res://src/scenes/screens/pause_menu.tscn', 'Catcher/Panel/Menu/ResumeButton'],
  ['res://src/scenes/screens/pause_menu.tscn', 'Catcher/Panel/Menu/SettingsButton'],
  ['res://src/scenes/screens/pause_menu.tscn', 'Catcher/Panel/Menu/QuitButton'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/Rows/MasterRow/Slider'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/Rows/MusicRow/Slider'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/Rows/InterfaceRow/Slider'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/Rows/GameRow/Slider'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/Rows/FullscreenRow/Check'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/Rows/MuteRow/Check'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/BackButton'],
  ['res://src/scenes/screens/speed_button.tscn', '.'],
  ['res://src/scenes/screens/title_screen.tscn', 'Menu/StartButton'],
  ['res://src/scenes/screens/title_screen.tscn', 'Menu/ResumeButton'],
  ['res://src/scenes/screens/title_screen.tscn', 'Menu/SettingsButton'],
  ['res://src/scenes/corridor_testbed.tscn', 'UILayer/ButtonRow/BackButton'],
  ['res://src/scenes/corridor_testbed.tscn', 'UILayer/ButtonRow/ForwardButton'],
]


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_lighten_brightens_visible_pixels_and_leaves_the_edge_alone() -> void:
  var image: Image = Image.create_empty(3, 1, false, Image.FORMAT_RGBA8)
  image.set_pixel(0, 0, Color(0.5, 0.5, 0.5, 1.0))
  image.set_pixel(1, 0, Color(0.0, 0.0, 0.0, 0.0))
  image.set_pixel(2, 0, Color(0.5, 0.5, 0.5, 0.5))
  var brightened: Image = Cursor._lighten(image, 0.5)
  assert_gt(brightened.get_pixel(0, 0).r, 0.5, 'the opaque pixel moved towards white')
  assert_almost_eq(brightened.get_pixel(0, 0).a, 1.0, 0.0001, 'the opaque pixel stays opaque')
  assert_almost_eq(brightened.get_pixel(1, 0).a, 0.0, 0.0001, 'the transparent pixel stays transparent')
  assert_almost_eq(brightened.get_pixel(2, 0).a, 0.5, 0.01, 'a soft edge pixel keeps its alpha')


func test_the_cursor_art_loads() -> void:
  assert_true(ResourceLoader.exists(CursorAutoload.TEXTURE_PATH), 'the stone pointer art is in the project')
  var texture: Texture2D = load(CursorAutoload.TEXTURE_PATH)
  assert_eq(texture.get_width(), 32, 'the art is 32 pixels wide')
  assert_eq(texture.get_height(), 32, 'the art is 32 pixels high')


func test_every_clickable_control_sets_the_pointing_hand_shape() -> void:
  for pair: Array in CLICKABLE_NODES:
    var root: Node = load(pair[0]).instantiate()
    var node: Control = root.get_node(pair[1])
    assert_eq(node.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND,
      '%s %s shows the pointing hand over it' % [pair[0], pair[1]])
    root.free()
