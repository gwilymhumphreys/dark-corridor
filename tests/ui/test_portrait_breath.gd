extends GutTest
## PortraitBreath (docs/systems/ui_juice.md → Portrait breathing): the `picture_zoom` instance uniform on
## the parent's canvas item rises above 1 and comes back down, never drops below 1, and goes back to 1
## when the node leaves the tree. A parent that is not a CanvasItem disables it.


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


func _zoom(item: CanvasItem) -> float:
  return RenderingServer.canvas_item_get_instance_shader_parameter(
    item.get_canvas_item(), PortraitBreath.UNIFORM)


func _breathing_rect(amount: float, period: float) -> Array:
  var rect := TextureRect.new()
  var breath := PortraitBreath.new()
  breath.amount = amount
  breath.period = period
  rect.add_child(breath)
  _host(rect)
  return [rect, breath]


func test_zoom_stays_between_one_and_one_plus_amount_across_a_full_cycle() -> void:
  var parts: Array = _breathing_rect(0.02, 4.0)
  var rect: TextureRect = parts[0]
  var breath: PortraitBreath = parts[1]
  var highest: float = 1.0
  for i in 40:
    breath._process(0.1)
    var z: float = _zoom(rect)
    assert_between(z, 1.0, 1.02, 'the zoom stays inside the breath range')
    highest = maxf(highest, z)
  assert_almost_eq(highest, 1.02, 0.001, 'the breath reaches its full zoom somewhere in the cycle')


func test_the_node_is_not_scaled_so_it_cannot_overflow_its_frame() -> void:
  var parts: Array = _breathing_rect(0.05, 4.0)
  var rect: TextureRect = parts[0]
  var breath: PortraitBreath = parts[1]
  breath._process(1.0)
  assert_eq(rect.offset_transform_scale, Vector2.ONE, 'the zoom is in the shader, not on the node')
  assert_eq(rect.scale, Vector2.ONE, 'the layout scale is untouched')


func test_zoom_returns_to_one_when_the_node_leaves_the_tree() -> void:
  var parts: Array = _breathing_rect(0.05, 4.0)
  var rect: TextureRect = parts[0]
  var breath: PortraitBreath = parts[1]
  breath._process(1.0)
  assert_ne(_zoom(rect), 1.0, 'the breath moved the zoom off 1')
  breath.free()
  assert_almost_eq(_zoom(rect), 1.0, 0.0001, 'the zoom is back to 1')


func test_a_parent_that_is_not_a_canvas_item_disables_the_breath() -> void:
  var holder := Node.new()
  var breath := PortraitBreath.new()
  holder.add_child(breath)
  _host(holder)
  assert_false(breath.is_processing(), 'processing is off without a canvas item to zoom')
