extends GutTest
## Haste and slow (decision #66): on-or-off states on an actor, each for a number of seconds. While
## one is on, the actor's item cooldown bars fill at Balance.HASTE_RATE or Balance.SLOW_RATE times the
## normal rate; both on at once cancel out. A new application adds its seconds to the time left and
## no stacks. Charge is not scaled, and a gated item still does not fill.


var _made: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for cm in _made:
    if is_instance_valid(cm):
      TestCleanup.dissolve_at_reset(cm.player)
      cm.teardown()
      cm.free()
  _made.clear()
  TestCleanup.reset_all_managers()


# --- helpers ----------------------------------------------------------------

## A started fight between `p` and one enemy, with a long-cooldown, effect-less item on `p`'s
## board, put there before the start so the fight steps it.
func _fight(p: Actor) -> Item:
  var e := Actor.new(1000.0)
  TestCleanup.dissolve_at_reset(e)
  var def := ItemDef.new()
  def.id = 'test_haste_item'
  def.cooldown = 10.0
  var it := Item.new(def, p)
  p.board.append(it)
  var cm := CombatManager.new(p, [e])
  _made.append(cm)
  TestCleanup.dissolve_at_reset(p)
  cm.start()
  return it


func _step(times: int) -> void:
  for i in times:
    _made[0].sim_step()


## A mechanic Delivery from `p` aimed at `target`, landed through the mechanic's own land.
func _land(mechanic_id: String, value: float, p: Actor, target) -> void:
  var d := Delivery.new()
  d.kind = Delivery.Kind.MECHANIC
  d.mechanic = mechanic_id
  d.value = value
  d.target = target
  d.source_actor = p
  d.travel = Ticker.new(0)
  MechanicRegistry.get_mechanic(mechanic_id).land(d, _made[0])


func _status(actor: Actor, id: String) -> StatusEffect:
  for s: StatusEffect in actor.statuses:
    if s.id == id:
      return s
  return null


# --- the fill rate -------------------------------------------------------------

func test_no_status_fills_one_step_per_step() -> void:
  var p := Actor.new(100.0)
  var it := _fight(p)
  _step(1)
  assert_almost_eq(it.cooldown.accum, 1.0, 0.0001, 'an actor with neither status fills at the normal rate')


func test_haste_fills_faster() -> void:
  var p := Actor.new(100.0)
  var it := _fight(p)
  StatusManager.apply(p, HasteStatus.ID, 1.0, 2.0)
  _step(1)
  assert_almost_eq(it.cooldown.accum, Balance.HASTE_RATE, 0.0001, 'a hasted actor fills at the haste rate')


func test_slow_fills_more_slowly() -> void:
  var p := Actor.new(100.0)
  var it := _fight(p)
  StatusManager.apply(p, SlowStatus.ID, 1.0, 2.0)
  _step(1)
  assert_almost_eq(it.cooldown.accum, Balance.SLOW_RATE, 0.0001, 'a slowed actor fills at the slow rate')


func test_haste_and_slow_together_cancel_out() -> void:
  var p := Actor.new(100.0)
  var it := _fight(p)
  StatusManager.apply(p, HasteStatus.ID, 1.0, 2.0)
  StatusManager.apply(p, SlowStatus.ID, 1.0, 2.0)
  _step(1)
  assert_almost_eq(it.cooldown.accum, 1.0, 0.0001, 'with both on, the bar fills at the normal rate')


func test_the_longer_status_takes_effect_when_the_shorter_ends() -> void:
  var p := Actor.new(100.0)
  _fight(p)
  StatusManager.apply(p, HasteStatus.ID, 1.0, 0.5)
  StatusManager.apply(p, SlowStatus.ID, 1.0, 2.0)
  _step(int(ceil(0.5 / Balance.STEP)) + 1)
  assert_false(StatusManager.has_status(p, HasteStatus.ID), 'the shorter haste has run out')
  assert_true(StatusManager.has_status(p, SlowStatus.ID), 'the slow still has time left')
  assert_almost_eq(StatusManager.cooldown_rate(p), Balance.SLOW_RATE, 0.0001, 'the slow now takes effect')


func test_the_rate_returns_to_normal_when_haste_ends() -> void:
  var p := Actor.new(100.0)
  _fight(p)
  StatusManager.apply(p, HasteStatus.ID, 1.0, 0.5)
  _step(int(ceil(0.5 / Balance.STEP)) + 1)
  assert_false(StatusManager.has_status(p, HasteStatus.ID), 'haste ends after its seconds')
  assert_almost_eq(StatusManager.cooldown_rate(p), 1.0, 0.0001, 'the rate is normal again')


func test_a_gated_item_does_not_fill_while_hasted() -> void:
  var p := Actor.new(100.0)
  var it := _fight(p)
  StatusManager.apply(p, HasteStatus.ID, 1.0, 2.0)
  var silence: StatusEffect = StatusManager.apply(it, 'silence', 1.0, 0.0)
  _step(1)
  assert_eq(it.cooldown.accum, 0.0, 'a gated item stays frozen')
  it.statuses.erase(silence)


func test_no_owner_has_the_normal_rate() -> void:
  assert_eq(StatusManager.cooldown_rate(null), 1.0, 'an item with no owner fills at the normal rate')


# --- applying ------------------------------------------------------------------

func test_a_haste_delivery_lasts_its_value_in_seconds_with_no_stacks() -> void:
  var p := Actor.new(100.0)
  _fight(p)
  _land(HasteMechanic.ID, 3.0, p, p)
  var haste: StatusEffect = _status(p, HasteStatus.ID)
  assert_not_null(haste, 'landing haste puts the status on the target')
  assert_eq(haste.duration, 3.0, 'the delivery value is the seconds')
  assert_eq(haste.count, 1, 'it has no stacks')


func test_reapplying_adds_seconds_and_no_stacks() -> void:
  var p := Actor.new(100.0)
  _fight(p)
  _land(SlowMechanic.ID, 1.0, p, p)
  _land(SlowMechanic.ID, 2.0, p, p)
  var slow: StatusEffect = _status(p, SlowStatus.ID)
  assert_eq(slow.duration, 3.0, 'the second application adds its seconds')
  assert_eq(slow.ticker.threshold, Ticker.from_seconds(1.0).threshold + Ticker.from_seconds(2.0).threshold,
      'the timer grows by the added seconds')
  assert_eq(slow.count, 1, 'a reapplication adds no stacks')


# --- what is not scaled -----------------------------------------------------------

func test_charge_is_not_scaled_by_haste() -> void:
  var p := Actor.new(100.0)
  var it := _fight(p)
  StatusManager.apply(p, HasteStatus.ID, 1.0, 2.0)
  _land(ChargeMechanic.ID, 1.0, p, it)
  assert_almost_eq(it.cooldown.accum, 1.0 / Balance.STEP, 0.0001, 'a charge adds its full seconds')

