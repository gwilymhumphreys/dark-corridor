extends GutTest
## Step 1 — the run-persistence service. Round-trip a handed snapshot, clear it,
## and prove the no-migration discards (absent / corrupt / wrong version) + that a
## 64-bit RNG state survives exactly when encoded as a string.


func before_each() -> void:
  TestCleanup.reset_all_managers()
  Save.clear()


func after_each() -> void:
  Save.clear()
  TestCleanup.reset_all_managers()


func _sample() -> Dictionary:
  return {
    'hp': 72.0,
    'max_hp': 100.0,
    'board': [{ 'id': 0, 'enchant': null }, { 'id': 2, 'enchant': null }],
    'relics': [0],
    'potions': [],
    'position': 3,
    'rng': { 'seed': '7', 'state': '12345678901234567' },   # > 2^53 — must stay exact
  }


func test_write_then_read_round_trips() -> void:
  var snap := _sample()
  Save.write(snap)
  assert_true(Save.has_save(), 'a save now exists')
  var got := Save.read()
  assert_eq(got['hp'], 72.0)
  assert_eq(int(got['position']), 3)
  assert_eq(got['board'].size(), 2)
  assert_eq(int(got['board'][0]['id']), 0)
  assert_eq(int(got['relics'][0]), 0)
  assert_eq(int(got['version']), 0, 'the format version is stamped on write')


func test_rng_state_survives_exactly() -> void:
  Save.write(_sample())
  var got := Save.read()
  assert_eq(got['rng']['state'], '12345678901234567', 'a 64-bit RNG state is exact via string encoding')
  assert_eq(int(got['rng']['state']), 12345678901234567, 'and parses back to the same integer')


func test_clear_removes_the_save() -> void:
  Save.write(_sample())
  Save.clear()
  assert_false(Save.has_save(), 'clear drops the slot')
  assert_true(Save.read().is_empty(), 'read returns {} when there is no save')


func test_disabled_write_is_a_noop() -> void:
  # The autotest's nosave: while disabled, write() does nothing — a headless run can
  # never clobber the real slot. TestCleanup resets the flag between tests.
  Save.disabled = true
  Save.write(_sample())
  assert_false(Save.has_save(), 'a disabled write persists nothing')
  Save.disabled = false
  Save.write(_sample())
  assert_true(Save.has_save(), 're-enabling write restores normal saving')


func test_absent_save_reads_empty() -> void:
  assert_true(Save.read().is_empty(), 'no save → {} (start fresh)')


func test_corrupt_save_reads_empty() -> void:
  var f := FileAccess.open(SaveAutoload.PATH, FileAccess.WRITE)
  f.store_string('{ this is not valid json ]')
  f.close()
  assert_true(Save.read().is_empty(), 'unreadable save is discarded, not crashed on (no migration)')


func test_wrong_version_is_discarded() -> void:
  var f := FileAccess.open(SaveAutoload.PATH, FileAccess.WRITE)
  f.store_string(JSON.stringify({ 'version': 999, 'hp': 1.0 }))
  f.close()
  assert_true(Save.read().is_empty(), 'an incompatible version is discarded (no migration)')


func test_read_recovers_the_tmp_after_a_crashed_commit() -> void:
  # write() commits remove-then-rename; a crash between the two leaves only the tmp
  # holding the newest save — read() must recover it instead of losing the run.
  Save.write(_sample())
  var dir := DirAccess.open('user://')
  dir.rename(SaveAutoload.PATH, SaveAutoload.TMP_PATH)   # simulate the crash window
  assert_false(FileAccess.file_exists(SaveAutoload.PATH), 'the main slot is gone')
  var got := Save.read()
  assert_eq(got['hp'], 72.0, 'read() recovered the snapshot from the tmp file')


func test_has_save_rejects_a_stale_format_file() -> void:
  var f := FileAccess.open(SaveAutoload.PATH, FileAccess.WRITE)
  f.store_string(JSON.stringify({ 'version': 999, 'hp': 1.0 }))
  f.close()
  assert_false(Save.has_save(), 'has_save() is version-checked — no Resume button that would no-op')
