extends GutTest
## Step 1 — the in-flight carrier. Instant (zero-travel) lands same step;
## a travelled Delivery lands when its travel Ticker crosses.


func test_instant_travel_already_arrived() -> void:
  var d := Delivery.new()
  d.travel = Ticker.new(0)
  assert_true(d.travel.crossed(), 'travel_time 0 is already arrived (same-step land)')


func test_travelled_delivery_lands_after_threshold() -> void:
  var d := Delivery.new()
  d.travel = Ticker.new(2)
  assert_false(d.step_travel(), 'step 1: still in flight')
  assert_true(d.step_travel(), 'step 2: arrives')


func test_default_payload_is_damage() -> void:
  var d := Delivery.new()
  assert_eq(d.kind, Delivery.Kind.DAMAGE, 'defaults to a damage payload')
  assert_false(d.landed, 'starts in flight')
  assert_false(d.fizzled, 'starts un-fizzled')
