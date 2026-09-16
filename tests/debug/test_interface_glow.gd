extends GutTest
## `InterfaceGlow`: nodes glow through `self_modulate` above white, the screen glow is only on while
## something glows, and glow settings are saved with an interface look (docs/systems/interface_glow.md).

const LOOK_PATH: String = 'user://test_looks/interface_glow.cfg'

var _item: ColorRect = null


func before_each() -> void:
  TestCleanup.reset_all_managers()
  _item = ColorRect.new()
  add_child(_item)


func after_each() -> void:
  _item.free()
  _item = null
  DirAccess.remove_absolute(LOOK_PATH)
  DirAccess.remove_absolute(LOOK_PATH.get_base_dir())
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


func test_glow_settings_are_saved_with_the_interface_look() -> void:
  InterfaceGlow.settings['glow_intensity'] = 4.0
  assert_eq(InterfaceLook.save_look(LOOK_PATH), OK, 'saved')
  InterfaceLook.reset()
  assert_almost_eq(InterfaceGlow.setting('glow_intensity'), 1.0, 0.001, 'reset restores the default')
  assert_true(InterfaceLook.load_look(LOOK_PATH), 'loaded')
  assert_almost_eq(InterfaceGlow.setting('glow_intensity'), 4.0, 0.001, 'the glow setting is restored')
