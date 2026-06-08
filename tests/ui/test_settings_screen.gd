extends GutTest
## The settings screen: three volume sliders seeded from Prefs (0..1 → 0..100), each writing the
## new level back to Prefs on change (which applies + persists); Close emits `closed`. Presentation
## reads/writes Prefs only — these confirm the wiring, not the visuals.

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
