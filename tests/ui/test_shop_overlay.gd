extends GutTest
## The shop panel (docs/systems/run_screen.md): one entry per good with its price, buy buttons that
## follow what the player can afford, the pick emitted by index, and the Leave button.

var _nodes: Array = []
var _runs: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()
  FixtureContent.install()
  Save.clear()


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


# A run standing in the fixture shop with `gold`.
func _run_in_shop(gold: int) -> RunManager:
  var run := RunManager.new()
  _runs.append(run)
  EncounterPools._positions = [[FixtureEncounters.SHOP], [FixtureEncounters.EVENT], [FixtureEncounters.REWARD]]
  run.start(1, FixtureCharacter.ID)
  run.gold = gold
  run.pick_path(0)
  run.begin_current()
  return run


func _overlay(run: RunManager) -> ShopOverlay:
  var overlay: ShopOverlay = preload('res://src/scenes/screens/shop_overlay.tscn').instantiate()
  add_child(overlay)
  _nodes.append(overlay)
  overlay.setup('A fixture shop', run)
  return overlay


func _buy_button(overlay: ShopOverlay, index: int) -> Button:
  return overlay.get_node('Panel/Cards').get_child(index).get_node('Buy')


func test_the_panel_lists_the_goods_with_their_prices() -> void:
  var run := _run_in_shop(100)
  var overlay := _overlay(run)
  assert_eq(overlay.get_node('Panel/Cards').get_child_count(), run.shop_goods().size(), 'one entry per good')
  assert_eq(_buy_button(overlay, 0).text, '%d gold' % RunManager.price_of(run.shop_goods()[0]), 'the price')
  assert_false(_buy_button(overlay, 0).disabled, 'affordable, so it can be bought')


func test_buying_emits_the_index_and_refresh_marks_it_sold() -> void:
  var run := _run_in_shop(100)
  var overlay := _overlay(run)
  watch_signals(overlay)
  _buy_button(overlay, 1).pressed.emit()
  assert_signal_emitted_with_parameters(overlay, 'bought', [1])
  run.buy(1)
  overlay.refresh(run)
  assert_eq(_buy_button(overlay, 1).text, 'Sold', 'the bought good reads Sold')
  assert_true(_buy_button(overlay, 1).disabled, 'and cannot be pressed')


func test_goods_the_player_cannot_afford_are_disabled() -> void:
  var run := _run_in_shop(0)
  var overlay := _overlay(run)
  for i in run.shop_goods().size():
    assert_true(_buy_button(overlay, i).disabled, 'no gold, nothing to buy')


func test_leave_emits_left() -> void:
  var overlay := _overlay(_run_in_shop(0))
  watch_signals(overlay)
  (overlay.get_node('Panel/LeaveButton') as Button).pressed.emit()
  assert_signal_emitted(overlay, 'left')
