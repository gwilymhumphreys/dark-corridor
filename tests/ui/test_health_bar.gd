extends GutTest
## The shared health bar (docs/systems/mechanics.md → Health bar): the bar's width stands for max
## health or shield, whichever is larger; shield fills over health from the left; the shield icon
## and value sit above the bar and keep their space when shield is 0.


var _nodes: Array = []
var _actors: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for n in _nodes:
    if is_instance_valid(n):
      n.free()
  _nodes.clear()
  for a in _actors:
    if is_instance_valid(a):
      a.dissolve()
  _actors.clear()
  TestCleanup.reset_all_managers()


func _spawn(hp: float) -> Actor:
  var a := Actor.new(hp)
  _actors.append(a)
  return a


func _bar_for(a: Actor) -> HealthBar:
  var bar: HealthBar = preload('res://src/scenes/combat/health_bar.tscn').instantiate()
  add_child(bar)
  _nodes.append(bar)
  bar.actor = a
  bar._process(0.0)
  return bar


func test_no_shield_hides_the_readout() -> void:
  var a := _spawn(100.0)
  a.take_damage(40.0)
  var bar := _bar_for(a)
  var row: Control = bar.get_node('Bar/Shield')
  assert_false(row.visible, 'the shield readout on the bar is hidden with no shield')
  assert_almost_eq(bar.get_node('Bar/HealthFill').anchor_right, 0.6, 0.0001, 'health fills 60 of 100')
  assert_eq(bar.get_node('Bar/ShieldFill').anchor_right, 0.0, 'no shield fill')
  assert_eq(bar.get_node('Bar/Label').text, '60', 'the label shows current health only')


func test_shield_below_max_health_is_measured_against_max_health() -> void:
  var a := _spawn(100.0)
  StatusManager.apply(a, ShieldStatus.ID, 25.0)
  var bar := _bar_for(a)
  assert_true(bar.get_node('Bar/Shield').visible, 'the readout shows')
  assert_eq(bar.get_node('Bar/Shield/Value').text, '25', 'with the shield value')
  assert_almost_eq(bar.get_node('Bar/ShieldFill').anchor_right, 0.25, 0.0001, 'shield fills 25 of 100')
  assert_almost_eq(bar.get_node('Bar/HealthFill').anchor_right, 1.0, 0.0001, 'health is full underneath')


func test_shield_above_max_health_becomes_the_scale() -> void:
  var a := _spawn(100.0)
  StatusManager.apply(a, ShieldStatus.ID, 250.0)
  var bar := _bar_for(a)   # binding the actor sets the scale at once, with no easing
  assert_almost_eq(bar.get_node('Bar/ShieldFill').anchor_right, 1.0, 0.0001, 'shield fills the bar')
  assert_almost_eq(bar.get_node('Bar/HealthFill').anchor_right, 0.4, 0.0001, 'health shrinks to 100 of 250')


func test_the_scale_eases_back_when_shield_drops() -> void:
  var a := _spawn(100.0)
  StatusManager.apply(a, ShieldStatus.ID, 200.0)
  var bar := _bar_for(a)
  StatusManager.reduce(a, ShieldStatus.ID, 200.0)
  bar._process(0.01)
  var health: float = bar.get_node('Bar/HealthFill').anchor_right
  assert_between(health, 0.5, 1.0, 'part way from 100 of 200 back towards full width')
  for i in 200:
    bar._process(0.05)
  assert_almost_eq(bar.get_node('Bar/HealthFill').anchor_right, 1.0, 0.0001, 'settles at max health')
