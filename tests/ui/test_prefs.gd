extends GutTest
## The Prefs autoload — audio volumes stored 0..1, applied to AudioServer buses, defaulted when
## unset, clamped on set. Disk persistence is suppressed in tests (TestCleanup sets
## Prefs.disabled); before_each forces an empty in-memory config so the defaults are hermetic.


func before_each() -> void:
  TestCleanup.reset_all_managers()
  Prefs._config = ConfigFile.new()   # hermetic: no disk read, so volume() returns the defaults


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _bus_db(key: String) -> float:
  return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(PrefsAutoload.AUDIO_BUSES[key]))


func test_unset_volume_returns_the_default() -> void:
  assert_almost_eq(Prefs.volume('master'), PrefsAutoload.AUDIO_DEFAULTS['master'], 0.0001,
    'an unset key reads its default level')


func test_set_volume_stores_and_clamps() -> void:
  Prefs.set_volume('music', 0.5)
  assert_almost_eq(Prefs.volume('music'), 0.5, 0.0001, 'the level is stored')
  Prefs.set_volume('music', 2.0)
  assert_almost_eq(Prefs.volume('music'), 1.0, 0.0001, 'and clamped to 1.0')
  Prefs.set_volume('music', -1.0)
  assert_almost_eq(Prefs.volume('music'), 0.0, 0.0001, 'and to 0.0')


func test_set_volume_applies_to_the_bus() -> void:
  Prefs.set_volume('effects', 0.5)
  assert_almost_eq(_bus_db('effects'), linear_to_db(0.5), 0.01, 'the Effects bus tracks the linear level (as dB)')


func test_zero_volume_is_silence_not_negative_infinity() -> void:
  Prefs.set_volume('master', 0.0)
  assert_almost_eq(_bus_db('master'), -80.0, 0.01, 'zero maps to -80 dB (silence), not -inf')


func _master_muted() -> bool:
  return AudioServer.is_bus_mute(AudioServer.get_bus_index(PrefsAutoload.AUDIO_BUSES['master']))


func test_mute_on_focus_lost_defaults_off() -> void:
  assert_false(Prefs.mute_on_focus_lost(), 'mute-when-unfocused is off until enabled')


func test_focus_out_mutes_only_when_enabled() -> void:
  Prefs.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
  assert_false(_master_muted(), 'a focus-out with the setting off leaves Master audible')
  Prefs.set_mute_on_focus_lost(true)
  Prefs.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
  assert_true(_master_muted(), 'with it on, losing focus mutes Master')
  Prefs.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
  assert_false(_master_muted(), 'and regaining focus unmutes it')


func test_disabling_mute_setting_unmutes_immediately() -> void:
  Prefs.set_mute_on_focus_lost(true)
  Prefs.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
  assert_true(_master_muted(), 'muted while unfocused')
  Prefs.set_mute_on_focus_lost(false)
  assert_false(_master_muted(), 'turning the setting off unmutes right away (not left silenced)')


func test_fullscreen_defaults_off_and_stores() -> void:
  assert_false(Prefs.is_fullscreen(), 'windowed until set')
  Prefs.set_fullscreen(true)
  assert_true(Prefs.is_fullscreen(), 'the chosen display mode is stored')
