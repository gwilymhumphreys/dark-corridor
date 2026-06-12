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
