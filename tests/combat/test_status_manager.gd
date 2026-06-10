extends GutTest
## The status FACADE over the polymorphic StatusEffect instances. Block (pool/absorber), the
## unblockable flag, additive stacking, the poison DoT (periodic, decrementing), a timed status
## expiring at its per-application duration, the Mass consume rule, and evasion. Statuses are
## driven by stepping in-test (the Combat manager drives them in the real loop).


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_block_absorbs_before_hp() -> void:
  var a := Actor.new(50.0)
  StatusManager.apply(a, 'block', 8.0)
  a.take_damage(5.0)
  assert_eq(a.hp, 50.0, 'block absorbs all 5')
  a.take_damage(5.0)
  assert_eq(a.hp, 48.0, 'remaining 3 block absorbs 3, 2 leaks to HP')
  assert_null(_find(a, 'block'), 'a spent block pool is removed')


func test_unblockable_skips_block() -> void:
  var a := Actor.new(50.0)
  StatusManager.apply(a, 'block', 8.0)
  a.take_damage(5.0, Delivery.Flag.UNBLOCKABLE)
  assert_eq(a.hp, 45.0, 'an unblockable payload bypasses block')


func test_unblockable_dot_bypasses_block() -> void:
  # Decision #5: an unblockable payload bypasses block — and a DoT is per-effect, so
  # the flag must survive to each tick (the applying Delivery is long gone by then).
  var a := Actor.new(50.0)
  StatusManager.apply(a, 'block', 8.0)
  var p := StatusManager.apply(a, 'poison', 3.0, 0.0, null, Delivery.Flag.UNBLOCKABLE)
  _advance(a, p, int(p.ticker.threshold))   # one tick
  assert_eq(a.hp, 47.0, 'the unblockable poison tick goes straight to HP (3 damage)')
  assert_eq(_find(a, 'block').count, 8.0, 'block is untouched by an unblockable DoT')


func test_block_stacks_additively() -> void:
  var a := Actor.new(50.0)
  StatusManager.apply(a, 'block', 5.0)
  StatusManager.apply(a, 'block', 3.0)
  assert_eq(_find(a, 'block').count, 8.0, 'block adds to the pool')


func test_vulnerable_amplifies_incoming_before_block() -> void:
  # #6 incoming seam: Vulnerable scales damage UP in the amplifier stage, before block
  # soaks the (amplified) remainder.
  var a := Actor.new(100.0)
  StatusManager.apply(a, 'vulnerable', 1.0, Balance.STATUS_VULNERABLE_DURATION)
  a.take_damage(10.0)
  var expected: float = 10.0 * Balance.STATUS_VULNERABLE_DAMAGE_MULT
  assert_almost_eq(a.hp, 100.0 - expected, 0.0001, 'Vulnerable amplifies the raw damage')

  var b := Actor.new(100.0)
  StatusManager.apply(b, 'vulnerable', 1.0, Balance.STATUS_VULNERABLE_DURATION)
  StatusManager.apply(b, 'block', 5.0)
  b.take_damage(10.0)   # 10 → x1.5 = 15 amplified; block soaks 5; 10 to HP
  assert_almost_eq(b.hp, 90.0, 0.0001, 'block absorbs the amplified amount (amplifier before absorber)')


func test_outgoing_damage_modifier_reads_weak() -> void:
  # #6 outgoing seam (the facade half): Weak lowers the holder's outgoing DAMAGE value.
  var a := Actor.new(100.0)
  assert_almost_eq(StatusManager.modify_outgoing(a, 10.0), 10.0, 0.0001, 'no statuses → no change')
  StatusManager.apply(a, 'weak', 1.0, Balance.STATUS_WEAK_DURATION)
  assert_almost_eq(StatusManager.modify_outgoing(a, 10.0), 10.0 * Balance.STATUS_WEAK_DAMAGE_MULT, 0.0001,
    'Weak scales outgoing damage down')


func test_poison_dot_decrements_and_expires() -> void:
  var a := Actor.new(50.0)
  var p := StatusManager.apply(a, 'poison', 3.0)
  var interval := int(p.ticker.threshold)
  _advance(a, p, interval)
  assert_eq(a.hp, 47.0, 'tick 1 deals count=3')
  _advance(a, p, interval)
  assert_eq(a.hp, 45.0, 'tick 2 deals count=2')
  var expired := _advance(a, p, interval)
  assert_eq(a.hp, 44.0, 'tick 3 deals count=1')
  assert_true(expired, 'poison expires once its stacks are spent')


func test_timed_status_expires_at_its_duration() -> void:
  var a := Actor.new(50.0)
  var w := StatusManager.apply(a, 'weak', 1.0, Balance.STATUS_WEAK_DURATION)
  var dur := int(w.ticker.threshold)
  var expired := false
  for _i in dur - 1:
    expired = StatusManager.advance_status(w, a)
  assert_false(expired, 'not expired before its duration elapses')
  expired = StatusManager.advance_status(w, a)
  assert_true(expired, 'expires exactly at duration')


func test_consume_spends_stacks_and_reports_what_it_removed() -> void:
  # Cap 1: consume spends up to `amount` stacks and returns how many were there (so the
  # consuming effect scales by what it found).
  var a := Actor.new(50.0)
  StatusManager.apply(a, 'poison', 5.0)
  assert_almost_eq(StatusManager.consume(a, 'poison', 3.0), 3.0, 0.0001, 'removed the requested 3')
  assert_almost_eq(_find(a, 'poison').count, 2.0, 0.0001, 'the remainder stays')


func test_consume_caps_at_available_and_drops_a_drained_stack() -> void:
  var a := Actor.new(50.0)
  StatusManager.apply(a, 'poison', 2.0)
  assert_almost_eq(StatusManager.consume(a, 'poison', 5.0), 2.0, 0.0001, 'only what was present')
  assert_null(_find(a, 'poison'), 'a fully-drained status is removed')


func test_consume_is_a_noop_for_non_fuel_statuses() -> void:
  # The design's stacked-only Mass rule: pool / timed / static return 0 and are untouched.
  var a := Actor.new(50.0)
  StatusManager.apply(a, 'block', 8.0)
  assert_almost_eq(StatusManager.consume(a, 'block', 5.0), 0.0, 0.0001, 'block is not Mass fuel')
  assert_almost_eq(_find(a, 'block').count, 8.0, 0.0001, 'and is untouched')


func test_consume_of_an_absent_status_returns_zero() -> void:
  assert_almost_eq(StatusManager.consume(Actor.new(50.0), 'poison', 3.0), 0.0, 0.0001, 'nothing to spend')


func test_periodic_status_on_an_item_does_not_crash() -> void:
  # The item-target shapes can deliver an APPLY_STATUS to an Item, and the status id is
  # authored content. A PERIODIC (poison) status on an item must NOT crash (Item has no
  # take_damage) — it ticks down harmlessly with no damage.
  var item := Item.new(ItemCatalog.get_def(ItemCatalog.POISON_DAGGER), Actor.new())
  var p := StatusManager.apply(item, 'poison', 2.0)
  p.ticker.accum = p.ticker.threshold - 1.0   # one step from firing
  StatusManager.advance_status(p, item)        # crosses → take_damage(item) would crash, guarded
  assert_almost_eq(p.count, 1.0, 0.0001, 'the periodic status ticked down on the item without crashing')


func test_has_evasion_reads_the_flag() -> void:
  # Cap 2: has_evasion asks the instances, never a status name.
  var a := Actor.new(50.0)
  assert_false(StatusManager.has_evasion(a), 'no statuses → no evasion')
  StatusManager.apply(a, 'blind', 1.0, Balance.STATUS_BLIND_DURATION)
  assert_true(StatusManager.has_evasion(a), 'a blind status causes evasion')


# --- helpers (not test_*; GUT ignores them) ---

func _advance(owner_actor: Actor, status: StatusEffect, steps: int) -> bool:
  var expired := false
  for _i in steps:
    expired = StatusManager.advance_status(status, owner_actor)
  return expired


func _find(a: Actor, id: String) -> StatusEffect:
  for s in a.statuses:
    if s.id == id:
      return s
  return null
