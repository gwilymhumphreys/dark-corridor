class_name PopAnimation
extends RefCounted
## Two short animations for a status icon (docs/systems/run_screen.md): `pop_in` when it
## first appears, growing from nothing past full size and settling back while it brightens and
## fades to normal, and `bump` when its value rises, a smaller grow and settle. Both tween the
## Control's visual-only offset transform, so they do not disturb container layout. A new animation
## on the same Control stops the one before it.

const POP_TIME: float = 0.35       # seconds a pop-in takes
const POP_BRIGHTNESS: float = 1.8  # how bright a popped-in control starts, fading to normal
const BUMP_SCALE: float = 1.3      # how large a bump makes the control before it settles
const BUMP_TIME: float = 0.2       # seconds a bump takes
const TWEEN_META: StringName = &'pop_animation_tween'


static func pop_in(target: Control) -> void:
  var tween: Tween = _start(target)
  target.offset_transform_scale = Vector2.ZERO
  target.modulate = Color(POP_BRIGHTNESS, POP_BRIGHTNESS, POP_BRIGHTNESS)
  tween.tween_property(target, 'offset_transform_scale', Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tween.parallel().tween_property(target, 'modulate', Color.WHITE, POP_TIME)


static func bump(target: Control) -> void:
  var tween: Tween = _start(target)
  target.offset_transform_scale = Vector2.ONE * BUMP_SCALE
  tween.tween_property(target, 'offset_transform_scale', Vector2.ONE, BUMP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Stop any animation already running on `target`, set it up to scale about its centre, and return a
# new tween bound to it, so the tween dies with the node.
static func _start(target: Control) -> Tween:
  if target.has_meta(TWEEN_META):
    var old: Tween = target.get_meta(TWEEN_META)
    if old != null and old.is_valid():
      old.kill()
  target.offset_transform_enabled = true
  target.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
  target.modulate = Color.WHITE
  var tween: Tween = target.create_tween()
  target.set_meta(TWEEN_META, tween)
  return tween
