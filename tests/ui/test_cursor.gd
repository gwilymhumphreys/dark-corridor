extends GutTest
## `Cursor`: the operating system's cursor is hidden and a pointing hand is drawn in its place,
## recoloured onto the interface palette, outlined over clickable controls, curled while the left
## button is held, and every clickable control sets the pointing-hand shape
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
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/Scroll/Rows/MasterRow/Slider'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/Scroll/Rows/MusicRow/Slider'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/Scroll/Rows/InterfaceRow/Slider'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/Scroll/Rows/GameRow/Slider'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/Scroll/Rows/TextSizeRow/Slider'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/Scroll/Rows/FullscreenRow/Check'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/Scroll/Rows/MuteRow/Check'],
  ['res://src/scenes/screens/settings_screen.tscn', 'Panel/BackButton'],
  ['res://src/scenes/screens/speed_button.tscn', '.'],
  ['res://src/scenes/screens/title_screen.tscn', 'Menu/StartButton'],
  ['res://src/scenes/screens/title_screen.tscn', 'Menu/ResumeButton'],
  ['res://src/scenes/screens/title_screen.tscn', 'Menu/SettingsButton'],
  ['res://src/debug/scenes/corridor_testbed.tscn', 'UILayer/ButtonRow/BackButton'],
  ['res://src/debug/scenes/corridor_testbed.tscn', 'UILayer/ButtonRow/ForwardButton'],
]


func before_each() -> void:
  TestCleanup.reset_all_managers()
  Cursor._set_pressed(false)


func after_each() -> void:
  TestCleanup.reset_all_managers()
  Cursor._set_pressed(false)


func test_recolouring_places_pixels_on_the_interface_colours_and_leaves_the_edge_alone() -> void:
  var image: Image = Image.create_empty(3, 1, false, Image.FORMAT_RGBA8)
  image.set_pixel(0, 0, Color(0.0, 0.0, 0.0, 1.0))
  image.set_pixel(1, 0, Color(0.0, 0.0, 0.0, 0.0))
  image.set_pixel(2, 0, Color(1.0, 1.0, 1.0, 0.5))
  var recoloured: Image = Cursor._recoloured(image)
  var darkest: Color = (Colours as Script).get(CursorAutoload.BODY_COLOURS[0])
  var lightest: Color = (Colours as Script).get(CursorAutoload.BODY_COLOURS[CursorAutoload.BODY_COLOURS.size() - 1])
  assert_almost_eq(recoloured.get_pixel(0, 0).r, darkest.r, 0.01, 'the black pixel takes the darkest interface colour')
  assert_almost_eq(recoloured.get_pixel(0, 0).a, 1.0, 0.0001, 'the opaque pixel stays opaque')
  assert_almost_eq(recoloured.get_pixel(1, 0).a, 0.0, 0.0001, 'the transparent pixel stays transparent')
  assert_almost_eq(recoloured.get_pixel(2, 0).r, lightest.r, 0.01, 'the white pixel takes the lightest interface colour')
  assert_almost_eq(recoloured.get_pixel(2, 0).a, 0.5, 0.01, 'a soft edge pixel keeps its alpha')


func test_the_outline_is_drawn_round_the_edge_and_not_through_the_middle() -> void:
  var image: Image = Image.create_empty(3, 3, false, Image.FORMAT_RGBA8)
  for y: int in 3:
    for x: int in 3:
      image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
  var outlined: Image = Cursor._outlined(image)
  var outline: Color = (Colours as Script).get(CursorAutoload.OUTLINE_COLOUR)
  assert_almost_eq(outlined.get_pixel(0, 0).r, outline.r, 0.01, 'a corner pixel is drawn in the outline colour')
  assert_almost_eq(outlined.get_pixel(1, 1).r, 1.0, 0.01, 'the middle pixel is left alone')
  assert_almost_eq(outlined.get_pixel(0, 0).a, 1.0, 0.0001, 'the outline keeps the pixel it replaced opaque')


func test_the_cursor_art_loads() -> void:
  for path: String in [CursorAutoload.TEXTURE_PATH, CursorAutoload.PRESSED_TEXTURE_PATH]:
    assert_true(ResourceLoader.exists(path), '%s is in the project' % path)
    var texture: Texture2D = load(path)
    assert_eq(texture.get_width(), 32, '%s is 32 pixels wide' % path)
    assert_eq(texture.get_height(), 32, '%s is 32 pixels high' % path)


func test_the_left_button_holds_the_pressed_cursor_and_releasing_lets_it_go() -> void:
  var down: InputEventMouseButton = InputEventMouseButton.new()
  down.button_index = MOUSE_BUTTON_LEFT
  down.pressed = true
  Cursor._input(down)
  assert_true(Cursor._pressed, 'holding the left button presses the cursor')
  var up: InputEventMouseButton = InputEventMouseButton.new()
  up.button_index = MOUSE_BUTTON_LEFT
  up.pressed = false
  Cursor._input(up)
  assert_false(Cursor._pressed, 'letting go of the left button releases the cursor')


func test_the_right_button_leaves_the_cursor_alone() -> void:
  var down: InputEventMouseButton = InputEventMouseButton.new()
  down.button_index = MOUSE_BUTTON_RIGHT
  down.pressed = true
  Cursor._input(down)
  assert_false(Cursor._pressed, 'only the left button presses the cursor')


func test_losing_window_focus_releases_the_cursor() -> void:
  var down: InputEventMouseButton = InputEventMouseButton.new()
  down.button_index = MOUSE_BUTTON_LEFT
  down.pressed = true
  Cursor._input(down)
  Cursor._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
  assert_false(Cursor._pressed, 'the press is let go when the window loses focus')


func test_the_drawn_hand_uses_the_picture_material_so_the_interface_look_applies() -> void:
  var hand: TextureRect = Cursor.get_node('Hand')
  assert_not_null(hand.material, 'the drawn hand has a material')
  assert_true(InterfaceLook.picture_materials.has(hand.material),
    'the drawn hand uses one of the picture materials, so the look and the palette clamp apply')
  assert_eq(hand.mouse_filter, Control.MOUSE_FILTER_IGNORE, 'the drawn hand does not take input')


func test_pressing_swaps_the_drawn_hand() -> void:
  Cursor._draw_hand()
  var resting: Texture2D = (Cursor.get_node('Hand') as TextureRect).texture
  var down: InputEventMouseButton = InputEventMouseButton.new()
  down.button_index = MOUSE_BUTTON_LEFT
  down.pressed = true
  Cursor._input(down)
  assert_ne((Cursor.get_node('Hand') as TextureRect).texture, resting,
    'a different hand is drawn while the button is held')


func test_every_clickable_control_sets_the_pointing_hand_shape() -> void:
  for pair: Array in CLICKABLE_NODES:
    var root: Node = load(pair[0]).instantiate()
    var node: Control = root.get_node(pair[1])
    assert_eq(node.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND,
      '%s %s shows the pointing hand over it' % [pair[0], pair[1]])
    root.free()
