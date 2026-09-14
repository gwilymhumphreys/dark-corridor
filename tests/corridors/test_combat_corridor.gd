extends GutTest
## CombatCorridor hosts whichever renderer the debug panel chose, sizes enemy HUD anchors from
## each sprite's own image, and picks painted images without touching the run RNG
## (docs/systems/run_screen.md, "Enemy-in-corridor occupant").

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


func test_hosts_each_renderer_kind() -> void:
  var expected: Dictionary = {
    DebugPanelsAutoload.CorridorKind.SCALED: 'CorridorScaled',
    DebugPanelsAutoload.CorridorKind.PERSPECTIVE: 'CorridorPerspective',
    DebugPanelsAutoload.CorridorKind.THREE_D: 'Corridor3D',
  }
  for kind: int in expected:
    DebugPanels.corridor_kind = kind
    var corridor: CombatCorridor = _host()
    var renderer: CorridorRenderer = corridor.renderer()
    assert_not_null(renderer, 'a renderer is hosted')
    assert_eq(renderer.get_script().get_global_name(), expected[kind], 'the chosen renderer kind')
    assert_false(renderer.input_enabled, 'W/S cannot scroll the fight corridor')
    corridor.set_enemy_depth(3.0)   # the approach works on every renderer
    assert_lt(corridor._enemies[0].scale.x, corridor._arrived_scale(corridor._enemies[0], 1), 'deeper is smaller')


func test_enemy_anchor_uses_the_sprite_image_height() -> void:
  var corridor: CombatCorridor = _host()
  var sprite: Sprite2D = corridor._enemies[0]
  var centre_y: float = corridor.global_position.y + corridor.size.y * 0.5
  var half_h: float = float(sprite.texture.get_height()) * corridor._arrived_scale(sprite, 1) * 0.5
  assert_almost_eq(corridor.enemy_anchor(0).y, centre_y - half_h - CombatCorridor.HUD_GAP, 0.01,
    'the HUD sits above this sprite\'s own image')
  assert_ne(sprite.texture, CombatCorridor.ENEMY_SPRITE, 'painted samples are the default')
  assert_almost_eq(half_h * 2.0, Balance.ENEMY_PAINTED_HEIGHT, 0.01, 'a painted image is sized to the target height')


func test_pixel_sprite_option_keeps_the_original_sprite() -> void:
  DebugPanels.enemy_images = DebugPanelsAutoload.EnemyImages.PIXEL
  var corridor: CombatCorridor = _host()
  var sprite: Sprite2D = corridor._enemies[0]
  assert_eq(sprite.texture, CombatCorridor.ENEMY_SPRITE, 'the pixel sprite is used')
  assert_almost_eq(sprite.scale.x, Balance.ENEMY_FULL_SCALE, 0.0001, 'at the original full scale')


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
