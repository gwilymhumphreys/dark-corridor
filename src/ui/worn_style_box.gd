class_name WornStyleBox
extends StyleBox
## Wraps a `StyleBox` with panel wear (docs/systems/panel_wear.md). Instead of drawing `base` normally,
## it asks `PrintLook` for a canvas item behind the control (`PrintLook.panel_wear_child`) and draws
## `base` into that, through `PrintLook.panel_material` (panel_wear.gdshader), so the control's own text
## and child nodes stay on top, unworn. Content margins and minimum size follow `base`, so wrapping a
## style does not change layout.
##
## Limit: a control's `self_modulate` does not reach the worn copy (its `modulate` does), because the
## copy is a separate canvas item parented to the control's own, not drawn by the control itself.

@export var base: StyleBox:
  set(value):
    base = value
    if base != null:
      content_margin_left = base.content_margin_left
      content_margin_top = base.content_margin_top
      content_margin_right = base.content_margin_right
      content_margin_bottom = base.content_margin_bottom

# `PrintLook` is looked up by node path rather than referenced as the bare autoload identifier: this
# script is a dependency of the project's default theme, which Godot loads before autoloads are
# registered, and resolving the identifier that early would break the script for the rest of the run.
static var _print_look: PrintLookAutoload


func _get_minimum_size() -> Vector2:
  return base.get_minimum_size() if base != null else Vector2.ZERO


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
  if base == null:
    return
  var look: PrintLookAutoload = _print_look_autoload()
  var child: RID = look.panel_wear_child(to_canvas_item, rect)
  RenderingServer.canvas_item_set_instance_shader_parameter(
    child, 'panel_rect', Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
  base.draw(child, rect)


func _print_look_autoload() -> PrintLookAutoload:
  if _print_look == null:
    _print_look = (Engine.get_main_loop() as SceneTree).root.get_node('PrintLook') as PrintLookAutoload
  return _print_look
