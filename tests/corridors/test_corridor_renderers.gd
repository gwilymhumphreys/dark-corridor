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


func test_corridor_3d_lights_every_piece_and_builds_past_the_light() -> void:
  var corridor: Corridor3D = SCENES[2].instantiate()
  corridor.input_enabled = false
  add_child(corridor)
  _nodes.append(corridor)
  for section: Node3D in corridor._sections.values():
    for piece: GeometryInstance3D in section.get_children():
      assert_eq(piece.material_overlay, corridor._light_material, piece.name + ' is darkened by the light')
  var last_index: int = corridor._sections.keys().max()
  var far_edge: float = corridor.depth_zero_distance() + float(last_index + 1) * corridor.piece_source.section_length
  assert_gt(far_edge, corridor.light_range, 'the last section ends beyond where the light reaches black')


func test_corridor_3d_wall_lights_replace_the_shader_light() -> void:
  var corridor: Corridor3D = SCENES[2].instantiate()
  corridor.input_enabled = false
  corridor.light_mode = Corridor3D.LightMode.WALL_LIGHTS
  add_child(corridor)
  _nodes.append(corridor)
  assert_eq(corridor._wall_lights.size(), 4, 'one light for each wall, the floor and the ceiling')
  for light: OmniLight3D in corridor._wall_lights:
    assert_eq(light.omni_range, corridor.light_range, 'the lights reach as far as the shader light')
    assert_eq(light.position.z, 0.0, 'level with the camera')
  for section: Node3D in corridor._sections.values():
    for piece: MeshInstance3D in section.get_children():
      assert_null(piece.material_overlay, piece.name + ' has no shader light')
      var material: StandardMaterial3D = piece.material_override
      assert_ne(material.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, piece.name + ' is lit by the lights')
  corridor.enemy_arrived_brightness = 0.8
  assert_almost_eq(corridor.enemy_brightness(0.0), 0.8, 0.0001, 'enemy images still use the shader formula')


func test_combat_corridor_passes_the_debug_light_choice() -> void:
  DebugPanels.corridor_kind = DebugPanelsAutoload.CorridorKind.THREE_D
  DebugPanels.corridor_light = Corridor3D.LightMode.WALL_LIGHTS
  var corridor: CombatCorridor = load('res://src/scenes/combat/combat_corridor.tscn').instantiate()
  add_child(corridor)
  _nodes.append(corridor)
  assert_eq((corridor.renderer() as Corridor3D).light_mode, Corridor3D.LightMode.WALL_LIGHTS, 'fights use the chosen light')


func test_corridor_3d_flicker_stays_within_its_amount() -> void:
  var corridor: Corridor3D = SCENES[2].instantiate()
  corridor.input_enabled = false
  add_child(corridor)
  _nodes.append(corridor)
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


func test_enemy_brightness_follows_the_corridor_light() -> void:
  for scene in SCENES:
    var corridor: CorridorRenderer = scene.instantiate()
    corridor.input_enabled = false
    add_child(corridor)
    _nodes.append(corridor)
    if not corridor is Corridor3D:
      assert_eq(corridor.enemy_brightness(3.0), 1.0, 'renderers without a light leave enemies at full brightness')
      continue
    var lit: Corridor3D = corridor
    lit.enemy_arrived_brightness = 0.8
    assert_almost_eq(lit.enemy_brightness(0.0), 0.8, 0.0001, 'arrived enemies use enemy_arrived_brightness')
    assert_lt(lit.enemy_brightness(0.5), 0.8, 'deeper enemies are darker')
    var past_light: float = lit.light_range / lit.piece_source.section_length
    assert_eq(lit.enemy_brightness(past_light), 0.0, 'enemies beyond light_range are black')


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
