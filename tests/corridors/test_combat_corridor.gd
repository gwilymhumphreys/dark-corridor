extends GutTest
## CombatCorridor hosts the 3D corridor, places enemy sprites in it, pins HUD anchors above them,
## and picks images without touching the run RNG (docs/systems/run_screen.md, "Enemies in the
## corridor").

const COMBAT_CORRIDOR: PackedScene = preload('res://src/scenes/combat/combat_corridor.tscn')

var _nodes: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for n in _nodes:
    if is_instance_valid(n):
      n.free()
  _nodes.clear()
  TestCleanup.reset_all_managers()


func _host() -> CombatCorridor:
  var corridor: CombatCorridor = COMBAT_CORRIDOR.instantiate()
  corridor.size = Vector2(1700.0, 1150.0)
  add_child(corridor)
  _nodes.append(corridor)
  return corridor


func test_hosts_the_3d_corridor_with_an_enemy_sprite() -> void:
  var corridor: CombatCorridor = _host()
  var corridor_3d: Corridor3D = corridor.corridor()
  assert_not_null(corridor_3d, 'a 3D corridor is hosted')
  assert_false(corridor_3d.input_enabled, 'W/S cannot scroll the fight corridor')
  var sprite: Sprite3D = corridor._enemies[0]
  assert_eq(sprite.get_parent(), corridor_3d.get_node('SubViewport/Enemies'), 'the enemy is a sprite in the 3D scene')
  assert_true(sprite.texture.resource_path.begins_with(MonsterImages.CUT_OUT_FOLDER), 'fights use the cut-out images')
  var arrived_z: float = sprite.position.z
  corridor.set_enemy_depth(3.0)
  assert_lt(sprite.position.z, arrived_z, 'a deeper enemy is further from the camera')


func test_enemy_anchor_sits_above_the_sprite() -> void:
  var corridor: CombatCorridor = _host()
  var sprite: Sprite3D = corridor._enemies[0]
  var top: Vector3 = sprite.position + Vector3(0.0, sprite.pixel_size * float(sprite.texture.get_height()) * 0.5, 0.0)
  var top_on_screen: Vector2 = corridor.global_position + corridor.size * 0.5 + corridor.corridor().unproject(top)
  var anchor: Vector2 = corridor.enemy_anchor(0)
  assert_almost_eq(anchor.x, top_on_screen.x, 0.5, 'centred on the sprite')
  assert_almost_eq(anchor.y, top_on_screen.y - CombatCorridor.HUD_GAP, 0.5, 'just above the sprite top')
  corridor.set_enemy_depth(3.0)
  assert_eq(corridor.enemy_anchor(0), anchor, 'the anchor stays put during the approach')


func test_each_enemy_keeps_its_own_sprite() -> void:
  var corridor: CombatCorridor = _host()
  var placeholder: Sprite3D = corridor._enemies[0]
  var left: RefCounted = RefCounted.new()
  var right: RefCounted = RefCounted.new()
  corridor.set_enemies([left, right])
  assert_eq(corridor._enemies[0], placeholder, 'the first enemy takes over the sprite shown during the approach')
  var right_sprite: Sprite3D = corridor._enemies[1]
  var right_texture: Texture2D = right_sprite.texture
  corridor.set_enemies([right])   # the left enemy died
  assert_eq(corridor._enemies.size(), 1, 'the dead enemy\'s sprite is removed')
  assert_eq(corridor._enemies[0], right_sprite, 'the surviving enemy keeps its sprite')
  assert_eq(right_sprite.texture, right_texture, 'and its image')
  assert_null(placeholder.texture, 'the dead enemy\'s sprite released its image')
  var summon: RefCounted = RefCounted.new()
  corridor.set_enemies([right, summon])
  assert_eq(corridor._enemies[0], right_sprite, 'a summon joining does not change existing sprites')
  assert_ne(corridor._enemies[1], right_sprite, 'the summon gets its own sprite')


func test_enemies_at_one_depth_have_distinct_distances() -> void:
  var corridor: CombatCorridor = _host()
  corridor.set_enemies([RefCounted.new(), RefCounted.new(), RefCounted.new()])
  var distances: Array = []
  for sprite: Sprite3D in corridor._enemies:
    assert_false(sprite.position.z in distances, 'no two enemies are drawn at the same distance')
    distances.append(sprite.position.z)
  assert_lt(corridor._enemies[0].position.x, corridor._enemies[2].position.x, 'arranged left to right')


func test_forced_monster_image_is_used_and_cleared_on_reset() -> void:
  MonsterImages.forced_path = 'res://assets/monsters/cut_out/bone_golem.png'
  var corridor: CombatCorridor = _host()
  assert_eq(corridor._enemies[0].texture.resource_path, MonsterImages.forced_path, 'the forced image is used')
  DebugPanels.reset_settings()
  assert_eq(MonsterImages.forced_path, '', 'resetting the debug panel clears it')


func test_cut_out_tool_makes_black_transparent_without_a_dark_edge() -> void:
  var tool_script: GDScript = load('res://tools/cut_out_monsters.gd')
  var image: Image = Image.create(3, 1, false, Image.FORMAT_RGB8)
  image.set_pixel(0, 0, Color8(3, 2, 4))       # background with compression noise
  image.set_pixel(1, 0, Color8(20, 10, 5))     # a soft edge, partly faded into the black
  image.set_pixel(2, 0, Color8(200, 150, 90))  # the figure
  tool_script.cut_out(image, 0.04, 0.12)
  assert_eq(image.get_pixel(0, 0).a, 0.0, 'near-black is fully transparent')
  var edge: Color = image.get_pixel(1, 0)
  assert_between(edge.a, 0.05, 0.95, 'a soft edge is partly transparent')
  assert_gt(edge.r8, 20, 'a partly transparent pixel is brightened, so there is no dark outline')
  assert_eq(image.get_pixel(2, 0), Color8(200, 150, 90), 'bright pixels are unchanged and opaque')


func test_corridor_is_drawn_through_the_world_clamp() -> void:
  var corridor: CombatCorridor = _host()
  assert_eq(corridor.material, DebugPanels.world_material, 'the corridor uses the world clamp material')
  assert_eq(DebugPanels.world_material.get_shader_parameter('colour_count'), 0, 'the world clamp is off by default')
  var path: String = 'res://assets/palettes/new/world/world-ash-16.gpl'
  DebugPanels.set_world_palette(path)
  var colours: PackedColorArray = PaletteLoader.load_palette(path)
  assert_eq(DebugPanels.world_material.get_shader_parameter('colour_count'), colours.size(),
    'a chosen palette file is loaded into the world clamp')
  var texture: Texture2D = DebugPanels.world_material.get_shader_parameter('palette_rgb')
  var last: int = colours.size() - 1
  assert_eq(texture.get_image().get_pixel(last, 0).to_rgba32(), colours[last].to_rgba32(), 'with the palette colours')
  DebugPanels.reset_settings()
  assert_eq(DebugPanels.world_material.get_shader_parameter('colour_count'), 0, 'resetting turns the world clamp off')


func test_random_image_pick_leaves_the_run_rng_untouched() -> void:
  var run := RunManager.new()
  run.start(1234)
  var run_state: int = run.rng.state
  seed(99)
  var expected_global: int = randi()
  seed(99)
  for i in 5:
    assert_not_null(MonsterImages.random_texture(), 'a sample image is picked')
  assert_eq(run.rng.state, run_state, 'the run RNG did not advance')
  assert_eq(randi(), expected_global, 'the global RNG did not advance')
  run.teardown()
  run.free()
