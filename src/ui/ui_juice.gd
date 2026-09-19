class_name UIJuice
extends Node

## Drop-in juice for any Control.
##
## Add this as a child of a Button (or any Control) and it gives the parent
## press life: a centred squash and a small drop on press, the highlight that
## answers the pointer (docs/systems/control_feedback.md), and hover/click sounds
## via SfxManager. Pick a Preset for the feel; override individual values only
## when you need to.
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

enum Highlight {
  FROM_PRESET,  ## Fill and border on the BUTTON preset, border only on CARD and ICON.
  BORDER,  ## Border only: for a control whose body is a picture.
  FILL,  ## Border, and the whole body lights up: for a plain button.
  NONE,  ## No highlight at all.
}

# Sentinel for the override exports: a negative value keeps the preset's value.
const _INHERIT: float = -1.0

@export var preset: Preset = Preset.BUTTON

@export var play_sounds: bool = true
## Optional per-node sound overrides; leave null to use SfxManager's shared bank.
@export var hover_sound: AudioStream
@export var click_sound: AudioStream

## How this control answers the pointer; FROM_PRESET follows the Preset above.
@export var highlight: Highlight = Highlight.FROM_PRESET
## The Control the highlight is drawn on, when it is not this node's parent — an item cell draws it
## on its frame, not on the cell rectangle its value pills hang outside of. Empty means the parent.
@export var highlight_target: NodePath

@export_group('Overrides')
## Squash size multiplier while pressed. -1 keeps the preset value.
@export var press_scale: float = _INHERIT

var _target: Control
var _is_button: bool = false
var _tween: Tween
var _highlighted: Control        # the Control the highlight is drawn on; null when there is none
var _fill: bool = false          # whether the highlight lights the whole body
var _hover_tween: Tween
var _press_tween: Tween
var _hover: float = 0.0
var _press: float = 0.0

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
  _target.mouse_exited.connect(_on_mouse_exited)
  _attach_highlight()
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


# The highlight is drawn on the target Control (or the node `highlight_target` names), behind its own
# content. FROM_PRESET reads the kind of control off the preset: a plain button lights its whole body,
# a card or an icon takes the border only, because its body is a picture.
func _attach_highlight() -> void:
  if highlight == Highlight.NONE:
    return
  var on: Control = _target
  if not highlight_target.is_empty():
    on = get_node_or_null(highlight_target) as Control
    if on == null:
      push_warning('UIJuice: highlight_target is not a Control. Path=%s' % str(highlight_target))
      return
  _fill = highlight == Highlight.FILL or (highlight == Highlight.FROM_PRESET and preset == Preset.BUTTON)
  _highlighted = on
  ControlFeedback.attach(on, _fill)
  if ControlFeedback.demo_amount > 0.0:
    # `--feedback-demo=` holds every control hovered for a screenshot. The text goes with it, and a
    # disabled button stays out of it, as it does under a real pointer.
    if _is_disabled():
      ControlFeedback.set_hover(on, 0.0)
    else:
      _hover = ControlFeedback.demo_amount
      _push_text_colour()


func _on_mouse_entered() -> void:
  if _is_disabled():
    return
  _hover_to(1.0)
  if play_sounds:
    _play_hover()


func _on_mouse_exited() -> void:
  _hover_to(0.0)


func _on_button_down() -> void:
  if _is_disabled():
    return
  # The press lands at once and the release springs back: a slower press reads as the control being
  # dragged rather than pushed.
  _press_to(1.0, _press_time, Tween.TRANS_QUAD, Tween.EASE_OUT)
  _squash_to(_press_scale, ControlFeedback.setting_float('press_depth'), _press_time, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _on_button_up() -> void:
  _press_to(0.0, _release_time, Tween.TRANS_QUAD, Tween.EASE_OUT)
  _squash_to(1.0, 0.0, _release_time, Tween.TRANS_BACK, Tween.EASE_OUT)


func _on_pressed() -> void:
  if play_sounds:
    _play_click()
  _bloom()


func _is_disabled() -> bool:
  return _is_button and (_target as BaseButton).disabled


# Scale and the small drop run together, so the control squashes into the page rather than shrinking
# in place. `depth` is in pixels and is scaled by the preset's squash, so a large card moves less.
func _squash_to(target_factor: float, depth: float, time: float, trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
  _kill_tween()
  _tween = _target.create_tween().set_parallel(true)
  _tween.tween_property(_target, 'offset_transform_scale', Vector2.ONE * target_factor, time).set_trans(trans).set_ease(ease_type)
  var drop: float = depth * (1.0 - _press_scale) / (1.0 - _PRESETS[Preset.BUTTON]['press_scale'])
  _tween.tween_property(_target, 'offset_transform_position', Vector2(0.0, drop), time).set_trans(trans).set_ease(ease_type)


func _hover_to(amount: float) -> void:
  if _highlighted == null:
    return
  if _hover_tween and _hover_tween.is_valid():
    _hover_tween.kill()
  _hover_tween = _highlighted.create_tween()
  _hover_tween.tween_method(_set_hover, _hover, amount, ControlFeedback.setting_float('hover_time'))


func _press_to(amount: float, time: float, trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
  if _highlighted == null:
    return
  if _press_tween and _press_tween.is_valid():
    _press_tween.kill()
  _press_tween = _highlighted.create_tween()
  _press_tween.tween_method(_set_press, _press, amount, time).set_trans(trans).set_ease(ease_type)


# One short pulse of extra ink on release, where the action actually fires.
func _bloom() -> void:
  if _highlighted == null:
    return
  var time: float = ControlFeedback.setting_float('bloom_time')
  var pulse: Tween = _highlighted.create_tween()
  var set_bloom: Callable = func(amount: float) -> void:
    if is_instance_valid(_highlighted):
      ControlFeedback.set_bloom(_highlighted, amount)
  pulse.tween_method(set_bloom, 0.0, 1.0, time * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  pulse.tween_method(set_bloom, 1.0, 0.0, time * 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _set_hover(amount: float) -> void:
  _hover = amount
  ControlFeedback.set_hover(_highlighted, amount)
  _push_text_colour()


func _set_press(amount: float) -> void:
  _press = amount
  ControlFeedback.set_press(_highlighted, amount)
  _push_text_colour()


# A button whose body lights up needs its text to darken with it, and the theme's own hover and
# pressed font colours would jump to their value the moment the state changed, ahead of the tween. So
# every state's font colour is overridden with the tweened one while the juice is alive; the disabled
# colour is left to the theme.
func _push_text_colour() -> void:
  if not _fill or not _is_button:
    return
  # The text has its own amounts, so it reaches nearly black while the body is only part way lit.
  var dark: float = maxf(
    _hover * ControlFeedback.setting_float('text_hover'),
    _press * ControlFeedback.setting_float('text_press'))
  var colour: Color = Colours.UI_TEXT_BUTTON.lerp(Colours.UI_TEXT_BUTTON_DARK, dark)
  for state: String in ['font_color', 'font_hover_color', 'font_pressed_color', 'font_hover_pressed_color']:
    _target.add_theme_color_override(state, colour)


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


func _kill_highlight_tweens() -> void:
  if _hover_tween and _hover_tween.is_valid():
    _hover_tween.kill()
  if _press_tween and _press_tween.is_valid():
    _press_tween.kill()


func _exit_tree() -> void:
  _kill_tween()
  _kill_highlight_tweens()
  _tween = null
  _hover_tween = null
  _press_tween = null
  if is_instance_valid(_highlighted):
    ControlFeedback.detach(_highlighted)
  _highlighted = null
  # Drop the parent's signal connections before releasing the ref, so the
  # still-alive parent cannot call back into this node during teardown.
  if is_instance_valid(_target):
    _target.mouse_entered.disconnect(_on_mouse_entered)
    _target.mouse_exited.disconnect(_on_mouse_exited)
    if _is_button:
      var btn: BaseButton = _target as BaseButton
      btn.button_down.disconnect(_on_button_down)
      btn.button_up.disconnect(_on_button_up)
      btn.pressed.disconnect(_on_pressed)
  _target = null
