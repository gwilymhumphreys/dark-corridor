class_name CodeBuiltPieceSource
extends CorridorPieceSource
## Flat textured rectangles for the walls, floor and ceiling, created in code
## (docs/systems/corridors/corridor_3d.md). Each side's texture is stretched across one section
## `uv_repeat` times, so it tiles from section to section.

@export var tex_left: Texture2D = preload('res://assets/sprites/test_wall.png')
@export var tex_right: Texture2D = preload('res://assets/sprites/test_wall.png')
@export var tex_ceiling: Texture2D = preload('res://assets/sprites/test_wall.png')
@export var tex_floor: Texture2D = preload('res://assets/sprites/test_wall.png')
## How many times each texture repeats across one section (along the corridor, across it).
@export var uv_repeat: Vector2 = Vector2.ONE

## True shows each texture's own colours, for Corridor3D's shader light. Corridor3D sets it to false
## when light nodes light the corridor.
var unshaded: bool = true

var _materials: Dictionary = {}   # 'texture id:unshaded' -> StandardMaterial3D, shared by every section


func build_section(_index: int) -> Node3D:
  var section: Node3D = Node3D.new()
  var half_w: float = section_width * 0.5
  var half_h: float = section_height * 0.5
  var mid_z: float = -section_length * 0.5
  # A QuadMesh faces +Z. Rotating about Y turns the side walls inward; about X lays the floor
  # and ceiling flat. The quad's first size axis runs along the corridor after rotation.
  _add_quad(section, 'Left', tex_left, Vector2(section_length, section_height),
    Vector3(-half_w, 0.0, mid_z), Vector3(0.0, PI * 0.5, 0.0))
  _add_quad(section, 'Right', tex_right, Vector2(section_length, section_height),
    Vector3(half_w, 0.0, mid_z), Vector3(0.0, -PI * 0.5, 0.0))
  _add_quad(section, 'Ceiling', tex_ceiling, Vector2(section_width, section_length),
    Vector3(0.0, half_h, mid_z), Vector3(PI * 0.5, 0.0, 0.0))
  _add_quad(section, 'Floor', tex_floor, Vector2(section_width, section_length),
    Vector3(0.0, -half_h, mid_z), Vector3(-PI * 0.5, 0.0, 0.0))
  return section


func _add_quad(parent: Node3D, piece_name: String, texture: Texture2D, quad_size: Vector2,
    at: Vector3, rotation: Vector3) -> void:
  var mesh: QuadMesh = QuadMesh.new()
  mesh.size = quad_size
  var piece: MeshInstance3D = MeshInstance3D.new()
  piece.name = piece_name
  piece.mesh = mesh
  piece.material_override = _material_for(texture)
  piece.position = at
  piece.rotation = rotation
  parent.add_child(piece)


func _material_for(texture: Texture2D) -> StandardMaterial3D:
  var key: String = '%d:%s' % [texture.get_instance_id(), unshaded]
  if _materials.has(key):
    return _materials[key]
  var material: StandardMaterial3D = StandardMaterial3D.new()
  material.albedo_texture = texture
  material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
  material.texture_repeat = true
  material.uv1_scale = Vector3(uv_repeat.x, uv_repeat.y, 1.0)
  material.cull_mode = BaseMaterial3D.CULL_DISABLED   # visible from inside whatever the winding
  material.metallic_specular = 0.0
  if unshaded:
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # Corridor3D's light overlay darkens it
  _materials[key] = material
  return material
