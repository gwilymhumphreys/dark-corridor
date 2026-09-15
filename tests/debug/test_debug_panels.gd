extends GutTest
## The [ and ] palette hotkeys step through the world palette list, skipping folder headings and
## wrapping through "Off"; ; and ' do the same for the interface palette list. Palette combos save and
## load the palette choices (docs/systems/debug_panel.md).

const COMBO_DIR: String = 'user://test_palette_combos'
const INTERFACE_PALETTE: String = 'res://assets/palettes/new/ui/ui-default.gpl'


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _option() -> OptionButton:
  return DebugPanels.get_node('PanelLayer/Panel/Rows/WorldPaletteRow/Option') as OptionButton


func _clamp_on() -> bool:
  return DebugPanels.world_palette != ''


func test_cycle_forward_from_off_selects_a_palette() -> void:
  DebugPanels.cycle_palette(1)
  var option: OptionButton = _option()
  assert_gt(option.selected, 0, 'moved off "Off"')
  assert_false(option.is_item_separator(option.selected), 'never lands on a folder heading')
  assert_true(_clamp_on(), 'the world clamp is on')


func test_cycle_back_from_off_wraps_to_the_last_palette() -> void:
  DebugPanels.cycle_palette(-1)
  var option: OptionButton = _option()
  assert_eq(option.selected, option.item_count - 1, 'wrapped to the last entry')
  assert_true(_clamp_on(), 'the world clamp is on')


func test_forward_then_back_returns_to_off() -> void:
  DebugPanels.cycle_palette(1)
  DebugPanels.cycle_palette(-1)
  assert_eq(_option().selected, 0, 'back on "Off"')
  assert_false(_clamp_on(), 'the world clamp is off')


func test_move_palette_file_moves_the_file_and_its_import_file() -> void:
  var source_dir: String = 'user://test_palettes/source'
  var target_dir: String = 'user://test_palettes/shortlist'
  DirAccess.make_dir_recursive_absolute(source_dir)
  FileAccess.open(source_dir.path_join('a.png'), FileAccess.WRITE).store_string('x')
  FileAccess.open(source_dir.path_join('a.png.import'), FileAccess.WRITE).store_string('x')
  var new_path: String = DebugPanelsAutoload.move_palette_file(source_dir.path_join('a.png'), target_dir)
  assert_eq(new_path, target_dir.path_join('a.png'), 'returns the new path')
  assert_true(FileAccess.file_exists(new_path), 'the palette is in the target folder')
  assert_true(FileAccess.file_exists(new_path + '.import'), 'the .import file moved with it')
  assert_false(FileAccess.file_exists(source_dir.path_join('a.png')), 'the palette left its old folder')
  FileAccess.open(source_dir.path_join('a.png'), FileAccess.WRITE).store_string('x')
  assert_eq(DebugPanelsAutoload.move_palette_file(source_dir.path_join('a.png'), target_dir), '',
    'refuses to overwrite a palette of the same name')
  for file: String in [source_dir.path_join('a.png'), new_path, new_path + '.import']:
    DirAccess.remove_absolute(file)
  for dir: String in [source_dir, target_dir, 'user://test_palettes']:
    DirAccess.remove_absolute(dir)


func test_every_step_skips_folder_headings() -> void:
  var option: OptionButton = _option()
  DebugPanels.cycle_palette(1)
  for i in option.item_count:
    assert_false(option.is_item_separator(option.selected), 'step %d is not a folder heading' % i)
    DebugPanels.cycle_palette(1)


func test_interface_palette_keys_step_and_wrap_through_off() -> void:
  DebugPanels.cycle_interface_palette(1)
  assert_ne(DebugPanels.interface_palette, '', 'an interface palette is applied')
  DebugPanels.cycle_interface_palette(-1)
  assert_eq(DebugPanels.interface_palette, '', 'back on "Off"')


func test_a_saved_palette_combo_loads_the_same_choices() -> void:
  var path: String = COMBO_DIR.path_join('combo.cfg')
  DebugPanels.set_world_palette(INTERFACE_PALETTE)
  DebugPanels.set_interface_palette(INTERFACE_PALETTE)
  DebugPanels.set_dithering(true)
  assert_eq(DebugPanels.save_palette_combo(path), OK, 'saved')
  DebugPanels.reset_settings()
  assert_true(DebugPanels.load_palette_combo(path), 'loaded')
  assert_eq(DebugPanels.world_palette, INTERFACE_PALETTE, 'world palette restored')
  assert_eq(DebugPanels.interface_palette, INTERFACE_PALETTE, 'interface palette restored')
  assert_true(DebugPanels.is_dithering(), 'dithering restored')
  DirAccess.remove_absolute(path)
  DirAccess.remove_absolute(COMBO_DIR)


func test_start_up_combo_is_skipped_for_tests_screenshots_and_palette_arguments() -> void:
  assert_true(DebugPanelsAutoload.start_up_combo_allowed(PackedStringArray(['--autostart']), false), 'a normal run')
  assert_false(DebugPanelsAutoload.start_up_combo_allowed(PackedStringArray(), true), 'headless')
  assert_false(DebugPanelsAutoload.start_up_combo_allowed(PackedStringArray(['--shot']), false), 'screenshot')
  assert_false(DebugPanelsAutoload.start_up_combo_allowed(PackedStringArray(['--ui-palette=x.gpl']), false),
    'a palette argument')
