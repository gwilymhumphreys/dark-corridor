extends GutTest
## Step 2 — the status rulebook. Block (pool/absorber), the unblockable flag,
## additive stacking, the poison DoT (periodic, decrementing), and a timed
## status expiring on schedule. Statuses are driven by stepping in-test (the
## Combat manager will drive them in Step 4).


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_block_absorbs_before_hp() -> void:
  var a := Actor.new(50.0)
  StatusManager.apply(a, StatusDef.Type.BLOCK, 8.0)
  a.take_damage(5.0)
  assert_eq(a.hp, 50.0, 'block absorbs all 5')
  a.take_damage(5.0)
  assert_eq(a.hp, 48.0, 'remaining 3 block absorbs 3, 2 leaks to HP')
  assert_null(_find(a, StatusDef.Type.BLOCK), 'a spent block pool is removed')


func test_unblockable_skips_block() -> void:
  var a := Actor.new(50.0)
  StatusManager.apply(a, StatusDef.Type.BLOCK, 8.0)
  a.take_damage(5.0, Delivery.Flag.UNBLOCKABLE)
  assert_eq(a.hp, 45.0, 'an unblockable payload bypasses block')


func test_block_stacks_additively() -> void:
  var a := Actor.new(50.0)
  StatusManager.apply(a, StatusDef.Type.BLOCK, 5.0)
  StatusManager.apply(a, StatusDef.Type.BLOCK, 3.0)
  assert_eq(_find(a, StatusDef.Type.BLOCK).count, 8.0, 'block adds to the pool')


func test_poison_dot_decrements_and_expires() -> void:
  var a := Actor.new(50.0)
  var p := StatusManager.apply(a, StatusDef.Type.POISON, 3.0)
  var interval := int(p.ticker.threshold)
  _advance(p, interval)
  assert_eq(a.hp, 47.0, 'tick 1 deals count=3')
  _advance(p, interval)
  assert_eq(a.hp, 45.0, 'tick 2 deals count=2')
  var expired := _advance(p, interval)
  assert_eq(a.hp, 44.0, 'tick 3 deals count=1')
  assert_true(expired, 'poison expires once its stacks are spent')


func test_timed_status_expires_at_duration() -> void:
  var a := Actor.new(50.0)
  var w := StatusManager.apply(a, StatusDef.Type.WEAK, 1.0)
  var dur := int(w.ticker.threshold)
  var expired := false
  for i in dur - 1:
    expired = StatusManager.advance_status(w)
  assert_false(expired, 'not expired before its duration elapses')
  expired = StatusManager.advance_status(w)
  assert_true(expired, 'expires exactly at duration')


# --- helpers (not test_*; GUT ignores them) ---

func _advance(status, steps: int) -> bool:
  var expired := false
  for i in steps:
    expired = StatusManager.advance_status(status)
  return expired


func _find(a, type: int):
  for s in a.statuses:
    if s.type == type:
      return s
  return null
