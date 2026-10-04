class_name CodeBuiltPieceSource
extends CorridorPieceSource
## Flat textured rectangles for the walls, floor and ceiling, created in code
## (docs/systems/corridors/corridor_3d.md). Each side's texture is stretched across one section
## `uv_repeat` times, so it tiles from section to section. The floor and ceiling repeat more across a
## corridor wider than it is tall, so their texture is the same size in metres as the walls'.

@export var tex_left: Texture2D = preload('res://assets/textures/castle_wall_slates.png')
@export var tex_right: Texture2D = preload('res://assets/textures/castle_wall_slates.png')
@export var tex_ceiling: Texture2D = preload('res://assets/textures/castle_wall_slates.png')
@export var tex_floor: Texture2D = preload('res://assets/textures/castle_wall_slates.png')
## How many times each texture repeats across one section (along the corridor, across it).
@export var uv_repeat: Vector2 = Vector2.ONE

var _materials: Dictionary = {}   # [texture id, repeat] -> StandardMaterial3D, shared by every section


func build_section(_index: int) -> Node3D:
  var section: Node3D = Node3D.new()
  var half_w: float = section_width * 0.5
  var half_h: float = section_height * 0.5
  var mid_z: float = -section_length * 0.5
  # A QuadMesh faces +Z. Rotating about Y turns the side walls inward; about X lays the floor
  # and ceiling flat. On the walls the quad's first size axis runs along the corridor; on the floor
  # and ceiling it runs across, so their first repeat follows the width.
  var flat_repeat: Vector2 = Vector2(uv_repeat.y * section_width / maxf(section_height, 0.001), uv_repeat.x)
  _add_quad(section, 'Left', tex_left, Vector2(section_length, section_height), uv_repeat,
    Vector3(-half_w, 0.0, mid_z), Vector3(0.0, PI * 0.5, 0.0))
  _add_quad(section, 'Right', tex_right, Vector2(section_length, section_height), uv_repeat,
    Vector3(half_w, 0.0, mid_z), Vector3(0.0, -PI * 0.5, 0.0))
  _add_quad(section, 'Ceiling', tex_ceiling, Vector2(section_width, section_length), flat_repeat,
    Vector3(0.0, half_h, mid_z), Vector3(PI * 0.5, 0.0, 0.0))
  _add_quad(section, 'Floor', tex_floor, Vector2(section_width, section_length), flat_repeat,
    Vector3(0.0, -half_h, mid_z), Vector3(-PI * 0.5, 0.0, 0.0))
  return section


func _add_quad(parent: Node3D, piece_name: String, texture: Texture2D, quad_size: Vector2,
    repeat: Vector2, at: Vector3, rotation: Vector3) -> void:
  var mesh: QuadMesh = QuadMesh.new()
  mesh.size = quad_size
  var piece: MeshInstance3D = MeshInstance3D.new()
  piece.name = piece_name
  piece.mesh = mesh
  piece.material_override = _material_for(texture, repeat)
  piece.position = at
  piece.rotation = rotation
  parent.add_child(piece)


func _material_for(texture: Texture2D, repeat: Vector2) -> StandardMaterial3D:
  var key: Array = [texture.get_instance_id(), repeat]
  if _materials.has(key):
    return _materials[key]
  var material: StandardMaterial3D = StandardMaterial3D.new()
  material.albedo_texture = texture
  material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  material.texture_repeat = true
  material.uv1_scale = Vector3(repeat.x, repeat.y, 1.0)
  material.cull_mode = BaseMaterial3D.CULL_DISABLED   # visible from inside whatever the winding
  material.metallic_specular = 0.0
  _materials[key] = material
  return material
