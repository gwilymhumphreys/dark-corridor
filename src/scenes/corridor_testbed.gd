extends Node2D
## Window host: instances the active corridor renderer into CorridorHolder, wires
## the UI (Forward/Back buttons, blur slider, mode switch) to it, and toggles
## between the scale-and-place (default) and perspective scenes. Both renderers
## share the CorridorRenderer interface, so the UI wiring is identical for either.

const CORRIDOR_SCENES: Array[PackedScene] = [
  preload('res://src/scenes/corridors/corridor_scaled.tscn'),
  preload('res://src/scenes/corridors/corridor_perspective.tscn'),
]
const MODE_NAMES: Array[String] = ['Scale-and-place', 'Perspective-quad']

var _mode: int = 0
var _corridor: CorridorRenderer


func _ready() -> void:
  var fwd: Button = $UILayer/ButtonRow/ForwardButton
  var back: Button = $UILayer/ButtonRow/BackButton
  fwd.button_down.connect(func() -> void: _set_forward(true))
  fwd.button_up.connect(func() -> void: _set_forward(false))
  back.button_down.connect(func() -> void: _set_back(true))
  back.button_up.connect(func() -> void: _set_back(false))

  $UILayer/SwitchButton.pressed.connect(_toggle_mode)
  $UILayer/BlurSlider.value_changed.connect(func(v: float) -> void: _set_blur(v))

  # Default to scale-and-place; `--perspective` starts on the toggle (dev/testing).
  var start_mode: int = 1 if '--perspective' in OS.get_cmdline_args() else 0
  _load_corridor(start_mode)

  # Verification helper: `--shot` captures a mid-glide frame then quits.
  if '--shot' in OS.get_cmdline_args() or '--shot' in OS.get_cmdline_user_args():
    _auto_shot()


func _load_corridor(mode: int) -> void:
  if _corridor:
    _corridor.queue_free()
  _mode = mode
  _corridor = CORRIDOR_SCENES[mode].instantiate() as CorridorRenderer
  _apply_view_override(_corridor)   # before add_child so _build reads it
  $CorridorHolder.add_child(_corridor)
  _corridor.set_blur($UILayer/BlurSlider.value)
  $UILayer/SwitchButton.text = 'Mode: %s  (M ⇄)' % MODE_NAMES[mode]


## Dev hook: `--view=WIDTHxHEIGHT` forces a fixed view_size (try aspects).
func _apply_view_override(c: CorridorRenderer) -> void:
  for arg in OS.get_cmdline_args():
    if arg.begins_with('--view='):
      var parts: PackedStringArray = arg.substr(7).split('x')
      if parts.size() == 2:
        c.auto_view_size = false
        c.view_size = Vector2(float(parts[0]), float(parts[1]))
        c.position = c.view_size * 0.5


func _toggle_mode() -> void:
  _load_corridor((_mode + 1) % CORRIDOR_SCENES.size())


func _unhandled_key_input(event: InputEvent) -> void:
  if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
    _toggle_mode()


func _set_forward(v: bool) -> void:
  if _corridor:
    _corridor.set_forward_held(v)


func _set_back(v: bool) -> void:
  if _corridor:
    _corridor.set_back_held(v)


func _set_blur(v: float) -> void:
  if _corridor:
    _corridor.set_blur(v)


func _auto_shot() -> void:
  # `--still` captures a stopped frame (no motion) to check the resting filter.
  if not ('--still' in OS.get_cmdline_args() or '--still' in OS.get_cmdline_user_args()):
    _set_forward(true)  # engage motion so the filter shows
  await get_tree().create_timer(0.6).timeout
  await RenderingServer.frame_post_draw
  var img: Image = get_viewport().get_texture().get_image()
  var path: String = 'user://shot.png'
  img.save_png(path)
  print('SHOT_SAVED:', ProjectSettings.globalize_path(path))
  get_tree().quit()
