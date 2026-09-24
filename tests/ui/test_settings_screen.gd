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
  var master: HSlider = s.get_node('Panel/Scroll/Rows/MasterRow/Slider')
  assert_almost_eq(master.value, PrefsAutoload.AUDIO_DEFAULTS['master'] * 100.0, 0.01,
    'the master slider is seeded from the stored level (0..1 → 0..100)')


func test_moving_a_slider_writes_the_level_to_prefs() -> void:
  var s := _screen()
  var music: HSlider = s.get_node('Panel/Scroll/Rows/MusicRow/Slider')
  music.value = 40.0     # value_changed → Prefs.set_volume('music', 0.4)
  assert_almost_eq(Prefs.volume('music'), 0.4, 0.0001, 'dragging the slider wrote the new level to Prefs')


## The text size slider is seeded from the stored scale as a percentage, and its range is the one
## `TextSize` allows.
func test_text_size_slider_seeds_from_prefs() -> void:
  var s := _screen()
  var slider: HSlider = s.get_node('Panel/Scroll/Rows/TextSizeRow/Slider')
  assert_almost_eq(slider.value, TextSize.DEFAULT_SCALE * 100.0, 0.01, 'seeded from the stored scale')
  assert_almost_eq(slider.min_value, TextSize.MIN_SCALE * 100.0, 0.01, 'the low end is the allowed minimum')
  assert_almost_eq(slider.max_value, TextSize.MAX_SCALE * 100.0, 0.01, 'the high end is the allowed maximum')


## Dragging it stores the new scale and resizes the theme, which is what every Control reads.
func test_moving_the_text_size_slider_resizes_the_theme() -> void:
  var s := _screen()
  var slider: HSlider = s.get_node('Panel/Scroll/Rows/TextSizeRow/Slider')
  slider.value = 150.0
  assert_almost_eq(Prefs.text_scale(), 1.5, 0.0001, 'the new scale reached Prefs')
  var theme: Theme = load(PrefsAutoload.THEME_PATH) as Theme
  assert_eq(theme.default_font_size, TextSize.size_of(TextSize.DEFAULT_RUNG, 1.5),
      'the theme default size was rewritten at the new scale')


## Each slider shows its value above the handle as a whole number; the text size one adds '%'.
func test_slider_value_labels_show_whole_numbers() -> void:
  var s := _screen()
  var music: HSlider = s.get_node('Panel/Scroll/Rows/MusicRow/Slider')
  music.value = 40.0
  assert_eq((music.get_node('Value') as Label).text, '40', 'the volume label shows the slider value')
  var text_size: HSlider = s.get_node('Panel/Scroll/Rows/TextSizeRow/Slider')
  text_size.value = 125.0
  assert_eq((text_size.get_node('Value') as Label).text, '125%', 'the text size label shows a whole percent')


func test_back_emits_closed() -> void:
  var s := _screen()
  watch_signals(s)
  s.get_node('Panel/BackButton').pressed.emit()
  assert_signal_emitted(s, 'closed')


func test_fullscreen_toggle_writes_to_prefs() -> void:
  var s := _screen()
  var check: CheckButton = s.get_node('Panel/Scroll/Rows/FullscreenRow/Check')
  check.button_pressed = true   # toggled → Prefs.set_fullscreen(true)
  assert_true(Prefs.is_fullscreen(), 'toggling Fullscreen wrote the display mode to Prefs')


func test_mute_toggle_writes_to_prefs() -> void:
  var s := _screen()
  var check: CheckButton = s.get_node('Panel/Scroll/Rows/MuteRow/Check')
  check.button_pressed = true   # toggled → Prefs.set_mute_on_focus_lost(true)
  assert_true(Prefs.mute_on_focus_lost(), 'toggling Mute-when-unfocused wrote the setting to Prefs')
