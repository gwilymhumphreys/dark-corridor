extends Node2D
## Window host for the corridor (docs/systems/corridors/corridor_3d.md): instances `Corridor3D`
## into CorridorHolder and wires the Forward/Back buttons to it. N places a random monster at the
## approach start and walks the corridor up to it, as a fight does.

const CORRIDOR_SCENE: PackedScene = preload('res://src/scenes/corridors/corridor_3d.tscn')

var _corridor: Corridor3D
var _monster: Sprite3D = null
var _monster_elapsed: float = 0.0
var _monster_walking: bool = false
var _walk_start_z: float = 0.0


func _ready() -> void:
  var forward: Button = $UILayer/ButtonRow/ForwardButton
  var back: Button = $UILayer/ButtonRow/BackButton
  forward.button_down.connect(func() -> void: _corridor.set_forward_held(true))
  forward.button_up.connect(func() -> void: _corridor.set_forward_held(false))
  back.button_down.connect(func() -> void: _corridor.set_back_held(true))
  back.button_up.connect(func() -> void: _corridor.set_back_held(false))

  _corridor = CORRIDOR_SCENE.instantiate() as Corridor3D
  _apply_overrides(_corridor)   # before add_child so the corridor builds with them
  $CorridorHolder.add_child(_corridor)
  # The debug look panel's settings and shader, as in fights.
  _corridor.apply_settings(DebugPanels.corridor_settings, DebugPanels.environment_settings)
  (_corridor.get_node('Display') as Sprite2D).material = DebugPanels.world_material

  # Verification helper: `--shot` captures a mid-glide frame then quits.
  if '--shot' in OS.get_cmdline_args() or '--shot' in OS.get_cmdline_user_args():
    _auto_shot()


func _exit_tree() -> void:
  if _monster != null and is_instance_valid(_monster):
    _monster.texture = null
  _monster = null


## Dev hooks: `--view=WIDTHxHEIGHT` forces a fixed view_size (try aspects), and
## `-- --set=property=value` sets any corridor export, e.g. `--set=light_energy=0.2`.
func _apply_overrides(corridor: Corridor3D) -> void:
  for arg in OS.get_cmdline_args():
    if arg.begins_with('--view='):
      var parts: PackedStringArray = arg.substr(7).split('x')
      if parts.size() == 2:
        corridor.auto_view_size = false
        corridor.view_size = Vector2(float(parts[0]), float(parts[1]))
        corridor.position = corridor.view_size * 0.5
  for arg in OS.get_cmdline_user_args():
    if arg.begins_with('--set='):
      var pair: PackedStringArray = arg.substr(6).split('=')
      if pair.size() == 2 and pair[0] in corridor:
        corridor.set(pair[0], str_to_var(pair[1]))


func _unhandled_key_input(event: InputEvent) -> void:
  if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
    _spawn_monster()


## Place a random monster at the approach start; _process walks the corridor up to it.
func _spawn_monster() -> void:
  if _monster != null:
    _corridor.remove_enemy(_monster)
    _monster = null
  var texture: Texture2D = MonsterImages.random_texture()
  if texture == null:
    return
  _monster = _corridor.add_enemy(texture)
  _corridor.size_enemy(_monster, Balance.ENEMY_PAINTED_HEIGHT)
  _monster_elapsed = 0.0
  _monster_walking = true
  _walk_start_z = _corridor.player_z
  _monster.position = _corridor.enemy_position(Balance.APPROACH_DEPTH_START, 0.0)


# The monster stands still and the corridor moves up to it, as the run screen's approach does: the
# player's position is driven straight from the elapsed time, so the Forward/Back buttons are
# overridden until the walk finishes.
func _process(delta: float) -> void:
  if not _monster_walking or _monster == null or not is_instance_valid(_monster):
    return
  _monster_elapsed += delta
  var t: float = clampf(_monster_elapsed / Balance.APPROACH_DURATION, 0.0, 1.0)
  var travelled: float = Balance.APPROACH_DEPTH_START * smoothstep(0.0, 1.0, t)
  _corridor.player_z = _walk_start_z + travelled
  _monster.position = _corridor.enemy_position(Balance.APPROACH_DEPTH_START - travelled, 0.0)
  if t >= 1.0:
    _monster_walking = false


func _auto_shot() -> void:
  # `--still` captures a stopped frame (no motion).
  if not ('--still' in OS.get_cmdline_args() or '--still' in OS.get_cmdline_user_args()):
    _corridor.set_forward_held(true)
  if '--monster' in OS.get_cmdline_user_args():
    _spawn_monster()
  # `--shot-delay=SECONDS` waits longer, e.g. for the monster to finish walking in.
  var delay: float = 0.6
  for arg in OS.get_cmdline_user_args():
    if arg.begins_with('--shot-delay='):
      delay = float(arg.substr(13))
  await get_tree().create_timer(delay).timeout
  await RenderingServer.frame_post_draw
  var img: Image = get_viewport().get_texture().get_image()
  var path: String = 'user://shot.png'
  img.save_png(path)
  print('SHOT_SAVED:', ProjectSettings.globalize_path(path))
  get_tree().quit()
