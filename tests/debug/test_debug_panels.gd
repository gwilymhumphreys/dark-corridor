extends GutTest
## The [ and ] palette hotkeys step through the world palette list, skipping folder headings and
## wrapping through "Off"; ; and ' do the same for the interface palette list. The corridor and
## interface parts of a preset hold their palette choices and the font, and the function keys open the
## panel's tabs
## (docs/systems/debug_panel.md).

const INTERFACE_PALETTE: String = 'res://assets/palettes/new/ui/ui-default.gpl'


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _option() -> OptionButton:
  return DebugPanels.get_node('PanelLayer/Panel/Rows/Tabs/Corridor/PaletteRows/WorldPaletteRow/Option') as OptionButton


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


func test_replace_palette_path_updates_saved_looks() -> void:
  var folder: String = 'user://test_palette_refs'
  DirAccess.make_dir_recursive_absolute(folder)
  var look: String = folder.path_join('look.cfg')
  FileAccess.open(look, FileAccess.WRITE).store_string('[corridor_palette]
world_palette="res://old/a.gpl"
')
  DebugPanelsAutoload.replace_palette_path([folder], 'res://old/a.gpl', 'res://new/a.gpl')
  assert_eq(FileAccess.get_file_as_string(look), '[corridor_palette]
world_palette="res://new/a.gpl"
',
    'the look points at the moved palette')
  DirAccess.remove_absolute(look)
  DirAccess.remove_absolute(folder)


func test_saved_presets_only_name_files_that_exist() -> void:
  var regex: RegEx = RegEx.create_from_string('"(res://[^"]+)"')
  for folder: String in [LookPresets.PRESET_DIR, LookPresets.HISTORY_DIR]:
    if not DirAccess.dir_exists_absolute(folder):
      continue
    for file_name: String in DirAccess.get_files_at(folder):
      if file_name.get_extension() != 'cfg':
        continue
      var text: String = FileAccess.get_file_as_string(folder.path_join(file_name))
      for found: RegExMatch in regex.search_all(text):
        assert_true(FileAccess.file_exists(found.get_string(1)), '%s names %s' % [file_name, found.get_string(1)])


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


func test_portrait_palette_same_as_corridor_follows_the_world_palette() -> void:
  DebugPanels.set_portrait_palette(DebugPanelsAutoload.PORTRAIT_SAME_AS_CORRIDOR)
  DebugPanels.set_world_palette(INTERFACE_PALETTE)
  assert_gt(InterfaceLook.material.get_shader_parameter('colour_count'), 0,
    'the interface images clamp to the world palette')
  DebugPanels.set_world_palette('')
  assert_eq(InterfaceLook.material.get_shader_parameter('colour_count'), 0,
    'the clamp is off when the world palette is off')


func test_portrait_palette_keys_step_away_from_the_default() -> void:
  DebugPanels.cycle_portrait_palette(1)
  assert_ne(DebugPanels.portrait_palette, DebugPanelsAutoload.PORTRAIT_SAME_AS_INTERFACE,
    'stepped off the default')
  DebugPanels.cycle_portrait_palette(-1)
  assert_eq(DebugPanels.portrait_palette, DebugPanelsAutoload.PORTRAIT_SAME_AS_INTERFACE,
    'back on the default')


func test_the_palette_sections_restore_the_same_choices() -> void:
  DebugPanels.set_world_palette(INTERFACE_PALETTE)
  DebugPanels.set_interface_palette(INTERFACE_PALETTE)
  DebugPanels.set_portrait_palette(DebugPanelsAutoload.PORTRAIT_SAME_AS_CORRIDOR)
  DebugPanels.set_dithering(true)
  var file: ConfigFile = ConfigFile.new()
  DebugPanels.write_corridor_palette(file)
  DebugPanels.write_interface_palettes(file)
  DebugPanels.reset_settings()
  DebugPanels.read_corridor_palette(file)
  DebugPanels.read_interface_palettes(file)
  assert_eq(DebugPanels.world_palette, INTERFACE_PALETTE, 'world palette restored')
  assert_eq(DebugPanels.interface_palette, INTERFACE_PALETTE, 'interface palette restored')
  assert_eq(DebugPanels.portrait_palette, DebugPanelsAutoload.PORTRAIT_SAME_AS_CORRIDOR,
    'portrait palette restored')
  assert_true(DebugPanels.is_dithering(), 'dithering restored')


func test_a_tab_key_opens_its_tab_switches_tabs_and_closes_its_own_tab() -> void:
  var tabs: TabContainer = DebugPanels.get_node('PanelLayer/Panel/Rows/Tabs') as TabContainer
  watch_signals(DebugPanels)
  DebugPanels.toggle_tab(LookPresets.Part.PRINT)
  assert_signal_emitted_with_parameters(DebugPanels, 'panels_open_changed', [true])
  assert_eq(tabs.current_tab, LookPresets.Part.PRINT, 'opens on the print tab')
  DebugPanels.toggle_tab(LookPresets.Part.INTERFACE)
  assert_true(DebugPanels.is_panel_open(), 'another tab key switches tabs instead of closing')
  assert_eq(tabs.current_tab, LookPresets.Part.INTERFACE, 'now on the interface tab')
  assert_signal_emit_count(DebugPanels, 'panels_open_changed', 1, 'switching tabs does not emit')
  DebugPanels.toggle_tab(LookPresets.Part.INTERFACE)
  assert_signal_emit_count(DebugPanels, 'panels_open_changed', 2)
  assert_signal_emitted_with_parameters(DebugPanels, 'panels_open_changed', [false])
  assert_false(DebugPanels.is_panel_open(), 'the key for the tab showing closes the panel')
