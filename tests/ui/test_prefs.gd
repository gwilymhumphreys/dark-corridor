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
