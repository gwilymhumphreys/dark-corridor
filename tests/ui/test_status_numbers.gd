extends GutTest
## The health-bar status numbers (docs/systems/mechanics.md → Health bar): one label per mechanic status
## (poison, burn, bleed, regen) shows its stack count in the mechanic's colour; shield is shown by
## HealthBar instead, outside-set statuses (weak) show no label, and a null actor hides everything.


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


func _host(node: Node) -> Node:
  add_child(node)
  _nodes.append(node)
  return node


func test_poison_label_shows_its_count_and_shield_and_weak_do_not() -> void:
  var numbers: StatusNumbers = preload('res://src/scenes/combat/status_numbers.tscn').instantiate()
  _host(numbers)
  var a := _spawn(100.0)
  StatusManager.apply(a, ShieldStatus.ID, 5.0)
  StatusManager.apply(a, PoisonStatus.ID, 3.0)
  StatusManager.apply(a, 'weak', 1.0)
  numbers.actor = a
  numbers._process(0.0)
  assert_false(numbers.has_node('Shield'), 'shield has no label here: the health bar shows it')
  assert_true(numbers.get_node('Poison').visible, 'the poison label is visible')
  assert_eq(numbers.get_node('Poison/Value').text, '3', 'the poison label shows its count')
  assert_false(numbers.get_node('Burn').visible, 'no burn, no label')
  assert_false(numbers.get_node('Bleed').visible, 'no bleed, no label')
  assert_false(numbers.get_node('Regen').visible, 'no regen, no label')


func test_null_actor_hides_every_label() -> void:
  var numbers: StatusNumbers = preload('res://src/scenes/combat/status_numbers.tscn').instantiate()
  _host(numbers)
  numbers.actor = null
  numbers._process(0.0)
  for label_name in ['Poison', 'Burn', 'Bleed', 'Regen']:
    assert_false((numbers.get_node(label_name) as Control).visible, '%s is hidden with a null actor' % label_name)
