extends GutTest
## The character panel's status row (docs/systems/run_screen.md): with the `status_layout` print
## setting at Under bar it sits between the bar and the item row, and at Under items it sits after
## the item row, so a status appearing does not push the items down.


const PANEL_SCENE: PackedScene = preload('res://src/scenes/combat/enemy_hud.tscn')

var _panel: CharacterPanel = null


func before_each() -> void:
  TestCleanup.reset_all_managers()
  _panel = PANEL_SCENE.instantiate() as CharacterPanel
  add_child(_panel)


func after_each() -> void:
  if is_instance_valid(_panel):
    _panel.free()
  _panel = null
  TestCleanup.reset_all_managers()


func _index(node_name: String) -> int:
  return _panel.get_node('Row/Readout/' + node_name).get_index()


func test_statuses_under_items_come_after_the_item_row() -> void:
  _panel.set_layout(CharacterPanel.ItemLayout.UNDER, CharacterPanel.StatusLayout.UNDER_ITEMS)
  assert_gt(_index('StatusesUnder'), _index('Items'), 'the status row is below the item row')
  assert_true(_panel.get_node('Row/Readout/StatusesUnder').visible, 'the one-row status icons show')


func test_switching_back_puts_the_statuses_under_the_bar() -> void:
  _panel.set_layout(CharacterPanel.ItemLayout.UNDER, CharacterPanel.StatusLayout.UNDER_ITEMS)
  _panel.set_layout(CharacterPanel.ItemLayout.UNDER, CharacterPanel.StatusLayout.UNDER_BAR)
  assert_eq(_index('StatusesUnder'), _index('Top') + 1, 'the status row is straight under the bar')
  assert_lt(_index('StatusesUnder'), _index('Items'), 'the item row is below the status row')
