extends GutTest
## `PrintLook`: background, panel, border and corridor overlay defaults, save/load round-trip including
## the panel section, and the panel wear colours (docs/systems/panel_wear.md, docs/systems/print_frame.md).

const LOOK_PATH: String = 'user://test_looks/print_look.cfg'


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  DirAccess.remove_absolute(LOOK_PATH)
  DirAccess.remove_absolute(LOOK_PATH.get_base_dir())
  TestCleanup.reset_all_managers()


func test_panel_defaults_are_read_from_the_shader_code() -> void:
  var defaults: Dictionary = PrintLook.panel_defaults()
  assert_eq(defaults['panel_faded_areas_on'], true, 'faded areas are on by default')
  assert_eq(defaults['panel_specks_on'], true, 'specks are on by default')
  assert_eq(defaults['panel_edge_wear_on'], true, 'edge wear is on by default')
  assert_eq(defaults['panel_creases_on'], true, 'creases are on by default')
  assert_false(defaults.has('wear_dark_colour'), 'the mark colours are not a look setting')
  assert_false(defaults.has('panel_rect'), 'the per-panel rect is not a look setting')
  assert_false(defaults.has('panel_seed'), 'the per-panel seed is not a look setting')


func test_panel_wear_has_no_folds_group() -> void:
  for uniform: String in PrintLook.panel_defaults():
    assert_false(uniform.begins_with('panel_folds'), 'folds are laid out for a screen, not a panel')


func test_save_then_load_restores_the_panel_section() -> void:
  PrintLook.panel_material.set_shader_parameter('panel_specks_on', false)
  PrintLook.panel_material.set_shader_parameter('panel_edge_wear_width', 30.0)
  assert_eq(PrintLook.save_print_look(LOOK_PATH), OK, 'saved')
  PrintLook.reset_print_look()
  assert_eq(PrintLook.panel_material.get_shader_parameter('panel_specks_on'), true, 'reset restores the default')
  assert_true(PrintLook.load_print_look(LOOK_PATH), 'loaded')
  assert_eq(PrintLook.panel_material.get_shader_parameter('panel_specks_on'), false, 'panel switch restored')
  assert_almost_eq(PrintLook.panel_material.get_shader_parameter('panel_edge_wear_width'), 30.0, 0.001,
    'panel number restored')


func test_panel_wear_colours_follow_the_interface_palette() -> void:
  var default_dark: Color = PrintLook.panel_material.get_shader_parameter('wear_dark_colour')
  var path: String = 'user://test_print_look_palette.gpl'
  DirAccess.make_dir_recursive_absolute(path.get_base_dir())
  var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
  file.store_string('GIMP Palette\nName: test\n10 20 30 ui panel wear\n')
  file.close()
  DebugPanels.set_interface_palette(path)
  assert_eq(PrintLook.panel_material.get_shader_parameter('wear_dark_colour'), Color8(10, 20, 30),
    'the panel wear colour follows the palette')
  DebugPanels.set_interface_palette('')
  assert_eq(PrintLook.panel_material.get_shader_parameter('wear_dark_colour'), default_dark, 'reset restores it')
  DirAccess.remove_absolute(path)
