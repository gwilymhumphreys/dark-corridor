extends GutTest
## `PrintLook`: background, panel, border and corridor overlay defaults, write and read round-trip including
## the panel section, and the panel wear colours (docs/systems/panel_wear.md, docs/systems/print_frame.md).


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
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
  var file: ConfigFile = ConfigFile.new()
  PrintLook.write_print_look(file)
  PrintLook.reset_print_look()
  assert_eq(PrintLook.panel_material.get_shader_parameter('panel_specks_on'), true, 'reset restores the default')
  PrintLook.read_print_look(file)
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


func test_the_background_is_written_and_read_on_its_own() -> void:
  PrintLook.background_material.set_shader_parameter('background_specks_on', false)
  var file: ConfigFile = ConfigFile.new()
  PrintLook.write_print_look(file)
  assert_false(file.has_section('print_background'), 'the print part does not hold the background')
  PrintLook.write_background_look(file)
  PrintLook.reset_background_look()
  assert_eq(PrintLook.background_material.get_shader_parameter('background_specks_on'), true,
    'reset restores the default')
  PrintLook.read_background_look(file)
  assert_eq(PrintLook.background_material.get_shader_parameter('background_specks_on'), false,
    'background switch restored')


func test_token_settings_are_written_onto_both_token_styles() -> void:
  PrintLook.set_print_value('token_shadow_size', 9.0)
  PrintLook.set_print_value('token_shadow_offset', 3.0)
  PrintLook.set_print_value('token_shadow_darkness', 0.25)
  var theme: Theme = ThemeDB.get_project_theme()
  for type: String in PrintLook.TOKEN_STYLES:
    var box: StyleBoxFlat = (theme.get_stylebox('panel', type) as WornStyleBox).base as StyleBoxFlat
    assert_eq(box.border_width_left, 0, '%s has no border; its edge is the worn edge' % type)
    assert_eq(box.shadow_size, 9, '%s shadow size' % type)
    assert_eq(box.shadow_offset, Vector2(3, 3), '%s shadow offset' % type)
    assert_almost_eq(box.shadow_color.a, 0.25, 0.001, '%s shadow darkness' % type)
  PrintLook.reset_print_look()
  var reset_box: StyleBoxFlat = (theme.get_stylebox('panel', 'PanelToken') as WornStyleBox).base as StyleBoxFlat
  assert_eq(reset_box.shadow_size, roundi(PrintLook.PRINT_SETTING_DEFAULTS['token_shadow_size']),
    'reset restores the shadow size')


func test_a_token_shadow_keeps_the_cell_layout() -> void:
  var theme: Theme = ThemeDB.get_project_theme()
  var before: Vector2 = theme.get_stylebox('panel', 'PanelToken').get_minimum_size()
  PrintLook.set_print_value('token_shadow_size', 20.0)
  assert_eq(theme.get_stylebox('panel', 'PanelToken').get_minimum_size(), before, 'the margins stay the same')
