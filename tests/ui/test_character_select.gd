extends GutTest
## The character-select screen (#27): it builds one CharacterCard per catalog character, a
## card press emits picked(character_id), and Back emits cancelled. Presentation reads
## CharacterCatalog and writes nothing — these confirm the wiring, not the visuals.

var _nodes: Array = []
var _saved_slide_time: float = 0.0


func before_each() -> void:
  TestCleanup.reset_all_managers()
  _saved_slide_time = PrintLook.print_setting('photo_slide_time')


func after_each() -> void:
  for n in _nodes:
    if is_instance_valid(n):
      n.free()
  _nodes.clear()
  PrintLook.set_print_value('photo_slide_time', _saved_slide_time)
  TestCleanup.reset_all_managers()


func _select() -> CharacterSelect:
  var s: CharacterSelect = preload('res://src/scenes/screens/character_select.tscn').instantiate()
  add_child(s)            # _ready builds the cards from CharacterCatalog
  _nodes.append(s)
  return s


func test_builds_one_card_per_character() -> void:
  var select := _select()
  assert_eq(select.get_node('Page/Cards').get_child_count(), CharacterCatalog.ids().size(),
    'one card per catalog character')


func test_card_press_emits_picked_with_the_character_id() -> void:
  var select := _select()
  watch_signals(select)
  var first_card: CharacterCard = select.get_node('Page/Cards').get_child(0)
  first_card.pressed.emit()
  assert_signal_emitted_with_parameters(select, 'picked', [CharacterCatalog.ids()[0]])


func test_second_card_picks_the_second_character() -> void:
  var select := _select()
  watch_signals(select)
  var second_card: CharacterCard = select.get_node('Page/Cards').get_child(1)
  second_card.pressed.emit()
  assert_signal_emitted_with_parameters(select, 'picked', [CharacterCatalog.ids()[1]])


func test_back_emits_cancelled() -> void:
  var select := _select()
  watch_signals(select)
  select.get_node('Page/BackButton').pressed.emit()
  assert_signal_emitted(select, 'cancelled')


func test_the_first_character_starts_selected_with_its_photo_on_top() -> void:
  var select := _select()
  var ids: Array = CharacterCatalog.ids()
  assert_eq(select.selected_id(), ids[0], 'the first character is selected')
  var photos: Control = select.get_node('Photos')
  assert_eq(photos.get_child_count(), ids.size(), 'one photo per character')
  assert_eq(_top(select), select.photo(ids[0]), 'the selected photo is on top of the pile')


func test_selecting_slides_the_photo_out_and_back_in_on_top() -> void:
  PrintLook.set_print_value('photo_slide_time', 0.1)
  var select := _select()
  var second: String = CharacterCatalog.ids()[1]
  var second_card: CharacterCard = select.get_node('Page/Cards').get_child(1)
  var rest: Vector2 = select.photo(second).offset_transform_position
  second_card.mouse_entered.emit()
  assert_eq(select.selected_id(), second, 'hovering selects')
  assert_ne(_top(select), select.photo(second), 'the photo is not on top until it has slid out')
  await wait_seconds(0.2)
  assert_eq(_top(select), select.photo(second), 'the photo ends on top')
  assert_almost_eq(select.photo(second).offset_transform_position, rest, Vector2.ONE * 0.01, 'back at its resting place')


func test_a_photo_left_before_it_slides_out_stays_in_the_pile() -> void:
  PrintLook.set_print_value('photo_slide_time', 0.2)
  var select := _select()
  var ids: Array = CharacterCatalog.ids()
  var photos: Control = select.get_node('Photos')
  var place: int = select.photo(ids[1]).get_index()
  select.select_character(ids[1])
  select.select_character(ids[2])
  await wait_seconds(0.3)
  assert_eq(_top(select), select.photo(ids[2]), 'the photo selected last is on top')
  assert_eq(photos.get_child(place), select.photo(ids[1]), 'the photo left behind keeps its place')


func test_leaving_a_card_keeps_it_selected() -> void:
  var select := _select()
  var second_card: CharacterCard = select.get_node('Page/Cards').get_child(1)
  second_card.mouse_entered.emit()
  second_card.mouse_exited.emit()
  assert_eq(select.selected_id(), CharacterCatalog.ids()[1], 'the hovered character stays selected')


func test_the_selected_character_is_picked_once() -> void:
  var select := _select()
  watch_signals(select)
  select.select_character(CharacterCatalog.ids()[1])
  select.get_node('MenuSelection')._unhandled_input(_action('ui_accept'))
  select.get_node('MenuSelection')._unhandled_input(_action('ui_accept'))
  assert_signal_emitted_with_parameters(select, 'picked', [CharacterCatalog.ids()[1]])
  assert_signal_emit_count(select, 'picked', 1, 'a second accept does nothing')


func test_cancel_goes_back() -> void:
  var select := _select()
  watch_signals(select)
  select._unhandled_input(_action('ui_cancel'))
  assert_signal_emitted(select, 'cancelled')


func _action(action: String) -> InputEventAction:
  var event: InputEventAction = InputEventAction.new()
  event.action = action
  event.pressed = true
  return event


func _top(select: CharacterSelect) -> Control:
  var photos: Control = select.get_node('Photos')
  return photos.get_child(photos.get_child_count() - 1)
