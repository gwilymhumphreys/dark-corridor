extends GutTest
## Phase 4 Step 5 — the draft overlay lists the 1-of-3 offer as cards and emits the
## picked index (the draft-pick intent the run screen forwards to apply_draft_pick).

var _nodes: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for n in _nodes:
    if is_instance_valid(n):
      n.free()
  _nodes.clear()
  TestCleanup.reset_all_managers()


func test_overlay_lists_the_offer_and_emits_the_pick() -> void:
  var overlay: DraftOverlay = preload('res://src/scenes/screens/draft_overlay.tscn').instantiate()
  add_child(overlay)
  _nodes.append(overlay)
  var offer: Array = [
    ItemCatalog.get_def(ItemCatalog.Id.WEAPON),
    ItemCatalog.get_def(ItemCatalog.Id.ARMOR),
    ItemCatalog.get_def(ItemCatalog.Id.POISON_DAGGER),
  ]
  overlay.setup(offer)
  assert_eq(overlay.get_node('Panel/Cards').get_child_count(), 3, 'one card per candidate')

  watch_signals(overlay)
  var card: Button = overlay.get_node('Panel/Cards').get_child(1)
  card.pressed.emit()   # the player picks the 2nd card
  assert_signal_emitted_with_parameters(overlay, 'picked', [1], 'picking card i emits index i')
