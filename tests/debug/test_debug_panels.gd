extends GutTest
## The [ and ] palette hotkeys step through the full-screen palette list, skipping folder headings
## and wrapping through "Off" (docs/systems/debug_panel.md).


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _option() -> OptionButton:
  return DebugPanels.get_node('PanelLayer/Panel/Rows/PaletteRow/Option') as OptionButton


func _clamp_on() -> bool:
  return (DebugPanels.get_node('ClampLayer') as CanvasLayer).visible


func test_cycle_forward_from_off_selects_a_palette() -> void:
  DebugPanels.cycle_palette(1)
  var option: OptionButton = _option()
  assert_gt(option.selected, 0, 'moved off "Off"')
  assert_false(option.is_item_separator(option.selected), 'never lands on a folder heading')
  assert_true(_clamp_on(), 'the clamp is on')


func test_cycle_back_from_off_wraps_to_the_last_palette() -> void:
  DebugPanels.cycle_palette(-1)
  var option: OptionButton = _option()
  assert_eq(option.selected, option.item_count - 1, 'wrapped to the last entry')
  assert_true(_clamp_on(), 'the clamp is on')


func test_forward_then_back_returns_to_off() -> void:
  DebugPanels.cycle_palette(1)
  DebugPanels.cycle_palette(-1)
  assert_eq(_option().selected, 0, 'back on "Off"')
  assert_false(_clamp_on(), 'the clamp is off')


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
