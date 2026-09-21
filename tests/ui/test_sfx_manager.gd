extends GutTest
## SfxManager's bus mapping: the first path segment of a sound's folder picks its bus, and an
## unrecognised category falls back to the interface bus. bus_for is pure string work, so these
## run under the headless dummy driver where nothing plays.


# Folders made by _write_volume, removed in after_each so a run leaves nothing behind.
var _temp_volume_folders: Array[String] = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for dir_path: String in _temp_volume_folders:
    DirAccess.remove_absolute(dir_path + '/' + SfxManagerAutoload.VOLUME_FILE)
    DirAccess.remove_absolute(dir_path)
  _temp_volume_folders.clear()
  SfxManager._volumes.clear()
  TestCleanup.reset_all_managers()


func test_interface_categories_use_the_interface_bus() -> void:
  assert_eq(SfxManager.bus_for('ui/hover'), SfxManagerAutoload.BUS_INTERFACE, 'ui sounds stay dry on the Interface bus')
  assert_eq(SfxManager.bus_for('run/victory'), SfxManagerAutoload.BUS_INTERFACE, 'run events stay dry on the Interface bus')


func test_nested_path_uses_its_first_segment() -> void:
  assert_eq(SfxManager.bus_for('world/footsteps/steps'), SfxManagerAutoload.BUS_WORLD, 'a nested world path still uses World')


func test_world_categories_use_the_world_bus() -> void:
  assert_eq(SfxManager.bus_for('mechanics/attack'), SfxManagerAutoload.BUS_WORLD, 'mechanic sounds carry the corridor reverb')
  assert_eq(SfxManager.bus_for('statuses/poison'), SfxManagerAutoload.BUS_WORLD, 'status sounds carry the corridor reverb')
  assert_eq(SfxManager.bus_for('combat/death'), SfxManagerAutoload.BUS_WORLD, 'combat sounds carry the corridor reverb')


func test_unrecognised_category_uses_the_interface_bus() -> void:
  assert_eq(SfxManager.bus_for('nonsense/thing'), SfxManagerAutoload.BUS_INTERFACE, 'an unknown category falls back to Interface')


## _bank_for rather than play_sound: these runs are headless, so play_sound returns -1 before
## it looks at the folder at all and would pass whatever the loading did.
func test_missing_folder_loads_an_empty_bank() -> void:
  assert_true(SfxManager._bank_for('mechanics/does_not_exist').is_empty(),
      'a folder that does not exist gives no recordings')


func test_an_existing_folder_loads_its_recordings() -> void:
  assert_false(SfxManager._bank_for('ui/click').is_empty(),
      'the click folder loads the recordings in it')


func test_shielded_attack_folder_loads_its_recordings() -> void:
  assert_false(SfxManager._bank_for('mechanics/attack/shielded').is_empty(),
      'the shielded attack folder loads the recordings in it')


func test_missing_variant_folder_loads_an_empty_bank() -> void:
  assert_true(SfxManager._bank_for('mechanics/attack/nonexistent').is_empty(),
      'a variant folder that does not exist gives no recordings')


func test_play_sound_ignores_an_empty_path() -> void:
  assert_eq(SfxManager.play_sound(''), -1, 'an empty path plays nothing')


func test_a_folder_without_a_volume_file_adjusts_by_nothing() -> void:
  assert_eq(SfxManager._volume_for('mechanics/attack'), 0.0,
      'a folder with no volume file plays at the level it was recorded')


func test_a_folder_with_a_volume_file_reads_it() -> void:
  assert_eq(SfxManager._volume_for('mechanics/shield'), -4.5,
      'the shield folder reads its volume file')


func test_an_out_of_range_volume_is_clamped() -> void:
  var written: bool = _write_volume('_volume_test_high', '99')
  assert_true(written, 'the test volume folder could be written')
  assert_eq(SfxManager._volume_for('mechanics/_volume_test_high'), SfxManagerAutoload.VOLUME_MAX_DB,
      'a value above the range is clamped to the maximum')


func test_an_unreadable_volume_adjusts_by_nothing() -> void:
  var written: bool = _write_volume('_volume_test_bad', 'loud please')
  assert_true(written, 'the test volume folder could be written')
  assert_eq(SfxManager._volume_for('mechanics/_volume_test_bad'), 0.0,
      'a value that is not a number is ignored')


func test_an_empty_variant_falls_back_past_more_than_one_parent() -> void:
  assert_eq(SfxManager._resolve_folder('mechanics/attack/nonexistent/alsonot'), 'mechanics/attack',
      'an empty variant walks up its parents to the nearest folder with recordings')


func test_an_unknown_mechanic_falls_back_to_the_category_default() -> void:
  assert_eq(SfxManager._resolve_folder('mechanics/does_not_exist'), '',
      'nothing plays when neither the folder nor a category default has recordings')


## Write `text` into a throwaway folder under mechanics/ and return whether it worked. The
## folder is removed in after_each.
func _write_volume(folder: String, text: String) -> bool:
  var dir_path: String = SfxManagerAutoload.SOUND_ROOT + 'mechanics/' + folder
  if DirAccess.make_dir_recursive_absolute(dir_path) != OK:
    return false
  _temp_volume_folders.append(dir_path)
  var file: FileAccess = FileAccess.open(dir_path + '/' + SfxManagerAutoload.VOLUME_FILE,
      FileAccess.WRITE)
  if file == null:
    return false
  file.store_string(text)
  file.close()
  return true


func test_a_layer_that_does_not_fall_back_stays_silent() -> void:
  assert_eq(SfxManager._resolve_folder('mechanics/attack/nothing_here', false), '',
      'an unfilled optional layer plays nothing rather than its parent')


func test_the_same_folder_falls_back_when_allowed() -> void:
  assert_eq(SfxManager._resolve_folder('mechanics/attack/nothing_here'), 'mechanics/attack',
      'the same folder still walks up when fallback is allowed')


func test_a_filled_layer_resolves_to_itself() -> void:
  assert_eq(SfxManager._resolve_folder('mechanics/attack/travel', false), 'mechanics/attack/travel',
      'a layer with recordings plays its own folder')
