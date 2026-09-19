extends GutTest
## The Icons tab (docs/systems/debug_panel.md): it builds for every icon slot, including the two
## that are not mechanics. `charge_time` and `card` have no `Mechanic` class, so they get no keyword
## chip and no colour row, and those branches are only reached by selecting them.

const ICON_PANEL: PackedScene = preload('res://src/debug/icon_panel.tscn')

var _panel: IconPanel = null


func before_each() -> void:
  TestCleanup.reset_all_managers()
  _panel = ICON_PANEL.instantiate() as IconPanel
  add_child_autofree(_panel)


func after_each() -> void:
  _panel = null
  TestCleanup.reset_all_managers()


## Build the tab with `slot` selected, and return its sections.
func _sections_for(slot: String) -> Array[Node]:
  _panel._slot_index = IconSlots.SLOTS.find(slot)
  _panel.rebuild()
  return _panel.get_node('Scroll/Sections').get_children()


func test_every_slot_builds_a_choose_and_a_samples_section() -> void:
  for slot: String in IconSlots.SLOTS:
    assert_eq(_sections_for(slot).size(), 2, '%s builds Choose and Samples' % slot)


func test_a_mechanic_slot_has_a_colour_row() -> void:
  var rows: Array[Node] = _sections_for('attack')[0].get_node('Rows').get_children()
  assert_eq(rows.size(), 3, 'a mechanic slot has Slot, Icon and Colour rows')


func test_a_slot_that_is_not_a_mechanic_has_no_colour_row() -> void:
  for slot: String in ['charge_time', 'card']:
    var rows: Array[Node] = _sections_for(slot)[0].get_node('Rows').get_children()
    assert_eq(rows.size(), 2, '%s has Slot and Icon rows only' % slot)


func test_the_icon_row_starts_on_the_icon_in_use() -> void:
  _sections_for('attack')
  var candidates: Array[String] = IconSlots.candidates('attack')
  assert_eq(candidates[_panel._icon_index], IconSlots.icon_for('attack'),
      'the Icon dropdown starts on the icon the slot actually uses')
