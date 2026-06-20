extends GutTest
## The new polymorphic status model (docs/systems/status_manager.md) — proving the
## WeakStatus slice before the full migration: registry construction, the outgoing-damage modifier
## (PULL hook), per-application duration, and reapply = STACK (extend the timer). The old
## StatusDef / StatusManager path is untouched and runs alongside; this is purely additive.


func test_registry_builds_a_weak_status_for_its_id() -> void:
  var w := StatusRegistry.create('weak')
  assert_not_null(w, 'the registry knows the weak id')
  assert_eq(w.id, 'weak', 'and builds a WeakStatus carrying that id')
  assert_eq(w.name_key, 'Weak', 'presentation is set on the instance (localizable)')


func test_weak_scales_outgoing_damage_down() -> void:
  var w := StatusRegistry.create('weak')
  assert_almost_eq(w.modify_outgoing(10.0, null, null), 10.0 * Balance.STATUS_WEAK_DAMAGE_MULT, 0.0001,
    'Weak scales an outgoing DAMAGE payload by the Weak multiplier')


func test_duration_rides_the_application_not_a_global() -> void:
  var short := StatusRegistry.create('weak')
  short.setup(1.0, 2.0, null, 0)
  var long := StatusRegistry.create('weak')
  long.setup(1.0, 5.0, null, 0)
  assert_true(long.ticker.threshold > short.ticker.threshold,
    'a 5s application outlasts a 2s one — duration is per-application, the original bug is gone')


func test_timed_status_expires_at_its_duration() -> void:
  var w := StatusRegistry.create('weak')
  w.setup(1.0, 2.0, null, 0)
  var steps := int(w.ticker.threshold)
  var expired := false
  for _i in steps - 1:
    expired = w.on_step(null, null)
  assert_false(expired, 'not expired before its duration elapses')
  expired = w.on_step(null, null)
  assert_true(expired, 'expires exactly at its duration')


func test_reapply_stacks_by_extending_the_timer() -> void:
  var w := StatusRegistry.create('weak')
  w.setup(1.0, 2.0, null, 0)
  var before: float = w.ticker.threshold
  w.reapply(1.0, 2.0, null, 0)
  assert_true(w.ticker.threshold > before, 'reapply STACKS — the timer is extended, not refreshed')
  assert_almost_eq(w.count, 2.0, 0.0001, 'and count adds')


# --- Decay use-status (docs/systems/item_creation_and_decay.md Cap 2) -----------------------
# Block's twin: a pool of count on an ITEM, drained by the item firing, that removes the item at 0.

## Records the ctx.remove_item call so the unit test can assert the host item is requested for removal.
class _RecordingCtx:
  var removed = null
  func remove_item(item) -> void:
    removed = item


func test_registry_builds_a_decay_status_for_its_id() -> void:
  var d := StatusRegistry.create('decay')
  assert_not_null(d, 'the registry knows the decay id')
  assert_eq(d.id, 'decay', 'and builds a DecayStatus carrying that id')


func test_decay_drains_one_per_fire_and_asks_to_remove_at_zero() -> void:
  var d := StatusRegistry.create('decay')
  d.setup(2.0, 0.0, null, 0)
  var ctx := _RecordingCtx.new()
  d.on_holder_fired('item_a', ctx)
  assert_almost_eq(d.count, 1.0, 0.0001, 'one activation spent per fire')
  assert_null(ctx.removed, 'not removed while charges remain (decay 2 fires twice)')
  d.on_holder_fired('item_a', ctx)
  assert_almost_eq(d.count, 0.0, 0.0001, 'drained to zero on the second fire')
  assert_eq(ctx.removed, 'item_a', 'and asks ctx to remove the host item at zero')


func test_decay_reapply_tops_up_charges() -> void:
  var d := StatusRegistry.create('decay')
  d.setup(2.0, 0.0, null, 0)
  d.reapply(2.0, 0.0, null, 0)
  assert_almost_eq(d.count, 4.0, 0.0001, 'reapply STACKS — charges add (top-up is reapply)')
