extends GutTest
## `InterfaceGlow`: nodes glow through `self_modulate` above white, the screen glow is only on while
## something glows, and glow settings are saved with the interface look part of a preset
## (docs/systems/interface_glow.md).


var _item: ColorRect = null


func before_each() -> void:
  TestCleanup.reset_all_managers()
  _item = ColorRect.new()
  add_child(_item)


func after_each() -> void:
  _item.free()
  _item = null
  TestCleanup.reset_all_managers()


func test_glow_is_off_while_nothing_glows() -> void:
  assert_false(InterfaceGlow.is_enabled(), 'the screen glow is off by default')


func test_set_glow_brightens_the_item_and_turns_the_glow_on() -> void:
  InterfaceGlow.set_glow(_item, 3.0)
  assert_eq(_item.self_modulate, Color(3.0, 3.0, 3.0), 'the item is brighter than white')
  assert_true(InterfaceGlow.is_enabled(), 'the screen glow is on')
  InterfaceGlow.set_glow(_item, 1.0)
  assert_eq(_item.self_modulate, Color.WHITE, 'the item is back to normal')
  assert_false(InterfaceGlow.is_enabled(), 'the screen glow is off again')


func test_flash_turns_the_glow_on_until_it_finishes() -> void:
  InterfaceGlow.flash(_item, 2.0, 0.1)
  assert_true(InterfaceGlow.is_enabled(), 'the screen glow is on during the flash')
  await wait_seconds(0.3)
  assert_eq(_item.self_modulate, Color.WHITE, 'the item is back to normal')
  assert_false(InterfaceGlow.is_enabled(), 'the screen glow is off after the flash')


func test_a_freed_item_stops_counting_as_glowing() -> void:
  var other: ColorRect = ColorRect.new()
  add_child(other)
  InterfaceGlow.set_glow(other, 3.0)
  other.free()
  InterfaceGlow.set_glow(_item, 1.0)
  assert_false(InterfaceGlow.is_enabled(), 'the freed item no longer keeps the glow on')


func test_an_item_freed_mid_flash_turns_the_glow_off() -> void:
  var other: ColorRect = ColorRect.new()
  add_child(other)
  InterfaceGlow.flash(other, 2.0, 1.0)
  other.free()
  await wait_process_frames(2)
  assert_false(InterfaceGlow.is_enabled(), 'the glow does not stay on for a freed item')


func test_glow_settings_are_saved_with_the_interface_look_part() -> void:
  InterfaceGlow.settings['glow_intensity'] = 4.0
  var file: ConfigFile = ConfigFile.new()
  InterfaceLook.write_look(file)
  InterfaceLook.reset()
  assert_almost_eq(InterfaceGlow.setting('glow_intensity'), 1.0, 0.001, 'reset restores the default')
  InterfaceLook.read_look(file)
  assert_almost_eq(InterfaceGlow.setting('glow_intensity'), 4.0, 0.001, 'the glow setting is restored')
