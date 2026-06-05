extends GutTest
## Step 3 — the reward draw. Returns 3 candidates from the pool, distinct within an
## offer, and is fully determined by the handed RNG state (the no-save-scum
## property: same run-state ⇒ same offer).


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _ids(offer: Array) -> Array:
  var out: Array = []
  for d in offer:
    out.append(d.id)
  return out


func _rng(seed_value: int) -> RandomNumberGenerator:
  var r := RandomNumberGenerator.new()
  r.seed = seed_value
  return r


func test_draw_returns_three_candidates() -> void:
  var offer := Draft.draw(DraftPool.ITEMS, 0, _rng(1))
  assert_eq(offer.size(), 3, 'a 1-of-3 offer')


func test_candidates_come_from_the_pool() -> void:
  var offer := Draft.draw(DraftPool.ITEMS, 0, _rng(5))
  for d in offer:
    assert_true(DraftPool.ITEMS.has(d.id), 'every candidate is a pool item')


func test_offer_is_distinct_when_the_pool_has_breadth() -> void:
  var ids := _ids(Draft.draw(DraftPool.ITEMS, 0, _rng(9)))
  assert_eq(ids.size(), 3)
  assert_false(ids[0] == ids[1] or ids[1] == ids[2] or ids[0] == ids[2], 'no duplicate slots (pool >= 3)')


func test_same_rng_state_yields_the_same_offer() -> void:
  var a := _ids(Draft.draw(DraftPool.ITEMS, 0, _rng(42)))
  var b := _ids(Draft.draw(DraftPool.ITEMS, 0, _rng(42)))
  assert_eq(a, b, 'same seed/state ⇒ identical offer (no save-scum)')


func test_draw_advances_the_rng_deterministically() -> void:
  # Two RNGs seeded alike must produce identical successive offers — proves the
  # draw consumes RNG state deterministically (so the saved state replays).
  var r1 := _rng(7)
  var r2 := _rng(7)
  var a1 := _ids(Draft.draw(DraftPool.ITEMS, 0, r1))
  var a2 := _ids(Draft.draw(DraftPool.ITEMS, 0, r1))
  var b1 := _ids(Draft.draw(DraftPool.ITEMS, 0, r2))
  var b2 := _ids(Draft.draw(DraftPool.ITEMS, 0, r2))
  assert_eq(a1, b1, 'first draws match')
  assert_eq(a2, b2, 'second draws match (state advanced identically)')
