extends GutTest
## The corridor renderers' shared perspective law (`axis_scale`) and the 3D corridor's piece
## sources (docs/systems/corridors/common.md, docs/systems/corridors/corridor_3d.md).

const SCENES: Array[PackedScene] = [
  preload('res://src/scenes/corridors/corridor_scaled.tscn'),
  preload('res://src/scenes/corridors/corridor_perspective.tscn'),
  preload('res://src/scenes/corridors/corridor_3d.tscn'),
]

var _nodes: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for n in _nodes:
    if is_instance_valid(n):
      n.free()
  _nodes.clear()
  TestCleanup.reset_all_managers()


func test_axis_scale_is_one_at_depth_zero_and_shrinks_with_depth() -> void:
  for scene in SCENES:
    var corridor: CorridorRenderer = scene.instantiate()
    corridor.input_enabled = false
    add_child(corridor)
    _nodes.append(corridor)
    var label: String = corridor.get_script().get_global_name()
    assert_almost_eq(corridor.axis_scale(0.0), 1.0, 0.0001, label + ': depth 0 = full size')
    assert_lt(corridor.axis_scale(1.0), 1.0, label + ': one cell deep is smaller')
    assert_lt(corridor.axis_scale(5.0), corridor.axis_scale(1.0), label + ': deeper is smaller still')


func test_corridor_3d_builds_sections_around_the_player() -> void:
  var corridor: Corridor3D = SCENES[2].instantiate()
  corridor.input_enabled = false
  add_child(corridor)
  _nodes.append(corridor)
  var sections: Node3D = corridor.get_node('SubViewport/Sections')
  assert_gt(sections.get_child_count(), 0, 'sections are built on ready')
  corridor.player_z = 40.0
  corridor._layout(0.0)
  await get_tree().process_frame   # sections behind are queue_freed
  for index: int in corridor._sections:
    assert_gte(index, 40 - corridor._sections_behind(), 'no section is kept far behind the player')
    assert_lte(index, 40 + corridor._sections_ahead(), 'no section is built beyond the light')


func test_code_built_pieces_stay_within_their_section() -> void:
  var source: CodeBuiltPieceSource = CodeBuiltPieceSource.new()
  var section: Node3D = source.build_section(7)
  _nodes.append(section)
  assert_eq(section.get_child_count(), 4, 'left, right, ceiling and floor')
  for piece: MeshInstance3D in section.get_children():
    var bounds: AABB = piece.transform * piece.mesh.get_aabb()
    assert_gte(bounds.position.z, -source.section_length - 0.001, piece.name + ' ends at the section far edge')
    assert_lte(bounds.end.z, 0.001, piece.name + ' starts at the section near edge')


func test_kit_piece_source_instances_each_side_scene() -> void:
  var model: Node3D = Node3D.new()
  var scene: PackedScene = PackedScene.new()
  scene.pack(model)
  model.free()
  var source: KitPieceSource = KitPieceSource.new()
  source.scene_left = scene
  source.scene_floor = scene
  source.offset_floor = Transform3D(Basis.IDENTITY, Vector3(0.0, -1.5, -1.5))
  var section: Node3D = source.build_section(0)
  _nodes.append(section)
  assert_eq(section.get_child_count(), 2, 'one piece per side that has a scene')
  assert_eq((section.get_node('Floor') as Node3D).position, Vector3(0.0, -1.5, -1.5), 'the side offset is applied')
