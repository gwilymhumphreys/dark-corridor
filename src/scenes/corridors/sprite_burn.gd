class_name SpriteBurn
extends Node2D
## Burns an enemy sprite in the corridor away like paper (docs/systems/paper_burn.md, "Enemy
## sprites"): the paper burn's hole and bands drawn on the Sprite3D's image by
## `paper_burn_sprite.gdshader`, with the same sparks and ash rising from the burn front. Started by
## `Corridor3D.burn_enemy`, which adds it under the corridor node, so its particles are drawn over the
## corridor image in the corridor's own coordinates (origin at the view's centre, as `unproject`
## returns). The settings are the `paper_burn_*` print settings, read at the start. When nothing is
## left, the sprite is removed through `Corridor3D.remove_enemy`.

signal finished

const SHADER: Shader = preload('res://src/shaders/paper_burn_sprite.gdshader')

## 0 before the first mark, 1 when nothing is left.
var progress: float = 0.0

var _corridor: Corridor3D = null
var _sprite: Sprite3D = null
var _material: ShaderMaterial = ShaderMaterial.new()
var _duration: float = 1.0
var _elapsed: float = 0.0
var _done: bool = false
var _origin: Vector2 = Vector2.ZERO
var _bands: float = 0.0
var _raggedness: float = 0.0
var _particles_on: bool = true
var _particles: Array[CPUParticles2D] = []


## Set up the burn of `sprite`, one of `corridor`'s enemy sprites. Call before adding it to the tree.
func setup(corridor: Corridor3D, sprite: Sprite3D) -> void:
  _corridor = corridor
  _sprite = sprite


func _ready() -> void:
  var rng: RandomNumberGenerator = RandomNumberGenerator.new()
  rng.randomize()
  var rect: Rect2 = screen_rect()
  _origin = PaperBurn.pick_origin(rng, rect.size)
  _material.shader = SHADER
  _material.set_shader_parameter('origin', _origin)
  _material.set_shader_parameter('seed', rng.randf() * 100.0)
  _material.set_shader_parameter('image', _sprite.texture)
  _material.set_shader_parameter('alpha_scissor_threshold', _sprite.alpha_scissor_threshold)
  _bands = PaperBurn.apply_band_settings(_material)
  _raggedness = PrintLook.print_setting('paper_burn_raggedness')
  _duration = maxf(PrintLook.print_setting('paper_burn_duration'), 0.05)
  _particles_on = PrintLook.print_setting('paper_burn_particles')
  _sprite.material_override = _material
  _particles = PaperBurn.new_particles()
  for particles: CPUParticles2D in _particles:
    particles.top_level = false   # drawn in the corridor node's coordinates, placed at the sprite
    add_child(particles)
  _push_progress(rect)


func _exit_tree() -> void:
  if is_instance_valid(_sprite):
    _sprite.material_override = null
  _material.set_shader_parameter('image', null)
  _sprite = null
  _corridor = null


func _process(delta: float) -> void:
  if _done:
    return
  if not is_instance_valid(_sprite):
    queue_free()
    return
  _elapsed += delta
  progress = clampf(_elapsed / _duration, 0.0, 1.0)
  var rect: Rect2 = screen_rect()
  _push_progress(rect)
  _place_particles(rect)
  if progress >= 1.0:
    _complete()


## Jump to the end: the sprite is removed and `finished` is emitted.
func finish() -> void:
  if not _done:
    _complete()


## The sprite's image on screen, in the corridor node's coordinates.
func screen_rect() -> Rect2:
  if not is_instance_valid(_sprite) or _sprite.texture == null:
    return Rect2()
  var half: Vector3 = Vector3(_sprite.pixel_size * float(_sprite.texture.get_width()) * 0.5, Corridor3D.enemy_half_height(_sprite), 0.0)
  var top_left: Vector2 = _corridor.unproject(_sprite.position + Vector3(-half.x, half.y, 0.0))
  var bottom_right: Vector2 = _corridor.unproject(_sprite.position + Vector3(half.x, -half.y, 0.0))
  return Rect2(top_left, bottom_right - top_left).abs()


# The shader works in screen pixels of the sprite's image, so the bands are as wide as on the interface.
func _push_progress(rect: Rect2) -> void:
  _material.set_shader_parameter('progress', progress)
  _material.set_shader_parameter('rect_size', rect.size)


func _place_particles(rect: Rect2) -> void:
  if not _particles_on:
    return
  var points: PackedVector2Array = PaperBurn.front_points(_origin, rect.size, _bands, _raggedness, progress)
  for particles: CPUParticles2D in _particles:
    particles.position = rect.position
    particles.emission_points = points
    # With no point on the sprite, nothing is emitted (an empty list would emit from the node's origin).
    particles.emitting = not points.is_empty()


func _complete() -> void:
  _done = true
  progress = 1.0
  if is_instance_valid(_sprite):
    _corridor.remove_enemy(_sprite)
  for particles: CPUParticles2D in _particles:
    particles.emitting = false
  finished.emit()
  # The last sparks and ash keep flying after the sprite has gone; the node frees itself, with them,
  # once the longest of them has died.
  var lifetime: float = 0.0
  for particles: CPUParticles2D in _particles:
    lifetime = maxf(lifetime, particles.lifetime)
  get_tree().create_timer(lifetime).timeout.connect(queue_free)
