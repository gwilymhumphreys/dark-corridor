extends GutTest
## `LookPresets`: saving and loading the whole look or one part of it, the default preset and the
## history of past defaults, and noticing changes (docs/systems/look_presets.md).

const FOLDER: String = 'user://test_presets'
const HISTORY: String = 'user://test_presets/history'
const WORLD_PALETTE: String = 'res://assets/palettes/new/ui/ui-default.gpl'


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for folder: String in [HISTORY, FOLDER]:
    if DirAccess.dir_exists_absolute(folder):
      for file_name: String in DirAccess.get_files_at(folder):
        DirAccess.remove_absolute(folder.path_join(file_name))
      DirAccess.remove_absolute(folder)
  TestCleanup.reset_all_managers()


# One change in each part of the look.
func _change_every_part() -> void:
  DebugPanels.set_world_palette(WORLD_PALETTE)
  DebugPanels.world_material.set_shader_parameter('grade_on', true)
  InterfaceLook.material.set_shader_parameter('halftone_on', true)
  PrintLook.set_print_value('print_border_on', true)
  PrintLook.background_material.set_shader_parameter('background_specks_on', false)


func test_a_saved_preset_restores_every_part() -> void:
  _change_every_part()
  var path: String = LookPresets.preset_path('every_part', FOLDER)
  assert_eq(LookPresets.save_preset(path), OK, 'saved')
  DebugPanels.reset_settings()
  assert_true(LookPresets.load_preset(path), 'loaded')
  assert_eq(DebugPanels.world_palette, WORLD_PALETTE, 'the corridor palette restored')
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_on'), true, 'corridor part restored')
  assert_eq(InterfaceLook.material.get_shader_parameter('halftone_on'), true, 'interface part restored')
  assert_eq(PrintLook.border_material.get_shader_parameter('print_border_on'), true, 'print part restored')
  assert_eq(PrintLook.background_material.get_shader_parameter('background_specks_on'), false, 'background part restored')


func test_loading_one_part_leaves_the_others_alone() -> void:
  _change_every_part()
  var path: String = LookPresets.preset_path('every_part', FOLDER)
  LookPresets.save_preset(path)
  DebugPanels.reset_settings()
  DebugPanels.world_material.set_shader_parameter('vignette_on', true)
  var parts: Array[LookPresets.Part] = [LookPresets.Part.PRINT]
  assert_true(LookPresets.load_preset(path, parts), 'loaded')
  assert_eq(PrintLook.border_material.get_shader_parameter('print_border_on'), true, 'the print part is loaded')
  assert_eq(DebugPanels.world_palette, '', 'the corridor palette is not loaded')
  assert_eq(DebugPanels.world_material.get_shader_parameter('vignette_on'), true, 'the corridor part is unchanged')


func test_an_empty_preset_turns_one_part_off() -> void:
  _change_every_part()
  var parts: Array[LookPresets.Part] = [LookPresets.Part.INTERFACE]
  LookPresets.apply(ConfigFile.new(), parts)
  assert_eq(InterfaceLook.material.get_shader_parameter('halftone_on'), false, 'the interface part is off')
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_on'), true, 'the corridor part is unchanged')


func test_matches_notices_a_change() -> void:
  var path: String = LookPresets.preset_path('check', FOLDER)
  LookPresets.save_preset(path)
  assert_true(LookPresets.matches(path), 'the look matches the preset just saved')
  DebugPanels.world_material.set_shader_parameter('grade_contrast', 1.9)
  assert_false(LookPresets.matches(path), 'a changed setting no longer matches')
  assert_false(LookPresets.matches(LookPresets.preset_path('missing', FOLDER)), 'a missing preset never matches')


func test_make_default_keeps_the_old_default_in_the_history() -> void:
  assert_eq(LookPresets.make_default('first', FOLDER, HISTORY), '', 'no history file when there was no default')
  DebugPanels.world_material.set_shader_parameter('grade_on', true)
  var history_path: String = LookPresets.make_default('second', FOLDER, HISTORY)
  assert_true(FileAccess.file_exists(history_path), 'the old default is in the history')
  assert_true(history_path.get_file().ends_with('_first.cfg'), 'named after the preset it was made from')
  DebugPanels.reset_settings()
  assert_true(LookPresets.load_default(FOLDER), 'the new default loads')
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_on'), true, 'the new default holds the look')
  assert_true(LookPresets.load_preset(history_path), 'the history file loads')
  assert_eq(DebugPanels.world_material.get_shader_parameter('grade_on'), false, 'the history file holds the old look')


func test_lists_put_the_default_first_and_the_newest_history_first() -> void:
  LookPresets.save_preset(LookPresets.preset_path('b', FOLDER))
  LookPresets.save_preset(LookPresets.preset_path('a', FOLDER))
  LookPresets.save_preset(LookPresets.preset_path(LookPresets.DEFAULT_NAME, FOLDER))
  assert_eq(LookPresets.preset_names(FOLDER), PackedStringArray(['default', 'a', 'b']), 'default, then by name')
  LookPresets.save_preset(LookPresets.preset_path('2026-09-10_0900_old', HISTORY))
  LookPresets.save_preset(LookPresets.preset_path('2026-09-17_1432_new', HISTORY))
  assert_eq(LookPresets.history_names(HISTORY), PackedStringArray(['2026-09-17_1432_new', '2026-09-10_0900_old']),
    'newest first')
  assert_eq(PresetBar.history_label('2026-09-17_1432_candlelit'), '2026-09-17 14:32  candlelit', 'readable label')


func test_delete_removes_a_preset_but_not_the_default() -> void:
  var path: String = LookPresets.preset_path('old', FOLDER)
  LookPresets.save_preset(path)
  assert_eq(LookPresets.delete_preset(path), OK, 'deleted')
  assert_false(FileAccess.file_exists(path), 'the file is gone')
  assert_eq(LookPresets.delete_preset(LookPresets.preset_path(LookPresets.DEFAULT_NAME)), ERR_UNAUTHORIZED,
    'the default preset is refused')
  assert_true(FileAccess.file_exists(LookPresets.preset_path(LookPresets.DEFAULT_NAME)), 'the default is still there')


func test_a_missing_preset_is_refused() -> void:
  assert_false(LookPresets.load_preset(LookPresets.preset_path('missing', FOLDER)), 'a missing file is refused')
  assert_false(LookPresets.load_default(FOLDER), 'no default in an empty folder')


func test_the_project_has_a_default_preset() -> void:
  assert_true(FileAccess.file_exists(LookPresets.preset_path(LookPresets.DEFAULT_NAME)),
    'the game starts from assets/presets/default.cfg')


func test_the_corridor_part_holds_the_world_palette() -> void:
  _change_every_part()
  var path: String = LookPresets.preset_path('every_part', FOLDER)
  LookPresets.save_preset(path)
  DebugPanels.reset_settings()
  var parts: Array[LookPresets.Part] = [LookPresets.Part.CORRIDOR]
  assert_true(LookPresets.load_preset(path, parts), 'loaded')
  assert_eq(DebugPanels.world_palette, WORLD_PALETTE, 'the world palette comes with the corridor part')


func test_the_background_part_loads_on_its_own() -> void:
  _change_every_part()
  var path: String = LookPresets.preset_path('every_part', FOLDER)
  LookPresets.save_preset(path)
  DebugPanels.reset_settings()
  var parts: Array[LookPresets.Part] = [LookPresets.Part.BACKGROUND]
  assert_true(LookPresets.load_preset(path, parts), 'loaded')
  assert_eq(PrintLook.background_material.get_shader_parameter('background_specks_on'), false, 'the background part is loaded')
  assert_eq(PrintLook.border_material.get_shader_parameter('print_border_on'), false, 'the print part is not loaded')
