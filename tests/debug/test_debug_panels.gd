extends GutTest
## The [ and ] palette hotkeys step through the main palette list, skipping folder headings and
## wrapping through "Off"; ; and ' do the same for the mechanic palette list. The colours part of a
## preset holds the palette choices, and the function keys open the panel's tabs
## (docs/systems/debug_panel.md).

const MAIN_PALETTE: String = 'res://assets/palettes/shortlist/2bit-demichrome.gpl'
const MECHANIC_PALETTE: String = 'res://assets/palettes/mechanics/mechanics-greys.gpl'


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _option() -> OptionButton:
  return DebugPanels.get_node('PanelLayer/Panel/Rows/Tabs/Colours/PaletteRows/MainPaletteRow/Option') as OptionButton


func _clamp_on() -> bool:
  return DebugPanels.main_palette != ''


func test_cycle_forward_from_off_selects_a_palette() -> void:
  DebugPanels.cycle_palette(1)
  var option: OptionButton = _option()
  assert_gt(option.selected, 0, 'moved off "Off"')
  assert_false(option.is_item_separator(option.selected), 'never lands on a folder heading')
  assert_true(_clamp_on(), 'the main palette is on')


func test_cycle_back_from_off_wraps_to_the_last_palette() -> void:
  DebugPanels.cycle_palette(-1)
  var option: OptionButton = _option()
  assert_eq(option.selected, option.item_count - 1, 'wrapped to the last entry')
  assert_true(_clamp_on(), 'the main palette is on')


func test_forward_then_back_returns_to_off() -> void:
  DebugPanels.cycle_palette(1)
  DebugPanels.cycle_palette(-1)
  assert_eq(_option().selected, 0, 'back on "Off"')
  assert_false(_clamp_on(), 'the main palette is off')


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


func test_mechanic_palette_keys_step_and_wrap_through_the_default() -> void:
  DebugPanels.cycle_mechanic_palette(1)
  assert_ne(DebugPanels.mechanic_palette, '', 'a mechanic palette is applied')
  DebugPanels.cycle_mechanic_palette(-1)
  assert_eq(DebugPanels.mechanic_palette, '', 'back on "Default"')


func test_the_main_palette_reaches_the_corridor_pictures_and_effects_by_their_switches() -> void:
  DebugPanels.set_main_palette(MAIN_PALETTE)
  assert_eq(DebugPanels.world_material.get_shader_parameter('colour_count'), 4, 'the corridor takes the four colours')
  assert_eq(InterfaceLook.material.get_shader_parameter('colour_count'), 4, 'the pictures take them too')
  assert_gt(InterfaceLook.effects_material.get_shader_parameter('colour_count'), 4,
    'the effects take them with the mechanic colours')
  DebugPanels.set_palette_setting('snap_pictures', false)
  assert_eq(InterfaceLook.material.get_shader_parameter('colour_count'), 0, 'the pictures switch turns their snapping off')
  assert_eq(DebugPanels.world_material.get_shader_parameter('colour_count'), 4, 'the corridor is left alone')
  DebugPanels.set_main_palette('')
  assert_eq(DebugPanels.world_material.get_shader_parameter('colour_count'), 0, 'no main palette, no snapping')
  assert_eq(InterfaceLook.effects_material.get_shader_parameter('colour_count'), 0, 'the effects are not snapped either')


func test_the_darkest_colour_is_added_to_the_snapped_colours() -> void:
  DebugPanels.set_main_palette(MAIN_PALETTE)
  DebugPanels.set_palette_setting('darkest_colour', Color.BLACK)
  DebugPanels.set_palette_setting('darkest', 'add')
  assert_eq(DebugPanels.world_material.get_shader_parameter('colour_count'), 5, 'one colour more')
  assert_eq(Colours.UI_PANEL_SHADOW, Color.BLACK, 'the darkest interface colour takes it')
  DebugPanels.set_palette_setting('darkest', MainPalette.Darkest.REPLACE)
  assert_eq(DebugPanels.world_material.get_shader_parameter('colour_count'), 4, 'swapped in for the darkest')


func test_the_palette_sections_restore_the_same_choices() -> void:
  DebugPanels.set_main_palette(MAIN_PALETTE)
  DebugPanels.set_mechanic_palette(MECHANIC_PALETTE)
  DebugPanels.set_palette_setting('darkest', MainPalette.Darkest.ADD)
  DebugPanels.set_palette_setting('darkest_colour', Color8(1, 2, 3))
  DebugPanels.set_palette_setting('snap_effects', false)
  DebugPanels.set_palette_setting('ui_background', 0.5)
  DebugPanels.set_dithering(true)
  DebugPanels.set_interface_dithering(true)
  var file: ConfigFile = ConfigFile.new()
  DebugPanels.write_palettes(file)
  DebugPanels.reset_settings()
  assert_eq(DebugPanels.main_palette, '', 'reset turns the main palette off')
  DebugPanels.read_palettes(file)
  assert_eq(DebugPanels.main_palette, MAIN_PALETTE, 'main palette restored')
  assert_eq(DebugPanels.mechanic_palette, MECHANIC_PALETTE, 'mechanic palette restored')
  assert_eq(DebugPanels.darkest, MainPalette.Darkest.ADD, 'darkest setting restored')
  assert_eq(DebugPanels.darkest_colour, Color8(1, 2, 3), 'darker colour restored')
  assert_false(DebugPanels.snap_effects, 'snap switch restored')
  assert_almost_eq(MainPalette.brightness('UI_BACKGROUND'), 0.5, 0.001, 'brightness restored')
  assert_true(DebugPanels.is_dithering(), 'corridor dithering restored')
  assert_true(DebugPanels.is_interface_dithering(), 'interface dithering restored')


func test_a_tab_key_opens_its_tab_switches_tabs_and_closes_its_own_tab() -> void:
  var tabs: TabContainer = DebugPanels.get_node('PanelLayer/Panel/Rows/Tabs') as TabContainer
  watch_signals(DebugPanels)
  DebugPanels.toggle_tab(DebugPanelsAutoload.Tab.WEAR)
  assert_signal_emitted_with_parameters(DebugPanels, 'panels_open_changed', [true])
  assert_eq(tabs.current_tab, DebugPanelsAutoload.Tab.WEAR, 'opens on the wear tab')
  DebugPanels.toggle_tab(DebugPanelsAutoload.Tab.PICTURES)
  assert_true(DebugPanels.is_panel_open(), 'another tab key switches tabs instead of closing')
  assert_eq(tabs.current_tab, DebugPanelsAutoload.Tab.PICTURES, 'now on the pictures tab')
  assert_signal_emit_count(DebugPanels, 'panels_open_changed', 1, 'switching tabs does not emit')
  DebugPanels.toggle_tab(DebugPanelsAutoload.Tab.PICTURES)
  assert_signal_emit_count(DebugPanels, 'panels_open_changed', 2)
  assert_signal_emitted_with_parameters(DebugPanels, 'panels_open_changed', [false])
  assert_false(DebugPanels.is_panel_open(), 'the key for the tab showing closes the panel')


func test_every_tab_but_icons_is_the_preset_part_of_the_same_position() -> void:
  var tabs: TabContainer = DebugPanels.get_node('PanelLayer/Panel/Rows/Tabs') as TabContainer
  for part: LookPresets.Part in LookPresets.ALL_PARTS:
    var row: PresetPartRow = tabs.get_child(part).get_node_or_null('PartRow') as PresetPartRow
    assert_not_null(row, 'tab %d has a preset row' % part)
    if row != null:
      assert_eq(row.part, part, 'tab %d loads its own part' % part)
  assert_null(tabs.get_child(DebugPanelsAutoload.Tab.ICONS).get_node_or_null('PartRow'), 'the Icons tab is not a part')
