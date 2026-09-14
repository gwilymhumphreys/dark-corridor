class_name Corridor3D
extends CorridorRenderer
## A real 3D corridor (docs/systems/corridors/corridor_3d.md). A SubViewport with its own 3D world
## holds the camera and the corridor sections; its image is drawn at `view_size`, centred on this
## node's origin (the vanishing point), like the 2D renderers.
##
## The camera stays at the origin. Each frame the sections are placed from `player_z`, so
## positions stay small however long the run is. One cell of the 2D renderers is one section
## here. Sections are created ahead up to the light's reach and removed behind.
##
## The light at the camera is drawn by `corridor_light.gdshader`, set as the material overlay on
## every piece. The pieces themselves show their full colours (unshaded, or lit by white ambient
## light), and the overlay darkens them with distance.

const LIGHT_SHADER: Shader = preload('res://src/shaders/corridor_light.gdshader')

## Where the section pieces come from. Any CorridorPieceSource can be used.
@export var piece_source: CorridorPieceSource
## The camera's vertical field of view, in degrees.
@export var fov: float = 70.0

@export_group('Light')
## The distance from the camera, in metres, where the light reaches black. Sections are built a
## little past it, so the end of the corridor is always in darkness.
@export var light_range: float = 4.0
## Brightness at the camera, 0 to 1. 1 shows the textures' own colours.
@export_range(0.0, 1.0) var light_energy: float = 1.0
## The shape of the fade to black. 1 fades evenly with distance; higher values darken sooner.
@export_range(0.1, 4.0) var light_falloff: float = 1.5
## How much darker surfaces are when they face away from the light. 0 ignores the angle.
@export_range(0.0, 1.0) var angle_shading: float = 0.5
## 0 fades smoothly. Above 0, the light level is rounded up to this many equal steps, so the
## last step ends in a hard edge to black at `light_range`.
@export_range(0, 16) var light_bands: int = 0
## Measure distance straight along the corridor instead of from the camera, so the fade and the
## band edges form square rings instead of curves on the walls.
@export var measure_along_corridor: bool = false
## How much the light dims at the bottom of a flicker, 0 to 1. 0 is a steady light.
@export_range(0.0, 1.0) var flicker_amount: float = 0.0
## How fast the flicker changes. Higher is faster.
@export var flicker_speed: float = 8.0
## An enemy image's brightness once it has arrived at depth 0. Further away it darkens in step
## with the corridor's light, reaching black at `light_range`.
@export_range(0.0, 1.0) var enemy_arrived_brightness: float = 1.0

var _sections: Dictionary = {}   # absolute section index -> Node3D
var _light_material: ShaderMaterial = ShaderMaterial.new()
var _flicker_noise: FastNoiseLite = FastNoiseLite.new()
var _flicker_time: float = 0.0

@onready var _viewport: SubViewport = $SubViewport
@onready var _camera: Camera3D = $SubViewport/Camera
@onready var _section_root: Node3D = $SubViewport/Sections
@onready var _display: Sprite2D = $Display


func _init() -> void:
  _flicker_noise.frequency = 1.0


func _exit_tree() -> void:
  _display.texture = null
  _clear_sections()


func _build() -> void:
  if piece_source == null:
    piece_source = CodeBuiltPieceSource.new()
  _viewport.size = Vector2i(maxi(int(view_size.x), 1), maxi(int(view_size.y), 1))
  _camera.fov = fov
  _camera.far = light_range + piece_source.section_length
  _light_material.shader = LIGHT_SHADER
  _apply_light()
  _display.texture = _viewport.get_texture()
  _display.centered = true
  _display.position = Vector2.ZERO
  _layout(0.0)


func _process(delta: float) -> void:
  super(delta)
  _flicker_time += delta
  _light_material.set_shader_parameter('flicker', flicker_level(_flicker_time))


## Push the light exports to the shader. Call after changing them at runtime.
func _apply_light() -> void:
  _light_material.set_shader_parameter('light_range', light_range)
  _light_material.set_shader_parameter('light_energy', light_energy)
  _light_material.set_shader_parameter('light_falloff', light_falloff)
  _light_material.set_shader_parameter('angle_shading', angle_shading)
  _light_material.set_shader_parameter('light_bands', light_bands)
  _light_material.set_shader_parameter('measure_along_corridor', measure_along_corridor)
  _light_material.set_shader_parameter('flicker', flicker_level(_flicker_time))


## The flicker's brightness multiplier at `time` seconds: between 1 - `flicker_amount` and 1.
func flicker_level(time: float) -> float:
  if flicker_amount <= 0.0:
    return 1.0
  # Simplex noise mostly stays within about -0.6..0.6, so it is stretched to reach the full dip.
  var wave: float = clampf(_flicker_noise.get_noise_1d(time * flicker_speed) * 0.8 + 0.5, 0.0, 1.0)
  return 1.0 - flicker_amount * wave


## See CorridorRenderer.enemy_brightness. The same fade, bands and flicker as the walls, scaled so
## the enemy is at `enemy_arrived_brightness` at depth 0. An on-axis image faces the camera, so
## `angle_shading` does not apply.
func enemy_brightness(depth_cells: float) -> float:
  var arrived: float = _light_curve(depth_zero_distance())
  if arrived <= 0.0:
    return 0.0
  var distance: float = depth_zero_distance() + depth_cells * piece_source.section_length
  var level: float = _light_curve(distance) / arrived * enemy_arrived_brightness
  level = clampf(level * flicker_level(_flicker_time), 0.0, 1.0)
  if light_bands > 0:
    level = ceilf(level * float(light_bands)) / float(light_bands)
  return level


# The fade with distance before energy, angle and flicker, as in corridor_light.gdshader.
func _light_curve(distance: float) -> float:
  return pow(clampf(1.0 - distance / light_range, 0.0, 1.0), light_falloff)


func _layout(_frac: float) -> void:
  var length: float = piece_source.section_length
  var base_index: int = floori(player_z)
  var first: int = base_index - _sections_behind()
  var last: int = base_index + _sections_ahead()
  for index: int in _sections.keys():
    if index < first or index > last:
      (_sections[index] as Node3D).queue_free()
      _sections.erase(index)
  for index in range(first, last + 1):
    if not _sections.has(index):
      var section: Node3D = piece_source.build_section(index)
      _set_light_overlay(section)
      _section_root.add_child(section)
      _sections[index] = section
    # Section `index` has its near edge (index - player_z) sections past depth 0.
    (_sections[index] as Node3D).position = Vector3(0.0, 0.0, -(depth_zero_distance() + (float(index) - player_z) * length))


func _set_light_overlay(node: Node) -> void:
  if node is GeometryInstance3D:
    (node as GeometryInstance3D).material_overlay = _light_material
  for child: Node in node.get_children():
    _set_light_overlay(child)


func _wall_nodes() -> Array:
  return []


## The camera's distance to depth 0: where the corridor's height exactly fills the view, the 3D
## match for the 2D renderers' near tile reaching the view edge.
func depth_zero_distance() -> float:
  var height: float = piece_source.section_height if piece_source != null else 3.0
  return (height * 0.5) / tan(deg_to_rad(fov) * 0.5)


## The camera's distance to depth 0 divided by its distance to the point `depth_cells` sections
## further. See CorridorRenderer.axis_scale.
func axis_scale(depth_cells: float) -> float:
  var length: float = piece_source.section_length if piece_source != null else 3.0
  var near: float = depth_zero_distance()
  return near / (near + depth_cells * length)


# Sections behind depth 0 still in front of the camera (plus one so the nearest is never missing).
func _sections_behind() -> int:
  return ceili(depth_zero_distance() / piece_source.section_length) + 1


func _sections_ahead() -> int:
  return ceili(light_range / piece_source.section_length) + 1


func _clear_sections() -> void:
  for section: Node3D in _sections.values():
    if is_instance_valid(section):
      section.queue_free()
  _sections.clear()
