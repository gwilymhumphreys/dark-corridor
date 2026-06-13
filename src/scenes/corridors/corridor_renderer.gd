class_name CorridorRenderer
extends Node2D
## Base for corridor renderers. Owns everything that is the same regardless of
## how the walls are drawn: input, the velocity ramp, the blur/filter model, the
## shared sharp-bilinear material, and the held/blur interface that `corridor_testbed.gd`
## drives. Subclasses implement only the geometry, via `_build()` and
## `_layout(frac)` (and `_wall_nodes()` so the base can toggle their filter).
##
## See docs/systems/corridors/common.md.

const SHARP_SHADER: Shader = preload('res://src/shaders/sharp_bilinear.gdshader')

## When true (default), `view_size` is set automatically to the size of the
## viewport this renderer is in (the main viewport, or a SubViewport sized by its
## container), and re-synced on resize. So you size the container and the corridor
## fills it — no manual numbers. Turn off to drive `view_size` yourself.
## Requires the renderer's parent to sit at the viewport origin (0,0).
@export var auto_view_size: bool = true

## The on-screen rectangle the corridor fills, in LOCAL px (node origin = its
## centre = the vanishing point). Aspect ratio is just view_size.x : view_size.y.
## All geometry derives from this, so it's independent of the node's `scale`.
## Used directly when `auto_view_size` is off; otherwise set from the viewport.
@export var view_size: Vector2 = Vector2(1280.0, 1280.0)

@export var speed: float = 1.2          ## cells per second at full glide
@export var ramp_time: float = 0.3      ## seconds to ease speed in/out (filter rides the same ramp)

## Whether the renderer polls the move_forward / move_back actions itself — a testbed
## affordance. Hosts that DRIVE the corridor (the combat view's backdrop) turn this off,
## or W/S would scroll the fight's corridor at any time.
@export var input_enabled: bool = true

var player_z: float = 0.0               ## continuous forward position, in cells
var velocity: float = 0.0               ## eased cells/sec; ramps over ramp_time
var blur_amount: float = 0.0            ## filter strength WHILE MOVING (0 = off even moving; never on at rest)
var aa_strength: float = 0.0
var forward_held: bool = false
var back_held: bool = false

var _mat: ShaderMaterial
var _filter_linear: bool = false        ## matches the NEAREST filter subclasses spawn with


func _ready() -> void:
  _mat = ShaderMaterial.new()
  _mat.shader = SHARP_SHADER
  if auto_view_size:
    _sync_view_size()
    get_viewport().size_changed.connect(_on_viewport_resized)
  _build()


## Fill (and centre in) the current viewport. Parent must be at the origin.
func _sync_view_size() -> void:
  var vp: Vector2 = get_viewport_rect().size
  view_size = vp
  position = vp * 0.5


func _on_viewport_resized() -> void:
  _sync_view_size()
  rebuild()


## Re-run the geometry (after a view_size change). _build() clears + respawns.
func rebuild() -> void:
  _filter_linear = false
  _build()


func _process(delta: float) -> void:
  var dir: float = 0.0
  if forward_held or (input_enabled and Input.is_action_pressed('move_forward')):
    dir += 1.0
  if back_held or (input_enabled and Input.is_action_pressed('move_back')):
    dir -= 1.0

  # Ease velocity toward the target over ramp_time (no snap on start/stop).
  var accel: float = speed / maxf(ramp_time, 0.001)
  velocity = move_toward(velocity, dir * speed, accel * delta)
  player_z += velocity * delta

  # Filter on only while moving, scaled by blur; never at rest, off at blur 0.
  aa_strength = blur_amount * (absf(velocity) / speed)
  _mat.set_shader_parameter('aa_strength', aa_strength)
  _apply_filter(aa_strength > 0.01)

  _layout(fposmod(player_z, 1.0))


## Toggle every wall node between crisp NEAREST (at rest) and LINEAR (so the
## sharp-bilinear shader can work while moving). Only touches nodes on a change.
func _apply_filter(linear: bool) -> void:
  if linear == _filter_linear:
    return
  _filter_linear = linear
  var f: int = CanvasItem.TEXTURE_FILTER_LINEAR if linear else CanvasItem.TEXTURE_FILTER_NEAREST
  for node in _wall_nodes():
    node.texture_filter = f


# --- Virtuals (subclasses override) ------------------------------------------

## Spawn the renderer's nodes. Assign each `_mat` and start at NEAREST filter.
func _build() -> void:
  pass


## Position/scale the nodes for the sub-cell offset `frac` (0..1).
func _layout(_frac: float) -> void:
  pass


## Every CanvasItem whose `texture_filter` the base should toggle.
func _wall_nodes() -> Array:
  return []


# --- Shared interface (driven by corridor_testbed.gd) ------------------------

func set_forward_held(v: bool) -> void:
  forward_held = v


func set_back_held(v: bool) -> void:
  back_held = v


func set_blur(v: float) -> void:
  blur_amount = clampf(v, 0.0, 1.0)
