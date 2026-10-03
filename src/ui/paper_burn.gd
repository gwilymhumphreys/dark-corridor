class_name PaperBurn
extends Node
## Burns a Control away like paper catching fire (docs/systems/paper_burn.md): a ragged hole spreads
## from a point on its edge, with a glowing ember line at the hole's edge, a black char behind the
## line, a dithered scorch ahead of it, and sparks and ash rising. The bands can be snapped to the
## combat effects' palette (`paper_burn_palette`). Start one with
## `PaperBurn.burn(target)`; the settings are the `paper_burn_*` print settings, read at the start.
##
## The target is set to clip its children (`clip_children`) and given the burn material, and a
## rectangle is drawn on it through its `draw` signal. Godot draws the children into a buffer and then
## draws that rectangle with the burn shader, which reads the children's pixels, cuts the hole and
## colours the bands on them. So everything under the target burns (a worn panel and its shadow, an
## icon, value pills), and the bands follow the children's shape. The target's own drawing is replaced
## by the rectangle during the burn. At the end the target is put back as it was, and hidden with its
## `modulate` alpha so it keeps its place in a container. A visual effect only; it has nothing to do
## with the Burn mechanic.

signal finished

const SCENE_PATH: String = 'res://src/ui/paper_burn.tscn'
const SHADER: Shader = preload('res://src/shaders/paper_burn.gdshader')
## How far outside the target the burn's rectangle reaches, in pixels, so the target's drop shadow and
## the value pills hanging off its edge are drawn, and burn with it.
const MARGIN: float = 24.0
## How many points on the burn front the sparks and ash can start from.
const FRONT_POINTS: int = 24
## The chance of the fire starting on each side: bottom, left, right, top. Fire mostly starts low.
const SIDE_WEIGHTS: Array[float] = [0.5, 0.2, 0.2, 0.1]
## The palette clamp uniforms copied from the combat effects' material when a burn starts, so the
## bands snap to the same palette as the effects, and the scorch uses the same dot pattern.
const PALETTE_UNIFORMS: Array[String] = [
  'palette_rgb', 'palette_lab', 'colour_count', 'perceptual', 'dithering', 'dither_pattern',
  'dither_size', 'dither_supersample', 'dither_noise',
]

## The Control that burns. Set by `burn`, or the parent when this is added some other way.
var target: Control = null
## Whether the target is hidden when the burn is done. The preview scene turns it off to repeat burns.
var hide_when_done: bool = true
## Whether the burn runs backwards, so the target appears out of the fire instead of burning away. Set by
## `burn`. The target is shown when it starts and stays shown at the end.
var reverse: bool = false
## 0 before the first mark, 1 when nothing is left.
var progress: float = 0.0

var _duration: float = 1.0
var _elapsed: float = 0.0
var _held: bool = false
var _done: bool = false
var _origin: Vector2 = Vector2.ZERO
var _bands: float = 0.0
var _raggedness: float = 0.0
var _particles_on: bool = true
var _material: ShaderMaterial = ShaderMaterial.new()
var _saved_material: Material = null
var _saved_clip: CanvasItem.ClipChildrenMode = CanvasItem.CLIP_CHILDREN_DISABLED

@onready var _sparks: CPUParticles2D = $Sparks
@onready var _ash: CPUParticles2D = $Ash


## Start burning `on` with the current settings. With `backwards`, `on` appears out of the fire instead.
static func burn(on: Control, backwards: bool = false) -> PaperBurn:
  var effect: PaperBurn = (load(SCENE_PATH) as PackedScene).instantiate()
  effect.target = on
  effect.reverse = backwards
  if backwards:
    effect.progress = 1.0
    on.modulate.a = 1.0
  on.add_child(effect)
  return effect


func _ready() -> void:
  if target == null:
    target = get_parent() as Control
  var rng: RandomNumberGenerator = RandomNumberGenerator.new()
  rng.randomize()
  _origin = pick_origin(rng, target.size)
  _material.shader = SHADER
  _material.set_shader_parameter('origin', _origin)
  _material.set_shader_parameter('seed', rng.randf() * 100.0)
  _read_settings()
  _saved_material = target.material
  _saved_clip = target.clip_children
  target.material = _material
  target.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
  target.draw.connect(_draw_on_target)
  target.queue_redraw()
  _sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
  _ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
  _push_progress()


func _exit_tree() -> void:
  if not _done:
    _restore_target()
  target = null


## Stop at `at` (0 to 1) and stay there, for the preview scene's strip of frames.
func hold(at: float) -> void:
  _held = true
  progress = clampf(at, 0.0, 1.0)
  _particles_on = false
  _sparks.emitting = false
  _ash.emitting = false
  _push_progress()


## Jump to the end: the target is hidden (with `hide_when_done`) and `finished` is emitted.
func finish() -> void:
  if not _done:
    _complete()


func _process(delta: float) -> void:
  if _done or _held:
    return
  _elapsed += delta
  var done: float = clampf(_elapsed / _duration, 0.0, 1.0)
  progress = 1.0 - done if reverse else done
  _push_progress()
  _place_particles()
  if done >= 1.0:
    _complete()


# The rectangle the burn shader draws the children through: the target grown by MARGIN.
func _draw_on_target() -> void:
  target.draw_rect(Rect2(-Vector2.ONE * MARGIN, target.size + Vector2.ONE * MARGIN * 2.0), Color.WHITE)


func _read_settings() -> void:
  _duration = maxf(PrintLook.print_setting('paper_burn_duration'), 0.05)
  _raggedness = PrintLook.print_setting('paper_burn_raggedness')
  var brightness: float = PrintLook.print_setting('paper_burn_brightness')
  _bands = apply_band_settings(_material)
  _material.set_shader_parameter('dither', PrintLook.print_setting('paper_burn_dither'))
  for uniform: String in PALETTE_UNIFORMS:
    _material.set_shader_parameter(uniform, InterfaceLook.effects_material.get_shader_parameter(uniform))
  _material.set_shader_parameter('snap', PrintLook.print_setting('paper_burn_palette'))
  _particles_on = PrintLook.print_setting('paper_burn_particles')
  _colour_particles(_sparks, _ash)
  # The ember line and the sparks are brighter than white, and the screen glow is only on while
  # something asks for it. The sparks ask, which also makes them that bright.
  InterfaceGlow.set_glow(_sparks, maxf(brightness, 1.0))


func _push_progress() -> void:
  _material.set_shader_parameter('progress', progress)
  _material.set_shader_parameter('rect_size', target.size)


## A point on the edge of a `rect_size` rectangle, on a side picked by SIDE_WEIGHTS, away from the
## corners. Also used by the enemy sprite burn (`SpriteBurn`).
static func pick_origin(rng: RandomNumberGenerator, rect_size: Vector2) -> Vector2:
  var along: float = rng.randf_range(0.15, 0.85)
  var roll: float = rng.randf()
  var side: int = 0
  while side < SIDE_WEIGHTS.size() - 1 and roll > SIDE_WEIGHTS[side]:
    roll -= SIDE_WEIGHTS[side]
    side += 1
  match side:
    0:
      return Vector2(along * rect_size.x, rect_size.y)
    1:
      return Vector2(0.0, along * rect_size.y)
    2:
      return Vector2(rect_size.x, along * rect_size.y)
  return Vector2(along * rect_size.x, 0.0)


# The sparks and ash start from the burn front.
func _place_particles() -> void:
  if not _particles_on:
    return
  var points: PackedVector2Array = front_points(_origin, target.size, _bands, _raggedness, progress)
  for particles: CPUParticles2D in [_sparks, _ash]:
    particles.global_transform = target.get_global_transform()
    particles.emission_points = points
    # With no point on the target, nothing is emitted (an empty list would emit from the node's origin).
    particles.emitting = not points.is_empty()


## Points on the burn front of a `rect_size` rectangle burning from `origin`, where the sparks and
## ash start: the circle around the origin at the front's distance (the shader's `front`, without the
## noise), where it crosses the rectangle. `bands` is the three band widths added up.
static func front_points(origin: Vector2, rect_size: Vector2, bands: float, raggedness: float, at: float) -> PackedVector2Array:
  # The farthest corner from the origin, as in the shader.
  var reach: float = Vector2(maxf(origin.x, rect_size.x - origin.x), maxf(origin.y, rect_size.y - origin.y)).length()
  var radius: float = lerpf(-bands - raggedness, reach + raggedness, at)
  var points: PackedVector2Array = PackedVector2Array()
  if radius > 0.0:
    var bounds: Rect2 = Rect2(Vector2.ZERO, rect_size)
    for i in FRONT_POINTS:
      var angle: float = TAU * (float(i) + 0.5) / float(FRONT_POINTS)
      var point: Vector2 = origin + Vector2.from_angle(angle) * radius
      if bounds.has_point(point):
        points.append(point)
  return points


## Set the burn shader's band and noise uniforms on `material` from the `paper_burn_*` print
## settings, and return the three band widths added up.
static func apply_band_settings(material: ShaderMaterial) -> float:
  var ember_width: float = PrintLook.print_setting('paper_burn_ember_width')
  var char_width: float = PrintLook.print_setting('paper_burn_char_width')
  var scorch_width: float = PrintLook.print_setting('paper_burn_scorch_width')
  material.set_shader_parameter('raggedness', PrintLook.print_setting('paper_burn_raggedness'))
  material.set_shader_parameter('detail', PrintLook.print_setting('paper_burn_detail'))
  material.set_shader_parameter('ember_width', ember_width)
  material.set_shader_parameter('char_width', char_width)
  material.set_shader_parameter('scorch_width', scorch_width)
  material.set_shader_parameter('brightness', PrintLook.print_setting('paper_burn_brightness'))
  material.set_shader_parameter('ember_colour', Colours.PAPER_BURN_EMBER)
  material.set_shader_parameter('char_colour', Colours.PAPER_BURN_CHAR)
  material.set_shader_parameter('scorch_colour', Colours.PAPER_BURN_SCORCH)
  return ember_width + char_width + scorch_width


## A new pair of the burn's particle emitters, [sparks, ash], set up as in this scene and coloured,
## for an effect that burns something other than a Control (`SpriteBurn`). They are not in the tree.
static func new_particles() -> Array[CPUParticles2D]:
  var scene: Node = (load(SCENE_PATH) as PackedScene).instantiate()
  var sparks: CPUParticles2D = scene.get_node('Sparks')
  var ash: CPUParticles2D = scene.get_node('Ash')
  scene.remove_child(sparks)
  scene.remove_child(ash)
  scene.free()
  _colour_particles(sparks, ash)
  for particles: CPUParticles2D in [sparks, ash]:
    particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
  return [sparks, ash]


static func _colour_particles(sparks: CPUParticles2D, ash: CPUParticles2D) -> void:
  sparks.color = Colours.PAPER_BURN_EMBER
  # Grey flakes, light enough to show against the dark sheet.
  ash.color = Colours.PAPER_BURN_CHAR.lerp(Colours.UI_TEXT_DIM, 0.5)


func _complete() -> void:
  _done = true
  progress = 0.0 if reverse else 1.0
  _push_progress()
  _restore_target()
  if hide_when_done and not reverse:
    target.modulate.a = 0.0
  # The last sparks and ash keep flying after the target has gone: they move to its parent, which the
  # target's modulate does not reach, and free themselves when the last one has died.
  var parent: Node = target.get_parent()
  for particles: CPUParticles2D in [_sparks, _ash]:
    particles.emitting = false
    if parent != null:
      particles.reparent(parent)
      get_tree().create_timer(particles.lifetime).timeout.connect(particles.queue_free)
  finished.emit()
  queue_free()


func _restore_target() -> void:
  if not is_instance_valid(target):
    return
  if target.draw.is_connected(_draw_on_target):
    target.draw.disconnect(_draw_on_target)
  target.material = _saved_material
  target.clip_children = _saved_clip
  target.queue_redraw()
