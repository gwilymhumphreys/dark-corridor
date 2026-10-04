extends GutTest
## The 3D corridor: its sections, light, piece sources and enemy sprites
## (docs/systems/corridors/corridor_3d.md).

const CORRIDOR_SCENE: PackedScene = preload('res://src/scenes/corridors/corridor_3d.tscn')
const TEXTURE_PATH: String = 'res://assets/monsters/cut_out/bone_golem.png'

var _nodes: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for n in _nodes:
    if is_instance_valid(n):
      n.free()
  _nodes.clear()
  TestCleanup.reset_all_managers()


func _corridor(configure: Callable = Callable()) -> Corridor3D:
  var corridor: Corridor3D = CORRIDOR_SCENE.instantiate()
  corridor.input_enabled = false
  corridor.auto_view_size = false
  corridor.view_size = Vector2(1700.0, 1150.0)
  if configure.is_valid():
    configure.call(corridor)
  add_child(corridor)
  _nodes.append(corridor)
  return corridor


func test_corridor_3d_builds_sections_around_the_player() -> void:
  var corridor: Corridor3D = _corridor()
  var sections: Node3D = corridor.get_node('SubViewport/Sections')
  assert_gt(sections.get_child_count(), 0, 'sections are built on ready')
  corridor.player_z = 40.0
  corridor._layout()
  await get_tree().process_frame   # sections behind are queue_freed
  for index: int in corridor._sections:
    assert_gte(index, 40 - corridor._sections_behind(), 'no section is kept far behind the player')
    assert_lte(index, 40 + corridor._sections_ahead(), 'no section is built beyond the light')


func test_corridor_3d_lit_pieces_and_builds_past_the_light() -> void:
  var corridor: Corridor3D = _corridor()
  var environment: Environment = (corridor.get_node('SubViewport/Camera') as Camera3D).environment
  assert_eq(environment.ambient_light_source, Environment.AMBIENT_SOURCE_DISABLED, 'only the lights light the corridor')
  for section: Node3D in corridor._sections.values():
    for piece: MeshInstance3D in section.get_children():
      var material: StandardMaterial3D = piece.material_override
      assert_ne(material.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, piece.name + ' is lit by the lights')
  var last_index: int = corridor._sections.keys().max()
  var far_edge: float = corridor.depth_zero_distance() + float(last_index + 1) * corridor.piece_source.section_length
  assert_gt(far_edge, corridor.light_range, 'the last section ends beyond where the light reaches black')


func test_corridor_3d_light_is_one_light_at_the_camera() -> void:
  var corridor: Corridor3D = _corridor(func(c: Corridor3D) -> void:
    c.light_range = 6.0
    c.light_attenuation = 0.5
  )
  var lights: Array[Node] = corridor.get_node('SubViewport').find_children('*', 'OmniLight3D')
  assert_eq(lights.size(), 1, 'a single light')
  var light: OmniLight3D = lights[0]
  assert_eq(light.position, Vector3.ZERO, 'at the camera')
  assert_eq(light.omni_range, 6.0, 'reaches light_range')
  assert_eq(light.omni_attenuation, 0.5, 'uses light_attenuation')
  assert_almost_eq(light.light_energy, corridor.light_energy, 0.0001, 'uses light_energy')


func test_corridor_3d_flicker_stays_within_its_amount() -> void:
  var corridor: Corridor3D = _corridor()
  assert_eq(corridor.flicker_level(1.23), 1.0, 'no flicker by default')
  corridor.flicker_amount = 0.5
  var lowest: float = 1.0
  var highest: float = 0.0
  for step in range(200):
    var level: float = corridor.flicker_level(float(step) * 0.05)
    lowest = minf(lowest, level)
    highest = maxf(highest, level)
  assert_gte(lowest, 0.5, 'never dimmer than 1 - flicker_amount')
  assert_lte(highest, 1.0, 'never brighter than full')
  assert_gt(highest - lowest, 0.25, 'the light visibly changes over ten seconds')


func test_enemy_sprite_is_lit_and_uses_alpha_scissor() -> void:
  var corridor: Corridor3D = _corridor(func(c: Corridor3D) -> void: c.alpha_scissor_threshold = 0.3)
  var sprite: Sprite3D = corridor.add_enemy(load(TEXTURE_PATH))
  assert_eq(sprite.get_parent(), corridor.get_node('SubViewport/Enemies'), 'under the Enemies node')
  assert_true(sprite.shaded, 'lit by the corridor light')
  assert_eq(sprite.alpha_cut, SpriteBase3D.ALPHA_CUT_DISCARD, 'alpha scissor, no blending')
  assert_almost_eq(sprite.alpha_scissor_threshold, 0.3, 0.0001, 'uses the corridor threshold')
  corridor.remove_enemy(sprite)
  assert_null(sprite.texture, 'the texture is released before free')


func test_enemy_sprite_at_depth_zero_is_the_target_height_on_screen() -> void:
  var corridor: Corridor3D = _corridor()
  var sprite: Sprite3D = corridor.add_enemy(load(TEXTURE_PATH))
  corridor.size_enemy(sprite, Balance.ENEMY_PAINTED_HEIGHT)
  var centre: Vector3 = corridor.enemy_position(0.0, 0.0)
  var half: float = sprite.pixel_size * float(sprite.texture.get_height()) * 0.5
  var top: Vector2 = corridor.unproject(centre + Vector3(0.0, half, 0.0))
  var bottom: Vector2 = corridor.unproject(centre - Vector3(0.0, half, 0.0))
  assert_almost_eq(bottom.y - top.y, Balance.ENEMY_PAINTED_HEIGHT, 1.0, 'the target height in screen pixels')
  var offset: Vector3 = corridor.enemy_position(0.0, 200.0)
  assert_almost_eq(corridor.unproject(offset).x, 200.0, 1.0, 'a horizontal offset is in screen pixels at depth 0')
  var deeper: Vector3 = corridor.enemy_position(2.0, 0.0)
  assert_lt(deeper.z, centre.z, 'a deeper enemy is further from the camera')


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
