class_name KitPieceSource
extends CorridorPieceSource
## Imported models from a bought modular kit (docs/systems/corridors/corridor_3d.md). Each side
## is a model scene instanced once per section. Kits place their pivots differently, so each side
## has an offset transform, applied inside the section's space (near edge at z = 0, extending to
## z = -section_length, centred on X and Y).
##
## Kits that keep their textures in a shared atlas are used through this source only; their
## textures cannot tile across a flat rectangle.

@export var scene_left: PackedScene
@export var scene_right: PackedScene
@export var scene_ceiling: PackedScene
@export var scene_floor: PackedScene

@export_group('Offsets')
@export var offset_left: Transform3D = Transform3D.IDENTITY
@export var offset_right: Transform3D = Transform3D.IDENTITY
@export var offset_ceiling: Transform3D = Transform3D.IDENTITY
@export var offset_floor: Transform3D = Transform3D.IDENTITY


func build_section(_index: int) -> Node3D:
  var section: Node3D = Node3D.new()
  _add_piece(section, 'Left', scene_left, offset_left)
  _add_piece(section, 'Right', scene_right, offset_right)
  _add_piece(section, 'Ceiling', scene_ceiling, offset_ceiling)
  _add_piece(section, 'Floor', scene_floor, offset_floor)
  return section


func _add_piece(parent: Node3D, piece_name: String, scene: PackedScene, offset: Transform3D) -> void:
  if scene == null:
    return
  var piece: Node = scene.instantiate()
  piece.name = piece_name
  if piece is Node3D:
    (piece as Node3D).transform = offset
  parent.add_child(piece)
