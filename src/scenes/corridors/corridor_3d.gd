class_name Corridor3D
extends CorridorRenderer
## A real 3D corridor (docs/systems/corridors/corridor_3d.md). A SubViewport with its own 3D world
## holds the camera, a light at the camera and the corridor sections; its image is drawn at
## `view_size`, centred on this node's origin (the vanishing point), like the 2D renderers.
##
## The camera and light stay at the origin. Each frame the sections are placed from `player_z`,
## so positions stay small however long the run is. One cell of the 2D renderers is one section
## here. Sections are created ahead up to the light's reach and removed behind.

## Where the section pieces come from. Any CorridorPieceSource can be used.
@export var piece_source: CorridorPieceSource
## The camera's vertical field of view, in degrees.
@export var fov: float = 70.0
## How far the light reaches, in metres. Nothing is built beyond it.
@export var light_range: float = 24.0
@export var light_energy: float = 1.5
## The light's falloff curve (OmniLight3D.omni_attenuation).
@export var light_attenuation: float = 1.0

var _sections: Dictionary = {}   # absolute section index -> Node3D

@onready var _viewport: SubViewport = $SubViewport
@onready var _camera: Camera3D = $SubViewport/Camera
@onready var _light: OmniLight3D = $SubViewport/Light
@onready var _section_root: Node3D = $SubViewport/Sections
@onready var _display: Sprite2D = $Display


func _exit_tree() -> void:
  _display.texture = null
  _clear_sections()


func _build() -> void:
  if piece_source == null:
    piece_source = CodeBuiltPieceSource.new()
  _viewport.size = Vector2i(maxi(int(view_size.x), 1), maxi(int(view_size.y), 1))
  _camera.fov = fov
  _camera.far = light_range + piece_source.section_length
  _light.omni_range = light_range
  _light.light_energy = light_energy
  _light.omni_attenuation = light_attenuation
  _display.texture = _viewport.get_texture()
  _display.centered = true
  _display.position = Vector2.ZERO
  _layout(0.0)


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
      _section_root.add_child(section)
      _sections[index] = section
    # Section `index` has its near edge (index - player_z) sections past depth 0.
    (_sections[index] as Node3D).position = Vector3(0.0, 0.0, -(depth_zero_distance() + (float(index) - player_z) * length))


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
