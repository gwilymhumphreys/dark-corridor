extends GutTest
## `InterfaceLook`: defaults read from the shared effects include, writing, reading and reset, copying
## settings to and from the corridor look, and the scenes that draw through its material
## (docs/systems/interface_look.md).

const INTERFACE_PALETTE: String = 'res://assets/palettes/new/ui/ui-default.gpl'

## Nodes drawn through `InterfaceLook.material`: the pictures that are not inside a panel frame.
const SCENE_NODES: Array[Array] = [
  ['res://src/scenes/combat/potion_slot.tscn', 'Icon'],
  ['res://src/scenes/combat/status_icon.tscn', 'Icon'],
  ['res://src/scenes/ui/tooltip/keyword_chip.tscn', 'Margin/Row/Icon'],
]

## Nodes drawn through `InterfaceLook.framed_material`: the pictures inside a `PanelSlot` frame.
const FRAMED_SCENE_NODES: Array[Array] = [
  ['res://src/scenes/combat/item_cell.tscn', 'Frame/Icon'],
]

## Nodes drawn through `InterfaceLook.portrait_material`: the framed portraits that breathe.
const PORTRAIT_SCENE_NODES: Array[Array] = [
  ['res://src/scenes/screens/character_card.tscn', 'Portrait/Image'],
  ['res://src/scenes/combat/ally_slot.tscn', 'Portrait/Image'],
  ['res://src/scenes/combat/combat_view_framed.tscn', 'Portraits/PlayerPortrait/Portrait/Image'],
]

## Nodes drawn through `InterfaceLook.element_material`: the interface elements that are not pictures.
const ELEMENT_SCENE_NODES: Array[Array] = [
  ['res://src/scenes/combat/value_pill.tscn', '.'],
  ['res://src/scenes/combat/value_pill.tscn', 'Value'],
  ['res://src/scenes/combat/ally_slot.tscn', 'Readout/HP/Background'],
  ['res://src/scenes/combat/ally_slot.tscn', 'Readout/HP/Fill'],
  ['res://src/scenes/combat/enemy_hud.tscn', 'HpRow/HP/Background'],
  ['res://src/scenes/combat/enemy_hud.tscn', 'HpRow/HP/Fill'],
  ['res://src/scenes/combat/combat_view_framed.tscn', 'Portraits/PlayerPortrait/Readout/HP/Background'],
  ['res://src/scenes/combat/combat_view_framed.tscn', 'Portraits/PlayerPortrait/Readout/HP/Fill'],
]


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_defaults_are_read_from_the_shared_effects_include() -> void:
  var defaults: Dictionary = InterfaceLook.defaults()
  assert_eq(defaults['grade_on'], false, 'grade is off by default')
  assert_almost_eq(defaults['halftone_cell'], 8.0, 0.001, 'the halftone cell size is read from the include')
  assert_true(defaults.has('scanlines_on'), 'scanlines are a setting')


func test_defaults_leave_out_bloom() -> void:
  for uniform: String in InterfaceLook.defaults():
    assert_false(uniform.begins_with('bloom_'), 'bloom is not an interface effect')


func test_the_vignette_is_a_setting() -> void:
  var defaults: Dictionary = InterfaceLook.defaults()
  assert_eq(defaults['vignette_on'], false, 'the vignette is off by default')
  assert_true(defaults.has('vignette_amount'), 'its settings are read from the shared include')


func test_the_dither_pattern_is_a_setting_but_the_switch_is_not() -> void:
  var defaults: Dictionary = InterfaceLook.defaults()
  assert_eq(defaults['dither_pattern'], 0, 'read from the palette clamp include')
  assert_true(defaults.has('dither_size'), 'the dot size is a setting')
  assert_true(defaults.has('dither_supersample'), 'the supersample switch is a setting')
  assert_false(defaults.has('dithering'), 'the dithering switch is kept by DebugPanels')
  assert_false(defaults.has('colour_count'), 'the palette itself is not a look setting')
  assert_false(defaults.has('perceptual'), 'colour matching is not a look setting')


func test_interface_dithering_is_separate_from_the_corridors() -> void:
  DebugPanels.set_interface_dithering(true)
  assert_true(DebugPanels.is_interface_dithering(), 'the interface switch is on')
  assert_eq(InterfaceLook.material.get_shader_parameter('dithering'), true,
    'the interface clamp dithers')
  assert_false(DebugPanels.is_dithering(), 'the corridor clamp is left alone')
  assert_eq(DebugPanels.world_material.get_shader_parameter('dithering'), false,
    'the corridor clamp does not dither')


func test_save_then_load_restores_the_settings() -> void:
  InterfaceLook.material.set_shader_parameter('halftone_on', true)
  InterfaceLook.material.set_shader_parameter('halftone_cell', 20.0)
  var file: ConfigFile = ConfigFile.new()
  InterfaceLook.write_look(file)
  InterfaceLook.reset()
  assert_eq(InterfaceLook.material.get_shader_parameter('halftone_on'), false, 'reset restores the default')
  InterfaceLook.read_look(file)
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


func test_framed_pictures_use_the_framed_material() -> void:
  for pair: Array in FRAMED_SCENE_NODES:
    var scene: PackedScene = load(pair[0])
    var root: Node = scene.instantiate()
    assert_eq(root.get_node(pair[1]).material, InterfaceLook.framed_material,
      '%s %s draws through the framed material' % [pair[0], pair[1]])
    root.free()



func test_breathing_portraits_use_the_portrait_material() -> void:
  for pair: Array in PORTRAIT_SCENE_NODES:
    var scene: PackedScene = load(pair[0])
    var root: Node = scene.instantiate()
    assert_eq(root.get_node(pair[1]).material, InterfaceLook.portrait_material,
      '%s %s draws through the portrait material' % [pair[0], pair[1]])
    root.free()


func test_the_portrait_material_follows_the_framed_settings() -> void:
  InterfaceLook.set_setting('hatching_on', true)
  InterfaceLook.set_setting('picture_wear_on', true)
  assert_eq(InterfaceLook.portrait_material.get_shader_parameter('hatching_on'), true, 'a setting reaches the portraits')
  assert_ne(InterfaceLook.portrait_material.get_shader_parameter('picture_wear_on'), true,
    'picture wear stays off, as on the framed material')
  InterfaceLook.reset()


func test_only_the_portrait_shader_has_a_per_node_setting() -> void:
  # Godot reserves a block of the instance uniform buffer for every node drawn through a shader with an
  # instance uniform, so the shader on every icon, pill and label must have none.
  for look_material: ShaderMaterial in [InterfaceLook.material, InterfaceLook.element_material, InterfaceLook.framed_material]:
    assert_false(look_material.shader.code.contains('#define PICTURE_ZOOM'), '%s has no picture_zoom' % look_material.shader.resource_path)
  assert_true(InterfaceLook.portrait_material.shader.code.contains('#define PICTURE_ZOOM'), 'the portrait shader has picture_zoom')


func test_interface_elements_use_the_element_material() -> void:
  for pair: Array in ELEMENT_SCENE_NODES:
    var scene: PackedScene = load(pair[0])
    var root: Node = scene.instantiate()
    assert_eq(root.get_node(pair[1]).material, InterfaceLook.element_material,
      '%s %s draws through the element material' % [pair[0], pair[1]])
    root.free()


func test_a_setting_is_written_to_every_material() -> void:
  InterfaceLook.set_setting('hatching_on', true)
  assert_eq(InterfaceLook.material.get_shader_parameter('hatching_on'), true,
    'the images take the setting')
  assert_eq(InterfaceLook.element_material.get_shader_parameter('hatching_on'), true,
    'the interface elements take the setting')
  assert_eq(InterfaceLook.framed_material.get_shader_parameter('hatching_on'), true,
    'the framed pictures take the setting')


func test_colour_changing_switches_stay_off_on_the_element_material() -> void:
  for uniform: String in InterfaceLookAutoload.ELEMENT_OFF_UNIFORMS:
    InterfaceLook.set_setting(uniform, true)
    assert_eq(InterfaceLook.material.get_shader_parameter(uniform), true,
      '%s is on for the images' % uniform)
    assert_ne(InterfaceLook.element_material.get_shader_parameter(uniform), true,
      '%s stays off for the interface elements' % uniform)


func test_picture_wear_stays_off_on_the_framed_material() -> void:
  for uniform: String in InterfaceLookAutoload.FRAMED_OFF_UNIFORMS:
    InterfaceLook.set_setting(uniform, true)
    assert_eq(InterfaceLook.material.get_shader_parameter(uniform), true,
      '%s is on for the unframed pictures' % uniform)
    assert_ne(InterfaceLook.framed_material.get_shader_parameter(uniform), true,
      '%s stays off for the pictures inside a frame' % uniform)


func test_the_framed_material_is_clamped_to_the_portrait_palette() -> void:
  DebugPanels.set_interface_palette(INTERFACE_PALETTE)
  DebugPanels.set_portrait_palette(DebugPanelsAutoload.PORTRAIT_SAME_AS_INTERFACE)
  assert_gt(InterfaceLook.framed_material.get_shader_parameter('colour_count'), 0,
    'the framed pictures clamp to the portrait palette like the other pictures')


func test_the_element_material_is_not_clamped_to_the_portrait_palette() -> void:
  DebugPanels.set_portrait_palette(DebugPanelsAutoload.PORTRAIT_SAME_AS_INTERFACE)
  var count: Variant = InterfaceLook.element_material.get_shader_parameter('colour_count')
  assert_true(count == null or count == 0, 'the interface elements keep their own colours')


func test_the_per_node_zoom_is_not_a_look_setting() -> void:
  for uniform: String in InterfaceLookAutoload.NODE_UNIFORMS:
    assert_false(InterfaceLook.defaults().has(uniform),
      '%s is set per node, so it is not in the panel or a preset' % uniform)
