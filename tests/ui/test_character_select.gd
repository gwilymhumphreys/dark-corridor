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
  assert_eq(select.get_node('Panel/Cards').get_child_count(), CharacterCatalog.ids().size(),
    'one card per catalog character')


func test_card_press_emits_picked_with_the_character_id() -> void:
  var select := _select()
  watch_signals(select)
  var first_card: CharacterCard = select.get_node('Panel/Cards').get_child(0)
  first_card.pressed.emit()
  assert_signal_emitted_with_parameters(select, 'picked', [CharacterCatalog.ids()[0]])


func test_second_card_picks_the_second_character() -> void:
  var select := _select()
  watch_signals(select)
  var second_card: CharacterCard = select.get_node('Panel/Cards').get_child(1)
  second_card.pressed.emit()
  assert_signal_emitted_with_parameters(select, 'picked', [CharacterCatalog.ids()[1]])


func test_back_emits_cancelled() -> void:
  var select := _select()
  watch_signals(select)
  select.get_node('Panel/BackButton').pressed.emit()
  assert_signal_emitted(select, 'cancelled')
