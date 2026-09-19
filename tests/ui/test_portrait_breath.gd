extends GutTest
## PortraitBreath (docs/systems/ui_juice.md → Portrait breathing): the parent Control's visual-only
## scale rises above 1 and comes back down, never drops below 1, and returns to 1 when the node leaves
## the tree. A non-Control parent disables it.


var _nodes: Array = []


func after_each() -> void:
  for n in _nodes:
    if is_instance_valid(n):
      n.free()
  _nodes.clear()


func _host(node: Node) -> Node:
  add_child(node)
  _nodes.append(node)
  return node


func _breathing_rect(amount: float, period: float) -> Array:
  var rect := TextureRect.new()
  var breath := PortraitBreath.new()
  breath.amount = amount
  breath.period = period
  rect.add_child(breath)
  _host(rect)
  return [rect, breath]


func test_scale_stays_between_one_and_one_plus_amount_across_a_full_cycle() -> void:
  var parts: Array = _breathing_rect(0.02, 4.0)
  var rect: TextureRect = parts[0]
  var breath: PortraitBreath = parts[1]
  assert_true(rect.offset_transform_enabled, 'the offset transform is switched on')
  var highest: float = 1.0
  for i in 40:
    breath._process(0.1)
    var s: float = rect.offset_transform_scale.x
    assert_between(s, 1.0, 1.02, 'scale stays inside the breath range')
    highest = maxf(highest, s)
  assert_almost_eq(highest, 1.02, 0.001, 'the breath reaches its full size somewhere in the cycle')


func test_scale_returns_to_one_when_the_node_leaves_the_tree() -> void:
  var parts: Array = _breathing_rect(0.05, 4.0)
  var rect: TextureRect = parts[0]
  var breath: PortraitBreath = parts[1]
  breath._process(1.0)
  assert_ne(rect.offset_transform_scale.x, 1.0, 'the breath moved the scale off its resting size')
  breath.free()
  assert_eq(rect.offset_transform_scale, Vector2.ONE, 'the resting size is restored')


func test_a_non_control_parent_disables_the_breath() -> void:
  var holder := Node.new()
  var breath := PortraitBreath.new()
  holder.add_child(breath)
  _host(holder)
  assert_false(breath.is_processing(), 'processing is off without a Control to scale')
