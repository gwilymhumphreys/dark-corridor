extends GutTest
## Step 1 — the accrual primitive. Threshold-crossing, push (charges model),
## reset-with-carry, instant (zero-threshold) case, and the seconds helper.


func test_crosses_at_threshold() -> void:
  var t := Ticker.new(3)
  assert_false(t.step(), 'step 1: accum 1, not crossed')
  assert_false(t.step(), 'step 2: accum 2, not crossed')
  assert_true(t.step(), 'step 3: accum 3 >= 3, crosses')


func test_reset_carries_overflow() -> void:
  var t := Ticker.new(3)
  t.accum = 4.0
  t.reset()
  assert_almost_eq(t.accum, 1.0, 0.0001, 'reset subtracts the threshold, carrying overflow')


func test_push_is_a_fraction_of_the_bar() -> void:
  var t := Ticker.new(10)
  t.push(0.5)
  assert_almost_eq(t.accum, 5.0, 0.0001, 'a half-bar push adds half the threshold')
  t.push(1.0)
  assert_true(t.crossed(), 'a full-bar push crosses')


func test_instant_zero_threshold_already_crossed() -> void:
  var t := Ticker.new(0)
  assert_true(t.crossed(), 'a zero-threshold ticker is already arrived (instant travel)')


func test_from_seconds_rounds_up_to_steps() -> void:
  assert_eq(int(Ticker.from_seconds(Balance.STEP).threshold), 1, 'one STEP of time -> threshold 1')
  assert_eq(int(Ticker.from_seconds(0.0).threshold), 0, 'zero seconds -> instant (threshold 0)')


func test_progress_ratio() -> void:
  var t := Ticker.new(4)
  t.step()
  t.step()
  assert_almost_eq(t.progress(), 0.5, 0.0001, 'two of four steps = half-filled ring')
