extends GutTest
## Stage 2 — the choice-point overlay: one telegraphed card per candidate encounter, and
## clicking a card emits the path-pick intent (run screen → RunManager.pick_path).


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_overlay_lists_candidates_and_emits_the_pick() -> void:
  var overlay: ChoiceOverlay = preload('res://src/scenes/screens/choice_overlay.tscn').instantiate()
  add_child(overlay)
  overlay.setup([EncounterCatalog.Id.FIGHT_GRUNT, EncounterCatalog.Id.FIGHT_TOUGH, EncounterCatalog.Id.FIGHT_ELITE])
  assert_eq(overlay.get_node('Panel/Cards').get_child_count(), 3, 'one card per candidate')
  watch_signals(overlay)
  var card: Button = overlay.get_node('Panel/Cards').get_child(2)
  card.pressed.emit()
  assert_signal_emitted_with_parameters(overlay, 'picked', [2], 'clicking a card emits the path pick')
  overlay.free()


func test_card_telegraphs_the_category() -> void:
  var card: ChoiceCard = preload('res://src/scenes/screens/choice_card.tscn').instantiate()
  add_child(card)
  card.setup(EncounterCatalog.get_def(EncounterCatalog.Id.FIGHT_ELITE))
  assert_eq(card.get_node('Category').text, tr('Elite'), 'an elite candidate telegraphs Elite')
  card.free()
