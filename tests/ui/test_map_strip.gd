extends GutTest
## The map strip shows the current act's squares and where the player is among them.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _strip() -> MapStrip:
  var strip: MapStrip = preload('res://src/scenes/screens/map_strip.tscn').instantiate()
  add_child_autofree(strip)
  return strip


func test_the_label_names_the_current_act() -> void:
  var strip: MapStrip = _strip()
  strip.setup(1, 0)
  assert_eq(strip.get_node('ActLabel').text, 'Act 1')
  strip.mark_position(RunMap.BEATS_PER_ACT)
  assert_eq(strip.get_node('ActLabel').text, 'Act 2', 'the label follows the position into the next act')


func test_the_current_square_follows_the_position() -> void:
  var strip: MapStrip = _strip()
  strip.setup(1, 0)
  assert_eq(strip.current_square(), [0, false], 'the run starts on the first square')
  var layout: Array[int] = RunMap.act_layout(0, 1)
  var event_beat: int = layout.find(-1)
  strip.mark_position(event_beat)
  assert_eq(strip.current_square(), [layout[event_beat + 1], true], 'at an event, the next square with the event marker')


func test_cleared_squares_are_face_down() -> void:
  var strip: MapStrip = _strip()
  var layout: Array[int] = RunMap.act_layout(0, 1)
  strip.setup(1, layout.find(3))   # on the fourth square
  var tokens: Node = strip.get_node('Track/Tokens')
  assert_eq(tokens.get_child_count(), RunMap.SQUARES.size(), 'a token per square')
  for index: int in 3:
    assert_null((tokens.get_child(index) as ItemCell).get_node('Frame/Icon').texture, 'a cleared square is face down')
  assert_not_null((tokens.get_child(3) as ItemCell).get_node('Frame/Icon').texture, 'the current square shows its icon')
  assert_eq((tokens.get_child(0) as ItemCell).cell_size.x, float(PrintLook.print_setting('status_size')),
    'the tokens are the small token size, the same as the status icons')
