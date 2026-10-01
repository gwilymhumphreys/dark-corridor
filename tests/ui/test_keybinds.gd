extends GutTest
## Keybinds: the rebindable actions, their two slots, storage through Prefs (kept off disk by
## TestCleanup) and what reaches InputMap.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _keys_in_map(action: String) -> Array[int]:
  var keys: Array[int] = []
  for event in InputMap.action_get_events(action):
    var key: InputEventKey = event as InputEventKey
    if key != null:
      keys.append(key.physical_keycode)
  return keys


func test_every_listed_action_is_in_the_project() -> void:
  for entry in Keybinds.ACTIONS:
    assert_true(InputMap.has_action(entry['action']), '%s is in project.godot' % entry['action'])


func test_defaults_come_from_the_project() -> void:
  assert_eq(Keybinds.slots('battle_speed_down'), [Keybinds.key_slot(KEY_BRACKETLEFT), {}], '[ is the main key')
  assert_eq(Keybinds.slots('battle_speed_up'), [Keybinds.key_slot(KEY_BRACKETRIGHT), {}], '] is the main key')
  Keybinds.apply_all()
  assert_eq(_keys_in_map('battle_speed_up'), [KEY_BRACKETRIGHT as int], 'apply_all puts the default in InputMap')


func test_bind_stores_and_applies() -> void:
  var taken_from: String = Keybinds.bind('battle_speed_up', 1, KEY_EQUAL)
  assert_eq(taken_from, '', 'no other action had the key')
  assert_eq(Keybinds.slots('battle_speed_up'), [Keybinds.key_slot(KEY_BRACKETRIGHT), Keybinds.key_slot(KEY_EQUAL)])
  assert_eq(_keys_in_map('battle_speed_up'), [KEY_BRACKETRIGHT as int, KEY_EQUAL as int], 'both keys reach InputMap')
  assert_not_null(Prefs.keybind_slots('battle_speed_up'), 'the change is stored')
  assert_null(Prefs.keybind_slots('battle_speed_down'), 'an unchanged action stores nothing')


func test_a_key_taken_from_another_action_empties_its_slot() -> void:
  var taken_from: String = Keybinds.bind('battle_speed_up', 0, KEY_BRACKETLEFT)
  assert_eq(taken_from, 'battle_speed_down', 'names the action that lost the key')
  assert_eq(Keybinds.slots('battle_speed_down'), [{}, {}], 'that slot is now empty')
  assert_eq(_keys_in_map('battle_speed_down'), [] as Array[int], 'and its key is gone from InputMap')


func test_moving_a_key_between_own_slots_does_not_duplicate_it() -> void:
  Keybinds.bind('battle_speed_up', 1, KEY_BRACKETRIGHT)
  assert_eq(Keybinds.slots('battle_speed_up'), [{}, Keybinds.key_slot(KEY_BRACKETRIGHT)], 'the key moved to the spare slot')


func test_reserved_keys_are_refused() -> void:
  assert_true(Keybinds.is_reserved(KEY_ESCAPE), 'Escape is reserved')
  assert_true(Keybinds.is_reserved(KEY_F7), 'the F keys are reserved')
  Keybinds.bind('battle_speed_up', 0, KEY_ESCAPE)
  assert_eq(Keybinds.slots('battle_speed_up'), [Keybinds.key_slot(KEY_BRACKETRIGHT), {}], 'nothing changed')


func test_clear_and_reset_all() -> void:
  Keybinds.clear('battle_speed_up', 0)
  assert_eq(Keybinds.slots('battle_speed_up'), [{}, {}], 'the main slot is empty')
  assert_eq(_keys_in_map('battle_speed_up'), [] as Array[int])
  Keybinds.reset_all()
  assert_eq(Keybinds.slots('battle_speed_up'), [Keybinds.key_slot(KEY_BRACKETRIGHT), {}], 'back on the default')
  assert_eq(_keys_in_map('battle_speed_up'), [KEY_BRACKETRIGHT as int])


func test_an_empty_main_slot_keeps_the_spare_in_place() -> void:
  Keybinds.bind('battle_speed_up', 1, KEY_EQUAL)
  Keybinds.clear('battle_speed_up', 0)
  assert_eq(Keybinds.slots('battle_speed_up'), [{}, Keybinds.key_slot(KEY_EQUAL)], 'the spare stays in slot 1')


func test_badly_formed_stored_slots_are_ignored() -> void:
  Prefs.set_keybind_slots('battle_speed_up', ['nonsense', {'kind': 'key'}, {'kind': 'key', 'physical_keycode': KEY_EQUAL}])
  assert_eq(Keybinds.slots('battle_speed_up'), [{}, {}], 'bad entries become empty slots, extras are dropped')
  Prefs.set_keybind_slots('not_an_action', [Keybinds.key_slot(KEY_EQUAL)])
  Keybinds.apply_all()
  assert_false(InputMap.has_action('not_an_action'), 'an unknown stored action is not added')


func test_unlisted_actions_cannot_be_bound() -> void:
  assert_eq(Keybinds.bind('ui_cancel', 0, KEY_Q), '', 'a built-in action is not listed')
  assert_null(Prefs.keybind_slots('ui_cancel'), 'and nothing is stored')


func test_printable_keys_show_their_character() -> void:
  assert_eq(Keybinds.slot_label(Keybinds.key_slot(KEY_BRACKETLEFT)), '[')
  assert_eq(Keybinds.slot_label(Keybinds.key_slot(KEY_SPACE)), 'Space')
  assert_eq(Keybinds.slot_label({}), '', 'an empty slot has no label')
