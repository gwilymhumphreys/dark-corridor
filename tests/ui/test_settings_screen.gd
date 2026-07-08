extends GutTest
## The settings screen: three volume sliders (0..1 → 0..100), a font dropdown, and the fullscreen
## + mute-when-unfocused toggles — each seeded from Prefs and writing back on change (Prefs applies
## + persists); Close emits `closed`. Presentation reads/writes Prefs only — these confirm the
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
  var master: HSlider = s.get_node('Panel/Rows/MasterRow/Slider')
  assert_almost_eq(master.value, PrefsAutoload.AUDIO_DEFAULTS['master'] * 100.0, 0.01,
    'the master slider is seeded from the stored level (0..1 → 0..100)')


func test_moving_a_slider_writes_the_level_to_prefs() -> void:
  var s := _screen()
  var music: HSlider = s.get_node('Panel/Rows/MusicRow/Slider')
  music.value = 40.0     # value_changed → Prefs.set_volume('music', 0.4)
  assert_almost_eq(Prefs.volume('music'), 0.4, 0.0001, 'dragging the slider wrote the new level to Prefs')


func test_back_emits_closed() -> void:
  var s := _screen()
  watch_signals(s)
  s.get_node('Panel/BackButton').pressed.emit()
  assert_signal_emitted(s, 'closed')


func test_font_dropdown_seeds_from_prefs() -> void:
  Prefs._config.set_value(PrefsAutoload.SECTION_DISPLAY, 'font_style', PrefsAutoload.FontStyle.PIXEL)
  var s := _screen()
  var option: OptionButton = s.get_node('Panel/Rows/FontRow/Option')
  assert_eq(option.get_selected_id(), PrefsAutoload.FontStyle.PIXEL,
    'the dropdown selects the item whose id is the stored font style')


func test_choosing_a_font_writes_the_style_to_prefs() -> void:
  var s := _screen()
  var option: OptionButton = s.get_node('Panel/Rows/FontRow/Option')
  option.select(option.get_item_index(PrefsAutoload.FontStyle.PIXEL))
  option.item_selected.emit(option.selected)   # select() doesn't emit; mirror a user pick
  assert_eq(Prefs.font_style(), PrefsAutoload.FontStyle.PIXEL, 'picking an item wrote the style to Prefs')


func test_fullscreen_toggle_writes_to_prefs() -> void:
  var s := _screen()
  var check: CheckButton = s.get_node('Panel/Rows/FullscreenRow/Check')
  check.button_pressed = true   # toggled → Prefs.set_fullscreen(true)
  assert_true(Prefs.is_fullscreen(), 'toggling Fullscreen wrote the display mode to Prefs')


func test_mute_toggle_writes_to_prefs() -> void:
  var s := _screen()
  var check: CheckButton = s.get_node('Panel/Rows/MuteRow/Check')
  check.button_pressed = true   # toggled → Prefs.set_mute_on_focus_lost(true)
  assert_true(Prefs.mute_on_focus_lost(), 'toggling Mute-when-unfocused wrote the setting to Prefs')
