extends GutTest
## The settings screen: the volume sliders (0..1 → 0..100), the text size slider (a scale → a
## percentage) and the fullscreen + mute-when-unfocused toggles — each seeded from Prefs and writing
## back on change (Prefs applies + persists); Close emits `closed`. Presentation reads/writes Prefs only — these confirm the
## wiring, not the visuals.

var _nodes: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()
  Prefs._config = ConfigFile.new()   # hermetic defaults (no disk read), persistence disabled


func after_each() -> void:
  for n in _nodes:
    if is_instance_valid(n):
      n.free()
  _nodes.clear()
  TestCleanup.reset_all_managers()


func _screen() -> SettingsScreen:
  var s: SettingsScreen = preload('res://src/scenes/screens/settings_screen.tscn').instantiate()
  add_child(s)            # _ready seeds + binds the sliders from Prefs
  _nodes.append(s)
  return s


func test_sliders_seed_from_prefs() -> void:
  var s := _screen()
  var master: HSlider = s.get_node('Panel/Tabs/Audio/Rows/MasterRow/Slider')
  assert_almost_eq(master.value, PrefsAutoload.AUDIO_DEFAULTS['master'] * 100.0, 0.01,
    'the master slider is seeded from the stored level (0..1 → 0..100)')


func test_moving_a_slider_writes_the_level_to_prefs() -> void:
  var s := _screen()
  var music: HSlider = s.get_node('Panel/Tabs/Audio/Rows/MusicRow/Slider')
  music.value = 40.0     # value_changed → Prefs.set_volume('music', 0.4)
  assert_almost_eq(Prefs.volume('music'), 0.4, 0.0001, 'dragging the slider wrote the new level to Prefs')


## The text size slider is seeded from the stored scale as a percentage, and its range is the one
## `TextSize` allows.
func test_text_size_slider_seeds_from_prefs() -> void:
  var s := _screen()
  var slider: HSlider = s.get_node('Panel/Tabs/Display/Rows/TextSizeRow/Slider')
  assert_almost_eq(slider.value, TextSize.DEFAULT_SCALE * 100.0, 0.01, 'seeded from the stored scale')
  assert_almost_eq(slider.min_value, TextSize.MIN_SCALE * 100.0, 0.01, 'the low end is the allowed minimum')
  assert_almost_eq(slider.max_value, TextSize.MAX_SCALE * 100.0, 0.01, 'the high end is the allowed maximum')


## Dragging it stores the new scale and resizes the theme, which is what every Control reads.
func test_moving_the_text_size_slider_resizes_the_theme() -> void:
  var s := _screen()
  var slider: HSlider = s.get_node('Panel/Tabs/Display/Rows/TextSizeRow/Slider')
  slider.value = 150.0
  assert_almost_eq(Prefs.text_scale(), 1.5, 0.0001, 'the new scale reached Prefs')
  var theme: Theme = load(PrefsAutoload.THEME_PATH) as Theme
  assert_eq(theme.default_font_size, TextSize.size_of(TextSize.DEFAULT_RUNG, 1.5),
      'the theme default size was rewritten at the new scale')


## Each slider shows its value above the handle as a whole number; the text size one adds '%'.
func test_slider_value_labels_show_whole_numbers() -> void:
  var s := _screen()
  var music: HSlider = s.get_node('Panel/Tabs/Audio/Rows/MusicRow/Slider')
  music.value = 40.0
  assert_eq((music.get_node('Value') as Label).text, '40', 'the volume label shows the slider value')
  var text_size: HSlider = s.get_node('Panel/Tabs/Display/Rows/TextSizeRow/Slider')
  text_size.value = 125.0
  assert_eq((text_size.get_node('Value') as Label).text, '125%', 'the text size label shows a whole percent')


func test_back_emits_closed() -> void:
  var s := _screen()
  watch_signals(s)
  s.get_node('Panel/BackButton').pressed.emit()
  assert_signal_emitted(s, 'closed')


func test_fullscreen_toggle_writes_to_prefs() -> void:
  var s := _screen()
  var check: CheckButton = s.get_node('Panel/Tabs/Display/Rows/FullscreenRow/Check')
  check.button_pressed = true   # toggled → Prefs.set_fullscreen(true)
  assert_true(Prefs.is_fullscreen(), 'toggling Fullscreen wrote the display mode to Prefs')


func test_mute_toggle_writes_to_prefs() -> void:
  var s := _screen()
  var check: CheckButton = s.get_node('Panel/Tabs/Audio/Rows/MuteRow/Check')
  check.button_pressed = true   # toggled → Prefs.set_mute_on_focus_lost(true)
  assert_true(Prefs.mute_on_focus_lost(), 'toggling Mute-when-unfocused wrote the setting to Prefs')


func _key_press(physical_keycode: Key) -> InputEventKey:
  var event: InputEventKey = InputEventKey.new()
  event.physical_keycode = physical_keycode
  event.pressed = true
  return event


func _keybind_row(s: SettingsScreen, action: String) -> KeybindRow:
  for row in s._keybind_rows():
    if row.action == action:
      return row
  return null


func test_controls_tab_has_a_row_per_action() -> void:
  var s := _screen()
  assert_eq(s._keybind_rows().size(), Keybinds.ACTIONS.size(), 'one row per rebindable action')
  assert_eq((_keybind_row(s, 'battle_speed_up').get_node('MainButton') as Button).text, ']', 'shows the default key')


func test_capturing_a_key_binds_it_and_names_the_action_that_lost_it() -> void:
  var s := _screen()
  var row: KeybindRow = _keybind_row(s, 'battle_speed_up')
  row._start_capture(0)
  assert_true(row.is_capturing(), 'waits for a key')
  row._input(_key_press(KEY_BRACKETLEFT))
  assert_false(row.is_capturing(), 'the key ends the wait')
  assert_eq(Keybinds.slots('battle_speed_up')[0], Keybinds.key_slot(KEY_BRACKETLEFT), 'the key is bound')
  assert_eq((_keybind_row(s, 'battle_speed_down').get_node('MainButton') as Button).text, '-', 'the other row lost it')
  assert_ne(s._message.text, '', 'the message names the action that lost the key')


func test_escape_cancels_and_reserved_keys_keep_waiting() -> void:
  var s := _screen()
  var row: KeybindRow = _keybind_row(s, 'battle_speed_up')
  row._start_capture(0)
  row._input(_key_press(KEY_F3))
  assert_true(row.is_capturing(), 'a reserved key is refused and the wait goes on')
  assert_ne(s._message.text, '', 'with a message')
  row._input(_key_press(KEY_ESCAPE))
  assert_false(row.is_capturing(), 'Escape cancels')
  assert_eq(Keybinds.slots('battle_speed_up')[0], Keybinds.key_slot(KEY_BRACKETRIGHT), 'nothing changed')


func test_only_one_row_waits_at_a_time() -> void:
  var s := _screen()
  var first: KeybindRow = _keybind_row(s, 'battle_speed_up')
  var second: KeybindRow = _keybind_row(s, 'battle_speed_down')
  first._start_capture(0)
  second._start_capture(1)
  assert_false(first.is_capturing(), 'starting a second capture cancels the first')
  assert_true(second.is_capturing())


func test_reset_keys_restores_the_defaults() -> void:
  var s := _screen()
  Keybinds.clear('battle_speed_up', 0)
  s._on_reset_keys()
  assert_eq((_keybind_row(s, 'battle_speed_up').get_node('MainButton') as Button).text, ']', 'back on the default')
