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
  strip.setup(0)
  assert_eq(strip.get_node('ActLabel').text, 'Act 1')
  strip.mark_position(RunMap.BEATS_PER_ACT)
  assert_eq(strip.get_node('ActLabel').text, 'Act 2', 'the label follows the position into the next act')


func test_the_current_square_follows_the_position() -> void:
  var strip: MapStrip = _strip()
  strip.setup(0)
  assert_eq(strip.current_square(), [0, true], 'the run opens on the choice before the first square')
  strip.mark_position(1)
  assert_eq(strip.current_square(), [0, false], 'then the first square')
  strip.mark_position(2)
  assert_eq(strip.current_square(), [1, true], 'then the choice before the second, with the marker')


func test_cleared_squares_are_face_down() -> void:
  var strip: MapStrip = _strip()
  strip.setup(3 * 2 + 1)   # on the fourth square
  var tokens: Node = strip.get_node('Track/Tokens')
  assert_eq(tokens.get_child_count(), RunMap.SQUARES.size(), 'a token per square')
  for index: int in 3:
    assert_null((tokens.get_child(index) as ItemCell).get_node('Frame/Icon').texture, 'a cleared square is face down')
  assert_not_null((tokens.get_child(3) as ItemCell).get_node('Frame/Icon').texture, 'the current square shows its icon')


func test_the_tokens_are_the_medium_size_and_shrink_to_fit_the_width() -> void:
  var strip: MapStrip = _strip()
  var medium: float = PrintLook.print_setting('medium_token_size')
  var token: ItemCell = strip.get_node('Track/Tokens').get_child(0)
  strip.size.x = medium * RunMap.SQUARES.size() * 2.0
  await wait_process_frames(2)
  assert_eq(token.cell_size.x, medium, 'the medium token size, the same as the enemy items')
  strip.size.x = medium * RunMap.SQUARES.size() * 0.5
  await wait_process_frames(2)
  assert_lt(token.cell_size.x, medium, 'smaller when the row would be wider than the strip')
  var track: Control = strip.get_node('Track')
  assert_lte(strip.get_node('Track/Boxes').size.x, track.size.x, 'the row fits the strip')
