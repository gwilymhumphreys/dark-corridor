extends GutTest
## `InterfaceLook`: defaults read from the shared effects include, save/load/reset, copying settings to
## and from the corridor look, and the scenes that draw through its material
## (docs/systems/interface_look.md).

const LOOK_PATH: String = 'user://test_looks/interface_look.cfg'
const SCENE_NODES: Array[Array] = [
  ['res://src/scenes/combat/item_cell.tscn', 'Frame/Icon'],
  ['res://src/scenes/combat/value_pill.tscn', '.'],
  ['res://src/scenes/combat/value_pill.tscn', 'Value'],
  ['res://src/scenes/screens/draft_card.tscn', 'Icon'],
  ['res://src/scenes/combat/potion_slot.tscn', 'Icon'],
  ['res://src/scenes/combat/status_icon.tscn', 'Icon'],
  ['res://src/scenes/ui/tooltip/keyword_chip.tscn', 'Margin/Row/Icon'],
  ['res://src/scenes/screens/character_card.tscn', 'Portrait/Image'],
  ['res://src/scenes/combat/ally_slot.tscn', 'Left/Portrait/Image'],
  ['res://src/scenes/combat/ally_slot.tscn', 'Left/HP/Fill'],
  ['res://src/scenes/combat/enemy_hud.tscn', 'HpRow/HP/Background'],
  ['res://src/scenes/combat/enemy_hud.tscn', 'HpRow/HP/Fill'],
  ['res://src/scenes/combat/combat_view_framed.tscn', 'BottomBar/PlayerPortrait/Portrait/Image'],
  ['res://src/scenes/combat/combat_view_framed.tscn', 'BottomBar/PlayerPortrait/HP/Fill'],
]


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  DirAccess.remove_absolute(LOOK_PATH)
  DirAccess.remove_absolute(LOOK_PATH.get_base_dir())
  TestCleanup.reset_all_managers()


func test_defaults_are_read_from_the_shared_effects_include() -> void:
  var defaults: Dictionary = InterfaceLook.defaults()
  assert_eq(defaults['grade_on'], false, 'grade is off by default')
  assert_almost_eq(defaults['halftone_cell'], 8.0, 0.001, 'the halftone cell size is read from the include')
  assert_true(defaults.has('scanlines_on'), 'scanlines are a setting')


func test_defaults_leave_out_warp_bloom_and_vignette() -> void:
  for uniform: String in InterfaceLook.defaults():
    assert_false(uniform.begins_with('warp_'), 'warp is not an interface effect')
    assert_false(uniform.begins_with('bloom_'), 'bloom is not an interface effect')
    assert_false(uniform.begins_with('vignette_'), 'vignette is not an interface effect')


func test_save_then_load_restores_the_settings() -> void:
  InterfaceLook.material.set_shader_parameter('halftone_on', true)
  InterfaceLook.material.set_shader_parameter('halftone_cell', 20.0)
  assert_eq(InterfaceLook.save_look(LOOK_PATH), OK, 'saved')
  InterfaceLook.reset()
  assert_eq(InterfaceLook.material.get_shader_parameter('halftone_on'), false, 'reset restores the default')
  assert_true(InterfaceLook.load_look(LOOK_PATH), 'loaded')
  assert_eq(InterfaceLook.material.get_shader_parameter('halftone_on'), true, 'switch restored')
  assert_almost_eq(InterfaceLook.material.get_shader_parameter('halftone_cell'), 20.0, 0.001,
    'number restored')


func test_picture_wear_is_a_setting_and_off_by_default() -> void:
  var defaults: Dictionary = InterfaceLook.defaults()
  assert_eq(defaults['picture_wear_on'], false, 'picture wear is off by default')
  assert_true(defaults.has('picture_edge_wear_width'), 'picture wear settings are read from the shader')
  assert_false(defaults.has('picture_wear_dark_colour'), 'the mark colours are not settings')


func test_picture_wear_is_not_copied_to_the_corridor_look() -> void:
  InterfaceLook.material.set_shader_parameter('picture_wear_on', true)
  InterfaceLook.copy_to_corridor()
  assert_null(DebugPanels.world_material.get_shader_parameter('picture_wear_on'),
    'the corridor look has no picture wear')


func test_load_of_a_missing_file_returns_false() -> void:
  assert_false(InterfaceLook.load_look('user://no_such_interface_look.cfg'), 'a missing file is refused')


func test_copy_from_corridor_copies_shared_settings() -> void:
  DebugPanels.world_material.set_shader_parameter('grade_on', true)
  DebugPanels.world_material.set_shader_parameter('grade_contrast', 2.5)
  InterfaceLook.copy_from_corridor()
  assert_eq(InterfaceLook.material.get_shader_parameter('grade_on'), true, 'switch copied')
  assert_almost_eq(InterfaceLook.material.get_shader_parameter('grade_contrast'), 2.5, 0.001,
    'number copied')


func test_copy_to_corridor_copies_shared_settings() -> void:
  InterfaceLook.material.set_shader_parameter('posterize_on', true)
  InterfaceLook.material.set_shader_parameter('posterize_levels', 3.0)
  InterfaceLook.copy_to_corridor()
  assert_eq(DebugPanels.world_material.get_shader_parameter('posterize_on'), true, 'switch copied')
  assert_almost_eq(DebugPanels.world_material.get_shader_parameter('posterize_levels'), 3.0, 0.001,
    'number copied')


func test_copy_to_corridor_leaves_corridor_only_settings_alone() -> void:
  DebugPanels.world_material.set_shader_parameter('bloom_on', true)
  InterfaceLook.copy_to_corridor()
  assert_eq(DebugPanels.world_material.get_shader_parameter('bloom_on'), true,
    'bloom is corridor-only, so it is not touched')


func test_reset_settings_resets_the_interface_look() -> void:
  InterfaceLook.material.set_shader_parameter('hatching_on', true)
  DebugPanels.reset_settings()
  assert_eq(InterfaceLook.material.get_shader_parameter('hatching_on'), false,
    'reset_settings resets the interface look')


func test_interface_images_use_the_shared_material() -> void:
  for pair: Array in SCENE_NODES:
    var scene: PackedScene = load(pair[0])
    var root: Node = scene.instantiate()
    assert_eq(root.get_node(pair[1]).material, InterfaceLook.material,
      '%s %s draws through the shared material' % [pair[0], pair[1]])
    root.free()
