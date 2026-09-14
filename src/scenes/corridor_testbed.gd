extends Node2D
## Window host: instances the active corridor renderer into CorridorHolder, wires
## the UI (Forward/Back buttons, blur slider, mode switch) to it, and cycles
## between the scale-and-place (default), perspective and 3D scenes. All renderers
## share the CorridorRenderer interface, so the UI wiring is identical for each.
## N walks a random painted sample monster from the approach start to depth 0.

const CORRIDOR_SCENES: Array[PackedScene] = [
  preload('res://src/scenes/corridors/corridor_scaled.tscn'),
  preload('res://src/scenes/corridors/corridor_perspective.tscn'),
  preload('res://src/scenes/corridors/corridor_3d.tscn'),
]
const MODE_NAMES: Array[String] = ['Scale-and-place', 'Perspective-quad', '3D']

var _mode: int = 0
var _corridor: CorridorRenderer
var _monster: Sprite2D = null
var _monster_elapsed: float = 0.0


func _ready() -> void:
  var fwd: Button = $UILayer/ButtonRow/ForwardButton
  var back: Button = $UILayer/ButtonRow/BackButton
  fwd.button_down.connect(func() -> void: _set_forward(true))
  fwd.button_up.connect(func() -> void: _set_forward(false))
  back.button_down.connect(func() -> void: _set_back(true))
  back.button_up.connect(func() -> void: _set_back(false))

  $UILayer/SwitchButton.pressed.connect(_toggle_mode)
  $UILayer/BlurSlider.value_changed.connect(func(v: float) -> void: _set_blur(v))

  # Default to scale-and-place; `--perspective` / `--3d` start on another renderer (dev/testing).
  var start_mode: int = 0
  if '--perspective' in OS.get_cmdline_args():
    start_mode = 1
  elif '--3d' in OS.get_cmdline_args() or '--3d' in OS.get_cmdline_user_args():
    start_mode = 2
  _load_corridor(start_mode)

  # Verification helper: `--shot` captures a mid-glide frame then quits.
  if '--shot' in OS.get_cmdline_args() or '--shot' in OS.get_cmdline_user_args():
    _auto_shot()


func _exit_tree() -> void:
  if _monster != null and is_instance_valid(_monster):
    _monster.texture = null
  _monster = null


func _load_corridor(mode: int) -> void:
  if _corridor:
    _corridor.queue_free()
  _monster = null   # freed with the old corridor
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
  if not (event is InputEventKey and event.pressed and not event.echo):
    return
  if event.keycode == KEY_M:
    _toggle_mode()
  elif event.keycode == KEY_N:
    _spawn_monster()


## Place a random sample monster at the approach start; _process walks it to depth 0 using the
## renderer's axis_scale, to check it grows with the walls and stops at full size.
func _spawn_monster() -> void:
  if _monster != null and is_instance_valid(_monster):
    _monster.texture = null
    _monster.queue_free()
  var texture: Texture2D = MonsterImages.random_texture()
  if texture == null:
    return
  _monster = Sprite2D.new()
  _monster.texture = texture
  _monster.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  _monster.z_index = 100
  _corridor.add_child(_monster)
  _monster_elapsed = 0.0
  _place_monster(Balance.APPROACH_DEPTH_START)


func _process(delta: float) -> void:
  if _monster == null or not is_instance_valid(_monster):
    return
  _monster_elapsed += delta
  var t: float = clampf(_monster_elapsed / Balance.APPROACH_DURATION, 0.0, 1.0)
  _place_monster(lerpf(Balance.APPROACH_DEPTH_START, 0.0, t))


func _place_monster(depth_cells: float) -> void:
  var full: float = Balance.ENEMY_PAINTED_HEIGHT / float(_monster.texture.get_height())
  var s: float = full * _corridor.axis_scale(depth_cells)
  _monster.scale = Vector2(s, s)


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
  if '--monster' in OS.get_cmdline_user_args():
    _spawn_monster()
  await get_tree().create_timer(0.6).timeout
  await RenderingServer.frame_post_draw
  var img: Image = get_viewport().get_texture().get_image()
  var path: String = 'user://shot.png'
  img.save_png(path)
  print('SHOT_SAVED:', ProjectSettings.globalize_path(path))
  get_tree().quit()
