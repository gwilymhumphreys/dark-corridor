extends GutTest
## The character-select screen (#27): it builds one CharacterCard per catalog character, a
## card press emits picked(character_id), and Back emits cancelled. Presentation reads
## CharacterCatalog and writes nothing — these confirm the wiring, not the visuals.

var _nodes: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for n in _nodes:
    if is_instance_valid(n):
      n.free()
  _nodes.clear()
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


func test_one_hidden_picture_per_character() -> void:
  var select := _select()
  var pictures: Control = select.get_node('Pictures')
  assert_eq(pictures.get_child_count(), CharacterCatalog.ids().size(), 'one picture per catalog character')
  for picture: Control in pictures.get_children():
    assert_eq(picture.modulate.a, 0.0, 'no picture shows before a card is hovered')


func test_hovering_a_card_burns_its_picture_in_and_leaving_burns_it_away() -> void:
  var select := _select()
  var card: CharacterCard = select.get_node('Page/Cards').get_child(0)
  var picture: Control = select.get_node('Pictures').get_child(0)
  card.mouse_entered.emit()
  var burn_in: PaperBurn = _burn_on(picture)
  assert_not_null(burn_in, 'hovering starts a burn on the picture')
  assert_true(burn_in.reverse, 'the picture burns in')
  burn_in.finish()
  card.mouse_exited.emit()
  var burn_out: PaperBurn = _burn_on(picture)
  assert_not_null(burn_out, 'leaving starts a burn on the picture')
  assert_false(burn_out.reverse, 'the picture burns away')
  burn_out.finish()
  assert_eq(picture.modulate.a, 0.0, 'the picture is hidden at the end')


func _burn_on(picture: Control) -> PaperBurn:
  for child: Node in picture.get_children():
    if child is PaperBurn and not child.is_queued_for_deletion():
      return child
  return null
