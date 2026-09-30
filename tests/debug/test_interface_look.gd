extends GutTest
## `InterfaceLook`: defaults read from the shared effects include, writing, reading and reset, copying
## settings to and from the corridor look, and the scenes that draw through its material
## (docs/systems/interface_look.md).

const INTERFACE_PALETTE: String = 'res://assets/palettes/new/ui/ui-default.gpl'

## Nodes drawn through `InterfaceLook.material`: the pictures that are not inside a panel frame.
const SCENE_NODES: Array[Array] = [
  ['res://src/scenes/combat/status_icon.tscn', 'Frame/Icon'],
  ['res://src/scenes/ui/tooltip/keyword_chip.tscn', 'Margin/Row/Icon'],
]

## Nodes drawn through `InterfaceLook.framed_material`: the pictures inside a panel frame.
const FRAMED_SCENE_NODES: Array[Array] = [
  ['res://src/scenes/combat/item_cell.tscn', 'Frame/Icon'],
  ['res://src/scenes/combat/potion_slot.tscn', 'Cell/Frame/Icon'],
]

## Nodes drawn through `InterfaceLook.portrait_material`: the framed portraits that breathe.
const PORTRAIT_SCENE_NODES: Array[Array] = [
  ['res://src/scenes/screens/character_card.tscn', 'Portrait/Image'],
  ['res://src/scenes/combat/ally_slot.tscn', 'Row/Portrait/Image'],
  ['res://src/scenes/combat/combat_view_framed.tscn', 'Portraits/PlayerPanel/Row/Portrait/Image'],
]

## Nodes drawn through `InterfaceLook.element_material`: the interface elements that are not pictures.
const ELEMENT_SCENE_NODES: Array[Array] = [
  ['res://src/scenes/combat/value_pill.tscn', '.'],
  ['res://src/scenes/combat/value_pill.tscn', 'Value'],
  ['res://src/scenes/combat/health_bar.tscn', 'Bar/Background'],
  ['res://src/scenes/combat/health_bar.tscn', 'Bar/HealthFill'],
  ['res://src/scenes/combat/health_bar.tscn', 'Bar/ShieldFill'],
  ['res://src/scenes/combat/health_bar.tscn', 'Bar/Lines'],
  ['res://src/scenes/combat/item_cell.tscn', 'TemporaryTag'],
  ['res://src/scenes/combat/item_cell.tscn', 'TemporaryTag/Label'],
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


func test_the_effects_wall_uses_the_effects_material() -> void:
  var scene: PackedScene = load('res://src/scenes/combat/combat_view_framed.tscn')
  var root: Node = scene.instantiate()
  assert_eq(root.get_node('VfxWall').material, InterfaceLook.effects_material,
    'the combat effects draw through the effects material')
  root.free()


func test_only_the_effects_shader_lays_patterns_out_on_the_screen() -> void:
  for look_material: ShaderMaterial in [InterfaceLook.material, InterfaceLook.element_material, InterfaceLook.framed_material, InterfaceLook.portrait_material]:
    assert_false(look_material.shader.code.contains('#define EFFECTS'), '%s is not the effects shader' % look_material.shader.resource_path)
  assert_true(InterfaceLook.effects_material.shader.code.contains('#define EFFECTS'), 'the effects shader defines EFFECTS')


func test_a_setting_reaches_the_effects_except_the_colour_changing_switches() -> void:
  InterfaceLook.set_setting('halftone_on', true)
  assert_eq(InterfaceLook.effects_material.get_shader_parameter('halftone_on'), true, 'a setting reaches the effects')
  for uniform: String in InterfaceLookAutoload.EFFECTS_OFF_UNIFORMS:
    InterfaceLook.set_setting(uniform, true)
    assert_ne(InterfaceLook.effects_material.get_shader_parameter(uniform), true,
      '%s stays off for the effects' % uniform)


func test_the_effects_settings_are_look_settings_and_off_by_default() -> void:
  var defaults: Dictionary = InterfaceLook.defaults()
  assert_eq(defaults['effects_on'], false, 'the effects take no look by default')
  assert_eq(defaults['effects_dither_transparency'], false, 'transparency dithering is off by default')
  assert_eq(defaults['effects_damage_numbers'], 0, 'the numbers are drawn with the effects by default')


func test_the_effects_take_the_effects_palette_not_the_portrait_palette() -> void:
  DebugPanels.set_interface_palette('')
  DebugPanels.set_portrait_palette('res://assets/palettes/shortlist/2bit-demichrome.gpl')
  DebugPanels.set_effects_palette(DebugPanelsAutoload.PORTRAIT_SAME_AS_INTERFACE)
  assert_gt(InterfaceLook.framed_material.get_shader_parameter('colour_count'), 0, 'the pictures are clamped')
  assert_eq(InterfaceLook.effects_material.get_shader_parameter('colour_count'), 0,
    'the effects follow the interface palette, which is off')
  DebugPanels.set_effects_palette(DebugPanelsAutoload.EFFECTS_SAME_AS_PORTRAIT)
  assert_eq(InterfaceLook.effects_material.get_shader_parameter('colour_count'),
    InterfaceLook.framed_material.get_shader_parameter('colour_count'), 'the effects can follow the pictures')


func test_the_interface_dithering_switch_reaches_the_effects() -> void:
  DebugPanels.set_interface_dithering(true)
  assert_eq(InterfaceLook.effects_material.get_shader_parameter('dithering'), true, 'the effects dither')


func test_the_effects_palette_is_saved_in_a_preset() -> void:
  DebugPanels.set_effects_palette(DebugPanelsAutoload.EFFECTS_SAME_AS_PORTRAIT)
  var file: ConfigFile = ConfigFile.new()
  DebugPanels.write_interface_palettes(file)
  DebugPanels.reset_palettes()
  assert_eq(DebugPanels.effects_palette, DebugPanelsAutoload.PORTRAIT_SAME_AS_INTERFACE, 'reset restores the default')
  DebugPanels.read_interface_palettes(file)
  assert_eq(DebugPanels.effects_palette, DebugPanelsAutoload.EFFECTS_SAME_AS_PORTRAIT, 'the choice is restored')


func test_damage_numbers_can_be_drawn_like_the_value_pills() -> void:
  var vfx: VfxDriver = VfxDriver.new()
  vfx.material = InterfaceLook.effects_material
  add_child_autofree(vfx)
  var numbers: Node2D = vfx.get_node('Numbers')
  vfx._numbers_material_update()
  assert_true(numbers.use_parent_material, 'the numbers share the wall material by default')
  InterfaceLook.set_setting('effects_on', true)
  InterfaceLook.set_setting('effects_damage_numbers', 1)
  vfx._numbers_material_update()
  assert_false(numbers.use_parent_material, 'drawn like the pills, the numbers have their own material')
  assert_eq(numbers.material, InterfaceLook.element_material, 'the value pills material')
