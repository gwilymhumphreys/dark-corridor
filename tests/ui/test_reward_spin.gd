extends GutTest
## The slot-machine reveal of the draft and shop goods (RewardSpin, docs/systems/run_screen.md →
## Overlays): the options flick through icons and land left to right, nothing can be picked until
## every option has landed, a click or key press lands them all, and the `reward_spin` print
## setting off shows the goods at once. Time is moved on by hand with `advance`.

var _nodes: Array = []
var _runs: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for n in _nodes:
    if is_instance_valid(n):
      n.free()
  _nodes.clear()
  for r in _runs:
    if is_instance_valid(r):
      r.teardown()
      r.free()
  _runs.clear()
  Save.clear()
  TestCleanup.reset_all_managers()


# The icons of the fixture items, to flick through.
func _faces() -> Array[Texture2D]:
  var faces: Array[Texture2D] = []
  for def: ItemDef in [FixtureItems.attack(), FixtureItems.shield(), FixtureItems.poison()]:
    faces.append(load(def.icon) as Texture2D)
  return faces


func _draft() -> DraftOverlay:
  var overlay: DraftOverlay = preload('res://src/scenes/screens/draft_overlay.tscn').instantiate()
  add_child(overlay)
  _nodes.append(overlay)
  overlay.setup([FixtureItems.attack(), FixtureItems.shield(), FixtureItems.poison()])
  return overlay


func _option(overlay: DraftOverlay, index: int) -> RewardOption:
  return overlay.get_node('Panel/Cards').get_child(index)


func _spin(overlay: Control) -> RewardSpin:
  return overlay.get_node('Spin')


func test_a_spinning_option_shows_no_good_and_cannot_be_picked() -> void:
  var overlay := _draft()
  overlay.spin_in(_faces())
  assert_true(overlay.is_spinning(), 'the options spin')
  assert_null(_option(overlay, 0).item(), 'a spinning option offers no good, so it has no tooltip')
  watch_signals(overlay)
  _option(overlay, 0).pressed.emit()
  (overlay.get_node('Panel/SkipButton') as Button).pressed.emit()
  assert_signal_not_emitted(overlay, 'picked', 'no pick while spinning')
  assert_signal_not_emitted(overlay, 'skipped', 'and no gold either')


func test_the_options_land_left_to_right_then_can_be_picked() -> void:
  var overlay := _draft()
  overlay.spin_in(_faces())
  var spin: RewardSpin = _spin(overlay)
  var first: float = PrintLook.print_setting('reward_spin_time')
  var gap: float = PrintLook.print_setting('reward_spin_gap')
  watch_signals(spin)
  spin.advance(first + gap * 0.5)
  assert_not_null(_option(overlay, 0).item(), 'the first option has landed')
  assert_null(_option(overlay, 1).item(), 'the second has not')
  assert_true(overlay.is_spinning(), 'so the panel is still spinning')
  spin.advance(gap * 2.0)
  assert_false(overlay.is_spinning(), 'every option has landed')
  assert_signal_emitted(spin, 'landed')
  assert_eq(_option(overlay, 2).item().def.id, FixtureItems.poison().id, 'each on its own good')
  watch_signals(overlay)
  _option(overlay, 1).pressed.emit()
  assert_signal_emitted_with_parameters(overlay, 'picked', [1])


func test_skip_lands_every_option_at_once() -> void:
  var overlay := _draft()
  overlay.spin_in(_faces())
  overlay.skip_spin()
  assert_false(overlay.is_spinning(), 'nothing spins')
  for i in 3:
    assert_not_null(_option(overlay, i).item(), 'option %d shows its good' % i)


func test_a_click_or_a_key_lands_every_option() -> void:
  var overlay := _draft()
  overlay.spin_in(_faces())
  var click := InputEventMouseButton.new()
  click.button_index = MOUSE_BUTTON_LEFT
  click.pressed = true
  _spin(overlay)._input(click)
  assert_false(overlay.is_spinning(), 'a click lands them')
  overlay.spin_in(_faces())
  var key := InputEventKey.new()
  key.keycode = KEY_A
  key.pressed = true
  _spin(overlay)._input(key)
  assert_false(overlay.is_spinning(), 'and so does a key press')


func test_the_spin_off_shows_the_goods_at_once() -> void:
  PrintLook.set_print_value('reward_spin', false)
  var overlay := _draft()
  overlay.spin_in(_faces())
  assert_false(overlay.is_spinning(), 'no spin')
  assert_not_null(_option(overlay, 0).item(), 'the good is shown')
  watch_signals(overlay)
  _option(overlay, 0).pressed.emit()
  assert_signal_emitted_with_parameters(overlay, 'picked', [0])


func test_the_shop_goods_cannot_be_bought_until_they_land() -> void:
  FixtureContent.install()
  Save.clear()
  var run := RunManager.new()
  _runs.append(run)
  EncounterPools._positions = [[FixtureEncounters.SHOP], [FixtureEncounters.EVENT], [FixtureEncounters.REWARD]]
  run.start(1, FixtureCharacter.ID)
  run.gold = 100
  run.pick_path(0)
  run.begin_current()
  var overlay: ShopOverlay = preload('res://src/scenes/screens/shop_overlay.tscn').instantiate()
  add_child(overlay)
  _nodes.append(overlay)
  overlay.setup('A fixture shop', run)
  overlay.spin_in()   # the item catalog is the fixtures', so its icons are flicked through
  assert_true(overlay.is_spinning(), 'the goods spin')
  watch_signals(overlay)
  var buy: Button = overlay.get_node('Panel/Cards').get_child(0).get_node('Buy')
  buy.pressed.emit()
  (overlay.get_node('Panel/RerollButton') as Button).pressed.emit()
  assert_signal_not_emitted(overlay, 'bought', 'nothing is bought while spinning')
  assert_signal_not_emitted(overlay, 'rerolled', 'and there is no reroll')
  overlay.skip_spin()
  buy.pressed.emit()
  assert_signal_emitted_with_parameters(overlay, 'bought', [0])
