extends GutTest
## The slot-machine reveal of the draft and shop goods (RewardSpin, docs/systems/run_screen.md →
## Overlays): the options spin and land left to right, nothing can be picked until every option has
## landed, a click or key press lands them all, and the `reward_spin` print setting off shows the
## goods at once. In the reel style a reel ends on the good; the flicker style changes the icon in
## place. The drum's sums (RewardReel) and the reel's motion are checked on their own. Time is moved
## on by hand with `advance`.

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
  assert_true(_option(overlay, 2).reel().visible, 'the reels show')
  overlay.skip_spin()
  assert_false(overlay.is_spinning(), 'nothing spins')
  for i in 3:
    assert_not_null(_option(overlay, i).item(), 'option %d shows its good' % i)
    assert_false(_option(overlay, i).reel().visible, 'with its reel put away')


func test_each_reel_ends_on_its_good() -> void:
  var overlay := _draft()
  overlay.spin_in(_faces())
  var spin: RewardSpin = _spin(overlay)
  var reel: RewardReel = _option(overlay, 0).reel()
  assert_true(reel.visible, 'the reel shows')
  spin.advance(PrintLook.print_setting('reward_spin_time') - 0.01)
  assert_true(reel.visible, 'still turning just before it lands')
  assert_eq(reel.face_at_centre(), load(FixtureItems.attack().icon) as Texture2D, 'with the good at the centre')
  spin.advance(0.02)
  assert_false(reel.visible, 'landed, the reel is put away')
  assert_eq(_option(overlay, 0).item().def.id, FixtureItems.attack().id, 'and the cell shows the good')


func test_the_flicker_style_changes_the_icon_in_place() -> void:
  PrintLook.set_print_value('reward_spin_style', RewardSpin.Style.FLICKER)
  var overlay := _draft()
  overlay.spin_in(_faces())
  var option: RewardOption = _option(overlay, 0)
  assert_false(option.reel().visible, 'no reel')
  assert_true(_faces().has((option.cell.get_node('Frame/Icon') as TextureRect).texture), 'the cell shows a flicked icon')
  assert_null(option.item(), 'and no good')
  _spin(overlay).advance(PrintLook.print_setting('reward_spin_time') + PrintLook.print_setting('reward_spin_gap') * 3.0)
  assert_false(overlay.is_spinning(), 'every option lands')
  assert_eq(option.item().def.id, FixtureItems.attack().id, 'on its good')


func test_the_drum_shows_the_centre_face_whole_and_the_others_flatter_and_darker() -> void:
  var half_window: float = 60.0
  var radius: float = RewardReel.drum_radius(half_window, 0.8)
  var length: float = RewardReel.face_arc(80.0, radius)
  var centre: Vector3 = RewardReel.drum_place(0.0, length, half_window, radius, 0.7)
  assert_almost_eq(centre.x, -40.0, 0.01, 'the centre face is its full height')
  assert_almost_eq(centre.y, 40.0, 0.01, 'about the centre')
  assert_almost_eq(centre.z, 1.0, 0.001, 'at full brightness')
  var below: Vector3 = RewardReel.drum_place(length, length, half_window, radius, 0.7)
  assert_lt(below.y - below.x, 80.0, 'the face below is flatter')
  assert_almost_eq(below.x, centre.y, 0.01, 'and meets the centre face, so the faces bunch up without overlapping')
  assert_lt(below.z, 1.0, 'and darker')
  var behind: Vector3 = RewardReel.drum_place(radius * PI, length, half_window, radius, 0.7)
  assert_almost_eq(behind.y - behind.x, 0.0, 0.001, 'a face round the back of the drum does not show')
  var flat: Vector3 = RewardReel.drum_place(100.0, 80.0, half_window, RewardReel.drum_radius(half_window, 0.0), 0.5)
  assert_eq(flat, Vector3(60.0, 140.0, 0.5), 'with no curve the strip is flat, darkest at the window edge')


func test_a_reel_slows_overshoots_and_settles_on_its_good() -> void:
  assert_eq(RewardSpin.reel_turns(1.0, 0.15, 0.05, 0.2), 8, 'about one icon per face time at the start, slowing evenly')
  assert_almost_eq(RewardSpin.reel_position(0.0, 1.0, 8, 0.2, 0.15), 0.0, 0.001, 'it starts at the first icon')
  assert_lt(RewardSpin.reel_position(0.4, 1.0, 8, 0.2, 0.15), RewardSpin.reel_position(0.6, 1.0, 8, 0.2, 0.15), 'it turns on')
  assert_almost_eq(RewardSpin.reel_position(0.85, 1.0, 8, 0.2, 0.15), 8.2, 0.001, 'overshoots its good')
  assert_almost_eq(RewardSpin.reel_position(1.0, 1.0, 8, 0.2, 0.15), 8.0, 0.001, 'and settles back on it')
  assert_almost_eq(RewardSpin.reel_position(1.0, 1.0, 8, 0.0, 0.0), 8.0, 0.001, 'with no overshoot it stops on it')


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
  var price: String = str(run.shop_price(0))
  assert_eq(buy.text, '', 'the price is hidden while the good spins')
  buy.pressed.emit()
  (overlay.get_node('Panel/RerollButton') as Button).pressed.emit()
  assert_signal_not_emitted(overlay, 'bought', 'nothing is bought while spinning')
  assert_signal_not_emitted(overlay, 'rerolled', 'and there is no reroll')
  overlay.skip_spin()
  assert_string_contains(buy.text, price, 'the price shows once the good lands')
  buy.pressed.emit()
  assert_signal_emitted_with_parameters(overlay, 'bought', [0])
