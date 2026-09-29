class_name PaperBurn
extends Node
## Burns a Control away like paper catching fire (docs/systems/paper_burn.md): a ragged hole spreads
## from a point on its edge, with a glowing ember line at the hole's edge, a black char behind the
## line, a dithered scorch ahead of it, and sparks and ash rising. Start one with
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

## The Control that burns. Set by `burn`, or the parent when this is added some other way.
var target: Control = null
## Whether the target is hidden when the burn is done. The preview scene turns it off to repeat burns.
var hide_when_done: bool = true
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


## Start burning `on` with the current settings.
static func burn(on: Control) -> PaperBurn:
  var effect: PaperBurn = (load(SCENE_PATH) as PackedScene).instantiate()
  effect.target = on
  on.add_child(effect)
  return effect


func _ready() -> void:
  if target == null:
    target = get_parent() as Control
  var rng: RandomNumberGenerator = RandomNumberGenerator.new()
  rng.randomize()
  _origin = _pick_origin(rng, target.size)
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
  progress = clampf(_elapsed / _duration, 0.0, 1.0)
  _push_progress()
  _place_particles()
  if progress >= 1.0:
    _complete()


# The rectangle the burn shader draws the children through: the target grown by MARGIN.
func _draw_on_target() -> void:
  target.draw_rect(Rect2(-Vector2.ONE * MARGIN, target.size + Vector2.ONE * MARGIN * 2.0), Color.WHITE)


func _read_settings() -> void:
  _duration = maxf(PrintLook.print_setting('paper_burn_duration'), 0.05)
  _raggedness = PrintLook.print_setting('paper_burn_raggedness')
  var ember_width: float = PrintLook.print_setting('paper_burn_ember_width')
  var char_width: float = PrintLook.print_setting('paper_burn_char_width')
  var scorch_width: float = PrintLook.print_setting('paper_burn_scorch_width')
  var brightness: float = PrintLook.print_setting('paper_burn_brightness')
  _bands = ember_width + char_width + scorch_width
  _material.set_shader_parameter('raggedness', _raggedness)
  _material.set_shader_parameter('detail', PrintLook.print_setting('paper_burn_detail'))
  _material.set_shader_parameter('ember_width', ember_width)
  _material.set_shader_parameter('char_width', char_width)
  _material.set_shader_parameter('scorch_width', scorch_width)
  _material.set_shader_parameter('brightness', brightness)
  _material.set_shader_parameter('dither', PrintLook.print_setting('paper_burn_dither'))
  _material.set_shader_parameter('ember_colour', Colours.PAPER_BURN_EMBER)
  _material.set_shader_parameter('char_colour', Colours.PAPER_BURN_CHAR)
  _material.set_shader_parameter('scorch_colour', Colours.PAPER_BURN_SCORCH)
  _particles_on = PrintLook.print_setting('paper_burn_particles')
  _sparks.color = Colours.PAPER_BURN_EMBER
  # Grey flakes, light enough to show against the dark sheet.
  _ash.color = Colours.PAPER_BURN_CHAR.lerp(Colours.UI_TEXT_DIM, 0.5)
  # The ember line and the sparks are brighter than white, and the screen glow is only on while
  # something asks for it. The sparks ask, which also makes them that bright.
  InterfaceGlow.set_glow(_sparks, maxf(brightness, 1.0))


func _push_progress() -> void:
  _material.set_shader_parameter('progress', progress)
  _material.set_shader_parameter('rect_size', target.size)


# A point on the target's edge, on a side picked by SIDE_WEIGHTS, away from the corners.
static func _pick_origin(rng: RandomNumberGenerator, rect_size: Vector2) -> Vector2:
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


# The sparks and ash start from the burn front: the circle around the origin at the front's distance
# (the shader's `front`, without the noise), where it crosses the target.
func _place_particles() -> void:
  if not _particles_on:
    return
  # The farthest corner from the origin, as in the shader.
  var reach: float = Vector2(maxf(_origin.x, target.size.x - _origin.x), maxf(_origin.y, target.size.y - _origin.y)).length()
  var radius: float = lerpf(-_bands - _raggedness, reach + _raggedness, progress)
  var points: PackedVector2Array = PackedVector2Array()
  if radius > 0.0:
    var bounds: Rect2 = Rect2(Vector2.ZERO, target.size)
    for i in FRONT_POINTS:
      var angle: float = TAU * (float(i) + 0.5) / float(FRONT_POINTS)
      var point: Vector2 = _origin + Vector2.from_angle(angle) * radius
      if bounds.has_point(point):
        points.append(point)
  for particles: CPUParticles2D in [_sparks, _ash]:
    particles.global_transform = target.get_global_transform()
    particles.emission_points = points
    # With no point on the target, nothing is emitted (an empty list would emit from the node's origin).
    particles.emitting = not points.is_empty()


func _complete() -> void:
  _done = true
  progress = 1.0
  _push_progress()
  _restore_target()
  if hide_when_done:
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
