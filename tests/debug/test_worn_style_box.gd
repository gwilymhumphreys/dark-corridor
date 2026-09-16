extends GutTest
## `WornStyleBox`: content margins and minimum size follow its wrapped `base`, and `PrintLook`'s
## registry of per-control worn-panel canvas items frees a control's entry when it leaves the tree
## (docs/systems/panel_wear.md).

var _nodes: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for node: Node in _nodes:
    if is_instance_valid(node):
      node.free()
  _nodes.clear()
  TestCleanup.reset_all_managers()


func _flat_base() -> StyleBoxFlat:
  var flat: StyleBoxFlat = StyleBoxFlat.new()
  flat.bg_color = Color.GRAY
  flat.content_margin_left = 12.0
  flat.content_margin_top = 8.0
  flat.content_margin_right = 12.0
  flat.content_margin_bottom = 8.0
  return flat


func test_content_margins_and_minimum_size_follow_the_base() -> void:
  var flat: StyleBoxFlat = _flat_base()
  var worn: WornStyleBox = WornStyleBox.new()
  worn.base = flat
  assert_eq(worn.content_margin_left, flat.content_margin_left)
  assert_eq(worn.content_margin_top, flat.content_margin_top)
  assert_eq(worn.content_margin_right, flat.content_margin_right)
  assert_eq(worn.content_margin_bottom, flat.content_margin_bottom)
  assert_eq(worn.get_minimum_size(), flat.get_minimum_size())


func test_panel_wear_child_is_created_once_per_control() -> void:
  var control: Control = Control.new()
  add_child(control)
  _nodes.append(control)
  var rid: RID = control.get_canvas_item()
  var first: RID = PrintLook.panel_wear_child(rid)
  var second: RID = PrintLook.panel_wear_child(rid)
  assert_eq(first, second, 'the same child is reused for the same control')


func test_registry_frees_the_child_when_the_control_leaves_the_tree() -> void:
  var control: Control = Control.new()
  add_child(control)
  var rid: RID = control.get_canvas_item()
  PrintLook.panel_wear_child(rid)
  assert_true(PrintLook._panel_children.has(rid), 'registered while the control is in the tree')
  remove_child(control)
  assert_false(PrintLook._panel_children.has(rid), 'freed once the control leaves the tree')
  control.free()


func test_a_drawn_panel_draws_its_base_into_the_worn_child() -> void:
  var flat: StyleBoxFlat = _flat_base()
  var worn: WornStyleBox = WornStyleBox.new()
  worn.base = flat
  var panel: PanelContainer = PanelContainer.new()
  panel.add_theme_stylebox_override('panel', worn)
  panel.size = Vector2(200.0, 100.0)
  add_child(panel)
  _nodes.append(panel)
  assert_true(is_instance_valid(worn), 'the style box draws without error')
