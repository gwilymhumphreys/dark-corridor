class_name UIJuice
extends Node

## Drop-in juice for any Control.
##
## Add this as a child of a Button (or any Control) and it gives the parent
## press life: a centred squash on press, plus hover/click sounds via SfxManager.
## Hover feedback is the theme's hover colour only; there is no hover size change.
## Pick a Preset for the feel; override individual values only when you need to.
##
## Works on any Control (covers all UI). Press effects additionally fire on
## BaseButton via its button_down / button_up / pressed signals. Sounds fall
## back to SfxManager's shared bank unless you assign per-node streams.

enum Preset {
  BUTTON,  ## Standard menu/control button: modest squash, snappy.
  CARD,  ## Gentler, slower squash — for big interactive panels.
  ICON,  ## Small, punchy squash — for icon/toolbar buttons.
}

const _PRESETS: Dictionary = {
  Preset.BUTTON: {
    'press_scale': 0.94,
    'release_time': 0.15,
    'press_time': 0.07,
  },
  Preset.CARD: {
    'press_scale': 0.97,
    'release_time': 0.18,
    'press_time': 0.08,
  },
  Preset.ICON: {
    'press_scale': 0.9,
    'release_time': 0.12,
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
## Squash size multiplier while pressed. -1 keeps the preset value.
@export var press_scale: float = _INHERIT

var _target: Control
var _is_button: bool = false
var _tween: Tween

# Resolved feel (preset merged with overrides).
var _press_scale: float
var _release_time: float
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
  # fights the container that lays this Control out. The pivot ratio defaults to
  # (0.5, 0.5), so scaling shrinks towards the centre at any size.
  _target.offset_transform_enabled = true
  _target.mouse_entered.connect(_on_mouse_entered)
  if _is_button:
    var btn: BaseButton = _target as BaseButton
    btn.button_down.connect(_on_button_down)
    btn.button_up.connect(_on_button_up)
    btn.pressed.connect(_on_pressed)


func _resolve_feel() -> void:
  var p: Dictionary = _PRESETS[preset]
  _press_scale = p['press_scale'] if press_scale < 0.0 else press_scale
  _release_time = p['release_time']
  _press_time = p['press_time']


func _on_mouse_entered() -> void:
  if _is_button and (_target as BaseButton).disabled:
    return
  if play_sounds:
    _play_hover()


func _on_button_down() -> void:
  if (_target as BaseButton).disabled:
    return
  _scale_to(_press_scale, _press_time, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _on_button_up() -> void:
  _scale_to(1.0, _release_time, Tween.TRANS_BACK, Tween.EASE_OUT)


func _on_pressed() -> void:
  if play_sounds:
    _play_click()


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
  # Drop the parent's signal connections before releasing the ref, so the
  # still-alive parent cannot call back into this node during teardown.
  if is_instance_valid(_target):
    _target.mouse_entered.disconnect(_on_mouse_entered)
    if _is_button:
      var btn: BaseButton = _target as BaseButton
      btn.button_down.disconnect(_on_button_down)
      btn.button_up.disconnect(_on_button_up)
      btn.pressed.disconnect(_on_pressed)
  _target = null
