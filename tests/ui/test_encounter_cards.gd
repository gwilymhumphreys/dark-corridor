extends GutTest
## The encounter cards dealt from a deck (docs/plans/encounter_cards.md): a card's picture falls back
## to its kind's default, a card cannot be picked until it is face up, and a pick or a walk past is
## reported only once the cards have gone back to the deck.

const CARD: PackedScene = preload('res://src/scenes/screens/encounter_card.tscn')
const CHOICE: PackedScene = preload('res://src/scenes/screens/encounter_choice.tscn')


func before_each() -> void:
  TestCleanup.reset_all_managers()
  FixtureContent.install()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_an_encounter_with_no_image_uses_its_kinds_default() -> void:
  var def: EncounterDef = FixtureEncounters.rest()
  assert_eq(EncounterCard.image_path(def), EncounterCard.DEFAULT_IMAGES[EncounterDef.Type.REST])
  def.image = 'res://assets/encounters/hermit.jpg'
  assert_eq(EncounterCard.image_path(def), 'res://assets/encounters/hermit.jpg', 'its own image wins')


func test_every_default_image_loads() -> void:
  for path: String in EncounterCard.DEFAULT_IMAGES.values():
    assert_not_null(load(path), path)


func test_a_card_is_dealt_face_down_and_cannot_be_picked() -> void:
  var card: EncounterCard = CARD.instantiate()
  add_child_autofree(card)
  card.setup(FixtureEncounters.rest())
  assert_true(card.disabled, 'not pickable while face down')
  assert_eq(card.mouse_default_cursor_shape, Control.CURSOR_ARROW, 'and the cursor does not offer a click')
  assert_true(card.get_node('Lift/Card/Back').visible, 'the back shows')
  assert_false(card.get_node('Lift/Card/Front').visible, 'the front is hidden')
  card.face_up = 1.0
  assert_true(card.get_node('Lift/Card/Front').visible, 'face up shows the front')
  card.pickable = true
  assert_false(card.disabled, 'and can then be picked')


func test_a_pick_is_reported_after_the_cards_go_back() -> void:
  var choice: EncounterChoice = _dealt_choice()
  watch_signals(choice)
  choice._on_card_pressed(1)
  assert_signal_not_emitted(choice, 'picked', 'not on the click')
  choice._on_card_pressed(0)   # a second click while the cards are going back does nothing
  await wait_for_signal(choice.picked, 5.0)
  assert_signal_emit_count(choice, 'picked', 1)
  assert_signal_emitted_with_parameters(choice, 'picked', [1])
  var kept: EncounterCard = choice._card_list[1]
  choice._place_cards()   # the cards are placed each frame; place them for the state the pick ended in
  var centre: Vector2 = kept.get_global_transform() * (kept.size * 0.5)
  assert_almost_eq(centre, choice.deck_point(), Vector2.ONE, 'the picked card is where the deck was')
  assert_eq(kept.face_up, 1.0, 'face up')
  assert_eq(kept.mouse_filter, Control.MOUSE_FILTER_IGNORE, 'and does not take the mouse while the encounter is shown')
  assert_eq((choice._card_list[0] as EncounterCard).travel, 0.0, 'the others went back to the deck')


func test_walking_past_is_reported_after_the_cards_go_back() -> void:
  var choice: EncounterChoice = _dealt_choice()
  watch_signals(choice)
  choice._on_skip_pressed()
  assert_signal_not_emitted(choice, 'skipped', 'not on the click')
  await wait_for_signal(choice.skipped, 5.0)
  assert_signal_emit_count(choice, 'skipped', 1)


# A choice of three fixture encounters with its deal finished at once.
func _dealt_choice() -> EncounterChoice:
  var choice: EncounterChoice = CHOICE.instantiate()
  add_child_autofree(choice)
  choice.setup([FixtureEncounters.REST, FixtureEncounters.EVENT, FixtureEncounters.REWARD])
  for card: EncounterCard in choice._present_cards():
    card.visible = true
    card.travel = 1.0
    card.face_up = 1.0
  choice._revealed = true
  choice.visible = true
  choice._deck_show = 1.0
  choice._on_dealt()
  return choice
