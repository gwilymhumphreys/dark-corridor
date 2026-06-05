class_name ItemIcon
extends Node2D
## Placeholder board-item view: an opaque colour panel + its value, a radial
## cooldown ring (Bazaar-style), and a scale-punch recoil when the item fires.
## No alpha — VFX grows incrementally. Reads the live Item; writes nothing.

const SIZE := Vector2(120, 120)

var item: Item
var _value: Label
var _last_progress: float = 0.0
var _scale_tween: Tween


func setup(target_item: Item) -> void:
  item = target_item
  _value = Label.new()
  _value.text = _value_text()
  _value.add_theme_font_size_override('font_size', 44)
  _value.size = SIZE
  _value.position = -SIZE * 0.5
  _value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  add_child(_value)


func _value_text() -> String:
  if item.def.effects.is_empty():
    return ''
  return str(int(item.def.effects[0].value))


func _process(_delta: float) -> void:
  var p: float = item.cooldown.progress()
  if p < _last_progress - 0.2:   # cooldown reset -> it just fired
    _recoil()
  _last_progress = p
  queue_redraw()


func _draw() -> void:
  draw_rect(Rect2(-SIZE * 0.5, SIZE), item.def.panel_color)
  draw_rect(Rect2(-SIZE * 0.5, SIZE), Color.BLACK, false, 3.0)
  var prog: float = item.cooldown.progress()
  if prog < 1.0:
    draw_arc(Vector2.ZERO, SIZE.x * 0.5 + 10.0, -PI * 0.5, -PI * 0.5 + prog * TAU, 48, Color(0.95, 0.95, 0.95), 5.0)


func _recoil() -> void:
  if _scale_tween != null and _scale_tween.is_valid():
    _scale_tween.kill()
  scale = Vector2(1.3, 1.3)
  _scale_tween = create_tween()
  _scale_tween.tween_property(self, 'scale', Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func contains_point(p: Vector2) -> bool:
  return Rect2(global_position - SIZE * 0.5, SIZE).has_point(p)
