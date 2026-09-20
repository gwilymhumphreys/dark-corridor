extends GutTest
## SfxManager's bus mapping: the first path segment of a sound's folder picks its bus, and an
## unrecognised category falls back to the interface bus. bus_for is pure string work, so these
## run under the headless dummy driver where nothing plays.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
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
