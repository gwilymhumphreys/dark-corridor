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


func test_overlay_shows_each_offer_at_its_level() -> void:
  var overlay: DraftOverlay = preload('res://src/scenes/screens/draft_overlay.tscn').instantiate()
  add_child(overlay)
  _nodes.append(overlay)
  var levels: Array[int] = [1, 3]
  overlay.setup([FixtureItems.attack(), FixtureItems.shield()], levels)
  var cards: Node = overlay.get_node('Panel/Cards')
  assert_eq((cards.get_child(0) as RewardOption).item().level, 1, 'the first at level 1')
  assert_eq((cards.get_child(1) as RewardOption).item().level, 3, 'the second at its offered level')


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


func test_overlay_offers_relics() -> void:
  var overlay: DraftOverlay = preload('res://src/scenes/screens/draft_overlay.tscn').instantiate()
  add_child(overlay)
  _nodes.append(overlay)
  var relic: RelicDef = FixtureKit.shield_relic()
  overlay.setup([relic, FixtureKit.max_hp_relic()])
  assert_eq(overlay.get_node('Panel/Cards').get_child_count(), 2, 'one option per relic')
  var option: RewardOption = overlay.get_node('Panel/Cards').get_child(0)
  var target: Dictionary = overlay.inspectable_at(option.get_global_rect().get_center())
  assert_eq((target['item'] as Item).def, relic, 'the relic option shows the item tooltip for the relic')
  watch_signals(overlay)
  (overlay.get_node('Panel/Cards').get_child(1) as RewardOption).pressed.emit()
  assert_signal_emitted_with_parameters(overlay, 'picked', [1])


func test_overlay_shows_a_potion_like_an_item() -> void:
  var overlay: DraftOverlay = preload('res://src/scenes/screens/draft_overlay.tscn').instantiate()
  add_child(overlay)
  _nodes.append(overlay)
  overlay.setup([FixtureKit.potion()])
  var option: RewardOption = overlay.get_node('Panel/Cards').get_child(0)
  assert_eq(option.item().def.id, FixtureKit.POTION_ID, 'the option shows an Item built from the potion')
  assert_eq(overlay.inspectable_at(option.get_global_rect().get_center()).get('item'), option.item(),
    'so it has the item tooltip')
  watch_signals(overlay)
  option.pressed.emit()
  assert_signal_emitted_with_parameters(overlay, 'picked', [0])
