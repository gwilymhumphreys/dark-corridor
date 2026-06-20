class_name UIJuice
extends Node

## Drop-in juice for any Control.
##
## Add this as a child of a Button (or any Control) and it gives the parent
## hover/press life: a centred scale bounce on mouse-over and a squash on press,
## plus hover/click sounds via SfxManager. Pick a Preset for the feel; override
## individual values only when you need to.
##
## Works on any Control (covers all UI). Press effects additionally fire on
## BaseButton via its button_down / button_up / pressed signals. Sounds fall
## back to SfxManager's shared bank unless you assign per-node streams.

enum Preset {
  BUTTON,  ## Standard menu/control button: modest pop, snappy.
  CARD,  ## Larger, slower, lifts slightly — for big interactive panels.
  ICON,  ## Small, punchy pop — for icon/toolbar buttons.
}

const _PRESETS: Dictionary = {
  Preset.BUTTON: {
    'hover_scale': 1.06,
    'overshoot_scale': 1.13,
    'press_scale': 0.94,
    'lift': 0.0,
    'rise_time': 0.12,
    'settle_time': 0.18,
    'exit_time': 0.15,
    'press_time': 0.07,
  },
  Preset.CARD: {
    'hover_scale': 1.04,
    'overshoot_scale': 1.09,
    'press_scale': 0.97,
    'lift': 6.0,
    'rise_time': 0.16,
    'settle_time': 0.22,
    'exit_time': 0.18,
    'press_time': 0.08,
  },
  Preset.ICON: {
    'hover_scale': 1.12,
    'overshoot_scale': 1.22,
    'press_scale': 0.9,
    'lift': 0.0,
    'rise_time': 0.09,
    'settle_time': 0.14,
    'exit_time': 0.12,
    'press_time': 0.06,
  },
}

# Sentinel for the override exports: a negative value keeps the preset's value.
const _INHERIT: float = -1.0

@export var preset: Preset = Preset.BUTTON

@export var play_sounds: bool = true
## Optional per-node sound overrides; leave null to use SfxManager's shared bank.
@export var hover_sound: AudioStream
@export var click_sound: AudioStream

@export_group('Overrides')
## Resting hover size multiplier. -1 keeps the preset value.
@export var hover_scale: float = _INHERIT
## Squash size multiplier while pressed. -1 keeps the preset value.
@export var press_scale: float = _INHERIT
## Pixels the node rises on hover. -1 keeps the preset value.
@export var lift: float = _INHERIT

var _target: Control
var _is_button: bool = false
var _hovered: bool = false
var _tween: Tween

# Resolved feel (preset merged with overrides).
var _hover_scale: float
var _overshoot_scale: float
var _press_scale: float
var _lift: float
var _rise_time: float
var _settle_time: float
var _exit_time: float
var _press_time: float


func _ready() -> void:
  var parent: Node = get_parent()
  if not (parent is Control):
    push_warning('UIJuice: parent is not a Control; juice disabled. Parent=%s' % str(parent))
    return
  _target = parent as Control
  _is_button = _target is BaseButton
  _resolve_feel()
  # Animate via the Godot 4.7 offset transform: it is visual-only, so juice never
  # fights the container that lays this Control out (this is what frees `lift`).
  # The pivot ratio defaults to (0.5, 0.5), so scaling grows from the centre at any
  # size — no manual pivot recompute on resize needed.
  _target.offset_transform_enabled = true
  _target.mouse_entered.connect(_on_mouse_entered)
  _target.mouse_exited.connect(_on_mouse_exited)
  if _is_button:
    var btn: BaseButton = _target as BaseButton
    btn.button_down.connect(_on_button_down)
    btn.button_up.connect(_on_button_up)
    btn.pressed.connect(_on_pressed)


func _resolve_feel() -> void:
  var p: Dictionary = _PRESETS[preset]
  _hover_scale = p['hover_scale'] if hover_scale < 0.0 else hover_scale
  _press_scale = p['press_scale'] if press_scale < 0.0 else press_scale
  _lift = p['lift'] if lift < 0.0 else lift
  _overshoot_scale = p['overshoot_scale']
  _rise_time = p['rise_time']
  _settle_time = p['settle_time']
  _exit_time = p['exit_time']
  _press_time = p['press_time']


func _on_mouse_entered() -> void:
  if _is_button and (_target as BaseButton).disabled:
    return
  _hovered = true
  if play_sounds:
    _play_hover()
  _bounce_to(_hover_scale, true)


func _on_mouse_exited() -> void:
  _hovered = false
  _settle()


func _on_button_down() -> void:
  if (_target as BaseButton).disabled:
    return
  _scale_to(_press_scale, _press_time, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _on_button_up() -> void:
  if _hovered:
    _bounce_to(_hover_scale, false)
  else:
    _settle()


func _on_pressed() -> void:
  if play_sounds:
    _play_click()


## Two-stage pop: overshoot past the target size then settle back. The settle
## uses TRANS_BACK so it dips slightly for a secondary bounce. `from_rest` true
## plays the bigger entry overshoot (hover); false is the smaller release pop.
func _bounce_to(target_factor: float, from_rest: bool) -> void:
  _kill_tween()
  _tween = _target.create_tween()
  var peak: float = _overshoot_scale if from_rest else maxf(target_factor, _press_scale) + 0.04
  _tween.tween_property(_target, 'offset_transform_scale', Vector2.ONE * peak, _rise_time) \
    .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
  _tween.tween_property(_target, 'offset_transform_scale', Vector2.ONE * target_factor, _settle_time) \
    .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
  if _lift > 0.0:
    _tween.parallel().tween_property(_target, 'offset_transform_position:y', -_lift, _rise_time) \
      .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _settle() -> void:
  _kill_tween()
  _tween = _target.create_tween()
  _tween.tween_property(_target, 'offset_transform_scale', Vector2.ONE, _exit_time) \
    .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
  if _lift > 0.0:
    _tween.parallel().tween_property(_target, 'offset_transform_position:y', 0.0, _exit_time) \
      .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _scale_to(target_factor: float, time: float, trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
  _kill_tween()
  _tween = _target.create_tween()
  _tween.tween_property(_target, 'offset_transform_scale', Vector2.ONE * target_factor, time).set_trans(trans).set_ease(ease_type)


func _play_hover() -> void:
  if hover_sound:
    SfxManager.play_guarded('ui_hover', hover_sound)
  else:
    SfxManager.play_ui_hover()


func _play_click() -> void:
  if click_sound:
    SfxManager.play_guarded('ui_click', click_sound)
  else:
    SfxManager.play_ui_click()


func _kill_tween() -> void:
  if _tween and _tween.is_valid():
    _tween.kill()


func _exit_tree() -> void:
  _kill_tween()
  _tween = null
  # Drop the parent's signal connections before releasing the ref — otherwise the
  # still-alive parent can emit mouse_exited during teardown and _settle() would
  # call create_tween() on a null _target.
  if is_instance_valid(_target):
    _target.mouse_entered.disconnect(_on_mouse_entered)
    _target.mouse_exited.disconnect(_on_mouse_exited)
    if _is_button:
      var btn: BaseButton = _target as BaseButton
      btn.button_down.disconnect(_on_button_down)
      btn.button_up.disconnect(_on_button_up)
      btn.pressed.disconnect(_on_pressed)
  _target = null
