extends GutTest
## AutoTestStuckDetector — the "fight that never resolves" guard. The first reading
## seeds the baseline; after that, `threshold` consecutive flat total-HP readings
## trip it, and any HP change resets the stall.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_flat_hp_trips_after_threshold() -> void:
  var d := AutoTestStuckDetector.new(3)
  assert_false(d.note(100.0), 'first reading only seeds the baseline')
  assert_false(d.note(100.0), '1 flat step')
  assert_false(d.note(100.0), '2 flat steps')
  assert_true(d.note(100.0), '3 flat steps reaches the threshold')


func test_hp_change_resets_the_stall() -> void:
  var d := AutoTestStuckDetector.new(3)
  d.note(100.0)
  d.note(100.0)
  d.note(100.0)
  assert_false(d.note(90.0), 'HP changed — the stall resets')
  assert_eq(d.flat_steps(), 0, 'flat counter cleared on progress')
  assert_false(d.note(90.0))
  assert_false(d.note(90.0))
  assert_true(d.note(90.0), 'trips again after another full flat run')


func test_threshold_floor_is_one() -> void:
  var d := AutoTestStuckDetector.new(0)   # clamped up to 1
  d.note(50.0)
  assert_true(d.note(50.0), 'one flat step trips a minimum-threshold detector')
