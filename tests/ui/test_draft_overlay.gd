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
    FixtureItems.attack(),
    FixtureItems.shield(),
    FixtureItems.poison(),
  ]
  overlay.setup(offer)
  assert_eq(overlay.get_node('Panel/Cards').get_child_count(), 3, 'one card per candidate')

  watch_signals(overlay)
  var option: RewardOption = overlay.get_node('Panel/Cards').get_child(1)
  assert_eq(option.item().def, offer[1], 'each reward is shown as a board item icon')
  assert_true(option is Button, 'a reward option is a button, so it gets the press juice')
  assert_true(option.get_node('Juice') is UIJuice, 'and the juice node that answers the pointer')
  option.pressed.emit()   # the player picks the 2nd reward
  assert_signal_emitted_with_parameters(overlay, 'picked', [1])


func test_skip_button_emits_skipped() -> void:
  # The Skip button banks gold instead of taking a card (decision #33) — it emits `skipped`,
  # which the run screen forwards to RunManager.apply_draft_skip.
  var overlay: DraftOverlay = preload('res://src/scenes/screens/draft_overlay.tscn').instantiate()
  add_child(overlay)
  _nodes.append(overlay)
  overlay.setup([FixtureItems.attack()])
  watch_signals(overlay)
  var skip: Button = overlay.get_node('Panel/SkipButton')
  assert_eq(skip.text, '+%d gold' % Balance.GOLD_SKIP, 'the button shows the gold amount')
  skip.pressed.emit()
  assert_signal_emitted(overlay, 'skipped')
